extends SceneTree
## QA-BILD probe: drives a stage with the autopilot in one graphics mode and records per-frame timings and memory.
## Run under Xvfb (counters) or headless:
##   godot --path . --rendering-driver opengl3 ... -s <this> -- --graphics=modern --gfx-preset=medium \
##       --stage=kiel_hamburg --from=kiel [--vehicle=limousine] [--hour=12] [--weather=normal] [--seed=11] [--start-km=0]
##       [--timescale=1] [--max-steps=8] [--max-wall=900] [--sample=5] [--out=<prefix>] [--quit-km=<km>] [--quit-sim=<s>]
## Writes <prefix>_frames.csv (one line per drawn frame after the stage went live), <prefix>_samples.jsonl and prints
## "QA-SUMMARY {...}", "PERF {...}" (session perf_stats) and "ERGEBNIS {...}" when the stage finishes.

var _scene: Node
var _args := {}
var _mode := "modern"
var _out := ""
var _wall0 := 0
var _max_wall := 900.0
var _sample_s := 5.0
var _next_sample := 0.0
var _quit_km := -1.0
var _quit_sim := -1.0
var _done := false
var _live_t0 := -1
var _added_ms := 0
var _live_ms := -1
var _last_us := 0
var _prev_render_us := 0
var _prev_commits := 0
var _frames_f: FileAccess
var _samples_f: FileAccess
var _frame_ms: PackedFloat32Array = []
var _render_ms: PackedFloat32Array = []
var _commit_frames: PackedInt32Array = []
var _n := 0
var _mem0 := {}


func _initialize() -> void:
	_args = CliArgs.all()
	_mode = str(_args.get("graphics", "modern"))
	var ts := clampf(float(_args.get("timescale", 1.0)), 0.1, 200.0)
	_max_wall = float(_args.get("max-wall", 900.0))
	_sample_s = float(_args.get("sample", 5.0))
	_quit_km = float(_args.get("quit-km", -1.0))
	_quit_sim = float(_args.get("quit-sim", -1.0))
	_out = str(_args.get("out", "/tmp/qa_drive"))
	var setup := {
		"mode": "single", "race_id": "", "stage_id": str(_args.get("stage", "kiel_hamburg")),
		"from_city": str(_args.get("from", "")), "vehicle": str(_args.get("vehicle", "limousine")),
		"start_world_minutes": float(_args.get("hour", 12.0)) * 60.0, "weather": str(_args.get("weather", "normal")),
		"start_km": float(_args.get("start-km", 0.0)), "autopilot": true,
		"autopilot_refuel": str(_args.get("autopilot-refuel", "auto")), "no_countdown": true,
		"seed": int(_args.get("seed", 11)), "gfx": _mode,
	}
	if _args.has("start-speed"):
		setup["start_speed_kmh"] = float(_args.get("start-speed", 0.0))
	if _args.has("traffic-warmup"):
		setup["traffic_warmup"] = true
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = int(_args.get("max-steps", clampi(int(ceil(ts)) * 2, 8, 128)))
	root.get_node("Settings").call("disarm_crash_guard")
	_frames_f = FileAccess.open(_out + "_frames.csv", FileAccess.WRITE)
	_frames_f.store_line("frame,t_wall_s,frame_ms,render_ms,commit,km,sim_s,process_ms")
	_samples_f = FileAccess.open(_out + "_samples.jsonl", FileAccess.WRITE)
	# QA-M2-BILD: --chain=<stage>:<from>,… drives these stages after the first one in the same process (leak check)
	for e: String in str(_args.get("chain", "")).split(",", false):
		_chain.append(e)
	_setup0 = setup
	_wall0 = Time.get_ticks_msec()
	_start_stage(setup)


var _chain: Array = []
var _setup0 := {}
var _stage_no := 0


func _start_stage(setup: Dictionary) -> void:
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", _on_finished)
	_scene.connect("stage_aborted", _on_aborted)
	root.add_child(_scene)
	_added_ms = Time.get_ticks_msec()
	_live_ms = -1
	_stage_no += 1
	print("QA-STAGE %d %s from %s" % [_stage_no, str(setup["stage_id"]), str(setup["from_city"])])
	print("QA-START ", JSON.stringify(setup), " timescale=", ts, " max_steps=", Engine.max_physics_steps_per_frame)


