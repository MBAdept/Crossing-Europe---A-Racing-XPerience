class_name ModernRenderer
extends Node3D
## Renderer of the graphics mode "Modern" (v0.8.0, docs/dev/v080_contract.md §4.4, §4.5 and amendment A-7): the seam
## to the race session and the facade every renderer package builds on, on top of the race3d kernel. It owns no
## content of its own: the road is a chunk builder, vehicles, lights, weather … are dynamic layers, each found by
## its fixed file name and driven through duck-typed hooks. What it does own: the quality states of the viewport
## (scripts/race3d/quality.gd – set while a stage is prepared, put back when it leaves the tree), the shader
## warm-up (prewarm.gd), the frame-time probe and the slowness watchdog of the countdown (perf_probe.gd).
## German docs: docs/renderer-modern.md, section "Aufbau: Fassade, Ebenen, Haken".
##
## Seam to the race session (RaceRenderers):
##   setup(track, projection, cfg, scenery_db) · apply_quality(levels) once · prepare(ctx) – spans frames ·
##   render(view) every frame, also while the stage is prepared (the frozen start view) · is_prepared() ·
##   prepare_progress() · healthy() · fail_reason() · perf_stats() · debug_snapshot() · world_to_screen(z, x, h) ·
##   signal quality_lowered(preset)
## Facade for layers, builders (in commit()) and tests – main thread, read-only: the members below up to
## `visibility_m`, signal rebased(shift), layer(id), builder(id), road_to_world(), add_lamps(), add_pool_material(),
## pool_materials().
##
## prepare(ctx) builds, in this order: RoadPath3D, TerrainProfile, ChaseCamera3D, the Camera3D, the node `world`,
## materials (ModernMaterials.shared()), the environment (scripts/race3d/environment_rig.gd if that file exists,
## else the built-in PlainEnvironment), the ChunkStreamer with BuilderRegistry.create_all() and its services, then
## every layer whose file scripts/race3d/layers/<id>.gd exists, in the order of BuilderRegistry.LAYERS. All of them
## exist before the first hook is called. Then, each time in the order environment, builders, layers:
## setup(renderer) on all, apply_quality(levels) on all, prepare(ctx) on all.
## Optional hooks of the environment, of builders and of layers (duck-typed, any may be missing):
##   setup(renderer) · apply_quality(levels) · prepare(ctx) · prepare_pending() -> int · fail_reason() -> String ·
##   warmup_nodes() -> Array · update(view, dt) · rebased(shift) · perf() -> Dictionary · snapshot() -> Dictionary ·
##   quality_lowered(levels) (the watchdog stepped the preset down); layers "lights" / "flares": add_static(parent, lamps)
## The preparation then runs over frames (_advance): the render self-test once per process (not headless) → every
## prepare_pending() is 0 → the world starts: the streamer loads the chunks the start view shows, update() runs
## from now on → warmup_nodes() of every hook stand in front of the camera for WARMUP_FRAMES drawn frames, in the
## light situations of prewarm.gd (the session's loading cover hides them), and are freed → is_prepared(). Nothing is updated before the world
## starts: an update() can rely on its own preparation and on a path that is integrated around the camera.
## Every render(view) after that: environment update → streamer.update() → camera → update(view, dt) of the builders
## that have one (registration order) → update(view, dt) of the layers in list order. While the stage is prepared
## the view is the frozen start view and dt is 0.0: nothing moves before the start, however many frames it takes.
## (A builder's update() runs on the main thread while its build() may run on a worker thread: it only touches
## what build() never reads – materials, nodes.)
## healthy() is false with fail_reason() "selftest:<reason>" (--gfx-debug=fail: "selftest:debug"), whatever a hook's
## fail_reason() says while the stage is prepared ("manifest", "shader", …), "script:<file>" for a layer, builder
## or rig file that exists but does not load, or "timeout" (graphics.modern.prepare_timeout_s of drawn frames, not
## in sync mode).
## Slowness watchdog (D34 c): during the countdown the frame times are judged once (perf_probe.gd); a slow stage
## steps its preset down one step – the viewport states and every level that selects no shader variant change at
## once (quality.gd, hook quality_lowered(levels)), signal quality_lowered(preset) tells the session. Off with
## --gfx-sync, --no-watchdog and headless.
## The simulation never reads anything from here (Rule 3); nothing here reads the sound profile (Rule 4).

