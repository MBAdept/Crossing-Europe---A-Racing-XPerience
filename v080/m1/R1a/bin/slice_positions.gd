extends SceneTree
## Scratch (R1a): prints what the race scene knows about Kiel – Hamburg from Kiel: fuel lanes, sections, length.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11, "gfx": "arcade"})
	root.add_child(sc)
	await process_frame
	var plan: Object = sc.get("plan")
	print("LAENGE ", plan.get("length_km"))
	print("TANKSPUREN ", plan.get("fuel_lanes"))
	for key: String in ["stations", "fuel_stations", "sections", "city_limits", "events", "tunnels", "bridges", "radars"]:
		var v: Variant = plan.get(key)
		if v != null:
			print(key.to_upper(), " ", str(v).left(900))
	quit(0)
