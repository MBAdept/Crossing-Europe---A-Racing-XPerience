extends "res://probe_base.gd"

func mesh_stats(root: Node) -> Dictionary:
	var out := {"mesh_instances": 0, "surfaces": 0, "vertices": 0, "triangles_lod0": 0, "lods_max": 0, "materials": {}, "compressed_surfaces": 0, "has_color": 0, "has_tangent": 0, "shadow_meshes": 0}
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var m: ArrayMesh = mi.mesh as ArrayMesh
		if m == null:
			continue
		out["mesh_instances"] += 1
		if m.shadow_mesh != null:
			out["shadow_meshes"] += 1
		for s: int in range(m.get_surface_count()):
			out["surfaces"] += 1
			out["vertices"] += m.surface_get_array_len(s)
			var idx: int = m.surface_get_array_index_len(s)
			out["triangles_lod0"] += (idx if idx > 0 else m.surface_get_array_len(s)) / 3
			var fmt: int = m.surface_get_format(s)
			if fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES:
				out["compressed_surfaces"] += 1
			if fmt & Mesh.ARRAY_FORMAT_COLOR:
				out["has_color"] += 1
			if fmt & Mesh.ARRAY_FORMAT_TANGENT:
				out["has_tangent"] += 1
			var lods: Dictionary = m.surface_get_lods(s) if m.has_method("surface_get_lods") else {}
			out["lods_max"] = maxi(out["lods_max"], lods.size())
			var mat_res: Material = m.surface_get_material(s)
			if mat_res != null:
				var mats: Dictionary = out["materials"]
				mats[mat_res.resource_name] = true
	out["materials"] = (out["materials"] as Dictionary).size()
	return out

func print_tree_limited(n: Node, depth: int, lines: PackedStringArray, max_lines: int) -> void:
	if lines.size() >= max_lines:
		return
	lines.append("  ".repeat(depth) + n.name + " [" + n.get_class() + "]")
	for c: Node in n.get_children():
		print_tree_limited(c, depth + 1, lines, max_lines)

func studio() -> void:
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.position = Vector3(5.2, 2.3, 6.2)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))
	env = Environment.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	sm.set_shader_parameter("use_time", 0.0)
	var sky := Sky.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	wenv = WorldEnvironment.new()
	wenv.environment = env
	world.add_child(wenv)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.light_energy = 1.1
	world.add_child(sun)
	plane(world, Vector2(200, 200), Vector3.ZERO, mat(Color(0.16, 0.16, 0.17), 0.6))

func show_model(path: String, tag: String, cam_pos: Vector3, target: Vector3) -> Node3D:
	var t0 := Time.get_ticks_msec()
	var ps: PackedScene = load(path)
	var t1 := Time.get_ticks_msec()
	var inst: Node3D = ps.instantiate()
	world.add_child(inst)
	var t2 := Time.get_ticks_msec()
	note(tag + "_load_ms", t1 - t0)
	note(tag + "_instantiate_ms", t2 - t1)
	note(tag + "_stats", mesh_stats(inst))
	var lines := PackedStringArray()
	print_tree_limited(inst, 0, lines, 14)
	note(tag + "_tree_head", lines)
	cam.position = cam_pos
	cam.look_at(target)
	return inst

func test_models() -> void:
	studio()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var a := show_model("res://models/player_sportwagen_raw.glb", "sportwagen_raw", Vector3(4.6, 1.9, 5.4), Vector3(0, 0.55, 0))
	await variant("0_sportwagen_raw_materials", true, 8)
	a.queue_free()
	var b := show_model("res://models/player_sportwagen_flat.glb", "sportwagen_flat", Vector3(4.6, 1.9, 5.4), Vector3(0, 0.55, 0))
	await variant("1_sportwagen_flat_materials", true, 8)
	cam.position = Vector3(-4.2, 1.6, -5.6)
	cam.look_at(Vector3(0, 0.55, 0))
	await variant("1_sportwagen_flat_rear", true, 4)
	get_viewport().mesh_lod_threshold = 0.0
	await variant("1_sportwagen_flat_rear_lod_off", true, 4)
	get_viewport().mesh_lod_threshold = 1.0
	# spin a wheel + switch a light: find nodes by name
	var wheel: Node3D = b.find_child("*wheel_f_rim*", true, false) as Node3D
	note("wheel_node_found", wheel != null)
	if wheel != null:
		note("wheel_node_origin", wheel.position)
	b.queue_free()
	var c := show_model("res://models/traffic_sedan_red_flat.glb", "sedan_flat", Vector3(4.6, 1.9, 5.4), Vector3(0, 0.6, 2.2))
	await variant("2_sedan_flat", true, 6)
	c.queue_free()
	var d := show_model("res://models/police_de_flat.glb", "police_flat", Vector3(4.6, 1.9, 5.4), Vector3(0, 0.6, 2.2))
	await variant("3_police_flat", true, 6)
	d.queue_free()
	var e := show_model("res://models/props_tree_oak_flat.glb", "oak_flat", Vector3(16, 6, 22), Vector3(0, 6, 0))
	await variant("4_tree_oak_flat", true, 6)
	e.queue_free()
	var f := show_model("res://models/props_building_oldtown_flat.glb", "oldtown_flat", Vector3(22, 9, 30), Vector3(0, 9, 0))
	await variant("5_building_oldtown_flat", true, 6)
	f.queue_free()
	var g := show_model("res://models/landmarks_eiffel_tower_flat.glb", "eiffel_flat", Vector3(260, 120, 420), Vector3(0, 150, 0))
	cam.far = 3000.0
	sun.directional_shadow_max_distance = 900.0
	await variant("6_eiffel_flat", true, 6)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED

