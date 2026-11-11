extends CanvasLayer
## Backdrop layer of the mode "Modern" (v0.8.0, contract D7, D13, D16): Arcade's RaceBackdrop – sky gradient, sun,
## moon, stars, clouds, every silhouette style of the sceneries with the per-city overrides – drawn on canvas layer
## -10, the background of the 3D picture (Environment.BG_CANVAS, background_canvas_max_layer = -10).
##
##  * Any aspect ratio: the backdrop gets its own RoadProjection whose screen is the LOGICAL size of the picture
##    (1280 × 720, 1280 × 800 on a Steam Deck, 1680 × 720 ultrawide – the race uses stretch aspect "expand") plus a
##    margin to the left and right; the focal length stays the camera's (711 px), so sky and silhouettes turn
##    exactly as far as the 3D world does.
##  * True horizon row: the silhouettes stand on render.horizon_y_frac of the picture height – the row on which the
##    pitch-free camera sees infinitely distant ground. Below it the canvas is the fog colour (what remains
##    visible there is the far end of the world, D16); hills in front are real geometry and cover it.
##  * Heading: view.bg_offset is the panorama angle of the ROAD at the car. The camera also looks into the bend
##    (ChaseCamera3D) and stands behind the car, so the backdrop is turned by the camera's real yaw against the
##    road heading at the car on top of it.
##  * The sun is drawn where the light comes from: the environment rig's sky_palette() (env.state.sun_pos).
##  * Camera shake moves the canvas item like the frustum offset moves the 3D picture.
##  * Inside a tunnel the canvas fades to the tunnel's darkness as long as no tunnel builder draws a tube (the
##    portal ramp of the environment rig); with a tube the outside stays visible through the exit.
##  * --gfx-debug=cover fills the whole canvas with magenta (terrain cover checks count those pixels).
## The canvas is redrawn only when its picture would change by about a quarter of a pixel (heading, time-driven
## clouds and stars, palette, scenery blend, size); between those frames it costs nothing.
## Not drawn here: skyline landmark silhouettes of the destination city (they need the landmark sets – the
## landmarks package) – RaceBackdrop.landmarks stays empty.
## Duck-typed layer: setup(renderer), update(view, dt), snapshot(). Owner: renderer core (R1).

const BACKDROP_LAYER := -10
const COVER := Color(1.0, 0.0, 1.0)
const MARGIN := 48.0               ## drawn beyond the left and right edge (camera shake)
const REDRAW_ANGLE := 0.00035      ## rad of heading (a quarter of a pixel at 711 px focal length)
const REDRAW_S_DAY := 0.09         ## seconds of view time between redraws for the cloud drift (0.004 rad/s)
const REDRAW_S_NIGHT := 0.05       ## … and for the twinkling stars


## The canvas item the backdrop is drawn on.
class Canvas extends Node2D:
	var layer_node: Node

	func _draw() -> void:
		if layer_node != null:
			layer_node.call(&"paint", self)


var canvas: Canvas
var backdrop := RaceBackdrop.new()
var batch := GeoBatch.new()
var sky_proj := RoadProjection.new()   ## projection of the backdrop: logical picture size + margins, the camera's focal

var _renderer: Node
var _cover := false
var _horizon_frac := 0.45
var _draw_distance := 900.0
var _bg_cache: Dictionary = {}
var _pal: Dictionary = {}
var _fog := Color.BLACK
var _heading := 0.0
var _time := 0.0
var _scen_id := ""
var _bg: Dictionary = {}
var _haze := 0.0
var _flat := 0.0                    ## 0..1: canvas faded to the tunnel's darkness
var _size := Vector2(1280.0, 720.0)
var _drawn_heading := 1.0e9
var _drawn_time := -1.0e9
var _drawn_sig: Array = []
var _redraws := 0
var _frames := 0


func _init() -> void:
	layer = BACKDROP_LAYER
	canvas = Canvas.new()
	canvas.name = "Canvas"
	canvas.layer_node = self
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(canvas)


