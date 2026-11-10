extends "res://probe_base.gd"

func lamps(n: int) -> void:
	for i: int in range(n):
		var side: float = -8.5 if i % 2 == 0 else 8.5
		var p := Vector3(side, 7.0, -10.0 - float(i) * 12.5)
		cyl(world, 0.08, 7.0, Vector3(side, 3.5, p.z), mat(Color(0.3, 0.3, 0.32), 0.5, 0.8))
		sphere(world, 0.25, p, emat(Color(1.0, 0.75, 0.4), 6.0))
		if i < 8:
			omni(world, p, 22.0, 3.0)

# Emissive materials + glow at night.
func test_glow() -> void:
	base_scene(true, true)
	night()
	lamps(40)
	spot(world, Vector3(-0.6, 0.7, -2.3), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	spot(world, Vector3(0.6, 0.7, -2.3), Vector3(0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	await variant("0_glow_off")
	env.glow_enabled = true
	await variant("1_glow_default")
	env.glow_intensity = 1.5
	env.glow_bloom = 0.15
	await variant("2_glow_int1.5_bloom0.15")
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.6
	env.glow_hdr_scale = 2.0
	env.glow_intensity = 2.0
	await variant("3_glow_thresh0.6_int2")
	# properties documented as "no effect" in Compatibility
	var before: Image = last_img
	env.glow_strength = 2.0
	env.set_glow_level(1, 1.0)
	env.set_glow_level(6, 1.0)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_normalized = true
	var after: Image = await variant("4_glow_levels_strength_blendmode", false)
	note("glow_levels_strength_blendmode_diff", diff(before, after))
	# day scene with glow: sun reflections / bright sky
	env.glow_enabled = false

func test_glow_day() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	await variant("0_day_glow_off")
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_hdr_threshold = 1.0
	await variant("1_day_glow_thr1.0")
	env.glow_bloom = 0.2
	await variant("2_day_glow_bloom0.2")

# Tonemappers + exposure/white + adjustments + colour correction.
func test_tonemap() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var names: Array[String] = ["linear", "reinhard", "filmic", "aces", "agx"]
	for tm: int in range(5):
		env.tonemap_mode = tm
		await variant("0_tonemap_%s" % names[tm])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.6
	await variant("1_filmic_exposure1.6", false)
	env.tonemap_exposure = 1.0
	env.tonemap_white = 4.0
	await variant("1_filmic_white4", false)
	env.tonemap_white = 1.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.1
	env.adjustment_contrast = 1.25
	env.adjustment_saturation = 1.4
	await variant("2_adjust_b1.1_c1.25_s1.4")
	env.adjustment_saturation = 0.0
	await variant("2_adjust_saturation0", false)
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	env.adjustment_brightness = 1.0
	# 1D LUT (GradientTexture1D): warm tint
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.0, 0.1))
	g.set_color(1, Color(1.0, 0.92, 0.75))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	env.adjustment_color_correction = gt
	await variant("3_colorcorrection_1dlut")
	# 3D LUT (ImageTexture3D 16^3): teal-orange style grade
	var imgs: Array[Image] = []
	var n := 16
	for b: int in range(n):
		var im := Image.create(n, n, false, Image.FORMAT_RGB8)
		for gi: int in range(n):
			for r: int in range(n):
				var c := Color(float(r) / 15.0, float(gi) / 15.0, float(b) / 15.0)
				var lum: float = c.get_luminance()
				var graded := Color(c.r * 1.08 + (lum - 0.5) * 0.12, c.g * 1.0, c.b * 0.92 - (lum - 0.5) * 0.18 + 0.04)
				im.set_pixel(r, gi, graded.clamp())
		imgs.append(im)
	var t3 := ImageTexture3D.new()
	t3.create(Image.FORMAT_RGB8, n, n, n, false, imgs)
	env.adjustment_color_correction = t3
	await variant("3_colorcorrection_3dlut")
	env.adjustment_color_correction = null
	env.adjustment_enabled = false

# Depth fog, height fog, sun scatter, aerial perspective, sky affect; volumetric fog (expected: no effect).
func test_fog() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	await variant("0_fog_off")
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.62, 0.68, 0.75)
	env.fog_density = 0.01
	await variant("1_exp_density0.01")
	env.fog_density = 0.03
	await variant("1_exp_density0.03", false)
	env.fog_sky_affect = 0.2
	await variant("1_exp_density0.03_skyaffect0.2", false)
	env.fog_sky_affect = 1.0
	env.fog_density = 0.004
	env.fog_height = 6.0
	env.fog_height_density = 0.25
	await variant("2_height_fog_h6_d0.25")
	env.fog_height_density = 0.0
	env.fog_density = 0.01
	env.fog_sun_scatter = 0.6
	sun.rotation_degrees = Vector3(-8.0, 172.0, 0.0)
	await variant("3_sun_scatter0.6_low_sun_ahead")
	env.fog_sun_scatter = 0.0
	env.fog_aerial_perspective = 1.0
	await variant("4_aerial_perspective1.0")
	env.fog_aerial_perspective = 0.0
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 220.0
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	await variant("5_depth_mode_30_220")
	env.fog_depth_curve = 2.5
	await variant("5_depth_mode_30_220_curve2.5", false)
	env.fog_enabled = false
	var a: Image = await variant("6_no_fog_ref", false)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.08
	var b: Image = await variant("6_volumetric_fog_on", false)
	note("volumetric_fog_diff", diff(a, b))
	env.volumetric_fog_enabled = false
	var fv := FogVolume.new()
	fv.size = Vector3(40, 10, 40)
	fv.position = Vector3(0, 3, -30)
	var fm := FogMaterial.new()
	fm.density = 2.0
	fv.material = fm
	world.add_child(fv)
	var c: Image = await variant("6_fogvolume_node", false)
	note("fogvolume_diff", diff(a, c))

