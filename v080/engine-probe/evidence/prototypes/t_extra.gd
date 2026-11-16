extends "res://probe_base.gd"

class SignDraw:
	extends Control
	var town := "Hamburg"
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.95, 0.8, 0.1))
		draw_rect(Rect2(6, 6, size.x - 12, size.y - 12), Color(0, 0, 0), false, 6.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(24, 86), town, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0, 0, 0))
		draw_string(font, Vector2(24, 150), "Kreis Probe – 12 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0, 0, 0))

# Signs with text: 2D drawing in a SubViewport as a texture on a 3D quad; Label3D; snapshot to a mipmapped ImageTexture.
func test_signs() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var sv := SubViewport.new()
	sv.size = Vector2i(512, 192)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var sd := SignDraw.new()
	sd.size = Vector2(512, 192)
	sv.add_child(sd)
	await frames(3)
	# live ViewportTexture on a quad
	var m1 := StandardMaterial3D.new()
	m1.albedo_texture = sv.get_texture()
	m1.roughness = 0.5
	var q1 := QuadMesh.new()
	q1.size = Vector2(3.2, 1.2)
	var s1 := add_mesh(world, q1, Vector3(9.0, 2.6, -8.0), m1)
	cyl(world, 0.05, 2.6, Vector3(9.0, 1.3, -8.02), mat(Color(0.6, 0.6, 0.62), 0.4, 0.8))
	# snapshot -> ImageTexture with mipmaps (for static signs), placed further away
	var img: Image = sv.get_texture().get_image()
	img.generate_mipmaps()
	var it := ImageTexture.create_from_image(img)
	var m2 := StandardMaterial3D.new()
	m2.albedo_texture = it
	m2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for i: int in range(6):
		var s2 := add_mesh(world, q1, Vector3(9.0, 2.6, -30.0 - float(i) * 30.0), m2)
		var s3 := add_mesh(world, q1, Vector3(-9.0, 2.6, -30.0 - float(i) * 30.0), m1)
	# Label3D
	var l3 := Label3D.new()
	l3.text = "TANKSTELLE 2 km"
	l3.font_size = 96
	l3.pixel_size = 0.01
	l3.modulate = Color(1, 1, 1)
	l3.outline_size = 12
	l3.position = Vector3(-9.0, 4.2, -8.0)
	l3.shaded = true
	l3.double_sided = false
	world.add_child(l3)
	note("sign_image_format", img.get_format())
	note("sign_image_size", img.get_size())
	await variant("0_signs_viewporttexture_imagetexture_label3d")
	cam.position = Vector3(6.0, 2.2, -1.0)
	cam.look_at(Vector3(9.0, 2.6, -8.0))
	await variant("1_sign_close")

# Per-instance uniforms, light distance fade, occlusion culling.
func test_extras() -> void:
	base_scene(true, true)
	night()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://inst_uniform.gdshader")
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 1.4, 4.4)
	for i: int in range(6):
		var mi := add_mesh(world, bm, Vector3(-9.5 + float(i) * 3.8, 0.7, -9.0), null)
		mi.material_override = sm
		mi.rotation_degrees = Vector3(0, 90, 0)
		mi.set_instance_shader_parameter("paint", Color.from_hsv(float(i) / 6.0, 0.8, 0.9))
		mi.set_instance_shader_parameter("lights_on", 3.0 if i % 2 == 0 else 0.0)
	await variant("0_instance_uniforms_6_boxes_one_material")
	# lamps with distance fade: only those within the fade range count against the limits
	var lamps: Array[OmniLight3D] = []
	for i: int in range(64):
		var side: float = -8.5 if i % 2 == 0 else 8.5
		var p := Vector3(side, 7.0, -10.0 - float(i) * 12.5)
		sphere(world, 0.25, p, emat(Color(1.0, 0.75, 0.4), 4.0))
		var l := omni(world, p, 22.0, 3.0)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 120.0
		l.distance_fade_length = 30.0
		lamps.append(l)
	# chunked ground so that the per-object limit is not the issue
	var road_m := mat(Color(0.13, 0.13, 0.14), 0.75)
	for i: int in range(56):
		plane(world, Vector2(15.0, 25.0), Vector3(0, 0.02, 12.5 - float(i) * 25.0), road_m)
	await variant("1_64_lamps_distance_fade_120m")
	for l: OmniLight3D in lamps:
		l.distance_fade_enabled = false
	await variant("2_64_lamps_no_distance_fade")

func test_occlusion() -> void:
	base_scene(true, true)
	note("use_occlusion_culling_setting", ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling"))
	# a big wall across the road hides everything behind it
	box(world, Vector3(200, 40, 1), Vector3(0, 20, -20), mat(Color(0.5, 0.5, 0.5)))
	await variant("0_wall_no_occluder")
	var occ := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(200, 40, 1)
	occ.occluder = bo
	occ.position = Vector3(0, 20, -20)
	world.add_child(occ)
	get_viewport().use_occlusion_culling = true
	await variant("1_wall_with_box_occluder", true, 8)

# Single-precision world coordinates far from the origin (a 400 km stage = 40 km of visible road).
func test_far_origin() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var ref: Image = await variant("0_origin_0")
	for off: float in [5000.0, 40000.0, 200000.0]:
		for c: Node in world.get_children():
			if c is Node3D and not (c is DirectionalLight3D):
				(c as Node3D).position += Vector3(0, 0, -off) - Vector3(0, 0, -world.get_meta("off", 0.0))
		world.set_meta("off", off)
		var im: Image = await variant("1_origin_minus_%dm" % int(off), false, 6)
		note("diff_vs_origin0_at_%dm" % int(off), diff(ref, im))
