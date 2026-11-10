extends "res://probe_base.gd"
# Export smoke test: one scene that uses the feature set a "Modern" mode would need.

func test_all() -> void:
	var t_start := Time.get_ticks_msec()
	note("adapter", RenderingServer.get_video_adapter_name())
	note("vendor", RenderingServer.get_video_adapter_vendor())
	note("api_version", RenderingServer.get_video_adapter_api_version())
	note("rendering_method", RenderingServer.get_current_rendering_method())
	note("rendering_driver", RenderingServer.get_current_rendering_driver_name())
	note("os", OS.get_name() + " / " + OS.get_distribution_name() + " / " + OS.get_version())
	note("executable", OS.get_executable_path().get_file())
	note("is_exported", OS.has_feature("template"))
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	env.sky.sky_material = sm
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.003
	env.fog_light_color = Color(0.6, 0.66, 0.74)
	env.ssao_enabled = true
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var fxs: GDScript = load("res://t_fx.gd")
	var fx: Node = fxs.new()
	add_child(fx)
	var forest: MultiMeshInstance3D = fx.call("make_forest", 3000, "scissor")
	world.add_child(forest)
	var rain: GPUParticles3D = fx.call("make_rain", 4000)
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(rain)
	var ps: PackedScene = load("res://models/player_sportwagen_flat.glb")
	var hero: Node3D = ps.instantiate()
	hero.position = Vector3(-5.0, 0.0, -9.0)
	hero.rotation_degrees = Vector3(0, 180, 0)
	world.add_child(hero)
	spot(world, Vector3(-0.6, 0.7, -2.3), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	omni(world, Vector3(8.5, 7.0, -20.0), 22.0, 3.0)
	var tex: Texture2D = load("res://tex/tex_vram_s3tc.png")
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = tex
	plane(world, Vector2(6, 6), Vector3(9.5, 0.03, -6), tm)
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := Label.new()
	l.text = "Export-Test: %s – %s" % [OS.get_name(), RenderingServer.get_video_adapter_api_version()]
	l.position = Vector2(30, 24)
	l.add_theme_font_size_override("font_size", 28)
	layer.add_child(l)
	var first: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for i: int in range(6):
		await RenderingServer.frame_post_draw
		var t1 := Time.get_ticks_usec()
		first.append(snappedf(float(t1 - t0) / 1000.0, 0.1))
		t0 = t1
	note("first_frames_ms", first)
	await variant("day", true, 20)
	night()
	sm.set_shader_parameter("night", 1.0)
	await variant("night", true, 12)
	note("total_ms", Time.get_ticks_msec() - t_start)
	note("static_memory_mb", snappedf(float(OS.get_static_memory_usage()) / 1048576.0, 0.1))
