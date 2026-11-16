extends SceneTree
## FLACKER-NACHSTELLEN (scratch): does a Modern stage leave slots of Godot's global shader buffer behind when it ends?
## Measures the free capacity (instances with instance uniforms that still get a slot) in a fresh process, after each
## of --stages (stage:from:km, comma separated) driven for --run-s seconds of view time with the autopilot and freed
## like GameFlow frees a stage. Capacity test: --probe-n hidden vpbr dummies, the Logger counts the refusals,
## free = n - refusals; the dummies are freed again. Prints one line per measurement.

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
var _args := {}
var _stages: PackedStringArray
var _si := 0
var _phase := 0
var _pf := 0
var _sc: Node
var _dummies: Array = []
var _hits0 := 0
var _t0 := -1.0
var _results: Array = []
var _mats: Object = null


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_stages = _arg("stages", "erfurt_kassel:erfurt:88,erfurt_kassel:erfurt:120").split(",")
	root.size = Vector2i(480, 270)
	OS.add_logger(_catch)
	root.get_node("Settings").call("disarm_crash_guard")


func _process(_dt: float) -> bool:
	_pf += 1
	match _phase:
		0:
			# the shared materials (registers the ce_* globals, like the first Modern scene of the game does)
			var mm: Script = load("res://scripts/race3d/modern_materials.gd")
			_mats = mm.call(&"shared")
			_phase = 1
			_pf = 0
		1:
			if _pf == 3:
				_cap_start()
			elif _pf == 8:
				_cap_end("fresh process")
				if _si >= _stages.size():
					return _finish()
				_start_stage()
				_phase = 2
				_pf = 0
		2:
			if _sc == null or int(_sc.get("_sim_steps")) < 2:
				return _pf > 20000 and _finish()
			var r: Object = _sc.get("renderer")
			var view: Dictionary = r.get("view")
			if _t0 < 0.0:
				_t0 = float(view.get("time", 0.0))
				Engine.time_scale = float(_arg("ts", "4"))
			if float(view.get("time", 0.0)) - _t0 >= float(_arg("run-s", "40")):
				Engine.time_scale = 1.0
				_results.append({"stage_end": _stages[_si], "refusals_during_stage": _catch.hits - _hits0,
					"km": float(_sc.get("pos_km"))})
				_sc.queue_free()
				_sc = null
				_si += 1
				_phase = 3
				_pf = 0
		3:
			if _pf == 10:
				_cap_start()
			elif _pf == 15:
				_cap_end("after stage %d" % _si)
				if _si >= _stages.size():
					return _finish()
				_start_stage()
				_phase = 2
				_pf = 0
	return false


func _start_stage() -> void:
	var p := _stages[_si].split(":")
	_hits0 = _catch.hits
	_t0 = -1.0
	var setup := {"mode": "single", "race_id": "", "stage_id": p[0], "from_city": p[1], "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": float(p[2]), "autopilot": true, "seed": 11 + _si,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": true, "autopilot_refuel": "never"}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _cap_start() -> void:
	_hits0 = _catch.hits
	var m: Material = _mats.call(&"material", "vpbr")
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	for i in int(_arg("probe-n", "300")):
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = m
		mi.visible = false
		root.add_child(mi)
		_dummies.append(mi)


func _cap_end(tag: String) -> void:
	var n := _dummies.size()
	var refused := _catch.hits - _hits0
	for d: Node in _dummies:
		d.queue_free()
	_dummies.clear()
	var rec := {"when": tag, "dummies": n, "refused": refused, "free_capacity": n - refused, "in_tree_iu": _count_iu()}
	_results.append(rec)
	print("LEAK ", JSON.stringify(rec))


func _count_iu() -> int:
	var n := 0
	for x: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := x as GeometryInstance3D
		if _dummies.has(gi):
			continue
		var mats: Array = []
		if gi.material_override != null:
			mats.append(gi.material_override)
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			for k in (gi as MeshInstance3D).mesh.get_surface_count():
				var m: Material = (gi as MeshInstance3D).get_active_material(k)
				if m != null:
					mats.append(m)
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null and (gi as MultiMeshInstance3D).multimesh.mesh != null:
			var mesh := (gi as MultiMeshInstance3D).multimesh.mesh
			for k in mesh.get_surface_count():
				var m2: Material = mesh.surface_get_material(k)
				if m2 != null:
					mats.append(m2)
		for m3: Variant in mats:
			if m3 is ShaderMaterial and (m3 as ShaderMaterial).shader != null and (m3 as ShaderMaterial).shader.code.contains("instance uniform"):
				n += 1
				break
	return n


func _finish() -> bool:
	OS.remove_logger(_catch)
	var f := FileAccess.open(_arg("out", "/tmp/leak") + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_results, "  "))
	f.close()
	print("LEAK done ", JSON.stringify(_results))
	quit(0)
	return true
