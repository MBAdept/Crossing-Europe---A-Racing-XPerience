extends SceneTree
## QA-RINT-BILD perf driver (scratch only, never committed): drives a whole stage with the autopilot like
## tests/race/run_stage.gd and records EVERY frame: wall frame time, draw calls and primitives (visible and shadow
## pass) of the root viewport; every --sample-s seconds memory monitors (objects, nodes, orphans, texture/buffer/
## video memory, static memory, RSS). At the end: perf_stats() of the session and one JSON line "QAPERF {...}".
##   godot --path . --rendering-driver opengl3 ... -s res://qa_perf.gd -- --stage=… --graphics=modern --gfx-preset=deck
##       [--timescale=10] [--max-seconds=1500] [--sample-s=10] [--out=/abs/file.json] (+ run_stage args)

var _scene: Node
var _wall0 := 0
var _max_wall := 1500.0
var _done := false
var _last_us := 0
var _ft := PackedFloat32Array()
var _dc := PackedInt32Array()
var _pr := PackedInt32Array()
var _prs := PackedInt32Array()
var _dcs := PackedInt32Array()
var _mem: Array = []
var _sample_s := 10.0
var _next_sample := 0.0
var _out := ""
var _last_report := 0
var _skip := 0
var _inst_max := 0
var _inst_km := 0.0
var _inst_n := 0
var _inst_frame := 0
var _mat_iu := {}
var _spikes: Array = []
var _last_hmax := {}


func _initialize() -> void:
	var args := CliArgs.all()
	var c := ConfigLoader.load_merged()
	var ts := clampf(float(args.get("timescale", 40.0)), 0.1, 200.0)
	_max_wall = float(args.get("max-seconds", 1500.0))
	_sample_s = float(args.get("sample-s", 10.0))
	_out = str(args.get("out", ""))
	var setup := {
		"mode": "single", "race_id": "",
		"stage_id": str(args.get("stage", "kiel_hamburg")),
		"from_city": str(args.get("from", "")),
		"vehicle": str(args.get("vehicle", ConfigLoader.lookup(c, "vehicles.default", "limousine"))),
		"start_world_minutes": float(args.get("hour", 12.0)) * 60.0,
		"weather": str(args.get("weather", "normal")),
		"start_km": float(args.get("start-km", 0.0)),
		"autopilot": true, "autopilot_speeding": false,
		"autopilot_refuel": str(args.get("autopilot-refuel", "auto")),
		"no_countdown": true, "seed": int(args.get("seed", 7)),
	}
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", _on_finished)
	_scene.connect("stage_aborted", _on_aborted)
	root.add_child(_scene)
	_wall0 = Time.get_ticks_msec()
	print("QARUN-START ", JSON.stringify(setup), " timescale=", ts)


func _rss_mb() -> float:
	var out: Array = []
	OS.execute("grep", ["VmRSS", "/proc/%d/status" % OS.get_process_id()], out)
	if out.is_empty():
		return 0.0
	var t := str(out[0]).strip_edges()
	var parts := t.split(" ", false)
	return float(parts[1]) / 1024.0 if parts.size() >= 2 else 0.0


