extends SceneTree
## FLACKER-ANALYSE (scratch only, ZS1 tree): the real race scene in Modern under Xvfb (real buffer of 4096 slots) on the
## stage the user drove – catches every "Too many instances using shader instance variables" of the engine (Logger),
## from the loading cover (shader warm-up) on, and counts the instances with instance uniforms of the whole scene.
## usage: xvfb-run … godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://flk_refusal_run.gd --
##        --graphics=modern --gfx-preset=medium --flk-from=erfurt --flk-km=0 --flk-sim=120 --flk-scale=4

const RACE := "res://scenes/race/race.tscn"
const REFUSAL := "Too many instances using shader instance variables"


class ErrorCatch extends Logger:
	var hits := 0
	var probing := false
	var probe_hits := 0
	var frames: Array = []
	var frame := 0
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if (code + " " + rationale).contains(REFUSAL):
			_lock.lock()
			if probing:
				probe_hits += 1
				_lock.unlock()
				return
			hits += 1
			if frames.size() < 40:
				frames.append(frame)
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catch := ErrorCatch.new()
var _sc: Node
var _frames := 0
var _t0 := -1.0
var _scale := 4.0
var _sim := 120.0
var _worst := 0
var _worst_frame := 0
var _worst_live := 0
var _prep_worst := 0
var _wall0 := 0
var _label := ""
## engine-truth probe of the free capacity of the global shader buffer: in a frame where the race scene does not
## process (nothing of the game is queued), PROBE_N quads with an instance uniform are created at frame_pre_draw;
## the refusals the logger sees until frame_post_draw give the free capacity (headroom = PROBE_N - refusals).
const PROBE_N := 300
var _probe_every := 30
var _probe_mesh: QuadMesh
var _probe_nodes: Array = []
var _probe_hits0 := 0
var _probe_state := 0            ## 0 idle, 1 scene paused this frame (probe at pre_draw), 2 probes queued
var _probe_hits_total := 0
var _probe_min := 999
var _probe_min_frame := 0
var _probe_n := 0
var _probe_log: Array = []
var _last_n := 0


func _arg(name: String, def: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	OS.add_logger(_catch)
	root.size = Vector2i(640, 400)
	_scale = float(_arg("flk-scale", "4"))
	_sim = float(_arg("flk-sim", "120"))
	var from := _arg("flk-from", "erfurt")
	var km := float(_arg("flk-km", "0"))
	var hour := float(_arg("flk-hour", "13"))
	_label = "erfurt_kassel ab %s km %.1f %s Uhr preset %s warm %s" % [from, km, hour, _arg("gfx-preset", "?"), _arg("flk-warm", "0")]
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": "erfurt_kassel", "from_city": from, "vehicle": "limousine",
		"start_world_minutes": hour * 60.0, "weather": "normal", "start_km": km, "autopilot": true, "seed": int(_arg("flk-seed", "3")),
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": _arg("flk-warm", "0") == "1"}
	_probe_every = int(_arg("flk-probe-every", "30"))
	var psh := Shader.new()
	psh.code = "shader_type spatial;\nrender_mode unshaded;\ninstance uniform float pv : instance_index(0) = 1.0;\nvoid fragment() { ALBEDO = vec3(pv); }\n"
	var pm := ShaderMaterial.new()
	pm.shader = psh
	_probe_mesh = QuadMesh.new()
	_probe_mesh.size = Vector2(0.01, 0.01)
	_probe_mesh.material = pm
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_dt: float) -> bool:
	_frames += 1
	_catch.frame = _frames
	if _probe_state == 0 and _sc != null and _probe_every > 0 and _frames > 20 and _frames % _probe_every == 0:
		_sc.process_mode = Node.PROCESS_MODE_DISABLED
		_probe_state = 1
		_last_n = _scene_instances()
		return false
	if _sc != null and _sc.process_mode == Node.PROCESS_MODE_DISABLED and _probe_state == 0:
		_sc.process_mode = Node.PROCESS_MODE_INHERIT
	var n := 0
	if _frames % 10 == 0 or _frames < 400:
		n = _scene_instances()
	if _frames % 150 == 0:
		print("FLKP f%d hits %d n %d prep_worst %d worst %d sim_steps %s wall %.0f s" % [_frames, _catch.hits, n, _prep_worst, _worst,
			str(_sc.get("_sim_steps") if _sc != null else -1), (Time.get_ticks_msec() - _wall0) / 1000.0])
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		_prep_worst = maxi(_prep_worst, n)
		return _frames > 6000 and _finish()
	var r: Object = _sc.get("renderer")
	var view: Dictionary = r.get("view")
	if _t0 < 0.0:
		_t0 = float(view.get("time", 0.0))
		_worst_live = 0
		Engine.time_scale = _scale
	if n > _worst:
		_worst = n
		_worst_frame = _frames
	_worst_live = maxi(_worst_live, n)
	if float(view.get("time", 0.0)) - _t0 >= _sim or _frames > 20000:
		return _finish()
	return false


