extends "res://probe_base.gd"

func soft_dot_texture(size: int = 64) -> ImageTexture:
	var im := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(im)

func particle_mat(color: Color, additive: bool, tex: Texture2D = null, billboard: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	if tex != null:
		m.albedo_texture = tex
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func make_rain(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.preprocess = 2.0
	p.visibility_aabb = AABB(Vector3(-30, -5, -60), Vector3(60, 30, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25, 0.5, 35)
	pm.direction = Vector3(0.15, -1, 0.1)
	pm.spread = 2.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.9)
	q.material = particle_mat(Color(0.75, 0.8, 0.9, 0.45), false, null, false)
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.position = Vector3(0, 16, -22)
	return p

func make_snow(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-30, -20, -60), Vector3(60, 30, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25, 0.5, 35)
	pm.direction = Vector3(0.2, -1, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -0.4, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = particle_mat(Color(1, 1, 1, 0.9), false, soft_dot_texture())
	p.draw_pass_1 = q
	p.position = Vector3(0, 14, -22)
	return p

func make_spray(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.2
	p.preprocess = 1.5
	p.visibility_aabb = AABB(Vector3(-6, -1, -4), Vector3(12, 6, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.9, 0.1, 0.3)
	pm.direction = Vector3(0, 0.35, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.5))
	gr.set_color(1, Color(1, 1, 1, 0.0))
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pm.color_ramp = grt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	q.material = particle_mat(Color(0.8, 0.83, 0.88, 0.5), false, soft_dot_texture())
	p.draw_pass_1 = q
	return p

func make_sparks(amount: int, trails: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.8
	p.preprocess = 0.6
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 6, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(-0.6, 0.5, 0.6)
	pm.spread = 30.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	pm.collision_bounce = 0.5
	p.process_material = pm
	if trails:
		p.trail_enabled = true
		p.trail_lifetime = 0.12
		var rm := RibbonTrailMesh.new()
		rm.size = 0.04
		rm.sections = 4
		var tm := particle_mat(Color(1.0, 0.7, 0.2, 1.0), true, null, false)
		tm.use_particle_trails = true
		tm.emission_enabled = true
		rm.material = tm
		p.draw_pass_1 = rm
	else:
		var q := QuadMesh.new()
		q.size = Vector2(0.03, 0.35)
		q.material = particle_mat(Color(1.0, 0.7, 0.2, 1.0), true, null, false)
		p.draw_pass_1 = q
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	return p

func proc_ms(n: int = 20) -> float:
	var acc: Array[float] = []
	for i: int in range(n):
		await get_tree().process_frame
		acc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	acc.sort()
	return snappedf(acc[n / 2], 0.001)

func test_particles() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.55, 0.6, 0.66)
	sun.light_energy = 0.5
	note("proc_ms_no_particles", await proc_ms())
	await variant("0_no_particles")
	var rain := make_rain(8000)
	world.add_child(rain)
	var spray := make_spray(300)
	spray.position = Vector3(0, 0.3, 2.3)
	world.add_child(spray)
	await variant("1_gpu_rain8000_spray300", true, 30)
	note("proc_ms_gpu_rain8000_spray300", await proc_ms())
	rain.amount = 30000
	await variant("1_gpu_rain30000", true, 30)
	rain.queue_free()
	spray.queue_free()
	var snow := make_snow(6000)
	world.add_child(snow)
	await variant("2_gpu_snow6000_turbulence", true, 30)
	note("proc_ms_gpu_snow6000", await proc_ms())
	snow.queue_free()
	var sparks := make_sparks(150, false)
	sparks.position = Vector3(1.5, 0.3, 1.5)
	world.add_child(sparks)
	var col := GPUParticlesCollisionBox3D.new()
	col.size = Vector3(40, 1, 40)
	col.position = Vector3(0, -0.5, 0)
	world.add_child(col)
	await variant("3_gpu_sparks150_collision_box", true, 30)
	sparks.queue_free()
	var sparks2 := make_sparks(150, true)
	sparks2.position = Vector3(1.5, 0.3, 1.5)
	world.add_child(sparks2)
	await variant("4_gpu_sparks150_trails", true, 30)
	sparks2.queue_free()
	# CPU particles: convert the same systems
	var grain := make_rain(8000)
	var crain := CPUParticles3D.new()
	crain.convert_from_particles(grain)
	crain.position = Vector3(0, 16, -22)
	world.add_child(crain)
	var gspray := make_spray(300)
	var cspray := CPUParticles3D.new()
	cspray.convert_from_particles(gspray)
	cspray.position = Vector3(0, 0.3, 2.3)
	world.add_child(cspray)
	await variant("5_cpu_rain8000_spray300", true, 30)
	note("proc_ms_cpu_rain8000_spray300", await proc_ms())
	grain.free()
	gspray.free()
	crain.queue_free()
	cspray.queue_free()
	var gsnow := make_snow(6000)
	var csnow := CPUParticles3D.new()
	csnow.convert_from_particles(gsnow)
	csnow.position = Vector3(0, 14, -22)
	world.add_child(csnow)
	await variant("6_cpu_snow6000", true, 30)
	note("proc_ms_cpu_snow6000", await proc_ms())
	gsnow.free()

func test_snow() -> void:
	base_scene(true, true)
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.55, 0.6, 0.66)
	sun.light_energy = 0.5
	var ref: Image = await variant("0_ref", false)
	var snow := make_snow(6000)
	world.add_child(snow)
	var a: Image = await variant("1_gpu_snow_turbulence", false, 40)
	note("turbulence_diff_vs_ref", diff(ref, a))
	var pm: ParticleProcessMaterial = snow.process_material
	pm.turbulence_enabled = false
	snow.restart()
	var b: Image = await variant("2_gpu_snow_no_turbulence", false, 40)
	note("no_turbulence_diff_vs_ref", diff(ref, b))
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.1
	snow.restart()
	var c: Image = await variant("3_gpu_snow_weak_turbulence", false, 40)
	note("weak_turbulence_diff_vs_ref", diff(ref, c))
	# particle collision: sparks dropping on a collision box (do they stop at the road?)
	snow.queue_free()
	var sparks := make_sparks(200, false)
	sparks.position = Vector3(0.0, 3.0, -4.0)
	var spm: ParticleProcessMaterial = sparks.process_material
	spm.direction = Vector3(0, -1, 0)
	spm.spread = 25.0
	spm.initial_velocity_min = 1.0
	spm.initial_velocity_max = 3.0
	sparks.lifetime = 3.0
	sparks.preprocess = 3.0
	world.add_child(sparks)
	var d: Image = await variant("4_sparks_no_collider", false, 40)
	var col := GPUParticlesCollisionBox3D.new()
	col.size = Vector3(40, 2, 40)
	col.position = Vector3(0, -1.0, 0)
	world.add_child(col)
	sparks.restart()
	var e: Image = await variant("5_sparks_collider_box", false, 60)
	note("collider_diff", diff(d, e))

# ---------------------------------------------------------------- MultiMesh + foliage

func tree_texture(size: int = 128) -> ImageTexture:
	# Procedural tree silhouette with alpha (crown blobs + trunk).
	var im := Image.create(size, size, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.1, 0.3, 0.08, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var blobs: Array[Vector3] = []
	for i: int in range(26):
		blobs.append(Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.08, 0.62), rng.randf_range(0.07, 0.16)))
	for y: int in range(size):
		for x: int in range(size):
			var u: float = (float(x) + 0.5) / float(size)
			var v: float = (float(y) + 0.5) / float(size)
			var a: float = 0.0
			var shade: float = 0.0
			for b: Vector3 in blobs:
				var d: float = Vector2(u - b.x, v - b.y).length()
				if d < b.z:
					a = 1.0
					shade = maxf(shade, 1.0 - d / b.z)
			var col := Color(0.10 + 0.10 * shade, 0.30 + 0.25 * shade, 0.08 + 0.06 * shade, a)
			if a < 0.5 and absf(u - 0.5) < 0.035 and v > 0.5:
				col = Color(0.3, 0.2, 0.12, 1.0)
			im.set_pixel(x, y, col)
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

func cross_quad_mesh(w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ang: float in [0.0, PI * 0.5]:
		var dx := Vector3(cos(ang), 0, sin(ang)) * w * 0.5
		var n := Vector3(-sin(ang), 0, cos(ang))
		var p0 := -dx
		var p1 := dx
		var p2 := dx + Vector3(0, h, 0)
		var p3 := -dx + Vector3(0, h, 0)
		for tri: Array in [[p0, p1, p2, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [p0, p2, p3, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)]]:
			for k: int in range(3):
				st.set_normal(Vector3.UP.lerp(n, 0.3).normalized())
				st.set_uv(tri[3 + k])
				st.add_vertex(tri[k])
	return st.commit()

func foliage_mat(tex: Texture2D, mode: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	m.vertex_color_use_as_albedo = true
	match mode:
		"scissor":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		"hash":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		"prepass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		"blend":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func make_forest(count: int, mode: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cross_quad_mesh(6.0, 8.0)
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i: int in range(count):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(11.0, 160.0)
		var z: float = rng.randf_range(-900.0, 10.0)
		var s: float = rng.randf_range(0.7, 1.5)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0, z))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, Color(rng.randf_range(0.7, 1.0), rng.randf_range(0.8, 1.0), rng.randf_range(0.6, 0.9)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = foliage_mat(tree_texture(), mode)
	return mmi

func empty_scene() -> void:
	# base scene without the sphere trees (lighter): ground, road, cars only
	base_scene(true, true)
	for c: Node in world.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			if mi.mesh is SphereMesh or (mi.mesh is CylinderMesh and mi.position.y > 1.0 and absf(mi.position.x) > 10.0):
				mi.queue_free()

func test_multimesh() -> void:
	empty_scene()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	await variant("0_no_forest")
	for mode: String in ["scissor", "hash", "prepass", "blend"]:
		var f := make_forest(5000, mode)
		world.add_child(f)
		await variant("1_forest5000_%s" % mode)
		f.queue_free()
	var f2 := make_forest(20000, "scissor")
	world.add_child(f2)
	await variant("2_forest20000_scissor")
	f2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await variant("2_forest20000_scissor_no_shadow_cast")
	f2.multimesh.visible_instance_count = 2000
	await variant("3_visible_instance_count_2000")
	f2.queue_free()
	# cost of updating instance transforms from GDScript (CPU, main thread)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cross_quad_mesh(6.0, 8.0)
	mm.instance_count = 2000
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	world.add_child(mmi)
	var t0 := Time.get_ticks_usec()
	for rep: int in range(20):
		for i: int in range(2000):
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(i % 50) * 3.0, 0.0, -float(i / 50) * 3.0 - float(rep))))
	var t1 := Time.get_ticks_usec()
	note("set_instance_transform_2000_us_per_frame", float(t1 - t0) / 20.0)
	var buf := PackedFloat32Array()
	buf.resize(2000 * 12)
	t0 = Time.get_ticks_usec()
	for rep: int in range(20):
		for i: int in range(2000):
			var o := i * 12
			buf[o] = 1.0
			buf[o + 3] = float(i % 50) * 3.0
			buf[o + 5] = 1.0
			buf[o + 7] = 0.0
			buf[o + 10] = 1.0
			buf[o + 11] = -float(i / 50) * 3.0 - float(rep)
		mm.buffer = buf
	t1 = Time.get_ticks_usec()
	note("buffer_bulk_update_2000_us_per_frame", float(t1 - t0) / 20.0)
	t0 = Time.get_ticks_usec()
	for rep: int in range(20):
		mm.buffer = buf
	t1 = Time.get_ticks_usec()
	note("buffer_assign_only_2000_us_per_frame", float(t1 - t0) / 20.0)

# Alpha modes on one textured quad each (close-up): scissor, hash, depth pre-pass, blend, scissor + alpha-to-coverage.
func test_alpha_modes() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	var tex := tree_texture(256)
	var x := -7.0
	var q := QuadMesh.new()
	q.size = Vector2(3.4, 3.4)
	for mode: String in ["scissor", "hash", "prepass", "blend", "a2c"]:
		var m := foliage_mat(tex, "scissor" if mode == "a2c" else mode)
		m.vertex_color_use_as_albedo = false
		if mode == "a2c":
			m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			m.alpha_antialiasing_edge = 0.3
		add_mesh(world, q, Vector3(x, 1.9, -5.0), m)
		x += 3.5
	var a: Image = await variant("0_scissor_hash_prepass_blend_a2c_no_msaa")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await variant("1_same_with_msaa4x")
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
