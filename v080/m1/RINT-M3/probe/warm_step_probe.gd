extends SceneTree
## RINT-M3 probe (note 7): the cost of ONE step of SightCorridor.warm() along a whole stage – the first step of a call
## always runs, whatever the deadline (a block of geometry, a block of the F2 need, or a camera fan). Steps the corridor
## from its front to the stage end with an already passed deadline (one step per call) and times every call; prints
## the distribution per kind and the longest steps with their km. Headless (main-thread script time only).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a: Dictionary = CliArgs.all()
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "kiel")), "vehicle": "limousine", "start_world_minutes": 12.0 * 60.0,
		"weather": "normal", "start_km": float(a.get("km", 0.0)), "autopilot": true, "autopilot_refuel": "never",
		"seed": 7, "gfx": "modern", "no_countdown": true, "traffic_warmup": false}
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 6000:
		await process_frame
		n += 1
	var r: Object = sc.get("renderer")
	var terrain: Object = r.get("terrain")
	var sight: Object = terrain.get("sight")
	var path: Object = sight.get("path")
	var tr: Object = r.get("track")
	var end := int(path.call("end_index"))
	var kinds := {"block": [], "fan": []}
	var worst: Array = []
	var calls := 0
	var t_all := Time.get_ticks_usec()
	while int(sight.call("front")) <= end and calls < 400000:
		var c := int(sight.call("front"))
		var due := bool(sight.call("_block_due", c, end))
		var t0 := Time.get_ticks_usec()
		sight.call("warm", end, 0)
		var us := Time.get_ticks_usec() - t0
		calls += 1
		(kinds["block" if due else "fan"] as Array).append(us)
		if us > 1500:
			worst.append([us, c, due])
		if int(sight.call("front")) == c and not due:
			break
	print("PROBE stage %s from km %.1f: %d calls, %.1f s, end row %d" % [str(setup["stage_id"]), float(setup["start_km"]),
		calls, float(Time.get_ticks_usec() - t_all) / 1.0e6, end])
	for k: String in kinds:
		var v: Array = kinds[k]
		v.sort()
		if v.is_empty():
			continue
		print("PROBE %s n=%d median %.3f ms p99 %.3f ms p999 %.3f ms max %.3f ms" % [k, v.size(), v[v.size() / 2] / 1000.0,
			v[int(v.size() * 0.99)] / 1000.0, v[mini(v.size() - 1, int(v.size() * 0.999))] / 1000.0, v[-1] / 1000.0])
	worst.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	for w: Array in worst.slice(0, 15):
		print("PROBE step %.3f ms at row %d km %.2f %s" % [float(w[0]) / 1000.0, int(w[1]),
			float(tr.call("z_to_km", float(w[1]) * float(tr.get("seg_len")))), "block" if bool(w[2]) else "fan"])
	quit(0)
