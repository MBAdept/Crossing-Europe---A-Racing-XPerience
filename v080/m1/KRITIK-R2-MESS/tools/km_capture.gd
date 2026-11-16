extends SceneTree
## KRITIK-R2-MESS (copy of AU-R2's kr_capture.gd; added: --seed=N reseeds the road slot's RNGs per segment, the
## road debug state is stored at the start of each capture too). KRITIK-R (copy for AU-R2, + per-segment "slab_db" override): constant-speed recordings of the Modern game mix on the real track Kiel – Hamburg (based on
## KRITIK-FAHRBAHN const_capture.gd, same drive model: state sent per frame, wall-clock dt). Works on the AU-C1 head
## (4209268) and on the AU-R head alike: every override is applied only when the member exists.
##   godot --headless --path <tree> --audio-driver Dummy -s <this> -- --graphics=arcade --plan=/abs/plan.json \
##       --out-dir=/abs/dir [--vehicle=limousine] [--only=a,b]
## Plan: {"segments": [{"name", "km", "kmh" (-1 = vmax), "throttle", "x", "mute": [buses], "seconds",
##        "paving": "asphalt"|"concrete"|"cobbles"|"" (forced the same way on both heads), "weather",
##        "nd": true (no side drift, no gusts, no pass-bys), "noslab": true, "slabonly": true (tyres on concrete off),
##        "off_road": 0, "tunnel": false}]}
## Writes per segment: <name>.wav (Master after everything, before Master's volume = Gesamtlautstärke 1.0),
## <name>_pre.f32 / <name>_post.f32 (MMaster right after the glue compressor / at the end of MMaster, raw float32
## stereo interleaved) and segments.json.

var _am: Node
var _rec: AudioEffectRecord
var _cap_pre: AudioEffectCapture
var _cap_post: AudioEffectCapture
var _pre := PackedVector2Array()
var _post := PackedVector2Array()
var _capturing := false
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _off := 0
var _tunnel := false
var _weather := "normal"
var _vehicle := "limousine"
var _vmax := 245.0

const GROUPS := ["MEngine", "MEngineFx", "MRoad", "MWind", "MImpact", "MWorld", "MAmb", "MMusic"]


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_pull()
	return false


func _pull() -> void:
	# (packed arrays are values: append to the members themselves)
	if _cap_pre != null:
		var n := _cap_pre.get_frames_available()
		if n > 0:
			var buf := _cap_pre.get_buffer(n)
			if _capturing:
				_pre.append_array(buf)
	if _cap_post != null:
		var m := _cap_post.get_frames_available()
		if m > 0:
			var buf2 := _cap_post.get_buffer(m)
			if _capturing:
				_post.append_array(buf2)


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
	_am.call("set_environment", {"tunnel": _tunnel})
	_am.call("set_vehicle_state", {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": _off, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": _tunnel, "weather": _weather, "hour": 12.0, "crash": false,
		"finished": false})


func _drive(seconds: float, throttle: float) -> void:
	var t0 := Time.get_ticks_usec()
	var last := t0
	while (Time.get_ticks_usec() - t0) / 1.0e6 < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1.0e6
		last = now
		_frame(dt, throttle)


func _mute(buses: Array) -> void:
	for b: String in GROUPS:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_mute(i, buses.has(b))


func _has(o: Object, prop: String) -> bool:
	for p: Dictionary in o.get_property_list():
		if str(p["name"]) == prop:
			return true
	return false


func _set_if(o: Object, prop: String, v: Variant) -> void:
	if _has(o, prop):
		o.set(prop, v)


