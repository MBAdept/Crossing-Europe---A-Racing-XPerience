extends "res://probe_base.gd"
# Shader compilation hitches: first use of a material / light configuration, cold vs. warm cache,
# and pre-warming in a tiny off-screen viewport.

var fx: Node

func frame_times(n: int) -> Array[float]:
	var out: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for i: int in range(n):
		await RenderingServer.frame_post_draw
		var t1 := Time.get_ticks_usec()
		out.append(float(t1 - t0) / 1000.0)
		t0 = t1
	return out

func baseline() -> float:
	var t: Array[float] = await frame_times(8)
	t.sort()
	return t[4]

func spike(label: String, action: Callable) -> void:
	var base: float = await baseline()
	action.call()
	var t: Array[float] = await frame_times(4)
	var after: float = await baseline()
	var mx: float = 0.0
	for v: float in t:
		mx = maxf(mx, v)
	note("spike_" + label, {"baseline_ms": snappedf(base, 0.1), "first_frames_ms": [snappedf(t[0], 0.1), snappedf(t[1], 0.1), snappedf(t[2], 0.1), snappedf(t[3], 0.1)], "steady_after_ms": snappedf(after, 0.1), "hitch_ms": snappedf(maxf(0.0, mx - after), 0.1)})

func light_world() -> void:
	# small scene so that steady frame times are low and hitches stand out
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.5, 8)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.8, -20))
	env = Environment.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	sm.set_shader_parameter("use_time", 0.0)
	var sky := Sky.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	wenv = WorldEnvironment.new()
	wenv.environment = env
	world.add_child(wenv)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	plane(world, Vector2(60, 400), Vector3(0, 0, -150), mat(Color(0.14, 0.14, 0.15), 0.7))

func actions(parent: Node3D) -> Array:
	var fxs: GDScript = load("res://t_fx.gd")
	fx = fxs.new()
	add_child(fx)
	return [
		["standard_material_metal", func() -> void: box(parent, Vector3(2, 1, 4), Vector3(-6, 0.5, -8), mat(Color(0.8, 0.1, 0.1), 0.3, 0.6))],
		["emission_material", func() -> void: box(parent, Vector3(0.5, 0.2, 0.1), Vector3(-6, 0.8, -5.9), emat(Color(1, 0.1, 0.05), 3.0))],
		["sun_shadow_pssm4", func() -> void:
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 120.0],
		["fog_enabled", func() -> void:
			env.fog_enabled = true
			env.fog_density = 0.004],
		["spot_light", func() -> void: spot(parent, Vector3(0, 1, 2), Vector3(0, 0, -30), 60.0, 30.0, 5.0)],
		["omni_light", func() -> void: omni(parent, Vector3(4, 5, -10), 20.0, 3.0)],
		["spot_light_with_shadow", func() -> void:
			var l := spot(parent, Vector3(2, 1, 2), Vector3(2, 0, -30), 60.0, 30.0, 5.0)
			l.shadow_enabled = true],
		["alpha_scissor_multimesh_forest", func() -> void: parent.add_child(fx.call("make_forest", 500, "scissor"))],
		["gpu_particles_rain", func() -> void: parent.add_child(fx.call("make_rain", 2000))],
		["imported_glb_car", func() -> void:
			var ps: PackedScene = load("res://models/player_sportwagen_flat.glb")
			var c: Node3D = ps.instantiate()
			c.position = Vector3(0, 0, -6)
			parent.add_child(c)],
		["custom_bend_shader", func() -> void:
			var m := ShaderMaterial.new()
			m.shader = load("res://bend_wrong.gdshader")
			m.set_shader_parameter("albedo", Color(0.2, 0.6, 0.9))
			box(parent, Vector3(2, 2, 2), Vector3(6, 1, -12), m)],
		["transparent_glass", func() -> void:
			var g := StandardMaterial3D.new()
			g.albedo_color = Color(0.5, 0.8, 1.0, 0.4)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			box(parent, Vector3(3, 2, 0.1), Vector3(-3, 1, -4), g)],
	]

