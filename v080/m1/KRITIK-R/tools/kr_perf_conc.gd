extends SceneTree
## KRITIK-R (copy of AU-C1 perf.gd, on forced concrete at km 42): GDScript time of the slots road and impact per frame (live players, real track Kiel – Hamburg, feed with
## events), measured by calling their update() once more per frame next to the normal step (only for timing).

var _am: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	ModernAudio.force_live = true
	_am.call("set_profile", "modern")
	await process_frame
	var plan: StagePlan = root.get_node("GameData").call("get_stage_plan", "kiel_hamburg", "kiel")
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var track := Track.new()
	track.setup(plan, ConfigLoader.load_merged(), (sc as Dictionary).get("scenery", {}))
	_am.call("set_vehicle", "limousine")
	_am.call("set_track", track, plan)
	var m: Object = _am.get("_modern")
	var road: Object = m.get("road")
	var impact: Object = m.get("impact")
	var feed: Object = m.get("feed")
	var z := track.km_to_z(42.0)
	var feed0: Object = m.get("feed")
	feed0.set("concrete_share", {"_": 1.0})
	for p: Dictionary in feed0.get_property_list():
		if str(p["name"]) == "concrete_threshold":
			feed0.set("concrete_threshold", {})
	(feed0.get("_concrete") as Dictionary).clear()
	var v := 140.0
	var us_road: Array[int] = []
	var us_imp: Array[int] = []
	var us_feed: Array[int] = []
	var last := Time.get_ticks_usec()
	for i in 900:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1.0e6
		last = now
		z += v / 3.6 * dt
		track.update_window(z - 9.0, 600.0)
		var e := track.road_edges_at(z)
		var x := 1.875 + (3.3 if (i / 120) % 2 == 1 else 0.0)
		_am.call("set_engine", v, 0.6, 245.0, true)
		_am.call("set_wind", v)
		_am.call("set_vehicle_state", {"z": z, "x": x, "speed": v, "throttle": 0.6, "understeer": 0.3, "lat_speed": 2.0,
			"off_road": 0, "rail_contact": i % 300 > 250, "road_left": e.x, "road_right": e.y, "shoulder_m": 2.5,
			"in_tunnel": false, "weather": "rain", "hour": 12.0, "crash": false, "finished": false})
		var f: Object = m.get("frame")
		var t0 := Time.get_ticks_usec()
		feed.call("update", f.get("state"))
		var t1 := Time.get_ticks_usec()
		road.call("update", f)
		var t2 := Time.get_ticks_usec()
		impact.call("update", f)
		var t3 := Time.get_ticks_usec()
		if i > 60:
			us_feed.append(t1 - t0)
			us_road.append(t2 - t1)
			us_imp.append(t3 - t2)
	for pair: Array in [["feed", us_feed], ["road", us_road], ["impact", us_imp]]:
		var a: Array = pair[1]
		a.sort()
		var s := 0
		for u: int in a:
			s += u
		print("PERF %-7s Mittel %.3f ms  Median %.3f ms  p95 %.3f ms  max %.3f ms (%d Bilder)" % [pair[0], s / 1000.0 / a.size(),
			a[a.size() / 2] / 1000.0, a[int(a.size() * 0.95)] / 1000.0, a[a.size() - 1] / 1000.0, a.size()])
	print("PERF road players: ", JSON.stringify(road.call("debug_state")))
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
