extends SceneTree
## AU-C1 demo drive for the user: Kiel – Hamburg in the Modern sound, the session's sound calls along a scripted path
## (real track and plan as the race session builds them; the feed reads them), recorded at the Master in real time:
## motorway (asphalt into a concrete section) → steel bridge with its joints (Köhlbrandbrücke) → rumble strip →
## gravel shoulder → guardrail hit and scrape → cobbles of Hamburg's centre. Writes <out>.wav and <out>.json (phases).
##   godot --headless --path . -s <this file> -- --out=/abs/drive.wav [--vehicle=limousine] [--music]

var _am: Node
var _rec: AudioEffectRecord
var _phases: Array = []
var _t0 := 0
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _feed := AudioFeed.new()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _mark(name: String, extra: Dictionary = {}) -> void:
	var p := {"name": name, "t": snappedf(_now(), 0.01), "km": snappedf(_track.z_to_km(_z), 0.01)}
	p.merge(extra)
	_phases.append(p)
	print("phase %-10s t=%5.2f km=%6.2f %s" % [name, _now(), _track.z_to_km(_z), JSON.stringify(extra)])


## Jumps to km. The Track only generates forward (segments behind its window are gone): a jump back builds the
## same track again and hands it to the sound (set_track) as a new stage would.
func _teleport(km: float) -> void:
	var z := _track.km_to_z(km)
	if z < _z - 1.0:
		_track = _new_track()
		_am.call("set_track", _track, _plan)
	_z = z
	_track.update_window(_z - 9.0, 600.0)


func _new_track() -> Track:
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var t := Track.new()
	t.setup(_plan, ConfigLoader.load_merged(), (sc as Dictionary).get("scenery", {}))
	return t


## One frame of the session's sound calls.
func _frame(dt: float, throttle: float, extra: Dictionary = {}) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	var vmax := 245.0
	_am.call("set_engine", _v, throttle, vmax, true)
	_am.call("set_wind", _v)
	_am.call("set_environment", {"tunnel": _track.is_tunnel_at(_z - 9.0)})
	var st := {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0, "understeer": 0.0,
		"lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y, "shoulder_m": _track.shoulder_w,
		"in_tunnel": _track.is_tunnel_at(_z - 9.0), "weather": "normal", "hour": 12.0, "crash": false, "finished": false}
	st.merge(extra, true)
	_am.call("set_vehicle_state", st)


