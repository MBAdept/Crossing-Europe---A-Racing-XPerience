extends SceneTree
## AS4R scratch: which triangles of a baked model sample a lit texel of its emission atlas (at the UV centroid)?
##   godot --headless --path . -s res://tools/kritik/emit_probe.gd -- --model=props/factory --lod=lod0 [--thr=0.3]

func _initialize() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and s.contains("="):
			a[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	var mid := str(a.get("model", "props/factory"))
	var lod := str(a.get("lod", "lod0"))
	var thr := float(a.get("thr", "0.3"))
	var root := "res://assets/models/" + mid + "/"
	var img := Image.load_from_file(ProjectSettings.globalize_path(root + "emit.png"))
	var mesh := load(root + lod + "_body.res") as ArrayMesh
	var groups := {}
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var name := mesh.surface_get_name(si)
		if not name.begins_with("baked"):
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var n := idx.size() / 3
		for t in n:
			var i0 := idx[t * 3]
			var i1 := idx[t * 3 + 1]
			var i2 := idx[t * 3 + 2]
			var c := (uv[i0] + uv[i1] + uv[i2]) / 3.0
			var px := Vector2i(clampi(int(c.x * img.get_width()), 0, img.get_width() - 1), clampi(int(c.y * img.get_height()), 0, img.get_height() - 1))
			var col := img.get_pixelv(px)
			if maxf(col.r, maxf(col.g, col.b)) < thr:
				continue
			var p := (v[i0] + v[i1] + v[i2]) / 3.0
			var nn := (nrm[i0] + nrm[i1] + nrm[i2]).normalized()
			var key := "%s n=(%.1f,%.1f,%.1f)" % [name, nn.x, nn.y, nn.z]
			var g: Array = groups.get(key, [0, 0.0, Vector3.ZERO, Vector3(1e9, 1e9, 1e9), Vector3(-1e9, -1e9, -1e9), col])
			g[0] += 1
			g[2] += p
			g[3] = Vector3(minf(g[3].x, p.x), minf(g[3].y, p.y), minf(g[3].z, p.z))
			g[4] = Vector3(maxf(g[4].x, p.x), maxf(g[4].y, p.y), maxf(g[4].z, p.z))
			groups[key] = g
	for k: String in groups:
		var g: Array = groups[k]
		print("LIT %s tris %d centre %s min %s max %s col %s" % [k, g[0], str(g[2] / float(g[0])), str(g[3]), str(g[4]), str(g[5])])
	quit(0)
