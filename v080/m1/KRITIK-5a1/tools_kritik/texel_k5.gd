extends SceneTree
## KRITIK-5a1 scratch: texel density (atlas px per metre) of the baked walls of lod0 per face direction and height
## band: approach face (+Z), road side (-X), far side (+X), back (-Z); band low = y < --band (7.5 m: ground and first
## floor), high = above. Prints the area-weighted mean and the area-weighted 10th percentile per group.
##   -- --models=props/a,props/b [--band=7.5]

func _initialize() -> void:
	var models := PackedStringArray()
	var band := 7.5
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--models="):
			models = s.substr(9).split(",", false)
		elif s.begins_with("--band="):
			band = float(s.substr(7))
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	for mid: String in models:
		var m: Dictionary = man["models"][mid]
		var tex_rel := str((m.get("textures", {}) as Dictionary).get("albedo", ""))
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/models/" + tex_rel))
		var tw := float(img.get_width())
		var th := float(img.get_height())
		var lod: Dictionary = m["lods"][0]
		var bb: Array = m["aabb"]
		var outer := float(OS.get_environment("K5_OUTER")) if OS.get_environment("K5_OUTER") != "" else 1.2
		var groups := {}
		for part: Dictionary in lod["parts"]:
			var mesh := load("res://assets/models/" + str(part["mesh"])) as ArrayMesh
			for si in mesh.get_surface_count():
				if not mesh.surface_get_name(si).begins_with("baked"):
					continue
				var arr := mesh.surface_get_arrays(si)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var n := idx.size() / 3 if idx.size() > 0 else v.size() / 3
				for t in n:
					var i0 := idx[t * 3] if idx.size() > 0 else t * 3
					var i1 := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
					var i2 := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
					var a := v[i0]
					var b := v[i1]
					var c := v[i2]
					var cr := (b - a).cross(c - a)
					var wa := cr.length() * 0.5
					if wa < 1e-4:
						continue
					var nn := -cr / (wa * 2.0)   # Godot winding: front faces are clockwise
					if absf(nn.y) > 0.3:
						continue
					var dir := ""
					var ctr := (a + b + c) / 3.0
					if nn.z > 0.7 and ctr.z > float(bb[5]) - outer - 0.5: dir = "front"
					elif nn.x < -0.7 and ctr.x < float(bb[0]) + outer: dir = "road"
					elif nn.x > 0.7 and ctr.x > float(bb[3]) - outer: dir = "far"
					elif nn.z < -0.7 and ctr.z < float(bb[2]) + outer: dir = "back"
					else: continue
					var ua := uv[i0] * Vector2(tw, th)
					var ub := uv[i1] * Vector2(tw, th)
					var uc := uv[i2] * Vector2(tw, th)
					var uarea := absf((ub - ua).cross(uc - ua)) * 0.5
					var dens := sqrt(uarea / wa)
					var yc := (a.y + b.y + c.y) / 3.0
					var key := "%s_%s" % [dir, "low" if yc < band else "high"]
					var g: Array = groups.get(key, [])
					g.append(Vector2(dens, wa))
					groups[key] = g
		var line := "TEXELK5 %s atlas %dx%d" % [mid.get_file(), int(tw), int(th)]
		for key: String in ["front_low", "front_high", "road_low", "road_high", "far_low", "far_high", "back_low", "back_high"]:
			var g: Array = groups.get(key, [])
			if g.is_empty():
				continue
			g.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
			var tot := 0.0
			var s := 0.0
			for p: Vector2 in g:
				tot += p.y
				s += p.x * p.y
			var acc := 0.0
			var p10 := 0.0
			for p: Vector2 in g:
				acc += p.y
				if acc >= tot * 0.1:
					p10 = p.x
					break
			line += "  %s %.0f m2 mean %.1f p10 %.1f" % [key, tot, s / tot, p10]
		print(line)
	quit(0)
