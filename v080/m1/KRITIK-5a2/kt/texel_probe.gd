extends SceneTree
## KRITIK-4 scratch: texel density (atlas px per metre) of the baked surface(s) of models, per face direction:
## +Z approach face, -X road side (right-hand placement), +X far side, -Z back, roof (n.y > 0.5), other.
##   -- --models=props/a,props/b

func _initialize() -> void:
	var models := PackedStringArray()
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--models="):
			models = s.substr(9).split(",", false)
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	for mid: String in models:
		var m: Dictionary = man["models"][mid]
		var tex_rel := str((m.get("textures", {}) as Dictionary).get("albedo", ""))
		if tex_rel == "":
			print("TEXEL %s: kein Atlas" % mid)
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/models/" + tex_rel))
		var tw := float(img.get_width())
		var th := float(img.get_height())
		for lod: Dictionary in m["lods"]:
			for part: Dictionary in lod["parts"]:
				var mesh := load("res://assets/models/" + str(part["mesh"])) as ArrayMesh
				for si in mesh.get_surface_count():
					var sname := mesh.surface_get_name(si)
					if not sname.begins_with("baked"):
						continue
					var arr := mesh.surface_get_arrays(si)
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					var groups := {}
					for t in range(0, idx.size(), 3):
						var a := v[idx[t]]
						var b := v[idx[t + 1]]
						var c := v[idx[t + 2]]
						var n := (b - a).cross(c - a)
						var wa := n.length() * 0.5
						if wa < 1e-6:
							continue
						n = n.normalized()
						var ua := uv[idx[t]] * Vector2(tw, th)
						var ub := uv[idx[t + 1]] * Vector2(tw, th)
						var uc := uv[idx[t + 2]] * Vector2(tw, th)
						var ta := absf((ub - ua).cross(uc - ua)) * 0.5
						var g := "sonst"
						if n.y > 0.5:
							g = "Dach"
						elif n.y < -0.5:
							g = "unten"
						elif n.z > 0.7:
							g = "Anfahrt+Z"
						elif n.z < -0.7:
							g = "Rueck-Z"
						elif n.x < -0.7:
							g = "Strasse-X"
						elif n.x > 0.7:
							g = "fern+X"
						var e: Array = groups.get(g, [0.0, 0.0])
						e[0] = float(e[0]) + wa
						e[1] = float(e[1]) + ta
						groups[g] = e
					var line: Array[String] = []
					for g: String in ["Anfahrt+Z", "Strasse-X", "fern+X", "Rueck-Z", "Dach", "sonst", "unten"]:
						if groups.has(g):
							var e: Array = groups[g]
							line.append("%s %.1f px/m (%.0f m²)" % [g, sqrt(float(e[1]) / maxf(1e-6, float(e[0]))), float(e[0])])
					print("TEXEL %s %s %s atlas %dx%d: %s" % [mid, str(lod["name"]), sname, int(tw), int(th), "  ".join(line)])
	quit(0)
