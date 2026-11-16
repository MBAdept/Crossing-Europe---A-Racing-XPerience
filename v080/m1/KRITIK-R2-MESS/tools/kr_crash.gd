extends SceneTree
## KRITIK-R: collisions in the running Modern profile (Limousine at 110 km/h on asphalt, Kiel – Hamburg km 15, engine
## + road + wind live), N times, with the impact RNG seeded by --seed (another sequence than the game's own seed).
## Records Master after everything, before Master's volume (= Gesamtlautstärke 1.0) as <out>.wav and MMaster right after
## the glue compressor / at its end as <out>_pre.f32 / <out>_post.f32 (raw float32 stereo). Marks per crash (frame
## index of the captures at the trigger, last_layers) in <out>.json. Optional: the AU-C1 levels (--hh=-9 --truck=-10).
## Then (--squeal) 16 understeer pulses (squeal start pitch) and (--pass) 40 s of pass-bys at 120 km/h (variants).
##   godot --headless --path <tree> --audio-driver Dummy -s <this> -- --graphics=arcade --out=/abs/x.wav [--n=24]
##       [--rel=130] [--heavy] [--seed=777] [--hh=-9] [--truck=-10] [--squeal] [--pass] [--gap=2.5]

var _am: Node
var _rec: AudioEffectRecord
var _cap_pre: AudioEffectCapture
var _cap_post: AudioEffectCapture
var _pre := PackedVector2Array()
var _post := PackedVector2Array()
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _v := 110.0
var _us := 0.0


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


func _frame(dt: float) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, 0.4, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_environment", {"tunnel": false})
	_am.call("set_vehicle_state", {"z": _z, "x": 1.875, "speed": _v, "throttle": 0.4, "brake": 0.0, "steer": 0.0,
		"understeer": _us, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
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
	var n := int(CliArgs.get_float("n", 24.0))
	var rel := CliArgs.get_float("rel", 130.0)
	var gap := CliArgs.get_float("gap", 2.5)
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
	var feed: Object = modern.get("feed")
	feed.set("concrete_share", {"_": 0.0})
	for p: Dictionary in feed.get_property_list():
		if str(p["name"]) == "concrete_threshold":
			feed.set("concrete_threshold", {})
	(feed.get("_concrete") as Dictionary).clear()
	var im: Object = modern.get("impact")
	var road: Object = modern.get("road")
	(im.get("_rng") as RandomNumberGenerator).seed = int(CliArgs.get_float("seed", 777.0))
	var tc: Dictionary = im.get("_tier_cfg")
	if CliArgs.has("hh"):
		(tc["heavy"]["layers"] as Dictionary)["hit_heavy"] = CliArgs.get_float("hh", -9.0)
	if CliArgs.has("truck"):
		(im.get("_truck_db") as Dictionary)["heavy"] = CliArgs.get_float("truck", -10.0)
	print("kr_crash: heavy layers %s, truck %s" % [JSON.stringify(tc["heavy"]["layers"]), JSON.stringify(im.get("_truck_db"))])
	_z = _track.km_to_z(15.0)
	_track.update_window(_z - 9.0, 600.0)
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
	await _drive(2.0)
	_pull()
	_pre = PackedVector2Array()
	_post = PackedVector2Array()
	_rec.set_recording_active(true)
	var marks: Array = []
	await _drive(1.0)
	for k in n:
		var side: int = [1, -1, 0][k % 3]
		_pull()
		var f0 := _pre.size()
		_am.call("play", "crash")
		_am.call("event", "collision", {"speed_kmh": _v, "rel_kmh": rel, "heavy": heavy, "side": side})
		marks.append({"frame": f0, "side": side, "layers": (im.get("last_layers") as Array).duplicate(true)})
		await _drive(gap)
	var squeals: Array = []
	if CliArgs.has("squeal"):
		for k in 16:
			_pull()
			var f0 := _pre.size()
			_us = 0.6
			await _drive(0.7)
			var fac: Variant = road.get("squeal_factor")
			squeals.append({"frame": f0, "factor": fac if fac != null else 1.0})
			_us = 0.0
			await _drive(1.0)
	var passes: Array = []
	if CliArgs.has("pass"):
		_v = 120.0
		var last_seen := {}
		var t0 := Time.get_ticks_usec()
		while (Time.get_ticks_usec() - t0) / 1.0e6 < 40.0:
			await _drive(0.016)
			var lp: Dictionary = road.get("last_pass")
			if not lp.is_empty() and lp.hash() != last_seen.hash():
				last_seen = lp.duplicate()
				passes.append(lp.duplicate())
	_rec.set_recording_active(false)
	_pull()
	var wav := _rec.get_recording()
	var err := wav.save_to_wav(out)
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
	fj.store_string(JSON.stringify({"rel_kmh": rel, "heavy": heavy, "marks": marks, "squeals": squeals, "passes": passes,
		"pre_frames": _pre.size(), "post_frames": _post.size(), "heavy_layers": tc["heavy"]["layers"],
		"truck_db": im.get("_truck_db")}, "\t") + "\n")
	fj.close()
	print("kr_crash: %d Unfälle, %d Quietschen, %d Vorbeifahrten -> %s (%s), pre %d post %d" % [n, squeals.size(), passes.size(),
		out, error_string(err), _pre.size(), _post.size()])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
