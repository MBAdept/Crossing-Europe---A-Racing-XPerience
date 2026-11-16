extends SceneTree
## AU-R: constant-speed recordings of the Modern game mix on the real track (Kiel – Hamburg unless --stage), one WAV
## per segment, from a JSON plan. Based on KRITIK-FAHRBAHN const_capture.gd. Works on the old head (4209268) and on
## the AU-R head alike (feed overrides are plain properties of AudioFeed in both).
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --plan=/abs/plan.json --out-dir=/abs/dir \
##       [--vehicle=limousine] [--only=a,b]
## Plan: {"segments": [{"name", "km", "kmh" (-1 = vmax), "throttle", "x", "mute": [...], "seconds",
##        "feed": {"concrete_share": {...}, "cobble_share": 1.0}, "weather": "normal", "state": {...}}]}
## Writes <name>.wav (Master after the shared limiter, BEFORE the master volume = Gesamtlautstärke 1.0),
## <name>_pre.f32 (MMaster after the glue compressor, before an AU-R limiter: raw float32 stereo) and segments.json.

var _am: Node
var _rec: AudioEffectRecord
var _cap: AudioEffectCapture = null
var _pre := PackedFloat32Array()
var _capturing := false
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _vehicle := "limousine"
var _vmax := 245.0
var _weather := "normal"
var _extra: Dictionary = {}

const GROUPS := ["MEngine", "MEngineFx", "MRoad", "MWind", "MImpact", "MWorld", "MAmb", "MMusic"]


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_pull()
	return false


func _pull() -> void:
	if _cap == null:
		return
	var n := _cap.get_frames_available()
	if n <= 0:
		return
	var buf := _cap.get_buffer(n)
	if _capturing:
		var off := _pre.size()
		_pre.resize(off + buf.size() * 2)
		for i in buf.size():
			_pre[off + 2 * i] = buf[i].x
			_pre[off + 2 * i + 1] = buf[i].y


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
	_am.call("set_environment", {"tunnel": false})
	var st := {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": false, "weather": _weather, "hour": 12.0, "crash": false,
		"finished": false}
	st.merge(_extra, true)
	_am.call("set_vehicle_state", st)


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


func _apply_feed(feed: AudioFeed, over: Dictionary) -> void:
	feed.concrete_share = (over.get("concrete_share", _base_concrete) as Dictionary).duplicate()
	feed.cobble_share = float(over.get("cobble_share", _base_cobble))
	feed._concrete.clear()
	feed._cobbles.clear()


var _base_concrete: Dictionary = {}
var _base_cobble := 0.6


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
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	_vehicle = CliArgs.get_string("vehicle", "limousine")
	var only := CliArgs.get_string("only", "").split(",", false)
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
	_plan = root.get_node("GameData").call("get_stage_plan", CliArgs.get_string("stage", "kiel_hamburg"), CliArgs.get_string("from", "kiel"))
	_track = _new_track()
	_am.call("set_vehicle", _vehicle)
	_am.call("set_track", _track, _plan)
	var modern: Object = _am.get("_modern")
	var feed: AudioFeed = modern.get("feed")
	_base_concrete = feed.concrete_share.duplicate()
	_base_cobble = feed.cobble_share
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	var mm := AudioServer.get_bus_index("MMaster")
	var fx_names: Array = []
	if mm >= 0:
		for j in AudioServer.get_bus_effect_count(mm):
			fx_names.append(AudioServer.get_bus_effect(mm, j).get_class())
		_cap = AudioEffectCapture.new()
		_cap.buffer_length = 2.0
		AudioServer.add_bus_effect(mm, _cap, mini(1, AudioServer.get_bus_effect_count(mm)))
	var meta := {"vehicle": _vehicle, "vmax": _vmax, "master_db": AudioServer.get_bus_volume_db(0), "mmaster_fx": fx_names,
		"segments": []}
	for seg: Dictionary in plan["segments"]:
		var name := str(seg["name"])
		if not only.is_empty() and not only.has(name):
			continue
		var v := float(seg.get("kmh", 130.0))
		if v <= 0.0:
			v = _vmax
		_mute(seg.get("mute", []))
		_weather = str(seg.get("weather", "normal"))
		_extra = seg.get("state", {})
		_v = v
		_x = float(seg.get("x", 1.875))
		_teleport(float(seg["km"]))
		_apply_feed(feed, seg.get("feed", {}))
		# analysis only: members of the road slot set for this segment (e.g. _pass_min, _slab_db), reset afterwards
		var road_set: Dictionary = seg.get("road_set", {})
		var road_obj: Object = modern.get("road")
		var road_old := {}
		for k: String in road_set:
			road_old[k] = road_obj.get(k)
			road_obj.set(k, road_set[k])
		var thr := float(seg.get("throttle", 0.35))
		await _drive(float(seg.get("pre_s", 2.5)), thr)
		var fs: Dictionary = feed.state()
		_pull()
		_pre = PackedFloat32Array()
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
		if _cap != null:
			var f := FileAccess.open(out_dir.path_join(name + "_pre.f32"), FileAccess.WRITE)
			f.store_buffer(_pre.to_byte_array())
			f.close()
		var road: Object = modern.get("road")
		meta["segments"].append({"name": name, "km": seg["km"], "kmh": v, "throttle": thr, "x": _x, "muted": seg.get("mute", []),
			"seconds": seg.get("seconds", 20.0), "wall_s": wall, "feed": fs, "road_levels": road.call("levels"),
			"err": error_string(err), "weather": _weather, "road_set": road_set})
		for k: String in road_old:
			road_obj.set(k, road_old[k])
		print("cap_const: %s %.1f s -> %s (%s) feed %s/%s %s %s" % [name, wall, path, error_string(err), fs.get("surface_l"),
			fs.get("surface_r"), fs.get("paving"), fs.get("zone")])
	_mute([])
	var fo := FileAccess.open(out_dir.path_join("segments.json"), FileAccess.WRITE)
	fo.store_string(JSON.stringify(meta, "\t") + "\n")
	fo.close()
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
