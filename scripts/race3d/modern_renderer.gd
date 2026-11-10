class_name ModernRenderer
extends Node3D
## Renderer of the graphics mode "Modern" – STUB of wave 0 (v0.8.0, docs/dev/v080_contract.md §4.4): it only proves
## the seam between the race session and a second, real-3D renderer. It draws a camera with Arcade's projection,
## the sky colour of the palette on a canvas layer behind the 3D picture (Environment BG_CANVAS, layer −10) and one
## grey plane as the ground; road, terrain, vehicles, light and effects follow in the renderer packages, which
## replace this file and keep its interface:
##   setup(track, projection, cfg, scenery_db) · render(view) every frame · perf_stats()
##   apply_quality(levels) once before prepare() · prepare(ctx) – spans frames · is_prepared() · prepare_progress()
##   healthy() · fail_reason() · debug_snapshot() · world_to_screen(z, x, h) · signal quality_lowered(preset)
## prepare(): with a real renderer the render self-test (GfxSelfTest) runs once per run; headless the stage is
## prepared on the next frame. --gfx-debug=fail makes healthy() false (tests of the fallback to Arcade).
## The simulation never reads anything from here (Rule 3); nothing here reads the sound profile (Rule 4).

signal quality_lowered(preset: String)

const SKY_LAYER := -10          ## canvas layer of the backdrop (= Environment.background_canvas_max_layer)
const PLANE_SIZE_M := 6000.0

## Result of the render self-test of this run ({} = not run yet): one test per start of the game.
static var selftest: Dictionary = {}
static var _selftest_running := false

var track: Track
var proj: RoadProjection
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var levels: Dictionary = {}       ## quality parameters of apply_quality() (Gfx.levels)
var debug_flags: Array[String] = []   ## --gfx-debug=<list>

var _camera: Camera3D
var _plane: MeshInstance3D
var _plane_mat: StandardMaterial3D
var _sky: ColorRect
var _near := 1.0
var _far := 2600.0
var _ctx: Dictionary = {}
var _preparing := false
var _prepared := false
var _fail := ""
var _frames := 0
var _render_us := 0
var _render_us_max := 0
var _last_view: Dictionary = {}
var _cam_snapshot: Dictionary = {}


func setup(p_track: Track, projection: RoadProjection, p_cfg: Dictionary, p_scenery_db: Dictionary) -> void:
	track = p_track
	proj = projection
	cfg = p_cfg
	scenery_db = p_scenery_db
	var cam_cfg: Variant = ConfigLoader.lookup(cfg, "graphics.modern.camera", {})
	if cam_cfg is Dictionary:
		_near = maxf(0.05, float((cam_cfg as Dictionary).get("near_m", _near)))
		_far = maxf(_near + 10.0, float((cam_cfg as Dictionary).get("far_m", _far)))
	# background: the canvas layers up to SKY_LAYER are the backdrop of the 3D picture (never BG_COLOR, D7);
	# the post path is pinned on with neutral adjustments so quality options never change the base look (D6)
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = SKY_LAYER
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = SKY_LAYER
	add_child(layer)
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.color = Color.BLACK
	layer.add_child(_sky)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(_camera)
	_camera.make_current()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(PLANE_SIZE_M, PLANE_SIZE_M)
	_plane_mat = StandardMaterial3D.new()
	_plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plane_mat.albedo_color = Palette.ROAD
	_plane = MeshInstance3D.new()
	_plane.mesh = mesh
	_plane.material_override = _plane_mat
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_plane)


## Quality parameters of this stage (Gfx.levels): once, before prepare(); never during a stage.
func apply_quality(p_levels: Dictionary) -> void:
	levels = p_levels.duplicate(true)


## Starts the preparation of the stage (self-test here; assets and shader warm-up in the real renderer). ctx:
## {"sets": Array[String] – every sprite set id the stage can show, "plan": StagePlan, "vehicle": String (type id),
## "weather": String, "hour": float, "sync": bool (deterministic test mode, --gfx-sync)}.
func prepare(ctx: Dictionary) -> void:
	_ctx = ctx
	debug_flags.clear()
	for f in CliArgs.get_string("gfx-debug", "").split(",", false):
		debug_flags.append(f.strip_edges())
	if debug_flags.has("fail"):
		_fail = "selftest:debug"
	_prepared = false
	_preparing = true


func is_prepared() -> bool:
	return _prepared


func prepare_progress() -> float:
	return 1.0 if _prepared else (0.5 if _selftest_running else 0.0)


## False when Modern cannot draw this stage; fail_reason() says why: "selftest:<reason>", "manifest", "shader",
## "timeout". The session then draws the stage in Arcade.
func healthy() -> bool:
	return _fail == ""


func fail_reason() -> String:
	return _fail


func _process(_delta: float) -> void:
	if not _preparing:
		return
	if _fail == "" and DisplayServer.get_name() != "headless" and selftest.is_empty():
		# the first Modern stage of this run with a real renderer: wait for the render self-test
		if not _selftest_running:
			_run_selftest(self)
		return
	if _fail == "" and not bool(selftest.get("ok", true)):
		_fail = "selftest:" + str(selftest.get("reason", ""))
	_preparing = false
	_prepared = true


