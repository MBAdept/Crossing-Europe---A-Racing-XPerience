extends CanvasLayer
## Backdrop layer of the mode "Modern" (v0.8.0, contract D7, D13, D16): Arcade's RaceBackdrop – sky gradient, sun,
## moon, stars, clouds, every silhouette style of the sceneries with the per-city overrides – drawn on canvas layer
## -10, the background of the 3D picture (Environment.BG_CANVAS, background_canvas_max_layer = -10).
##
##  * Any aspect ratio: the backdrop gets its own RoadProjection whose screen is the LOGICAL size of the picture
##    (1280 × 720, 1280 × 800 on a Steam Deck, 1680 × 720 ultrawide – the race uses stretch aspect "expand") plus a
##    margin to the left and right; the focal length stays the camera's (711 px), so sky and silhouettes turn
##    exactly as far as the 3D world does.
##  * Horizon row: the silhouettes stand on render.horizon_y_frac of the picture height – the row on which the
##    pitch-free camera sees infinitely distant ground – or, where the road ahead rises above that row, on the
##    highest row the road reaches up to the sight (Arcade's crest rule, at most 120 rows higher: RoadRenderer._draw,
##    base_y = max(clip, hy - 120)). The lift is lift_rows; the far ground's rim stands up to the same row
##    (layers/far_ground.gd), so below the silhouettes the picture is land, never the canvas (RINT-B). Below the
##    base row the canvas is the fog colour, as Arcade fills it.
##  * Heading: view.bg_offset is the panorama angle of the ROAD at the car. The camera also looks into the bend
##    (ChaseCamera3D) and stands behind the car, so the backdrop is turned by the camera's real yaw against the
##    road heading at the car on top of it.
##  * The sun disc: the environment rig's sky_palette() – since R4 Arcade's place (ahead, high at noon), where a low
##    sun's light also comes from.
##  * Camera shake moves the canvas item like the frustum offset moves the 3D picture.
##  * Inside a tunnel the canvas fades to the tunnel's darkness as long as no tunnel builder draws a tube (the
##    portal ramp of the environment rig); with a tube the outside stays visible through the exit.
##  * --gfx-debug=cover fills the whole canvas with magenta (terrain cover checks count those pixels).
## The canvas is redrawn only when its picture would change by about a quarter of a pixel (heading, time-driven
## clouds and stars, palette, scenery blend, size); between those frames it costs nothing.
##  * R7b: the SKYLINE of the destination city (cities.json "skyline") inside the City Limits, as Arcade draws it
##    (RoadRenderer._skyline_silhouettes / _draw_skyline_landmark, frozen): each silhouette anchored to the panorama
##    when first seen – one that also stands on the road as a landmark starts in its true direction from the camera
##    (in 3D: the direction of its anchor on the path) – then turning with the panorama, faded out while that
##    landmark is within its landmark range (the 3D landmark of builders/landmarks.gd takes over: no double), at
##    render.skyline_distance_m in size. A sprite silhouette is the "c" cell of its sheet (and its light layer at night),
##    a procedural one Arcade's own 2D drawing (RoadRenderer._draw_landmark_proc through a RoadRenderer instance that is
##    never in the tree, drawing into this canvas through its GeoBatch). Sheets are resolved in prepare().
##  * R7d (A-27): the SKY itself is assets/shaders/modern/sky2d.gdshader on its own node behind the canvas (Arcade's
##    gradient, glow, stars, moon and sun at Arcade's places, and the cloud layer of CloudField instead of Arcade's
##    cloud sprites); the canvas keeps the silhouettes, skylines, landmarks, the fog below the horizon row, the tunnel
##    darkness and the debug cover in front of it. graphics.modern.sky2d false draws Arcade's sky again.
## Duck-typed layer: setup(renderer), prepare(ctx), update(view, dt), rebased(shift), snapshot(). Owner: renderer core
## (R1); the skyline: package R7 (wave 5: R7b); the sky: R7d.

