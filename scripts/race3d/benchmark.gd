class_name ModernBenchmark
extends Node
## Leistungstest of the graphics mode "Modern" (v0.8.0, docs/dev/v080_contract.md §4.8, docs/grafik-modi.md): drives
## the fixed scenes of config graphics.benchmark.scenes – the real race scene with setup.gfx = "modern", the
## autopilot and a fixed traffic seed, graphics.benchmark.seconds (20) each – with whatever Modern renderer the build
## contains, measures every frame and returns one result dictionary, which is also written to
## user://leistungstest.json (and to out_path / --bench-out=<file>). The player runs it from the options (GRAFIK,
## "Leistungstest") or with --bench=<scene id,…|all>; on a Steam Deck or a Windows PC it is the only way to learn
## what the real graphics hardware does – nothing of that can be measured on the build machine.
##
##   var bench: Node = load("res://scripts/race3d/benchmark.gd").new()      # never preload: an Arcade start
##   bench.host = GameFlow            # whoever shows the race scene: start_attract_stage(setup) -> Node
##   add_child(bench); bench.finished.connect(…); bench.start([])           # [] = every scene
##
## What is measured, per scene: the stage is started, prepared by the renderer behind its loading picture (not
## measured) and goes live (RaceSession.is_live()); SETTLE_S later the window of `seconds` begins. Every frame's
## wall-clock duration is recorded (Time.get_ticks_usec between two _process calls) – V-Sync and the frame cap are
## switched off for the test, so the numbers show what the machine can do, not the display's refresh rate
## (where the window system allows it; "refresh_hz" and "vsync" are in the result). From the frames: average and
## 1 %-low fps, median / 95th / 99th percentile of the frame time (Gfx.frame_stats). From the renderer's
## perf_stats(), sampled four times a second: GDScript time of render() over the window ("script_ms"), draw calls
## and primitives including the shadow passes; next to them the engine's totals of the whole frame (HUD included).
## From all scenes: the verdict and a suggested preset (Gfx.bench_suggestion – the slowest scene decides).
##
## Fallback: when the session cannot draw the scene in Modern (render self-test failed, model manifest broken, the
## renderer cannot be created) it falls back to Arcade by itself; the test then ends at once with "fallback":
## <reason>, no scenes and "suggested_mode": "arcade" – and still writes the file (that IS the result for this
## machine). Esc / gamepad B, a lost window focus (the race pauses) or a scene that never goes live end the test
## with "aborted" / "error"; nothing is written then.
##
## Result (version 1; keys of the contract first, then additions):
##   {"version": 1, "date", "adapter", "api", "tier", "preset", "quality": {shadows, details, scale, aa, effects},
##    "resolution": [w, h], "scenes": [{"id", "avg_fps", "low1_fps", "frame_ms_p95", "frame_ms_p99", "script_ms",
##    "draw_calls", "primitives", + "name", "frames", "seconds", "frame_ms_median", "frame_ms_max",
##    "draw_calls_shadow", "primitives_shadow", "frame_draw_calls", "frame_primitives", "sim_ms", "prepare_s",
##    "video_mem_mb"}], "suggested_preset",
##    + "suggested_mode", "verdict", "worst_scene", "headroom", "target_ms", "refresh_hz", "vsync", "seconds",
##    "game_version", "os", "cpu", "cpu_threads", "vendor", "driver", "renderer_stub", "fallback", "aborted", "error"}
## Nothing here feeds back into the simulation (Rule 3); the sound profile is not read (Rule 4).

signal progress(scene_id: String, p01: float)   ## p01 = progress of the whole test, 0..1
signal finished(result: Dictionary)

const RACE_SCENE := "res://scenes/race/race.tscn"
const RESULT_FILE := "user://leistungstest.json"
const FORMAT_VERSION := 1
const SETTLE_S := 1.0            ## after the stage went live: late loads and the first frames are not measured
const PREPARE_MAX_S := 120.0     ## a scene that is not live after this long ends the test ("timeout")
const COUNTER_EVERY_S := 0.25    ## renderer counters are sampled this often
const MIN_SECONDS := 0.1

enum Phase { IDLE, PREPARING, SETTLING, MEASURING }

