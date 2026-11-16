extends SceneTree
## R3E scratch: where the time of the vehicle layer goes – the leistung scenario of check_vehicles, once with the
## stand-ins and once with painted boxes; the layer's temporary PROF counters (µs) per frame and per car.

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const LAYER := "res://scripts/race3d/layers/vehicles.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe: GDScript = load(PROBE)
	var layer_s: GDScript = load(LAYER)
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	cli.erase("graphics")
	renderers.set("modern_script", PROBE)
	for round in 4:
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
		(layer_s.get("PROF") as Dictionary).clear()
		var frames := 0
		var total := 0
		for f in 120:
			var t0 := Time.get_ticks_usec()
			vl.call("update", r.get("view"), 1.0 / 60.0)
			total += Time.get_ticks_usec() - t0
			frames += 1
			await process_frame
		var prof: Dictionary = layer_s.get("PROF")
		var line := "Runde %d %-6s: update %.1f µs/Bild |" % [round, mode, float(total) / frames]
		var keys := prof.keys()
		keys.sort()
		for k: String in keys:
			if k.ends_with("_n"):
				continue
			var cnt := int(prof.get(k + "_n", 0))
			if cnt > 0:
				line += " %s %.1f µs/Auto (%d/Bild)," % [k, float(prof[k]) / cnt, cnt / frames]
			else:
				line += " %s %.1f µs/Bild," % [k, float(prof[k]) / frames]
		print(line)
		probe.call("reset")
		sc.queue_free()
		await process_frame
		await process_frame
	renderers.set("modern_script", renderers.get("MODERN_SCRIPT"))
	quit(0)