signal quality_lowered(preset: String)
## The floating origin moved: add `shift` to every origin-relative position that is kept (chunk nodes are moved
## by the streamer, the camera and whatever is placed per frame through `path` need nothing).
signal rebased(shift: Vector3)

const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")
const PlainSky := preload("res://scripts/race3d/plain_sky.gd")
const Quality := preload("res://scripts/race3d/quality.gd")
const PerfProbe := preload("res://scripts/race3d/perf_probe.gd")
const Prewarm := preload("res://scripts/race3d/prewarm.gd")

const SKY_LAYER := -10              ## canvas layer of the backdrop (= Environment.background_canvas_max_layer)
const RIG_SCRIPT := "res://scripts/race3d/environment_rig.gd"
const LAMP_LAYERS: Array[String] = ["lights", "flares"]   ## add_lamps() forwards to these
const WARMUP_FRAMES := 8            ## drawn frames the warm-up nodes (and the start view) are shown before the start (prewarm.gd: four light situations, two frames each)
const WARMUP_AHEAD_M := 14.0        ## … this far in front of the camera, on the road
const PREPARE_TIMEOUT_S := 120.0    ## default of graphics.modern.prepare_timeout_s
const TIMEOUT_FRAME_MS := 250.0     ## a single frame counts at most this much towards the time limit
const GROUND_LAYERS := 2            ## render layer of ground meshes (road, terrain): the positional lights of the lights layer leave it out

enum Stage { IDLE, SELFTEST, HOOKS, CHUNKS, WARMUP, DONE }
const STAGE_NAMES: Array[String] = ["idle", "selftest", "hooks", "chunks", "warmup", "done"]

## Result of the render self-test of this run ({} = not run yet): one test per start of the game.
static var selftest: Dictionary = {}
static var _selftest_running := false

# --- facade (A-7): main thread, read-only for layers, builders and tests ------------------------------------------
var track: Track
var proj: RoadProjection
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var levels: Dictionary = {}         ## Gfx levels of apply_quality()
var sync := false                   ## --gfx-sync (prepare ctx): deterministic test mode
var prep: Dictionary = {}           ## ctx of prepare(): sets, plan, vehicle, weather, hour, sync
var path: RoadPath3D                ## integrated around the camera from the first update() on
var terrain: TerrainProfile
var streamer: ChunkStreamer
var chase: ChaseCamera3D
var camera: Camera3D
var materials: ModernMaterials      ## = ModernMaterials.shared()
var env: Node                       ## scripts/race3d/environment_rig.gd, null while that file is missing
var world: Node3D                   ## parent of the 3D nodes of dynamic layers: identity transform, origin-relative
var view: Dictionary = {}           ## the view of the current render() call
var visibility_m := 900.0           ## sight of this frame in metres
var debug_flags: Array[String] = []   ## --gfx-debug=<list>

var _environment: Node              ## the rig or the built-in PlainEnvironment
var _plain_sky: Node                ## built-in backdrop while layers/backdrop.gd is missing
var _layers: Dictionary = {}        ## layer id -> Node
var _hooks: Array = []              ## environment, builders, (plain sky,) layers – the order of every hook phase
var _updaters: Array = []           ## objects with update(view, dt) after the camera: builders, (plain sky,) layers
var _env_updates := false
var _rebase_listeners: Array = []   ## objects with rebased(shift), in hook order
var _pool_materials: Array = []     ## ShaderMaterial
var _lamps := 0
var _warm: Node3D
var _stage := Stage.IDLE
var _prepared := false
var _fail := ""
var _world_started := false
var _prewarm := true
var _timeout_s := PREPARE_TIMEOUT_S
var _pending := 0
var _pending_max := 0
var _prep_t0 := 0
var _wait_ms := 0.0                 ## time of the preparation that counts towards the time limit
var _wait_tick := 0
var _wait_drawn := -1
var _prepare_ms := 0.0
var _warm_from := 0
var _warm_t0 := 0
var _warm_count := 0
var _prewarm_ms := 0.0
var _load_stats: Dictionary = {}
var _frames := 0
var _render_us := 0
var _render_us_max := 0
var _quality := Quality.new()       ## viewport and RenderingServer states of the quality levels
var _probe := PerfProbe.new()       ## frame times and the watchdog of the countdown
var _warmup: RefCounted             ## Prewarm while the warm-up runs
var _lowered := ""                  ## preset the watchdog stepped down to ("" = it did not)
var _wire := false
var _vp_size := Vector2(1280.0, 720.0)
var _cam_tr := Transform3D.IDENTITY
var _cam_fr: Dictionary = {}
var _cam_yaw := 0.0


