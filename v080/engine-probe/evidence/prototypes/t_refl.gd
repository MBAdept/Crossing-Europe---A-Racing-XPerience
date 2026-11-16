extends "res://probe_base.gd"

func setup_wet() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.rotation_degrees = Vector3(-30.0, 160.0, 0.0)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	sm.set_shader_parameter("use_time", 0.0)
	env.sky.sky_material = sm
	# wet road patch (chunked 25 m pieces), dark and smooth
	var wet := mat(Color(0.05, 0.05, 0.055), 0.07, 0.0)
	for i: int in range(10):
		plane(world, Vector2(15.0, 25.0), Vector3(0, 0.02, 2.5 - float(i) * 25.0), wet)
	# colourful objects to be reflected
	box(world, Vector3(6, 5, 1), Vector3(-10.5, 2.5, -20), mat(Color(0.9, 0.1, 0.1), 0.6))
	box(world, Vector3(6, 5, 1), Vector3(10.5, 2.5, -28), mat(Color(0.1, 0.2, 0.9), 0.6))
	sphere(world, 0.8, Vector3(2.5, 3.2, -12.0), emat(Color(1.0, 0.8, 0.2), 5.0))

func test_reflections() -> void:
	setup_wet()
	await variant("0_sky_radiance_reflection", true, 14)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	await variant("1_reflections_disabled", true, 8)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var probe := ReflectionProbe.new()
	probe.size = Vector3(70, 30, 260)
	probe.position = Vector3(0, 2.0, -100)
	probe.origin_offset = Vector3(0, 0.0, 95.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	world.add_child(probe)
	await variant("2_probe_once", true, 20)
	probe.box_projection = true
	await variant("3_probe_once_boxprojection", true, 20)
	probe.enable_shadows = true
	await variant("3_probe_once_boxprojection_shadows", true, 20)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	await variant("4_probe_always", true, 20)
	note("reflection_atlas_size", ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_size"))
	note("reflection_atlas_count", ProjectSettings.get_setting("rendering/reflections/reflection_atlas/reflection_count"))
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = false
	# night with probe: lamps reflected?
	night()
	env.sky.sky_material.set_shader_parameter("night", 1.0)
	for i: int in range(16):
		var side: float = -8.5 if i % 2 == 0 else 8.5
		var p := Vector3(side, 7.0, -10.0 - float(i) * 12.5)
		sphere(world, 0.35, p, emat(Color(1.0, 0.75, 0.4), 8.0))
		if i < 8:
			omni(world, p, 22.0, 3.0)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	env.glow_enabled = true
	await variant("5_night_probe_always_glow", true, 20)
	probe.visible = false
	await variant("6_night_no_probe_glow", true, 12)

# Does an UPDATE_ALWAYS probe follow scene changes (moving object, sky change, probe moved)?
func test_probe_update() -> void:
	setup_wet()
	var probe := ReflectionProbe.new()
	probe.size = Vector3(70, 30, 260)
	probe.position = Vector3(0, 2.0, -100)
	probe.origin_offset = Vector3(0, 0.0, 95.0)
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	world.add_child(probe)
	var mover := sphere(world, 1.2, Vector3(-4.0, 3.0, -14.0), emat(Color(0.1, 1.0, 0.2), 6.0))
	var a: Image = await variant("0_always_t0", true, 20)
	mover.position = Vector3(4.0, 3.0, -14.0)
	var b: Image = await variant("1_always_object_moved", true, 20)
	env.sky.sky_material.set_shader_parameter("top_color", Color(0.8, 0.2, 0.1))
	env.sky.sky_material.set_shader_parameter("horizon_color", Color(1.0, 0.6, 0.2))
	var c: Image = await variant("2_always_sky_changed_red", true, 30)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	mover.position = Vector3(0.0, 5.0, -20.0)
	var d: Image = await variant("3_once_object_moved_again", true, 20)
	# moving the probe re-triggers an UPDATE_ONCE capture?
	probe.position = Vector3(0, 2.0, -100.5)
	var e: Image = await variant("4_once_probe_moved", true, 20)
	note("diff_once_after_object_move_vs_probe_moved", diff(d, e))

func px(img: Image, x: int, y: int) -> String:
	var c := img.get_pixel(x, y)
	return "(%d,%d,%d)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]

func quick() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

# UPDATE_ALWAYS over many frames; UPDATE_ONCE re-triggered by moving the probe: latency and cost.
func test_probe_update2() -> void:
	setup_wet()
	var probe := ReflectionProbe.new()
	probe.size = Vector3(70, 30, 260)
	probe.position = Vector3(0, 2.0, -100)
	probe.origin_offset = Vector3(0, 0.0, 95.0)
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	world.add_child(probe)
	for i: int in range(6):
		await frames(20)
		var im: Image = await quick()
		note("always_after_%d_frames_road_px" % ((i + 1) * 20), px(im, 640, 690) + " chrome=" + px(im, 410, 520))
	await variant("0_always_after_120_frames", false, 1)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	var seq: Array[String] = []
	for i: int in range(10):
		var im2: Image = await quick()
		seq.append("%s dc=%d prim=%d" % [px(im2, 640, 690), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))])
	note("after_switch_to_once_per_frame", seq)
	await variant("1_once", false, 4)
	# change the sky, then re-trigger by moving the probe
	env.sky.sky_material.set_shader_parameter("top_color", Color(0.8, 0.2, 0.1))
	env.sky.sky_material.set_shader_parameter("horizon_color", Color(1.0, 0.6, 0.2))
	await frames(10)
	var im3: Image = await quick()
	note("once_sky_changed_not_retriggered_road_px", px(im3, 640, 690))
	probe.position += Vector3(0, 0, -0.01)
	var seq2: Array[String] = []
	for i: int in range(12):
		var im4: Image = await quick()
		seq2.append("%s dc=%d prim=%d" % [px(im4, 640, 690), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))])
	note("after_probe_moved_per_frame", seq2)
	await variant("2_once_retriggered_red_sky", false, 2)
	# restrict what the probe renders: cull mask (layer 2 only = nothing but sky) and LOD
	probe.cull_mask = 2
	probe.position += Vector3(0, 0, -0.01)
	var seq3: Array[String] = []
	for i: int in range(12):
		var im5: Image = await quick()
		seq3.append("%s dc=%d prim=%d" % [px(im5, 640, 690), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))])
	note("after_probe_moved_cullmask_sky_only_per_frame", seq3)
	await variant("3_once_cullmask_sky_only", false, 2)

