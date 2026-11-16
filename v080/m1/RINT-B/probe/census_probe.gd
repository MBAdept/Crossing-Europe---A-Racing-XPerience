extends SceneTree
## Probe (RINT-B): how many geometry instances with instance uniforms (16 slots each in Godot's global shader
## buffer; 4096 slots with a 64 KB uniform block) a Modern race keeps alive – every 120 frames: per shader, per layer
## node (vehicles: active, pooled), the vehicles layer's perf(). Kiel–Hamburg, autopilot at 120 km/h, traffic warm-up.
## usage: ... -s <this> -- --graphics=modern [--frames=900] [--stage=kiel_hamburg] [--km=2]

const RACE := "res://scenes/race/race.tscn"

var _sc: Node
var _frames := 0
var _max := 900
var _stage := "kiel_hamburg"
var _from := "kiel"
var _km := 2.0
var _peak := 0
var _speed := 120.0
var _auto := true
var _warm := true
var _probe_r := false
var _hour := 12.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_max = int(a.substr(9))
		elif a.begins_with("--stage="):
			_stage = a.substr(8)
		elif a.begins_with("--from="):
			_from = a.substr(7)
		elif a.begins_with("--km="):
			_km = float(a.substr(5))
		elif a.begins_with("--speed="):
			_speed = float(a.substr(8))
		elif a == "--no-autopilot":
			_auto = false
		elif a == "--no-warmup":
			_warm = false
		elif a == "--probe-renderer":
			_probe_r = true
		elif a.begins_with("--timescale="):
			Engine.time_scale = float(a.substr(12))
		elif a.begins_with("--hour="):
			_hour = float(a.substr(7))
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": _stage, "from_city": _from, "vehicle": "limousine",
		"start_world_minutes": _hour * 60.0, "weather": "normal", "start_km": _km, "autopilot": _auto, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": _speed, "traffic_warmup": _warm}
	if _probe_r:
		var rr: GDScript = load("res://scripts/race/race_renderers.gd")
		rr.set("modern_script", "res://tests/race3d/fixtures/vehicle_probe_renderer.gd")
		(load("res://tests/race3d/fixtures/vehicle_probe_renderer.gd") as GDScript).set("hide_player", true)
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


var _load_frames := 0


func _process(_dt: float) -> bool:
	if _sc == null:
		return false
	if int(_sc.get("_sim_steps")) < 2:
		_load_frames += 1
		_census("load%d" % _load_frames)
		return false
	_frames += 1
	if _frames <= 5 or _frames % 120 == 1 or _frames >= _max:
		_census("f%d" % _frames)
	return _frames >= _max


func _census(tag: String) -> void:
	var by_shader := {}
	var total := 0
	var hidden := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is GeometryInstance3D):
			continue
		var gi := n as GeometryInstance3D
		var mats: Array = []
		if gi.material_override != null:
			mats.append(gi.material_override)
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mi := gi as MeshInstance3D
			for k in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(k)
				if m != null:
					mats.append(m)
		if gi is MultiMeshInstance3D and gi.material_override == null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null:
				for k in mm.mesh.get_surface_count():
					var m2: Material = mm.mesh.surface_get_material(k)
					if m2 != null:
						mats.append(m2)
		var key := ""
		for m in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				var sh := (m as ShaderMaterial).shader
				if sh.code.contains("instance uniform"):
					key = sh.resource_path.get_file()
					break
		if key == "":
			continue
		total += 1
		if not gi.is_visible_in_tree():
			hidden += 1
		by_shader[key] = int(by_shader.get(key, 0)) + 1
	_peak = maxi(_peak, total)
	var r: Object = _sc.get("renderer")
	var perf := {}
	if r != null:
		var vl: Object = r.call("layer", "vehicles")
		if vl != null and vl.has_method("perf"):
			perf = vl.call("perf")
	var cars := 0
	if r != null:
		cars = ((r.call("debug_snapshot") as Dictionary).get("vehicles", []) as Array).size()
	print("CENSUS %s total=%d hidden=%d peak=%d cars=%d %s pool=%s builds=%s veh_inst=%s trims=%s" % [tag, total, hidden, _peak, cars,
		JSON.stringify(by_shader), str(perf.get("vehicle_pool", "?")), str(perf.get("vehicle_builds", "?")),
		str(perf.get("vehicle_instances", "?")), str(perf.get("vehicle_trims", "?"))])