func _sample(wall: float) -> void:
	_mem.append({"wall_s": snappedf(wall, 0.1), "km": snappedf(float(_scene.get("pos_km")), 0.01),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.01),
		"buf_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.01),
		"vid_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		"rss_mb": snappedf(_rss_mb(), 0.1)})


func _process(_delta: float) -> bool:
	if _done:
		return true
	var now := Time.get_ticks_usec()
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	var gs: Variant = _scene.get("_gfx_state")
	var live: bool = gs == null or int(gs) == 0
	if _last_us > 0 and live:
		_skip += 1
		if _skip > 3:
			_ft.append(float(now - _last_us) / 1000.0)
			var vp := root.get_viewport_rid()
			_dc.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
			_pr.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
			_dcs.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
			_prs.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	_last_us = now
	_inst_frame += 1
	if _inst_frame % 10 == 0 and live:
		var ni := _scene_instances()
		_inst_n += 1
		if ni > _inst_max:
			_inst_max = ni
			_inst_km = float(_scene.get("pos_km"))
	if _inst_frame % 20 == 0 and live:
		_track_spikes()
	if wall >= _next_sample:
		_next_sample = wall + _sample_s
		_sample(wall)
	if int(wall) >= _last_report + 30:
		_last_report = int(wall)
		print("... km %.1f wall %.0f s frames %d" % [float(_scene.get("pos_km")), wall, _ft.size()])
	if wall > _max_wall:
		print("QA: Zeitlimit bei km %.2f" % float(_scene.get("pos_km")))
		_report(false)
		quit(0)
		return true
	return false


## Where the maxima of the renderer's hook times and of the chunk commit grow (km, wall): localises hitches.
func _track_spikes() -> void:
	var r: Variant = _scene.get("renderer")
	if r == null or not (r as Object).has_method("perf_stats"):
		return
	var p: Dictionary = (r as Object).call("perf_stats")
	var hm: Dictionary = (p.get("hooks_ms_max", {}) as Dictionary).duplicate()
	var st: Dictionary = p.get("streamer", {})
	hm["commit"] = float(st.get("commit_ms_max", 0.0))
	hm["collect"] = float(st.get("collect_ms_max", 0.0))
	for k: Variant in hm:
		var v := float(hm[k])
		if v > float(_last_hmax.get(k, 0.0)) + 0.5 and v >= 4.0:
			_spikes.append({"part": str(k), "ms": snappedf(v, 0.01), "km": snappedf(float(_scene.get("pos_km")), 0.01),
				"wall": snappedf(float(Time.get_ticks_msec() - _wall0) / 1000.0, 0.1)})
		_last_hmax[k] = maxf(v, float(_last_hmax.get(k, 0.0)))


func _scene_instances() -> int:
	var n := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		for c in x.get_children():
			stack.append(c)
		if not (x is GeometryInstance3D) or x.is_queued_for_deletion():
			continue
		if _uses_iu(x as GeometryInstance3D):
			n += 1
	return n


func _mat_has_iu(m: Material) -> bool:
	if m == null:
		return false
	var k := m.get_instance_id()
	if _mat_iu.has(k):
		return bool(_mat_iu[k])
	var r := m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.code.contains("instance uniform")
	_mat_iu[k] = r
	return r


func _uses_iu(gi: GeometryInstance3D) -> bool:
	if _mat_has_iu(gi.material_override):
		return true
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
		var mi := gi as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			if _mat_has_iu(mi.get_active_material(k)):
				return true
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
		var mesh := (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for k in mesh.get_surface_count():
				if _mat_has_iu(mesh.surface_get_material(k)):
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


func _q(a: Variant, q: float) -> float:
	if a.size() == 0:
		return 0.0
	var s: Array = Array(a)
	s.sort()
	return float(s[mini(s.size() - 1, int(float(s.size()) * q))])


func _stats(a: Variant) -> Dictionary:
	if a.size() == 0:
		return {}
	var sum := 0.0
	for v: Variant in a:
		sum += float(v)
	return {"avg": snappedf(sum / a.size(), 0.01), "p50": _q(a, 0.5), "p95": _q(a, 0.95), "p99": _q(a, 0.99),
		"max": _q(a, 1.0)}


func _report(ok: bool) -> void:
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	_sample(wall)
	var perf: Dictionary = _scene.call("perf_stats")
	var out := {"ok": ok, "wall_s": wall, "sim_s": float(_scene.get("stage_time")), "km": float(_scene.get("pos_km")),
		"frames": _ft.size(), "frame_ms": _stats(_ft), "draw_calls": _stats(_dc), "primitives": _stats(_pr),
		"draw_calls_shadow": _stats(_dcs), "primitives_shadow": _stats(_prs), "mem": _mem}
	out["perf"] = perf
	out["iu_instances_max"] = _inst_max
	out["iu_instances_km"] = _inst_km
	out["iu_samples"] = _inst_n
	out["spikes"] = _spikes
	var js := JSON.stringify(out)
	print("QAPERF ", js)
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		if f != null:
			f.store_string(js)
			f.close()