# Each new feature is introduced in the visible scene; the hitch is the extra time of the first frames.
func test_cold() -> void:
	RenderingServer.global_shader_parameter_add("bend_params", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	light_world()
	await frames(10)
	note("shader_cache_enabled", ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled"))
	note("user_dir", OS.get_user_data_dir())
	for a: Array in actions(world):
		await spike(a[0], a[1])
	await variant("end", false, 4)

# Pre-warm: run all actions first inside a 64x64 SubViewport that shares the world (same lights/env),
# then repeat them in the main view.
func test_prewarm() -> void:
	RenderingServer.global_shader_parameter_add("bend_params", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	light_world()
	await frames(10)
	var t0 := Time.get_ticks_msec()
	# the pre-warm objects live in the same World3D, far below the ground, seen only by the warm camera
	var warm_root := Node3D.new()
	warm_root.position = Vector3(0, -500, 0)
	world.add_child(warm_root)
	var sv := SubViewport.new()
	sv.size = Vector2i(64, 64)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var wc := Camera3D.new()
	sv.add_child(wc)
	wc.global_position = Vector3(0, -497.5, 8)
	wc.look_at(Vector3(0, -499.2, -20))
	for a: Array in actions(warm_root):
		(a[1] as Callable).call()
	# lights created by the actions sit at warm_root; the environment changes (fog, shadows) are global
	await frames(6)
	var t1 := Time.get_ticks_msec()
	note("prewarm_total_ms", t1 - t0)
	# reset the global toggles, then repeat everything in the visible scene
	sun.shadow_enabled = false
	env.fog_enabled = false
	sv.queue_free()
	warm_root.queue_free()
	await frames(6)
	for a: Array in actions(world):
		await spike(a[0], a[1])
	await variant("end", false, 4)

# Pre-warm by replaying the same sequence of state combinations in a 64x64 SubViewport first.
func test_prewarm_seq() -> void:
	RenderingServer.global_shader_parameter_add("bend_params", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	light_world()
	await frames(10)
	var t0 := Time.get_ticks_msec()
	var warm_root := Node3D.new()
	warm_root.position = Vector3(0, -500, 0)
	world.add_child(warm_root)
	var sv := SubViewport.new()
	sv.size = Vector2i(64, 64)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var wc := Camera3D.new()
	sv.add_child(wc)
	wc.global_position = Vector3(0, -497.5, 8)
	wc.look_at(Vector3(0, -499.2, -20))
	# the ground too, so that its material sees every state
	plane(warm_root, Vector2(60, 400), Vector3(0, 0, -150), mat(Color(0.14, 0.14, 0.15), 0.7))
	for a: Array in actions(warm_root):
		(a[1] as Callable).call()
		await frames(2)
	var t1 := Time.get_ticks_msec()
	note("prewarm_seq_total_ms", t1 - t0)
	sun.shadow_enabled = false
	env.fog_enabled = false
	sv.queue_free()
	warm_root.queue_free()
	await frames(6)
	for a: Array in actions(world):
		await spike(a[0], a[1])

# Replay in the same (main) viewport: pass 1 compiles, everything is removed, pass 2 repeats.
func test_replay() -> void:
	RenderingServer.global_shader_parameter_add("bend_params", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	light_world()
	await frames(10)
	for pass_i: int in range(2):
		var holder := Node3D.new()
		world.add_child(holder)
		var t0 := Time.get_ticks_msec()
		for a: Array in actions(holder):
			await spike("pass%d_%s" % [pass_i + 1, a[0]], a[1])
		note("pass%d_total_ms" % (pass_i + 1), Time.get_ticks_msec() - t0)
		holder.queue_free()
		sun.shadow_enabled = false
		env.fog_enabled = false
		await frames(6)
