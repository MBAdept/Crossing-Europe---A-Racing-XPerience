extends SceneTree
## The instance uniforms of the mode "Modern" fit into Godot's global shader buffer (RINT-B). The Compatibility renderer
## gives every geometry instance whose material has instance uniforms (vpbr, glass, the stand-in shaders) 16 slots of
## that buffer, and the buffer is only as large as the GPU's uniform block (64 KB = 4096 slots with llvmpipe and most
## desktop drivers): beyond about 250 such instances Godot refuses one ("Too many instances using shader instance
## variables") and draws it with the values of another. Pooled cars kept their levels, so a race with traffic ran past
## it within a few minutes (measured in RINT-B; layers/vehicles.gd INSTANCE_BUDGET is the cure).
## Render check (Xvfb – headless there is no buffer): tools/run_render_checks.sh modern runs it.
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tests/race3d/render/check_instance_budget.gd
## The player stands at km 2 of Kiel–Hamburg while the traffic streams past for SIM_S of view time (six times the
## speed, drawn at 480 x 270 – the buffer does not depend on the size of the picture). Every engine error passes
## through a Logger: none may be the refusal; after every frame the vehicles layer keeps its INSTANCE_BUDGET, and the
## instances with instance uniforms in the whole scene (counted every 60 frames) stay below SCENE_LIMIT, the margin
## for what other layers add.
## Prints "RENDER-CHECK instanzen OK|FEHLER …"; exit code 0 when it passes.

const RACE := "res://scenes/race/race.tscn"
const SIM_S := 100.0
const MAX_FRAMES := 1600
const TIME_SCALE := 6.0            ## view time per frame: 6/60 s (the runner fixes 60 fps)
const SCENE_LIMIT := 230            ## of about 250 (4096 slots / 16, less the global uniforms)
const REFUSAL := "Too many instances using shader instance variables"


class ErrorCatch extends Logger:
	var hits := 0
	var first := ""
	var _lock := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if (code + " " + rationale).contains(REFUSAL):
			_lock.lock()
			hits += 1
			if first == "":
				first = rationale if rationale != "" else code
			_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _catch := ErrorCatch.new()
var _sc: Node
var _frames := 0
var _t0 := -1.0
var _worst_layer := 0
var _worst_scene := 0
var _budget := 0
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK instanzen FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	OS.add_logger(_catch)
	root.size = Vector2i(480, 270)
	root.get_node("Settings").call("disarm_crash_guard")
	if _preset() != "":
		CliArgs.all()["gfx-preset"] = _preset()
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", _race_setup())
	root.add_child(_sc)


## The race of the check (check_instance_budget_wald.gd drives a forest stage instead).
func _race_setup() -> Dictionary:
	return {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}


## Quality preset of the run ("" = the one this machine picks).
func _preset() -> String:
	return ""


func _check_name() -> String:
	return "instanzen"


func _process(_dt: float) -> bool:
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		_frames += 1
		if _frames % 30 == 0:
			_worst_scene = maxi(_worst_scene, _scene_instances())
		return _frames > MAX_FRAMES and _finish()
	var r: Object = _sc.get("renderer")
	var vl: Object = r.call(&"layer", "vehicles")
	var view: Dictionary = r.get("view")
	if _t0 < 0.0:
		_t0 = float(view.get("time", 0.0))
		_budget = int((vl.get_script() as GDScript).get_script_constant_map().get("INSTANCE_BUDGET", 0))
		Engine.time_scale = TIME_SCALE
	_frames += 1
	var pf: Dictionary = vl.call(&"perf")
	_worst_layer = maxi(_worst_layer, int(pf.get("vehicle_instances", 0)))
	if _frames % 60 == 0:
		_worst_scene = maxi(_worst_scene, _scene_instances())
	if float(view.get("time", 0.0)) - _t0 >= SIM_S or _frames >= MAX_FRAMES:
		return _finish()
	return false


func _finish() -> bool:
	Engine.time_scale = 1.0
	OS.remove_logger(_catch)
	var p: Array[String] = []
	var sim_s := 0.0
	var trims := 0
	var builds := 0
	if _sc != null and _sc.get("renderer") != null and _t0 >= 0.0:
		var r: Object = _sc.get("renderer")
		sim_s = float((r.get("view") as Dictionary).get("time", 0.0)) - _t0
		var pf: Dictionary = (r.call(&"layer", "vehicles") as Object).call(&"perf")
		trims = int(pf.get("vehicle_trims", 0))
		builds = int(pf.get("vehicle_builds", 0))
	if _t0 < 0.0:
		p.append("das Rennen lief nicht an")
	if sim_s < SIM_S * 0.9:
		p.append("nur %.0f s Verkehr in %d Bildern" % [sim_s, _frames])
	if _catch.hits > 0:
		p.append("%d× „%s“" % [_catch.hits, _catch.first.left(90)])
	if _budget <= 0 or _worst_layer > _budget:
		p.append("Fahrzeug-Ebene höchstens %d Instanzen (%d)" % [_budget, _worst_layer])
	if _worst_scene > SCENE_LIMIT:
		p.append("ganze Szene höchstens %d Instanzen mit Instanz-Uniforms (%d)" % [SCENE_LIMIT, _worst_scene])
	var ok := p.is_empty()
	print("RENDER-CHECK %-14s %s  %s%s" % [_check_name(), "OK    " if ok else "FEHLER",
		"%.0f s Verkehr bei 6-facher Zeit (%d Bilder): keine Ablehnung der Engine, Fahrzeug-Ebene höchstens %d Instanzen (Budget %d, %d freigegeben, %d Bauten), ganze Szene höchstens %d mit Instanz-Uniforms (Grenze %d; %.0f s)" % [
			sim_s, _frames, _worst_layer, _budget, trims, builds, _worst_scene, SCENE_LIMIT, (Time.get_ticks_msec() - _wall0) / 1000.0],
		"" if ok else "  –  FEHLT: " + "; ".join(p)])
	quit(0 if ok else 1)
	return true


## Geometry instances whose material has instance uniforms, in the whole tree (what takes 16 slots each).
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
