extends SceneTree
## QA-RINT-SYSTEM: run_stage.gd plus a per-second hash of the simulation state (player + every traffic car,
## exact bits, the same fields as check_session._sim_hash) and a digest over all seconds.
## Works in v0.7.0 (no graphics mode) and in v0.8.0 (pass -- --graphics=arcade|modern).
##   godot --headless --path <tree> -s <abs>/stage_hash.gd -- --stage=… [--from=…] [--hour=…] [--weather=…]
##       [--timescale=40] [--seed=7] [--autopilot-refuel=always] [--graphics=…]
## Output: "ERGEBNIS {...}", "HASHES n=<count> digest=<hex>", "HASHLIST <first 400 per-second hashes>", "PERF", "RUN".

## NACH-RINT additions: --shot-km=<km,km,…> --out=<abs prefix>: a screenshot of the drawn frame when the player
## passes each km (threaded streaming, no --gfx-sync); a Logger counts engine errors and warnings ("ERRORS" line).
class Catch extends Logger:
	var lines: Array = []
	var warn := 0
	var err := 0
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		_m.lock()
		if error_type == 1:
			warn += 1
		else:
			err += 1
		if lines.size() < 40:
			lines.append("%s %s:%d %s %s" % ["WARN" if error_type == 1 else "ERR", file.get_file(), line, code, rationale])
		_m.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error:
			_m.lock()
			err += 1
			if lines.size() < 40:
				lines.append("MSGERR " + message.strip_edges())
			_m.unlock()


var _c := Catch.new()
var _shot_km: Array = []
var _out := ""
var _shot_pending := ""
## QA-MID: from a shot km on the simulation runs in real time (time scale 1, 60 physics ticks per second, at most
## 8 per frame – every tick stays 1/60 s, so the simulation is the same tick sequence as without shots; a time scale of
## 0 is NOT that: the ticks go on with a delta of 0 and the traffic draws diverge) and the frames go on until the
## streamer has every wanted chunk committed (is_idle(), at least HOLD_MIN frames, at most HOLD_MAX); then the shot is
## taken and the time lapse runs again. At timescale 40 under llvmpipe a frame jumps ~1.3 s of simulation (up to ~100 m
## of road) – without the hold a shot can show the world not loaded yet, which never happens at the frame rate of the
## real game.
## QA-MID v2: the shot lands at its km (a frame at timescale 40 moves up to 80 ticks, ~0.6 km at full speed, and the
## v1 hold 8 ticks a frame): before a shot km the steps of the next frame are capped so that the car stops just short
## of it (km per tick measured over the last frame), and the hold runs one tick a frame. Only the number of ticks per
## frame changes, never the tick length – the simulation stays the same tick sequence.
const HOLD_MIN := 4
const HOLD_MAX := 120
var _hold := 0
var _ts := 40.0
var _cap_full := 80
var _ticks := 0
var _pos_prev := 0.0
var _dpt := 0.0

var _scene: Node
var _wall0 := 0
var _max_wall := 3000.0
var _done := false
var _last_report := 0
var _sec := -1
var _hashes: Array = []
var _max_cars := 0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	OS.add_logger(_c)
	_out = str(args.get("out", ""))
	for k in str(args.get("shot-km", "")).split(",", false):
		_shot_km.append(float(k))
	_shot_km.sort()
	var ts := clampf(float(args.get("timescale", 40.0)), 0.1, 200.0)
	_ts = ts
	_max_wall = float(args.get("max-seconds", 3000.0))
	var setup := {
		"mode": "single",
		"race_id": "",
		"stage_id": str(args.get("stage", "dev_testetappe")),
		"from_city": str(args.get("from", "")),
		"vehicle": str(args.get("vehicle", "limousine")),
		"start_world_minutes": float(args.get("hour", 8.0)) * 60.0,
		"weather": str(args.get("weather", "normal")),
		"start_km": float(args.get("start-km", 0.0)),
		"autopilot": true,
		"autopilot_speeding": args.has("autopilot-speeding"),
		"autopilot_refuel": str(args.get("autopilot-refuel", "auto")),
		"no_countdown": true,
		"seed": int(args.get("seed", 0)),
	}
	_cap_full = clampi(int(ceil(ts)) * 2, 8, 128)
	_set_lapse(ts, _cap_full)
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", _on_finished)
	_scene.connect("stage_aborted", _on_aborted)
	root.add_child(_scene)
	_wall0 = Time.get_ticks_msec()
	print("RUN-START ", JSON.stringify(setup), " timescale=", ts)


func _set_lapse(ts: float, cap: int) -> void:
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = cap


