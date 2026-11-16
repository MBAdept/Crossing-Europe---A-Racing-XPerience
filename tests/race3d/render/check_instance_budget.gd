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
## Prints "RENDER-CHECK instanzen OK|FEHLER …" with the wall time of the two phases (loading until the first
## simulation step, then the drive); exit code 0 when it passes. Subclasses set their own view time (_sim_s()).
## RINT-M2 (A-19, NACH-M2 N-02): a subclass may fill the vehicle budget from the first picture on (_inject_n() test cars
## through tests/race3d/fixtures/vehicle_probe_renderer.gd, kept in view at distances that sweep 20–540 m so every car
## builds its levels) – then the vehicle layer must reach at least LOADED_SHARE of INSTANCE_BUDGET, or the check says it
## was not loaded (FEHLER): only so does it check the whole scene WITH a full vehicle budget (forest, city finish).

const RACE := "res://scenes/race/race.tscn"
const SIM_S := 100.0
const MAX_FRAMES := 1600
const TIME_SCALE := 6.0            ## view time per frame: 6/60 s (the runner fixes 60 fps)
const SCENE_LIMIT := 230            ## of about 250 (4096 slots / 16, less the global uniforms)
const REFUSAL := "Too many instances using shader instance variables"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const LOADED_SHARE := 0.9           ## injected traffic: the vehicle layer reaches at least this share of its budget
## injected traffic: the sets the test cars cycle through (cars, vans, trucks, bus, police: every vehicle class)
const INJECT_SETS: Array = ["traffic/hatch_red", "traffic/sedan_silver", "traffic/suv_white", "traffic/van_white",
	"traffic/truck_red", "traffic/bus_blue", "police/de", "traffic/sports_yellow", "traffic/wagon_darkblue",
	"traffic/hatch_white", "traffic/wagon_white", "traffic/wagon_silver"]


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
var _wall_live := -1               ## wall clock (ms) when the race ran its first steps: end of the loading phase
var _probe: GDScript               ## the probe renderer when the check injects traffic (_inject_n() > 0)


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
	if _inject_n() > 0:
		_probe = load(PROBE)
		load("res://scripts/race/race_renderers.gd").set("modern_script", PROBE)
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", _race_setup())
	root.add_child(_sc)


## The race of the check (check_instance_budget_wald.gd drives a forest stage instead).
func _race_setup() -> Dictionary:
	return {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}


## View time of the drive in seconds (SIM_S; check_instance_budget_wald.gd drives less – its forest is there from the
## first picture, FIX-M2 / QA-M2-SYSTEM M2S-01).
func _sim_s() -> float:
	return SIM_S


## Quality preset of the run ("" = the one this machine picks).
func _preset() -> String:
	return ""


## Test cars kept in view from the start (0 = only the stage's own traffic) – see the header.
func _inject_n() -> int:
	return 0


## The injected cars of this frame: distances sweep 20–540 m with the view time (each car crosses every level of
## detail), three lanes, the sets of INJECT_SETS in turn.
func _inject(view: Dictionary, t: float) -> void:
	var cam_z := float(view.get("camera_z", 0.0))
	var pl: Variant = view.get("player", {})
	var px := float((pl as Dictionary).get("x", 0.0)) if pl is Dictionary else 0.0
	var cars: Array = []
	for i in _inject_n():
		var set_id: String = INJECT_SETS[i % INJECT_SETS.size()]
		var d := 20.0 + fmod(float(i) * 37.0 + t * 26.0, 520.0)
		cars.append({"kind": "car", "id": 9700 + i, "set": set_id, "z": cam_z + d, "x": px + 3.75 * float(i % 3 - 1),
			"length": float(ModelDB.object_size(set_id).get("length_m", 4.7)), "tail": 0.0, "brake": 0.0, "speed": 0.0,
			"blink": 0, "blink_t": 0.0, "heavy": set_id.contains("truck") or set_id.contains("bus")})
	_probe.set("inject", cars)


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
		_wall_live = Time.get_ticks_msec()
		_budget = int((vl.get_script() as GDScript).get_script_constant_map().get("INSTANCE_BUDGET", 0))
		Engine.time_scale = TIME_SCALE
	_frames += 1
	if _probe != null:
		_inject(view, float(view.get("time", 0.0)) - _t0)
	var pf: Dictionary = vl.call(&"perf")
	_worst_layer = maxi(_worst_layer, int(pf.get("vehicle_instances", 0)))
	if _frames % 60 == 0:
		_worst_scene = maxi(_worst_scene, _scene_instances())
	if float(view.get("time", 0.0)) - _t0 >= _sim_s() or _frames >= MAX_FRAMES:
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
	if sim_s < _sim_s() * 0.9:
		p.append("nur %.0f s Verkehr in %d Bildern" % [sim_s, _frames])
	if _catch.hits > 0:
		p.append("%d× „%s“" % [_catch.hits, _catch.first.left(90)])
	if _budget <= 0 or _worst_layer > _budget:
		p.append("Fahrzeug-Ebene höchstens %d Instanzen (%d)" % [_budget, _worst_layer])
	if _probe != null:
		_probe.call("reset")
		load("res://scripts/race/race_renderers.gd").set("modern_script", "res://scripts/race3d/modern_renderer.gd")
		if _worst_layer < int(ceil(float(_budget) * LOADED_SHARE)):
			p.append("Fahrzeug-Ebene nicht belastet: %d von %d Instanzen (verlangt %.0f %%)" % [_worst_layer, _budget, LOADED_SHARE * 100.0])
	if _worst_scene > SCENE_LIMIT:
		p.append("ganze Szene höchstens %d Instanzen mit Instanz-Uniforms (%d)" % [SCENE_LIMIT, _worst_scene])
	var ok := p.is_empty()
	var now := Time.get_ticks_msec()
	var load_s := float((_wall_live if _wall_live >= 0 else now) - _wall0) / 1000.0
	var drive_s := float(now - _wall_live) / 1000.0 if _wall_live >= 0 else 0.0
	print("RENDER-CHECK %-14s %s  %s%s" % [_check_name(), "OK    " if ok else "FEHLER",
		"%.0f s Verkehr bei 6-facher Zeit (%d Bilder%s): keine Ablehnung der Engine, Fahrzeug-Ebene höchstens %d Instanzen (Budget %d, %d freigegeben, %d Bauten), ganze Szene höchstens %d mit Instanz-Uniforms (Grenze %d; Laden %.0f s, Fahrt %.0f s)" % [
			sim_s, _frames, ", %d eingespeiste Autos" % _inject_n() if _inject_n() > 0 else "", _worst_layer, _budget, trims, builds,
			_worst_scene, SCENE_LIMIT, load_s, drive_s],
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
