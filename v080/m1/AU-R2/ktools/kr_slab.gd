extends SceneTree
## KRITIK-R (R3): the two slab loops of a concrete motorway across 110–150 km/h. Concrete forced at Kiel – Hamburg
## km 42, tyres / wind / pass-bys / joints silent, engine buses muted. The slow design stays on MRoad, the fast one is
## routed to MWind, so the two are recorded apart (AudioEffectCapture at the end of each bus, the same mix blocks).
## Speed profile with ramps and jumps through the crossfade; per frame: speed, playing, playback share and gain of both.
##   godot --headless --path <tree> --audio-driver Dummy -s <this> -- --graphics=arcade --out=/abs/slab (writes
##   <out>_slow.f32, <out>_fast.f32 (raw float32 stereo), <out>.json)

var _am: Node
var _cap_s: AudioEffectCapture
var _cap_f: AudioEffectCapture
var _s := PackedVector2Array()
var _f := PackedVector2Array()
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _v := 100.0

## [seconds, target km/h at the end (ramp from the speed before), or jump when seconds = 0]
const PROFILE := [
	[3.0, 100.0], [8.0, 160.0], [4.0, 160.0], [6.0, 105.0], [3.0, 105.0], [0.0, 130.0], [6.0, 130.0], [3.0, 145.0],
	[4.0, 145.0], [6.0, 90.0], [3.0, 90.0], [4.0, 125.0], [8.0, 125.0], [4.0, 150.0], [6.0, 112.0], [5.0, 112.0],
	[0.0, 140.0], [5.0, 140.0], [5.0, 118.0], [6.0, 118.0]]


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_pull()
	return false


func _pull() -> void:
	if _cap_s != null:
		var n := _cap_s.get_frames_available()
		if n > 0:
			_s.append_array(_cap_s.get_buffer(n))
	if _cap_f != null:
		var m := _cap_f.get_frames_available()
		if m > 0:
			_f.append_array(_cap_f.get_buffer(m))


func _frame(dt: float) -> void:
	_z += _v / 3.6 * dt
	_track.update_window(_z - 9.0, 600.0)
	var e := _track.road_edges_at(_z)
	_am.call("set_engine", _v, 0.4, 245.0, true)
	_am.call("set_wind", _v)
	_am.call("set_environment", {"tunnel": false})
	_am.call("set_vehicle_state", {"z": _z, "x": 1.875, "speed": _v, "throttle": 0.4, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": false, "weather": "normal", "hour": 12.0, "crash": false, "finished": false})


func _share(l: Object) -> float:
	var pl: Variant = (l.get("players") as Array)[0]
	if pl == null or not bool((pl as Node).get("playing")):
		return -1.0
	var length := float(l.get("length_s"))
	return fposmod(float((pl as Node).call("get_playback_position")) / maxf(length, 0.001), 1.0)


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out := CliArgs.get_string("out", "")
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
	feed.set("concrete_share", {"_": 1.0})
	for p: Dictionary in feed.get_property_list():
		if str(p["name"]) == "concrete_threshold":
			feed.set("concrete_threshold", {})
	(feed.get("_concrete") as Dictionary).clear()
	var road: Object = modern.get("road")
	(road.get("_surface_db") as Dictionary)["concrete"] = -200.0
	road.set("_wind_fade", Vector2(9000.0, 9001.0))
	road.set("_pass_min", 1.0e9)
	road.set("_joint_min", 1.0e9)
	for b: String in ["MEngine", "MEngineFx", "MImpact", "MWorld", "MAmb", "MMusic"]:
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0:
			AudioServer.set_bus_mute(bi, true)
	var slow: Object = road.get("slab_slow")
	var fast: Object = road.get("slab_fast")
	var pf: Node = (fast.get("players") as Array)[0]
	pf.set("bus", "MWind")
	_cap_s = AudioEffectCapture.new()
	_cap_s.buffer_length = 10.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("MRoad"), _cap_s)
	_cap_f = AudioEffectCapture.new()
	_cap_f.buffer_length = 10.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("MWind"), _cap_f)
	_z = _track.km_to_z(42.0)
	_track.update_window(_z - 9.0, 600.0)
	var t0 := Time.get_ticks_usec()
	var last := t0
	var rows: Array = []
	var seg := 0
	var seg_t0 := 0.0
	var v_from := _v
	_pull()
	_s = PackedVector2Array()
	_f = PackedVector2Array()
	while seg < PROFILE.size():
		await process_frame
		var now := Time.get_ticks_usec()
		var t := (now - t0) / 1.0e6
		var dt := (now - last) / 1.0e6
		last = now
		var dur := float(PROFILE[seg][0])
		var target := float(PROFILE[seg][1])
		var u := 1.0 if dur <= 0.0 else clampf((t - seg_t0) / dur, 0.0, 1.0)
		_v = lerpf(v_from, target, u)
		if u >= 1.0:
			seg += 1
			seg_t0 = t
			v_from = target
		_frame(dt)
		_pull()
		rows.append([snappedf(t, 0.001), snappedf(_v, 0.01), _s.size(), _f.size(), snappedf(_share(slow), 0.00001),
			snappedf(_share(fast), 0.00001), snappedf(float(slow.get("level")), 0.0001), snappedf(float(fast.get("level")), 0.0001),
			snappedf(float(slow.get("pitch")), 0.0001), snappedf(float(fast.get("pitch")), 0.0001)])
	_pull()
	for pair: Array in [["_slow", _s], ["_fast", _f]]:
		var arr: PackedVector2Array = pair[1]
		var flat := PackedFloat32Array()
		flat.resize(arr.size() * 2)
		for i in arr.size():
			flat[2 * i] = arr[i].x
			flat[2 * i + 1] = arr[i].y
		var f := FileAccess.open(out + str(pair[0]) + ".f32", FileAccess.WRITE)
		f.store_buffer(flat.to_byte_array())
		f.close()
	var realigned: Variant = road.get("slab_realigned")
	var fj := FileAccess.open(out + ".json", FileAccess.WRITE)
	fj.store_string(JSON.stringify({"rows": rows, "len_slow": slow.get("length_s"), "len_fast": fast.get("length_s"),
		"ref_slow": slow.get("ref_kmh"), "ref_fast": fast.get("ref_kmh"), "realigned": realigned if realigned != null else -1,
		"xfade": road.get("_slab_xfade")}) + "\n")
	fj.close()
	print("kr_slab: %.1f s, slow %d / fast %d frames, realigned %s -> %s" % [(Time.get_ticks_usec() - t0) / 1.0e6, _s.size(),
		_f.size(), str(realigned), out])
	pf.set("bus", "MRoad")
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
