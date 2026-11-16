extends SceneTree
## KRITIK-R: AU-C1's worst case (worst_case.gd, scenario unchanged: Gran Turismo flat out at 230 km/h in a tunnel,
## race music, understeer squeal, two trucks and the police car close with the siren, a heavy crash into a truck, a
## hard guardrail hit and scraping, a second crash). Changed only what is recorded: Master after everything at
## Gesamtlautstärke 1.0 (the recording is taken before Master's volume – not scaled), MMaster right after the glue
## compressor (in front of an AU-R limiter) and at its end, raw float32.
##   godot --headless --path . -s <this file> -- --out=/abs/worst.wav [--seconds=14] [--no-music]

var _am: Node
var _rec: AudioEffectRecord
var _cap_pre: AudioEffectCapture
var _cap_post: AudioEffectCapture
var _pre := PackedVector2Array()
var _post := PackedVector2Array()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_pull()
	return false


func _pull() -> void:
	if _cap_pre != null:
		var n := _cap_pre.get_frames_available()
		if n > 0:
			_pre.append_array(_cap_pre.get_buffer(n))
	if _cap_post != null:
		var m := _cap_post.get_frames_available()
		if m > 0:
			_post.append_array(_cap_post.get_buffer(m))


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "user://worst.wav")
	var seconds := CliArgs.get_float("seconds", 14.0)
	var music := not CliArgs.has("no-music")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", "modern")
	await process_frame
	var mm := AudioServer.get_bus_index("MMaster")
	var glue_i := 0
	for i in AudioServer.get_bus_effect_count(mm):
		if AudioServer.get_bus_effect(mm, i) is AudioEffectCompressor:
			glue_i = i
	_cap_pre = AudioEffectCapture.new()
	_cap_pre.buffer_length = 10.0
	AudioServer.add_bus_effect(mm, _cap_pre, glue_i + 1)
	_cap_post = AudioEffectCapture.new()
	_cap_post.buffer_length = 10.0
	AudioServer.add_bus_effect(mm, _cap_post)
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_am.call("set_vehicle", "gran_turismo")
	if music:
		_am.call("set_music", true)
		_am.call("set_music_context", "race", {})
	_pull()
	_pre = PackedVector2Array()
	_post = PackedVector2Array()
	_rec.set_recording_active(true)
	var t0 := Time.get_ticks_usec()
	var events_done := {}
	var v := 230.0
	var marks := {}
	while true:
		var t := (Time.get_ticks_usec() - t0) / 1.0e6
		if t > seconds:
			break
		var crash_now := t > 5.0 and t < 6.2
		var rail := t > 8.0 and t < 11.0
		_am.call("set_engine", v, 1.0, 270.0, true)
		_am.call("set_wind", v)
		_am.call("set_environment", {"tunnel": true})
		_am.call("set_siren", true, 0.95)
		var cars := [
			{"id": 1, "set": "traffic/truck_red", "z": 6.0, "x": 3.75, "length": 16.5, "speed": 90.0, "heavy": true},
			{"id": 2, "set": "traffic/truck_red", "z": -4.0, "x": -3.75, "length": 16.5, "speed": 88.0, "heavy": true},
			{"id": 3, "set": "traffic/sedan_blue", "z": 14.0, "x": 0.0, "length": 4.7, "speed": 120.0},
			{"id": -2, "set": "police/de", "z": -12.0, "x": 0.0, "length": 4.8, "speed": 232.0},
		]
		_am.call("set_traffic", cars, {"z": 0.0, "x": 0.0, "speed": v})
		_am.call("set_vehicle_state", {"z": 1000.0 + t * v / 3.6, "x": 7.0 if rail else 1.875, "speed": v, "throttle": 1.0,
			"brake": 0.0, "steer": 0.4, "understeer": 1.0, "lat_speed": 3.0, "off_road": 2 if rail else 0, "rail_contact": rail,
			"road_left": -5.625, "road_right": 5.625, "shoulder_m": 2.5, "in_tunnel": true, "weather": "normal", "hour": 12.0,
			"crash": crash_now, "finished": false})
		if t > 5.0 and not events_done.has("crash1"):
			events_done["crash1"] = true
			_pull()
			marks["crash1"] = _pre.size()
			_am.call("play", "crash")
			_am.call("event", "collision", {"speed_kmh": v, "rel_kmh": 140.0, "heavy": true, "side": 1})
		if t > 8.0 and not events_done.has("rail"):
			events_done["rail"] = true
			_pull()
			marks["rail"] = _pre.size()
			_am.call("play", "rail", 2.0)
			_am.call("event", "rail_hit", {"impact_mps": 6.0, "side": 1})
		if t > 11.5 and not events_done.has("crash2"):
			events_done["crash2"] = true
			_pull()
			marks["crash2"] = _pre.size()
			_am.call("play", "crash")
			_am.call("event", "collision", {"speed_kmh": v, "rel_kmh": 90.0, "heavy": true, "side": -1})
		await process_frame
	_rec.set_recording_active(false)
	_pull()
	var wav := _rec.get_recording()
	var err := wav.save_to_wav(out)          # before Master's volume = Gesamtlautstärke 1.0
	for pair: Array in [["_pre", _pre], ["_post", _post]]:
		var arr: PackedVector2Array = pair[1]
		var flat := PackedFloat32Array()
		flat.resize(arr.size() * 2)
		for i in arr.size():
			flat[2 * i] = arr[i].x
			flat[2 * i + 1] = arr[i].y
		var f := FileAccess.open(out.get_basename() + str(pair[0]) + ".f32", FileAccess.WRITE)
		f.store_buffer(flat.to_byte_array())
		f.close()
	var fj := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	fj.store_string(JSON.stringify({"marks": marks, "pre_frames": _pre.size(), "post_frames": _post.size()}) + "\n")
	fj.close()
	print("kr_worst: %s (%.1f s) -> %s, pre %d post %d" % [out, seconds, error_string(err), _pre.size(), _post.size()])
	_am.call("set_music", false)
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)