const BACKDROP_LAYER := -10
const COVER := Color(1.0, 0.0, 1.0)
const MARGIN := 48.0               ## drawn beyond the left and right edge (camera shake)
const REDRAW_ANGLE := 0.00035      ## rad of heading (a quarter of a pixel at 711 px focal length)
const REDRAW_S_DAY := 0.09         ## seconds of view time between redraws for the cloud drift (0.004 rad/s)
const REDRAW_S_NIGHT := 0.05       ## … and for the twinkling stars
const LIFT_MAX := 120.0            ## Arcade's crest rule: the silhouettes rise at most this many rows above the horizon
const LIFT_STEP := 0.25            ## the canvas is redrawn when the base row moved by this many rows
const SKY_ALPHA_STEP := 0.05       ## a skyline silhouette fades in steps of this alpha (FIX-R7b, B-06)


## The canvas item the backdrop is drawn on.
class Canvas extends Node2D:
	var layer_node: Node

	func _draw() -> void:
		if layer_node != null:
			layer_node.call(&"paint", self)


## R7d: the node of the sky shader – one rectangle over the canvas' area, in the canvas' own coordinates.
class SkyNode extends Node2D:
	var rect := Rect2(0.0, -48.0, 1376.0, 816.0)

	func _draw() -> void:
		draw_rect(rect, Color.WHITE)


const SKY_SHADER := "res://assets/shaders/modern/sky2d.gdshader"
const CLOUD_SHADER := "res://assets/shaders/modern/clouds2d.gdshader"
const CLOUD_SCALE := 2.0                ## canvas pixels per pixel of the cloud viewport (half resolution)
const SKY_STEPS := 16                   ## sky_steps without a Gfx level


var canvas: Canvas
var backdrop := RaceBackdrop.new()
var batch := GeoBatch.new()
var sky_proj := RoadProjection.new()   ## projection of the backdrop: logical picture size + margins, the camera's focal
var lift_rows := 0.0                   ## rows the silhouettes stand above the horizon row (Arcade's crest rule)

var _h_first := 0                      ## segment index of _h[0]
var _h := PackedFloat32Array()         ## heights of the segments from _h_first on (Track.get_segment(i).y)
var _drawn_lift := -1.0

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
# R7b: skyline silhouettes (Arcade's RoadRenderer._skyline_silhouettes)
var _sky_painter: RoadRenderer          ## draws Arcade's procedural silhouettes into this canvas; never in the tree
var _sky_anchor: Dictionary = {}        ## skyline index -> panorama angle (rad), fixed when first seen
var _sky_dist := 1800.0                 ## render.skyline_distance_m
var _lm_law := Vector2(2.0, 1900.0)     ## render.landmark_range_factor, render.landmark_far_m
var _sky_sig: Array = []
var _sky_list: Array = []               ## this frame's silhouettes (snapshot)
# R7d: the sky shader
var sky_node: SkyNode
var _sky_mat: ShaderMaterial
var cloud_vp: SubViewport               ## the cloud layer at half resolution (clouds2d.gdshader), read by the sky shader
var _cloud_node: SkyNode                ## its rectangle
var _cloud_mat: ShaderMaterial
var _sky2d := true                      ## graphics.modern.sky2d
var _sky_steps := SKY_STEPS             ## most samples of a view ray through the clouds (Gfx level "sky_steps")
var _shift_total := Vector2.ZERO        ## sum of the floating origin's shifts (x, z): the cloud field stays in the world
var _cloud: Dictionary = {}             ## this frame's cloud values (snapshot)
var _tunnel01 := 0.0                    ## the environment rig's tunnel ramp of this frame


func _init() -> void:
	layer = BACKDROP_LAYER
	sky_node = SkyNode.new()
	sky_node.name = "Sky"
	add_child(sky_node)
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
		_sky_dist = maxf(200.0, float(ConfigLoader.lookup(cfg, "render.skyline_distance_m", _sky_dist)))
		_lm_law = Vector2(float(ConfigLoader.lookup(cfg, "render.landmark_range_factor", 2.0)),
			float(ConfigLoader.lookup(cfg, "render.landmark_far_m", 1900.0)))
		_sky2d = bool(ConfigLoader.lookup(cfg, "graphics.modern.sky2d", true))
	sky_node.visible = _sky2d
	if _sky2d and _sky_mat == null:
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = load(SKY_SHADER) as Shader
		sky_node.material = _sky_mat
		_build_clouds()
		ModernMaterials.set_global("ce_cloud_tex", CloudField.texture())
	if not _sky2d:
		ModernMaterials.set_global("ce_cloud", Vector4(1.0, CloudField.SOFT, 0.0, 0.0))
	if proj != null:
		_horizon_frac = proj.horizon_y / maxf(1.0, proj.screen.y)
		sky_proj.focal = proj.focal
		sky_proj.cam_height = proj.cam_height
		sky_proj.cam_distance = proj.cam_distance
		sky_proj.near = proj.near
		_size = proj.screen
	_fit(_size)
	backdrop.setup(sky_proj, batch, blend_s)
	backdrop.sprite_cb = _draw_skyline_landmark


