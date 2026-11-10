extends SceneTree
## Synthesis check: headless bake glb -> node-free ArrayMesh .res (+ JSON with node tree), fixed ids, no materials.
func _arg(n: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return d

func _initialize() -> void:
	var src := _arg("src", "")
	var out := _arg("out", "")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(src, state)
	var scene: Node = doc.generate_scene(state)
	var nodes: Array = []
	var tris := 0
	var lod_info: Array = []
	var list: Array = scene.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in list:
		var src_mesh: Mesh = mi.mesh
		var im := ImporterMesh.new()
		var names: Array = []
		for s in src_mesh.get_surface_count():
			var m := src_mesh.surface_get_material(s)
			var nm := str(m.resource_name) if m != null else ""
			names.append(nm)
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src_mesh.surface_get_arrays(s), [], {}, null, nm)
		im.generate_lods(60.0, 25.0, [])
		var mesh: ArrayMesh = im.get_mesh()
		var lods: Array = []
		for s in mesh.get_surface_count():
			mesh.surface_set_name(s, str(names[s]))
			mesh.surface_set_material(s, null)
			tris += mesh.surface_get_array_index_len(s) / 3
			lods.append(im.get_surface_lod_count(s))
		mesh.resource_scene_unique_id = "mesh0"
		mesh.resource_name = str(mi.name)
		var p := out + "/" + str(mi.name) + ".res"
		var e := ResourceSaver.save(mesh, p, ResourceSaver.FLAG_COMPRESS)
		var xf: Transform3D = mi.transform
		nodes.append({"node": str(mi.name), "parent": str(mi.get_parent().name), "origin": [xf.origin.x, xf.origin.y, xf.origin.z], "surfaces": names, "lods": lods, "save_err": e,
			"extras": mi.get_meta_list()})
	var f := FileAccess.open(out + "/nodes.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(nodes, " "))
	f.close()
	print("BAKE err=", err, " meshes=", list.size(), " tris_lod0=", tris)
	quit(0)