func setup(p_track: Track, projection: RoadProjection, p_cfg: Dictionary, p_scenery_db: Dictionary) -> void:
	track = p_track
	proj = projection
	cfg = p_cfg
	scenery_db = p_scenery_db
	_vp_size = projection.screen


## Quality parameters of this stage (Gfx.levels): once, before prepare(); never during a stage.
func apply_quality(p_levels: Dictionary) -> void:
	if _stage != Stage.IDLE:
		push_warning("ModernRenderer: apply_quality() nach prepare() wird ignoriert")
		return
	levels = p_levels.duplicate(true)


## Starts the preparation of the stage: builds the kernel, the environment, the builders and the layers, calls
## their hooks and then runs over frames until is_prepared() (see the header). ctx: {"sets": Array[String] – every
## sprite set id the stage can show, "plan": StagePlan, "vehicle": String (type id), "weather": String,
## "hour": float, "sync": bool (deterministic test mode, --gfx-sync)}.
func prepare(ctx: Dictionary) -> void:
	if _stage != Stage.IDLE:
		push_warning("ModernRenderer: prepare() gibt es einmal je Renderer")
		return
	prep = ctx
	sync = bool(ctx.get("sync", false))
	debug_flags.clear()
	for f in CliArgs.get_string("gfx-debug", "").split(",", false):
		debug_flags.append(f.strip_edges())
	_prep_t0 = Time.get_ticks_msec()
	_stage = Stage.SELFTEST
	if debug_flags.has("fail"):
		_fail = "selftest:debug"
		return
	_build()


func is_prepared() -> bool:
	return _prepared


func prepare_progress() -> float:
	match _stage:
		Stage.IDLE:
			return 0.0
		Stage.SELFTEST:
			# (a finished test stays at its step: the bar of the loading picture never runs backwards – RINT-B)
			return 0.1 if _selftest_running or not selftest.is_empty() else 0.05
		Stage.HOOKS:
			return 0.15 + 0.45 * (1.0 - float(_pending) / float(maxi(_pending_max, 1)))
		Stage.CHUNKS:
			return 0.65
		Stage.WARMUP:
			return 0.8 + 0.2 * ((_warmup as Prewarm).progress(Engine.get_frames_drawn()) if _warmup != null else 1.0)
	return 1.0


## False when Modern cannot draw this stage; fail_reason() says why (see the header). The session then draws the
## stage in Arcade.
func healthy() -> bool:
	return _fail == ""


func fail_reason() -> String:
	return _fail


## Layer `id` ("backdrop", "far_ground", "lights", "vehicles", "flares", "weather", "overlay", "post"), null when
## its file does not exist (or before prepare()).
func layer(id: String) -> Node:
	return _layers.get(id)


## The registered chunk builder with that id(), or null.
func builder(id: String) -> ChunkBuilder:
	if streamer == null:
		return null
	for b: ChunkBuilder in streamer.builders():
		if b.id() == id:
			return b
	return null


## Road coordinates (z along the road, x lateral, h above the road) -> origin-relative world position
## (RoadPath3D.world()). Valid inside the integrated path, i.e. from the first update() on; Vector3.ZERO before.
func road_to_world(z: float, x: float, h: float) -> Vector3:
	if path == null or not path.is_ready():
		return Vector3.ZERO
	return path.world(z, x, h)