## R7d: the samples of a view ray through the clouds (Gfx level "sky_steps" of the effects level).
func apply_quality(levels: Dictionary) -> void:
	_sky_steps = clampi(int(levels.get("sky_steps", SKY_STEPS)), 4, 64)
	if _cloud_mat != null:
		_cloud_mat.set_shader_parameter("steps", _sky_steps)


## The slowness watchdog lowered the preset during the countdown: the sky takes the lower level's samples too.
func quality_lowered(levels: Dictionary) -> void:
	apply_quality(levels)


## R7b: the skyline's pictures are resolved (and their sheets loaded) behind the loading cover, not in the race.
func prepare(_ctx: Dictionary) -> void:
	var track: Track = _renderer.get("track") if _renderer != null else null
	if track == null or track.plan == null or track.plan.skyline.is_empty():
		return
	var p := _painter()
	for e: Dictionary in track.plan.skyline:
		p.call(&"_prep_prop", e)


func _painter() -> RoadRenderer:
	if _sky_painter == null:
		_sky_painter = RoadRenderer.new()
		_sky_painter.batch = batch
		_sky_painter.proj = sky_proj
	return _sky_painter


func _exit_tree() -> void:
	if _sky_painter != null:
		_sky_painter.free()
		_sky_painter = null


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
			_tunnel01 = tunnel01
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
	# FIX1: with a tube (builders/tunnel.gd) the canvas stays dark too while the exit lies beyond the sight – the
	# tube ends where the loaded chunks end, and Arcade draws its backdrop in a tunnel only once the exit is in view
	# (RoadRenderer._tunnel_exit_visible)
	if _renderer == null or _renderer.call(&"builder", "tunnel") == null or not _exit_in_sight(view):
		_flat = tunnel01
	else:
		_flat = 0.0
	canvas.position = Vector2(-MARGIN, 0.0) + (view.get("shake", Vector2.ZERO) as Vector2)
	if _sky2d:
		sky_node.position = canvas.position
		var cam_xz := Vector2.ZERO
		var cam_heading := 0.0
		if cam != null:
			var ct := cam.global_transform if cam.is_inside_tree() else cam.transform
			cam_xz = Vector2(ct.origin.x, ct.origin.z)
			var f := -ct.basis.z
			cam_heading = atan2(f.x, -f.z)
		var to_sun := Vector3.UP
		if env != null:
			var st2: Variant = env.get("state")
			if st2 is Dictionary:
				to_sun = (st2 as Dictionary).get("to_sun", to_sun)
		_update_sky(pal, cam_xz, cam_heading, to_sun)
	backdrop.landmarks = skyline(view, heading)
	var lift := crest_lift(view)
	if absf(lift - _drawn_lift) >= LIFT_STEP or (lift == 0.0 and _drawn_lift != 0.0):
		_drawn_lift = lift
	lift_rows = maxf(_drawn_lift, 0.0)          # the row the canvas draws on – the far ground's rim takes the same
	# redraw only when the picture changes
	var sig := [_size, _cover, _scen_id, _flat, _haze, pal.get("sky_top"), pal.get("sky_bottom"), pal.get("ambient"), fog,
		pal.get("sun_pos"), pal.get("moon_pos"), pal.get("stars"), backdrop._blend < 1.0, _drawn_lift, _sky_sig]
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
		var base_y := sky_proj.horizon_y - lift_rows
		if not _sky2d:
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
		"heading": snappedf(_heading, 0.00001), "scenery": _scen_id, "redraws": _redraws, "frames": _frames,
		"lift_rows": snappedf(lift_rows, 0.01), "base_row": snappedf(sky_proj.horizon_y - lift_rows, 0.01),
		"skyline": _sky_list.duplicate(true), "sky2d": _sky2d, "clouds": _cloud.duplicate(true)}}


