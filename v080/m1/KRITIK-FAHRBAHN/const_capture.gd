extends SceneTree
## KRITIK-FAHRBAHN: constant-speed recordings of the Modern game mix (Master, after the limiter, before the master
## volume) on the real track Kiel – Hamburg, one WAV per segment, groups muted per segment.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --out-dir=/abs/dir [--vehicle=limousine] [--only=a,b]
## Writes <out-dir>/<segment>.wav and <out-dir>/segments.json (parameters, master volume dB, feed state).

var _am: Node
var _rec: AudioEffectRecord
var _track: Track
var _plan: StagePlan
var _z := 0.0
var _x := 1.875
var _v := 0.0
var _vehicle := "limousine"
var _vmax := 245.0

const ROAD_ONLY := ["MEngine", "MEngineFx", "MWind"]
const WIND_ONLY := ["MEngine", "MEngineFx", "MRoad"]
const ENGINE_ONLY := ["MRoad", "MWind"]
const NO_ENGINE := ["MEngine", "MEngineFx"]
const GROUPS := ["MEngine", "MEngineFx", "MRoad", "MWind", "MImpact", "MWorld", "MAmb", "MMusic"]

## name, km, km/h, throttle, x, muted buses, seconds
var SEGMENTS := [
	["asph130_full", 15.0, 130.0, 0.35, 1.875, [], 20.0],
	["asph130_road", 15.0, 130.0, 0.35, 1.875, ROAD_ONLY, 20.0],
	["asph130_wind", 15.0, 130.0, 0.35, 1.875, WIND_ONLY, 20.0],
	["asph130_engine", 15.0, 130.0, 0.35, 1.875, ENGINE_ONLY, 20.0],
	["asph200_full", 20.0, 200.0, 0.6, 1.875, [], 20.0],
	["asph200_engine", 20.0, 200.0, 0.6, 1.875, ENGINE_ONLY, 20.0],
	["asph200_roadwind", 20.0, 200.0, 0.6, 1.875, NO_ENGINE, 20.0],
	["vmax_full", 15.0, -1.0, 1.0, 1.875, [], 15.0],
	["vmax_engine", 15.0, -1.0, 1.0, 1.875, ENGINE_ONLY, 15.0],
	["conc130_full", 42.0, 130.0, 0.35, 1.875, [], 20.0],
	["conc130_road", 42.0, 130.0, 0.35, 1.875, ROAD_ONLY, 20.0],
	["rumble130_full", 15.0, 130.0, 0.35, 5.15, [], 10.0],
	["rumble130_road", 15.0, 130.0, 0.35, 5.15, ROAD_ONLY, 10.0],
	["cobbles50_full", 87.3, 50.0, 0.25, 1.875, [], 15.0],
	["cobbles50_road", 87.3, 50.0, 0.25, 1.875, ROAD_ONLY, 15.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


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
	_am.call("set_vehicle_state", {"z": _z, "x": _x, "speed": _v, "throttle": throttle, "brake": 0.0, "steer": 0.0,
		"understeer": 0.0, "lat_speed": 0.0, "off_road": 0, "rail_contact": false, "road_left": e.x, "road_right": e.y,
		"shoulder_m": _track.shoulder_w, "in_tunnel": false, "weather": "normal", "hour": 12.0, "crash": false,
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


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var out_dir := CliArgs.get_string("out-dir", "")
	if out_dir == "" or not out_dir.is_absolute_path():
		push_error("--out-dir=<absolute path> fehlt")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	_plan = root.get_node("GameData").call("get_stage_plan", "kiel_hamburg", "kiel")
	_track = _new_track()
	_am.call("set_vehicle", _vehicle)
	_am.call("set_track", _track, _plan)
	var modern: Object = _am.get("_modern")
	var feed: AudioFeed = modern.get("feed")
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	var meta := {"vehicle": _vehicle, "vmax": _vmax, "master_db": AudioServer.get_bus_volume_db(0), "segments": []}
	for seg: Array in SEGMENTS:
		var name: String = seg[0]
		if not only.is_empty() and not only.has(name):
			continue
		var v := float(seg[2]) if float(seg[2]) > 0.0 else _vmax
		_mute(seg[5])
		_v = v
		_x = float(seg[4])
		_teleport(float(seg[1]))
		await _drive(2.5, float(seg[3]))
		var fs: Dictionary = feed.state()
		_rec.set_recording_active(true)
		var t0 := Time.get_ticks_usec()
		await _drive(float(seg[6]), float(seg[3]))
		_rec.set_recording_active(false)
		var wall := (Time.get_ticks_usec() - t0) / 1.0e6
		var wav := _rec.get_recording()
		var path := out_dir.path_join(name + ".wav")
		var err := wav.save_to_wav(path)
		var road: Object = modern.get("road")
		meta["segments"].append({"name": name, "km": seg[1], "kmh": v, "throttle": seg[3], "x": seg[4], "muted": seg[5],
			"seconds": seg[6], "wall_s": wall, "feed": fs, "road_levels": road.call("levels"), "err": error_string(err)})
		print("const_capture: %s %.1f s -> %s (%s) feed %s/%s %s" % [name, wall, path, error_string(err), fs.get("surface_l"), fs.get("surface_r"), fs.get("paving")])
	_mute([])
	var f := FileAccess.open(out_dir.path_join("segments.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t") + "\n")
	f.close()
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
