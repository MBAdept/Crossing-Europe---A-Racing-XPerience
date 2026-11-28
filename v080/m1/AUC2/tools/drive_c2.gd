extends SceneTree
## AU-C2 review drive (scratch tool, not in the repo): the session's sound calls along scripted scenes on real stages
## (track and plan as the race session builds them; the feed reads them; synthetic traffic around the car), recorded
## at the Master in real time, one WAV per scene, and a JSON with what the slots saw.
##   godot --headless --path . -s <this> -- --out=/abs/dir [--vehicle=limousine] [--only=scene,scene] [--mute-bus=MWorld,…]

var _am: Node
var _rec: AudioEffectRecord
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _hour := 12.0
var _weather := "normal"
var _cars: Array = []           ## [{id, set, z, x, length, speed, heavy}]
var _police := {}               ## the police car (id -2) or {}
var _siren := 0.0
var _out := ""
var _log: Array = []
var _t0 := 0


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


func _stage(id: String, from: String) -> void:
	_plan = root.get_node("GameData").call("get_stage_plan", id, from)
	_track = _new_track()
	_am.call("set_track", _track, _plan)
	_z = 0.0


func _goto(km: float) -> void:
	var z := _track.km_to_z(km)
	if z < _z - 1.0:
		_track = _new_track()
		_am.call("set_track", _track, _plan)
	_z = z
	_track.update_window(_z - 9.0, 600.0)


func _frame(dt: float, throttle: float, extra: Dictionary = {}) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	var cam_tunnel := _track.is_tunnel_at(_z - 9.0)
	_am.call("set_engine", _v, throttle, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_rain", 1.0 if _weather == "rain" and not cam_tunnel else 0.0)
	_am.call("set_environment", {"tunnel": cam_tunnel})
	for c: Dictionary in _cars:
		c["z"] = float(c["z"]) + float(c["speed"]) / 3.6 * dt
	var list: Array = _cars.duplicate()
	if not _police.is_empty():
		_police["z"] = float(_police["z"]) + float(_police["speed"]) / 3.6 * dt
		list.append(_police)
	if _siren > 0.0:
		_am.call("set_siren", true, _siren)
	_am.call("set_traffic", list, {"z": _z - 9.0, "x": _x, "speed": _v})
	var st := {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0, "understeer": 0.0,
		"lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": cam_tunnel, "weather": _weather, "hour": _hour, "crash": false,
		"finished": false}
	st.merge(extra, true)
	_am.call("set_vehicle_state", st)


func _drive(seconds: float, target_kmh: float, accel: float, throttle: float, extra: Dictionary = {}) -> void:
	var t0 := _now()
	var last := _now()
	while _now() - t0 < seconds:
		await process_frame
		var dt := _now() - last
		last = _now()
		_v = move_toward(_v, target_kmh, accel * dt)
		_frame(dt, throttle, extra)


func _snapshot() -> Dictionary:
	var dbg: Dictionary = (_am.get("_modern") as Object).call("debug_state")
	var feed: Dictionary = dbg["feed"]
	return {"feed": {"zone": feed.get("zone"), "cover": feed.get("cover"), "water": feed.get("water"),
		"climate": feed.get("climate"), "style": feed.get("style"), "scenery": feed.get("scenery"), "city": feed.get("city"),
		"wet": feed.get("wet")}, "env": dbg["slots"]["env"], "ambience": dbg["slots"]["ambience"],
		"traffic": dbg["slots"]["traffic"], "events": dbg.get("events", {})}


func _start_rec() -> void:
	_rec.set_recording_active(true)


func _stop_rec(name: String, info: Dictionary) -> void:
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0))
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var path := _out.path_join(name + ".wav")
	var err := wav.save_to_wav(path)
	info["file"] = path
	info["snapshot"] = _snapshot()
	_log.append(info)
	print("Szene %-12s -> %s %s" % [name, error_string(err), JSON.stringify(info["snapshot"]["feed"])])


func _car(id: int, set_id: String, rel_z: float, x: float, kmh: float, length := 4.6, heavy := false) -> Dictionary:
	return {"id": id, "set": set_id, "z": _z + rel_z, "x": x, "length": length, "speed": kmh, "heavy": heavy}