## Paving forced the same way on both heads (a share of 0 or 1 decides every hash the same way).
func _force_paving(feed: Object, paving: String) -> void:
	match paving:
		"asphalt":
			feed.set("concrete_share", {"_": 0.0})
			_set_if(feed, "concrete_threshold", {})
		"concrete":
			feed.set("concrete_share", {"_": 1.0})
			_set_if(feed, "concrete_threshold", {})
		"cobbles":
			feed.set("cobble_share", 1.0)
		_:
			return
	(feed.get("_concrete") as Dictionary).clear()
	(feed.get("_cobbles") as Dictionary).clear()


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out_dir := CliArgs.get_string("out-dir", "")
	var plan_path := CliArgs.get_string("plan", "")
	if out_dir == "" or not out_dir.is_absolute_path() or plan_path == "":
		push_error("--out-dir=<absolute path> und --plan= fehlen")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var plan_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	_vehicle = CliArgs.get_string("vehicle", "limousine")
	var only := CliArgs.get_string("only", "").split(",", false)
	var rng_seed := int(CliArgs.get_float("seed", -1.0))
	var cfg: Dictionary = _am.get("_audio_cfg")
	_vmax = float(ConfigLoader.lookup(ConfigLoader.load_merged(), "vehicles.types.%s.vmax_kmh" % _vehicle, 245.0))
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", "modern")
	await process_frame
	_plan = root.get_node("GameData").call("get_stage_plan", str(plan_data.get("stage", "kiel_hamburg")),
		str(plan_data.get("from", "kiel")))
	_track = _new_track()
	_am.call("set_vehicle", _vehicle)
	_am.call("set_track", _track, _plan)
	var modern: Object = _am.get("_modern")
	var feed: Object = modern.get("feed")
	var road: Object = modern.get("road")
	# captures on MMaster: right after the glue compressor (in front of an AU-R limiter) and at its end
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
	var fx_names: Array = []
	for i in AudioServer.get_bus_effect_count(mm):
		fx_names.append(AudioServer.get_bus_effect(mm, i).get_class())
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	# defaults of the road slot, restored per segment
	var base := {"_gust_db": road.get("_gust_db"), "_pass_min": road.get("_pass_min"), "_slab_db": road.get("_slab_db"),
		"_surface_db": (road.get("_surface_db") as Dictionary).duplicate(), "_joint_min": road.get("_joint_min")}
	if _has(road, "_drift_db"):
		base["_drift_db"] = road.get("_drift_db")
	var feed_base := {"concrete_share": (feed.get("concrete_share") as Dictionary).duplicate(), "cobble_share": feed.get("cobble_share")}
	if _has(feed, "concrete_threshold"):
		feed_base["concrete_threshold"] = (feed.get("concrete_threshold") as Dictionary).duplicate(true)
	var meta := {"vehicle": _vehicle, "vmax": _vmax, "master_db": AudioServer.get_bus_volume_db(0), "mmaster_fx": fx_names,
		"segments": []}
	var seg_i := -1
	for seg: Dictionary in plan_data["segments"]:
		seg_i += 1
		var name: String = seg["name"]
		if not only.is_empty() and not only.has(name):
			continue
		# restore, then apply this segment's overrides
		for k: String in base:
			road.set(k, base[k] if not (base[k] is Dictionary) else (base[k] as Dictionary).duplicate())
		for k: String in feed_base:
			feed.set(k, feed_base[k] if not (feed_base[k] is Dictionary) else (feed_base[k] as Dictionary).duplicate(true))
		if bool(seg.get("nd", false)):
			road.set("_gust_db", 0.0)
			road.set("_pass_min", 1.0e9)
			_set_if(road, "_drift_db", 0.0)
		if bool(seg.get("noslab", false)):
			road.set("_slab_db", -200.0)
		if bool(seg.get("nojoint", false)):
			road.set("_joint_min", 1.0e9)
		if bool(seg.get("slabonly", false)):
			(road.get("_surface_db") as Dictionary)["concrete"] = -200.0
		if seg.has("slab_db"):
			road.set("_slab_db", float(seg["slab_db"]))
		var v := float(seg["kmh"]) if float(seg["kmh"]) > 0.0 else _vmax
		_mute(seg.get("mute", []))
		_v = v
		_x = float(seg.get("x", 1.875))
		_off = int(seg.get("off_road", 0))
		_tunnel = bool(seg.get("tunnel", false))
		_weather = str(seg.get("weather", "normal"))
		_teleport(float(seg["km"]))
		_force_paving(feed, str(seg.get("paving", "")))
		var thr := float(seg.get("throttle", 0.35))
		if rng_seed >= 0:
			for pr: Array in [["_rng", 0], ["_rng_start", 1]]:
				if _has(road, str(pr[0])):
					(road.get(str(pr[0])) as RandomNumberGenerator).seed = rng_seed + 101 * seg_i + int(pr[1])
		await _drive(2.5, thr)
		var dbg_start: Dictionary = road.call("debug_state")
		var fs: Dictionary = feed.state()
		_pre = PackedVector2Array()
		_post = PackedVector2Array()
		_pull()
		_capturing = true
		_rec.set_recording_active(true)
		var t0 := Time.get_ticks_usec()
		await _drive(float(seg.get("seconds", 20.0)), thr)
		_rec.set_recording_active(false)
		_pull()
		_capturing = false
		var wall := (Time.get_ticks_usec() - t0) / 1.0e6
		var wav := _rec.get_recording()
		var path := out_dir.path_join(name + ".wav")
		var err := wav.save_to_wav(path)
		for pair: Array in [["_pre", _pre], ["_post", _post]]:
			var f := FileAccess.open(out_dir.path_join(name + str(pair[0]) + ".f32"), FileAccess.WRITE)
			var arr: PackedVector2Array = pair[1]
			var flat := PackedFloat32Array()
			flat.resize(arr.size() * 2)
			for i in arr.size():
				flat[2 * i] = arr[i].x
				flat[2 * i + 1] = arr[i].y
			f.store_buffer(flat.to_byte_array())
			f.close()
		var fs_end: Dictionary = feed.state()
		meta["segments"].append({"name": name, "seg": seg, "kmh": v, "wall_s": wall, "feed": fs, "feed_end": fs_end,
			"road_levels": road.call("levels"), "road_debug": road.call("debug_state"), "road_debug_start": dbg_start,
			"seed": rng_seed, "err": error_string(err),
			"pre_frames": _pre.size(), "post_frames": _post.size()})
		print("kr_capture: %s %.1f s -> %s (%s) feed %s/%s %s zone %s | pre %d post %d" % [name, wall, path, error_string(err),
			fs.get("surface_l"), fs.get("surface_r"), fs.get("paving"), fs.get("zone"), _pre.size(), _post.size()])
	_mute([])
	var f2 := FileAccess.open(out_dir.path_join("segments.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(meta, "\t") + "\n")
	f2.close()
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
