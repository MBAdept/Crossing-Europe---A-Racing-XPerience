extends SceneTree
## KRITIK-FAHRBAHN: the AU-C1 impact sounds in the running Modern profile, recorded in front of the master limiter
## (AudioEffectCapture at index 0 of Master) and behind it (AudioEffectRecord last), both before the master volume.
## Only MImpact is audible (--all keeps everything else on: engine, road, wind at 110 km/h).
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --out=/abs/impacts.wav [--all]
## Writes <out> (behind the limiter, float32 WAV via raw file), <out>_pre.raw, <out>.json (event times by frame count).

var _am: Node
var _rec: AudioEffectRecord
var _cap: AudioEffectCapture
var _pre := PackedVector2Array()
var _marks: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _cap != null:
		var n := _cap.get_frames_available()
		if n > 0:
			_pre.append_array(_cap.get_buffer(n))
	return false


func _frame(z: float, v: float) -> void:
	_am.call("set_engine", v, 0.35, 245.0, true)
	_am.call("set_wind", v)
	_am.call("set_environment", {"tunnel": false})
	_am.call("set_vehicle_state", {"z": z, "x": 1.875, "speed": v, "throttle": 0.35, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": -5.625, "road_right": 5.625,
		"shoulder_m": 2.5, "in_tunnel": false, "weather": "normal", "hour": 12.0, "crash": false, "finished": false})


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", "modern")
	await process_frame
	_am.call("set_vehicle", "limousine")
	if not CliArgs.has("all"):
		for b: String in ["MEngine", "MEngineFx", "MRoad", "MWind", "MWorld", "MAmb", "MMusic"]:
			var i := AudioServer.get_bus_index(b)
			if i >= 0:
				AudioServer.set_bus_mute(i, true)
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 4.0
	AudioServer.add_bus_effect(0, _cap, 0)
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	var z := 1000.0
	var v := 110.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	# settle 1.5 s, then the events
	var plan := [
		[1.5, "collision", {"speed_kmh": 110.0, "rel_kmh": 6.0, "heavy": false, "side": 1}, "Rempler 6"],
		[4.0, "collision", {"speed_kmh": 110.0, "rel_kmh": 30.0, "heavy": false, "side": 0}, "Auffahren 30"],
		[6.5, "collision", {"speed_kmh": 110.0, "rel_kmh": 70.0, "heavy": false, "side": -1}, "schwer 70"],
		[9.0, "collision", {"speed_kmh": 110.0, "rel_kmh": 130.0, "heavy": false, "side": 1}, "schwer 130"],
		[11.5, "collision", {"speed_kmh": 110.0, "rel_kmh": 40.0, "heavy": true, "side": 1}, "Lkw 40"],
		[14.0, "collision", {"speed_kmh": 110.0, "rel_kmh": 110.0, "heavy": true, "side": -1}, "Lkw 110"],
		[16.5, "collision", {"speed_kmh": 110.0, "rel_kmh": 130.0, "heavy": false, "side": 0}, "schwer 130 mittig"],
		[19.0, "rail_hit", {"impact_mps": 2.0, "side": 1}, "Leitplanke 2"],
		[21.5, "rail_hit", {"impact_mps": 5.0, "side": 1}, "Leitplanke 5"],
	]
	var next := 0
	_rec.set_recording_active(true)
	var rec_frames0 := _pre.size()
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var t := (now - t0) / 1.0e6
		z += v / 3.6 * (now - last) / 1.0e6
		last = now
		_frame(z, v)
		if next < plan.size() and t >= float(plan[next][0]):
			var p: Array = plan[next]
			_marks.append({"t": t, "label": p[3], "pre_frame": _pre.size() - rec_frames0})
			if str(p[1]) == "collision":
				_am.call("play", "crash")
			else:
				_am.call("play", "rail", clampf(-10.0 + 2.0 * float((p[2] as Dictionary)["impact_mps"]), -10.0, 2.0))
			_am.call("event", str(p[1]), p[2])
			next += 1
		if t > 24.5:
			break
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	wav.save_to_wav(out)
	var f := FileAccess.open(out.get_basename() + "_pre.raw", FileAccess.WRITE)
	for fr in _pre:
		f.store_float(fr.x)
		f.store_float(fr.y)
	f.close()
	var j := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	j.store_string(JSON.stringify({"master_db": AudioServer.get_bus_volume_db(0), "marks": _marks, "pre_frames": _pre.size(),
		"mix_rate": AudioServer.get_mix_rate()}, "\t"))
	j.close()
	print("impact_check: %d pre frames, marks %d -> %s" % [_pre.size(), _marks.size(), out])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