func setup(renderer: Node) -> void:
	_renderer = renderer
	if renderer == null:
		return
	var flags: Variant = renderer.get("debug_flags")
	_cover = flags is Array and (flags as Array).has("cover")
	var proj: RoadProjection = renderer.get("proj")
	var cfg: Variant = renderer.get("cfg")
	var blend_s := 2.5
	if cfg is Dictionary:
		blend_s = float(ConfigLoader.lookup(cfg, "render.background_blend_s", blend_s))
		_draw_distance = maxf(1.0, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", _draw_distance)))
	if proj != null:
		_horizon_frac = proj.horizon_y / maxf(1.0, proj.screen.y)
		sky_proj.focal = proj.focal
		sky_proj.cam_height = proj.cam_height
		sky_proj.cam_distance = proj.cam_distance
		sky_proj.near = proj.near
		_size = proj.screen
	_fit(_size)
	backdrop.setup(sky_proj, batch, blend_s)


func update(view: Dictionary, _dt: float) -> void:
	_frames += 1
	var size := _size
	if is_inside_tree():
		var rect := get_viewport().get_visible_rect().size
		if rect.x > 0.0 and rect.y > 0.0:
			size = rect
	if size != _size:
		_fit(size)
	var pal: Dictionary = view.get("palette", {})
	var env: Node = _renderer.get("env") if _renderer != null else null
	var tunnel01 := 1.0 if bool(view.get("camera_in_tunnel", false)) else 0.0
	var fog: Color = pal.get("fog", Color.BLACK)
	var road_heading := 0.0
	if env != null:
		if env.has_method(&"sky_palette"):
			pal = env.call(&"sky_palette", pal)
		var st: Variant = env.get("state")
		if st is Dictionary and not (st as Dictionary).is_empty():
			tunnel01 = float((st as Dictionary).get("tunnel01", tunnel01))
			fog = (st as Dictionary).get("fog_color", fog)
			road_heading = float((st as Dictionary).get("heading", 0.0))
	_pal = pal
	_fog = fog
	_time = float(view.get("time", 0.0))
	_scen_id = str(view.get("scenery", ""))
	_bg = _background_for(_scen_id)
	_haze = clampf(1.0 - float(view.get("visibility_m", _draw_distance)) / _draw_distance, 0.0, 1.0) * 0.9
	# panorama angle of the camera axis: the road's angle at the car plus the camera's real yaw against that road
	var heading := float(view.get("bg_offset", 0.0))
	var cam: Camera3D = _renderer.get("camera") if _renderer != null else null
	if cam != null and env != null:
		var fwd := -cam.global_transform.basis.z if cam.is_inside_tree() else -cam.transform.basis.z
		heading += wrapf(atan2(fwd.x, -fwd.z) - road_heading, -PI, PI)
	_heading = heading
	_flat = tunnel01 if (_renderer == null or _renderer.call(&"builder", "tunnel") == null) else 0.0
	canvas.position = Vector2(-MARGIN, 0.0) + (view.get("shake", Vector2.ZERO) as Vector2)
	# redraw only when the picture changes
	var sig := [_size, _cover, _scen_id, _flat, _haze, pal.get("sky_top"), pal.get("sky_bottom"), pal.get("ambient"), fog,
		pal.get("sun_pos"), pal.get("moon_pos"), pal.get("stars"), backdrop._blend < 1.0]
	var every := REDRAW_S_NIGHT if float(pal.get("stars", 0.0)) > 0.02 else REDRAW_S_DAY
	if sig != _drawn_sig or absf(wrapf(_heading - _drawn_heading, -PI, PI)) > REDRAW_ANGLE or absf(_time - _drawn_time) >= every \
			or backdrop._blend < 1.0:
		_drawn_sig = sig
		_drawn_heading = _heading
		_drawn_time = _time
		canvas.queue_redraw()


## Draws the backdrop on its canvas item (called from Canvas._draw).
func paint(item: CanvasItem) -> void:
	_redraws += 1
	var w := sky_proj.screen.x
	var h := sky_proj.screen.y
	batch.begin(item.get_canvas_item())
	if _cover or _pal.is_empty():
		batch.rect(Rect2(0.0, -MARGIN, w, h + 2.0 * MARGIN), COVER if _cover else Color.BLACK)
		batch.flush()
		return
	if _flat < 0.999:
		var base_y := sky_proj.horizon_y
		backdrop.draw_sky(_pal, _heading, _time)
		backdrop.draw_background(_pal, _scen_id, _bg, _heading, _time, _haze, base_y)
		batch.rect(Rect2(0.0, base_y, w, h - base_y + MARGIN), _fog)
	if _flat > 0.001:
		batch.rect(Rect2(0.0, -MARGIN, w, h + 2.0 * MARGIN), Color(Palette.TUNNEL_FOG, _flat))
	batch.flush()


## Colour the canvas shows at a logical pixel of the picture (tests): redraws nothing, samples the laws of
## RaceBackdrop.draw_sky for the plain gradient – valid away from sun, moon, clouds and silhouettes.
func gradient_at(row: float) -> Color:
	if _cover:
		return COVER
	var hy := sky_proj.horizon_y
	var my := hy * 0.52
	var c: Color = _fog
	if row < my:
		c = (_pal.get("sky_top", Color.BLACK) as Color).lerp(_pal.get("sky_mid", Color.BLACK), clampf((row + 40.0) / (my + 40.0), 0.0, 1.0))
	elif row < hy:
		c = (_pal.get("sky_mid", Color.BLACK) as Color).lerp(_pal.get("sky_bottom", Color.BLACK), clampf((row - my) / (hy + 3.0 - my), 0.0, 1.0))
	return c.lerp(Palette.TUNNEL_FOG, _flat)


func snapshot() -> Dictionary:
	return {"backdrop": {"plain": false, "cover": _cover, "flat": _flat >= 0.999, "tunnel": snappedf(_flat, 0.001),
		"horizon_frac": _horizon_frac, "horizon_row": snappedf(sky_proj.horizon_y, 0.01), "size": [_size.x, _size.y],
		"heading": snappedf(_heading, 0.00001), "scenery": _scen_id, "redraws": _redraws, "frames": _frames}}


## The backdrop's projection for a picture of `size` logical pixels: wider by the margins, horizon on its fraction.
func _fit(size: Vector2) -> void:
	_size = size
	sky_proj.screen = Vector2(size.x + 2.0 * MARGIN, size.y)
	sky_proj.horizon_y = size.y * _horizon_frac
	_drawn_sig = []


## Scenery background with the per-city overrides (cities.json "background") inside the City Limits – the rule of
## RoadRenderer._background_for.
func _background_for(scen_id: String) -> Dictionary:
	var db: Variant = _renderer.get("scenery_db") if _renderer != null else null
	var scen: Dictionary = (db as Dictionary).get(scen_id, {}) if db is Dictionary else {}
	var bg: Dictionary = scen.get("background", {})
	var track: Track = _renderer.get("track") if _renderer != null else null
	if track == null or track.plan == null or not scen_id.begins_with("city"):
		return bg
	var over: Dictionary = track.plan.city_background
	if over.is_empty():
		return bg
	var c: Variant = _bg_cache.get(scen_id)
	if c == null:
		var m := bg.duplicate(true)
		for key: String in over:
			m[key] = over[key]
		_bg_cache[scen_id] = m
		c = m
	return c
