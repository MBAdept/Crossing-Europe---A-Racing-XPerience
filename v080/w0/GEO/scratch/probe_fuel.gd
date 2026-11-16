extends SceneTree
## Scratch: targets on the fuel lane (+7.5 m) – per distance, whole network, camera in every lane and on the fuel lane.

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var proj := Fair.make_projection(cfg)
	var envs := Fair.envelopes(cfg)
	var cam := Fair.make_camera(cfg, proj)
	var sets := {
		"fuel target, cam in the lanes": {"cam_lats": [-3.75, 0.0, 3.75], "lats": [7.5]},
		"fuel target, cam on the fuel lane": {"cam_lats": [7.5], "lats": [7.5]},
		"lane targets, cam on the fuel lane": {"cam_lats": [7.5], "lats": [-3.75, 0.0, 3.75]},
	}
	var total := {}
	var samples := {}
	var worst := {}
	for key: String in sets:
		total[key] = {}
		samples[key] = 0
		worst[key] = {"normal": 0.0, "rain": 0.0, "snow": 0.0}
	for dir: Dictionary in Fair.directions(net, []):
		var geo := Fair.build_geo(cfg, net, dir)
		var profiles := {}
		for w: String in Fair.WEATHERS:
			profiles[w] = Fair.speed_profile(geo, envs[w])
		for key: String in sets:
			var o: Dictionary = (sets[key] as Dictionary).duplicate()
			o["near_from"] = 15
			o["near_step"] = 15
			o["check_every"] = 1 << 40
			var r := Fair.scan_frustum(geo, cam, proj, profiles, envs, o)
			samples[key] = int(samples[key]) + int(r["samples"])
			for d: int in (r["cases"] as Dictionary):
				total[key][d] = int(total[key].get(d, 0)) + int(r["cases"][d])
			for w: String in Fair.WEATHERS:
				worst[key][w] = maxf(float(worst[key][w]), float(r["worst"][w]["ratio"]))
	for key: String in sets:
		var ds: Array = (total[key] as Dictionary).keys()
		ds.sort()
		var txt := ""
		for d: int in ds:
			if d <= 330:
				txt += "%d:%d " % [d, int(total[key][d])]
		print("FUEL %s: %d samples; cases by d (<= 330 m): %s; worst ratio dry %.3f rain %.3f snow %.3f" % [
			key, int(samples[key]), txt, float(worst[key]["normal"]), float(worst[key]["rain"]), float(worst[key]["snow"])])
	quit(0)
