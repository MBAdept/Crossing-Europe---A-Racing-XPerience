extends SceneTree
## Scratch: F1/F2 on the whole network with the camera in every lane (and targets at the roadside).

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var proj := Fair.make_projection(cfg)
	var envs := Fair.envelopes(cfg)
	var cam := Fair.make_camera(cfg, proj)
	var sets := {
		"lanes3x3": {"cam_lats": [-3.75, 0.0, 3.75], "lats": [-3.75, 0.0, 3.75]},
		"lanes2": {"cam_lats": [-1.875, 1.875], "lats": [-1.875, 1.875]},
		"fuel_lane": {"cam_lats": [-3.75, 0.0, 3.75, 7.5], "lats": [7.5]},
		"roadside": {"cam_lats": [-3.75, 0.0, 3.75], "lats": [-9.4, 9.4]},
	}
	var agg := {}
	for key: String in sets:
		agg[key] = {"samples": 0, "f1": 0, "nearest": INF, "first": INF, "worst": {"normal": 0.0, "rain": 0.0, "snow": 0.0}, "where": {}}
	var only: Array = Array(str(CliArgs.all().get("stage", "")).split(",", false))
	for dir: Dictionary in Fair.directions(net, only):
		var geo := Fair.build_geo(cfg, net, dir)
		var profiles := {}
		for w: String in Fair.WEATHERS:
			profiles[w] = Fair.speed_profile(geo, envs[w])
		for key: String in sets:
			var o: Dictionary = (sets[key] as Dictionary).duplicate()
			o["near_from"] = 15
			o["check_every"] = 1 << 40
			var r := Fair.scan_frustum(geo, cam, proj, profiles, envs, o)
			var a: Dictionary = agg[key]
			a["samples"] = int(a["samples"]) + int(r["samples"])
			a["f1"] = int(a["f1"]) + int(r["f1_cases"])
			a["nearest"] = minf(float(a["nearest"]), float(r["f1_nearest_m"]))
			for d: int in (r["cases"] as Dictionary):
				a["first"] = minf(float(a["first"]), float(d))
			for w: String in Fair.WEATHERS:
				if float(r["worst"][w]["ratio"]) > float(a["worst"][w]):
					a["worst"][w] = float(r["worst"][w]["ratio"])
					a["where"][w] = "%s km %.1f d %d" % [r["worst"][w]["name"], float(r["worst"][w]["km"]), int(r["worst"][w]["d"])]
	for key: String in sets:
		var a: Dictionary = agg[key]
		print("WIDE %-10s cam %s targets %s: %d samples, %d cases <= 270 m (nearest %s), first case at %s; worst ratio dry %.3f rain %.3f snow %.3f  %s" % [
			key, str(sets[key]["cam_lats"]), str(sets[key]["lats"]), int(a["samples"]), int(a["f1"]),
			("%.0f m" % float(a["nearest"])) if float(a["nearest"]) < INF else "-", ("%.0f m" % float(a["first"])) if float(a["first"]) < INF else "-",
			float(a["worst"]["normal"]), float(a["worst"]["rain"]), float(a["worst"]["snow"]), str(a["where"])])
	quit(0)