# Screen-space effects: SSAO (documented as supported), SSR, SSIL, SDFGI (documented as unsupported).
func test_ss() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	# geometry with creases: a wall + boxes near the camera
	box(world, Vector3(4, 3, 0.4), Vector3(-5.5, 1.5, -6), mat(Color(0.8, 0.8, 0.78), 0.9))
	box(world, Vector3(1, 1, 1), Vector3(-4.8, 0.5, -5.2), mat(Color(0.8, 0.8, 0.78), 0.9))
	box(world, Vector3(0.8, 1.6, 0.8), Vector3(-6.2, 0.8, -5.2), mat(Color(0.8, 0.8, 0.78), 0.9))
	var ref: Image = await variant("0_ref")
	env.ssao_enabled = true
	var a: Image = await variant("1_ssao_default")
	note("ssao_diff", diff(ref, a))
	env.ssao_intensity = 4.0
	env.ssao_radius = 2.0
	var a2: Image = await variant("1_ssao_int4_radius2")
	note("ssao_strong_diff", diff(ref, a2))
	for q: int in range(5):
		RenderingServer.environment_set_ssao_quality(q, true, 0.5, 2, 50.0, 300.0)
		var aq: Image = await variant("2_ssao_quality%d" % q)
		note("ssao_quality%d_diff_vs_ref" % q, diff(ref, aq))
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_SSAO
	await variant("2_ssao_debugdraw", false)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	env.ssao_enabled = false
	var ref2: Image = await variant("3_ref_again", false)
	env.ssr_enabled = true
	var b: Image = await variant("3_ssr_on", false)
	note("ssr_diff", diff(ref2, b))
	env.ssr_enabled = false
	env.ssil_enabled = true
	var c: Image = await variant("3_ssil_on", false)
	note("ssil_diff", diff(ref2, c))
	env.ssil_enabled = false
	env.sdfgi_enabled = true
	var d: Image = await variant("3_sdfgi_on", false)
	note("sdfgi_diff", diff(ref2, d))
	env.sdfgi_enabled = false

func px(img: Image, x: int, y: int) -> String:
	var c := img.get_pixel(x, y)
	return "(%d,%d,%d)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]

# BG_COLOR background with and without the post path (glow / adjustments).
func test_bgcolor() -> void:
	base_scene(false, true)
	env.background_color = Color(0.2, 0.25, 0.3)
	for tm: int in [Environment.TONE_MAPPER_LINEAR, Environment.TONE_MAPPER_FILMIC]:
		env.tonemap_mode = tm
		env.glow_enabled = false
		env.adjustment_enabled = false
		note("tm%d_plain_bg" % tm, px(await variant("tm%d_plain" % tm, false), 640, 40) + " expected (51,64,77)")
		env.glow_enabled = true
		note("tm%d_glow_bg" % tm, px(await variant("tm%d_glow" % tm, false), 640, 40))
		env.glow_enabled = false
		env.adjustment_enabled = true
		note("tm%d_adjust_bg" % tm, px(await variant("tm%d_adjust" % tm, false), 640, 40))
		env.adjustment_enabled = false
		get_viewport().scaling_3d_scale = 0.75
		note("tm%d_scale_bg" % tm, px(await variant("tm%d_scale" % tm, false), 640, 40))
		get_viewport().scaling_3d_scale = 1.0
	env.background_mode = Environment.BG_CLEAR_COLOR
	RenderingServer.set_default_clear_color(Color(0.2, 0.25, 0.3))
	note("clearcolor_plain_bg", px(await variant("clearcolor_plain", false), 640, 40))
	env.glow_enabled = true
	note("clearcolor_glow_bg", px(await variant("clearcolor_glow", false), 640, 40))
