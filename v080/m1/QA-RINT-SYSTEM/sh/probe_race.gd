extends SceneTree
## QA-RINT-SYSTEM robustness probe (Xvfb). Starts the race scene like a player start (countdown on unless --nocd),
## runs until --run-s seconds of stage time after the countdown (or --wall-s wall seconds), then prints:
##   PROBE start_renderer, end_renderer, gfx, gfx_fallback, gfx_lowered, aspect, marker before/after, messages,
##   perf (watchdog*, preset, …), errors (engine errors/warnings caught by a Logger) and saves a screenshot.
## Args (after --): --stage --km --hour --weather --vehicle --seed --gfx=<setup.gfx or empty> --run-s --wall-s
##   --shot=<png> --nocd --autopilot ; quality and debug flags go through the normal CLI (--gfx-preset, --gfx-debug …).

class Catch extends Logger:
	var lines: Array = []
	var warn := 0
	var err := 0
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		_m.lock()
		if error_type == 1:
			warn += 1
		else:
			err += 1
		if lines.size() < 40:
			lines.append("%s %s:%d %s %s" % ["WARN" if error_type == 1 else "ERR", file.get_file(), line, code, rationale])
		_m.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error:
			_m.lock()
			err += 1
			if lines.size() < 40:
				lines.append("MSGERR " + message.strip_edges())
			_m.unlock()


var _c := Catch.new()
var _sc: Node
var _args := {}
var _wall0 := 0
var _messages: Array = []
var _start_renderer := ""
var _marker_path := ""
var _marker_seen := false
var _done := false
var _shot := ""


func _arg(k: String, d: Variant) -> Variant:
	return _args.get(k, d)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	OS.add_logger(_c)
	_wall0 = Time.get_ticks_msec()
	_shot = str(_arg("shot", ""))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(_arg("stage", "kiel_hamburg")), "from_city": str(_arg("from", "")),
		"vehicle": str(_arg("vehicle", "limousine")), "start_world_minutes": float(_arg("hour", 12.0)) * 60.0,
		"weather": str(_arg("weather", "normal")), "start_km": float(_arg("km", 2.0)), "autopilot": _args.has("autopilot"),
		"no_countdown": _args.has("nocd"), "seed": int(_arg("seed", 3))}
	if str(_arg("gfx", "")) != "":
		setup["gfx"] = str(_arg("gfx", ""))
	var settings := root.get_node("Settings")
	_marker_path = str(settings.get("marker_path")) if "marker_path" in settings else ""
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	print("PROBE-START ", JSON.stringify(setup), " args=", JSON.stringify(_args))


func _renderer_file() -> String:
	var r: Variant = _sc.get("renderer")
	if r == null or not (r is Object) or (r as Object).get_script() == null:
		return ""
	return str(((r as Object).get_script() as Script).resource_path).get_file()


func _process(_dt: float) -> bool:
	if _done:
		return true
	if _start_renderer == "":
		_start_renderer = _renderer_file()
	if _marker_path != "" and FileAccess.file_exists(_marker_path):
		_marker_seen = true
	var hud: Object = _sc.get("hud")
	if hud != null:
		for m: Dictionary in hud.get("_messages"):
			var t := str(m["text"])
			if not _messages.has(t):
				_messages.append(t)
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	var st := float(_sc.get("stage_time"))
	var cd_over := bool(_sc.get("running"))
	if (cd_over and st >= float(_arg("run-s", 3.0))) or wall > float(_arg("wall-s", 600.0)):
		_finish(wall, st)
		return true
	return false


func _finish(wall: float, st: float) -> void:
	_done = true
	if _shot != "":
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png(_shot)
	var perf: Dictionary = _sc.call("perf_stats")
	var keep := {}
	for k: String in perf:
		if str(k).begins_with("watchdog") or k in ["mode", "preset", "chunks", "draw_calls", "primitives", "tex_mem_mb",
				"frame_ms_median", "frame_ms_p95", "prewarm_ms", "fallback_sets", "lights_omni", "lights_spot", "render_ms_avg", "render_ms_max", "particles", "spray_puffs", "quality_lowered", "draw_calls_shadow", "primitives_shadow"]:
			keep[k] = perf[k]
	var r: Variant = _sc.get("renderer")
	var levels: Variant = (r as Object).get("levels") if r is Object and "levels" in (r as Object) else null
	print("PROBE ", JSON.stringify({"start_renderer": _start_renderer, "end_renderer": _renderer_file(),
		"gfx": str(_sc.get("gfx")), "gfx_fallback": str(_sc.get("gfx_fallback")) if "gfx_fallback" in _sc else "",
		"gfx_lowered": str(_sc.get("gfx_lowered")) if "gfx_lowered" in _sc else "", "aspect": int(root.content_scale_aspect),
		"marker_seen": _marker_seen, "marker_now": _marker_path != "" and FileAccess.file_exists(_marker_path),
		"wall_s": wall, "stage_time": st, "running": bool(_sc.get("running")), "speed": float((_sc.get("vehicle") as Object).get("speed")),
		"messages": _messages, "perf": keep,
		"tex_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"buffer_mem_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"streamer": (perf.get("streamer", {}) as Dictionary).duplicate() if perf.get("streamer") is Dictionary else {},
		"hooks_ms_max": perf.get("hooks_ms_max", {}), "chunk_commit_ms_max": perf.get("chunk_commit_ms_max", -1.0),
		"gfx_lowered_perf": perf.get("quality_lowered", "")}))
	if levels is Dictionary:
		print("PROBE-LEVELS ", JSON.stringify(levels))
	print("PROBE-ERRORS err=%d warn=%d" % [_c.err, _c.warn])
	for l in _c.lines:
		print("  ", l)
	quit(0)
