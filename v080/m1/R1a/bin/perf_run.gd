extends SceneTree
## Scratch (R1a): GDScript time of ModernRenderer.render() of the skeleton at real-time pace (run with --fixed-fps 60,
## headless): 1,800 frames = 30 s of driving. -- --km=<start km> [--sync]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var km := float(CliArgs.all().get("km", 2.0))
	if CliArgs.all().has("sync"):
		CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": km, "autopilot": true, "seed": 11, "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": 160.0, "autopilot_refuel": "never", "traffic_warmup": true})
	root.add_child(sc)
	var r: Node = sc.get("renderer")
	var n := 0
	while int(sc.get("_sim_steps")) == 0 and n < 600:
		await process_frame
		n += 1
	for i in 1800:
		await process_frame
	var perf: Dictionary = r.call("perf_stats")
	var st: Dictionary = perf.get("streamer", {})
	var load: Dictionary = perf.get("load", {})
	print("PERF km %.0f%s: frames %d, render() avg %.3f ms max %.3f ms, chunks %d, build avg %.2f max %.2f ms, collect avg %.2f max %.2f ms, commit avg %.3f max %.3f ms, commits %d, prepare %.0f ms (load: %d chunks, build avg %.2f ms, collect max %.2f ms), pos km %.1f, speed %.0f" % [
		km, " sync" if CliArgs.all().has("sync") else "", int(perf["frames"]), float(perf["render_ms_avg"]), float(perf["render_ms_max"]), int(perf["chunks"]),
		float(st.get("build_ms_avg", 0.0)), float(st.get("build_ms_max", 0.0)), float(st.get("collect_ms_avg", 0.0)), float(st.get("collect_ms_max", 0.0)),
		float(st.get("commit_ms_avg", 0.0)), float(st.get("commit_ms_max", 0.0)), int(st.get("commits", 0)), float(perf.get("prepare_ms", 0.0)),
		int(load.get("commits", 0)), float(load.get("build_ms_avg", 0.0)), float(load.get("collect_ms_max", 0.0)), float(sc.get("pos_km")),
		float((sc.get("vehicle") as Object).get("speed"))])
	sc.queue_free()
	await process_frame
	await process_frame
	quit(0)
