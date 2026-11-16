extends SceneTree
## Scratch: where do F1 cases appear when camera and target are offset laterally?

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var proj := Fair.make_projection(cfg)
	var envs := Fair.envelopes(cfg)
	var names: Array = ["bukarest_sibiu__sibiu", "saragossa_pau__saragossa", "belgrad_sofia__sofia", "erfurt_kassel__kassel"]
	var geos: Array = []
	for dir: Dictionary in Fair.directions(net, names):
		var geo := Fair.build_geo(cfg, net, dir)
		var profiles := {}
		for w: String in Fair.WEATHERS:
			profiles[w] = Fair.speed_profile(geo, envs[w])
		geos.append([geo, profiles])
	for gain: float in [0.6, 0.0]:
		var cam := Fair.make_camera(cfg, proj, {"look_gain": gain})
		print("look_gain %.1f" % gain)
		for combo: Array in [[0.0, 3.75], [0.0, -3.75], [-3.75, 3.75], [3.75, -3.75], [0.0, 7.5], [0.0, 9.4], [0.0, -9.4], [-3.75, 9.4], [3.75, -9.4],
				[-1.875, 1.875], [-1.875, 7.5], [1.875, -7.5]]:
			var total := {}
			var samples := 0
			var worst_ratio := 0.0
			for g: Array in geos:
				var r := Fair.scan_frustum(g[0], cam, proj, g[1], envs, {"near_from": 15, "near_step": 15, "cam_lats": [combo[0]], "lats": [combo[1]],
					"check_every": 1 << 40})
				samples += int(r["samples"])
				for d: int in (r["cases"] as Dictionary):
					total[d] = int(total.get(d, 0)) + int(r["cases"][d])
				worst_ratio = maxf(worst_ratio, float(r["worst"]["normal"]["ratio"]))
			var ds := total.keys()
			ds.sort()
			var txt := ""
			var below := 0
			for d: int in ds:
				if d <= 270:
					below += int(total[d])
					txt += "%d:%d " % [d, int(total[d])]
			print("  cam_x %+5.2f target_x %+5.2f (rel %+5.2f): %d cases <= 270 m of %d samples; worst F2 ratio dry %.3f; by d: %s" % [combo[0], combo[1],
				float(combo[1]) - float(combo[0]), below, samples, worst_ratio, txt])
	quit(0)
