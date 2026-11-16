extends SceneTree
## Scratch tool of AU-B (not part of the repo): records what a sound profile puts on the Master bus while the engine of
## one car is driven through a scripted drive – the car's engine alone (no wind, no traffic), as the game plays it
## through its buses. Real time, headless (Dummy driver). Modelled on tools/audio/modern/capture_mix.gd.
##   godot --headless --path <repo> -s <this file> -- --sound=arcade|modern --vehicle=kompakt --out=/abs/x.wav [--wind]
## Drive: start and idle 4 s · two blips in neutral · full throttle through the gears to 205 km/h (or 30 s) · 6 s at
## 200 km/h · lift 2.5 s · brake to 130 (downshifts) · 6 s at 130 km/h · kick-down 3.5 s · lift 2 s · brake to a stop.

const DT := 1.0 / 60.0

var _am: Node
var _rec: AudioEffectRecord
var _t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "user://ab_capture.wav")
	var profile := CliArgs.get_string("sound", "modern")
	var vehicle := CliArgs.get_string("vehicle", "gran_turismo")
	var with_wind := CliArgs.has("wind")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_music", false)
	_am.call("set_profile", profile)
	await process_frame
	var full := ConfigLoader.load_merged()
	var spec := VehicleModel.resolve_spec(full, vehicle)
	var vmax := float(spec.get("vmax_kmh", 245.0))
	var tl := _timeline(spec, vmax)
	var steps: Array = tl["steps"]
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	_am.call("set_vehicle", vehicle)
	var trace := {"t": [], "speed": [], "throttle": [], "rpm": [], "gear": [], "load": []}
	var total := steps.size() * DT
	while _now() < total:
		var i := mini(int(_now() / DT), steps.size() - 1)
		var st: Array = steps[i]
		_am.call("set_engine", float(st[0]), float(st[1]), vmax, true)
		if with_wind:
			_am.call("set_wind", float(st[0]))
		_am.call("set_environment", {"tunnel": false})
		var es: Dictionary = _am.call("engine_state")
		trace["t"].append(snappedf(_now(), 0.001))
		trace["speed"].append(snappedf(float(st[0]), 0.1))
		trace["throttle"].append(float(st[1]))
		trace["rpm"].append(snappedf(float(es.get("rpm", 0.0)), 1.0))
		trace["gear"].append(int(es.get("gear", 0)))
		trace["load"].append(snappedf(float(es.get("load", 0.0)), 0.01))
		await process_frame
	var seconds := _now()
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var perf: Dictionary = _am.call("engine_perf")
	_am.call("stop_all")
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0))
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var err := wav.save_to_wav(out)
	var info := {"profile": str(_am.call("profile")), "vehicle": vehicle, "seconds": snappedf(seconds, 0.01), "mix_rate": int(wav.mix_rate),
		"master_db": AudioServer.get_bus_volume_db(0), "phases": tl["phases"], "wind": with_wind, "engine": perf, "trace": trace}
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info) + "\n")
	f.close()
	print("ab_capture: %s %s -> %s (%.1f s, %s) perf %s" % [vehicle, info["profile"], out, seconds, error_string(err), str(perf)])
	for j in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, j) == _rec:
			AudioServer.remove_bus_effect(0, j)
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)


## The scripted drive: [[speed km/h, throttle], …] per 1/60 s and the phases (the same as work/e3render.gd "drive").
func _timeline(spec: Dictionary, vmax: float) -> Dictionary:
	var steps: Array = []
	var phases: Array = []
	var a0 := float(spec["accel_a0"])
	var q := float(spec["accel_q"])
	var v := 0.0
	var hold := func(name: String, seconds: float, speed: float, thr: float) -> void:
		var t_a := steps.size() * DT
		for i in int(round(seconds / DT)):
			steps.append([speed, thr])
		phases.append({"name": name, "t0": t_a, "t1": steps.size() * DT, "v0": speed, "v1": speed})
	hold.call("idle", 4.0, 0.0, 0.0)
	var t_a := steps.size() * DT
	for i in int(round(3.2 / DT)):
		var tt := i * DT
		var on := (tt >= 0.2 and tt < 0.5) or (tt >= 1.5 and tt < 2.0)
		steps.append([0.0, 1.0 if on else 0.0])
	phases.append({"name": "revs", "t0": t_a, "t1": steps.size() * DT, "v0": 0.0, "v1": 0.0})
	t_a = steps.size() * DT
	var v_top := minf(205.0, vmax * 0.9)
	var n := 0
	while v < v_top and n < int(30.0 / DT):
		v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, a0, q) + DT, vmax, a0, q)
		steps.append([v, 1.0])
		n += 1
	phases.append({"name": "pull", "t0": t_a, "t1": steps.size() * DT, "v0": 0.0, "v1": v})
	var v_hi := minf(v, 200.0)
	t_a = steps.size() * DT
	for i in int(round(6.0 / DT)):
		v = move_toward(v, v_hi, 20.0 * DT)
		steps.append([v, 0.45])
	phases.append({"name": "cruise_hi", "t0": t_a, "t1": steps.size() * DT, "v0": v_hi, "v1": v_hi})
	t_a = steps.size() * DT
	var v0 := v
	for i in int(round(2.5 / DT)):
		v = maxf(v - 7.0 * DT, 0.0)
		steps.append([v, 0.0])
	phases.append({"name": "lift", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
	t_a = steps.size() * DT
	v0 = v
	while v > 130.0:
		v = maxf(v - 30.0 * DT, 130.0)
		steps.append([v, 0.0])
	for i in int(round(0.6 / DT)):
		steps.append([v, 0.0])
	phases.append({"name": "brake", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
	hold.call("cruise_130", 6.0, 130.0, 0.22)
	t_a = steps.size() * DT
	v0 = v
	for i in int(round(3.5 / DT)):
		v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, a0, q) + DT, vmax, a0, q)
		steps.append([v, 1.0])
	phases.append({"name": "kickdown", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
	t_a = steps.size() * DT
	v0 = v
	for i in int(round(2.0 / DT)):
		v = maxf(v - 7.0 * DT, 0.0)
		steps.append([v, 0.0])
	phases.append({"name": "lift2", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
	t_a = steps.size() * DT
	v0 = v
	while v > 0.0:
		v = maxf(v - 32.0 * DT, 0.0)
		steps.append([v, 0.0])
	for i in int(round(2.0 / DT)):
		steps.append([0.0, 0.0])
	phases.append({"name": "stop", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": 0.0})
	return {"steps": steps, "phases": phases}
