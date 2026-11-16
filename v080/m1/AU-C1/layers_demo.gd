extends SceneTree
## AU-C1 layer previews for the user, recorded at the Master in real time with the Modern profile (the real runtime
## laws, the real track Kiel – Hamburg for the feed). Engine and other groups can be muted with --mute-bus.
##   godot --headless --path . -s <this file> -- --scenario=belaege|ruettel|wind|quietschen|aufprall --out=/abs/x.wav
## Writes <out>.wav and <out>.json (marks: t, label).

var _am: Node
var _rec: AudioEffectRecord
var _marks: Array = []
var _t0 := 0
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _weather := "normal"
var _vehicle := "limousine"


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _mark(label: String) -> void:
	_marks.append({"t": snappedf(_now(), 0.01), "label": label})
	print("mark %6.2f %s" % [_now(), label])


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


func _frame(dt: float, throttle: float, extra: Dictionary) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, throttle, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_environment", {"tunnel": bool(extra.get("in_tunnel", false))})
	var st := {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0, "understeer": 0.0,
		"lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y, "shoulder_m": _track.shoulder_w,
		"in_tunnel": false, "weather": _weather, "hour": 12.0, "crash": false, "finished": false}
	st.merge(extra, true)
	_am.call("set_vehicle_state", st)


func _drive(seconds: float, target_kmh: float, accel: float, throttle: float, extra: Dictionary = {}, x_to: float = NAN, x_rate: float = 2.0) -> void:
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


func _gap(seconds: float) -> void:
	# silence between examples: the session stops calling (everything fades out)
	var t0 := _now()
	while _now() - t0 < seconds:
		await process_frame


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "user://layers.wav")
	var scenario := CliArgs.get_string("scenario", "belaege")
	_vehicle = CliArgs.get_string("vehicle", "limousine")
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
	_am.call("set_vehicle", _vehicle)
	_am.call("set_track", _track, _plan)
	var feed: AudioFeed = (_am.get("_modern") as Object).get("feed")
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	match scenario:
		"belaege":
			await _belaege(feed)
		"ruettel":
			await _ruettel(feed)
		"wind":
			await _wind()
		"quietschen":
			await _quietschen()
		"aufprall":
			await _aufprall()
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
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"scenario": scenario, "vehicle": _vehicle, "seconds": total, "marks": _marks,
		"mute": CliArgs.get_string("mute-bus", "")}, "\t") + "\n")
	f.close()
	print("layers_demo: %s %s (%.1f s) -> %s" % [scenario, out, total, error_string(err)])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)


## Surfaces in a row at 100 km/h (cobbles at 50): asphalt, concrete, steel deck, cobbles, gravel shoulder, grass,
## wet asphalt, snow.
func _belaege(feed: AudioFeed) -> void:
	feed.concrete_share = {"_": 0.0}
	_v = 100.0
	_teleport(30.0)
	_mark("Asphalt 100 km/h")
	await _drive(4.0, 100.0, 1.0, 0.3)
	feed.concrete_share = {"_": 1.0}
	feed._concrete.clear()
	_mark("Beton 100 km/h (mit Plattenfugen)")
	await _drive(4.5, 100.0, 1.0, 0.3)
	feed.concrete_share = {"_": 0.0}
	feed._concrete.clear()
	var br: Dictionary = {}
	for b: Dictionary in _plan.bridges:
		if str(b.get("type", "")) == "cable_stayed":
			br = b
	_teleport(float(br.get("start_km", 78.0)) + 0.1)
	_mark("Stahldeck 100 km/h")
	await _drive(4.0, 100.0, 1.0, 0.3)
	feed.cobble_share = 1.0
	feed._cobbles.clear()
	_v = 50.0
	_teleport(_plan.city_center_km + 1.0)
	_mark("Kopfsteinpflaster 50 km/h")
	await _drive(4.5, 50.0, 1.0, 0.25)
	feed.cobble_share = 0.6
	feed._cobbles.clear()
	_v = 100.0
	_teleport(40.0)
	_x = 6.6
	_mark("Bankett rechts 100 km/h")
	await _drive(4.0, 100.0, 1.0, 0.3, {"off_road": 1})
	_x = 5.625 + 2.5 - 0.93
	_mark("Gras am Rand (beide Seiten neben der Fahrbahn) 60 km/h")
	_v = 60.0
	_x = 9.5
	await _drive(4.0, 60.0, 1.0, 0.3, {"off_road": 2, "x": 9.5, "road_left": -5.625, "road_right": 5.625})
	_x = 1.875
	_weather = "rain"
	_v = 100.0
	_mark("Asphalt nass 100 km/h")
	await _drive(4.5, 100.0, 1.0, 0.3)
	_weather = "snow"
	_mark("Schnee 80 km/h")
	_v = 80.0
	await _drive(5.0, 80.0, 1.0, 0.3)
	_weather = "normal"