var host: Node = null                ## shows the race scene (start_attract_stage(setup) -> Node); null: this node does
var seconds_override := -1.0         ## seconds per scene instead of the configuration (tests)
var out_path := ""                   ## a second result file (--bench-out); "" = only RESULT_FILE
var result_file := RESULT_FILE       ## tests write elsewhere
var result: Dictionary = {}
var running := false
var phase := Phase.IDLE
var scene_index := -1                ## scene being driven (overlay: "Szene 2 von 3")
var scene_count := 0
var scene_name := ""

var _cfg: Dictionary = {}
var _scenes: Array[Dictionary] = []
var _seconds := 20.0
var _scene: Node = null
var _own_scene := false              ## this node added the scene to the tree itself (no host)
var _phase_t0 := 0                   ## ticks (µs) when the phase began
var _last_us := 0
var _frame_ms := PackedFloat32Array()
var _perf0: Dictionary = {}
var _counters: Dictionary = {}       ## key -> [sum, samples, max]
var _next_counter_us := 0
var _prepare_s := 0.0
var _scene_over := false             ## the scene's stage finished or was aborted inside the window
var _results: Array = []
var _vsync_before := -1
var _max_fps_before := -1
var _settled := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # a race that pauses itself (focus lost) must not freeze the test


## Starts the test with the scenes whose ids are listed ([] = all, in the order of the configuration). The result
## comes with `finished` – at once (next frame) when there is nothing to run.
func start(scene_ids: Array = []) -> void:
	if running:
		return
	running = true
	_cfg = _config()
	var b: Variant = ConfigLoader.lookup(_cfg, "graphics.benchmark", {})
	var bc: Dictionary = b if b is Dictionary else {}
	_seconds = float(bc.get("seconds", 20.0))
	if CliArgs.has("bench-seconds"):
		_seconds = CliArgs.get_float("bench-seconds", _seconds)
	if seconds_override > 0.0:
		_seconds = seconds_override
	_seconds = maxf(MIN_SECONDS, _seconds)
	if out_path == "" and CliArgs.has("bench-out"):
		out_path = CliArgs.get_string("bench-out", "")
	_scenes = select_scenes(bc.get("scenes", []), scene_ids)
	scene_count = _scenes.size()
	_results = []
	result = header()
	result["seconds"] = _seconds
	if _scenes.is_empty():
		_end.call_deferred({"error": "no_scene"})
		return
	_unthrottle()
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method(&"set_music"):
		am.call(&"set_music", false)   # as in a stage: no menu music over the engine
		am.call(&"stop_all")
	_next_scene()


## Ends the test without a result (Esc / B, the window lost its focus).
func abort(reason: String = "user") -> void:
	if running:
		_end({"aborted": true, "error": reason})