# Custom screen-space reflections on a wet road (overlay with depth + screen texture).
func test_wet_ssr() -> void:
	setup_wet()
	night()
	env.sky.sky_material.set_shader_parameter("night", 1.0)
	env.glow_enabled = true
	env.glow_intensity = 1.2
	for i: int in range(16):
		var side: float = -8.5 if i % 2 == 0 else 8.5
		var p := Vector3(side, 7.0, -10.0 - float(i) * 12.5)
		cyl(world, 0.08, 7.0, Vector3(side, 3.5, p.z), mat(Color(0.3, 0.3, 0.32), 0.5, 0.8))
		sphere(world, 0.35, p, emat(Color(1.0, 0.75, 0.4), 8.0))
		if i < 8:
			omni(world, p, 22.0, 3.0)
	spot(world, Vector3(-0.6, 0.7, -2.3), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	spot(world, Vector3(0.6, 0.7, -2.3), Vector3(0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	await variant("0_wet_night_sky_radiance_only", true, 14)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://wet_ssr.gdshader")
	var overlays: Array[MeshInstance3D] = []
	for i: int in range(10):
		var o := plane(world, Vector2(15.0, 25.0), Vector3(0, 0.03, 2.5 - float(i) * 25.0), sm)
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlays.append(o)
	await variant("1_wet_night_custom_ssr_overlay", true, 8)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await variant("2_wet_night_custom_ssr_msaa4x", true, 6)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	# day
	sun.light_energy = 1.3
	sun.light_color = Color(1, 1, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.sky.sky_material.set_shader_parameter("night", 0.0)
	await variant("3_wet_day_custom_ssr", true, 14)