## True when the camera is in a tunnel whose exit lies within the sight (view.visibility_m), or not in a tunnel.
func _exit_in_sight(view: Dictionary) -> bool:
	var track: Track = _renderer.get("track") if _renderer != null else null
	if track == null or track.plan == null:
		return true
	var cam_z := float(view.get("camera_z", 0.0))
	var t: Dictionary = track.plan.tunnel_at(track.z_to_km(cam_z))
	if t.is_empty():
		return true
	return track.km_to_z(float(t["end_km"])) - cam_z <= float(view.get("visibility_m", _draw_distance))


## Arcade's crest rule (RoadRenderer._draw / _project: base_y = max(clip[n], hy - 120) when the clip row of the
## farthest row lies above the horizon row): how many rows above the horizon row the highest road row up to the
## sight stands – rows k = 0 … vis / seg_len + 2 from the camera's segment, (y_k - camera_y) * focal / dz_k for every
## row in front of the near plane – at most LIFT_MAX, 0 when the road ahead stays below the horizon.
## The heights are cached by segment index (a few new segments per frame).
func crest_lift(view: Dictionary) -> float:
	var track: Track = _renderer.get("track") if _renderer != null else null
	var proj: RoadProjection = _renderer.get("proj") if _renderer != null else null
	if track == null or proj == null or track.segment_count < 3:
		return 0.0
	var seg_len := track.seg_len
	var cam_z := float(view.get("camera_z", 0.0))
	var cam_y := float(view.get("camera_y", 0.0))
	var vis := float(view.get("visibility_m", _draw_distance))
	var base := mini(int(floor(cam_z / seg_len)), track.segment_count - 2)
	var count := maxi(1, mini(int(vis / seg_len) + 2, track.segment_count - 1 - base))
	var first := maxi(base, 0)
	_cache_heights(track, first, base + count)
	var best := 0.0
	var focal := proj.focal
	var near := proj.near
	for k in count + 1:
		var i := base + k
		var dz := float(i) * seg_len - cam_z
		if dz <= near:
			continue
		var up := (_h[maxi(i, 0) - _h_first] - cam_y) * focal / dz
		if up > best:
			best = up
	return minf(best, LIFT_MAX)


func _cache_heights(track: Track, first: int, last: int) -> void:
	if _h.is_empty() or first < _h_first or first > _h_first + _h.size():
		_h_first = first
		_h = PackedFloat32Array()
	elif first > _h_first:
		_h = _h.slice(first - _h_first)
		_h_first = first
	for i in range(_h_first + _h.size(), last + 1):
		_h.append(track.get_segment(i).y)