## The scenes of the configuration that are listed in `ids` ([] = all usable ones), in the configuration's order.
static func select_scenes(raw: Variant, ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for s: Variant in raw:
			if s is Dictionary and str((s as Dictionary).get("stage", "")) != "" \
					and (ids.is_empty() or ids.has(str((s as Dictionary).get("id", "")))):
				out.append(s)
	return out


## Race session setup of a scene (as an attract demo's: autopilot without refuelling and speeding, no countdown,
## traffic already spread, flying start) – in the mode "Modern", whatever the player has chosen.
static func scene_setup(scene: Dictionary, cfg: Dictionary) -> Dictionary:
	var s := {
		"mode": "demo", "demo": true, "bench": true, "race_id": "",
		"stage_id": str(scene.get("stage", "")), "from_city": str(scene.get("from", "")),
		"vehicle": str(scene.get("vehicle", ConfigLoader.lookup(cfg, "vehicles.default", "limousine"))),
		"start_world_minutes": float(scene.get("hour", 12.0)) * 60.0, "weather": str(scene.get("weather", "normal")),
		"start_km": float(scene.get("km", 0.0)), "autopilot": true,
		"autopilot_target": float(scene.get("cruise_kmh", 180.0)), "autopilot_speeding": false,
		"autopilot_refuel": "never", "no_countdown": true, "traffic_warmup": true, "seed": int(scene.get("seed", 0)),
		"start_speed_kmh": clampf(float(scene.get("speed_kmh", scene.get("cruise_kmh", 120.0))), 0.0, 300.0),
		"gfx": Gfx.MODERN,
	}
	if scene.has("lane"):
		s["start_lane"] = int(scene["lane"])
	return s


## The part of the result that describes machine and settings (everything but the scenes and the suggestion).
func header() -> Dictionary:
	var settings := get_node_or_null("/root/Settings")
	var q: Dictionary = settings.call("quality") if settings != null else Gfx.quality("medium", {}, {})
	var tier := str(settings.call("adapter_tier")) if settings != null else "ok"
	var quality := {}
	for k in Gfx.QUALITY_KEYS:
		quality[k] = int(q.get(k, 0))
	var size := Vector2i.ZERO
	var refresh := -1.0
	var vsync := false
	if DisplayServer.get_name() != "headless":
		size = DisplayServer.window_get_size()
		refresh = DisplayServer.screen_get_refresh_rate()
		if not is_finite(refresh) or refresh <= 0.0:
			refresh = -1.0   # unknown (Xvfb answers NaN – JSON has no NaN): judged against 60 Hz
		vsync = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	elif is_inside_tree():
		size = Vector2i(get_tree().root.size)
	return {
		"version": FORMAT_VERSION,
		"date": Time.get_datetime_string_from_system(false, true),
		"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"tier": tier,
		"preset": str(q.get("preset", "")),
		"quality": quality,
		"resolution": [size.x, size.y],
		"scenes": [],
		"suggested_preset": str(q.get("preset", "")),
		"suggested_mode": Gfx.MODERN,
		"verdict": "",
		"refresh_hz": snappedf(refresh, 0.01),
		"target_ms": snappedf(Gfx.target_ms_for_refresh(refresh), 0.001),
		"vsync": vsync,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"os": OS.get_name() + (" (" + OS.get_distribution_name() + ")" if OS.get_distribution_name() != "" and OS.get_distribution_name() != OS.get_name() else ""),
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"fallback": "",
		"aborted": false,
		"error": "",
	}


func _config() -> Dictionary:
	var c := get_node_or_null("/root/Config")
	var d: Variant = c.get("data") if c != null else null
	return d if d is Dictionary else ConfigLoader.load_merged()


# --- one scene after the other -------------------------------------------------------------------------

func _next_scene() -> void:
	scene_index += 1
	if scene_index >= _scenes.size():
		_end({})
		return
	var sc := _scenes[scene_index]
	scene_name = str(sc.get("name", sc.get("id", "")))
	var setup := scene_setup(sc, _cfg)
	_scene_over = false
	_settled = false
	_frame_ms = PackedFloat32Array()
	_counters = {}
	_scene = _show_scene(setup)
	if _scene == null or _scene.get("plan") == null:
		_end({"error": "scene:" + str(sc.get("id", ""))})
		return
	for c in _scene.get_children():
		if c is Screenshotter:
			c.queue_free()   # a --screenshot run is captured by the host's Screenshotter, not one per scene
	if _scene.has_signal(&"stage_finished"):
		_scene.connect(&"stage_finished", func(_r: Dictionary) -> void: _scene_over = true)
	if _scene.has_signal(&"stage_aborted"):
		_scene.connect(&"stage_aborted", func(_r: String) -> void: _scene_over = true)
	phase = Phase.PREPARING
	_phase_t0 = Time.get_ticks_usec()
	progress.emit(str(sc.get("id", "")), _overall(0.0))


## Puts the race scene on the screen: through the host (GameFlow keeps track of the current scene and frees the
## last one) or, without one, as a child of the tree root.
func _show_scene(setup: Dictionary) -> Node:
	if host != null and is_instance_valid(host) and host.has_method(&"start_attract_stage"):
		_own_scene = false
		return host.call(&"start_attract_stage", setup)
	_free_own_scene()
	var packed := load(RACE_SCENE) as PackedScene
	if packed == null:
		return null
	var scene := packed.instantiate()
	scene.set("setup", setup)
	_own_scene = true
	get_tree().root.add_child(scene)
	return scene


func _free_own_scene() -> void:
	if _own_scene and _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null


func _overall(scene_p: float) -> float:
	return clampf((float(maxi(scene_index, 0)) + clampf(scene_p, 0.0, 1.0)) / float(maxi(1, _scenes.size())), 0.0, 1.0)


func _process(_delta: float) -> void:
	if not running or phase == Phase.IDLE:
		return
	var now := Time.get_ticks_usec()
	if _scene == null or not is_instance_valid(_scene):
		_end({"error": "scene_lost"})
		return
	if get_tree().paused:
		# the race paused itself (window focus lost, standby): the numbers would mean nothing
		get_tree().paused = false
		_end({"aborted": true, "error": "paused"})
		return
	# Modern could not start: the session drew (or will draw) the scene in Arcade – that ends the test
	var fbv: Variant = _scene.get("gfx_fallback")
	var fb := str(fbv) if fbv is String else ""
	if fb != "" or (phase != Phase.PREPARING and str(_scene.get("gfx")) != Gfx.MODERN):
		_end({"fallback": fb if fb != "" else "unknown"})
		return
	var sc := _scenes[scene_index]
	var id := str(sc.get("id", ""))
	match phase:
		Phase.PREPARING:
			if _scene.has_method(&"is_live") and bool(_scene.call(&"is_live")):
				_prepare_s = float(now - _phase_t0) / 1000000.0
				phase = Phase.SETTLING
				_phase_t0 = now
			elif float(now - _phase_t0) / 1000000.0 > PREPARE_MAX_S:
				_end({"error": "timeout"})
		Phase.SETTLING:
			if float(now - _phase_t0) / 1000000.0 >= minf(SETTLE_S, _seconds):
				phase = Phase.MEASURING
				_phase_t0 = now
				_last_us = now
				_next_counter_us = now
				_perf0 = _perf()
		Phase.MEASURING:
			_frame_ms.append(float(now - _last_us) / 1000.0)
			_last_us = now
			if now >= _next_counter_us:
				_next_counter_us = now + int(COUNTER_EVERY_S * 1000000.0)
				_sample_counters()
			var t := float(now - _phase_t0) / 1000000.0
			progress.emit(id, _overall(t / _seconds))
			if t >= _seconds or _scene_over:
				_results.append(_scene_result(sc, t))
				phase = Phase.IDLE
				_next_scene.call_deferred()


## Esc / B end the test; nothing else reaches the race scene or the menus while it runs.
func _input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		abort("user")
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion \
			or event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()


# --- measuring --------------------------------------------------------------------------------------------

## perf_stats() of the scene (the session adds its simulation times to the renderer's) or {}.
func _perf() -> Dictionary:
	if _scene != null and is_instance_valid(_scene) and _scene.has_method(&"perf_stats") and _scene.get("renderer") != null:
		var p: Variant = _scene.call(&"perf_stats")
		if p is Dictionary:
			return p
	return {}


func _count(key: String, value: float) -> void:
	var c: Array = _counters.get(key, [0.0, 0, 0.0])
	c[0] = float(c[0]) + value
	c[1] = int(c[1]) + 1
	c[2] = maxf(float(c[2]), value)
	_counters[key] = c


func _sample_counters() -> void:
	var p := _perf()
	for k: String in ["draw_calls", "draw_calls_shadow", "primitives", "primitives_shadow"]:
		_count(k, float(p.get(k, 0)))
	_count("frame_draw_calls", float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	_count("frame_primitives", float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
	_count("video_mem", float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)))


func _avg(key: String) -> float:
	var c: Array = _counters.get(key, [0.0, 0, 0.0])
	return float(c[0]) / float(maxi(1, int(c[1])))


## Average of a "<x>_avg" value of perf_stats() over the measured window only: the renderer averages since its
## setup (the frames of the preparation included), so the window is taken from the two sums. Falls back to the
## value itself when the renderer does not report the count it averaged over.
static func window_average(before: Dictionary, after: Dictionary, avg_key: String, count_key: String) -> float:
	var a1 := float(after.get(avg_key, 0.0))
	if not after.has(count_key) or not before.has(count_key):
		return a1
	var n0 := float(before.get(count_key, 0))
	var n1 := float(after.get(count_key, 0))
	if n1 - n0 < 1.0:
		return a1
	return maxf(0.0, (a1 * n1 - float(before.get(avg_key, 0.0)) * n0) / (n1 - n0))


func _scene_result(sc: Dictionary, measured_s: float) -> Dictionary:
	var st := Gfx.frame_stats(_frame_ms)
	var p1 := _perf()
	return {
		"id": str(sc.get("id", "")),
		"avg_fps": snappedf(float(st["avg_fps"]), 0.1),
		"low1_fps": snappedf(float(st["low1_fps"]), 0.1),
		"frame_ms_p95": snappedf(float(st["frame_ms_p95"]), 0.01),
		"frame_ms_p99": snappedf(float(st["frame_ms_p99"]), 0.01),
		"script_ms": snappedf(window_average(_perf0, p1, "render_ms_avg", "frames"), 0.001),
		"draw_calls": roundi(_avg("draw_calls") + _avg("draw_calls_shadow")),
		"primitives": roundi(_avg("primitives") + _avg("primitives_shadow")),
		"name": str(sc.get("name", "")),
		"frames": int(st["frames"]),
		"seconds": snappedf(measured_s, 0.01),
		"frame_ms_median": snappedf(float(st["frame_ms_median"]), 0.01),
		"frame_ms_max": snappedf(float(st["frame_ms_max"]), 0.01),
		"draw_calls_shadow": roundi(_avg("draw_calls_shadow")),
		"primitives_shadow": roundi(_avg("primitives_shadow")),
		"frame_draw_calls": roundi(_avg("frame_draw_calls")),
		"frame_primitives": roundi(_avg("frame_primitives")),
		"sim_ms": snappedf(window_average(_perf0, p1, "sim_avg_ms", "sim_steps"), 0.001),
		"prepare_s": snappedf(_prepare_s, 0.01),
		"video_mem_mb": snappedf(_avg("video_mem") / 1048576.0, 0.1),
	}


# --- the end ------------------------------------------------------------------------------------------------

## V-Sync and the frame cap off for the test (restored by _restore()).
func _unthrottle() -> void:
	_max_fps_before = Engine.max_fps
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_args().find("--write-movie") < 0:
		_vsync_before = DisplayServer.window_get_vsync_mode()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		result["vsync"] = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED


func _restore() -> void:
	if _vsync_before >= 0:
		DisplayServer.window_set_vsync_mode(_vsync_before as DisplayServer.VSyncMode)
		_vsync_before = -1
	if _max_fps_before >= 0:
		if Engine.max_fps == 0:   # nobody else (FrameCap of a window without focus) has set a cap meanwhile
			Engine.max_fps = _max_fps_before
		_max_fps_before = -1


func _exit_tree() -> void:
	_restore()
	_free_own_scene()


## Completes the result (`extra`: "fallback", "aborted", "error"), writes the files and reports it.
func _end(extra: Dictionary) -> void:
	if not running:
		return
	running = false
	phase = Phase.IDLE
	_restore()
	result["scenes"] = _results
	for k: String in extra:
		result[k] = extra[k]
	var stub := false
	if _scene != null and is_instance_valid(_scene):
		var r: Variant = _scene.get("renderer")
		if r != null and is_instance_valid(r) and (r as Object).has_method(&"debug_snapshot"):
			var snap: Variant = (r as Object).call(&"debug_snapshot")
			stub = snap is Dictionary and bool((snap as Dictionary).get("stub", false))
	result["renderer_stub"] = stub
	var gfx_cfg: Variant = ConfigLoader.lookup(_cfg, "graphics", {})
	var q: Dictionary = (result["quality"] as Dictionary).duplicate()
	q["preset"] = str(result["preset"])
	var sug := Gfx.bench_suggestion(q, _results, float(result["target_ms"]), str(result["tier"]),
		gfx_cfg if gfx_cfg is Dictionary else {})
	result["verdict"] = str(sug["verdict"])
	result["suggested_preset"] = str(sug["suggested_preset"])
	result["suggested_mode"] = str(sug["suggested_mode"])
	result["worst_scene"] = str(sug["worst"])
	result["headroom"] = snappedf(float(sug["headroom"]), 0.01)
	if str(result.get("fallback", "")) != "":
		result["suggested_mode"] = Gfx.ARCADE   # Modern does not start on this machine
	# written: a complete run, and a run that ended because Modern does not start here (that is the finding)
	var fell_back := str(result.get("fallback", "")) != ""
	var failed := bool(result.get("aborted", false)) or (str(result.get("error", "")) != "" and not fell_back)
	result.erase("written")   # a status of this run, not part of the file
	var written := false
	if not failed and (fell_back or not _results.is_empty()):
		written = write_result(result, result_file)
		if out_path != "":
			written = write_result(result, out_path) and written
	result["written"] = written
	_free_own_scene()
	finished.emit(result)


## Writes a result as indented JSON (readable for the player who sends it in). Returns false if writing failed.
static func write_result(res: Dictionary, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Leistungstest: %s lässt sich nicht schreiben (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(res, "  ", false) + "\n")   # keys in the order of the format, not sorted
	f.close()
	return true
