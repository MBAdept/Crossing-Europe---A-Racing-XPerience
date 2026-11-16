extends SceneTree
# scratch: ModelFactory smoke test without a window - every model set at every level, MultiMesh parts, impostor
func _initialize() -> void:
	var mats := ModernMaterials.new()
	var errors := 0
	for sid in ModelDB.set_ids():
		var r := ModelDB.resolve(sid)
		if (r["model"] as Dictionary).is_empty():
			if ModelFactory.build(sid, "lod0", mats) != null:
				print("FEHLER: Platzhalter-Set baut einen Knoten: ", sid)
				errors += 1
			continue
		var m: Dictionary = r["model"]
		var line := "%-22s" % sid
		for l: Variant in m.get("lods", []):
			var ln := str((l as Dictionary)["name"])
			var node := ModelFactory.build(sid, ln, mats)
			var parts := ModelFactory.multimesh_parts(sid, ln, mats)
			var parts_plain := ModelFactory.multimesh_parts(sid, ln)
			if node == null or parts.is_empty() or parts.size() != parts_plain.size():
				print("FEHLER: ", sid, " ", ln)
				errors += 1
				continue
			var wheels: Array = node.get_meta("wheels", [])
			var shadow := node.get_node_or_null("shadow") != null
			var mat_ok := true
			for p: Variant in parts:
				var mesh: ArrayMesh = (p as Dictionary)["mesh"]
				for s in mesh.get_surface_count():
					if mesh.surface_get_material(s) == null:
						mat_ok = false
			line += "  %s: %d Knoten, %d Räder%s, %d MultiMesh-Teile%s" % [ln, node.get_child_count(), wheels.size(),
				", Schatten" if shadow else "", parts.size(), "" if mat_ok else " (Material fehlt!)"]
			if not mat_ok:
				errors += 1
			node.free()
		var imp := ModelFactory.build_impostor(sid, mats)
		if m.has("impostor"):
			line += "  Fernbild %s" % ("ok" if imp != null else "FEHLT")
			if imp == null:
				errors += 1
		if imp != null:
			imp.free()
		print(line)
	print("ModelFactory: ", "OK" if errors == 0 else "%d FEHLER" % errors, ", Materialien: ", mats.all_materials().size())
	quit(0 if errors == 0 else 1)