func _drive(seconds: float, target_kmh: float, accel: float, throttle: float, x_to: float = NAN, x_rate: float = 1.5, extra: Dictionary = {}) -> void:
	var t0 := _now()
	var last := _now()
	while _now() - t0 < seconds:
		await process_frame
		var dt := _now() - last
		last = _now()
		_v = move_toward(_v, target_kmh, accel * dt)
		if not is_nan(x_to):
			_x = move_toward(_x, x_to, x_rate * dt)
		_frame(dt, throttle, extra)


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "user://drive.wav")
	var vehicle := CliArgs.get_string("vehicle", "limousine")
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
	_track = _new_track()
	_am.call("set_vehicle", vehicle)
	_am.call("set_track", _track, _plan)
	# where things are: a section boundary asphalt → concrete, the steel bridge, a cobbled block of the centre
	var probe := AudioFeed.new()
	probe.setup(ConfigLoader.lookup(cfg, "audio.modern", {}))
	probe.set_track(_track, _plan)
	var boundary := -1.0
	for i in _plan.sections.size() - 1:
		var a: Dictionary = _plan.sections[i]
		var b: Dictionary = _plan.sections[i + 1]
		var ca := probe._concrete_section((float(a["start_km"]) + float(a["end_km"])) * 0.5)
		var cb := probe._concrete_section((float(b["start_km"]) + float(b["end_km"])) * 0.5)
		print("Abschnitt %d %s %.1f–%.1f km: %s" % [i, str(a.get("name", "")), float(a["start_km"]), float(a["end_km"]), "Beton" if ca else "Asphalt"])
		if boundary < 0.0 and not ca and cb and str(b.get("road", "")) == "autobahn" and float(b["start_km"]) < _plan.city_limits_km:
			boundary = float(b["start_km"])
	var bridge: Dictionary = {}
	for br: Dictionary in _plan.bridges:
		if str(br.get("type", "")) == "cable_stayed":
			bridge = br
	if bridge.is_empty() and not _plan.bridges.is_empty():
		bridge = _plan.bridges[0]
	var cobble_km := -1.0
	var k := _plan.city_center_km + 0.2
	while k < _plan.length_km - 2.0:
		if probe._cobbled(k) and not probe._cobbled(k - 0.9):
			cobble_km = k - 0.5
			break
		k += 0.1
	print("Grenze Asphalt/Beton bei km %.2f, Brücke %s bei km %.2f–%.2f, Pflaster ab km %.2f (Zentrum ab %.2f, Stil %s)" % [boundary,
		str(bridge.get("name", "")), float(bridge.get("start_km", -1.0)), float(bridge.get("end_km", -1.0)), cobble_km,
		_plan.city_center_km, _plan.city_style])
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	if CliArgs.has("music"):
		_am.call("set_music", true)
		_am.call("set_music_context", "race", {})
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	# 1 motorway: 170 km/h on asphalt into the concrete section (the slabs' ta-tock)
	_v = 170.0
	_x = 1.875
	var m1 := boundary - 0.47 * 5.0 if boundary > 0.0 else 30.0
	_teleport(m1)
	_mark("autobahn", {"km_beton": boundary})
	await _drive(9.5, 175.0, 3.0, 0.55)
	# 2 the steel bridge: 120 km/h, its expansion joints
	_v = 120.0
	_teleport(float(bridge.get("start_km", 78.0)) - 0.33 * 2.5)
	_mark("bruecke", {"name": str(bridge.get("name", "")), "km0": float(bridge.get("start_km", 0.0)), "km1": float(bridge.get("end_km", 0.0))})
	await _drive(11.0, 122.0, 2.0, 0.4)
	# 3 back on the A7 (guardrail, profiled edge lines): drift onto the rumble strip
	_v = 125.0
	_x = 1.875
	_teleport(52.0)
	_mark("ruettelstreifen")
	await _drive(1.2, 125.0, 1.0, 0.35)
	await _drive(2.8, 125.0, 1.0, 0.35, 5.15, 2.6)
	await _drive(1.5, 125.0, 1.0, 0.35, 1.875, 3.0)
	# 4 the gravel shoulder
	_mark("bankett")
	await _drive(0.8, 110.0, 8.0, 0.2, 6.55, 3.5)
	await _drive(2.8, 105.0, 3.0, 0.3, 6.55, 1.0, {"off_road": 1})
	await _drive(1.2, 105.0, 3.0, 0.3, 1.875, 4.5)
	# 5 the guardrail: a hit, then scraping along it
	_mark("leitplanke")
	await _drive(0.9, 100.0, 3.0, 0.3, 5.5, 4.5)
	var lim := 5.625 + 2.5 - 0.93
	_x = lim
	_am.call("play", "rail", clampf(-10.0 + 2.0 * 2.2, -10.0, 2.0))
	_am.call("event", "rail_hit", {"impact_mps": 2.2, "side": 1})
	await _drive(3.0, 85.0, 5.0, 0.25, lim, 1.0, {"rail_contact": true, "off_road": 2})
	await _drive(1.5, 85.0, 5.0, 0.3, 1.875, 3.5)
	# 6 Hamburg's centre: 50 km/h over cobbles
	_v = 50.0
	_x = 1.875
	_teleport(cobble_km if cobble_km > 0.0 else _plan.length_km - 1.5)
	_mark("pflaster", {"km": cobble_km})
	await _drive(11.0, 50.0, 2.0, 0.25)
	_mark("ende")
	var total := _now()
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0))
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var err := wav.save_to_wav(out)
	var dbg: Dictionary = (_am.get("_modern") as Object).call("debug_state")
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"vehicle": vehicle, "seconds": total, "phases": _phases, "events": dbg.get("events", {}),
		"road": dbg["slots"]["road"], "impact": dbg["slots"]["impact"]}, "\t") + "\n")
	f.close()
	print("drive_demo: %s (%.1f s) -> %s; Ereignisse %s" % [out, total, error_string(err), JSON.stringify(dbg.get("events", {}))])
	_am.call("set_music", false)
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)
