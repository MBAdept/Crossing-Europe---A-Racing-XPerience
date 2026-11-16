extends SceneTree
## FLACKER-NACHSTELLEN recon probe (scratch, not part of the game): drives a stage in Modern with the autopilot and
## counts how often Godot refuses a geometry instance its slot of the global shader buffer ("Too many instances using
## shader instance variables"), and how many instances with instance uniforms the scene holds.
##   xvfb-run … godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -s <this> -- \
##       --stage=erfurt_kassel --from=erfurt --start-km=0 --hour=12 --gfx-preset=medium --graphics=modern \
##       --sim-s=120 --ts=6 --out=/abs/prefix
## Untyped access to game classes (a -s script compiles before the autoloads exist).

const RACE := "res://scenes/race/race.tscn"
const REFUSAL := "Too many instances using shader instance variables"

class ErrorCatch extends Logger:
	var hits := 0
	var frame_hits: Dictionary = {}
	var frame := 0
	var first := ""
	var others: Dictionary = {}
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var txt := code + " " + rationale
		_lock.lock()
		if txt.contains(REFUSAL):
			hits += 1
			frame_hits[frame] = int(frame_hits.get(frame, 0)) + 1
			if first == "":
				first = txt
		else:
			var k := txt.left(160)
			others[k] = int(others.get(k, 0)) + 1
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catch := ErrorCatch.new()
var _sc: Node
var _frames := 0
var _live_frames := 0
var _t0 := -1.0
var _args := {}
var _rows: Array = []
var _scene_max := 0
var _scene_samples: Array = []
var _wall0 := 0
var _out := ""
var _sim_s := 120.0
var _ts := 6.0


func _arg(k: String, d: String) -> String:
	return str(_args.get(k, d))


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = _arg("out", "/tmp/probe")
	_sim_s = float(_arg("sim-s", "120"))
	_ts = float(_arg("ts", "6"))
	var res := _arg("res", "480x270").split("x")
	root.size = Vector2i(int(res[0]), int(res[1]))
	OS.add_logger(_catch)
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "erfurt_kassel"), "from_city": _arg("from", "erfurt"),
		"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0, "weather": _arg("weather", "normal"),
		"start_km": float(_arg("start-km", "0")), "autopilot": true, "seed": int(_arg("seed", "11")), "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": float(_arg("start-speed", "120")), "traffic_warmup": true}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	_catch.frame = _frames
	_frames += 1
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		if _frames % 60 == 0:
			_sample_scene()
		return _frames > 6000 and _finish()
	var r: Object = _sc.get("renderer")
	if r == null or not r.has_method("layer"):
		return _frames > 6000 and _finish()
	var vl: Object = r.call(&"layer", "vehicles")
	var view: Dictionary = r.get("view")
	if _t0 < 0.0:
		_t0 = float(view.get("time", 0.0))
		Engine.time_scale = _ts
	_live_frames += 1
	var pf: Dictionary = vl.call(&"perf") if vl != null else {}
	var row := {"f": _frames, "t": snappedf(float(view.get("time", 0.0)) - _t0, 0.001), "km": snappedf(float(_sc.get("pos_km")), 0.001),
		"ref": int(_catch.frame_hits.get(_frames - 1, 0)), "vi": int(pf.get("vehicle_instances", 0)), "vb": int(pf.get("vehicle_builds", 0)),
		"vt": int(pf.get("vehicle_trims", 0)), "vd": int(pf.get("vehicles", 0)), "sd": int(pf.get("standin_cars", 0))}
	if _live_frames % 30 == 0:
		row["scene"] = _sample_scene()
	_rows.append(row)
	if float(view.get("time", 0.0)) - _t0 >= _sim_s or _live_frames > 20000:
		return _finish()
	return false


func _sample_scene() -> int:
	var n := _scene_instances()
	_scene_max = maxi(_scene_max, n)
	return n


func _finish() -> bool:
	Engine.time_scale = 1.0
	OS.remove_logger(_catch)
	var f := FileAccess.open(_out + "_frames.jsonl", FileAccess.WRITE)
	if f != null:
		for row: Dictionary in _rows:
			f.store_line(JSON.stringify(row))
		f.close()
	var summary := {"args": _args, "frames": _frames, "live_frames": _live_frames, "refusals": _catch.hits, "refusal_frames": _catch.frame_hits.size(),
		"first": _catch.first, "scene_max": _scene_max, "wall_s": (Time.get_ticks_msec() - _wall0) / 1000.0,
		"km_end": float(_sc.get("pos_km")) if _sc != null else -1.0, "other_errors": _catch.others}
	var g := FileAccess.open(_out + "_summary.json", FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify(summary, "  "))
		g.close()
	print("PROBE summary ", JSON.stringify(summary))
	quit(0)
	return true


## Geometry instances whose material has instance uniforms, in the whole tree (16 slots each) – as
## tests/race3d/render/check_instance_budget.gd counts them.
func _scene_instances() -> int:
	var n := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		for c in x.get_children():
			stack.append(c)
		if not (x is GeometryInstance3D) or x.is_queued_for_deletion():
			continue
		if _uses_instance_uniforms(x as GeometryInstance3D):
			n += 1
	return n


static func _uses_instance_uniforms(gi: GeometryInstance3D) -> bool:
	var mats: Array[Material] = []
	if gi.material_override != null:
		mats.append(gi.material_override)
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
		var mi := gi as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(k)
			if m != null:
				mats.append(m)
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
		var mesh := (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for k in mesh.get_surface_count():
				var m2: Material = mesh.surface_get_material(k)
				if m2 != null:
					mats.append(m2)
	for m: Material in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("instance uniform"):
			return true
	return false
