extends SceneTree
## FLACKER-NACHSTELLEN (scratch, not part of the game): the level switch of ONE traffic car as the chase camera sees
## it, in Modern AND Arcade from the same simulation states (run twice, --gfx=modern / --gfx=arcade). The player
## stands still (0 km/h, no autopilot); every frame the probe puts the car (a TrafficSystem.Car of its own, so both
## renderers draw it) at camera distance d in the player's lane and removes every other car.
##
## Modes (--mode):
##   sweep  d goes from --far down to --near and back (--step m per frame); every frame a crop around the car
##          (<out>/<set>/f####.png), a log line {d, lod, xfade, refused}; full frames at --full-d.
##   clip   d = --centre + --amp * sin(2 pi t / --period) for --clip-frames frames at the fixed 60 fps: what a player who
##          follows the car at ~40 m with small speed changes sees (camera fixed here); full frames saved for ffmpeg.
## --refuse=none|lod0|lod1 (Modern): forces Godot to refuse the instance-uniform slots of that level of the car (the
##   overflow of the 4096-vec4 global shader buffer): the car's built levels are dropped, 300 hidden vpbr dummies fill
##   the buffer, and the level is rebuilt after that -> refused (Logger counts it). With lod1 the dummies come before
##   the car appears and 40 of them are freed before lod0 is built (lod0 gets slots, lod1 not).
## Arguments: --gfx --stage --from --start-km --hour --weather --sets=a,b --far --near --step --crop=x,y,w,h --out
##   --res=1280x720 --mode --centre --amp --period --clip-frames --refuse --full-d=40
## Untyped access to game classes (a -s script compiles before the autoloads exist).

const RACE := "res://scenes/race/race.tscn"
const REFUSAL := "Too many instances using shader instance variables"
const DUMMIES := 300

class ErrorCatch extends Logger:
	var hits := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if (code + " " + rationale).contains(REFUSAL):
			_lock.lock()
			hits += 1
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catch := ErrorCatch.new()
var _sc: Node
var _args := {}
var _out := ""
var _sets: PackedStringArray
var _si := 0
var _phase := 0
var _pf := 0
var _d := 0.0
var _far := 45.0
var _near := 36.0
var _step := 0.08
var _crop := Rect2i(400, 280, 480, 240)
var _car: Object = null
var _log: FileAccess
var _frame_i := 0
var _last_set_d := -1.0
var _pos_z := 0.0
var _x := 0.0
var _gfx := "modern"
var _mode := "sweep"
var _refuse := "none"
var _wait := 0
var _dummies: Array = []
var _hits_before := 0
var _clip_t := 0


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = _arg("out", "/tmp/switch")
	_gfx = _arg("gfx", "modern")
	_mode = _arg("mode", "sweep")
	_refuse = _arg("refuse", "none")
	_sets = _arg("sets", "traffic/hatch_white").split(",")
	_far = float(_arg("far", "45"))
	_near = float(_arg("near", "36"))
	_step = float(_arg("step", "0.08"))
	var c := _arg("crop", "400,280,480,240").split(",")
	_crop = Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
	var res := _arg("res", "1280x720").split("x")
	root.size = Vector2i(int(res[0]), int(res[1]))
	OS.add_logger(_catch)
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "erfurt_kassel"), "from_city": _arg("from", "erfurt"),
		"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0, "weather": _arg("weather", "normal"),
		"start_km": float(_arg("start-km", "30")), "autopilot": false, "seed": int(_arg("seed", "11")), "gfx": _gfx,
		"no_countdown": true, "start_speed_kmh": 0.0, "traffic_warmup": true}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out.path_join("log.jsonl"), FileAccess.WRITE)


func _vl() -> Object:
	var r: Object = _sc.get("renderer")
	if r == null or not r.has_method("layer"):
		return null
	return r.call(&"layer", "vehicles")


func _layer_car() -> Object:
	var vl := _vl()
	if vl == null:
		return null
	var cars: Dictionary = vl.get("_cars")
	return cars.get(777777)


