extends SceneTree
# micro benchmark: GDScript loop with a ray/normal crossing
func _initialize() -> void:
	var n := 2000
	var px := PackedFloat64Array()
	var pz := PackedFloat64Array()
	var th := PackedFloat64Array()
	px.resize(n)
	pz.resize(n)
	th.resize(n)
	var a := 0.0
	var x := 0.0
	var z := 0.0
	for i in n:
		px[i] = x
		pz[i] = z
		th[i] = a
		a += 0.01
		x += sin(a) * 3.0
		z -= cos(a) * 3.0
	var env := PackedFloat32Array()
	env.resize(n)
	var t0 := Time.get_ticks_usec()
	var it := 0
	for c in range(0, n - 120):
		var cx := px[c]
		var cz := pz[c]
		var fx := sin(th[c])
		var fz := -cos(th[c])
		var rx := cos(th[c])
		var rz := sin(th[c])
		var best := -10.0
		for d in range(100, 0, -1):
			var j := c + d
			var vx := px[j] - cx
			var vz := pz[j] - cz
			var b := atan2(vx * rx + vz * rz, vx * fx + vz * fz)
			if b > best:
				best = b
			var ux := fx * cos(best) + rx * sin(best)
			var uz := fz * cos(best) + rz * sin(best)
			var njx := cos(th[j])
			var njz := sin(th[j])
			var den := njx * uz - njz * ux
			if absf(den) > 1e-6:
				var t := ((cx - px[j]) * uz - (cz - pz[j]) * ux) / den
				if t > env[j]:
					env[j] = t
			it += 1
	var us := Time.get_ticks_usec() - t0
	print("BENCH iterations=%d total=%.1f ms per_it=%.3f us" % [it, us / 1000.0, float(us) / float(it)])
	quit(0)
