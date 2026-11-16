import sys
p = 'scripts/race3d/modern_renderer.gd'
s = open(p).read()


def rep(old, new, count=1):
    global s
    assert s.count(old) >= 1, old[:80]
    s = s.replace(old, new, count)


# --- header
rep('''## Renderer of the graphics mode "Modern" (v0.8.0) – the SKELETON of wave 1 (docs/dev/v080_contract.md §4.4, §4.5
## and amendment A-7): the facade every renderer package builds on, on top of the race3d kernel. It owns no
## content of its own: the road is a chunk builder, vehicles, lights, weather … are dynamic layers, each found by
## its fixed file name and driven through duck-typed hooks. German docs: docs/renderer-modern.md, section
## "Aufbau: Fassade, Ebenen, Haken".''', '''## Renderer of the graphics mode "Modern" (v0.8.0, docs/dev/v080_contract.md §4.4, §4.5 and amendment A-7): the seam
## to the race session and the facade every renderer package builds on, on top of the race3d kernel. It owns no
## content of its own: the road is a chunk builder, vehicles, lights, weather … are dynamic layers, each found by
## its fixed file name and driven through duck-typed hooks. What it does own: the quality states of the viewport
## (scripts/race3d/quality.gd – set while a stage is prepared, put back when it leaves the tree), the shader
## warm-up (prewarm.gd), the frame-time probe and the slowness watchdog of the countdown (perf_probe.gd).
## German docs: docs/renderer-modern.md, section "Aufbau: Fassade, Ebenen, Haken".''')
rep('''##   warmup_nodes() -> Array · update(view, dt) · rebased(shift) · perf() -> Dictionary · snapshot() -> Dictionary;
##   layers "lights" / "flares": add_static(parent, lamps)''', '''##   warmup_nodes() -> Array · update(view, dt) · rebased(shift) · perf() -> Dictionary · snapshot() -> Dictionary ·
##   quality_lowered(levels) (the watchdog stepped the preset down); layers "lights" / "flares": add_static(parent, lamps)''')
rep('''## from now on → warmup_nodes() of every hook stand in front of the camera for WARMUP_FRAMES drawn frames (the
## session's loading cover hides them) and are freed → is_prepared(). Nothing is updated before the world''', '''## from now on → warmup_nodes() of every hook stand in front of the camera for WARMUP_FRAMES drawn frames, in the
## light situations of prewarm.gd (the session's loading cover hides them), and are freed → is_prepared(). Nothing is updated before the world''')
rep('''## The simulation never reads anything from here (Rule 3); nothing here reads the sound profile (Rule 4).''', '''## Slowness watchdog (D34 c): during the countdown the frame times are judged once (perf_probe.gd); a slow stage
## steps its preset down one step – the viewport states and every level that selects no shader variant change at
## once (quality.gd, hook quality_lowered(levels)), signal quality_lowered(preset) tells the session. Off with
## --gfx-sync, --no-watchdog and headless.
## The simulation never reads anything from here (Rule 3); nothing here reads the sound profile (Rule 4).''')

# --- consts
rep('''const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")
const PlainSky := preload("res://scripts/race3d/plain_sky.gd")
''', '''const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")
const PlainSky := preload("res://scripts/race3d/plain_sky.gd")
const Quality := preload("res://scripts/race3d/quality.gd")
const PerfProbe := preload("res://scripts/race3d/perf_probe.gd")
const Prewarm := preload("res://scripts/race3d/prewarm.gd")
''')
rep('''const WARMUP_FRAMES := 2            ## drawn frames the warm-up nodes (and the start view) are shown before the start''',
    '''const WARMUP_FRAMES := 8            ## drawn frames the warm-up nodes (and the start view) are shown before the start (prewarm.gd: four light situations, two frames each)''')
rep('''const FRAME_WINDOW := 240           ## frames behind frame_ms_median / frame_ms_p95
''', '''const GROUND_LAYERS := 2            ## render layer of ground meshes (road, terrain): the positional lights of the lights layer leave it out
''')

# --- members
rep('''var _frames := 0
var _render_us := 0
var _render_us_max := 0
var _frame_us := PackedInt32Array()
var _frame_i := 0
var _last_tick := 0
''', '''var _frames := 0
var _render_us := 0
var _render_us_max := 0
var _quality := Quality.new()       ## viewport and RenderingServer states of the quality levels
var _probe := PerfProbe.new()       ## frame times and the watchdog of the countdown
var _warmup: RefCounted             ## Prewarm while the warm-up runs
var _lowered := ""                  ## preset the watchdog stepped down to ("" = it did not)
var _wire := false
''')

