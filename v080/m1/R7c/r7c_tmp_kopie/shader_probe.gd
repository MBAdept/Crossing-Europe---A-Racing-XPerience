extends SceneTree
## R7c scratch probe (never committed): compiles and draws every prop material class once under Xvfb.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ModelDB.load_manifest()
	var mats := ModernMaterials.new()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 3, 12)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var x := -8.0
	for sid: String in ["props/tree_oak", "props/city_paris_haussmann", "props/wind_turbine", "props/farmhouse"]:
		for lod: String in ["lod0", "lod1"]:
			for p: Variant in ModelFactory.multimesh_parts(sid, lod, mats):
				var part: Dictionary = p
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.use_custom_data = true
				mm.mesh = part["mesh"]
				mm.instance_count = 1
				mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.2), Vector3(x, 0, 0)))
				mm.set_instance_color(0, Color.WHITE)
				mm.set_instance_custom_data(0, Color(1, 1, 1, 1.5))
				var mi := MultiMeshInstance3D.new()
				mi.multimesh = mm
				root.add_child(mi)
		x += 4.0
	var lib := PropLibrary.new()
	lib.request(["props/tree_oak"], self)
	while lib.pending() > 0:
		await process_frame
	for p: Variant in lib.mesh_parts("props/tree_oak", PropLibrary.IMPOSTOR):
		var mi := MeshInstance3D.new()
		mi.mesh = (p as Dictionary)["mesh"]
		mi.material_override = (p as Dictionary)["material"]
		mi.position = Vector3(6, 0, 0)
		root.add_child(mi)
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/shots/probe.png")
	print("PROBE OK")
	lib.clear(self)
	ModelDB.release_all()
	quit(0)
