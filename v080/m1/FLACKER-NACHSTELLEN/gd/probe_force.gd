extends SceneTree
## FLACKER-NACHSTELLEN (scratch): what a car looks like whose geometry Godot refused a slot of the global shader buffer.
## In a real Modern race (the rig's light, palette and ce_* globals) the probe waits until the followed traffic car is
## at --at-m (camera distance), then builds three copies of a model next to it in the neighbouring lane:
##   A  built BEFORE the buffer is filled (gets its slots: the normal look)
##   B  built AFTER the buffer was filled with hidden vpbr dummies (refused: what the user may have seen)
## and saves the frames: before filling, with A and B, and crops. The copies get the same instance uniforms the vehicle
## layer gives a traffic car (paint of the set, fade 1, sun 1, lamps off, xfade 0).
## Arguments: --stage --from --start-km --hour --set=traffic/hatch_white --lod=lod0 --at-m=45 --out --pilot --prefer

const RACE := "res://scenes/race/race.tscn"
const REFUSAL := "Too many instances using shader instance variables"

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
var _frames := 0
var _phase := 0
var _phase_f := 0
var _pilot: Object = null
var _dummies: Array = []
var _copy_a: Node3D
var _copy_b: Node3D
var _target_id := -1
var _info := {}


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = _arg("out", "/tmp/force")
	var res := _arg("res", "1280x720").split("x")
	root.size = Vector2i(int(res[0]), int(res[1]))
	OS.add_logger(_catch)
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "erfurt_kassel"), "from_city": _arg("from", "erfurt"),
		"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0, "weather": "normal",
		"start_km": float(_arg("start-km", "0")), "autopilot": true, "seed": int(_arg("seed", "11")), "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": float(_arg("start-speed", "120")), "traffic_warmup": true, "autopilot_refuel": "never"}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames > 20000:
		return _done("timeout")
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	var r: Object = _sc.get("renderer")
	if r == null or not r.has_method("layer"):
		return false
	var vl: Object = r.call(&"layer", "vehicles")
	if _pilot == null:
		_install_pilot()
	var cars: Dictionary = vl.get("_cars")
	var tid := int(_pilot.get("target_id")) if _pilot != null else -1
	var car: Object = cars.get(tid)
	match _phase:
		0:
			# wait for the followed car at the wanted distance, showing a model level
			if car != null and bool(car.get("shown")) and not bool((car.get("info") as Dictionary).get("box", false)):
				var d := float(car.get("dist"))
				if absf(d - float(_arg("at-m", "45"))) < 3.0 and str(car.get("set_id")).contains(_arg("prefer", "")):
					_target_id = tid
					Engine.time_scale = 0.0          # hold the simulation: the same state for every picture
					_copy_a = _place_copy(r, car, -1.0, "A")
					_phase = 1
					_phase_f = _frames
		1:
			if _frames - _phase_f >= 3:
				_save("1_with_A")
				# fill the global buffer with hidden vpbr instances (each takes 16 slots even when hidden)
				var mats: Object = r.get("materials")
				var m: Material = mats.call(&"material", "vpbr")
				var box := BoxMesh.new()
				box.size = Vector3(0.1, 0.1, 0.1)
				for i in int(_arg("dummies", "300")):
					var mi := MeshInstance3D.new()
					mi.mesh = box
					mi.material_override = m
					mi.visible = false
					root.add_child(mi)
					_dummies.append(mi)
				_phase = 2
				_phase_f = _frames
		2:
			if _frames - _phase_f >= 3:
				var before := _catch.hits
				_info["refusals_after_fill"] = before
				var tc: Object = cars.get(_target_id)
				if tc == null:
					return _done("target lost")
				_copy_b = _place_copy(r, tc, 1.0, "B")
				_phase = 3
				_phase_f = _frames
		3:
			if _frames - _phase_f >= 3:
				_info["refusals_after_B"] = _catch.hits
				_save("2_with_A_and_B")
				# free the dummies: B stays refused (Godot never retries an instance)
				for d: Node in _dummies:
					d.queue_free()
				_dummies.clear()
				_phase = 4
				_phase_f = _frames
		4:
			if _frames - _phase_f >= 4:
				_save("3_after_free")
				return _done("ok")
	return false


func _install_pilot() -> void:
	var scr: Script = load(_arg("pilot", ""))
	var old: Object = _sc.get("autopilot")
	_pilot = scr.new()
	_pilot.set("target_kmh", old.get("target_kmh") if old != null else 235.0)
	_pilot.set("refuel_mode", "never")
	_pilot.set("prefer", _arg("prefer", "_white"))
	_pilot.set("gap_lo", float(_arg("gap-lo", "30")))
	_pilot.set("gap_hi", float(_arg("gap-hi", "40")))
	_pilot.set("wiggle", 0.0)
	var ms := {}
	var model_db: Script = load("res://scripts/core/model_db.gd")
	for sid: Variant in root.get_node(^"SpriteDB").call(&"ids_with_tag", "traffic"):
		if bool(model_db.call(&"has_model", str(sid))):
			ms[str(sid)] = true
	_pilot.set("model_sets", ms)
	_sc.set("autopilot", _pilot)


## A copy of the followed car's model (set --set or the car's own) at --lod, one lane to the side (side -1 left,
## +1 right) at the car's pose, with the instance uniforms the vehicle layer gives a traffic car by day.
func _place_copy(r: Object, car: Object, side: float, tag: String) -> Node3D:
	var sid := _arg("set", str(car.get("set_id")))
	var model_factory: Script = load("res://scripts/race3d/model_factory.gd")
	var n: Node3D = model_factory.call(&"build", sid, _arg("lod", "lod0"), r.get("materials"), true)
	n.name = "copy_" + tag
	var pose: Transform3D = car.get("pose")
	var t := pose
	t.origin += pose.basis.x.normalized() * side * float(_arg("lane-m", "3.75"))
	n.transform = t
	(r.get("world") as Node3D).add_child(n)
	for gi: GeometryInstance3D in model_factory.call(&"geometry_of", n):
		gi.set_instance_shader_parameter(&"fade", 1.0)
		gi.set_instance_shader_parameter(&"sun", 1.0)
		gi.set_instance_shader_parameter(&"lamp_a", Vector4.ZERO)
		gi.set_instance_shader_parameter(&"lamp_b", Vector4.ZERO)
		gi.set_instance_shader_parameter(&"xfade", 0.0)
		if str(gi.name) == "shadow":
			gi.visible = true
	_info["copy_" + tag] = {"set": sid, "lod": _arg("lod", "lod0"), "dist": float(car.get("dist"))}
	return n


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out + "_" + name + ".png")


func _done(why: String) -> bool:
	_info["why"] = why
	_info["refusals_total"] = _catch.hits
	var f := FileAccess.open(_out + "_info.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_info, "  "))
	f.close()
	print("FORCE ", JSON.stringify(_info))
	Engine.time_scale = 1.0
	quit(0)
	return true