## Static lamps of a chunk part: `lamps` = Array of {"pos": Vector3 (local to parent), "dir": Vector3 (unit, local;
## where the lamp looks), "role": String, "color": Color, "size": float (m), "range": float (m, radius of the light
## pool on the ground; 0 = none), "energy": float (default 1)}. Forwarded to the layers "lights" and "flares" when
## they exist and have add_static(parent, lamps); both follow parent.global_transform and forget the entries when
## `parent` leaves the tree. Without those layers nothing happens.
func add_lamps(parent: Node3D, lamps: Array) -> void:
	if parent == null or lamps.is_empty():
		return
	_lamps += lamps.size()
	for id: String in LAMP_LAYERS:
		var l: Node = _layers.get(id)
		if l != null and l.has_method(&"add_static"):
			l.call(&"add_static", parent, lamps)


## Registers a material whose shader includes assets/shaders/modern/inc/pools.gdshaderinc: the layer "lights" sets
## pool_pos_r, pool_col and pool_count on every registered material once per frame.
func add_pool_material(mat: ShaderMaterial) -> void:
	if mat != null and not _pool_materials.has(mat):
		_pool_materials.append(mat)


## The registered pool materials (for the lights layer; do not change the array).
func pool_materials() -> Array:
	return _pool_materials


# --- what a test double may replace -------------------------------------------------------------------------------

## Script file of layer `id` (tests stand fixtures in by overriding it in a subclass).
func _layer_script(id: String) -> String:
	return BuilderRegistry.layer_path(id)


## The chunk builders of this renderer, in build order: every builder of the registry whose file exists (the debug
## road while builders/road.gd is missing). A file that is there but gives no builder with that id() makes the
## renderer unhealthy ("script:builders/<name>.gd").
func _create_builders() -> Array[ChunkBuilder]:
	var out := BuilderRegistry.create_all()
	var ids: Array[String] = []
	for b: ChunkBuilder in out:
		ids.append(b.id())
	for n: String in BuilderRegistry.existing_builders():
		if not ids.has(n) and _fail == "":
			_fail = "script:builders/%s.gd" % n
	if not ids.has("terrain") and not ids.has(BuilderRegistry.DEBUG_ROAD):
		# the road is there, the terrain is not (yet): the debug road stands in with its ribbon alone
		var ribbon := BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD)
		if ribbon != null:
			ribbon.set("road_strips", false)
			out.append(ribbon)
	return out


## Script file of the environment rig.
func _rig_script() -> String:
	return RIG_SCRIPT


# --- building ---------------------------------------------------------------------------------------------------

