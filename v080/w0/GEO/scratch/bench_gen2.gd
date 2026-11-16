extends SceneTree
## Scratch: track generation cost with and without the crest sign decisions; identity of curve / height.

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var fast: Dictionary = cfg.duplicate(true)
	fast["road"]["crest_warning_sight_m"] = 0.0
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var limit := 24
	for mode in ["normal", "fast", "fast_nosign"]:
		var conf: Dictionary = cfg if mode == "normal" else fast
		if mode == "fast_nosign":
			conf = fast.duplicate(true)
			conf["road"]["curve_warning_min_curve"] = 99.0
			conf["road"]["curve_warning_blind_min_curve"] = 99.0
		var t0 := Time.get_ticks_msec()
		var total := 0
		var dirs := 0
		var hsum := 0
		for s: Dictionary in net.get("stages", []):
			if bool(s.get("dev", false)):
				continue
			for from_id: String in [str(s["from"]), str(s["to"])]:
				if dirs >= limit:
					break
				var plan := StagePlan.build(s, from_id, cities, countries, conf)
				var track := Track.new()
				track.setup(plan, conf, {})
				var n := track.segment_count
				for i in n:
					var sg := track.get_segment(i)
					hsum = hash([hsum, sg.curve, sg.y, sg.lanes, sg.fuel_lane, sg.tunnel, sg.city])
				total += n
				dirs += 1
		var t1 := Time.get_ticks_msec()
		print("%s: %d dirs, %d segments in %d ms = %.1f us/segment, hash %d" % [mode, dirs, total, t1 - t0, float(t1 - t0) * 1000.0 / float(total), hsum])
	quit(0)