# --- build: quality, probe
rep('''	var modern := _as_dict(ConfigLoader.lookup(cfg, "graphics.modern", {}))
	_prewarm = bool(modern.get("prewarm", true)) and not CliArgs.has("no-prewarm")
	_timeout_s = float(modern.get("prepare_timeout_s", PREPARE_TIMEOUT_S))
''', '''	var modern := _as_dict(ConfigLoader.lookup(cfg, "graphics.modern", {}))
	_prewarm = bool(modern.get("prewarm", true)) and not CliArgs.has("no-prewarm")
	_timeout_s = float(modern.get("prepare_timeout_s", PREPARE_TIMEOUT_S))
	# quality states of the viewport and of the RenderingServer: set now, put back in _exit_tree()
	var headless := DisplayServer.get_name() == "headless"
	if is_inside_tree():
		_quality.apply(get_viewport(), levels)
		if debug_flags.has("wire") and not headless:
			_wire = true
			RenderingServer.set_debug_generate_wireframes(true)
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	_probe.configure(_as_dict(ConfigLoader.lookup(cfg, "graphics.watchdog", {})), DisplayServer.screen_get_refresh_rate() if not headless else 0.0,
		Engine.max_fps, not sync and not headless and not CliArgs.has("no-watchdog"))
''')

# --- warm-up stage
rep('''	if _stage == Stage.WARMUP:
		var need := WARMUP_FRAMES
		if not _prewarm or DisplayServer.get_name() == "headless" or not RenderingServer.render_loop_enabled:
			need = 0   # nothing is drawn (or wanted): no warm-up frames
		if _pending > 0 or Engine.get_frames_drawn() - _warm_from < need:
			return
		for n: Node in _warm.get_children():
			_warm.remove_child(n)
			n.free()
		_prewarm_ms = float(Time.get_ticks_usec() - _warm_t0) / 1000.0
		_finish()
''', '''	if _stage == Stage.WARMUP:
		if _pending > 0:
			return
		# (no plan: nothing is drawn or wanted – no warm-up frames)
		if _warmup != null and not (_warmup as Prewarm).step(Engine.get_frames_drawn(), _cam_tr):
			return
		if _warmup != null:
			(_warmup as Prewarm).finish()
			_warmup = null
		for n: Node in _warm.get_children():
			_warm.remove_child(n)
			n.free()
		_prewarm_ms = float(Time.get_ticks_usec() - _warm_t0) / 1000.0
		_finish()
''')
rep('''			elif n is Node and (n as Node).get_parent() == null:
				(n as Node).free()   # only fresh Node3D are shown; nothing handed over may leak
	_place_warmup()
''', '''			elif n is Node and (n as Node).get_parent() == null:
				(n as Node).free()   # only fresh Node3D are shown; nothing handed over may leak
	_place_warmup()
	if DisplayServer.get_name() != "headless" and RenderingServer.render_loop_enabled:
		# every light situation the stage can bring, a few drawn frames each (prewarm.gd)
		var plan := Prewarm.new()
		plan.begin(world, _warm_from)
		_warmup = plan
''')
rep('''		Stage.WARMUP:
			return 0.8 + 0.2 * clampf(float(Engine.get_frames_drawn() - _warm_from) / float(WARMUP_FRAMES), 0.0, 1.0)''',
    '''		Stage.WARMUP:
			return 0.8 + 0.2 * ((_warmup as Prewarm).progress(Engine.get_frames_drawn()) if _warmup != null else 1.0)''')
rep('''	if streamer != null:
		_load_stats = streamer.stats()
		streamer.reset_stats()   # perf_stats() shows the drive; the load is kept as "load"
	_last_tick = 0
''', '''	if _warmup != null:
		(_warmup as Prewarm).finish()   # a preparation that was cut short (failure, time limit)
		_warmup = null
	if streamer != null:
		_load_stats = streamer.stats()
		streamer.reset_stats()   # perf_stats() shows the drive; the load is kept as "load"
''')

# --- render
rep('''	if _prepared:
		if _last_tick > 0:
			if _frame_us.size() < FRAME_WINDOW:
				_frame_us.append(t0 - _last_tick)
			else:
				_frame_us[_frame_i] = t0 - _last_tick
				_frame_i = (_frame_i + 1) % FRAME_WINDOW
		_last_tick = t0
		_frames += 1
		var us := Time.get_ticks_usec() - t0
		_render_us += us
		_render_us_max = maxi(_render_us_max, us)
''', '''	if _prepared:
		var frame_us := _probe.frame(t0)
		if _probe.enabled and _probe.watch(frame_us, float(p_view.get("countdown", -1.0)), Quality.lower_preset(str(levels.get("preset", ""))) == "") == "slow":
			_lower_quality()
		_frames += 1
		var us := Time.get_ticks_usec() - t0
		_render_us += us
		_render_us_max = maxi(_render_us_max, us)
''')