func _build() -> void:
	var modern := _as_dict(ConfigLoader.lookup(cfg, "graphics.modern", {}))
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
	# kernel: the path is set up by the streamer's first update(), behind the camera of the start view
	path = RoadPath3D.new()
	terrain = TerrainProfile.new()
	terrain.setup(path, track, _as_dict(modern.get("terrain", {})), scenery_db)
	chase = ChaseCamera3D.new()
	chase.setup(proj, _as_dict(modern.get("camera", {})))
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.make_current()
	_vp_size = _viewport_size()
	_cam_fr = chase.frustum(_vp_size)
	camera.set_frustum(float(_cam_fr["size"]), _cam_fr["offset"], float(_cam_fr["near"]), float(_cam_fr["far"]))
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	materials = ModernMaterials.shared()
	# environment: the rig of the renderer package, or the built-in plain one
	var rig_path := _rig_script()
	if rig_path != "" and ResourceLoader.exists(rig_path):
		var rig: Variant = _instance(rig_path)
		if rig is Node:
			env = rig
			_environment = rig
		else:
			_fail = "script:" + rig_path.get_file()
	else:
		_environment = PlainEnvironment.new()
	if _environment != null:
		_environment.name = "Environment"
		add_child(_environment)
		_hooks.append(_environment)
	# streamer and builders
	streamer = ChunkStreamer.new()
	streamer.name = "Chunks"
	world.add_child(streamer)
	streamer.setup(path, terrain, track, cfg, levels, sync)
	streamer.services = {"renderer": self, "materials": materials}
	for b: ChunkBuilder in _create_builders():
		streamer.register(b)
		_hooks.append(b)
	var debug_road := builder(BuilderRegistry.DEBUG_ROAD)
	if debug_road != null and builder("terrain") != null:
		debug_road.set("terrain_rings", false)   # the real terrain is there: the stand-in only draws the road
	streamer.rebased.connect(_on_rebased)
	_warm = Node3D.new()
	_warm.name = "Warmup"
	world.add_child(_warm)
	# layers, in the fixed order; the built-in sky stands in for a missing backdrop layer
	for id: String in BuilderRegistry.LAYERS:
		var script_path := _layer_script(id)
		if script_path == "" or not ResourceLoader.exists(script_path):
			if id == "backdrop":
				_plain_sky = PlainSky.new()
				_plain_sky.name = "PlainSky"
				add_child(_plain_sky)
				_hooks.append(_plain_sky)
			continue
		var obj: Variant = _instance(script_path)
		if not (obj is Node):
			if _fail == "":
				_fail = "script:layers/%s.gd" % id
			continue
		var node: Node = obj
		node.name = id
		add_child(node)
		_layers[id] = node
		_hooks.append(node)
	if _fail != "":
		push_warning("ModernRenderer: %s lässt sich nicht laden" % _fail)
		return
	# hook phases: every object exists before the first call
	for h: Object in _hooks:
		if h.has_method(&"setup"):
			h.call(&"setup", self)
	for h: Object in _hooks:
		if h.has_method(&"apply_quality"):
			h.call(&"apply_quality", levels)
	for h: Object in _hooks:
		if h.has_method(&"prepare"):
			h.call(&"prepare", prep)
	# the environment is updated before the streamer and the camera, everything else after them (hook order:
	# builders, then layers)
	_env_updates = _environment != null and _environment.has_method(&"update")
	for h: Object in _hooks:
		if h != _environment and h.has_method(&"update"):
			_updaters.append(h)
		if h.has_method(&"rebased"):
			_rebase_listeners.append(h)


## A new instance of the script at `script_path`, or null when it does not load.
static func _instance(script_path: String) -> Variant:
	var script: Variant = load(script_path)
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		return null
	var obj: Variant = (script as GDScript).new()
	if obj is Node:
		return obj
	if obj is Object and not (obj is RefCounted):
		(obj as Object).free()
	return null


static func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


# --- preparation over frames ------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _stage == Stage.IDLE or _stage == Stage.DONE:
		return
	_advance()


## One step of the preparation (every frame until is_prepared()).
func _advance() -> void:
	if _fail != "":
		_finish()
		return
	if _stage == Stage.SELFTEST:
		if DisplayServer.get_name() != "headless" and selftest.is_empty():
			# the first Modern stage of this run with a real renderer: wait for the render self-test
			if not _selftest_running:
				_run_selftest(self)
			return
		if not bool(selftest.get("ok", true)):
			_fail = "selftest:" + str(selftest.get("reason", ""))
			_finish()
			return
		_stage = Stage.HOOKS
	_pending = _poll_hooks()
	_pending_max = maxi(_pending_max, _pending)
	# the time limit counts frames that were drawn, each with at most TIMEOUT_FRAME_MS: a minimised window draws
	# nothing (self-test and warm-up wait for it), and a computer that slept is not a renderer that hangs
	var now := Time.get_ticks_msec()
	var drawn := Engine.get_frames_drawn()
	if _wait_tick > 0 and (drawn != _wait_drawn or DisplayServer.get_name() == "headless"):
		_wait_ms += minf(float(now - _wait_tick), TIMEOUT_FRAME_MS)
	_wait_tick = now
	_wait_drawn = drawn
	if _fail == "" and not sync and _timeout_s > 0.0 and _wait_ms > _timeout_s * 1000.0:
		_fail = "timeout"
	if _fail != "":
		push_warning("ModernRenderer: Vorbereitung abgebrochen (%s)" % _fail)
		_finish()
		return
	if _stage == Stage.HOOKS:
		if _pending > 0:
			return
		_stage = Stage.CHUNKS
		if not sync:
			# one drawn frame with the bar at the chunk step: the start view is then loaded at once, in one long
			# frame (Kiel–Hamburg on the build VM about 2 s – RINT-B measured the bar standing at 0.05 meanwhile)
			return
	if _stage == Stage.CHUNKS:
		if view.is_empty():
			return   # the first render() brings the start view
		if not _world_started:
			_start_world()
		if sync:
			streamer.flush()
		if _pending > 0 or streamer.pending_count() > 0:
			return
		_begin_warmup()
	if _stage == Stage.WARMUP:
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


