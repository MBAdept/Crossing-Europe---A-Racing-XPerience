extends SceneTree
## FLACKER-NACHSTELLEN (scratch): paint codes of the vehicle meshes per level – area (m²) of the triangles per code
## (COLOR.a: 0 paint, 0.25 paint2, 0.5 paint3, 1 fixed, lamps by UV2) and per surface class, and the albedo of the
## fixed-colour triangles weighted by area. Headless. Args: --models=traffic/hatch,traffic/wagon

func _initialize() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	var out := {}
	for mid: String in str(args.get("models", "traffic/hatch,traffic/wagon,traffic/sedan,traffic/truck")).split(","):
		var md: Dictionary = man["models"][mid]
		var res := {}
		for l: Dictionary in md["lods"]:
			var lev := {}
			for p: Dictionary in l["parts"]:
				if p.has("wheel"):
					continue
				var mesh: ArrayMesh = load("res://assets/models/" + str(p["mesh"]))
				if mesh == null:
					lev[str(p["mesh"])] = "missing"
					continue
				for s in mesh.get_surface_count():
					var arr := mesh.surface_get_arrays(s)
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
					var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
					var cls := mesh.surface_get_name(s)
					var areas := {}
					var n_tri := idx.size() / 3 if idx.size() > 0 else v.size() / 3
					for t in n_tri:
						var i0 := idx[t * 3] if idx.size() > 0 else t * 3
						var i1 := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
						var i2 := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
						var area := 0.5 * (v[i1] - v[i0]).cross(v[i2] - v[i0]).length()
						# flat varyings take the provoking vertex: Godot/GL uses the last vertex of the triangle
						var code := c[i2].a if c.size() > 0 else -1.0
						var lamp := uv2[i2].x >= 0.0 if uv2.size() > 0 else false
						var key := "lamp" if lamp else ("paint" if code < 0.125 else ("paint2" if code < 0.375 else ("paint3" if code < 0.75 else "fixed")))
						areas[key] = float(areas.get(key, 0.0)) + area
					var rounded := {}
					for k: String in areas:
						rounded[k] = snappedf(float(areas[k]), 0.001)
					lev["%s/%s" % [str(p["node"]), cls]] = rounded
			res[str(l["name"])] = lev
		out[mid] = res
	print("CODES " + JSON.stringify(out))
	quit(0)
