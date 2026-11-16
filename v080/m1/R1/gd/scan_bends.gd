extends SceneTree
# Scratch: curvature at S1 and candidate bends (R ~ 400 m over >= 150 m, R ~ 136 m over >= 100 m).
const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	print("R1 = ", r1)
	for name: String in ["kiel_hamburg__kiel", "saragossa_pau__saragossa", "kassel_wuerzburg__kassel", "hamburg_hannover__hamburg"]:
		var dirs := Fair.directions(net, [name])
		if dirs.is_empty():
			print("keine Richtung ", name)
			continue
		var geo := Fair.build_geo(cfg, net, dirs[0])
		var track: Track = geo["track"]
		var curve: PackedFloat32Array = geo["curve"]
		var n := int(geo["nz"])
		if name == "kiel_hamburg__kiel":
			var k0 := int(track.km_to_z(2.0) / 3.0)
			var s := ""
			for k in range(k0 - 5, k0 + 80, 5):
				s += "%.2f " % curve[k]
			print("S1 km2 seg ", k0, " curves: ", s)
		# runs of nearly constant curvature
		for target: Array in [[r1 / 400.0, 50, 0.06], [r1 / 136.0, 34, 0.1]]:
			var want: float = target[0]
			var need: int = target[1]
			var tol: float = target[2]
			var found := 0
			var k := 0
			while k < n - need and found < 4:
				var ok := true
				for j in need:
					if absf(absf(curve[k + j]) - want) > tol or signf(curve[k + j]) != signf(curve[k]):
						ok = false
						break
				if ok:
					print("%s: |curve| %.2f (R %.0f m) ab Segment %d = km %.2f, Vorzeichen %d" % [name, want, r1 / want, k, track.z_to_km(float(k) * 3.0), int(signf(curve[k]))])
					found += 1
					k += need * 3
				else:
					k += 1
	quit(0)