static func _rss_mb() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	for _i in 80:
		var line := f.get_line()
		if line.begins_with("VmRSS:"):
			var parts := line.replace("\t", " ").split(" ", false)
			return float(parts[1]) / 1024.0
		if f.eof_reached():
			break
	return -1.0


static func _load1() -> float:
	var f := FileAccess.open("/proc/loadavg", FileAccess.READ)
	if f == null:
		return -1.0
	var parts := f.get_line().split(" ", false)
	return float(parts[0]) if parts.size() > 0 else -1.0


func _renderer() -> Object:
	var r: Variant = _scene.get("renderer")
	return r if r is Object else null


func _sample(wall: float) -> void:
	var r := _renderer()
	var ps: Dictionary = {}
	if r != null and r.has_method("perf_stats"):
		ps = r.call("perf_stats")
	var s := {
		"t": snappedf(wall, 0.01), "km": snappedf(float(_scene.get("pos_km")), 0.01),
		"sim_s": snappedf(float(_scene.get("stage_time")), 0.01),
		"rss_mb": snappedf(_rss_mb(), 0.1), "load1": _load1(),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buf_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1),
		"vid_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"draw_calls": ps.get("draw_calls", -1), "primitives": ps.get("primitives", -1),
		"chunks": ps.get("chunks", -1), "instances": ps.get("instances", -1), "vehicles": ps.get("vehicles", -1),
		"vehicle_instances": ps.get("vehicle_instances", -1), "flares": ps.get("flares", -1),
		"lights_omni": ps.get("lights_omni", -1), "lights_spot": ps.get("lights_spot", -1),
		"render_ms_avg": ps.get("render_ms_avg", -1), "render_ms_max": ps.get("render_ms_max", -1),
		"commit_ms_max": ps.get("chunk_commit_ms_max", -1), "contact_shadows": ps.get("contact_shadows", -1),
		"standin_cars": ps.get("standin_cars", -1), "stage": _stage_no,
	}
	_samples_f.store_line(JSON.stringify(s))
	_samples_f.flush()


