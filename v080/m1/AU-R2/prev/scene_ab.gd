extends SceneTree
## AU-R previews (real time, Master, Modern profile, real track Kiel – Hamburg):
##   --scenario=bruecke   Köhlbrandbrücke at 120 km/h (joints: AU-C1 every 24 m, AU-R steel ends + ~100 m)
##   --scenario=aufprall  eight heavy and medium crashes in a row at 110 km/h (variants, glass only sometimes)
##   --scenario=schnee    snow at 50, 90, 130 km/h (Limousine, engine + road + wind)
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --scenario=… --out=/abs/x.wav [--master=1.0]
## Writes <out>.wav (scaled to the master volume, default 0.8 as in the game) and <out>.json (marks; joints seen).

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


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _mark(label: String) -> void:
	_marks.append({"t": snappedf(_now(), 0.01), "label": label, "km": snappedf(_track.z_to_km(_z), 0.01)})
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


func _frame(dt: float, throttle: float) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, throttle, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_environment", {"tunnel": false})
	_am.call("set_vehicle_state", {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": false, "weather": _weather, "hour": 12.0, "crash": false, "finished": false})


func _drive(seconds: float, target: float, accel: float, throttle: float) -> void:
	var t0 := _now()
	var last := _now()
	while _now() - t0 < seconds:
		await process_frame
		var dt := _now() - last
		last = _now()
		_v = move_toward(_v, target, accel * dt)
		_frame(dt, throttle)


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "")
	var scenario := CliArgs.get_string("scenario", "bruecke")
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
	_am.call("set_vehicle", "limousine")
	_am.call("set_track", _track, _plan)
	var modern: Object = _am.get("_modern")
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	var joints: Array = []
	match scenario:
		"bruecke":
			var br: Dictionary = {}
			for b: Dictionary in _plan.bridges:
				if str(b.get("type", "")) == "cable_stayed":
					br = b
			_v = 120.0
			_teleport(float(br.get("start_km", 78.0)) - 0.6)
			_mark("vor der Köhlbrandbrücke, 120 km/h")
			var t0 := _now()
			var last := _now()
			var n0 := int((modern.get("road") as Object).get("joints"))
			while _now() - t0 < 11.0:
				await process_frame
				var dt := _now() - last
				last = _now()
				_frame(dt, 0.35)
				var feed: Object = modern.get("feed")
				for e: Dictionary in (feed.get("events") as Array):
					if str(e.get("name")) == "joint":
						joints.append({"t": snappedf(_now(), 0.01), "km": snappedf(_track.z_to_km(float(e["z"])), 0.001), "kind": e.get("kind"), "deck": e.get("deck")})
			_mark("Ende")
			print("Fugen: ", int((modern.get("road") as Object).get("joints")) - n0, " ", JSON.stringify(joints))
		"aufprall":
			_v = 110.0
			_teleport(30.0)
			await _drive(1.5, 110.0, 1.0, 0.4)
			var hits := [["schwer, 130 km/h Schließgeschwindigkeit", 130.0, false, 1], ["mittel, 35 km/h", 35.0, false, -1],
				["schwer, 60 km/h (Glas nur manchmal)", 60.0, false, 0], ["schwer, 100 km/h", 100.0, false, -1],
				["mittel, 30 km/h", 30.0, false, 1], ["schwer, 70 km/h (Glas nur manchmal)", 70.0, false, 1],
				["Lkw, 90 km/h", 90.0, true, -1], ["schwer, 130 km/h", 130.0, false, 0]]
			var im: Object = modern.get("impact")
			for h: Array in hits:
				_mark(str(h[0]))
				_am.call("play", "crash")
				_am.call("event", "collision", {"speed_kmh": _v, "rel_kmh": float(h[1]), "heavy": bool(h[2]), "side": int(h[3])})
				var layers: Array = im.get("last_layers")
				_marks[_marks.size() - 1]["layers"] = layers.duplicate(true)
				await _drive(2.6, 110.0, 1.0, 0.3)
		"schnee":
			_weather = "snow"
			for kmh: float in [50.0, 90.0, 130.0]:
				_v = kmh
				_teleport(20.0 + kmh * 0.05)
				_mark("Schnee %d km/h" % int(kmh))
				await _drive(6.0, kmh, 1.0, 0.35)
	_mark("ende")
	var total := _now()
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0)) if not CliArgs.has("master") else CliArgs.get_float("master", 1.0)
	var data := wav.data
	for i in range(0, data.size(), 2):
		data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
	wav.data = data
	var err := wav.save_to_wav(out)
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"scenario": scenario, "seconds": total, "marks": _marks, "joints": joints}, "\t") + "\n")
	f.close()
	print("scene_ab: %s %s (%.1f s) -> %s" % [scenario, out, total, error_string(err)])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0 if err == OK else 1)
