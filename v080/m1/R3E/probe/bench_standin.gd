extends SceneTree
## R3E scratch (not in the repo): the "leistung" scenario of tests/race3d/check_vehicles.gd, alternating between the
## stand-in pictures (R3E) and the painted boxes (R3: the layer's prepared sheets cleared), several rounds in one
## process, so machine load hits both alike. Prints the median µs per car and frame of each round.

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe: GDScript = load(PROBE)
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	cli.erase("graphics")
	renderers.set("modern_script", PROBE)
	var results := {"bild": [], "kasten": []}
	for round in 6:
		var mode := "bild" if round % 2 == 0 else "kasten"
		var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
			"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
			"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
		var sc: Node = (load(RACE) as PackedScene).instantiate()
		sc.set("setup", setup)
		root.add_child(sc)
		var n := 0
		while int(sc.get("_sim_steps")) <= 2 and n < 3000:
			await process_frame
			n += 1
		var r: Node = sc.get("renderer")
		var vl: Node = r.call("layer", "vehicles")
		if mode == "kasten":
			vl.set("_standin_tex", {})
			(vl.get("_set_cache") as Dictionary).clear()
			(vl.get("_cars") as Dictionary).clear()
			(vl.get("_free") as Dictionary).clear()
		var view: Dictionary = r.get("view")
		var cam_z := float(view.get("camera_z", 0.0))
		var x0 := float((view.get("player", {}) as Dictionary).get("x", 0.0))
		var sets := ["traffic/sedan_red", "traffic/hatch_blue", "traffic/wagon_silver", "traffic/truck_red", "traffic/sports_blue",
			"traffic/van_white", "traffic/bus_red", "traffic/suv_grey", "police/de"]
		var cars: Array = []
		for i in 23:
			var lane := float(i % 3 - 1) * 3.75
			var sid: String = sets[i % sets.size()]
			var l := float(ModelDB.object_size(sid).get("length_m", 4.5))
			cars.append({"kind": "car", "id": 9200 + i, "set": sid, "z": cam_z + 14.0 + float(i) * 17.0, "x": x0 + lane, "length": l,
				"tail": 0.0, "brake": 1.0 if i % 4 == 0 else 0.0, "speed": 0.0, "blink": 1 if i % 5 == 0 else 0, "blink_t": 0.1})
		probe.set("inject", cars)
		for f in 30:
			await process_frame
		var samples: Array[float] = []
		var drawn := 0
		for f in 120:
			var t0 := Time.get_ticks_usec()
			vl.call("update", r.get("view"), 1.0 / 60.0)
			var us := float(Time.get_ticks_usec() - t0)
			drawn = int((vl.call("perf") as Dictionary)["vehicles"])
			samples.append(us / maxf(1.0, float(drawn)))
			await process_frame
		samples.sort()
		var median := samples[samples.size() / 2]
		(results[mode] as Array).append(median)
		var st: Dictionary = vl.call("perf")
		print("Runde %d %-6s: %d Autos, davon Ersatzbilder %d, Median %.1f µs/Auto, p90 %.1f" % [round, mode, drawn, int(st.get("standin_cars", 0)), median, samples[int(samples.size() * 0.9)]])
		probe.call("reset")
		sc.queue_free()
		await process_frame
		await process_frame
	print("Ersatzbilder: ", results["bild"], "   gemalte Kästen: ", results["kasten"])
	renderers.set("modern_script", renderers.get("MODERN_SCRIPT"))
	quit(0)
