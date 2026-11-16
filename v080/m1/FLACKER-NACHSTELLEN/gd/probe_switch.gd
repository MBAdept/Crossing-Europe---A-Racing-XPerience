extends SceneTree
## FLACKER-NACHSTELLEN (scratch): the level switch of a traffic car as the chase camera sees it, in Modern AND Arcade
## from the same simulation states. The player stands still (no autopilot, 0 km/h); every frame the probe puts ONE
## traffic car (TrafficSystem.Car, so both renderers draw it from the same view) at camera distance d in the player's
## lane (or --lane-off lanes beside it) and removes every other car. Per set: background without the car, then d sweeps
## from --far down to --near and back (step --step m per frame); every frame a crop around the car is saved
## (<out>/<set>/f####.png) and a log line {d, lod, xfade} (Modern). Python (switch_stats.py) measures the change at
## the switch frames. Run with --gfx-sync. Arguments: --gfx=modern|arcade --stage --from --start-km --hour --weather
## --sets=a,b --far --near --step --crop=x,y,w,h --lane-off=0 --out --res=1280x720

const RACE := "res://scenes/race/race.tscn"

var _sc: Node
var _args := {}
var _out := ""
var _sets: PackedStringArray
var _si := 0
var _phase := 0
var _pf := 0
var _d := 0.0
var _dir := -1.0
var _far := 45.0
var _near := 36.0
var _step := 0.08
var _crop := Rect2i(400, 280, 480, 240)
var _lane_off := 0
var _car: Object = null
var _log: FileAccess
var _frame_i := 0
var _last_set_d := -1.0
var _pos_z := 0.0
var _x := 0.0
var _gfx := "modern"
var _wait := 0


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = _arg("out", "/tmp/switch")
	_gfx = _arg("gfx", "modern")
	_sets = _arg("sets", "traffic/hatch_white").split(",")
	_far = float(_arg("far", "45"))
	_near = float(_arg("near", "36"))
	_step = float(_arg("step", "0.08"))
	_lane_off = int(_arg("lane-off", "0"))
	var c := _arg("crop", "400,280,480,240").split(",")
	_crop = Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
	var res := _arg("res", "1280x720").split("x")
	root.size = Vector2i(int(res[0]), int(res[1]))
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
		_x = float(track.call(&"lane_center_x", _pos_z + 40.0, clampi(lane + _lane_off, 0, lanes - 1)))
		_log.store_line(JSON.stringify({"ev": "start", "gfx": _gfx, "pos_z": _pos_z, "player_x": px, "car_x": _x, "lanes": lanes}))
		_begin_set()
		return false
	# the picture of the last frame shows the state set one iteration ago
	var img := root.get_texture().get_image()
	var lod := ""
	var xf := 0.0
	if _gfx == "modern":
		var vl: Object = r.call(&"layer", "vehicles")
		var cars: Dictionary = vl.get("_cars")
		var c: Object = cars.get(777777)
		if c != null:
			lod = str(c.get("lod"))
			xf = float(c.get("xf_t"))
	var set_id := _sets[_si]
	var dir := _out.path_join(set_id.replace("/", "_"))
	match _phase:
		0:
			# background without the car (a few frames to settle)
			_pf += 1
			if _pf == 6:
				img.get_region(_crop).save_png(dir.path_join("bg.png"))
				_phase = 1
				_pf = 0
				_d = _far
		1:
			# car at the far end, settle (level built)
			_pf += 1
			if _pf == 8:
				_phase = 2
				_pf = 0
		2, 3:
			_frame_i += 1
			img.get_region(_crop).save_png(dir.path_join("f%04d.png" % _frame_i))
			if _phase == 2 and absf(_last_set_d - float(_arg("full-d", "40"))) < _step * 0.5:
				img.save_png(dir.path_join("full_%.1fm.png" % _last_set_d))
			_log.store_line(JSON.stringify({"set": set_id, "i": _frame_i, "d": snappedf(_last_set_d, 0.001), "lod": lod, "xf": snappedf(xf, 0.001),
				"phase": "in" if _phase == 2 else "out"}))
			if _phase == 2:
				_d -= _step
				if _d <= _near:
					_phase = 3
			else:
				_d += _step
				if _d >= _far:
					_si += 1
					if _si >= _sets.size():
						_log.close()
						quit(0)
						return true
					_begin_set()
	_place()
	return false


func _begin_set() -> void:
	_phase = 0
	_pf = 0
	_frame_i = 0
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
