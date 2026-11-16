extends SceneTree
## QA: the paint codes (COLOR.a 0 / 0.25 / 0.5 / 1) through a compressed .res and vpbr.gdshader with instance
## uniforms, and the cut-out variant of baked.gdshader (no reference model uses either). Xvfb. --out=<dir>

var _out := ""

func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _quad(arr_v: PackedVector3Array, arr_n: PackedVector3Array, arr_c: PackedColorArray, arr_uv: PackedVector2Array, arr_uv2: PackedVector2Array, idx: PackedInt32Array, x0: float, col: Color) -> void:
	var base := arr_v.size()
	for c: Vector2 in [Vector2(x0, 1.0), Vector2(x0 + 0.8, 1.0), Vector2(x0 + 0.8, 0.2), Vector2(x0, 0.2)]:
		arr_v.append(Vector3(c.x, c.y, 0.0))
		arr_n.append(Vector3(0, 0, 1))
		arr_c.append(col)
		arr_uv.append(Vector2(0.9, 0.0))
		arr_uv2.append(Vector2(-1.0, 0.0))
	idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var codes := [0.0, 64.0 / 255.0, 128.0 / 255.0, 1.0]       # as ce3d/roles.py writes them: 0, 64, 128, 255
	for i in codes.size():
		_quad(v, n, c, uv, uv2, idx, float(i) * 1.0, Color(0.5, 0.5, 0.5, float(codes[i])))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "vpbr", Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	var mesh := im.get_mesh()
	mesh.surface_set_material(0, null)
	var path := _out.path_join("codes_probe.res")
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	var back: PackedColorArray = loaded.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var seen := {}
	for col: Color in back:
		seen[snappedf(col.a, 0.0001)] = true
	var keys: Array = seen.keys()
	keys.sort()
	print("paint codes written 0 / 64 / 128 / 255 (bytes) -> decoded from the compressed .res: ", keys, "  format compressed: ", (loaded.surface_get_format(0) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0)
	var mats := ModernMaterials.new()
	var sv := SubViewport.new()
	sv.size = Vector2i(800, 300)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.2, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.6
	cam.position = Vector3(1.9, 0.6, 5.0)
	sv.add_child(cam)
	var mi := MeshInstance3D.new()
	loaded.surface_set_material(0, mats.material("vpbr"))
	mi.mesh = loaded
	sv.add_child(mi)
	mi.set_instance_shader_parameter("paint", Color(1, 0, 0, 0))
	mi.set_instance_shader_parameter("paint2", Color(0, 1, 0, 0))
	mi.set_instance_shader_parameter("paint3", Color(0, 0, 1, 0))
	# cut-out variant of baked.gdshader on a quad with a checker alpha texture
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var on := ((x / 8) + (y / 8)) % 2 == 0
			img.set_pixel(x, y, Color(1.0, 0.8, 0.2, 1.0 if on else 0.0))
	var tex := ImageTexture.create_from_image(img)
	var cut := mats.material("baked_cutout", {}) as ShaderMaterial
	cut.set_shader_parameter("albedo_tex", tex)
	var plain := mats.material("baked", {"roughness": 0.5}) as ShaderMaterial
	plain.set_shader_parameter("albedo_tex", tex)
	print("baked_cutout shader: %s, differs from baked: %s, has CE_CUTOUT: %s" % [str(cut.shader != null), str(cut.shader != plain.shader), str(cut.shader.code.contains("#define CE_CUTOUT"))])
	for k in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.8, 0.8)
		q.mesh = qm
		q.material_override = cut if k == 0 else plain
		q.position = Vector3(4.6 + float(k) * 1.0, 0.6, 0.0)
		sv.add_child(q)
	cam.size = 2.4
	cam.position = Vector3(3.0, 0.6, 5.0)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var shot := sv.get_texture().get_image()
	shot.convert(Image.FORMAT_RGB8)
	shot.save_png(_out.path_join("codes_probe.png"))
	# sample the centre of each quad: world x 0.4, 1.4, 2.4, 3.4 at y 0.6; ortho width = size * aspect
	var w_m := 2.4 * 800.0 / 300.0
	for i in 4:
		var px := int((float(i) + 0.4 - (3.0 - w_m * 0.5)) / w_m * 800.0)
		var col := shot.get_pixel(px, 150)
		print("quad with code %.3f -> displayed %s  (%s)" % [float(codes[i]), col.to_html(false), ["paint (red wanted)", "paint2 (green wanted)", "paint3 (blue wanted)", "fixed colour (grey wanted)"][i]])
	# cut-out: opaque cell and hole
	var cx := int((4.6 - (3.0 - w_m * 0.5)) / w_m * 800.0)
	var holes := 0
	var solid := 0
	for dx in range(-45, 46, 3):
		var p := shot.get_pixel(cx + dx, 150)
		if absf(p.r - 0.2) < 0.03 and absf(p.g - 0.2) < 0.03:
			holes += 1
		else:
			solid += 1
	print("baked_cutout quad along one line: %d samples show the background (holes), %d show the texture" % [holes, solid])
	quit(0)
