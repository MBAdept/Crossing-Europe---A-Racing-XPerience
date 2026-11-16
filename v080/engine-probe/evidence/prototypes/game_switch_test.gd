extends SceneTree
## Probe (scratch copy only): 2D race scene -> 3D scene -> 2D race scene in one session.
## Is the Arcade picture the same before and after a 3D scene was shown (and its root-viewport settings changed)?
##   xvfb-run ... godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -s res://probe/switch_test.gd -- --out=<dir> [--hour=21]

var _out := "/tmp"
var _hour := 21.0
var _runner: Node


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--hour="):
			_hour = float(a.substr(7))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _race(tag: String, frames_n: int) -> Image:
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": "limousine",
		"start_world_minutes": _hour * 60.0, "weather": "rain", "start_km": 30.0, "autopilot": true, "no_countdown": true, "seed": 5}
	var t0 := Time.get_ticks_msec()
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	await _frames(frames_n)
	var img: Image = await _grab()
	img.save_png(_out.path_join("switch_%s.png" % tag))
	print("SWITCH race ", tag, " frames=", frames_n, " ms=", Time.get_ticks_msec() - t0, " size=", img.get_size(), " canvas_draw_calls=", root.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	sc.queue_free()
	await _frames(3)
	return img


func _three_d(tag: String) -> Image:
	var t0 := Time.get_ticks_msec()
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.5, 8)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.8, -20))
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.01
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	for i: int in range(60):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.8, 1.4, 4.4)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(float(i) / 60.0, 0.8, 0.9)
		m.metallic = 0.4
		m.roughness = 0.3
		if i % 5 == 0:
			m.emission_enabled = true
			m.emission = Color(1, 0.2, 0.1)
			m.emission_energy_multiplier = 3.0
		mi.material_override = m
		mi.position = Vector3(float(i % 3) * 4.0 - 4.0, 0.7, -float(i) * 6.0)
		world.add_child(mi)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 800)
	ground.mesh = pm
	world.add_child(ground)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 1, 6)
	spot.shadow_enabled = true
	world.add_child(spot)
	# root viewport settings a 3D mode would touch
	root.msaa_3d = Viewport.MSAA_4X
	root.scaling_3d_scale = 0.75
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	await _frames(20)
	var img: Image = await _grab()
	img.save_png(_out.path_join("switch_%s.png" % tag))
	print("SWITCH 3d ", tag, " ms=", Time.get_ticks_msec() - t0, " draw_calls=", root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	world.queue_free()
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.scaling_3d_scale = 1.0
	RenderingServer.directional_shadow_atlas_set_size(4096, false)
	await _frames(3)
	return img


func _cmp(a: Image, b: Image, label: String) -> void:
	var m: Dictionary = a.compute_image_metrics(b, false)
	print("SWITCH compare ", label, ": max=", m["max"], " mean=", m["mean"], " identical=", float(m["max"]) == 0.0)


func _run() -> void:
	await _frames(5)
	print("SWITCH stretch mode=", root.content_scale_mode, " aspect=", root.content_scale_aspect, " root disable_3d=", root.disable_3d, " msaa_3d=", root.msaa_3d)
	var a1: Image = await _race("a1_race", 45)
	var a2: Image = await _race("a2_race_again", 45)
	_cmp(a1, a2, "race vs race again (control, no 3D in between)")
	var b: Image = await _three_d("b_3d")
	var a3: Image = await _race("a3_race_after_3d", 45)
	_cmp(a1, a3, "race vs race after the 3D scene")
	_cmp(a2, a3, "race again vs race after the 3D scene")
	# 3D scene visible together with the race scene? (both in the root viewport: 3D below the canvas)
	print("SWITCH orphan nodes=", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), " objects=", Performance.get_monitor(Performance.OBJECT_COUNT), " video_mem_mb=", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1))
	quit(0)
