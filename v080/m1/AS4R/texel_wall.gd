extends SceneTree
## AS4R scratch: texel density of the faces of one wall plane only: --model=props/factory --axis=0 --at=-17 --tol=0.05
func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and s.contains("="):
			a[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	var mid := str(a.get("model", "props/factory"))
	var axis := int(a.get("axis", "0"))
	var at := float(a.get("at", "-17"))
	var tol := float(a.get("tol", "0.05"))
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	var m: Dictionary = man["models"][mid]
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/models/" + str(m["textures"]["albedo"])))
	var tw := float(img.get_width())
	var th := float(img.get_height())
	var mesh := load("res://assets/models/" + str(m["lods"][0]["parts"][0]["mesh"])) as ArrayMesh
	var area_w := 0.0
	var area_uv := 0.0
	for si in mesh.get_surface_count():
		if not mesh.surface_get_name(si).begins_with("baked"):
			continue
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var p0 := v[idx[t * 3]]
			var p1 := v[idx[t * 3 + 1]]
			var p2 := v[idx[t * 3 + 2]]
			if absf(p0[axis] - at) > tol or absf(p1[axis] - at) > tol or absf(p2[axis] - at) > tol:
				continue
			area_w += (p1 - p0).cross(p2 - p0).length() * 0.5
			var u0 := uv[idx[t * 3]] * Vector2(tw, th)
			var u1 := uv[idx[t * 3 + 1]] * Vector2(tw, th)
			var u2 := uv[idx[t * 3 + 2]] * Vector2(tw, th)
			area_uv += absf((u1 - u0).cross(u2 - u0)) * 0.5
	print("WAND %s Achse %d bei %.2f: %.1f m², %.1f px/m" % [mid, axis, at, area_w, sqrt(area_uv / maxf(1e-6, area_w))])
	quit(0)