func _process(_delta: float) -> bool:
	if _done:
		return true
	if _scene == null or not is_instance_valid(_scene) or not _scene.is_inside_tree():
		return false
	var now_us := Time.get_ticks_usec()
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	if _live_ms < 0 and bool(_scene.call("is_live")):
		_live_ms = Time.get_ticks_msec()
		print("QA-LIVE load_s=%.3f" % (float(_live_ms - _added_ms) / 1000.0))
		_last_us = now_us
		var r0 := _renderer()
		if r0 != null:
			var v0: Variant = r0.get("_render_us")
			_prev_render_us = int(v0) if v0 != null else 0
		_next_sample = wall
		_sample(wall)
		return false
	if _live_ms < 0:
		return false
	var fms := float(now_us - _last_us) / 1000.0
	_last_us = now_us
	var rms := -1.0
	var commit := 0
	var r := _renderer()
	if r != null:
		var v: Variant = r.get("_render_us")
		if v != null:
			rms = float(int(v) - _prev_render_us) / 1000.0
			_prev_render_us = int(v)
		var st: Variant = r.get("streamer")
		if st is Object and (st as Object).has_method("stats"):
			var c := int(((st as Object).call("stats") as Dictionary).get("commits", 0))
			commit = c - _prev_commits
			_prev_commits = c
	var km := float(_scene.get("pos_km"))
	var sim := float(_scene.get("stage_time"))
	_frames_f.store_line("%d,%.3f,%.3f,%.3f,%d,%.3f,%.3f,%.3f" % [_n, wall, fms, rms, commit, km, sim,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	if rms > float(_args.get("spike-ms", 40.0)) and r != null and r.has_method("perf_stats"):
		# which hook peaked: the *_us_max / *_ms_max keys of the merged perf dictionary
		var ps: Dictionary = r.call("perf_stats")
		var peaks := {}
		for k: String in ps.keys():
			if k.ends_with("_us_max") or k.ends_with("_ms_max"):
				peaks[k] = ps[k]
		print("QA-SPIKE frame=%d render_ms=%.1f km=%.3f sim=%.2f commit=%d %s" % [_n, rms, km, sim, commit, JSON.stringify(peaks)])
	_n += 1
	_frame_ms.append(fms)
	_render_ms.append(rms)
	if commit > 0:
		_commit_frames.append(_n - 1)
	if wall >= _next_sample:
		_next_sample = wall + _sample_s
		_sample(wall)
	if (_quit_km > 0.0 and km >= _quit_km) or (_quit_sim > 0.0 and sim >= _quit_sim):
		_summary(true, "quit")
		_done = true
		quit(0)
		return true
	if wall > _max_wall:
		_summary(false, "timeout")
		_done = true
		quit(1)
		return true
	return false


static func _pct(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(floor(p * float(b.size() - 1))), 0, b.size() - 1)]


func _summary(ok: bool, why: String) -> void:
	_sample(float(Time.get_ticks_msec() - _wall0) / 1000.0)
	_frames_f.flush()
	var med := _pct(_frame_ms, 0.5)
	var spikes := 0
	var spikes_commit := 0
	var commit_set := {}
	for i in _commit_frames:
		commit_set[i] = true
	for i in _frame_ms.size():
		if _frame_ms[i] > 3.0 * med:
			spikes += 1
			if commit_set.has(i):
				spikes_commit += 1
	var rc: PackedFloat32Array = []
	var rn: PackedFloat32Array = []
	for i in _render_ms.size():
		if commit_set.has(i):
			rc.append(_render_ms[i])
		else:
			rn.append(_render_ms[i])
	var s := {"ok": ok, "why": why, "mode": _mode, "frames": _n,
		"load_s": float(_live_ms - _added_ms) / 1000.0 if _live_ms > 0 else -1.0,
		"frame_ms_p50": med, "frame_ms_p95": _pct(_frame_ms, 0.95), "frame_ms_p99": _pct(_frame_ms, 0.99),
		"frame_ms_max": _pct(_frame_ms, 1.0), "spikes_3x": spikes, "spikes_3x_on_commit": spikes_commit,
		"commit_frames": _commit_frames.size(),
		"render_ms_p50": _pct(_render_ms, 0.5), "render_ms_p95": _pct(_render_ms, 0.95),
		"render_ms_p99": _pct(_render_ms, 0.99), "render_ms_max": _pct(_render_ms, 1.0),
		"render_ms_commit_p50": _pct(rc, 0.5), "render_ms_commit_p95": _pct(rc, 0.95), "render_ms_commit_max": _pct(rc, 1.0),
		"render_ms_nocommit_p50": _pct(rn, 0.5), "render_ms_nocommit_p95": _pct(rn, 0.95),
		"km": float(_scene.get("pos_km")), "sim_s": float(_scene.get("stage_time")),
		"wall_s": float(Time.get_ticks_msec() - _wall0) / 1000.0}
	print("QA-SUMMARY ", JSON.stringify(s))
	print("PERF ", JSON.stringify(_scene.call("perf_stats")))


func _on_finished(result: Dictionary) -> void:
	print("ERGEBNIS ", JSON.stringify(result))
	if not _chain.is_empty():
		var nxt := str(_chain.pop_front()).split(":")
		print("PERF-STAGE ", JSON.stringify(_scene.call("perf_stats")))
		_sample(float(Time.get_ticks_msec() - _wall0) / 1000.0)
		var old := _scene
		_scene = null
		old.queue_free()
		var s2 := _setup0.duplicate(true)
		s2["stage_id"] = nxt[0]
		s2["from_city"] = nxt[1] if nxt.size() > 1 else ""
		_next_stage.call_deferred(s2)
		return
	_summary(true, "finished")
	_done = true
	quit(0)


func _next_stage(s2: Dictionary) -> void:
	await process_frame
	await process_frame
	_start_stage(s2)


func _on_aborted(reason: String) -> void:
	print("FEHLER: Etappe abgebrochen: ", reason)
	_summary(false, "aborted")
	_done = true
	quit(1)
