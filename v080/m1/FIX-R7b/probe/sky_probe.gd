extends SceneTree
## FIX-R7b probe (B-06): main-thread cost of one backdrop redraw with and without the skyline silhouettes.
## Args after --: --stage-id=… --from-city=… --km=… (default Lüttich – Paris km 376)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a := CliArgs.all()
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage-id", "luettich_paris")),
		"from_city": str(a.get("from-city", "luettich")), "vehicle": "limousine",
		"start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": "normal", "start_km": float(a.get("km", 376.0)),
		"autopilot": true, "autopilot_refuel": "never", "seed": 11, "gfx": "modern", "no_countdown": true,
		"start_speed_kmh": 0.0, "traffic_warmup": false}
	CliArgs.all()["no-traffic"] = true
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		await process_frame
		n += 1
	for i in 20:
		await process_frame
	paused = true
	var r: Object = sc.get("renderer")
	var bd: Object = r.call("layer", "backdrop")
	var view: Dictionary = r.get("view")
	var snap: Dictionary = (bd.call("snapshot") as Dictionary).get("backdrop", {})
	print("PROBE skyline ", snap.get("skyline"))
	var track: Track = r.get("track")
	var sky_keep: Array[Dictionary] = track.plan.skyline.duplicate()
	for round in 3:
		for with_sky: bool in [true, false]:
			if with_sky:
				track.plan.skyline = sky_keep
			else:
				track.plan.skyline = [] as Array[Dictionary]
			var times: Array[float] = []
			for i in 60:
				bd.set("_drawn_sig", [])
				var t0 := Time.get_ticks_usec()
				bd.call("update", view, 0.016)
				bd.call("paint", bd.get("canvas"))
				times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
				if i % 10 == 0:
					await process_frame
			times.sort()
			var sum := 0.0
			for t: float in times:
				sum += t
			print("PROBE runde %d %s: update+paint Ø %.3f ms, Median %.3f, max %.3f (60)" % [round, "mit Skyline" if with_sky else "ohne Skyline",
				sum / 60.0, times[30], times[59]])
	track.plan.skyline = sky_keep
	quit(0)
