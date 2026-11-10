extends "res://probe_base.gd"

func test_base() -> void:
	base_scene()
	await variant("noshadow")

# DirectionalLight3D shadows: modes, split counts, distance, filter quality, atlas size.
func test_dirshadow() -> void:
	base_scene()
	await variant("0_off")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	await variant("1_ortho_150m")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	await variant("2_pssm2_150m")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	await variant("3_pssm4_150m")
	sun.directional_shadow_blend_splits = true
	await variant("4_pssm4_150m_blend")
	sun.directional_shadow_blend_splits = false
	sun.directional_shadow_max_distance = 400.0
	await variant("5_pssm4_400m")
	sun.directional_shadow_max_distance = 150.0
	# filter quality 0 = hard .. 5 = soft ultra
	for q: int in [0, 1, 3, 5]:
		RenderingServer.directional_soft_shadow_filter_set_quality(q)
		await variant("6_pssm4_quality%d" % q)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	for sz: int in [1024, 2048, 8192]:
		RenderingServer.directional_shadow_atlas_set_size(sz, false)
		await variant("7_pssm4_atlas%d" % sz)
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	await variant("8_pssm4_atlas4096_16bit")
	RenderingServer.directional_shadow_atlas_set_size(4096, false)
	# debug view of the PSSM splits
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_PSSM_SPLITS
	await variant("9_debug_pssm_splits", false)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DIRECTIONAL_SHADOW_ATLAS
	await variant("9_debug_shadow_atlas", false)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	# low sun (long shadows) and a second directional light
	sun.rotation_degrees = Vector3(-9.0, -70.0, 0.0)
	await variant("10_low_sun")
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50.0, 120.0, 0.0)
	moon.light_color = Color(0.5, 0.6, 1.0)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	world.add_child(moon)
	await variant("11_two_dir_lights_shadows")

func px(img: Image, x: int, y: int) -> String:
	var c := img.get_pixel(x, y)
	return "(%d,%d,%d)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]

func sample(img: Image) -> String:
	return "grass=%s road=%s car=%s sky=%s" % [px(img, 1200, 400), px(img, 640, 690), px(img, 640, 570), px(img, 640, 50)]

# Does enabling the sun shadow change the brightness of lit surfaces? (multi-pass + in-shader tonemap)
func test_shadowbright() -> void:
	base_scene()
	sun.directional_shadow_max_distance = 150.0
	for tm: int in [Environment.TONE_MAPPER_LINEAR, Environment.TONE_MAPPER_FILMIC, Environment.TONE_MAPPER_ACES, Environment.TONE_MAPPER_AGX]:
		for glow: bool in [false, true]:
			for sh: bool in [false, true]:
				env.tonemap_mode = tm
				env.glow_enabled = glow
				env.glow_intensity = 0.0001
				sun.shadow_enabled = sh
				var img: Image = await variant("tm%d_glow%d_shadow%d" % [tm, int(glow), int(sh)], false)
				note("tm%d_glow%d_shadow%d" % [tm, int(glow), int(sh)], sample(img))
	env.glow_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	get_viewport().use_hdr_2d = true
	for sh: bool in [false, true]:
		sun.shadow_enabled = sh
		var img2: Image = await variant("tm2_hdr2d_shadow%d" % int(sh), false)
		note("tm2_hdr2d_shadow%d" % int(sh), sample(img2))
	get_viewport().use_hdr_2d = false

# Controlled energy check: grey plane (albedo 0.5) lit head-on, no ambient, linear tonemap.
func test_energy() -> void:
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	cam.position = Vector3(0, 10, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	world.add_child(cam)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0, 0, 0)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	wenv = WorldEnvironment.new()
	wenv.environment = env
	world.add_child(wenv)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-90, 0, 0)
	sun.light_energy = 0.5
	sun.light_specular = 0.0
	world.add_child(sun)
	var m := mat(Color(0.5, 0.5, 0.5), 1.0, 0.0)
	plane(world, Vector2(30, 30), Vector3.ZERO, m)
	box(world, Vector3(1, 1, 1), Vector3(3, 0.5, 0), mat(Color(0.5, 0.5, 0.5), 1.0))
	for sh: bool in [false, true]:
		for hdr: bool in [false, true]:
			for glow: bool in [false, true]:
				sun.shadow_enabled = sh
				get_viewport().use_hdr_2d = hdr
				env.glow_enabled = glow
				env.glow_intensity = 0.0001
				var img: Image = await variant("shadow%d_hdr%d_glow%d" % [int(sh), int(hdr), int(glow)], false)
				note("shadow%d_hdr%d_glow%d" % [int(sh), int(hdr), int(glow)], "plane=%s (expected 137 for linear 0.25; 188 = doubled)" % px(img, 200, 200))
	get_viewport().use_hdr_2d = false

func test_bisect() -> void:
	base_scene()
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sun.directional_shadow_max_distance = 150.0
	await frames(30)
	var cases: Array[String] = ["default", "ambient_color", "no_reflection", "no_specular", "sun_overhead", "bg_color"]
	for c: String in cases:
		match c:
			"ambient_color":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = Color(0.3, 0.3, 0.3)
			"no_reflection":
				env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			"no_specular":
				sun.light_specular = 0.0
			"sun_overhead":
				sun.rotation_degrees = Vector3(-90, 0, 0)
			"bg_color":
				env.background_mode = Environment.BG_COLOR
				env.background_color = Color(0.3, 0.4, 0.6)
		for sh: bool in [false, true, false, true]:
			sun.shadow_enabled = sh
			var img: Image = await variant("%s_shadow%d" % [c, int(sh)], false, 6)
			note("%s_shadow%d" % [c, int(sh)], sample(img))

func lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

func pxlin(img: Image, x: int, y: int) -> String:
	var c := img.get_pixel(x, y)
	return "srgb8=(%d,%d,%d) lin=(%.4f,%.4f,%.4f)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0)), lin(c.r), lin(c.g), lin(c.b)]

# Additivity of ambient + direct light with and without shadows (controlled).
func test_additive() -> void:
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	cam.position = Vector3(0, 10, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	world.add_child(cam)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	wenv = WorldEnvironment.new()
	wenv.environment = env
	world.add_child(wenv)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-90, 0, 0)
	sun.light_specular = 0.0
	world.add_child(sun)
	plane(world, Vector2(30, 30), Vector3.ZERO, mat(Color(0.5, 0.5, 0.5), 1.0, 0.0))
	for mode: String in ["plain", "glow", "hdr2d"]:
		env.glow_enabled = mode == "glow"
		env.glow_intensity = 0.0001
		get_viewport().use_hdr_2d = mode == "hdr2d"
		for c: Array in [[0.4, 0.0, false], [0.0, 0.5, false], [0.0, 0.5, true], [0.4, 0.5, false], [0.4, 0.5, true]]:
			var a: float = c[0]
			env.ambient_light_color = Color(a, a, a)
			env.ambient_light_energy = 1.0
			sun.light_energy = c[1]
			sun.visible = float(c[1]) > 0.0
			sun.shadow_enabled = c[2]
			var img: Image = await variant("%s_amb%.1f_sun%.1f_sh%d" % [mode, a, float(c[1]), int(bool(c[2]))], false)
			note("%s_amb%.1f_sun%.1f_sh%d" % [mode, a, float(c[1]), int(bool(c[2]))], pxlin(img, 200, 200))
	get_viewport().use_hdr_2d = false

# Positional lights at night: headlights (spots) + street lamps (omnis), per-object and total limits.
func test_positional() -> void:
	base_scene(true, true)
	night()
	await variant("0_night_no_lights")
	var h1 := spot(world, Vector3(-0.6, 0.7, -2.3), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	var h2 := spot(world, Vector3(0.6, 0.7, -2.3), Vector3(0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	await variant("1_headlights_2spots")
	h1.shadow_enabled = true
	h2.shadow_enabled = true
	await variant("2_headlights_2spots_shadows")
	h1.shadow_enabled = false
	h2.shadow_enabled = false
	# street lamps: one omni every 25 m, alternating sides; the road is ONE mesh (1400 m)
	var lamps: Array[OmniLight3D] = []
	for i: int in range(64):
		var side: float = -8.5 if i % 2 == 0 else 8.5
		var p := Vector3(side, 7.0, -10.0 - float(i) * 12.5)
		cyl(world, 0.08, 7.0, Vector3(side, 3.5, p.z), mat(Color(0.3, 0.3, 0.32), 0.5, 0.8))
		sphere(world, 0.25, p, emat(Color(1.0, 0.75, 0.4), 4.0))
		var l := omni(world, p, 22.0, 3.0)
		l.visible = false
		lamps.append(l)
	for n: int in [4, 8, 9, 16, 32, 33, 64]:
		for i: int in range(64):
			lamps[i].visible = i < n
		await variant("3_omni_lamps_%02d" % n)
	# one shadowed omni
	for i: int in range(64):
		lamps[i].visible = i < 8
	lamps[1].shadow_enabled = true
	await variant("4_omni8_one_shadow")
	for i: int in range(8):
		lamps[i].shadow_enabled = true
	await variant("5_omni8_all_shadows")
	note("max_lights_per_object", ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object"))
	note("max_renderable_lights", ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights"))

# Street lamps over a chunked road (25 m pieces): every chunk has <= 8 lights in range.
func test_chunked() -> void:
	base_scene(true, true)
	night()
	# replace nothing: add a chunked road + ground slightly above the single-mesh ones
	var road_m := mat(Color(0.13, 0.13, 0.14), 0.75)
	var grass_m := mat(Color(0.22, 0.42, 0.16), 0.95)
	for i: int in range(56):
		var z: float = 12.5 - float(i) * 25.0
		plane(world, Vector2(15.0, 25.0), Vector3(0, 0.02, z), road_m)
		plane(world, Vector2(60.0, 25.0), Vector3(-37.5, 0.02, z), grass_m)
		plane(world, Vector2(60.0, 25.0), Vector3(37.5, 0.02, z), grass_m)
	var lamps: Array[OmniLight3D] = []
	for i: int in range(64):
		var side: float = -8.5 if i % 2 == 0 else 8.5
		var p := Vector3(side, 7.0, -10.0 - float(i) * 12.5)
		cyl(world, 0.08, 7.0, Vector3(side, 3.5, p.z), mat(Color(0.3, 0.3, 0.32), 0.5, 0.8))
		sphere(world, 0.25, p, emat(Color(1.0, 0.75, 0.4), 4.0))
		lamps.append(omni(world, p, 22.0, 3.0))
	spot(world, Vector3(-0.6, 0.7, -2.3), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	spot(world, Vector3(0.6, 0.7, -2.3), Vector3(0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	note("max_lights_per_object", ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object"))
	note("max_renderable_lights", ProjectSettings.get_setting("rendering/limits/opengl/max_renderable_lights"))
	await variant("lamps64_chunked_road")
	for i: int in range(64):
		lamps[i].visible = i < 30
	await variant("lamps30_chunked_road")
	for i: int in range(64):
		lamps[i].visible = false
	await variant("lamps0_chunked_road")
