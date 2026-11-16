extends SceneTree
## KRITIK-MISCHUNG: the Modern game mix at fixed speeds on a real asphalt motorway section of Kiel – Hamburg (the
## session's sound calls incl. set_vehicle_state, so the road module works with the feed), recorded at the Master in
## real time. Phases: idle, 80 km/h (throttle 0.3), 130 (0.3), 130 (1.0), 200 (1.0), 250 (1.0), lift-off to 160,
## 130 (0.3). Writes <out>.wav and <out>.json (phases + a per-frame log of the ducking and the music clock).
##   godot --headless --path <copy> -s res://kritik_tools/mix_speeds.gd -- --out=/abs/x.wav --vehicle=gran_turismo \
##       [--music] [--mute-bus=MEnv] [--race-skip=N]   (N extra race contexts first: rotation step)

var _am: Node
var _rec: AudioEffectRecord
var _phases: Array = []
var _log: Array = []
var _t0 := 0
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _vmax := 270.0
var _music := false
var _start_km := 20.0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _new_track() -> Track:
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var t := Track.new()
	t.setup(_plan, ConfigLoader.load_merged(), (sc as Dictionary).get("scenery", {}))
	return t


func _teleport(km: float) -> void:
	var z := _track.km_to_z(km)
	if z < _z - 1.0:
		_track = _new_track()
		_am.call("set_track", _track, _plan)
	_z = z
	_track.update_window(_z - 9.0, 600.0)


func _frame(dt: float, throttle: float) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, throttle, _vmax, true)
	_am.call("set_wind", _v)
	_am.call("set_environment", {"tunnel": _track.is_tunnel_at(_z - 9.0)})
	var st := {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0, "understeer": 0.0,
		"lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y, "shoulder_m": _track.shoulder_w,
		"in_tunnel": _track.is_tunnel_at(_z - 9.0), "weather": "normal", "hour": 12.0, "crash": false, "finished": false}
	_am.call("set_vehicle_state", st)
	var m: Object = _am.get("_modern")
	var rec := {"t": snappedf(_now(), 0.001), "v": snappedf(_v, 0.1), "thr": throttle, "km": snappedf(_track.z_to_km(_z), 0.001)}
	if m != null:
		var mix: Object = m.get("mix")
		rec["duck"] = snappedf(float(mix.get("duck_db")), 0.001)
		rec["car"] = snappedf(float(mix.get("car")), 0.01)
		if _music:
			var dbg: Dictionary = (m.call("debug_state") as Dictionary)["slots"]["music"]
			rec["music_t"] = snappedf(float(dbg.get("music_t", -1.0)), 0.001)
			rec["pos"] = snappedf(float(dbg.get("position", -1.0)), 0.001)
			rec["piece"] = str(dbg.get("race_piece", ""))
	_log.append(rec)


func _hold(name: String, seconds: float, kmh: float, throttle: float, accel: float = 60.0) -> void:
	var t0 := _now()
	var last := _now()
	_phases.append({"name": name, "t0": snappedf(t0, 0.001), "kmh": kmh, "throttle": throttle})
	while _now() - t0 < seconds:
		await process_frame
		var dt := _now() - last
		last = _now()
		_v = move_toward(_v, kmh, accel * dt)
		_frame(dt, throttle)
	_phases[-1]["t1"] = snappedf(_now(), 0.001)
	print("phase %-10s %5.1f-%5.1f s  km %.2f" % [name, t0, _now(), _track.z_to_km(_z)])


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "user://mix_speeds.wav")
	var vehicle := CliArgs.get_string("vehicle", "gran_turismo")
	_music = CliArgs.has("music")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", "modern")
	await process_frame
	var spec := VehicleModel.resolve_spec(ConfigLoader.load_merged(), vehicle)
	_vmax = float(spec.get("vmax_kmh", 245.0))
	_plan = root.get_node("GameData").call("get_stage_plan", "kiel_hamburg", "kiel")
	_track = _new_track()
	_am.call("set_vehicle", vehicle)
	_am.call("set_track", _track, _plan)
	# the longest asphalt motorway section (no concrete) before the city limits
	var probe := AudioFeed.new()
	probe.setup(ConfigLoader.lookup(cfg, "audio.modern", {}))
	probe.set_track(_track, _plan)
	var best_km := 20.0
	var best_len := 0.0
	for i in _plan.sections.size():
		var a: Dictionary = _plan.sections[i]
		var k0 := float(a["start_km"])
		var k1 := float(a["end_km"])
		var conc := probe._concrete_section((k0 + k1) * 0.5)
		print("Abschnitt %d %s %.1f-%.1f km %s %s" % [i, str(a.get("name", "")), k0, k1, str(a.get("road", "")), "Beton" if conc else "Asphalt"])
		if not conc and str(a.get("road", "")) == "autobahn" and k1 < _plan.city_limits_km:
			# contiguous asphalt motorway: extend the run of the previous section
			if best_len > 0.0 and absf(k0 - (best_km - 0.3 + best_len)) < 0.01:
				best_len += k1 - k0
			elif k1 - k0 > best_len:
				best_len = k1 - k0
				best_km = k0 + 0.3
	_start_km = best_km
	print("Start bei km %.2f (Asphalt %.1f km lang)" % [best_km, best_len])
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	if _music:
		_am.call("set_music", true)
		for i in int(CliArgs.get_float("race-skip", 0.0)):
			_am.call("set_music_context", "race", {})
			await process_frame
		_am.call("set_music_context", "race", {})
	_teleport(best_km)
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	if _music:
		_am.call("event", "go", {})
	await _hold("idle", 5.0, 0.0, 0.0)
	_v = 80.0
	await _hold("v80", 12.0, 80.0, 0.3)
	_v = 130.0
	await _hold("v130", 12.0, 130.0, 0.3)
	await _hold("v130_full", 10.0, 130.0, 1.0)
	_v = 200.0
	_teleport(_start_km)
	await _hold("v200_full", 12.0, 200.0, 1.0)
	_v = minf(250.0, _vmax * 0.99)
	_teleport(_start_km)
	await _hold("v250_full", 12.0, minf(250.0, _vmax * 0.99), 1.0)
	await _hold("lift", 4.0, 160.0, 0.0, 22.0)
	await _hold("v130_back", 8.0, 130.0, 0.3, 15.0)
	var total := _now()
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0))
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var err := wav.save_to_wav(out)
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"vehicle": vehicle, "vmax": _vmax, "seconds": total, "phases": _phases, "log": _log,
		"master_db": AudioServer.get_bus_volume_db(0), "music": _music,
		"mute_buses": CliArgs.get_string("mute-bus", "").split(",", false)}) + "\n")
	f.close()
	print("mix_speeds: %s (%.1f s) -> %s" % [out, total, error_string(err)])
	_am.call("set_music", false)
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)