## Sum of prepare_pending() of all hooks; the first fail_reason() that is not empty ends the preparation.
func _poll_hooks() -> int:
	var n := 0
	for h: Object in _hooks:
		if _fail == "" and h.has_method(&"fail_reason"):
			var reason := str(h.call(&"fail_reason"))
			if reason != "":
				_fail = reason
		if h.has_method(&"prepare_pending"):
			n += maxi(0, int(h.call(&"prepare_pending")))
	return n


## Every hook is ready: the streamer sets the path up behind the camera of the start view and loads everything
## that view shows at once; from here on render() updates the world.
func _start_world() -> void:
	streamer.update(float(view.get("camera_z", 0.0)), visibility_m)
	_world_started = true
	_draw_world(0.0)


func _begin_warmup() -> void:
	_stage = Stage.WARMUP
	_warm_t0 = Time.get_ticks_usec()
	_warm_from = Engine.get_frames_drawn()
	if not _prewarm:
		return
	for h: Object in _hooks:
		if not h.has_method(&"warmup_nodes"):
			continue
		var nodes: Variant = h.call(&"warmup_nodes")
		if not (nodes is Array):
			continue
		for n: Variant in nodes:
			if n is Node3D and (n as Node3D).get_parent() == null:
				_warm.add_child(n)
				_warm_count += 1
			elif n is Node and (n as Node).get_parent() == null:
				(n as Node).free()   # only fresh Node3D are shown; nothing handed over may leak
	_place_warmup()
	if DisplayServer.get_name() != "headless" and RenderingServer.render_loop_enabled:
		# every light situation the stage can bring, a few drawn frames each (prewarm.gd)
		var plan := Prewarm.new()
		plan.begin(world, _warm_from)
		_warmup = plan


func _finish() -> void:
	_stage = Stage.DONE
	_prepared = true
	_prepare_ms = float(Time.get_ticks_msec() - _prep_t0)
	if _warmup != null:
		(_warmup as Prewarm).finish()   # a preparation that was cut short (failure, time limit)
		_warmup = null
	if streamer != null:
		_load_stats = streamer.stats()
		streamer.reset_stats()   # perf_stats() shows the drive; the load is kept as "load"


## Runs the render self-test and keeps its verdict for the rest of the run. Static: the test outlives a renderer
## that is freed in the middle of it (a member coroutine cannot be resumed once its node is gone); a test that lost
## its renderer has no verdict – the next stage tests again.
static func _run_selftest(parent: Node) -> void:
	_selftest_running = true
	var res: Dictionary = await GfxSelfTest.run(parent)
	_selftest_running = false
	if not bool(res.get("aborted", false)):
		selftest = res


# --- quality while a stage runs ---------------------------------------------------------------------------------

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

