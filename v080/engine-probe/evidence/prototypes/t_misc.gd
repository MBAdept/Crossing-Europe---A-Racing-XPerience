extends "res://probe_base.gd"

func marking_texture() -> ImageTexture:
	# arrow + skid marks style decal texture with alpha
	var s := 128
	var im := Image.create(s, s, false, Image.FORMAT_RGBA8)
	im.fill(Color(1, 1, 1, 0))
	for y: int in range(s):
		for x: int in range(s):
			var u: float = float(x) / float(s) - 0.5
			var v: float = float(y) / float(s)
			var a: float = 0.0
			if v > 0.35 and absf(u) < 0.08:
				a = 1.0
			if v <= 0.35 and absf(u) < v * 0.75:
				a = 1.0
			im.set_pixel(x, y, Color(1, 1, 1, a))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

# Decal node (expected: unavailable) and substitutes: alpha-blended quads on the road.
func test_decal() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var ref: Image = await variant("0_ref")
	var tex := marking_texture()
	var dec := Decal.new()
	dec.texture_albedo = tex
	dec.size = Vector3(3, 2, 6)
	dec.position = Vector3(-2.5, 0.0, -9.0)
	world.add_child(dec)
	var a: Image = await variant("1_decal_node", false)
	note("decal_node_diff", diff(ref, a))
	dec.queue_free()
	# substitute 1: quad 1 cm above the road, alpha blend, receives light + shadow
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(0.95, 0.95, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.6
	for i: int in range(40):
		var q := plane(world, Vector2(2.0, 5.0), Vector3(-2.5 + float(i % 3) * 2.5, 0.01, -9.0 - float(i) * 14.0), m)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# skid marks: dark multiply-ish (alpha blend black)
	var sk := StandardMaterial3D.new()
	sk.albedo_color = Color(0.02, 0.02, 0.02, 0.55)
	sk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane(world, Vector2(0.25, 18.0), Vector3(1.6, 0.012, -6.0), sk)
	plane(world, Vector2(0.25, 18.0), Vector3(3.2, 0.012, -6.0), sk)
	# light pool: additive unshaded quad (fake headlight cone on the road)
	var lp := StandardMaterial3D.new()
	lp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lp.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lp.albedo_color = Color(1.0, 0.9, 0.6, 0.35)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	var g2 := GradientTexture2D.new()
	g2.gradient = gr
	g2.fill = GradientTexture2D.FILL_RADIAL
	g2.fill_from = Vector2(0.5, 0.5)
	g2.fill_to = Vector2(1.0, 0.5)
	lp.albedo_texture = g2
	plane(world, Vector2(5.0, 14.0), Vector3(-5.0, 0.014, -24.0), lp)
	await variant("2_quad_substitutes_markings_skid_lightpool")
	# z-fighting check from far away / low angle
	cam.position = Vector3(0.0, 1.0, 7.5)
	cam.look_at(Vector3(0.0, 0.6, -60.0))
	await variant("3_low_camera_far_markings")
	cam.fov = 12.0
	await variant("4_zoomed_far_markings_fov12")

# Transparent sorting: overlapping blended objects, glass, particles.
func test_transparent() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.7, 0.9, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# three intersecting large panes + nested boxes
	for i: int in range(3):
		var b := box(world, Vector3(4.0, 2.5, 0.1), Vector3(-4.5, 1.3, -6.0), glass)
		b.rotation_degrees = Vector3(0, float(i) * 60.0, 0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.1, 0.1, 0.5)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box(world, Vector3(1.5, 1.5, 1.5), Vector3(4.2, 1.0, -6.0), red)
	box(world, Vector3(0.7, 0.7, 0.7), Vector3(4.2, 1.0, -6.0), glass)
	# long transparent strip (like a guard-rail glass wall) crossing other transparents
	box(world, Vector3(0.1, 2.0, 60.0), Vector3(6.0, 1.0, -30.0), glass)
	sphere(world, 1.0, Vector3(6.0, 1.2, -12.0), red)
	await variant("0_alpha_blend_sorting")
	# render_priority fixes fixed layering
	red.render_priority = 1
	await variant("1_render_priority")
	# depth pre-pass variant
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	await variant("2_depth_prepass")
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.refraction_enabled = true
	glass.refraction_scale = 0.08
	await variant("3_refraction")

# Visibility ranges (manual HLOD), mesh LOD via ImporterMesh, GeometryInstance3D.transparency.
func test_lod() -> void:
	base_scene(true, true)
	var red := mat(Color(1, 0.1, 0.1))
	var blue := mat(Color(0.1, 0.2, 1))
	for i: int in range(40):
		var z: float = -10.0 - float(i) * 12.0
		var near := sphere(world, 1.2, Vector3(9.0, 1.2, z), red)
		near.visibility_range_end = 150.0
		near.visibility_range_end_margin = 10.0
		var far := box(world, Vector3(2.4, 2.4, 2.4), Vector3(9.0, 1.2, z), blue)
		far.visibility_range_begin = 150.0
		far.visibility_range_begin_margin = 10.0
	var a: Image = await variant("0_visibility_range_hlod_150m")
	for c: Node in world.get_children():
		if c is GeometryInstance3D and (c as GeometryInstance3D).visibility_range_end > 0.0:
			(c as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var b: Image = await variant("1_visibility_range_fade_self", false)
	note("fade_self_diff", diff(a, b))
	# GeometryInstance3D.transparency (docs: ignored)
	var s := sphere(world, 1.0, Vector3(-3.4, 2.4, -3.0), mat(Color(1, 1, 0)))
	var c1: Image = await variant("2_before_instance_transparency", false)
	s.transparency = 0.7
	var c2: Image = await variant("2_instance_transparency_0.7", false)
	note("instance_transparency_diff", diff(c1, c2))
	# automatic mesh LOD: generate LODs for a dense sphere through ImporterMesh
	var sm := SphereMesh.new()
	sm.radial_segments = 128
	sm.rings = 64
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, sm.get_mesh_arrays())
	im.generate_lods(25.0, 60.0, [])
	note("importer_mesh_lod_count", im.get_surface_lod_count(0))
	var lod_sizes: Array[int] = []
	for i: int in range(im.get_surface_lod_count(0)):
		lod_sizes.append(im.get_surface_lod_indices(0, i).size() / 3)
	note("importer_mesh_lod_triangles", lod_sizes)
	var am: ArrayMesh = im.get_mesh()
	for c: Node in world.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
			c.queue_free()
	await frames(2)
	var before := stats()
	for i: int in range(60):
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = mat(Color(0.2, 0.8, 0.3))
		mi.position = Vector3(-10.0 - float(i % 3) * 4.0, 1.5, -5.0 - float(i) * 9.0)
		mi.scale = Vector3(1.5, 1.5, 1.5)
		world.add_child(mi)
	get_viewport().mesh_lod_threshold = 0.0
	await variant("3_lod_disabled_threshold0")
	get_viewport().mesh_lod_threshold = 1.0
	await variant("3_lod_threshold1px")
	get_viewport().mesh_lod_threshold = 4.0
	await variant("3_lod_threshold4px")
	get_viewport().mesh_lod_threshold = 1.0

# AreaLight3D (new in 4.7) at night.
func test_arealight() -> void:
	base_scene(true, true)
	night()
	var ref: Image = await variant("0_ref")
	var al := AreaLight3D.new()
	al.area_size = Vector2(6.0, 1.0)
	al.area_range = 25.0
	al.light_energy = 8.0
	al.light_color = Color(0.4, 0.9, 1.0)
	al.position = Vector3(-6.0, 4.0, -12.0)
	world.add_child(al)
	al.look_at(Vector3(0.0, 0.0, -12.0))
	box(world, Vector3(0.1, 1.0, 6.0), Vector3(-6.05, 4.0, -12.0), emat(Color(0.4, 0.9, 1.0), 6.0))
	var a: Image = await variant("1_area_light")
	note("area_light_diff", diff(ref, a))
	al.shadow_enabled = true
	var b: Image = await variant("2_area_light_shadow_enabled")
	note("area_light_shadow_diff", diff(a, b))