func _pre_draw() -> void:
	if _probe_state != 1:
		return
	_probe_hits0 = _catch.probe_hits
	_catch.probing = true
	var holder := Node3D.new()
	holder.name = "flk_probe"
	holder.position = Vector3(0.0, -50000.0, 0.0)
	root.add_child(holder)
	_probe_nodes = [holder]
	for i in PROBE_N:
		var mi := MeshInstance3D.new()
		mi.mesh = _probe_mesh
		holder.add_child(mi)
	_probe_state = 2


func _post_draw() -> void:
	if _probe_state != 2:
		return
	_catch.probing = false
	var r := _catch.probe_hits - _probe_hits0
	_probe_hits_total += r
	var head := PROBE_N - r
	_probe_n += 1
	var sim_t := -1.0
	if _sc != null and _sc.get("renderer") != null and _t0 >= 0.0:
		var view: Dictionary = (_sc.get("renderer") as Object).get("view")
		sim_t = float(view.get("time", 0.0)) - _t0
	var km := -1.0
	if _sc != null and _sc.get("renderer") != null:
		var v2: Dictionary = (_sc.get("renderer") as Object).get("view")
		km = float(v2.get("camera_z", -1.0))
	var odo := float(_sc.get("pos_km")) if _sc != null and _sc.get("pos_km") != null else -1.0
	var ncars := -1
	var vinst := -1
	if _sc != null and _sc.get("renderer") != null:
		var v3: Dictionary = (_sc.get("renderer") as Object).get("view")
		ncars = (v3.get("cars", []) as Array).size()
		var vl: Variant = (_sc.get("renderer") as Object).call(&"layer", "vehicles")
		if vl is Object:
			vinst = int(((vl as Object).call(&"perf") as Dictionary).get("vehicle_instances", -1))
	if head < _probe_min:
		_probe_min = head
		_probe_min_frame = _frames
	var line := "FLKH f%d sim %.1f km %.2f cam_z %.0f headroom %d tree %d (engine used %d) cars %d veh_inst %d" % [_frames, sim_t, odo, km, head, _last_n, 254 - head, ncars, vinst]
	print(line)
	for nd: Node in _probe_nodes:
		nd.free()
	_probe_nodes = []
	_probe_state = 0


func _finish() -> bool:
	Engine.time_scale = 1.0
	OS.remove_logger(_catch)
	var pf := {}
	if _sc != null and _sc.get("renderer") != null:
		pf = ((_sc.get("renderer") as Object).call(&"layer", "vehicles") as Object).call(&"perf")
	print("FLKPROBE %d Proben, kleinste Reserve %d (Bild %d), Proben-Ablehnungen %d" % [_probe_n, _probe_min, _probe_min_frame, _probe_hits_total])
	print("FLK %s: %d Bilder, Ablehnungen %d (erste Bilder %s), ganze Szene max %d (Ladephase %d, Fahrt %d), Fahrzeug-Ebene Spitze %d, Bauten %d, Freigaben %d; %.0f s Wand" % [
		_label, _frames, _catch.hits, str(_catch.frames.slice(0, 12)), maxi(_worst, _prep_worst), _prep_worst, _worst_live,
		int(pf.get("vehicle_instances_peak", 0)), int(pf.get("vehicle_builds", 0)), int(pf.get("vehicle_trims", 0)),
		(Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0)
	return true


func _scene_instances() -> int:
	var n := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		for c in x.get_children():
			stack.append(c)
		if not (x is GeometryInstance3D) or x.is_queued_for_deletion():
			continue
		if _uses(x as GeometryInstance3D):
			n += 1
	return n


static func _uses(gi: GeometryInstance3D) -> bool:
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