## The backdrop's projection for a picture of `size` logical pixels: wider by the margins, horizon on its fraction.
func _fit(size: Vector2) -> void:
	_size = size
	sky_proj.screen = Vector2(size.x + 2.0 * MARGIN, size.y)
	sky_proj.horizon_y = size.y * _horizon_frac
	_drawn_sig = []
	sky_node.rect = Rect2(0.0, -MARGIN, sky_proj.screen.x, size.y + 2.0 * MARGIN)
	sky_node.queue_redraw()
	if cloud_vp != null:
		var r := sky_node.rect
		var vs := Vector2i(int(ceil(r.size.x / CLOUD_SCALE)), int(ceil(r.size.y / CLOUD_SCALE)))
		cloud_vp.size = vs
		_cloud_node.rect = Rect2(Vector2.ZERO, Vector2(vs))
		_cloud_node.queue_redraw()
		_cloud_mat.set_shader_parameter("px_scale", r.size / Vector2(vs))
		_cloud_mat.set_shader_parameter("origin", r.position)
		_sky_mat.set_shader_parameter("clouds_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))


## R7d: the cloud layer – a viewport of its own at 1 / CLOUD_SCALE of the canvas' resolution, drawn every frame by
## clouds2d.gdshader (premultiplied colour and coverage, transparent where there is no cloud) and laid over the sky by
## sky2d.gdshader. A view ray through the clouds costs more than the rest of the sky; the clouds are soft.
func _build_clouds() -> void:
	cloud_vp = SubViewport.new()
	cloud_vp.name = "Clouds"
	cloud_vp.disable_3d = true
	cloud_vp.transparent_bg = true
	cloud_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cloud_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	cloud_vp.size = Vector2i(688, 408)
	_cloud_node = SkyNode.new()
	_cloud_node.name = "CloudRect"
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = load(CLOUD_SHADER) as Shader
	_cloud_mat.set_shader_parameter("cloud_tex", CloudField.texture())
	_cloud_mat.set_shader_parameter("field", Vector4(CloudField.TILE_M, CloudField.HEIGHT_M, CloudField.DETAIL.x, CloudField.DETAIL.y))
	_cloud_mat.set_shader_parameter("weights", CloudField.W)
	_cloud_mat.set_shader_parameter("thick", CloudField.THICK_M)
	_cloud_mat.set_shader_parameter("column_k", CloudField.COLUMN_K)
	_cloud_mat.set_shader_parameter("n_max", CloudField.n_max())
	_cloud_mat.set_shader_parameter("steps", _sky_steps)
	_cloud_node.material = _cloud_mat
	cloud_vp.add_child(_cloud_node)
	add_child(cloud_vp)
	_sky_mat.set_shader_parameter("clouds", cloud_vp.get_texture())
	_sky_mat.set_shader_parameter("clouds_on", 1.0)


## R7d: the values of the sky shader for this frame – the projection, the camera in the cloud field, the light, and
## Arcade's places of sun, moon and stars (RaceBackdrop.draw_sky's formulas), the palette's colours, the cover.
func _update_sky(pal: Dictionary, cam_xz: Vector2, cam_heading: float, to_sun: Vector3) -> void:
	if _sky_mat == null or pal.is_empty():
		return
	var w := sky_proj.screen.x
	var hy := sky_proj.horizon_y
	var f := sky_proj.focal
	var m := _sky_mat
	var cm := _cloud_mat
	var overcast := clampf(float(pal.get("overcast", 0.0)), 0.0, 1.0)
	var cover := CloudField.cover_for(pal)
	var field := CloudField.field_pos(cam_xz, _shift_total, _time)
	var sc: Color = pal.get("sun", Color.WHITE)
	var sun_pos: Vector2 = pal.get("sun_pos", Vector2(0.0, 0.5))
	var sun_x := w * 0.5 + RaceBackdrop.wrap_angle(sun_pos.x * 1.1 - _heading) * f
	var sun_y := hy - (hy - 30.0) * pow(maxf(sun_pos.y, 0.0), 0.8) + 6.0
	var sun_on := bool(pal.get("sun_visible", false)) and sun_x > -120.0 and sun_x < w + 120.0
	var sun_disc := Vector3(sun_x, sun_y, 1.0 if sun_on else 0.0)
	var mp: Vector2 = pal.get("moon_pos", Vector2(0.0, 0.5))
	var mx := w * 0.5 + RaceBackdrop.wrap_angle(mp.x * 1.1 + 0.4 - _heading) * f
	var mz := hy - (hy - 50.0) * mp.y - 20.0
	var moon_on := bool(pal.get("moon_visible", false)) and mx > -60.0 and mx < w + 60.0
	# what both draw
	for mat: ShaderMaterial in [m, cm]:
		mat.set_shader_parameter("screen", sky_proj.screen)
		mat.set_shader_parameter("horizon_y", hy)
		mat.set_shader_parameter("focal", f)
		mat.set_shader_parameter("sky_top", pal.get("sky_top", Color.BLACK))
		mat.set_shader_parameter("sky_bottom", pal.get("sky_bottom", Color.BLACK))
		mat.set_shader_parameter("cloud_shade", pal.get("cloud_dark", Color.GRAY))
		mat.set_shader_parameter("overcast", overcast)
		mat.set_shader_parameter("sun_disc", sun_disc)
	# the sky: Arcade's gradient, glow, stars, moon and sun
	m.set_shader_parameter("pan", _heading)
	m.set_shader_parameter("time", _time)
	m.set_shader_parameter("sky_mid", pal.get("sky_mid", Color.BLACK))
	m.set_shader_parameter("glow", pal.get("glow", Color.BLACK))
	m.set_shader_parameter("sun", Vector3(sc.r, sc.g, sc.b))
	m.set_shader_parameter("moon_disc", Vector3(mx, mz, 1.0 if moon_on else 0.0))
	m.set_shader_parameter("stars", float(pal.get("stars", 0.0)))
	# the cloud layer
	cm.set_shader_parameter("cam_heading", cam_heading)
	cm.set_shader_parameter("cam_field", field)
	cm.set_shader_parameter("to_sun", to_sun)
	cm.set_shader_parameter("cloud_lit", pal.get("cloud", Color.WHITE))
	cm.set_shader_parameter("threshold", CloudField.threshold(cover))
	cm.set_shader_parameter("cover", cover)
	cm.set_shader_parameter("night", clampf(float(pal.get("night", 0.0)), 0.0, 1.0))
	# the cloud shadows on the land: the same field (inc/cloud_shadow.gdshaderinc)
	var strength := CloudField.shadow_strength(pal, _tunnel01)
	var origin_field := CloudField.field_pos(Vector2.ZERO, _shift_total, _time)
	ModernMaterials.set_global("ce_cloud", Vector4(CloudField.threshold(cover), CloudField.SOFT, strength, 0.0))
	ModernMaterials.set_global("ce_cloud_pos", Vector4(origin_field.x, origin_field.y, CloudField.TILE_M, CloudField.HEIGHT_M))
	_cloud = {"cover": snappedf(cover, 0.001), "field": [snappedf(field.x, 0.1), snappedf(field.y, 0.1)], "shadow": snappedf(strength, 0.0001),
		"heading": snappedf(cam_heading, 0.0001), "sun": sun_on, "moon": moon_on}


## The floating origin moved: the cloud field stays where it is in the world.
func rebased(shift: Vector3) -> void:
	_shift_total += Vector2(shift.x, shift.z)


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


# --- skyline (R7b) -------------------------------------------------------------------------------------------------

## The skyline silhouettes of this frame for RaceBackdrop.landmarks: Arcade's RoadRenderer._skyline_silhouettes –
## only inside the City Limits (the camera's ground point), each faded out while its landmark is within the landmark
## range (smoothstep(L, 1.15 L, its distance)), anchored to the panorama when first seen. heading = the panorama angle
## of the screen centre (the road's angle at the car plus the camera's yaw against it).
func skyline(view: Dictionary, heading: float) -> Array:
	_sky_list = []
	_sky_sig = []
	var track: Track = _renderer.get("track") if _renderer != null else null
	var proj: RoadProjection = _renderer.get("proj") if _renderer != null else null
	if track == null or track.plan == null or proj == null:
		return []
	var sky: Array[Dictionary] = track.plan.skyline
	var cam_z := float(view.get("camera_z", 0.0))
	if sky.is_empty() or not track.is_city_at(cam_z + proj.cam_distance):
		return []
	# a silhouette is anchored when first seen: not before the camera stands where the stage shows it (while the stage
	# is prepared the camera's yaw is not yet the one of the start view)
	if _renderer.has_method(&"is_prepared") and not bool(_renderer.call(&"is_prepared")):
		return []
	var vis := float(view.get("visibility_m", _draw_distance))
	var l := clampf(vis * _lm_law.x, minf(vis, 600.0), maxf(_lm_law.y, vis))
	var out: Array = []
	for i in sky.size():
		var e: Dictionary = sky[i]
		var a := 1.0
		var prop_km := float(e.get("prop_km", -1.0))
		var dz := 0.0
		if prop_km >= 0.0:
			dz = track.km_to_z(prop_km) - cam_z
			a = smoothstep(l, l * 1.15, dz) if dz > 0.0 else 0.0
		# FIX-R7b (QA-R7b B-06): the fade in steps of SKY_ALPHA_STEP – the step drawn is the step of the signature, so a
		# fade alone redraws the canvas 20 times, not 67 (a redraw with silhouettes costs +0.1 … 0.3 ms, measured)
		a = snappedf(a, SKY_ALPHA_STEP)
		if a <= 0.01:
			continue
		if not _sky_anchor.has(i):
			_sky_anchor[i] = heading + skyline_offset(i, e, dz, track)
		out.append({"entry": e, "angle": float(_sky_anchor[i]), "alpha": a, "s": sky_proj.focal / _sky_dist})
		_sky_list.append({"set": str(e.get("set", "")), "angle": snappedf(float(_sky_anchor[i]), 0.0001), "alpha": snappedf(a, 0.001),
			"x": snappedf(sky_proj.screen.x * 0.5 - MARGIN + RaceBackdrop.wrap_angle(float(_sky_anchor[i]) - heading) * sky_proj.focal, 0.1)})
		_sky_sig.append(a)
		_sky_sig.append(i)
	return out


## Panorama offset of skyline entry i against the screen centre when it is first seen (RoadRenderer._skyline_offset):
## its azimuth_deg if given; for one that also stands on the road as a landmark the true direction of that landmark
## from the camera (its anchor on the path, against the camera's axis); else Arcade's fixed offsets.
func skyline_offset(i: int, e: Dictionary, dz: float, track: Track) -> float:
	var az := float(e.get("azimuth_deg", NAN))
	if not is_nan(az):
		return deg_to_rad(az)
	if dz > 0.0:
		var cam: Camera3D = _renderer.get("camera") if _renderer != null else null
		var path: Variant = _renderer.get("path") if _renderer != null else null
		if cam != null and path is RoadPath3D and (path as RoadPath3D).is_ready():
			for it: Dictionary in track.landmarks:
				if str(it["set"]) != str(e["set"]):
					continue
				var z := float(it["z"])
				var k := int(floor(z / track.seg_len))
				if not ((path as RoadPath3D).has(k) and (path as RoadPath3D).has(k + 1)):
					break
				var x := float(it.get("x", 0.0))
				if it.has("proc"):
					x += float(int(it.get("side", 1))) * float(it.get("width_m", 30.0)) * 0.5 * float(it.get("scale", 1.0))
				var t := cam.global_transform if cam.is_inside_tree() else cam.transform
				var local := t.affine_inverse() * (path as RoadPath3D).world(z, x, 0.0)
				return atan2(local.x, -local.z)
	return RoadRenderer.SKY_OFFSETS[i % RoadRenderer.SKY_OFFSETS.size()]


## RaceBackdrop.sprite_cb: one skyline silhouette standing on the panorama base line at pos (s = px per m) – Arcade's
## RoadRenderer._draw_skyline_landmark: the "c" cell of its sprite × the ambient light towards the fog × 1.15 by the
## haze, tinted, with its light layer at night; or Arcade's procedural silhouette.
func _draw_skyline_landmark(entry: Dictionary, pos: Vector2, s: float, alpha: float, haze: float) -> void:
	var p := _painter()
	var pc: Array = p.call(&"_prep_prop", entry)
	var amb: Color = _pal.get("ambient", Color.WHITE)
	var lights := float(_pal.get("lights", 0.0)) * alpha
	p.set(&"_amb_out", amb)
	p.set(&"_fog_outc", _fog)
	p.set(&"_lm_amb", amb)
	p.set(&"_lm_haze", haze)
	p.set(&"_lm_alpha", alpha)
	p.set(&"_time", _time)
	var info: Array = pc[1]
	var anchor := Vector3(pos.x, pos.y, s)
	if not info.is_empty():
		var tint: Color = pc[5]
		var mod := Color(amb.r, amb.g, amb.b).lerp(_fog * 1.15, haze)
		_sky_cell(info, "base", anchor, float(pc[2]), Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, alpha))
		if lights > 0.02 and (info[RoadRenderer.SI_ROWS] as Dictionary).has("lights"):
			_sky_cell(info, "lights", anchor, float(pc[2]), Color(1, 1, 1, lights))
	elif str(pc[4]) != "":
		p.call(&"_draw_landmark_proc", str(pc[4]), entry, anchor, lights)


