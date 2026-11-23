extends SceneTree
## R7c scratch probe (never committed): GPU cost (llvmpipe frame time) of a city house drawn with its whole facade
## as baked_cutout (alpha test, both faces) against the same mesh drawn opaque (baked, back faces culled).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ModelDB.load_manifest()
	var mats := ModernMaterials.new()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 8, 30)
	cam.look_at(Vector3(0, 6, -20))
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	for sid: String in ["props/city_paris_haussmann", "props/city_french_sud"]:
		var parts := ModelFactory.multimesh_parts(sid, "lod0", mats)
		var mesh: Mesh = (parts[0] as Dictionary)["mesh"]
		var model := ModelDB.model(sid)
		var res := {}
		for mode: String in ["cutout", "opaque", "cutout", "opaque"]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = 24
			for i in 24:
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(i % 6) * 22.0 - 55.0, 0, -float(i / 6) * 18.0)))
				mm.set_instance_color(i, Color.WHITE)
				mm.set_instance_custom_data(i, Color(1, 1, 1, 1.5))
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			if mode == "opaque":
				# the same mesh with every cut-out surface drawn by the opaque class (no alpha test, back faces culled)
				var dup := mesh.duplicate() as ArrayMesh
				for s in dup.get_surface_count():
					if str(dup.surface_get_name(s)) == "baked_cutout":
						dup.surface_set_material(s, mats.material("baked", model))
				mm.mesh = dup
			root.add_child(mi)
			for i in 10:
				await process_frame
			var t0 := Time.get_ticks_usec()
			var n := 40
			for i in n:
				await RenderingServer.frame_post_draw
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
			res[mode] = res.get(mode, []) + [snappedf(ms, 0.1)]
			mi.free()
		print("CUTOUT-COST %s %s" % [sid, str(res)])
	ModelDB.release_all()
	quit(0)
