extends Node
## Synthesis probe: (1) light additivity vs. shadow flag / casters / post path, (2) BG_CANVAS + sky as reflection source.

var env: Environment
var we: WorldEnvironment
var sun: DirectionalLight3D
var plane: MeshInstance3D
var ball: MeshInstance3D
var box: MeshInstance3D
var cam: Camera3D
var bg_layer: CanvasLayer
var results: Array = []

func _ready() -> void:
	cam = Camera3D.new()
	cam.position = Vector3(0, 3, 8)
	cam.look_at_from_position(Vector3(0, 3, 8), Vector3(0, 0.5, 0))
	add_child(cam)
	env = Environment.new()
	we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.5
	add_child(sun)
	plane = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	plane.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.5, 0.5)
	m.roughness = 1.0
	plane.material_override = m
	add_child(plane)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 1, 1)
	bm.metallic = 1.0
	bm.roughness = 0.05
	ball.material_override = bm
	ball.position = Vector3(-2.0, 1.0, 0)
	add_child(ball)
	box = MeshInstance3D.new()
	var bxm := BoxMesh.new()
	bxm.size = Vector3(1.5, 1.5, 1.5)
	box.mesh = bxm
	var xm := StandardMaterial3D.new()
	xm.albedo_color = Color(0.8, 0.2, 0.2)
	box.material_override = xm
	box.position = Vector3(2.5, 0.75, 0)
	add_child(box)
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	var cr := ColorRect.new()
	cr.color = Color(0.2, 0.4, 0.8)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(cr)
	add_child(bg_layer)
	bg_layer.visible = false
	await run_all()
	var f := FileAccess.open("user://results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	f.close()
	get_tree().quit()

func px(img: Image, x: int, y: int) -> String:
	var c := img.get_pixel(x, y)
	return "%d,%d,%d" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]

func shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % name)
	# plane lit (front, away from shadows), plane in box shadow, ball centre-top, sky/background
	var w := img.get_width()
	var h := img.get_height()
	var r := {"name": name,
		"plane_front": px(img, w / 2, h - 30),
		"bg_top": px(img, w / 2, 8),
		"ball_top": px(img, int(w * 0.5 - w * 0.115), int(h * 0.36)),
		"ball_mid": px(img, int(w * 0.5 - w * 0.115), int(h * 0.50)),
		"box": px(img, int(w * 0.5 + w * 0.14), int(h * 0.52)),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
	print(JSON.stringify(r))
	results.append(r)

func reset() -> void:
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.1, 0.2, 0.6)
	psm.sky_horizon_color = Color(0.6, 0.7, 0.8)
	psm.ground_bottom_color = Color(0.1, 0.1, 0.1)
	psm.ground_horizon_color = Color(0.6, 0.7, 0.8)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.ambient_light_energy = 0.4
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.adjustment_enabled = false
	env.fog_enabled = false
	env.ssao_enabled = false
	sun.visible = true
	sun.shadow_enabled = false
	sun.light_energy = 0.5
	sun.directional_shadow_max_distance = 100.0
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bg_layer.visible = false
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED

func all_cast(on: bool) -> void:
	var v := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.cast_shadow = v
	ball.cast_shadow = v
	box.cast_shadow = v

func run_all() -> void:
	# --- E3: lit brightness vs. shadow split mode and casters (post path pinned) ---------------
	for mode: int in [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS]:
		for cast: bool in [true, false]:
			reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
			sun.directional_shadow_mode = mode
			all_cast(cast)
			await shot("e3_mode%d_cast%d" % [mode, int(cast)])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# --- E2: additivity -------------------------------------------------------------------
	reset(); sun.visible = false
	await shot("e2_ambient_only")
	reset(); env.ambient_light_energy = 0.0
	await shot("e2_sun_only_noshadow")
	reset()
	await shot("e2_amb_sun_noshadow")
	reset(); sun.shadow_enabled = true
	await shot("e2_amb_sun_shadow")
	reset(); sun.shadow_enabled = true; all_cast(false)
	await shot("e2_amb_sun_shadowflag_nocasters")
	reset(); sun.shadow_enabled = true; sun.directional_shadow_max_distance = 1.0
	await shot("e2_amb_sun_shadow_maxdist1")
	# same four with the post path pinned by adjustments
	reset(); env.adjustment_enabled = true
	await shot("e2p_amb_sun_noshadow_adj")
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
	await shot("e2p_amb_sun_shadow_adj")
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true; all_cast(false)
	await shot("e2p_amb_sun_shadowflag_nocasters_adj")
	reset(); env.glow_enabled = true; sun.shadow_enabled = true
	await shot("e2p_amb_sun_shadow_glow")
	reset(); env.glow_enabled = true; env.adjustment_enabled = true; sun.shadow_enabled = true
	await shot("e2p_amb_sun_shadow_glow_adj")
	reset(); get_viewport().scaling_3d_scale = 0.75; sun.shadow_enabled = true
	await shot("e2p_amb_sun_shadow_scale075")
	# sun energy 0 with shadow flag (tunnel case): must equal ambient only
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true; sun.light_energy = 0.0
	await shot("e2p_amb_sun0_shadow_adj")
	reset(); env.adjustment_enabled = true; sun.visible = false
	await shot("e2p_ambient_only_adj")
	# --- E1: BG_CANVAS + sky as reflection / ambient source -------------------------------
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	await shot("e1_bgsky_reflsky")
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
	env.background_mode = Environment.BG_CANVAS; env.background_canvas_max_layer = -10; bg_layer.visible = true
	await shot("e1_bgcanvas_norefl")
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
	env.background_mode = Environment.BG_CANVAS; env.background_canvas_max_layer = -10; bg_layer.visible = true
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	await shot("e1_bgcanvas_reflsky")
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
	env.background_mode = Environment.BG_CANVAS; env.background_canvas_max_layer = -10; bg_layer.visible = true
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	await shot("e1_bgcanvas_reflsky_ambsky")
	reset(); env.adjustment_enabled = true; sun.shadow_enabled = true
	env.background_mode = Environment.BG_CANVAS; env.background_canvas_max_layer = -10; bg_layer.visible = true
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.glow_enabled = true
	get_viewport().scaling_3d_scale = 0.75
	get_viewport().msaa_3d = Viewport.MSAA_2X
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 60.0
	env.fog_light_color = Color(0.78, 0.86, 0.93)
	await shot("e1_bgcanvas_reflsky_glow_scale_msaa_fog")
