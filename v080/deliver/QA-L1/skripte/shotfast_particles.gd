extends SceneTree
## QA lens 1: what Screenshotter --shot-fast (render loop off until 0.1 s before a shot) does to things the
## RenderingServer advances while drawing: a GPUParticles3D system with a fixed seed, rendered for 120 frames,
## against the same system with the render loop off for the first 114 frames.

func _initialize() -> void:
	_run.call_deferred()

func _scene() -> Node3D:
	var n := Node3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.1)
	var we := WorldEnvironment.new()
	we.environment = env
	n.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1, 6)
	n.add_child(cam)
	var p := GPUParticles3D.new()
	p.amount = 300
	p.lifetime = 4.0
	p.use_fixed_seed = true
	p.seed = 1234
	p.fixed_fps = 60
	p.interpolate = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -2, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(4, 0.1, 1)
	p.process_material = mat
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.3)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.8, 0.9, 1.0)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = sm
	p.draw_pass_1 = q
	p.position = Vector3(0, 4, 0)
	n.add_child(p)
	return n

func _shot(fast: bool) -> Image:
	var n := _scene()
	root.add_child(n)
	for f in 120:
		if fast:
			RenderingServer.render_loop_enabled = f >= 114
		await process_frame
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	n.queue_free()
	for i in 3:
		await process_frame
	return img

func _run() -> void:
	var a := await _shot(false)
	var a2 := await _shot(false)
	var b := await _shot(true)
	var out := CliArgs.get_string("out", "/tmp")
	a.save_png(out + "/particles_full.png")
	b.save_png(out + "/particles_shotfast.png")
	var d1 := 0
	var d2 := 0
	var lit_a := 0
	var lit_b := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != a2.get_pixel(x, y):
				d1 += 1
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				d2 += 1
			if a.get_pixel(x, y).get_luminance() > 0.3:
				lit_a += 1
			if b.get_pixel(x, y).get_luminance() > 0.3:
				lit_b += 1
	print("QA-FAST full vs full (same seed): %d pixels different; full vs render loop off for 114 of 120 frames: %d pixels different; particle pixels %d (full) / %d (fast)" % [d1, d2, lit_a, lit_b])
	quit(0)
