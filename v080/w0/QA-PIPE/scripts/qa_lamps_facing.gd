extends SceneTree
## QA: per lamp channel of the vehicle bodies: area at the rear / front end and how much of it faces backwards,
## forwards or sideways (area-weighted geometric normals).
const CH: Array[String] = ["tail", "brake", "tail_brake", "ind_l", "ind_r", "head", "drl", "reverse", "plate"]
func _initialize() -> void:
	for f: String in ["traffic/sedan/lod0_body.res", "traffic/sedan/lod1_body.res", "traffic/sedan/lod2_body.res", "player/limousine/lod0_body.res"]:
		var mesh := load("res://assets/models/" + f) as ArrayMesh
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var u2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var acc := {}
		var t := 0
		while t + 2 < idx.size():
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			t += 3
			if u2[a].x < 0.0:
				continue
			var ch := int(floor(u2[a].x))
			var g := -(v[b] - v[a]).cross(v[c] - v[a])        # clockwise front faces
			var ar := g.length() * 0.5
			if ar <= 0.0:
				continue
			var n := g.normalized()
			var cen := (v[a] + v[b] + v[c]) / 3.0
			var key := "%d|%s" % [ch, "rear" if cen.z > 0.0 else "front"]
			var e: Dictionary = acc.get(key, {"area": 0.0, "back": 0.0, "fwd": 0.0, "side": 0.0, "up": 0.0, "zmin": INF, "zmax": -INF, "seen_back": 0.0, "seen_front": 0.0})
			e["area"] += ar
			e["back"] += ar * maxf(n.z, 0.0)          # projected area seen from straight behind
			e["fwd"] += ar * maxf(-n.z, 0.0)
			e["side"] += ar * absf(n.x)
			e["zmin"] = minf(e["zmin"], minf(v[a].z, minf(v[b].z, v[c].z)))
			e["zmax"] = maxf(e["zmax"], maxf(v[a].z, maxf(v[b].z, v[c].z)))
			acc[key] = e
		print("== ", f)
		var keys: Array = acc.keys()
		keys.sort()
		for k: String in keys:
			var e: Dictionary = acc[k]
			var ch := int(k.get_slice("|", 0))
			var endname := k.get_slice("|", 1)
			print("   %-10s %-5s area %7.1f cm2 | projected area seen from straight behind %7.1f cm2, from straight ahead %7.1f cm2, from the side %7.1f cm2 | z %.3f .. %.3f" % [
				CH[ch] if ch < CH.size() else str(ch), endname, e["area"] * 1e4, e["back"] * 1e4, e["fwd"] * 1e4, e["side"] * 1e4, e["zmin"], e["zmax"]])
	quit(0)
