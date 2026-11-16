extends SceneTree
## SPIKE: bake a glb into committed, node-free resources (ArrayMesh .res) – deterministic bytes?
func _initialize() -> void:
	var out_dir := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/product-ux/imp/"
	var tag := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/product-ux/samples/player_kompakt_d2.glb", state)
	var scene: Node = doc.generate_scene(state)
	var n := 0
	var tris := 0
	for mi in scene.find_children("*", "ImporterMeshInstance3D", true, false) + scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = null
		if mi is ImporterMeshInstance3D:
			var im: ImporterMesh = (mi as ImporterMeshInstance3D).mesh
			im.generate_lods(60.0, 25.0, [])
			mesh = im.get_mesh()
		else:
			mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var p := out_dir + "bake_%s_%s.res" % [tag, str(mi.name)]
		if OS.get_cmdline_user_args().has("--no-materials"):
			# materials come from a shared library at runtime (surface names carry the slot): no sub-resources left
			for s in mesh.get_surface_count():
				var mat0 := mesh.surface_get_material(s)
				(mesh as ArrayMesh).surface_set_name(s, str(mat0.resource_name) if mat0 != null else "")
				mesh.surface_set_material(s, null)
		if OS.get_cmdline_user_args().has("--fixed-ids"):
			# deterministic ids: the mesh itself and every material stored inside it (Godot generates random
			# 5-character ids for resources without one – different bytes at every save)
			mesh.resource_scene_unique_id = "mesh0"
			var seen := {}
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				if mat != null and not seen.has(mat):
					seen[mat] = true
					mat.resource_scene_unique_id = "mat%02d" % seen.size()
		var e := ResourceSaver.save(mesh, p, 0 if OS.get_cmdline_user_args().has("--raw") else ResourceSaver.FLAG_COMPRESS)
		n += 1
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(s) / 3
	print("baked ", n, " meshes, ", tris, " triangles (LOD0), gltf err ", err)
	quit(0)
