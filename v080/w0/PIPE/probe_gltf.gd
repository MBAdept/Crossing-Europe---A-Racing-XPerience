extends SceneTree
func _initialize() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var src := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
	var err := doc.append_from_file(src, state)
	print("err ", err)
	for gm: GLTFMesh in state.get_meshes():
		var im: ImporterMesh = gm.mesh
		print("gltfmesh name='", gm.resource_name, "' original='", gm.original_name, "' im.name='", im.resource_name, "' surfaces=", im.get_surface_count())
		for s in im.get_surface_count():
			var arr := im.get_surface_arrays(s)
			var mat := im.get_surface_material(s)
			print("  surf ", s, " name='", im.get_surface_name(s), "' mat='", (mat.resource_name if mat else "null"), "' fmt=", im.get_surface_format(s),
				" verts=", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), " tangent=", arr[Mesh.ARRAY_TANGENT] != null,
				" color=", arr[Mesh.ARRAY_COLOR] != null, " uv=", arr[Mesh.ARRAY_TEX_UV] != null, " uv2=", arr[Mesh.ARRAY_TEX_UV2] != null,
				" idx=", (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size())
			if arr[Mesh.ARRAY_COLOR] != null:
				var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
				print("   col0 ", c[0], " uv0 ", (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[0], " uv2_0 ", (arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)[0])
	for n: GLTFNode in state.get_nodes():
		print("node '", n.resource_name, "' orig='", n.original_name, "' mesh=", n.mesh, " xform=", n.xform)
	quit(0)
