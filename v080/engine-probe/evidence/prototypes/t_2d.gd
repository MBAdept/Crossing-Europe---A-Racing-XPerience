extends "res://probe_base.gd"

func label(parent: Node, text: String, pos: Vector2, size: int = 28, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l

func hud() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.45)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(330, 110)
	layer.add_child(panel)
	label(layer, "187 km/h", Vector2(36, 28), 44, Color(1, 0.9, 0.3))
	label(layer, "Kiel – Hamburg   42,7 km", Vector2(36, 86), 22)
	label(layer, "HUD: CanvasLayer über 3D", Vector2(880, 660), 24)
	return layer

# 2D HUD over the 3D picture + full-screen canvas post effects reading the screen texture.
func test_hud_post() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var h := hud()
	await variant("0_hud_over_3d")
	note("root_viewport_size", get_viewport().size)
	note("visible_rect", get_viewport().get_visible_rect())
	note("window_size", get_window().size)
	# post layer between 3D and HUD
	var post_layer := CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://post_screen.gdshader")
	rect.material = sm
	post_layer.add_child(rect)
	var a: Image = await variant("1_post_identity")
	sm.set_shader_parameter("vignette", 0.7)
	await variant("2_post_vignette")
	sm.set_shader_parameter("blur_strength", 0.25)
	await variant("3_post_radial_blur_vignette")
	sm.set_shader_parameter("blur_strength", 0.0)
	sm.set_shader_parameter("droplets", 0.35)
	await variant("4_post_droplets")
	sm.set_shader_parameter("chroma", 0.02)
	await variant("5_post_droplets_chroma")
	# with MSAA and glow the screen texture still contains the final 3D picture?
	sm.set_shader_parameter("droplets", 0.0)
	sm.set_shader_parameter("chroma", 0.0)
	sm.set_shader_parameter("blur_strength", 0.25)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	env.glow_enabled = true
	await variant("6_post_blur_with_msaa_glow")
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	env.glow_enabled = false
	h.queue_free()
	post_layer.queue_free()

# Full-screen quad inside the 3D scene with depth + screen texture access.
func test_depth_quad() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var ref: Image = await variant("0_ref")
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://post_depth.gdshader")
	mi.material_override = sm
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(mi)
	mi.position = Vector3(0, 0, -1)
	sm.set_shader_parameter("mode", 0.0)
	await variant("1_depth_visualised")
	sm.set_shader_parameter("mode", 1.0)
	await variant("2_depth_tint_haze")
	sm.set_shader_parameter("mode", 2.0)
	await variant("3_depth_outline")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await variant("4_depth_outline_msaa4x")
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	env.glow_enabled = true
	await variant("5_depth_outline_glow")
	env.glow_enabled = false
	get_viewport().scaling_3d_scale = 0.5
	await variant("6_depth_outline_scale0.5")
	get_viewport().scaling_3d_scale = 1.0

# 3D inside a SubViewport composited into a 2D scene (menu showroom / race picture as a texture).
func test_subviewport() -> void:
	# 2D background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.15, 0.2, 0.4))
	grad.set_color(1, Color(0.02, 0.02, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)
	label(self, "2D-Menü (Control-Knoten) – darüber ein 3D-Schauraum im SubViewport", Vector2(40, 30), 30)
	# SubViewport with its own world
	var svc := SubViewportContainer.new()
	svc.position = Vector2(60, 110)
	svc.size = Vector2(760, 520)
	svc.stretch = true
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	var w := Node3D.new()
	sv.add_child(w)
	var c := Camera3D.new()
	c.position = Vector3(4.5, 2.2, 5.5)
	c.fov = 40.0
	w.add_child(c)
	c.look_at(Vector3(0, 0.7, 0))
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7)
	e.ambient_light_energy = 0.6
	e.glow_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = e
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 35, 0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	w.add_child(key)
	car(w, Vector3.ZERO, Color(0.8, 0.05, 0.05), true)
	cyl(w, 3.5, 0.1, Vector3(0, -0.05, 0), mat(Color(0.25, 0.25, 0.28), 0.3, 0.2))
	label(self, "Text über dem SubViewport (2D)", Vector2(100, 560), 26, Color(1, 0.9, 0.4))
	# second viewport shown via ViewportTexture in a TextureRect, lower internal resolution
	var sv2 := SubViewport.new()
	sv2.size = Vector2i(320, 180)
	sv2.world_3d = sv.find_world_3d()
	sv2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv2)
	var c2 := Camera3D.new()
	sv2.add_child(c2)
	c2.position = Vector3(0, 6, 0.01)
	c2.look_at(Vector3(0, 0, 0))
	var tr2 := TextureRect.new()
	tr2.texture = sv2.get_texture()
	tr2.position = Vector2(860, 130)
	tr2.size = Vector2(380, 214)
	tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(tr2)
	label(self, "ViewportTexture 320×180 → 380×214", Vector2(860, 350), 18)
	await variant("0_subviewport_in_2d_transparent_bg", true, 8)
	note("subviewport_size", sv.size)
	sv.transparent_bg = false
	e.background_color = Color(0.2, 0.25, 0.3, 1)
	await variant("1_subviewport_opaque", true, 6)
	sv.scaling_3d_scale = 0.5
	await variant("2_subviewport_scaling_0.5", true, 6)
	note("subviewport_get_texture_size", sv.get_texture().get_size())

