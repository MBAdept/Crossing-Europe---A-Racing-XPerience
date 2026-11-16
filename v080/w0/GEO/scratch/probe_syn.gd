extends SceneTree
## Scratch: F1 on synthetic generator-like roads (which magnitudes / straights produce cases <= 270 m?).

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")


func _road(mag_max: float, straight_min: int, same_dir: bool) -> PackedFloat32Array:
	var curves := SynTrack.straight(100)
	for i in 10:
		var length := 110 + (i * 37) % 60
		var mag := (mag_max if i % 3 != 1 else mag_max * 0.67) * (1.0 if (i % 2 == 0 or same_dir) else -1.0)
		var piece := PackedFloat32Array()
		piece.resize(length)
		for q in length:
			var t := float(q) / float(length)
			piece[q] = mag * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t))
		curves.append_array(piece)
		curves.append_array(SynTrack.straight(straight_min + (i * 23) % 50))
	curves.append_array(SynTrack.straight(400))
	return curves


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var proj := Fair.make_projection(cfg)
	var envs := Fair.envelopes(cfg)
	for spec: Array in [[0.9, 45, false], [0.9, 45, true], [0.9, 80, false], [0.9, 120, false], [0.8, 45, false], [0.7, 45, false], [0.6, 45, false], [0.45, 45, false]]:
		var t: Track = SynTrack.new()
		t.fill(cfg, _road(spec[0], spec[1], spec[2]))
		var geo := Fair.geo_of_track(cfg, t, "syn")
		var profiles := {}
		for w: String in Fair.WEATHERS:
			profiles[w] = Fair.speed_profile(geo, envs[w])
		var line := "mag %.2f straights >= %d m same_dir %s:" % [spec[0], int(spec[1]) * 3, spec[2]]
		for gain: float in [0.6, 0.0]:
			var r := Fair.scan_frustum(geo, Fair.make_camera(cfg, proj, {"look_gain": gain}), proj, profiles, envs, {"near_from": 15})
			var ds := (r["cases"] as Dictionary).keys()
			ds.sort()
			var txt := ""
			for d: int in ds:
				if d <= 300:
					txt += "%d:%d " % [d, int(r["cases"][d])]
			line += "  gain %.1f: F1 %d (nearest %s) ratio %.3f [%s]" % [gain, int(r["f1_cases"]), str(r["f1_nearest_m"]), float(r["worst"]["normal"]["ratio"]), txt]
		print(line)
	quit(0)
