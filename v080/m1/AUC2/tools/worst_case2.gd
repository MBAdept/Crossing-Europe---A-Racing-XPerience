extends SceneTree
## AU-C1 worst case for the master's true peak (contract AU-C1: tunnel + trucks + siren + crash + music ≤ −0.5 dBTP).
## Modern profile, live playback headless (ModernAudio.force_live), race music, Gran Turismo flat out at 230 km/h in
## a tunnel (reverb), understeer squeal, two trucks and the police car close with the siren on, then a heavy crash
## into a truck, a hard guardrail hit and scraping along it, a second crash. Records the Master after its limiter
## (what reaches the sound card) to --out=<file.wav> and the signal in front of the limiter to <file>_pre.wav.
##   godot --headless --path . -s <this file> -- --out=/abs/worst.wav [--seconds=14] [--no-music]

var _am: Node
var _rec: AudioEffectRecord
var _cap: AudioEffectCapture
var _pre := PackedVector2Array()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _cap != null:
		var n := _cap.get_frames_available()
		if n > 0:
			_pre.append_array(_cap.get_buffer(n))
	return false


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
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 2.0
	# AU-R: in front of the Modern limiter on MMaster (behind the glue compressor); on a head without it the same place
	var mm := AudioServer.get_bus_index("MMaster")
	AudioServer.add_bus_effect(mm, _cap, mini(1, AudioServer.get_bus_effect_count(mm)))
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)             # behind it
	_am.call("set_vehicle", "gran_turismo")
	if music:
		_am.call("set_music", true)
		_am.call("set_music_context", "race", {})
	_rec.set_recording_active(true)
	var t0 := Time.get_ticks_usec()
	var events_done := {}
	var v := 230.0
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
			_am.call("play", "crash")
			_am.call("event", "collision", {"speed_kmh": v, "rel_kmh": 140.0, "heavy": true, "side": 1})
		if t > 8.0 and not events_done.has("rail"):
			events_done["rail"] = true
			_am.call("play", "rail", 2.0)
			_am.call("event", "rail_hit", {"impact_mps": 6.0, "side": 1})
		if t > 11.5 and not events_done.has("crash2"):
			events_done["crash2"] = true
			_am.call("play", "crash")
			_am.call("event", "collision", {"speed_kmh": v, "rel_kmh": 90.0, "heavy": true, "side": -1})
		await process_frame
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	# the record effect sits before the volume of Master: apply it (AU-R: --master=1.0 for the full volume)
	var gain := CliArgs.get_float("master", db_to_linear(AudioServer.get_bus_volume_db(0)))
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var err := wav.save_to_wav(out)
	# the signal in front of the limiter (float frames), with the same Master volume
	var pre := AudioStreamWAV.new()
	pre.format = AudioStreamWAV.FORMAT_16_BITS
	pre.stereo = true
	pre.mix_rate = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(_pre.size() * 4)
	var clip := 0
	var peak := 0.0
	for i in _pre.size():
		var l := _pre[i].x * gain
		var r := _pre[i].y * gain
		peak = maxf(peak, maxf(absf(l), absf(r)))
		if absf(l) > 1.0 or absf(r) > 1.0:
			clip += 1
		bytes.encode_s16(i * 4, clampi(int(round(l * 32767.0 * 0.5)), -32768, 32767))      # stored at −6 dB (headroom)
		bytes.encode_s16(i * 4 + 2, clampi(int(round(r * 32767.0 * 0.5)), -32768, 32767))
	pre.data = bytes
	pre.save_to_wav(out.get_basename() + "_pre.wav")
	print("worst_case: %s (%.1f s) -> %s; vor dem Begrenzer: Spitze %.2f dBFS, %d Frames über 0 dBFS (Datei _pre um 6 dB abgesenkt)" % [
		out, seconds, error_string(err), linear_to_db(maxf(peak, 1.0e-9)), clip])
	print("worst_case: Zustand ", JSON.stringify((_am.get("_modern") as Object).call("debug_state")["mix"]))
	_am.call("set_music", false)
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)
