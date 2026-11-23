extends SceneTree
## FIX-R7b probe: main-thread cost of creating a landmark node (_make) and of placing it (_place) at Kiel – Hamburg,
## and the per-frame landmark hook while driving towards Hamburg (spikes and where they happen).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": float(CliArgs.all().get("km", 60.0)),
		"autopilot": true, "autopilot_refuel": "never", "seed": 7, "gfx": "modern", "no_countdown": true,
		"start_speed_kmh": 120.0, "traffic_warmup": false}
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		await process_frame
		n += 1
	Engine.time_scale = 20.0
	var r: Object = sc.get("renderer")
	var b: Object = r.call("builder", "landmarks")
	var last_max := 0.0
	var frames := 0
	var t_end := Time.get_ticks_msec() + int(float(CliArgs.all().get("secs", 120.0)) * 1000.0)
	while Time.get_ticks_msec() < t_end:
		await process_frame
		frames += 1
		var ps: Dictionary = r.call("perf_stats")
		var hm: Dictionary = ps.get("hooks_ms_max", {})
		var m := float(hm.get("landmarks", 0.0))
		if m > last_max + 0.2:
			var view: Dictionary = r.get("view")
			print("PROBE Spitze landmarks %.2f ms bei km %.2f (Bild %d), live %s" % [m, float(view.get("km", -1.0)), frames,
				str(((b.call("snapshot") as Dictionary).get("landmarks", []) as Array).map(func(e: Dictionary) -> String:
					return "%s d=%.0f blend=%s" % [str(e["landmark"]).get_file(), float(e["d"]), str(e["blend"])]))])
			last_max = m
	Engine.time_scale = 1.0
	# direct timing of _place and _make for every plan
	var plans: Array = b.get("_plans")
	var world: Node3D = r.get("world")
	for li in plans.size():
		var p: Dictionary = plans[li]
		var t0 := Time.get_ticks_usec()
		var made := 0
		for k in 5:
			var e: Variant = b.call("_make", 900 + li * 10 + k, p, world)
			if e != null:
				made += 1
				((e as Dictionary)["node"] as Node).free()
				(b.get("_live") as Dictionary).erase(900 + li * 10 + k)
		var t1 := Time.get_ticks_usec()
		print("PROBE %s rep %d: _make %.3f ms je Knoten (%d)" % [str(p["landmark"]), int(p["rep"]), float(t1 - t0) / 1000.0 / maxf(1.0, made), made])
	quit(0)