## Drops the built levels of the probe car (all, or only `only`) so the layer builds them again.
func _drop_levels(only: String) -> void:
	var c := _layer_car()
	if c == null:
		return
	var levels: Dictionary = c.get("levels")
	for lod: Variant in levels.keys():
		if only != "" and str(lod) != only:
			continue
		var n: Node3D = levels[lod]
		if n == c.get("node"):
			c.set("node", null)
			c.set("lod", "")
			c.set("lod_i", -1)
			var empty: Array[GeometryInstance3D] = []
			c.set("geo", empty)
		levels.erase(lod)
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()


## 300 vpbr dummies far below the road: they take every free slot of the global shader buffer.
func _fill() -> void:
	var vl := _vl()
	var mats: Object = vl.get("_mats")
	var m: Material = mats.call(&"material", "vpbr")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	var holder := Node3D.new()
	holder.name = "flk_dummies"
	(_sc.get("renderer") as Node).add_child(holder)
	for i in DUMMIES:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(0.0, -800.0 - float(i), 0.0)
		holder.add_child(mi)
		_dummies.append(mi)


func _unfill(n: int) -> void:
	for i in mini(n, _dummies.size()):
		var mi: Node = _dummies.pop_back()
		mi.queue_free()


func _process(_dt: float) -> bool:
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	var tr: Object = _sc.get("traffic")
	var r: Object = _sc.get("renderer")
	if r == null:
		return false
	if _car == null:
		_wait += 1
		if _wait < int(_arg("wait", "220")):
			return false
		var ts: GDScript = load("res://scripts/gameplay/traffic_system.gd")
		_car = (ts.get("Car") as GDScript).new() if ts.get("Car") != null else null
		if _car == null:
			var cars: Array = tr.get("cars")
			_car = cars[0]
		_car.set("id", 777777)
		var track: Object = _sc.get("track")
		_pos_z = float(_sc.get("pos_z"))
		var px := float((_sc.get("vehicle") as Object).get("x"))
		var lanes := int(track.call(&"lane_count_at", _pos_z))
		var lane := lanes - 1
		var best := INF
		for li in lanes:
			var dx := absf(float(track.call(&"lane_center_x", _pos_z, li)) - px)
			if dx < best:
				best = dx
				lane = li
		_x = float(track.call(&"lane_center_x", _pos_z + 40.0, clampi(lane, 0, lanes - 1)))
		_log.store_line(JSON.stringify({"ev": "start", "gfx": _gfx, "pos_z": _pos_z, "player_x": px, "car_x": _x, "lanes": lanes,
			"mode": _mode, "refuse": _refuse}))
		_begin_set()
		return false
	# the picture of the last frame shows the state set one iteration ago
	var img := root.get_texture().get_image()
	var lod := ""
	var xf := 0.0
	var cd := -1.0
	if _gfx == "modern":
		var c := _layer_car()
		if c != null:
			lod = str(c.get("lod"))
			xf = float(c.get("xf_t"))
			cd = float(c.get("dist"))
	var set_id := _sets[_si]
	var dir := _out.path_join(set_id.replace("/", "_"))
	match _phase:
		0:
			# background without the car (a few frames to settle)
			_pf += 1
			if _pf == 6:
				img.get_region(_crop).save_png(dir.path_join("bg.png"))
				img.save_png(dir.path_join("bg_full.png"))
				if _refuse == "lod1" and _gfx == "modern":
					_fill()         # before the car appears: its first level (lod1) is refused
					_hits_before = _catch.hits
				_phase = 1
				_pf = 0
				_d = _far
		1:
			# car at the far end, settle (level built)
			_pf += 1
			if _pf == 2 and _gfx == "modern" and _refuse == "lod1":
				_drop_levels("")   # a pooled car of the set may have its levels already: build them again (refused)
			if _pf == 6 and _gfx == "modern" and _refuse == "lod0":
				_drop_levels("lod0")
				_fill()            # lod1 (shown) keeps its slots; lod0 is built later -> refused
				_hits_before = _catch.hits
			if _pf == 10 and _gfx == "modern" and _refuse == "lod1":
				_unfill(40)        # room for lod0 (built when the car comes nearer)
			if _pf == 14:
				_phase = 2 if _mode == "sweep" else 4
				_pf = 0
				_log.store_line(JSON.stringify({"ev": "ready", "set": set_id, "lod": lod, "refusals": _catch.hits, "dummies": _dummies.size()}))
		2, 3:
			_frame_i += 1
			img.get_region(_crop).save_png(dir.path_join("f%04d.png" % _frame_i))
			if _phase == 2 and absf(_last_set_d - float(_arg("full-d", "40"))) < _step * 0.5:
				img.save_png(dir.path_join("full_%.1fm.png" % _last_set_d))
			_log.store_line(JSON.stringify({"set": set_id, "i": _frame_i, "d": snappedf(_last_set_d, 0.001), "lod": lod, "xf": snappedf(xf, 0.001),
				"phase": "in" if _phase == 2 else "out", "refusals": _catch.hits, "cd": snappedf(cd, 0.001)}))
			if _phase == 2:
				_d -= _step
				if _d <= _near:
					_phase = 3
			else:
				_d += _step
				if _d >= _far:
					return _next_set()
		4:
			# clip: full frames, d oscillating around the switch band
			_frame_i += 1
			var cc := _arg("clip-crop", "320,160,640,360").split(",")
			img.get_region(Rect2i(int(cc[0]), int(cc[1]), int(cc[2]), int(cc[3]))).save_png(dir.path_join("c%04d.png" % _frame_i))
			img.get_region(_crop).save_png(dir.path_join("f%04d.png" % _frame_i))
			_log.store_line(JSON.stringify({"set": set_id, "i": _frame_i, "d": snappedf(_last_set_d, 0.001), "lod": lod, "xf": snappedf(xf, 0.001),
				"phase": "clip", "refusals": _catch.hits, "cd": snappedf(cd, 0.001)}))
			_clip_t += 1
			var t := float(_clip_t) / 60.0
			_d = float(_arg("centre", "40")) + float(_arg("amp", "3")) * sin(TAU * t / float(_arg("period", "2.0")))
			if _clip_t >= int(_arg("clip-frames", "240")):
				return _next_set()
	_place()
	return false


