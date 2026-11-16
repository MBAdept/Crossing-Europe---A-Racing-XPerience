extends SceneTree
## KRITIK-4 scratch: vertex statistics of a baked mesh.  -- --mesh=res://...res [--ymax=2 --zmin=15] [--box=x0,x1,y0,y1,z0,z1]

func _initialize() -> void:
	var a := {}
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var mesh := load(str(a.get("mesh", ""))) as ArrayMesh
	if mesh == null:
		print("PROBE kein Netz")
		quit(1)
		return
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var bb := AABB(v[0], Vector3.ZERO)
		for p in v:
			bb = bb.expand(p)
		print("PROBE surface %d %s: %d vertices, %d triangles, aabb %s" % [si, mesh.surface_get_name(si), v.size(), idx.size() / 3, str(bb)])
		if a.has("box"):
			var b := str(a["box"]).split(",")
			var n := 0
			var sel := AABB()
			var first := true
			var lamps := {}
			for i in v.size():
				var p := v[i]
				if p.x >= float(b[0]) and p.x <= float(b[1]) and p.y >= float(b[2]) and p.y <= float(b[3]) and p.z >= float(b[4]) and p.z <= float(b[5]):
					n += 1
					if first:
						sel = AABB(p, Vector3.ZERO)
						first = false
					else:
						sel = sel.expand(p)
					if uv2.size() > i:
						var ch := int(floor(uv2[i].x))
						lamps[ch] = int(lamps.get(ch, 0)) + 1
			print("PROBE   box %s: %d vertices, aabb %s, lamp channels %s" % [str(a["box"]), n, str(sel), str(lamps)])
		if a.has("lamps") and uv2.size() == v.size():
			# colours of each lamp channel: count, mean colour, weight range
			var by := {}
			for i in v.size():
				var ch := int(floor(uv2[i].x))
				if ch < 0:
					continue
				var e: Array = by.get(ch, [0, Vector3.ZERO, 9.0, -9.0])
				e[0] = int(e[0]) + 1
				if col.size() > i:
					e[1] = (e[1] as Vector3) + Vector3(col[i].r, col[i].g, col[i].b)
				e[2] = minf(float(e[2]), uv2[i].y)
				e[3] = maxf(float(e[3]), uv2[i].y)
				by[ch] = e
			for ch: int in by:
				var e: Array = by[ch]
				var m: Vector3 = (e[1] as Vector3) / float(maxi(1, int(e[0])))
				print("PROBE   channel %d: %d vertices, mean colour (%d,%d,%d), weight %.2f..%.2f" % [ch, int(e[0]),
					int(m.x * 255.0), int(m.y * 255.0), int(m.z * 255.0), float(e[2]), float(e[3])])
			# colours of the non-lamp vertices with low roughness (glass)
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var gs := Vector3.ZERO
			var gn := 0
			for i in v.size():
				if uv2[i].x < 0.0 and uv.size() > i and uv[i].x < 0.3 and col.size() > i:
					gs += Vector3(col[i].r, col[i].g, col[i].b)
					gn += 1
			if gn > 0:
				gs /= float(gn)
				print("PROBE   glass (roughness < 0.3, no lamp): %d vertices, mean colour (%d,%d,%d)" % [gn, int(gs.x * 255.0), int(gs.y * 255.0), int(gs.z * 255.0)])
	quit(0)
