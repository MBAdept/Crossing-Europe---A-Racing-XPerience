extends SceneTree
## Probe (RINT-B): loading time of Kiel–Hamburg from its start (km 0) until the session is live, in one mode, measured
## like the Leistungstest (prepare_s: scene added -> RaceSession.is_live()). Samples the renderer's prepare_progress()
## every frame (the loading picture's bar) and prints how often it moved and the longest frame while loading.
## usage: ... -s <this> -- --mode=arcade|modern [--km=0]

var _sc: Node
var _mode := "modern"
var _km := 0.0
var _t0 := 0
var _last := 0
var _longest := 0
var _frames := 0
var _progress: Array[float] = []
var _moves := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--km="):
			_km = float(a.substr(5))
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": _km, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": _mode, "no_countdown": true, "start_speed_kmh": 0.0}
	_t0 = Time.get_ticks_usec()
	_last = _t0
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	var now := Time.get_ticks_usec()
	_longest = maxi(_longest, now - _last)
	_last = now
	_frames += 1
	var r: Variant = _sc.get("renderer")
	if r is Object and (r as Object).has_method("prepare_progress"):
		var p := float((r as Object).call("prepare_progress"))
		if _progress.is_empty() or absf(p - _progress[-1]) > 0.0005:
			if not _progress.is_empty():
				_moves += 1
			_progress.append(p)
	if bool(_sc.call("is_live")) or now - _t0 > 300000000:
		var ps: Dictionary = {}
		if r is Object and (r as Object).has_method("perf_stats"):
			ps = (r as Object).call("perf_stats")
		var steps: Array = []
		for i in range(0, _progress.size(), maxi(1, _progress.size() / 12)):
			steps.append(snappedf(_progress[i], 0.01))
		print("LOADTIME " + JSON.stringify({"mode": _mode, "km": _km, "prepare_s": snappedf(float(now - _t0) / 1e6, 0.01),
			"frames": _frames, "longest_frame_ms": snappedf(float(_longest) / 1000.0, 0.1), "bar_moves": _moves,
			"bar_samples": steps, "live": bool(_sc.call("is_live")), "renderer_prepare": ps.get("prepare_s", -1)}))
		return true
	return false