func _sim_hash() -> int:
	var v: Object = _scene.get("vehicle")
	var fuel: Object = _scene.get("fuel")
	var a := PackedFloat64Array([float(_scene.get("pos_z")), float(v.get("x")), float(v.get("speed")),
		float(fuel.get("fuel_l")) if fuel != null else -1.0, float(_scene.get("stage_time")),
		float(_scene.get("penalty_time")), float(v.get("state"))])
	var traffic: Object = _scene.get("traffic")
	var cars: Array = traffic.get("cars")
	_max_cars = maxi(_max_cars, cars.size())
	for c in cars:
		a.append_array(PackedFloat64Array([float(c.id), c.z, c.x, c.speed, float(c.lane), 1.0 if c.braking else 0.0]))
	return hash(a.to_byte_array())


## Sampled per physics tick (the session steps the simulation in _physics_process), so the sampled seconds do not
## depend on wall-clock frame timing.
func _physics_process(_delta: float) -> bool:
	if _done or _scene == null:
		return false
	_ticks += 1
	if bool(_scene.get("running")) and not bool(_scene.get("finished")):
		var sec := int(floor(float(_scene.get("stage_time"))))
		if sec != _sec:
			_sec = sec
			_hashes.append(_sim_hash())
	return false


func _process(_delta: float) -> bool:
	if _done:
		return true
	if _shot_pending != "" and _out != "":
		_hold += 1
		var idle := true
		var r: Object = _scene.get("renderer")
		if r != null and r.get("streamer") != null:
			idle = bool((r.get("streamer") as Object).call("is_idle"))
		if (idle and _hold >= HOLD_MIN) or _hold >= HOLD_MAX:
			var img := root.get_texture().get_image()
			if img != null:
				img.save_png("%s_%s.png" % [_out, _shot_pending])
				print("SHOT ", _shot_pending, " km ", float(_scene.get("pos_km")), " hold ", _hold, " idle ", idle)
			_shot_pending = ""
			_hold = 0
			_set_lapse(_ts, _cap_full)
			_ticks = 0
			_pos_prev = float(_scene.get("pos_km"))
		return false
	var pos := float(_scene.get("pos_km"))
	if _ticks > 0:
		_dpt = maxf((pos - _pos_prev) / float(_ticks), 0.0)
	_ticks = 0
	_pos_prev = pos
	if not _shot_km.is_empty() and pos >= float(_shot_km[0]):
		_shot_pending = "km%05.1f" % float(_shot_km[0])
		_shot_km.remove_at(0)
		_hold = 0
		_set_lapse(1.0, 1)
	elif not _shot_km.is_empty():
		var cap := _cap_full
		if _dpt > 0.0:
			cap = clampi(int(floor((float(_shot_km[0]) - pos) / _dpt)), 1, _cap_full)
		Engine.max_physics_steps_per_frame = cap
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	if int(wall) >= _last_report + 30:
		_last_report = int(wall)
		print("... km %.1f  t %.1f s  wall %.0f s" % [float(_scene.get("pos_km")), float(_scene.call("total_time")), wall])
	if wall > _max_wall:
		print("FEHLER: Zeitlimit überschritten bei km %.2f" % float(_scene.get("pos_km")))
		_report(false)
		quit(1)
		return true
	return false


func _on_finished(result: Dictionary) -> void:
	print("ERGEBNIS ", JSON.stringify(result))
	_report(true)
	_done = true
	quit(0)


func _on_aborted(reason: String) -> void:
	print("FEHLER: Etappe abgebrochen: ", reason)
	_report(false)
	_done = true
	quit(1)


func _report(ok: bool) -> void:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var all := PackedInt64Array()
	for h in _hashes:
		all.append(int(h))
	ctx.update(all.to_byte_array())
	print("HASHES n=%d digest=%s max_cars=%d" % [_hashes.size(), ctx.finish().hex_encode(), _max_cars])
	var ls := []
	for i in mini(_hashes.size(), 100000):
		ls.append(str(_hashes[i]))
	print("HASHLIST ", ",".join(ls))
	print("PERF ", JSON.stringify(_scene.call("perf_stats")))
	print("ERRORS err=%d warn=%d" % [_c.err, _c.warn])
	for l in _c.lines:
		print("  ", l)
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	var st: Variant = _scene.get("stats")
	print("RUN ", JSON.stringify({"ok": ok, "wall_s": wall, "sim_s": float(_scene.get("stage_time")),
		"gfx": str(_scene.get("gfx")) if "gfx" in _scene else "(v0.7.0)",
		"renderer": str((_scene.get("renderer") as Object).get_script().resource_path) if _scene.get("renderer") != null else ""}))