# 20 traffic cars + player: draw calls and primitives with real models (LOD on/off).
func test_traffic() -> void:
	base_scene(true, false)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	for c: Node in world.get_children():
		if c is Node3D and c.get_child_count() >= 6 and not (c is MeshInstance3D):
			c.queue_free()   # remove the box cars
	await frames(2)
	var before := stats()
	note("without_cars", before)
	var sedan: PackedScene = load("res://models/traffic_sedan_red_flat.glb")
	var police: PackedScene = load("res://models/police_de_flat.glb")
	var player: PackedScene = load("res://models/player_sportwagen_flat.glb")
	var p: Node3D = player.instantiate()
	p.rotation_degrees = Vector3(0, 180, 0)
	world.add_child(p)
	for i: int in range(20):
		var lane: float = [-5.0, 0.0, 5.0][i % 3]
		var car_i: Node3D = (police if i == 3 else sedan).instantiate()
		car_i.position = Vector3(lane, 0.0, -10.0 - float(i) * 14.0)
		car_i.rotation_degrees = Vector3(0, 180, 0)
		world.add_child(car_i)
	await variant("0_player_plus_20_cars_lod_default")
	get_viewport().mesh_lod_threshold = 0.0
	await variant("1_player_plus_20_cars_lod_off")
	get_viewport().mesh_lod_threshold = 3.0
	await variant("2_player_plus_20_cars_lod_3px")
	get_viewport().mesh_lod_threshold = 1.0

func mat_info(root: Node, limit: int = 6) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m: ArrayMesh = (n as MeshInstance3D).mesh as ArrayMesh
		if m == null:
			continue
		for s: int in range(m.get_surface_count()):
			var sm: StandardMaterial3D = m.surface_get_material(s) as StandardMaterial3D
			if sm == null or seen.has(sm.resource_name):
				continue
			seen[sm.resource_name] = true
			if out.size() < limit:
				out.append("%s albedo=%s metal=%.2f rough=%.2f emis=%s e=%.1f vcol=%s transp=%d clearcoat=%s" % [sm.resource_name, sm.albedo_color.to_html(false), sm.metallic, sm.roughness, sm.emission.to_html(false) if sm.emission_enabled else "-", sm.emission_energy_multiplier, sm.vertex_color_use_as_albedo, sm.transparency, sm.clearcoat_enabled])
	return out