## Draws the "c" cell of `layer` of a sprite (Arcade's info array) with its anchor at p (x, y, px per m) into this
## canvas – RoadRenderer._sprite_cell, but onto the backdrop's canvas item.
func _sky_cell(info: Array, layer: String, p: Vector3, scale: float, modulate: Color) -> void:
	var row := int((info[RoadRenderer.SI_ROWS] as Dictionary).get(layer, -1))
	if row < 0:
		return
	var cell: Vector2 = info[RoadRenderer.SI_CELL]
	var w := cell.x / float(info[RoadRenderer.SI_PPM]) * p.z * scale
	var h := w * cell.y / cell.x
	if w < 0.8:
		return
	var dest := RoadRenderer.sprite_dest(Vector2(p.x, p.y), w, h, info[RoadRenderer.SI_ANCHOR], false)
	if dest.position.x > sky_proj.screen.x + 4.0 or dest.end.x < -4.0:
		return
	var ai := int((info[RoadRenderer.SI_COLS] as Dictionary).get("c", 0))
	var tex: Texture2D = info[RoadRenderer.SI_TEX]
	batch.flush()
	RenderingServer.canvas_item_add_texture_rect_region(canvas.get_canvas_item(), dest, tex.get_rid(),
		RoadRenderer.cell_src(info, ai, row), modulate)
