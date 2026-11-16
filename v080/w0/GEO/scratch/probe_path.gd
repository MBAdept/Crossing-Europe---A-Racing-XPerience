extends SceneTree
## Scratch: compare the path scan with / without city data and against the study's pair loop.

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	for with_city in [true, false]:
		var net2 := net.duplicate()
		if not with_city:
			net2["city_db"] = {}
		for dir: Dictionary in Fair.directions(net2, ["saragossa_pau", "bukarest_sibiu"]):
			var geo := Fair.build_geo(cfg, net2, dir)
			var p := Fair.scan_path(geo)
			# the study's loop: points every 4 segments, pairs 30..158 points apart
			var xs: PackedFloat64Array = geo["x"]
			var zs: PackedFloat64Array = geo["z"]
			var n: int = geo["n"]
			var m := (n + 3) / 4
			var best := INF
			var bi := 0
			var bk := 0
			for k in range(30, 159):
				for i in range(0, m - k):
					var dx := xs[(i + k) * 4] - xs[i * 4]
					var dz := zs[(i + k) * 4] - zs[i * 4]
					var d2 := dx * dx + dz * dz
					if d2 < best:
						best = d2
						bi = i
						bk = k
			var cmax := 0.0
			for c in (geo["curve"] as PackedFloat32Array):
				cmax = maxf(cmax, absf(c))
			print("%s city=%s n=%d grid min %.2f (km %.1f sep %.0f) | pair loop min %.2f at i=%d (km %.1f) sep %d m | max curve %.3f minR %.0f | length_km %.1f seed %d" % [
				geo["name"], with_city, n, float(p["min_m"]), float(p["min_km"]), float(p["min_sep_m"]), sqrt(best), bi, float(bi) * 12.0 * float(geo["km_per_m"]), bk * 12,
				cmax, 120.0 / cmax, (geo["plan"] as StagePlan).length_km, (geo["plan"] as StagePlan).seed])
	quit(0)
