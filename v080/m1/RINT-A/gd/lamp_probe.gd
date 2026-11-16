extends SceneTree
## RINT-A: are the lamps of the prop models registered and lit? S4 (City Limits) at 22:00, headless.

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var km := 80.0
	var hour := 22.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--km="):
			km = float(a.substr(5))
		elif a.begins_with("--hour="):
			hour = float(a.substr(7))
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": hour * 60.0, "weather": "normal", "start_km": km, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 50.0, "traffic_warmup": true, "gfx": "modern"}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 60 and n < 3000:
		await process_frame
		n += 1
	var r: Object = sc.get("renderer")
	var snap: Dictionary = r.call("debug_snapshot")
	print("RINT lights ", JSON.stringify(snap.get("lights", {})))
	print("RINT props ", JSON.stringify(snap.get("props", {})))
	var fl: Object = r.call("layer", "flares")
	if fl != null:
		print("RINT flares snapshot ", JSON.stringify(fl.call("snapshot")).left(600))
	var v: Dictionary = r.get("view")
	print("RINT palette lights ", (v.get("palette", {}) as Dictionary).get("lights"))
	quit(0)