## Rumble strip at 60 / 120 / 200 km/h, bridge joints (steel, concrete) at 60 / 120 / 200, concrete slabs at
## 90 / 140 / 200.
func _ruettel(feed: AudioFeed) -> void:
	for kmh: float in [60.0, 120.0, 200.0]:
		_v = kmh
		_x = 1.875
		_teleport(30.0 + kmh * 0.05)
		_mark("Rüttelstreifen rechts %d km/h" % int(kmh))
		await _drive(1.0, kmh, 1.0, 0.3)
		await _drive(2.2, kmh, 1.0, 0.3, {}, 5.15, 4.0)
		await _drive(1.0, kmh, 1.0, 0.3, {}, 1.875, 4.0)
	var br: Dictionary = {}
	for b: Dictionary in _plan.bridges:
		if str(b.get("type", "")) == "cable_stayed":
			br = b
	for kmh: float in [60.0, 120.0, 200.0]:
		_v = kmh
		_x = 1.875
		_teleport(float(br.get("start_km", 78.0)) - kmh / 3.6 / 100.0 * 0.6)
		_mark("Stahlbrücke, Fugen bei %d km/h" % int(kmh))
		await _drive(3.5, kmh, 1.0, 0.3)
	feed.concrete_share = {"_": 1.0}
	feed._concrete.clear()
	for kmh: float in [90.0, 140.0, 200.0]:
		_v = kmh
		_teleport(20.0 + kmh * 0.04)
		_mark("Betonplatten %d km/h" % int(kmh))
		await _drive(3.5, kmh, 1.0, 0.3)
	feed.concrete_share = {"_": 0.1}
	feed._concrete.clear()


## Wind from 50 to 250 km/h in the open (gusts), then 220 km/h in a tunnel (no state: the tunnel of the calls) and
## on a bridge.
func _wind() -> void:
	_v = 50.0
	_teleport(30.0)
	_mark("Wind 50 km/h")
	var t0 := _now()
	var last := _now()
	var marked := 50
	while _v < 249.5:
		await process_frame
		var dt := _now() - last
		last = _now()
		_v = minf(250.0, 50.0 + (_now() - t0) * 8.0)
		if int(_v) >= marked + 50:
			marked += 50
			_mark("%d km/h" % marked)
		_frame(dt, 0.5, {})
	await _drive(3.0, 250.0, 1.0, 0.5)
	_mark("250 km/h Brücke (stärker, böiger)")
	var br: Dictionary = _plan.bridges[0] if not _plan.bridges.is_empty() else {}
	_teleport(float(br.get("start_km", 80.0)) - 0.05)
	await _drive(2.5, 250.0, 1.0, 0.5)


## Squeal: understeer 0.3 / 0.6 / 1.0 at 120 km/h, a sharp lane change, wet, on gravel, the slide of a crash.
func _quietschen() -> void:
	_v = 120.0
	_teleport(30.0)
	for us: float in [0.3, 0.6, 1.0]:
		_mark("Untersteuern %.1f bei 120 km/h" % us)
		await _drive(2.5, 120.0, 1.0, 0.4, {"understeer": us, "steer": 0.8})
		await _drive(1.0, 120.0, 1.0, 0.4)
	_mark("scharfer Spurwechsel (Querbewegung 4 m/s)")
	await _drive(1.5, 120.0, 1.0, 0.4, {"lat_speed": 4.5})
	await _drive(1.0, 120.0, 1.0, 0.4)
	_weather = "rain"
	_mark("Untersteuern 0.8 nass")
	await _drive(2.5, 120.0, 1.0, 0.4, {"understeer": 0.8})
	_weather = "normal"
	await _drive(1.0, 120.0, 1.0, 0.4)
	_mark("Rutschen beim Unfall")
	await _drive(2.0, 90.0, 20.0, 0.0, {"crash": true})
	await _drive(1.5, 90.0, 1.0, 0.3)


## Impacts by speed and partner, the guardrail, a delineator.
func _aufprall() -> void:
	_v = 110.0
	_teleport(30.0)
	await _drive(1.0, 110.0, 1.0, 0.4)
	var hits := [["Rempler, 6 km/h Unterschied", 6.0, false, 1], ["Auffahren, 30 km/h Unterschied", 30.0, false, 0],
		["schwerer Aufprall, 70 km/h", 70.0, false, -1], ["schwerer Aufprall, 130 km/h", 130.0, false, 1],
		["Lkw, 40 km/h Unterschied", 40.0, true, 1], ["Lkw, 110 km/h Unterschied", 110.0, true, -1]]
	for h: Array in hits:
		_mark(str(h[0]))
		_am.call("play", "crash")
		_am.call("event", "collision", {"speed_kmh": _v, "rel_kmh": float(h[1]), "heavy": bool(h[2]), "side": int(h[3])})
		await _drive(2.6, 110.0, 1.0, 0.3)
	for r: Array in [["Leitplanke gestreift (0,5 m/s)", 0.5], ["Leitplanke getroffen (2 m/s)", 2.0], ["Leitplanke hart (5 m/s)", 5.0]]:
		_mark(str(r[0]))
		_am.call("play", "rail", clampf(-10.0 + 2.0 * float(r[1]), -10.0, 2.0))
		_am.call("event", "rail_hit", {"impact_mps": float(r[1]), "side": 1})
		await _drive(2.2, 110.0, 1.0, 0.3)
	var lim := 5.625 + 2.5 - 0.93
	_x = lim
	_mark("an der Leitplanke entlang schleifen, 110 → 60 km/h")
	await _drive(4.0, 60.0, 12.0, 0.2, {"rail_contact": true, "off_road": 2})
	_x = 1.875
	await _drive(1.0, 60.0, 1.0, 0.3)
	_mark("Leitpfosten umgefahren (90 km/h)")
	_v = 90.0
	await _drive(0.3, 90.0, 1.0, 0.3)
	var m: Object = _am.get("_modern")
	m.call("event", "pass_object", {"kind": "post", "set": "delineator", "side": 1, "dist_m": 0.6, "size": 0.15, "contact": true, "z": _z})
	await _drive(2.0, 90.0, 1.0, 0.3)