## Runs the render self-test and keeps its verdict for the rest of the run. Static: the test outlives a renderer
## that is freed in the middle of it (a member coroutine cannot be resumed once its node is gone); a test that lost
## its renderer has no verdict – the next stage tests again.
static func _run_selftest(parent: Node) -> void:
	_selftest_running = true
	var res: Dictionary = await GfxSelfTest.run(parent)
	_selftest_running = false
	if not bool(res.get("aborted", false)):
		selftest = res


## Draws the frame of `view` (ARCHITECTURE.md §6; Modern also reads hour, dt and player.type).
func render(view: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	_last_view = view
	var pal: Dictionary = view.get("palette", {})
	var ambient: Color = pal.get("ambient", Color.WHITE)
	_sky.color = pal.get("sky_mid", Color.BLACK)
	_plane_mat.albedo_color = Color(Palette.ROAD.r * ambient.r, Palette.ROAD.g * ambient.g, Palette.ROAD.b * ambient.b)
	# Arcade's projection exactly (D12): frustum with a constant focal length in logical pixels at every aspect
	# ratio, the horizon at render.horizon_y_frac of the height, no pitch, no roll. The stub's world is flat: the
	# plane lies proj.cam_height below the camera and moves with it.
	var size := _viewport_size()
	var frustum_h := _near * size.y / proj.focal
	var horizon_frac := proj.horizon_y / proj.screen.y
	var shake: Vector2 = view.get("shake", Vector2.ZERO)
	var offset := Vector2(-shake.x, shake.y) * (_near / proj.focal) + Vector2(0.0, -(0.5 - horizon_frac) * frustum_h)
	_camera.set_frustum(frustum_h, offset, _near, _far)
	_camera.position = Vector3(float(view.get("camera_x", 0.0)), proj.cam_height, 0.0)
	_plane.position = Vector3(_camera.position.x, 0.0, 0.0)
	_cam_snapshot = {"z": float(view.get("camera_z", 0.0)), "x": float(view.get("camera_x", 0.0)),
		"y": float(view.get("camera_y", 0.0)), "yaw_deg": 0.0,
		"frustum": {"size": frustum_h, "offset": offset, "near": _near, "far": _far}}
	_frames += 1
	var us := Time.get_ticks_usec() - t0
	_render_us += us
	_render_us_max = maxi(_render_us_max, us)


## Screen position of a point in road coordinates (z along the road, x lateral, h above the road): (pixel x,
## pixel y, depth in m) in logical pixels of the current picture. Stub: flat, straight world.
func world_to_screen(z: float, x: float, h: float) -> Vector3:
	var size := _viewport_size()
	var depth := z - float(_cam_snapshot.get("z", 0.0))
	var s := proj.focal / maxf(depth, 0.001)
	var horizon := size.y * proj.horizon_y / proj.screen.y
	return Vector3(size.x * 0.5 + (x - float(_cam_snapshot.get("x", 0.0))) * s, horizon - (h - proj.cam_height) * s, depth)


## Logical size of the picture: 1280×720, or more rows/columns where the window has another aspect ratio (the race
## uses stretch aspect "expand" in Modern, D13).
func _viewport_size() -> Vector2:
	var size := proj.screen
	if is_inside_tree():
		var rect := get_viewport().get_visible_rect().size
		if rect.x > 0.0 and rect.y > 0.0:
			size = rect
	return size


func perf_stats() -> Dictionary:
	var n := maxf(1.0, float(_frames))
	return {"mode": Gfx.MODERN, "preset": str(levels.get("preset", "")), "frames": _frames,
		"render_ms_avg": float(_render_us) / n / 1000.0, "render_ms_max": float(_render_us_max) / 1000.0,
		"chunks": 0, "chunk_build_ms_avg": 0.0, "chunk_build_ms_max": 0.0, "chunk_commit_ms_max": 0.0,
		"draw_calls": 0, "draw_calls_shadow": 0, "primitives": 0, "primitives_shadow": 0, "lights_omni": 0,
		"lights_spot": 0, "vehicles": (_last_view.get("cars", []) as Array).size(), "instances": 0,
		"frame_ms_median": 0.0, "frame_ms_p95": 0.0, "prewarm_ms": float(selftest.get("ms", 0.0)),
		"fallback_sets": 0, "tex_mem_mb": 0.0}


## Plain data for headless tests (no render counters): what the renderer shows right now.
func debug_snapshot() -> Dictionary:
	var vehicles: Array = []
	var cars: Array = _last_view.get("cars", [])
	var list: Array = cars.duplicate()
	if _last_view.has("player"):
		list.append(_last_view["player"])
	for c: Variant in list:
		if c is Dictionary:
			var d: Dictionary = c
			vehicles.append({"id": int(d.get("id", 0)) if not bool(d.get("player", false)) else -1, "set": str(d.get("set", "")),
				"model": "", "lod": -1, "z": float(d.get("z", 0.0)), "x": float(d.get("x", 0.0)), "yaw_deg": 0.0, "lamps": {}})
	return {"camera": _cam_snapshot.duplicate(true), "chunks": [], "vehicles": vehicles,
		"lights": {"omni": 0, "spot": 0, "pools": 0}, "props": {}, "signs": [], "quality": levels.duplicate(true),
		"stub": true}
