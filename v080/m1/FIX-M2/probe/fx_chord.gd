extends SceneTree
## FIX-M2 study for B-01 (headless): which chord does the sight corridor of a bend need for fairness rule F2?
## F2: stopping sight distance at the fastest drivable speed <= 0.6 x the distance at which Modern shows the target.
## A tree on the inside of a bend at m metres beyond the paved edge first blocks the line of sight to a car on the
## road at the chord c = sqrt(8 m / k_edge). So the corridor keeps F2 when its chord is at least
## c_req = need / 0.6 + CAM_BACK (the camera stands that far behind the car). For every row of every stage direction
## where that chord's sagitta is wider than the plain corridor (corridor_min_m), this prints the distribution of c_req
## (per weather) and the worst rows.
##   godot --headless --path . -s <this> [-- --stage=<id>,…]

const Fair := preload("res://tests/race3d/fairness.gd")
const CAM_BACK := 9.0
const RATIO := 0.6


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			only = Array(a.substr(8).split(",", false))
	var dirs := Fair.directions(net, only)
	var envs := Fair.envelopes(cfg)
	var corr_min := float(ConfigLoader.lookup(cfg, "graphics.modern.terrain.corridor_min_m", 8.0))
	var half_road := 5.625
	var vals := {}
	var worst := {}
	for w: String in Fair.WEATHERS:
		vals[w] = []
		worst[w] = []
	for dir: Dictionary in dirs:
		var geo := Fair.build_geo(cfg, net, dir)
		var n := int(geo["nz"])
		var seg := float(geo["seg"])
		var th: PackedFloat64Array = geo["th"]
		# curvature per boundary from the integrated headings (1/m)
		var k := PackedFloat32Array()
		k.resize(n)
		for i in range(1, n - 1):
			k[i] = absf(angle_difference(th[i - 1], th[i + 1])) / (2.0 * seg)
		var kmx := 0.0
		for i in range(1, n - 1):
			kmx = maxf(kmx, k[i])
		print("FX-DIR %s n=%d seg=%.1f kmax=%.5f (R %.0f m)" % [str(dir["name"]), n, seg, kmx, 1.0 / maxf(kmx, 1e-6)])
		for w: String in Fair.WEATHERS:
			var prof := Fair.speed_profile(geo, envs[w])
			var need: PackedFloat64Array = prof["need"]
			var v: PackedFloat64Array = prof["v"]
			var im := 0
			for i in range(1, n - 1):
				if k[i] > k[im]:
					im = i
			print("  %s apex row %d: v %.1f km/h need %.1f m c_req %.1f sag %.1f" % [w, im, v[im] * 3.6, need[im], need[im] / RATIO + CAM_BACK,
				pow(need[im] / RATIO + CAM_BACK, 2.0) * 0.125 * k[im]])
			for at: String in _ats():
				var parts := at.split(":")
				if parts[0] == str(dir["name"]):
					var kpm := float(geo["km_per_m"])
					var i0 := int(float(parts[1]) / kpm / seg)
					var i1 := int(float(parts[2]) / kpm / seg)
					var cmax := 0.0
					var vmax := 0.0
					for i in range(i0, mini(i1, n - 1)):
						cmax = maxf(cmax, need[i] / RATIO + CAM_BACK)
						vmax = maxf(vmax, v[i] * 3.6)
					print("FX-AT %s %s km %s–%s: c_req max %.0f m, v max %.0f km/h" % [w, parts[0], parts[1], parts[2], cmax, vmax])
			for i in range(1, n - 1):
				var c_req := need[i] / RATIO + CAM_BACK
				var half := int(ceil(c_req * 0.5 / seg))
				var kmax := 0.0
				for j in range(maxi(1, i - half), mini(n - 1, i + half + 1)):
					kmax = maxf(kmax, k[j])
				if kmax < 1.0e-5:
					continue
				var k_edge := kmax / maxf(0.05, 1.0 - kmax * half_road)
				if c_req * c_req * 0.125 * k_edge <= corr_min:
					continue
				(vals[w] as Array).append(c_req)
				var wl: Array = worst[w]
				if wl.size() < 400 or c_req > float((wl[wl.size() - 1] as Array)[0]):
					wl.append([c_req, str(dir["name"]), snappedf(float(i) * seg / 1000.0, 0.01), snappedf(v[i] * 3.6, 0.1),
						snappedf(1.0 / k_edge, 1.0), snappedf(c_req * c_req * 0.125 * k_edge, 0.1)])
					wl.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
					if wl.size() > 400:
						wl.resize(400)
		geo["path"] = null
	for w: String in Fair.WEATHERS:
		var a := PackedFloat32Array(vals[w] as Array)
		a.sort()
		var cnt := a.size()
		if cnt == 0:
			print("FX-CHORD %s keine Reihe" % w)
			continue
		print("FX-CHORD %s rows=%d p50=%.0f p90=%.0f p99=%.0f max=%.0f m (share > 150 m: %.2f %%, > 200 m: %.2f %%, > 300 m: %.2f %%)" % [w, cnt,
			a[cnt / 2], a[int(cnt * 0.9)], a[int(cnt * 0.99)], a[cnt - 1],
			100.0 * float(_count_above(a, 150.0)) / float(cnt), 100.0 * float(_count_above(a, 200.0)) / float(cnt),
			100.0 * float(_count_above(a, 300.0)) / float(cnt)])
		var wl: Array = worst[w]
		for e: Array in wl.slice(0, 8):
			print("  worst %s: c_req %.0f m at %s km %.2f, %.0f km/h, R_edge %.0f m, sagitta %.1f m" % [w, float(e[0]), e[1], float(e[2]), float(e[3]), float(e[4]), float(e[5])])
	quit(0)


static func _ats() -> Array:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			return Array(a.substr(5).split(",", false))
	return []


static func _count_above(a: PackedFloat32Array, lim: float) -> int:
	var n := 0
	for x in a:
		if x > lim:
			n += 1
	return n