func test_models2() -> void:
	studio()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var a := show_model("res://models/traffic_sedan_red_merged.glb", "sedan_merged", Vector3(-4.4, 1.9, -3.0), Vector3(0, 0.6, 2.3))
	note("sedan_merged_materials", mat_info(a, 12))
	await variant("0_sedan_merged_rear", true, 6)
	cam.position = Vector3(4.6, 1.9, 8.0)
	cam.look_at(Vector3(0, 0.6, 2.3))
	await variant("0_sedan_merged_front", true, 4)
	# wheel spin + steering through the node hierarchy; switch tail lights via emission energy
	var wheels: Array[Node] = a.find_children("*tyre*", "MeshInstance3D", true, false)
	note("sedan_wheel_nodes", wheels.size())
	a.queue_free()
	var b := show_model("res://models/police_de_merged.glb", "police_merged", Vector3(-4.4, 1.9, -3.0), Vector3(0, 0.6, 2.3))
	await variant("1_police_merged", true, 6)
	b.queue_free()
	var c := show_model("res://models/traffic_truck_white_merged.glb", "truck_merged", Vector3(-9, 4, -8), Vector3(0, 1.8, 6))
	await variant("2_truck_merged", true, 6)
	c.queue_free()
	var d := show_model("res://models/landmarks_eiffel_tower_merged.glb", "eiffel_merged", Vector3(260, 120, 420), Vector3(0, 150, 0))
	cam.far = 3000.0
	sun.directional_shadow_max_distance = 900.0
	await variant("3_eiffel_merged", true, 6)
	d.queue_free()
	cam.far = 1500.0
	sun.directional_shadow_max_distance = 60.0
	var e := show_model("res://models/props_streetlight_merged.glb", "streetlight", Vector3(6, 5, 9), Vector3(0, 4.5, 0))
	note("streetlight_materials", mat_info(e, 6))
	await variant("4_streetlight", true, 6)
	e.queue_free()
	var f := show_model("res://models/vc_test.glb", "vc_test", Vector3(0.01, 6, 0.0), Vector3(0, 0, 0))
	f.position = Vector3(0, 0.05, 0)
	note("vc_test_materials", mat_info(f, 3))
	await variant("5_vertex_colour_and_emission", true, 6)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED

func test_traffic2() -> void:
	base_scene(true, false)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	for c: Node in world.get_children():
		if not (c is MeshInstance3D) and c is Node3D and c.get_child_count() >= 6:
			c.queue_free()
	await frames(2)
	note("without_cars", stats())
	for kind: String in ["flat", "merged"]:
		var sedan: PackedScene = load("res://models/traffic_sedan_red_%s.glb" % kind)
		var cars: Array[Node3D] = []
		for i: int in range(20):
			var lane: float = [-5.0, 0.0, 5.0][i % 3]
			var ci: Node3D = sedan.instantiate()
			ci.position = Vector3(lane, 0.0, -6.0 - float(i) * 14.0)
			ci.rotation_degrees = Vector3(0, 180, 0)
			world.add_child(ci)
			cars.append(ci)
		await variant("20_sedans_%s_lod_default" % kind)
		get_viewport().mesh_lod_threshold = 0.0
		await variant("20_sedans_%s_lod_off" % kind)
		get_viewport().mesh_lod_threshold = 1.0
		for ci: Node3D in cars:
			ci.queue_free()
		await frames(2)

func test_vcol() -> void:
	studio()
	env.glow_enabled = false
	var f := show_model("res://models/vc_test.glb", "vc_test", Vector3(0.01, 6, 0.0), Vector3(0, 0, 0))
	f.position = Vector3(0, 0.05, 0)
	var mi: MeshInstance3D = f.find_children("*", "MeshInstance3D", true, false)[0]
	var m: StandardMaterial3D = mi.mesh.surface_get_material(0)
	m.emission_enabled = false
	var a: Image = await variant("0_as_imported_emission_off", false, 6)
	m.vertex_color_use_as_albedo = true
	var b: Image = await variant("1_vertex_color_use_as_albedo", false, 6)
	note("vcol_flag_diff", diff(a, b))
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	note("vcol_first_colors", [cols[0], cols[40], cols[80]] if cols.size() > 80 else cols.size())

# 2D textures on 3D materials: lossless vs VRAM compressed (S3TC / BPTC) – memory and look; anisotropy.
func test_textures() -> void:
	studio()
	env.glow_enabled = false
	cam.position = Vector3(0, 1.6, 6)
	cam.look_at(Vector3(0, 0, -30))
	await frames(4)
	var base_mem: float = float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0
	note("texture_mem_before_mb", snappedf(base_mem, 0.01))
	var x := -9.0
	for name: String in ["tex_lossless", "tex_vram_s3tc", "tex_vram_bptc"]:
		var t: Texture2D = load("res://tex/%s.png" % name)
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		m.uv1_scale = Vector3(1, 8, 1)
		m.roughness = 0.7
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		plane(world, Vector2(8, 120), Vector3(x, 0.02, -50), m)
		x += 9.0
		await frames(3)
		var mem: float = float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0
		note("%s_format" % name, t.get_image().get_format())
		note("%s_texture_mem_added_mb" % name, snappedf(mem - base_mem, 0.01))
		base_mem = mem
	await variant("0_lossless_s3tc_bptc_aniso", false, 6)
	note("anisotropic_filtering_level_setting", ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level"))
