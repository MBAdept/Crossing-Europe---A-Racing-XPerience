extends SceneTree
## QA-M2-SYSTEM: map of what the Modern sound's AudioFeed derives along a real stage (paving, deck, bridge, zone, city
## and the feed events such as bridge joints), driving the car's centre line in 1-m steps. Pure data, headless.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --stage=kiel_hamburg [--from=kiel] [--lane-x=1.8]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("/root/GameData")
	var stage := CliArgs.get_string("stage", "kiel_hamburg")
	var from := CliArgs.get_string("from", "")
	var plan: Object = gd.call("get_stage_plan", stage, from)
	var cfg := ConfigLoader.load_merged()
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var track := Track.new()
	track.setup(plan, cfg, (sc as Dictionary).get("scenery", {}))
	var f := AudioFeed.new()
	var m: Variant = ConfigLoader.lookup(cfg, "audio.modern", {})
	f.setup(m if m is Dictionary else {})
	f.set_track(track, plan)
	var x := CliArgs.get_float("lane-x", 1.8)
	var z := 0.0
	var z_end := track.km_to_z(float(plan.get("length_km")) - 0.05)
	var last := ""
	var counts := {}
	var seg_m := {}
	var t0 := Time.get_ticks_msec()
	while z < z_end:
		if int(z) % 200 == 0:
			track.update_window(z - 60.0, 800.0)
		var road_l := -5.625
		var road_r := 5.625
		f.update({"z": z, "x": x, "speed": 130.0, "road_left": road_l, "road_right": road_r, "shoulder_m": 2.5,
			"off_road": 0, "rail_contact": false, "weather": "normal"})
		var key := "paving=%s deck=%s bridge=%s city=%s tunnel=%s zone=%s road=%s" % [f.paving, f.deck, f.bridge, str(f.city), str(f.tunnel), f.zone, f.road]
		var km := float(track.call("z_to_km", z))
		if key != last:
			print("FEED km %7.3f  %s" % [km, key])
			last = key
		seg_m[f.paving] = float(seg_m.get(f.paving, 0.0)) + 1.0
		for e: Dictionary in f.events:
			var n := str(e.get("name", ""))
			counts[n] = int(counts.get(n, 0)) + 1
			if n == "joint" or n.begins_with("bridge") or n.begins_with("tunnel"):
				print("EVENT km %7.3f  %s" % [km, JSON.stringify(e)])
		z += 1.0
	print("PAVING_M ", JSON.stringify(seg_m))
	print("EVENTS ", JSON.stringify(counts))
	print("STRUCTURES ", JSON.stringify(f.structures()).substr(0, 1500))
	print("DONE %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)
