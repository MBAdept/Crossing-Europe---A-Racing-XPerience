extends SceneTree
## QA: where do the light anchors of the manifest lie relative to the surface of lod0? (flares, pools)

func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


func _initialize() -> void:
	for mid in ModelDB.model_ids():
		var m := ModelDB.model(mid)
		var lights: Array = m.get("lights", [])
		if lights.is_empty():
			continue
		var faces := PackedVector3Array()
		for p: Variant in ModelDB.lod(m, "lod0").get("parts", []):
			var part: Dictionary = p
			var mesh := ModelDB.mesh(str(part["mesh"]))
			var xf := ModelFactory.part_transform(part)
			for v in mesh.get_faces():
				faces.append(xf * v)
		var bb: Array = m.get("aabb", [])
		print("== %s  (%d Dreiecke, aabb %s)" % [mid, faces.size() / 3, str(bb)])
		for l: Variant in lights:
			var ld: Dictionary = l
			var lp: Array = ld["pos"]
			var p := Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
			var best := INF
			var bestq := Vector3.ZERO
			var bestn := Vector3.ZERO
			var i := 0
			while i + 2 < faces.size():
				var q := _closest_on_tri(p, faces[i], faces[i + 1], faces[i + 2])
				var d := p.distance_to(q)
				if d < best:
					best = d
					bestq = q
					# Godot: clockwise front faces
					bestn = -(faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).normalized()
				i += 3
			# inside test: parity of crossings along three directions (majority)
			var inside_votes := 0
			for dir: Vector3 in [Vector3(0.577, 0.577, 0.577).normalized(), Vector3(-0.3, 0.9, 0.2).normalized(), Vector3(0.1, 0.2, 0.97).normalized()]:
				var hits := 0
				var k := 0
				while k + 2 < faces.size():
					var r: Variant = Geometry3D.ray_intersects_triangle(p, dir, faces[k], faces[k + 1], faces[k + 2])
					if r != null:
						hits += 1
					k += 3
				if hits % 2 == 1:
					inside_votes += 1
			var side := (p - bestq).dot(bestn)
			var out_of_box := ""
			if bb.size() == 6:
				if p.x < float(bb[0]) - 0.001 or p.x > float(bb[3]) + 0.001 or p.y < float(bb[1]) - 0.001 or p.y > float(bb[4]) + 0.001 or p.z < float(bb[2]) - 0.001 or p.z > float(bb[5]) + 0.001:
					out_of_box = "  AUSSERHALB DER HÜLLE"
			print("   %-8s pos (%7.3f %6.3f %7.3f) size %.3f  nächste Fläche %.1f mm  %s  (Paritätstest innen: %d/3)%s" % [str(ld["role"]), p.x, p.y, p.z, float(ld["size"]), best * 1000.0,
				"unter der Fläche" if side < 0.0 else "über der Fläche", inside_votes, out_of_box])
	quit(0)