func _next_set() -> bool:
	_si += 1
	if _si >= _sets.size():
		_log.store_line(JSON.stringify({"ev": "end", "refusals": _catch.hits}))
		_log.close()
		OS.remove_logger(_catch)
		quit(0)
		return true
	_unfill(_dummies.size())
	_begin_set()
	return false


func _begin_set() -> void:
	_phase = 0
	_pf = 0
	_frame_i = 0
	_clip_t = 0
	_d = 2000.0          # out of sight while the background is taken
	var set_id := _sets[_si]
	DirAccess.make_dir_recursive_absolute(_out.path_join(set_id.replace("/", "_")))
	var tr: Object = _sc.get("traffic")
	var dims: Dictionary = tr.get("_dims")
	var dm: Variant = dims.get(set_id)
	_car.set("set_id", set_id)
	if dm is Dictionary:
		_car.set("length", float((dm as Dictionary).get("length", 4.5)))
		_car.set("width", float((dm as Dictionary).get("width", 1.8)))
		_car.set("height", float((dm as Dictionary).get("height", 1.5)))
	_car.set("heavy", set_id.contains("truck") or set_id.contains("bus"))
	_log.store_line(JSON.stringify({"ev": "set", "set": set_id, "dims": dm}))


## Puts the car at camera distance _d (its centre) and makes it the only car of the traffic.
func _place() -> void:
	var tr: Object = _sc.get("traffic")
	var cam_dist := 9.0
	var proj: Object = _sc.get("proj")
	if proj != null:
		cam_dist = float(proj.get("cam_distance"))
	var z := _pos_z - cam_dist + _d
	_car.set("z", z)
	_car.set("prev_z", z)
	_car.set("x", _x)
	_car.set("prev_x", _x)
	_car.set("speed", 0.0)
	_car.set("cruise_speed", 0.0)
	_car.set("braking", false)
	_car.set("signal_dir", 0)
	var cars: Array = tr.get("cars")
	cars.clear()
	if _d < 1500.0:
		cars.append(_car)
	_last_set_d = _d