# --- lower quality + exit tree
rep('''# --- every frame ------------------------------------------------------------------------------------------------
''', '''# --- quality while a stage runs ---------------------------------------------------------------------------------

## The watchdog found the countdown slow: the preset goes down one step for the rest of the stage. Everything that
## selects no shader variant changes at once – viewport states, shadow casters and reach, glow, SSAO, densities and
## LOD distances of what is built from now on; hooks with quality_lowered(levels) follow, and without casters the
## geometry under `world` stops casting shadows. Signal quality_lowered(preset) tells the session.
func _lower_quality() -> void:
	var lower := Quality.lower_preset(str(levels.get("preset", "")))
	if lower == "" or _lowered != "":
		return
	var gfx_cfg := _as_dict(ConfigLoader.lookup(cfg, "graphics", {}))
	var target := Gfx.levels(Gfx.quality(lower, {}, _as_dict(gfx_cfg.get("presets", {}))), gfx_cfg)
	var next: Dictionary = Quality.lowered(levels, target)
	# in place: the streamer and every chunk context hold this dictionary
	levels.clear()
	levels.merge(next)
	_lowered = lower
	if is_inside_tree():
		_quality.apply(get_viewport(), levels)
	for h: Object in _hooks:
		if h.has_method(&"quality_lowered"):
			h.call(&"quality_lowered", levels)
	if int(levels.get("shadow_casters", 0)) <= 0 and world != null:
		_stop_casting(world)
	quality_lowered.emit(lower)


static func _stop_casting(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: Node in node.get_children():
		_stop_casting(c)


## Leaving the tree: the viewport and RenderingServer states of the quality levels go back to what they were.
func _exit_tree() -> void:
	_quality.restore()
	if _wire:
		_wire = false
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED


# --- every frame ------------------------------------------------------------------------------------------------
''')

# --- perf stats
rep('''	var sorted := _frame_us.duplicate()
	sorted.sort()
	var median := 0.0
	var p95 := 0.0
	if not sorted.is_empty():
		median = float(sorted[sorted.size() / 2]) / 1000.0
		p95 = float(sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))]) / 1000.0
	var out := {"mode": Gfx.MODERN, "preset": str(levels.get("preset", "")), "frames": _frames,''',
    '''	var out := {"mode": Gfx.MODERN, "preset": str(levels.get("preset", "")), "frames": _frames,''')
rep('''		"lights_spot": 0, "vehicles": 0, "instances": 0, "frame_ms_median": median, "frame_ms_p95": p95,
		"prewarm_ms": _prewarm_ms, "fallback_sets": 0, "tex_mem_mb": 0.0,
		"prepare_ms": _prepare_ms, "selftest_ms": float(selftest.get("ms", 0.0)), "warmup_nodes": _warm_count,
		"streamer": st, "load": _load_stats}''', '''		"lights_spot": 0, "vehicles": 0, "instances": 0, "frame_ms_median": 0.0, "frame_ms_p95": 0.0,
		"prewarm_ms": _prewarm_ms, "fallback_sets": 0, "tex_mem_mb": 0.0,
		"prepare_ms": _prepare_ms, "selftest_ms": float(selftest.get("ms", 0.0)), "warmup_nodes": _warm_count,
		"quality_lowered": _lowered, "streamer": st, "load": _load_stats}
	out.merge(_probe.stats(), true)''')
rep('''		"builders": builders, "pool_materials": _pool_materials.size(), "lamps": _lamps, "visibility_m": visibility_m}''',
    '''		"builders": builders, "pool_materials": _pool_materials.size(), "lamps": _lamps, "visibility_m": visibility_m,
		"render_state": _quality.applied.duplicate(), "quality_lowered": _lowered}''')
rep('''## (0 headless); frame_ms_* = wall clock between the last FRAME_WINDOW render() calls. perf() of the hooks is merged
## in: numbers add up (lights_omni, lights_spot, vehicles, instances, fallback_sets … start at 0 here).''',
    '''## (0 headless); frame_ms_* = wall clock between the last render() calls, start_frame_ms_* the first 30 s of the
## stage, watchdog* the verdict of the countdown (perf_probe.gd). perf() of the hooks is merged in: numbers add up
## (lights_omni, lights_spot, vehicles, instances, fallback_sets … start at 0 here).''')
open(p, 'w').write(s)
print("ok")