# HDR 2D: banding and bright (>1) values with 2D glow.
func test_hdr2d() -> void:
	var vp := get_viewport()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.06))
	grad.set_color(1, Color(0.10, 0.12, 0.20))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 256
	gt.fill_to = Vector2(1, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)
	for i: int in range(5):
		var r := ColorRect.new()
		var v: float = [0.5, 1.0, 2.0, 4.0, 8.0][i]
		r.color = Color(v, v * 0.6, v * 0.2)
		r.position = Vector2(140 + i * 210, 260)
		r.size = Vector2(120, 120)
		add_child(r)
		label(self, "×%.1f" % v, Vector2(160 + i * 210, 400), 24)
	label(self, "2D-Farben über 1,0 (roh) – mit HDR 2D + Glow (BG_CANVAS) leuchten sie", Vector2(60, 60), 28)
	var a: Image = await variant("0_sdr_no_env", false)
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var b: Image = await variant("1_sdr_bg_canvas_glow", false)
	note("sdr_glow_diff_vs_noenv", diff(a, b))
	vp.use_hdr_2d = true
	var c: Image = await variant("2_hdr2d_bg_canvas_glow", false)
	note("hdr2d_image_format", get_viewport().get_texture().get_image().get_format())
	note("hdr2d_glow_diff_vs_sdr_glow", diff(b, c))
	e.glow_enabled = false
	var d: Image = await variant("3_hdr2d_no_glow", false)
	vp.use_hdr_2d = false

# 16:10 window (Steam Deck 1280x800): stretch aspect "keep" (letterbox) vs "expand" for the 3D picture.
func test_aspect() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var h := hud()
	note("window_size", get_window().size)
	note("content_scale_size", get_window().content_scale_size)
	await variant("0_keep", false, 6)
	note("keep_visible_rect", get_viewport().get_visible_rect())
	note("keep_image_size", last_img.get_size())
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await variant("1_expand", false, 6)
	note("expand_visible_rect", get_viewport().get_visible_rect())
	note("expand_image_size", last_img.get_size())
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

class Backdrop2D:
	extends Node2D
	func _draw() -> void:
		# sky gradient bands + sun + mountain silhouettes + skyline, like a 2D parallax backdrop
		for i: int in range(36):
			var t: float = float(i) / 35.0
			draw_rect(Rect2(0, t * 400.0, 1280, 12), Color(0.25, 0.45, 0.85).lerp(Color(0.95, 0.75, 0.55), t))
		draw_circle(Vector2(900, 300), 46, Color(1.0, 0.95, 0.7))
		var pts := PackedVector2Array()
		pts.append(Vector2(0, 420))
		for i: int in range(33):
			pts.append(Vector2(float(i) * 40.0, 330.0 + 50.0 * sin(float(i) * 0.9) + 25.0 * sin(float(i) * 2.3)))
		pts.append(Vector2(1280, 420))
		draw_colored_polygon(pts, Color(0.35, 0.42, 0.55))
		for i: int in range(18):
			var h: float = 30.0 + float((i * 37) % 70)
			draw_rect(Rect2(380.0 + float(i) * 22.0, 400.0 - h, 18, h + 20.0), Color(0.22, 0.25, 0.32))
		draw_rect(Rect2(0, 410, 1280, 310), Color(0.3, 0.45, 0.3))

# Environment.BG_CANVAS: a 2D canvas layer as the background of the 3D scene (reuse of a 2D backdrop).
func test_bg_canvas() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	cam.far = 400.0
	var ref: Image = await variant("0_sky_background")
	var layer := CanvasLayer.new()
	layer.layer = -5
	add_child(layer)
	layer.add_child(Backdrop2D.new())
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	var h := hud()
	await variant("1_bg_canvas_2d_backdrop_behind_3d")
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.8, 0.75, 0.7)
	await variant("2_bg_canvas_with_fog")
	env.glow_enabled = true
	await variant("3_bg_canvas_fog_glow")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await variant("4_bg_canvas_fog_glow_msaa")
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
