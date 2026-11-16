extends SceneTree
## RINT-A: fog range and visibility of a few stage states (headless). Prints "RINT fog …".

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _one(stage: String, from: String, km: float, hour: float, weather: String) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": stage, "from_city": from, "vehicle": "limousine",
		"start_world_minutes": hour * 60.0, "weather": weather, "start_km": km, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": "modern"}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 10 and n < 3000:
		await process_frame
		n += 1
	var r: Object = sc.get("renderer")
	var st: Dictionary = (r.get("env") as Object).get("state")
	var v: Dictionary = r.get("view")
	print("RINT fog %s km %.1f %02.0f h %s: visibility %.0f m, fog %.0f .. %.0f m" % [stage, km, hour, weather,
		float(v.get("visibility_m", 0.0)), float(st.get("fog_begin", 0.0)), float(st.get("fog_end", 0.0))])
	sc.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	await _one("kiel_hamburg", "kiel", 2.0, 12.0, "normal")
	await _one("saragossa_pau", "saragossa", 198.8, 14.0, "normal")
	await _one("kiel_hamburg", "kiel", 2.0, 22.0, "normal")
	await _one("hamburg_hannover", "hamburg", 71.0, 22.0, "snow")
	quit(0)