func _wants(scene: String) -> bool:
	var only := CliArgs.get_string("only", "")
	return only == "" or (only.split(",") as PackedStringArray).has(scene)


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	_out = CliArgs.get_string("out", "user://")
	DirAccess.make_dir_recursive_absolute(_out)
	var vehicle := CliArgs.get_string("vehicle", "limousine")
	var cfg: Dictionary = _am.get("_audio_cfg")
	if CliArgs.has("horn-always"):
		cfg["audio"]["modern"]["traffic"]["horns"]["after_collision"] = 1.0
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", "modern")
	await process_frame
	_am.call("set_vehicle", vehicle)
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_t0 = Time.get_ticks_usec()

	# 1 Hamburg, the centre by the port in the morning (the end of Kiel – Hamburg): standing, then 45 km/h
	if _wants("hamburg"):
		_stage("kiel_hamburg", "kiel")
		_hour = 9.5
		_weather = "normal"
		_goto(89.0)
		_v = 0.0
		_cars = [_car(1, "traffic/hatch_red", 30.0, 3.75, 0.0), _car(2, "traffic/sedan_blue", -15.0, -3.75, 0.0)]
		_start_rec()
		await _drive(9.0, 0.0, 1.0, 0.0)
		await _drive(9.0, 45.0, 6.0, 0.35)
		_stop_rec("hamburg", {"title": "Hamburg, Zentrum am Hafen, 9:30 Uhr: Stand am Start, dann 45 km/h"})
	# 2 the Elbtunnel with trucks, 80 km/h
	if _wants("tunnel"):
		_stage("hamburg_hannover", "hamburg")
		var t: Dictionary = _plan.tunnels[0]
		_hour = 11.0
		_goto(float(t.get("start_km", 5.0)) - 0.25)
		_v = 80.0
		_cars = [_car(11, "traffic/truck_red", 60.0, 3.75, 72.0, 16.5, true), _car(12, "traffic/truck_white", 140.0, 3.75, 70.0, 16.5, true),
			_car(13, "traffic/sedan_grey", -40.0, -0.0, 95.0)]
		_start_rec()
		await _drive(16.0, 80.0, 2.0, 0.35)
		_stop_rec("tunnel", {"title": "Elbtunnel mit 80 km/h: Lkw rechts, ein Pkw überholt", "tunnel": t})
	# 3 the heath motorway, 140 km/h: overtaking a truck (gust), a car passes us, a police chase passes
	if _wants("autobahn"):
		_stage("hamburg_hannover", "hamburg")
		_hour = 14.0
		_goto(40.0)
		_v = 140.0
		_x = 1.875
		_cars = [_car(21, "traffic/truck_red", 70.0, 5.6, 85.0, 16.5, true), _car(22, "traffic/sedan_blue", -70.0, -1.875, 185.0),
			_car(23, "traffic/wagon_grey", 160.0, 5.6, 115.0), _car(24, "traffic/hatch_yellow", 260.0, 1.875, 120.0)]
		_start_rec()
		await _drive(14.0, 140.0, 2.0, 0.5)
		_police = {"id": -2, "set": "police/de", "z": _z - 260.0, "x": -1.875, "length": 4.8, "speed": 212.0}
		_siren = 0.9
		await _drive(16.0, 140.0, 2.0, 0.5)
		_siren = 0.0
		_am.call("set_siren", false, 0.0)
		_police = {}
		await _drive(3.0, 140.0, 2.0, 0.5)
		_stop_rec("autobahn", {"title": "Heide, 140 km/h: Lkw überholt (Luftstoß), Pkw überholt uns, Polizei mit Martinshorn fährt vorbei"})
	# 4 a collision with a car: its driver honks
	if _wants("unfall"):
		_stage("hamburg_hannover", "hamburg")
		_hour = 15.0
		_goto(55.0)
		_v = 110.0
		_cars = [_car(31, "traffic/sedan_red", 12.0, 3.0, 100.0)]
		_start_rec()
		await _drive(2.0, 110.0, 2.0, 0.4)
		_am.call("play", "crash")
		_am.call("event", "collision", {"speed_kmh": 30.0, "heavy": false, "side": 1})
		await _drive(5.0, 95.0, 4.0, 0.2)
		_stop_rec("unfall", {"title": "Auffahrunfall mit 30 km/h Unterschied: der andere hupt"})
	# 5 forest at dawn, slow
	if _wants("wald"):
		_stage("kassel_wuerzburg", "kassel")
		_hour = 6.4
		_weather = "normal"
		_cars = []
		_goto(60.0)
		_v = 25.0
		_start_rec()
		await _drive(22.0, 25.0, 1.0, 0.15)
		_stop_rec("wald", {"title": "Wald bei Kassel, 6:24 Uhr (Morgenchor), 25 km/h"})
	# 6 the same forest at night, then rain
	if _wants("nacht"):
		_stage("kassel_wuerzburg", "kassel")
		_hour = 23.5
		_weather = "normal"
		_goto(80.0)
		_v = 0.0
		_start_rec()
		await _drive(18.0, 0.0, 1.0, 0.0)
		_weather = "rain"
		await _drive(12.0, 0.0, 1.0, 0.0)
		_stop_rec("nacht", {"title": "Hessisches Bergland, 23:30 Uhr im Stand, nach 18 s Regen"})
	# 7 the Mediterranean at noon
	if _wants("mittelmeer"):
		_stage("montpellier_lyon", "montpellier")
		_hour = 14.0
		_weather = "normal"
		_goto(20.0)
		_v = 40.0
		_start_rec()
		await _drive(18.0, 40.0, 1.0, 0.2)
		_stop_rec("mittelmeer", {"title": "Bei Montpellier, 14 Uhr, 40 km/h"})
	# 8 an Alpine valley: the slap echo of the slopes
	if _wants("tal"):
		_stage("bern_mailand", "bern")
		_hour = 12.0
		_goto(150.0)
		_v = 90.0
		_start_rec()
		await _drive(14.0, 90.0, 2.0, 0.45)
		_stop_rec("tal", {"title": "Alpen zwischen Bern und Mailand, 90 km/h"})
	# 9 the fuel station on Kiel – Hamburg (km 15): standing under the canopy
	if _wants("tankstelle"):
		_stage("kiel_hamburg", "kiel")
		_hour = 21.0
		var zc := 0.0
		for zn: Dictionary in _track.zones:
			if str(zn.get("kind", "")) == "fuel_canopy":
				zc = (float(zn["z0"]) + float(zn["z1"])) * 0.5
				break
		_goto(_track.z_to_km(zc))
		_v = 0.0
		_x = 9.0
		_start_rec()
		await _drive(10.0, 0.0, 1.0, 0.0)
		_stop_rec("tankstelle", {"title": "Tankstelle bei Kiel, 21 Uhr, im Stand unter dem Dach"})
	var f := FileAccess.open(_out.path_join("szenen.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_log, "\t") + "\n")
	f.close()
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