## Draws the frame of `view` (ARCHITECTURE.md §6; Modern also reads hour, dt and player.type). While the stage is
## prepared the session passes the frozen start view; the world is updated from the moment every hook is ready –
## with dt = 0.0 until is_prepared(): the frozen view stands still, so the state at the start does not depend on
## how many frames the preparation took (self-test and warm-up frames, none of them headless).
func render(p_view: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	view = p_view
	visibility_m = float(p_view.get("visibility_m", visibility_m))
	if _world_started:
		_draw_world(float(p_view.get("dt", 0.0)) if _prepared else 0.0)
	if _prepared:
		var frame_us := _probe.frame(t0)
		if _probe.enabled and _probe.watch(frame_us, float(p_view.get("countdown", -1.0)), Quality.lower_preset(str(levels.get("preset", ""))) == "") == "slow":
			_lower_quality()
		_frames += 1
		var us := Time.get_ticks_usec() - t0
		_render_us += us
		_render_us_max = maxi(_render_us_max, us)


## environment → streamer → camera → builders with update() → layers.
func _draw_world(dt: float) -> void:
	if _env_updates:
		_environment.call(&"update", view, dt)
	streamer.update(float(view.get("camera_z", 0.0)), visibility_m)
	# Arcade's projection exactly, plus the look into the bend (D12): transform and frustum from ChaseCamera3D, for
	# the LOGICAL size of the picture (1280 x 720, or more rows / columns with stretch aspect "expand", D13)
	_vp_size = _viewport_size()
	_cam_tr = chase.transform(view, path)
	_cam_fr = chase.frustum(_vp_size, view.get("shake", Vector2.ZERO))
	_cam_yaw = chase.look_yaw(path, float(view.get("camera_z", 0.0)))
	if camera.is_inside_tree():
		camera.global_transform = _cam_tr
	else:
		camera.transform = _cam_tr
	camera.set_frustum(float(_cam_fr["size"]), _cam_fr["offset"], float(_cam_fr["near"]), float(_cam_fr["far"]))
	for l: Object in _updaters:
		l.call(&"update", view, dt)
	if _stage == Stage.WARMUP:
		_place_warmup()


## The warm-up nodes stand on the road in front of the camera, turned like a vehicle ahead.
func _place_warmup() -> void:
	_warm.transform = Transform3D(_cam_tr.basis, _cam_tr.origin + _cam_tr.basis * Vector3(0.0, -proj.cam_height, -WARMUP_AHEAD_M))


func _on_rebased(shift: Vector3) -> void:
	for l: Object in _rebase_listeners:
		l.call(&"rebased", shift)
	rebased.emit(shift)


## Screen position of a point in road coordinates (z along the road, x lateral, h above the road): (pixel x,
## pixel y, depth in m along the view axis) in logical pixels of the picture of the last render()
## (ChaseCamera3D.project – the mapping of Camera3D.unproject_position()). Depth <= 0: behind the camera or
## nothing drawn yet (the pixel values are then meaningless).
func world_to_screen(z: float, x: float, h: float) -> Vector3:
	if not _world_started:
		return Vector3(0.0, 0.0, -1.0)
	return ChaseCamera3D.project(_cam_tr, _cam_fr, _vp_size, path.world(z, x, h))


## Logical size of the picture: 1280×720, or more rows/columns where the window has another aspect ratio (the race
## uses stretch aspect "expand" in Modern, D13).
func _viewport_size() -> Vector2:
	var size := proj.screen
	if is_inside_tree():
		var rect := get_viewport().get_visible_rect().size
		if rect.x > 0.0 and rect.y > 0.0:
			size = rect
	return size


# --- statistics and test data -----------------------------------------------------------------------------------

## Contract §4.4.5. render_ms_* = GDScript time of render() since the stage is prepared; chunk_* = the streamer's
## times of the drive ("load" holds those of the preparation); draw calls and primitives of the last drawn frame
## (0 headless); frame_ms_* = wall clock between the last render() calls, start_frame_ms_* the first 30 s of the
## stage, watchdog* the verdict of the countdown (perf_probe.gd). perf() of the hooks is merged in: numbers add up
## (lights_omni, lights_spot, vehicles, instances, fallback_sets … start at 0 here).
func perf_stats() -> Dictionary:
	var n := maxf(1.0, float(_frames))
	var st: Dictionary = streamer.stats() if streamer != null else {}
	var out := {"mode": Gfx.MODERN, "preset": str(levels.get("preset", "")), "frames": _frames,
		"render_ms_avg": float(_render_us) / n / 1000.0, "render_ms_max": float(_render_us_max) / 1000.0,
		"chunks": int(st.get("chunks", 0)), "chunk_build_ms_avg": float(st.get("build_ms_avg", 0.0)),
		"chunk_build_ms_max": float(st.get("build_ms_max", 0.0)), "chunk_commit_ms_max": float(st.get("commit_ms_max", 0.0)),
		"draw_calls": 0, "draw_calls_shadow": 0, "primitives": 0, "primitives_shadow": 0, "lights_omni": 0,
		"lights_spot": 0, "vehicles": 0, "instances": 0, "frame_ms_median": 0.0, "frame_ms_p95": 0.0,
		"prewarm_ms": _prewarm_ms, "fallback_sets": 0, "tex_mem_mb": 0.0,
		"prepare_ms": _prepare_ms, "selftest_ms": float(selftest.get("ms", 0.0)), "warmup_nodes": _warm_count,
		"quality_lowered": _lowered, "streamer": st, "load": _load_stats}
	out.merge(_probe.stats(), true)
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		var vp := get_viewport().get_viewport_rid()
		out["draw_calls"] = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		out["draw_calls_shadow"] = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		out["primitives"] = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		out["primitives_shadow"] = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		out["tex_mem_mb"] = float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0
	for h: Object in _hooks:
		if h.has_method(&"perf"):
			var extra: Variant = h.call(&"perf")
			if extra is Dictionary:
				merge_data(out, extra)
	return out


## Plain data for headless tests (no render counters): what the renderer shows right now. Contract §4.4.5:
## camera {z, x, y, yaw_deg, frustum}, chunks [{index, seg_a, seg_b, state, pos, parts: {<builder id>: …}}],
## vehicles, lights {omni, spot, pools}, props, signs, quality – plus stage, prepared, layers, builders, path,
## pending_chunks, pool_materials, lamps, visibility_m. snapshot() of the hooks is merged in (arrays are appended,
## dictionaries merged, numbers add up).
func debug_snapshot() -> Dictionary:
	var builders: Array[String] = []
	if streamer != null:
		for b: ChunkBuilder in streamer.builders():
			builders.append(b.id())
	var out := {"camera": {"z": float(view.get("camera_z", 0.0)), "x": float(view.get("camera_x", 0.0)),
			"y": float(view.get("camera_y", 0.0)), "yaw_deg": rad_to_deg(_cam_yaw), "frustum": _cam_fr.duplicate(),
			"pos": [_cam_tr.origin.x, _cam_tr.origin.y, _cam_tr.origin.z], "viewport": [_vp_size.x, _vp_size.y]},
		"chunks": [], "vehicles": [], "lights": {"omni": 0, "spot": 0, "pools": 0}, "props": {}, "signs": [],
		"quality": levels.duplicate(true), "stage": STAGE_NAMES[_stage], "prepared": _prepared, "layers": _layers.keys(),
		"builders": builders, "pool_materials": _pool_materials.size(), "lamps": _lamps, "visibility_m": visibility_m,
		"render_state": _quality.applied.duplicate(), "quality_lowered": _lowered}
	if streamer != null:
		var s := streamer.snapshot()
		out["chunks"] = s["chunks"]
		out["pending_chunks"] = s["pending"]
		out["path"] = s["path"]
	for h: Object in _hooks:
		if h.has_method(&"snapshot"):
			var extra: Variant = h.call(&"snapshot")
			if extra is Dictionary:
				merge_data(out, extra)
	return out


## Merges `extra` into `into`: arrays are appended, dictionaries merged key by key, numbers add up, anything else
## (and a key that is new) is taken as it is.
static func merge_data(into: Dictionary, extra: Dictionary) -> void:
	for k: Variant in extra:
		var v: Variant = extra[k]
		if not into.has(k):
			into[k] = v
			continue
		var old: Variant = into[k]
		if old is Dictionary and v is Dictionary:
			merge_data(old, v)
		elif old is Array and v is Array:
			(old as Array).append_array(v)
		elif (old is int or old is float) and (v is int or v is float):
			into[k] = old + v
		else:
			into[k] = v
