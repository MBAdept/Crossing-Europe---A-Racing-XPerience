extends SceneTree
## QA: what frees the texture memory of the Modern models? release_all() alone, or only together with
## ModernMaterials.clear()? (Xvfb)
func _mem() -> float:
	return float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(640, 360)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 20, 120)
	cam.far = 3000.0
	sv.add_child(cam)
	var sun := DirectionalLight3D.new()
	sv.add_child(sun)
	var holder := Node3D.new()
	sv.add_child(holder)
	for i in 8:
		await process_frame
	var base := _mem()
	var mats := ModernMaterials.new()
	for round in 3:
		var x := -40.0
		for sid: String in ["landmarks/michel", "props/farmhouse", "props/tree_oak", "props/streetlight", "traffic/sedan_red", "player/limousine"]:
			var n := ModelFactory.build(sid, "lod0", mats)
			n.position = Vector3(x, 0, 0)
			holder.add_child(n)
			x += 16.0
		holder.add_child(ModelFactory.build_impostor("props/tree_oak", mats))
		for i in 6:
			await process_frame
		var shown := _mem()
		for c in holder.get_children():
			c.free()
		ModelDB.release_all()
		for i in 6:
			await process_frame
		var after_release := _mem()
		print("round %d: baseline %.2f MB, models shown %.2f MB, after freeing the nodes + ModelDB.release_all() %.2f MB, materials kept by ModernMaterials: %d" % [round + 1, base, shown, after_release, mats.all_materials().size()])
	mats.clear()
	for i in 6:
		await process_frame
	print("after ModernMaterials.clear(): %.2f MB" % _mem())
	quit(0)
