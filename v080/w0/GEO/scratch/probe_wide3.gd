extends SceneTree
## Scratch: roadside targets (signs at +-9.4 m) – per distance, whole network.

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var proj := Fair.make_projection(cfg)
	var envs := Fair.envelopes(cfg)
	var cam := Fair.make_camera(cfg, proj)
	var total := {}
	var samples := 0
	var worst := {"normal": 0.0, "rain": 0.0, "snow": 0.0}
	for dir: Dictionary in Fair.directions(net, []):
		var geo := Fair.build_geo(cfg, net, dir)
		var profiles := {}
		for w: String in Fair.WEATHERS:
			profiles[w] = Fair.speed_profile(geo, envs[w])
		var r := Fair.scan_frustum(geo, cam, proj, profiles, envs, {"near_from": 30, "near_step": 15, "cam_lats": [-3.75, 0.0, 3.75],
			"lats": [-9.4, 9.4], "check_every": 1 << 40})
		samples += int(r["samples"])
		for d: int in (r["cases"] as Dictionary):
			total[d] = int(total.get(d, 0)) + int(r["cases"][d])
		for w: String in Fair.WEATHERS:
			worst[w] = maxf(float(worst[w]), float(r["worst"][w]["ratio"]))
	var ds := total.keys()
	ds.sort()
	var txt := ""
	for d: int in ds:
		if d <= 330:
			txt += "%d:%d " % [d, int(total[d])]
	print("ROADSIDE cam -3.75/0/+3.75, targets +-9.4 m, d 30..750: %d samples; cases by d (<= 330 m): %s; worst ratio dry %.3f rain %.3f snow %.3f" % [
		samples, txt, float(worst["normal"]), float(worst["rain"]), float(worst["snow"])])
	quit(0)
