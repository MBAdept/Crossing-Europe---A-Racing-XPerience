extends SceneTree
## QA: cost of the Godot-side API (headless): manifest load, resolve, build, synchronous loads.
func _initialize() -> void:
	var t0 := Time.get_ticks_usec()
	ModelDB.load_manifest()
	var t1 := Time.get_ticks_usec()
	print("load_manifest: %.2f ms" % ((t1 - t0) / 1000.0))
	t0 = Time.get_ticks_usec()
	for i in 1000:
		for sid: String in ["traffic/sedan_red", "police/de", "props/tree_oak", "props/barn"]:
			ModelDB.resolve(sid)
	t1 = Time.get_ticks_usec()
	print("resolve(): %.2f us per call" % (float(t1 - t0) / 4000.0))
	# synchronous first load of every file
	for mid in ModelDB.model_ids():
		t0 = Time.get_ticks_usec()
		var n := 0
		for f in ModelDB.files_of(mid):
			if f.ends_with(".res"):
				ModelDB.mesh(f)
			else:
				ModelDB.texture(f)
			n += 1
		t1 = Time.get_ticks_usec()
		print("first synchronous load of %-18s %2d files: %7.2f ms" % [mid, n, (t1 - t0) / 1000.0])
	var mats := ModernMaterials.new()
	for sid: String in ["traffic/sedan_red", "player/limousine", "props/tree_oak", "props/farmhouse"]:
		for lod: String in ["lod0", "lod1"]:
			var probe := ModelFactory.build(sid, lod, mats)
			if probe == null:
				continue
			probe.free()
			t0 = Time.get_ticks_usec()
			var nodes: Array = []
			for i in 500:
				nodes.append(ModelFactory.build(sid, lod, mats))
			t1 = Time.get_ticks_usec()
			for nd: Node in nodes:
				nd.free()
			print("ModelFactory.build(%s, %s): %.1f us per call (cached meshes)" % [sid, lod, float(t1 - t0) / 500.0])
	t0 = Time.get_ticks_usec()
	for i in 2000:
		ModelDB.lod_for_distance(ModelDB.model("traffic/sedan"), float(i))
	t1 = Time.get_ticks_usec()
	print("lod_for_distance(): %.2f us per call" % (float(t1 - t0) / 2000.0))
	print("lod_for_distance(tree, 5000 m) = '%s'  (the tree has an impostor beyond lod1; the function cannot say so)" % ModelDB.lod_for_distance(ModelDB.model("props/tree_oak"), 5000.0))
	print("multimesh_parts('showroom/limousine', '') first mesh: %s (build() with '' takes the set's level 'show')" % str((ModelFactory.multimesh_parts("showroom/limousine", "")[0]["mesh"] as ArrayMesh).resource_path.get_file()))
	var r := ModelDB.resolve("police/de")
	print("resolve(police/de) = ", r)
	quit(0)
