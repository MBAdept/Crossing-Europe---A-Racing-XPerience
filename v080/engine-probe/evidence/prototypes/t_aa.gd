extends "res://probe_base.gd"

func test_aa() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var vp := get_viewport()
	var ref: Image = await variant("0_no_aa")
	for m: int in [Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]:
		vp.msaa_3d = m
		var im: Image = await variant("1_msaa_%dx" % [[1, 2, 4, 8][m]])
		note("msaa%d_diff_vs_ref" % [[1, 2, 4, 8][m]], diff(ref, im))
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var fx: Image = await variant("2_fxaa")
	note("fxaa_diff_vs_ref", diff(ref, fx))
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	var sm: Image = await variant("2_smaa")
	note("smaa_diff_vs_ref", diff(ref, sm))
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = true
	var ta: Image = await variant("2_taa")
	note("taa_diff_vs_ref", diff(ref, ta))
	vp.use_taa = false
	vp.use_debanding = true
	var db: Image = await variant("2_debanding")
	note("debanding_diff_vs_ref", diff(ref, db))
	vp.use_debanding = false
	for sc: float in [0.5, 0.67, 0.75, 1.5, 2.0]:
		vp.scaling_3d_scale = sc
		var im2: Image = await variant("3_scale_%.2f_bilinear" % sc)
		note("scale%.2f_diff_vs_ref" % sc, diff(ref, im2))
	vp.scaling_3d_scale = 0.5
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	await variant("4_scale_0.50_nearest")
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	var f1: Image = await variant("4_scale_0.50_fsr1")
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	var f2: Image = await variant("4_scale_0.50_fsr2")
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var bl: Image = await variant("4_scale_0.50_bilinear_again")
	note("fsr1_vs_bilinear_diff", diff(f1, bl))
	note("fsr2_vs_bilinear_diff", diff(f2, bl))
	# MSAA + scale 0.75 combined (candidate Deck preset)
	vp.scaling_3d_scale = 0.75
	vp.msaa_3d = Viewport.MSAA_4X
	await variant("5_scale_0.75_msaa4x")
	vp.scaling_3d_scale = 1.0
	# MSAA + glow (post path)
	env.glow_enabled = true
	await variant("6_msaa4x_glow")
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await variant("6_glow_no_msaa")
	env.glow_enabled = false

func px(img: Image, x: int, y: int) -> String:
	var c := img.get_pixel(x, y)
	return "(%d,%d,%d)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]

func sample(img: Image) -> String:
	return "grass=%s road=%s car=%s building=%s sky=%s" % [px(img, 1200, 400), px(img, 640, 690), px(img, 640, 570), px(img, 400, 440), px(img, 640, 50)]

# Which settings switch the renderer from "tonemap in the material shader" to "tonemap in a post pass",
# and does the picture change (it does when shadowed = additive lights are present)?
func test_pipeline() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var vp := get_viewport()
	var ref: Image = await variant("0_plain", false)
	note("0_plain", sample(ref))
	vp.msaa_3d = Viewport.MSAA_4X
	note("1_msaa4x", sample(await variant("1_msaa4x", false)))
	vp.msaa_3d = Viewport.MSAA_DISABLED
	env.glow_enabled = true
	env.glow_intensity = 0.0
	note("2_glow_intensity0", sample(await variant("2_glow_intensity0", false)))
	env.glow_enabled = false
	env.adjustment_enabled = true
	note("3_adjustment_identity", sample(await variant("3_adjustment_identity", false)))
	env.adjustment_enabled = false
	vp.scaling_3d_scale = 0.99
	note("4_scale0.99", sample(await variant("4_scale0.99", false)))
	vp.scaling_3d_scale = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 0.0
	note("5_ssao_intensity0", sample(await variant("5_ssao_intensity0", false)))
	env.ssao_enabled = false
	vp.use_hdr_2d = true
	note("6_hdr2d", sample(await variant("6_hdr2d", false)))
	note("6_hdr2d_format", get_viewport().get_texture().get_image().get_format())
	vp.use_hdr_2d = false
	note("7_plain_again", sample(await variant("7_plain_again", false)))
	# same checks without any shadowed light: do both paths agree then?
	sun.shadow_enabled = false
	note("8_noshadow_plain", sample(await variant("8_noshadow_plain", false)))
	env.glow_enabled = true
	env.glow_intensity = 0.0
	note("9_noshadow_glow0", sample(await variant("9_noshadow_glow0", false)))
	env.glow_enabled = false
