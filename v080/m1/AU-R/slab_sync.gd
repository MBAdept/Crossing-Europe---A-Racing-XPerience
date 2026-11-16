extends SceneTree
## AU-R (R3): the two concrete slab loops in the running Modern profile (Dummy driver, players live) – speed changes
## across the crossfade (110-150 km/h) and a long hold inside it; every 0.2 s both positions are read with the
## AudioServer locked and their distance in the pattern converted to milliseconds at the current speed.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade
## Output: "SYNC {...}" per phase and "SUMMARY {...}".

var _am: Node
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _v := 100.0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _frame(dt: float) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, 0.4, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_vehicle_state", {"z": _z, "x": 1.875, "speed": _v, "throttle": 0.4, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": false, "weather": "normal", "hour": 12.0, "crash": false, "finished": false})


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", "modern")
	await process_frame
	_plan = root.get_node("GameData").call("get_stage_plan", "kiel_hamburg", "kiel")
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	_track = Track.new()
	_track.setup(_plan, ConfigLoader.load_merged(), (sc as Dictionary).get("scenery", {}))
	_am.call("set_vehicle", "limousine")
	_am.call("set_track", _track, _plan)
	var modern: Object = _am.get("_modern")
	var feed: AudioFeed = modern.get("feed")
	feed.concrete_share = {"_": 1.0}
	feed._concrete.clear()
	var road: Object = modern.get("road")
	_z = _track.km_to_z(20.0)
	_track.update_window(_z - 9.0, 600.0)
	# phases: [name, from kmh, to kmh, seconds]
	var phases := [["rein_100", 100.0, 100.0, 3.0], ["hoch_130", 100.0, 130.0, 3.0], ["halten_130", 130.0, 130.0, 60.0],
		["hoch_160", 130.0, 160.0, 3.0], ["runter_125", 160.0, 125.0, 4.0], ["halten_125", 125.0, 125.0, 20.0],
		["runter_95", 125.0, 95.0, 4.0], ["hoch_140", 95.0, 140.0, 4.0], ["halten_140", 140.0, 140.0, 40.0]]
	var worst := 0.0
	var samples := 0
	var t_all := 0.0
	for ph: Array in phases:
		var t0 := Time.get_ticks_usec()
		var last := t0
		var next_s := 0.0
		var ph_max := 0.0
		var ph_n := 0
		var dur := float(ph[3])
		while (Time.get_ticks_usec() - t0) / 1.0e6 < dur:
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1.0e6
			last = now
			var tt := (now - t0) / 1.0e6
			_v = lerpf(float(ph[1]), float(ph[2]), clampf(tt / dur, 0.0, 1.0))
			_frame(dt)
			if tt >= next_s:
				next_s += 0.2
				var a: Object = road.get("slab_slow")
				var b: Object = road.get("slab_fast")
				AudioServer.lock()
				var pa := bool(a.call("playing"))
				var pb := bool(b.call("playing"))
				var sa := float(a.call("share"))
				var sb := float(b.call("share"))
				AudioServer.unlock()
				if pa and pb:
					var d := fposmod(sb - sa + 0.5, 1.0) - 0.5
					var period := float(a.get("length_s")) / maxf(float(a.get("pitch")), 0.01)
					var ms := absf(d) * period * 1000.0
					ph_max = maxf(ph_max, ms)
					worst = maxf(worst, ms)
					ph_n += 1
					samples += 1
		t_all += dur
		print("SYNC ", JSON.stringify({"phase": ph[0], "kmh": snappedf(_v, 0.1), "both_playing_samples": ph_n,
			"max_offset_ms": snappedf(ph_max, 0.01), "realigned_total": road.get("slab_realigned")}))
	print("SUMMARY ", JSON.stringify({"samples_both": samples, "worst_offset_ms": snappedf(worst, 0.01),
		"realigned": road.get("slab_realigned"), "seconds": t_all}))
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
