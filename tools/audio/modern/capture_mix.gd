extends SceneTree
## Records what a sound profile puts on the Master bus during a scripted drive or in the menu – for the loudness plan
## (docs/audio-modern.md "Pegelplan"). Real time, also headless (the Dummy audio driver mixes as usual):
##
##   godot --headless --path . -s res://tools/audio/modern/capture_mix.gd -- --sound=modern --scenario=drive \
##       --vehicle=gran_turismo --out=/tmp/mix_modern_gt.wav
##   … --scenario=menu --seconds=60        the menu music from its start
##   … --scenario=race_music --seconds=30  music context "race" over the drive (needs a race piece; with
##                                         --placeholders the placeholder)
## Then: python3 tools/audio/modern/measure_mix.py /tmp/mix_modern_gt.wav
##
##   … --mute-bus=MEnv                     with race_music: the music alone (the car's group is muted, the ducking
##                                         still follows the drive)
## Output: <out>.wav (16 bit, 44.1 kHz, the signal after the Master volume and limiter – what reaches the sound
## card) and <out>.json with the phases of the scenario {name, t0, t1} and the settings; with the Modern profile
## each phase also has car_plan_lufs (the car's loudness after the plan, the key of the ducking), duck_db (the
## ducking of the music) and car_bus_peak_db (the highest block peak of the car bus). The drive: 3 s idle, full
## throttle from a standstill to top speed (the car's own acceleration curve), 6 s flat out, 3 s off the throttle,
## 8 s cruising at 130 km/h; wind as the race session sends it, no traffic, no tunnel.
## In a headless run the Arcade sounds are built as on a display and the Modern profile plays (ModernAudio.force_live).

var _am: Node
var _rec: AudioEffectRecord
var _phases: Array = []
var _t0 := 0
var _key_sum := 0.0              # Modern: the car's loudness after the plan (ducking key) over the running phase
var _key_n := 0
var _peak := -200.0              # Modern: highest block peak of the car bus in the running phase
var _duck_sum := 0.0
var _sample_from := 0.0          # the phase is measured from this time on


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _phase(phase_name: String, t0: float, t1: float) -> void:
	var p := {"name": phase_name, "t0": snappedf(t0, 0.001), "t1": snappedf(t1, 0.001)}
	if _key_n > 0:
		p["car_plan_lufs"] = snappedf(_key_sum / _key_n, 0.01)
		p["car_bus_peak_db"] = snappedf(_peak, 0.01)
		p["duck_db"] = snappedf(_duck_sum / _key_n, 0.01)
	_phases.append(p)
	_key_sum = 0.0
	_key_n = 0
	_peak = -200.0
	_duck_sum = 0.0


## Modern: what the mix saw of the car bus in this frame.
func _sample_mix() -> void:
	var m: Variant = _am.get("_modern")
	if not (m is ModernAudio) or _now() < _sample_from:
		return
	var mo: ModernAudio = m
	if mo.mix.car > -150.0:
		_key_sum += mo.mix.car
		_key_n += 1
		_duck_sum += mo.mix.duck_db
	_peak = maxf(_peak, mo.buses.peak_db("MCar"))


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "user://capture_mix.wav")
	var profile := CliArgs.get_string("sound", "modern")
	var scenario := CliArgs.get_string("scenario", "drive")
	var vehicle := CliArgs.get_string("vehicle", "gran_turismo")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	if CliArgs.has("placeholders"):
		(cfg["audio"]["modern"] as Dictionary)["placeholders"] = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", profile)
	await process_frame
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	match scenario:
		"menu":
			await _menu(CliArgs.get_float("seconds", 60.0))
		"race_music":
			_am.call("set_music_context", "race", {})
			await _drive(vehicle)
		_:
			await _drive(vehicle)
	var total := _now()
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	_am.call("set_music", false)
	_am.call("stop_all")
	# the effect sits before the volume of Master: apply it, so the file is what leaves the bus
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0))
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var err := wav.save_to_wav(out)
	var info := {"profile": str(_am.call("profile")), "scenario": scenario, "vehicle": vehicle, "seconds": snappedf(total, 0.01),
		"mix_rate": int(wav.mix_rate), "master_db": AudioServer.get_bus_volume_db(0), "phases": _phases,
		"placeholders": CliArgs.has("placeholders"), "mute_buses": CliArgs.get_string("mute-bus", "").split(",", false),
		"engine": _am.call("engine_perf")}
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t") + "\n")
	f.close()
	print("capture_mix: %s (%s, %s, %.1f s) -> %s" % [out, info["profile"], scenario, total, error_string(err)])
	for j in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, j) == _rec:
			AudioServer.remove_bus_effect(0, j)
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)


func _menu(seconds: float) -> void:
	_am.call("set_music", true)
	_am.call("set_music_context", "menu", {})
	var t0 := _now()
	while _now() - t0 < seconds:
		await process_frame
	_phase("menu", t0 + 1.0, _now())


## One frame of the race session's sound calls.
func _send(speed: float, throttle: float, vmax: float) -> void:
	_am.call("set_engine", speed, throttle, vmax, true)
	_am.call("set_wind", speed)
	_am.call("set_environment", {"tunnel": false})
	_sample_mix()


func _drive(vehicle: String) -> void:
	var cfg := ConfigLoader.load_merged()
	var spec := VehicleModel.resolve_spec(cfg, vehicle)
	var vmax := float(spec.get("vmax_kmh", 245.0))
	var a0 := float(spec["accel_a0"])
	var q := float(spec["accel_q"])
	_am.call("set_vehicle", vehicle)
	var t0 := _now()
	_sample_from = t0 + 1.5
	while _now() - t0 < 3.0:
		_send(0.0, 0.0, vmax)
		await process_frame
	_phase("idle", t0 + 1.5, _now())
	t0 = _now()
	_sample_from = t0 + 1.0
	var v := 0.0
	var last := _now()
	while v < vmax * 0.985 and _now() - t0 < 60.0:
		var dt := _now() - last
		last = _now()
		v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, a0, q) + dt, vmax, a0, q)
		_send(v, 1.0, vmax)
		await process_frame
	_phase("full_throttle", t0 + 1.0, _now())
	t0 = _now()
	_sample_from = t0
	while _now() - t0 < 6.0:
		_send(vmax * 0.99, 1.0, vmax)
		await process_frame
	_phase("flat_out", t0, _now())
	t0 = _now()
	last = _now()
	while _now() - t0 < 3.0:
		v = maxf(130.0, v - 25.0 * (_now() - last))
		last = _now()
		_send(v, 0.0, vmax)
		await process_frame
	_phase("lift", t0, _now())
	t0 = _now()
	_sample_from = t0 + 2.0
	last = _now()
	while _now() - t0 < 9.0:
		v = move_toward(v, 130.0, 40.0 * (_now() - last))
		last = _now()
		_send(v, 0.22, vmax)
		await process_frame
	_phase("cruise_130", t0 + 2.0, _now())
