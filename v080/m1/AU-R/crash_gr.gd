extends SceneTree
## AU-R (R5): heavy crashes at 130 km/h closing speed in the running Modern profile (Limousine at 110 km/h on asphalt,
## engine + road + wind), N times with fresh random variants / levels / delays: Master after the limiters at
## Gesamtlautstärke 1.0 (<out>.wav) and MMaster behind the glue compressor, in front of the Modern limiter
## (<out>_pre.f32, raw float stereo). Marks per crash in <out>.json.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --out=/abs/x.wav [--n=16] [--rel=130] [--heavy]

var _am: Node
var _rec: AudioEffectRecord
var _cap: AudioEffectCapture
var _pre := PackedFloat32Array()
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _v := 110.0
var _t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _cap != null:
		var n := _cap.get_frames_available()
		if n > 0:
			var buf := _cap.get_buffer(n)
			var off := _pre.size()
			_pre.resize(off + buf.size() * 2)
			for i in buf.size():
				_pre[off + 2 * i] = buf[i].x
				_pre[off + 2 * i + 1] = buf[i].y
	return false


func _frame(dt: float) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, 0.4, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_vehicle_state", {"z": _z, "x": 1.875, "speed": _v, "throttle": 0.4, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": false, "weather": "normal", "hour": 12.0, "crash": false, "finished": false})


func _drive(seconds: float) -> void:
	var t0 := Time.get_ticks_usec()
	var last := t0
	while (Time.get_ticks_usec() - t0) / 1.0e6 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		_frame((now - last) / 1.0e6)
		last = now


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "")
	var n := int(CliArgs.get_float("n", 16.0))
	var rel := CliArgs.get_float("rel", 130.0)
	var heavy := CliArgs.has("heavy")
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
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	_track = Track.new()
	_track.setup(_plan, ConfigLoader.load_merged(), (sc as Dictionary).get("scenery", {}))
	_am.call("set_vehicle", "limousine")
	_am.call("set_track", _track, _plan)
	var modern: Object = _am.get("_modern")
	(modern.get("feed") as Object).set("concrete_share", {"_": 0.0})
	_z = _track.km_to_z(15.0)
	_track.update_window(_z - 9.0, 600.0)
	var mm := AudioServer.get_bus_index("MMaster")
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 2.0
	AudioServer.add_bus_effect(mm, _cap, mini(1, AudioServer.get_bus_effect_count(mm)))
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	await _drive(2.0)
	_pre = PackedFloat32Array()
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	var marks: Array = []
	var im: Object = modern.get("impact")
	if CliArgs.has("hh"):     # analysis only: the heavy tier's hit_heavy peak (dB at 70 km/h) for this run
		var tc: Dictionary = im.get("_tier_cfg")
		(tc["heavy"]["layers"] as Dictionary)["hit_heavy"] = CliArgs.get_float("hh", -10.5)
		print("crash_gr: hit_heavy (schwer) = %.1f dB" % float(tc["heavy"]["layers"]["hit_heavy"]))
	await _drive(1.0)
	for k in n:
		var side: int = [1, -1, 0][k % 3]
		var t := (Time.get_ticks_usec() - _t0) / 1.0e6
		_am.call("play", "crash")
		_am.call("event", "collision", {"speed_kmh": _v, "rel_kmh": rel, "heavy": heavy, "side": side})
		marks.append({"t": snappedf(t, 0.001), "side": side, "layers": (im.get("last_layers") as Array).duplicate(true)})
		await _drive(2.5)
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var err := wav.save_to_wav(out)       # before Master's volume: Gesamtlautstärke 1.0
	var f := FileAccess.open(out.get_basename() + "_pre.f32", FileAccess.WRITE)
	f.store_buffer(_pre.to_byte_array())
	f.close()
	var fj := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	fj.store_string(JSON.stringify({"rel_kmh": rel, "heavy": heavy, "marks": marks, "mmaster_fx_count": AudioServer.get_bus_effect_count(mm)}, "\t") + "\n")
	fj.close()
	print("crash_gr: %d Unfälle, %s -> %s" % [n, out, error_string(err)])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
