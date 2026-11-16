extends SceneTree
## AU-R3: the feed of AU-R2 (3600eb7 copy, --old=<file>) against the tree's AudioFeed along a whole stage on the real
## Track, step by step as the race session drives it (update_window behind the car, then the feed): every field of
## state() and every event compared. Same state for both feeds; no traffic, no physics – the feed's own decisions.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --old=<file> --stage=<id> --from=<city> [--step=1.0]
## Output: "DIFF {...}" for the first differing steps, "STRETCH {...}" per run of differing paving, "RESULT {...}".


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := CliArgs.all()
	var OldFeed: GDScript = load(str(args.get("old", "")))
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var modern: Dictionary = ConfigLoader.lookup(cfg, "audio.modern", {})
	var plan: StagePlan = gd.call("get_stage_plan", str(args.get("stage", "kiel_hamburg")), str(args.get("from", "")))
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var track := Track.new()
	track.setup(plan, cfg, (sc as Dictionary).get("scenery", {}))
	var fo: Object = OldFeed.new()
	var fn := AudioFeed.new()
	for f: Object in [fo, fn]:
		f.call("setup", modern)
		f.call("set_vehicle_width", 1.86)
		f.call("set_track", track, plan)
	var step := float(args.get("step", 1.0))
	var z := 0.0
	var z_end := track.km_to_z(plan.length_km)
	var steps := 0
	var state_diff := 0
	var event_diff := 0
	var events := 0
	var shown := 0
	var run_from := -1.0
	var run_pv := ""
	var pav := {}
	while z < z_end:
		track.update_window(z - 9.0, 300.0)
		var e := track.road_edges_at(z)
		var st := {"z": z, "x": 0.0, "speed": 130.0, "road_left": e.x, "road_right": e.y, "shoulder_m": 2.5, "off_road": 0,
			"rail_contact": false, "weather": "normal"}
		fo.call("update", st)
		fn.update(st)
		steps += 1
		var so: Dictionary = fo.call("state")
		var sn: Dictionary = fn.state()
		var eo: Array = (fo.get("events") as Array)
		events += fn.events.size()
		var k := "%s>%s" % [str(so["paving"]), str(sn["paving"])]
		pav[k] = float(pav.get(k, 0.0)) + step
		if so != sn:
			state_diff += 1
			if run_from < 0.0:
				run_from = z
				run_pv = k
			if shown < 5:
				shown += 1
				var d := {}
				for key: String in so:
					if so[key] != sn[key]:
						d[key] = [so[key], sn[key]]
				print("DIFF ", JSON.stringify({"z": z, "km": snappedf(track.z_to_km(z), 0.001), "fields": d}))
		elif run_from >= 0.0:
			print("STRETCH ", JSON.stringify({"km0": snappedf(track.z_to_km(run_from), 0.001), "km1": snappedf(track.z_to_km(z), 0.001),
				"m": z - run_from, "paving": run_pv, "bridge": str(track.bridge_at(run_from).get("name", ""))}))
			run_from = -1.0
		if str(eo) != str(fn.events):
			event_diff += 1
		z += step
	if run_from >= 0.0:
		print("STRETCH ", JSON.stringify({"km0": snappedf(track.z_to_km(run_from), 0.001), "km1": snappedf(track.z_to_km(z), 0.001),
			"m": z - run_from, "paving": run_pv, "bridge": str(track.bridge_at(run_from).get("name", ""))}))
	print("RESULT ", JSON.stringify({"stage": plan.stage_id, "from": plan.from_id, "to": plan.to_id, "steps": steps, "step_m": step,
		"state_diff_steps": state_diff, "event_diff_steps": event_diff, "events_new": events, "paving_old_to_new_m": pav}))
	quit(0)
