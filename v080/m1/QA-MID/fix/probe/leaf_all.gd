extends SceneTree
func _initialize() -> void:
	var dir := DirAccess.open("res://assets/models/props")
	for d in dir.get_directories():
		var mp := "res://assets/models/props/%s/model.json" % d
		if not FileAccess.file_exists(mp):
			continue
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(mp))
		var m: Dictionary = j.get("model", {})
		var tex: Dictionary = m.get("textures", {})
		if not tex.has("leaves"):
			continue
		var outs := []
		for lod: Dictionary in m.get("lods", []):
			for part: Dictionary in lod.get("parts", []):
				var classes: Array = part.get("classes", [])
				var mesh: Mesh = load("res://assets/models/" + str(part["mesh"]))
				for s in mesh.get_surface_count():
					var cls := str(mesh.surface_get_name(s))
					if cls == "" and s < classes.size():
						cls = str(classes[s])
					if cls != "leaves":
						continue
					var arr := mesh.surface_get_arrays(s)
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					var tot := 0.0
					var ks := 0.0
					for t in idx.size() / 3:
						var a := v[idx[t * 3]]
						var b := v[idx[t * 3 + 1]]
						var c := v[idx[t * 3 + 2]]
						var area := (b - a).cross(c - a).length() * 0.5
						var up := (n[idx[t * 3]].y + n[idx[t * 3 + 1]].y + n[idx[t * 3 + 2]].y) / 3.0
						tot += area
						ks += smoothstep(0.35, 0.85, up) * 0.85 * area
					outs.append("%s %.2f" % [lod["name"], ks / maxf(tot, 1e-9)])
		print("%-28s %-40s %s" % [d, str(tex["leaves"]), "  ".join(outs)])
	quit(0)
