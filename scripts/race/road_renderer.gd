class_name RoadRenderer
extends Node2D
## Pseudo-3D road renderer (Node2D with _draw, design document "Darstellung und Technik").
## Every frame ~300 short segments are projected (near -> far, accumulating curve offsets) and then
## drawn back to front (painter's algorithm) together with props, signs and vehicle sprites, so hills
## hide what lies behind them. Tunnels use portal/exit faces plus walls and ceiling per segment.
## Owner: race module. Input: render(view) once per frame (see ARCHITECTURE.md §Renderer-View).

var track: Track
var proj: RoadProjection
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var view: Dictionary = {}
var font: Font

var _idx := PackedInt32Array()
var _bv := PackedVector2Array()
var _bc := PackedColorArray()

# projected points of the current frame (k = 0 is the segment under the camera)
var _n := 0
var _base := 0
var _dz := PackedFloat32Array()
var _xw := PackedFloat32Array()
var _yw := PackedFloat32Array()
var _hd := PackedFloat32Array()
var _sx := PackedFloat32Array()
var _sy := PackedFloat32Array()
var _ss := PackedFloat32Array()
var _segs: Array[TrackSegment] = []
var _cam_y := 0.0
var _vis := 900.0
var _fog_start := 400.0
var _stars: PackedVector3Array
var _cam_in_tunnel := false


func setup(t: Track, p: RoadProjection, config: Dictionary, scenery: Dictionary) -> void:
	track = t
	proj = p
	cfg = config
	scenery_db = scenery
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_idx.resize(120000)
	for i in _idx.size():
		_idx[i] = i
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_stars = PackedVector3Array()
	for i in 160:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.95, rng.randf_range(0.6, 2.0)))


func render(v: Dictionary) -> void:
	view = v
	queue_redraw()


# --- batching -------------------------------------------------------------------------------

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_bv.append(a)
	_bv.append(b)
	_bv.append(c)
	_bv.append(a)
	_bv.append(c)
	_bv.append(d)
	for i in 6:
		_bc.append(col)


func _flush() -> void:
	var n := _bv.size()
	if n == 0:
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx.slice(0, n), _bv, _bc)
	_bv.clear()
	_bc.clear()


# --- frame ----------------------------------------------------------------------------------

func _draw() -> void:
	if track == null or view.is_empty():
		return
	var pal: Dictionary = view["palette"]
	var shake: Vector2 = view.get("shake", Vector2.ZERO)
	draw_set_transform(shake)
	_draw_sky(pal)
	_project_points()
	_draw_background(pal)
	_draw_road_and_sprites(pal)
	if float(pal.get("lights", 0.0)) > 0.25 and not _cam_in_tunnel:
		_draw_headlights(pal)
	_draw_weather(pal)
	draw_set_transform(Vector2.ZERO)


func _project_points() -> void:
	var cam_z := float(view["camera_z"])
	var cam_x := float(view["camera_x"])
	_cam_y = float(view["camera_y"])
	_vis = float(view.get("visibility_m", 900.0))
	_fog_start = _vis * float(ConfigLoader.lookup(cfg, "render.fog_start_frac", 0.45))
	var seg_len := track.seg_len
	var k_curve := seg_len * seg_len / float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	_base = track.segment_index_at(cam_z)
	var count := int(_vis / seg_len) + 2
	_n = count
	for arr in [_dz, _xw, _yw, _hd, _sx, _sy, _ss]:
		arr.resize(count + 1)
	_segs.resize(count + 1)
	var s0 := track.get_segment(_base)
	_cam_in_tunnel = s0.tunnel
	var frac := (cam_z - _base * seg_len) / seg_len
	var x := 0.0
	var dx := -s0.curve * k_curve * frac
	var half_w := proj.screen.x * 0.5
	for k in count + 1:
		var idx := mini(_base + k, track.segment_count - 1)
		var seg := track.get_segment(idx)
		_segs[k] = seg
		var dz := (_base + k) * seg_len - cam_z
		_dz[k] = dz
		_xw[k] = x - cam_x
		_yw[k] = seg.y
		_hd[k] = dx / seg_len
		var s := proj.focal / maxf(dz, proj.near)
		_ss[k] = s
		_sx[k] = half_w + _xw[k] * s
		_sy[k] = proj.horizon_y - (seg.y - _cam_y) * s
		x += dx
		dx += seg.curve * k_curve


func _fog_t(dz: float) -> float:
	return clampf((dz - _fog_start) / maxf(1.0, _vis - _fog_start), 0.0, 1.0)


# --- sky and background ---------------------------------------------------------------------

func _draw_sky(pal: Dictionary) -> void:
	var w := proj.screen.x
	var h := proj.screen.y
	var hy := proj.horizon_y
	var top: Color = pal["sky_top"]
	var bot: Color = pal["sky_bottom"]
	if view.get("in_tunnel_view", false):
		top = Color("120d08")
		bot = Color("1c140b")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy + 2), Vector2(0, hy + 2)]),
		PackedColorArray([top, top, bot, bot]))
	draw_rect(Rect2(0, hy, w, h - hy), pal["fog"])
	var stars := float(pal.get("stars", 0.0))
	if stars > 0.01:
		for st in _stars:
			draw_rect(Rect2(st.x * w, st.y * hy, st.z, st.z), Color(1, 1, 1, stars * 0.85))
	if pal.get("sun_visible", false):
		var sp: Vector2 = pal["sun_pos"]
		var c: Color = pal["sun"]
		var pos := Vector2(sp.x * w, sp.y * hy)
		draw_circle(pos, 34.0, Color(c, 0.18))
		draw_circle(pos, 22.0, c)
	elif stars > 0.5:
		draw_circle(Vector2(w * 0.78, hy * 0.25), 16.0, Color(0.92, 0.93, 1.0, 0.9))
		draw_circle(Vector2(w * 0.78 + 7, hy * 0.25 - 4), 14.0, pal["sky_top"])


func _draw_background(pal: Dictionary) -> void:
	if _cam_in_tunnel:
		return
	var scen: Dictionary = scenery_db.get(str(view.get("scenery", "")), {})
	var bg: Dictionary = scen.get("background", {})
	var style := str(bg.get("style", "hills"))
	var cols: Array = bg.get("colors", ["#8aa2bd", "#6f8f6a"])
	var off := float(view.get("bg_offset", 0.0))
	var hy := proj.horizon_y
	var fog: Color = pal["fog"]
	var amb: Color = pal["ambient"]
	for layer in 2:
		var col := (Color(str(cols[mini(layer, cols.size() - 1)])) * amb).lerp(fog, 0.55 - layer * 0.25)
		if float(pal.get("snow", 0.0)) > 0.0:
			col = col.lerp(Color("e9eef3") * amb, 0.5)
		var par := 0.35 + layer * 0.45
		var amp := 60.0 - layer * 28.0
		var pts := PackedVector2Array()
		var steps := 64
		for i in steps + 1:
			var sx := proj.screen.x * float(i) / steps
			var u := (sx + off * par * proj.screen.x) / proj.screen.x
			pts.append(Vector2(sx, hy - _profile(style, u, layer) * amp))
		pts.append(Vector2(proj.screen.x, hy + 2))
		pts.append(Vector2(0, hy + 2))
		draw_colored_polygon(pts, col)


func _profile(style: String, u: float, layer: int) -> float:
	var p := u * TAU
	match style:
		"plain":
			return 0.06 + 0.04 * sin(p * 3.0 + layer) + 0.02 * sin(p * 11.0)
		"mountains", "alps":
			var v := absf(sin(p * 1.7 + layer * 1.3)) * 0.8 + absf(sin(p * 4.3 + 0.7)) * 0.35 + absf(sin(p * 9.1)) * 0.12
			return v * (1.4 if layer == 0 else 0.7)
		"city":
			var b := floorf(u * 40.0 + layer * 17.0)
			return (0.15 + fposmod(sin(b * 12.9898) * 43758.5453, 1.0) * 0.5) * (1.0 if layer == 0 else 0.55)
		"coast":
			return 0.02 + 0.03 * sin(p * 2.0 + layer)
		"forest":
			return 0.25 + 0.06 * sin(p * 23.0 + layer) + 0.08 * sin(p * 5.0)
		_:
			return 0.35 + 0.25 * sin(p * 2.0 + layer * 2.1) + 0.12 * sin(p * 5.3 + 1.0)


# --- road -----------------------------------------------------------------------------------

func _draw_road_and_sprites(pal: Dictionary) -> void:
	var buckets := {}
	for item: Dictionary in view.get("cars", []):
		_bucket(buckets, item)
	if view.has("player"):
		_bucket(buckets, view["player"])
	for k in range(_n - 1, -1, -1):
		var dz2 := _dz[k + 1]
		if dz2 <= proj.near:
			continue
		var seg := _segs[k]
		if _dz[k] > proj.near:
			_draw_segment(k, pal)
		var items: Array = []
		if _dz[k] > -track.seg_len:
			for p: Dictionary in seg.sprites:
				var it := p.duplicate()
				it["z"] = seg.z + track.seg_len * 0.5
				items.append(it)
		items.append_array(buckets.get(k, []))
		if not items.is_empty():
			_flush()
			items.sort_custom(func(a, b): return float(a["z"]) > float(b["z"]))
			for it: Dictionary in items:
				_draw_item(k, it, pal)
		# tunnel faces at point k (the near edge of segment k)
		if k > 0 and _dz[k] > proj.near:
			var prev := _segs[k - 1]
			if prev.tunnel and not seg.tunnel:
				_flush()
				_draw_tunnel_face(k, pal, true)
			elif seg.tunnel and not prev.tunnel:
				_flush()
				_draw_tunnel_face(k, pal, false)
	_flush()


func _bucket(buckets: Dictionary, item: Dictionary) -> void:
	var k := track.segment_index_at(float(item["z"])) - _base
	if k < 0 or k >= _n:
		return
	if not buckets.has(k):
		buckets[k] = []
	buckets[k].append(item)


func _draw_segment(k: int, pal: Dictionary) -> void:
	var seg := _segs[k]
	var seg2 := _segs[k + 1]
	var w := proj.screen.x
	var x1 := _sx[k]
	var y1 := _sy[k]
	var s1 := _ss[k]
	var x2 := _sx[k + 1]
	var y2 := _sy[k + 1]
	var s2 := _ss[k + 1]
	var fog: Color = pal["fog"]
	var ft := _fog_t(_dz[k])
	var stripes: Dictionary = ConfigLoader.lookup(cfg, "render.stripes", {})
	var lw := track.lane_w
	var sh := track.shoulder_w
	var l1 := -seg.lanes * lw * 0.5
	var r1 := seg.lanes * lw * 0.5 + seg.fuel_lane * lw
	var l2 := -seg2.lanes * lw * 0.5
	var r2 := seg2.lanes * lw * 0.5 + seg2.fuel_lane * lw
	var alt := (seg.index / int(stripes.get("grass", 4))) % 2 == 0
	var scen: Dictionary = scenery_db.get(seg.scenery, {})
	var grass_cols: Array = scen.get("grass", ["#5d9a3e", "#56913a"])
	var grass := Palette.ground(Color(str(grass_cols[0 if alt else 1])), pal).lerp(fog, ft)
	if seg.tunnel:
		grass = Color("1c140b").lerp(fog, ft)
	_quad(Vector2(0, y2), Vector2(w, y2), Vector2(w, y1), Vector2(0, y1), grass)
	# shoulder / sidewalk
	var sh_col := Palette.ground(Palette.SIDEWALK if seg.city else Palette.SHOULDER, pal).lerp(fog, ft)
	if seg.tunnel:
		sh_col = Palette.road(Color("6a6a66"), pal).lerp(fog, ft)
	_quad(Vector2(x1 + (l1 - sh) * s1, y1), Vector2(x1 + l1 * s1, y1), Vector2(x2 + l2 * s2, y2), Vector2(x2 + (l2 - sh) * s2, y2), sh_col)
	_quad(Vector2(x1 + r1 * s1, y1), Vector2(x1 + (r1 + sh) * s1, y1), Vector2(x2 + (r2 + sh) * s2, y2), Vector2(x2 + r2 * s2, y2), sh_col)
	# asphalt
	var road_base := Palette.ROAD if (seg.index / 3) % 2 == 0 else Palette.ROAD_ALT
	var road_col := Palette.road(road_base, pal).lerp(fog, ft)
	_quad(Vector2(x1 + l1 * s1, y1), Vector2(x1 + r1 * s1, y1), Vector2(x2 + r2 * s2, y2), Vector2(x2 + l2 * s2, y2), road_col)
	var line_col := Palette.road(Palette.LINE, pal).lerp(fog, ft)
	if float(pal.get("lights", 0.0)) > 0.3:
		line_col = line_col.lerp(Color(0.85, 0.85, 0.8), 0.35 * (1.0 - ft))
	var el := float(ConfigLoader.lookup(cfg, "render.edge_line_m", 0.22))
	var ll := float(ConfigLoader.lookup(cfg, "render.lane_line_m", 0.15))
	if seg.city:
		var curb := Color("d8d8d8") if (seg.index / int(stripes.get("rumble", 2))) % 2 == 0 else Color("9a9a9a")
		curb = Palette.road(curb, pal).lerp(fog, ft)
		var rw := float(ConfigLoader.lookup(cfg, "render.rumble_width_m", 0.5))
		_strip(x1, y1, s1, x2, y2, s2, l1 - rw, l1, l2 - rw, l2, curb)
		_strip(x1, y1, s1, x2, y2, s2, r1, r1 + rw, r2, r2 + rw, curb)
	else:
		_strip(x1, y1, s1, x2, y2, s2, l1 + 0.1, l1 + 0.1 + el, l2 + 0.1, l2 + 0.1 + el, line_col)
		_strip(x1, y1, s1, x2, y2, s2, r1 - 0.1 - el, r1 - 0.1, r2 - 0.1 - el, r2 - 0.1, line_col)
	# lane markings (dashed), solid line towards the fuel lane
	var dash_on := int(stripes.get("dash_on", 2))
	var dash_cycle := dash_on + int(stripes.get("dash_off", 4))
	var main_r1 := seg.lanes * lw * 0.5
	var main_r2 := seg2.lanes * lw * 0.5
	if seg.index % dash_cycle < dash_on:
		var n := int(ceil(seg.lanes - 0.01))
		for i in range(1, n):
			var b1 := l1 + i * lw
			var b2 := l2 + i * lw
			if b1 < main_r1 - 0.5:
				_strip(x1, y1, s1, x2, y2, s2, b1 - ll * 0.5, b1 + ll * 0.5, b2 - ll * 0.5, b2 + ll * 0.5, line_col)
	if seg.fuel_lane > 0.05:
		_strip(x1, y1, s1, x2, y2, s2, main_r1 - ll * 0.5, main_r1 + ll, main_r2 - ll * 0.5, main_r2 + ll, line_col)
	if seg.index == track.segment_count - 3 or seg.index == track.segment_count - 2:
		_finish_line(x1, y1, s1, x2, y2, s2, l1, r1, l2, r2, pal, ft)
	if seg.tunnel:
		_draw_tunnel_segment(k, pal, l1 - sh, r1 + sh, l2 - sh, r2 + sh, ft)
	elif seg.guardrail:
		_draw_guardrail(k, pal, l1 - sh, l2 - sh, ft)
		_draw_guardrail(k, pal, r1 + sh, r2 + sh, ft)


func _strip(x1: float, y1: float, s1: float, x2: float, y2: float, s2: float, a1: float, b1: float, a2: float, b2: float, col: Color) -> void:
	_quad(Vector2(x1 + a1 * s1, y1), Vector2(x1 + b1 * s1, y1), Vector2(x2 + b2 * s2, y2), Vector2(x2 + a2 * s2, y2), col)


func _finish_line(x1: float, y1: float, s1: float, x2: float, y2: float, s2: float, l1: float, r1: float, l2: float, r2: float, pal: Dictionary, ft: float) -> void:
	var cells := 12
	for i in cells:
		var a := float(i) / cells
		var b := float(i + 1) / cells
		var col := Color.WHITE if i % 2 == 0 else Color.BLACK
		col = Palette.road(col, pal).lerp(pal["fog"], ft)
		_strip(x1, y1, s1, x2, y2, s2, lerpf(l1, r1, a), lerpf(l1, r1, b), lerpf(l2, r2, a), lerpf(l2, r2, b), col)


func _draw_guardrail(k: int, pal: Dictionary, x_a: float, x_b: float, ft: float) -> void:
	var h := 0.75
	var col := Palette.road(Color("b9bec4"), pal).lerp(pal["fog"], ft)
	var y1 := _sy[k]
	var y2 := _sy[k + 1]
	var s1 := _ss[k]
	var s2 := _ss[k + 1]
	var p1 := _sx[k] + x_a * s1
	var p2 := _sx[k + 1] + x_b * s2
	_quad(Vector2(p1, y1 - h * s1), Vector2(p2, y2 - h * s2), Vector2(p2, y2 - (h - 0.3) * s2), Vector2(p1, y1 - (h - 0.3) * s1), col)
	if _segs[k].index % 4 == 0:
		var post := col.darkened(0.35)
		_quad(Vector2(p1 - 0.06 * s1, y1 - h * s1), Vector2(p1 + 0.06 * s1, y1 - h * s1), Vector2(p1 + 0.06 * s1, y1), Vector2(p1 - 0.06 * s1, y1), post)


func _draw_tunnel_segment(k: int, pal: Dictionary, la: float, ra: float, lb: float, rb: float, ft: float) -> void:
	var tcfg: Dictionary = ConfigLoader.lookup(cfg, "render.tunnel", {})
	var wall_h := float(tcfg.get("wall_height_m", 5.0))
	var ceil_h := float(tcfg.get("ceiling_m", 5.6))
	var fog: Color = pal["fog"]
	var x1 := _sx[k]
	var y1 := _sy[k]
	var s1 := _ss[k]
	var x2 := _sx[k + 1]
	var y2 := _sy[k + 1]
	var s2 := _ss[k + 1]
	var wall := Color("8a7f70") * (pal["ambient"] as Color)
	var alt := (_segs[k].index / 2) % 2 == 0
	if alt:
		wall = wall.darkened(0.06)
	wall = wall.lerp(fog, ft)
	var ceil_col := Color("3b332a").lerp(fog, ft)
	# left wall, right wall, ceiling
	_quad(Vector2(x1 + la * s1, y1), Vector2(x1 + la * s1, y1 - wall_h * s1), Vector2(x2 + lb * s2, y2 - wall_h * s2), Vector2(x2 + lb * s2, y2), wall)
	_quad(Vector2(x1 + ra * s1, y1), Vector2(x1 + ra * s1, y1 - wall_h * s1), Vector2(x2 + rb * s2, y2 - wall_h * s2), Vector2(x2 + rb * s2, y2), wall)
	_quad(Vector2(x1 + la * s1, y1 - wall_h * s1), Vector2(x1 + ra * s1, y1 - wall_h * s1), Vector2(x2 + rb * s2, y2 - ceil_h * s2), Vector2(x2 + lb * s2, y2 - ceil_h * s2), ceil_col)
	var every := maxi(1, int(float(tcfg.get("light_every_m", 24.0)) / track.seg_len))
	if _segs[k].index % every == 0:
		var lamp := Color(1.0, 0.82, 0.5).lerp(fog, ft * 0.6)
		for side: float in [la + 0.4, ra - 0.4]:
			var lx1 := x1 + side * s1
			var lx2 := x2 + side * s2
			_quad(Vector2(lx1 - 0.25 * s1, y1 - (wall_h - 0.2) * s1), Vector2(lx1 + 0.25 * s1, y1 - (wall_h - 0.2) * s1),
				Vector2(lx2 + 0.25 * s2, y2 - (wall_h - 0.05) * s2), Vector2(lx2 - 0.25 * s2, y2 - (wall_h - 0.05) * s2), lamp)


## Portal face (entrance, seen from outside) or inner face (exit, seen from inside) at point k.
func _draw_tunnel_face(k: int, pal: Dictionary, exit_face: bool) -> void:
	var tcfg: Dictionary = ConfigLoader.lookup(cfg, "render.tunnel", {})
	var ceil_h := float(tcfg.get("ceiling_m", 5.6))
	var seg := _segs[k]
	var lw := track.lane_w
	var sh := track.shoulder_w
	var x := _sx[k]
	var y := _sy[k]
	var s := _ss[k]
	var left := x + (-seg.lanes * lw * 0.5 - sh) * s
	var right := x + (seg.lanes * lw * 0.5 + seg.fuel_lane * lw + sh) * s
	var top := y - ceil_h * s
	var ft := _fog_t(_dz[k])
	var w := proj.screen.x
	if exit_face:
		var col := Color("2a2219").lerp(pal["fog"], ft * 0.5)
		if _cam_in_tunnel:
			draw_rect(Rect2(0, 0, w, top), col)
			draw_rect(Rect2(0, top, left, y - top), col)
			draw_rect(Rect2(right, top, w - right, y - top), col)
		else:
			_face_rect(x, y, s, left, right, top, col, 40.0, 30.0)
	else:
		var rock := Palette.ground(Color("6d6a62"), pal).lerp(pal["fog"], ft)
		_face_rect(x, y, s, left, right, top, rock, 60.0, 34.0)
		var frame := Palette.ground(Color("a29d92"), pal).lerp(pal["fog"], ft)
		draw_rect(Rect2(left - 0.6 * s, top - 0.8 * s, right - left + 1.2 * s, 0.8 * s), frame)


func _face_rect(x: float, y: float, s: float, left: float, right: float, top: float, col: Color, half_w_m: float, h_m: float) -> void:
	var l := x - half_w_m * s
	var r := x + half_w_m * s
	var t := y - h_m * s
	draw_rect(Rect2(l, t, r - l, top - t), col)
	draw_rect(Rect2(l, top, left - l, y - top), col)
	draw_rect(Rect2(right, top, r - right, y - top), col)
	draw_colored_polygon(PackedVector2Array([Vector2(l, t), Vector2(x - half_w_m * 0.3 * s, t - h_m * 0.5 * s), Vector2(x + half_w_m * 0.4 * s, t - h_m * 0.35 * s), Vector2(r, t)]), col)


# --- sprites --------------------------------------------------------------------------------

func _item_screen(k: int, z: float, x: float, y_off: float = 0.0) -> Vector3:
	var seg_start := (_base + k) * track.seg_len
	var f := clampf((z - seg_start) / track.seg_len, 0.0, 1.0)
	var dz := lerpf(_dz[k], _dz[k + 1], f)
	if dz <= proj.near:
		return Vector3(0, 0, -1)
	var s := proj.focal / dz
	var xw := lerpf(_xw[k], _xw[k + 1], f)
	var yw := lerpf(_yw[k], _yw[k + 1], f)
	return Vector3(proj.screen.x * 0.5 + (xw + x) * s, proj.horizon_y - (yw + y_off - _cam_y) * s, s)


func _draw_item(k: int, it: Dictionary, pal: Dictionary) -> void:
	var z := float(it["z"])
	var p := _item_screen(k, z, float(it.get("x", 0.0)))
	if p.z <= 0.0:
		return
	var dz := proj.focal / p.z
	var alpha := 1.0 - pow(_fog_t(dz), 2.0)
	if alpha <= 0.02:
		return
	match str(it.get("kind", "prop")):
		"sign":
			_draw_sign(it, p, pal, alpha)
		"car":
			_draw_car(k, it, p, pal, alpha)
		_:
			_draw_prop(it, p, pal, alpha)


func _sprite(set_id: String, angle: String, layer: String, p: Vector3, scale: float, modulate: Color, flip: bool = false) -> void:
	var tex := SpriteDB.texture(set_id)
	if tex == null:
		return
	var src := SpriteDB.region(set_id, angle, layer)
	if src.size.x <= 0.0:
		return
	var w := src.size.x / SpriteDB.pixels_per_meter(set_id) * p.z * scale
	var h := w * src.size.y / src.size.x
	if w < 0.6 or w > proj.screen.x * 4.0:
		return
	var a := SpriteDB.anchor(set_id)
	var dest := Rect2(p.x - a.x * w, p.y - a.y * h, w, h)
	if flip:
		dest = Rect2(dest.position.x + w, dest.position.y, -w, h)
	draw_texture_rect_region(tex, dest, src, modulate)


func _draw_prop(it: Dictionary, p: Vector3, pal: Dictionary, alpha: float) -> void:
	var set_id := str(it.get("set", ""))
	var amb: Color = pal["ambient"]
	var scale := float(it.get("scale", 1.0))
	var flip := int(it.get("side", 1)) < 0 and bool(it.get("mirror", false))
	_sprite(set_id, "c", "base", p, scale, Color(amb, alpha), flip)
	var lights := float(pal.get("lights", 0.0))
	if lights > 0.05 and SpriteDB.has_layer(set_id, "lights"):
		_sprite(set_id, "c", "lights", p, scale, Color(1, 1, 1, alpha * lights), flip)


func _car_angle(k: int, it: Dictionary, p: Vector3) -> String:
	if it.has("angle"):
		return str(it["angle"])
	var heading := lerpf(_hd[k], _hd[mini(k + 1, _n)], 0.5)
	var dz := proj.focal / p.z
	var ray := (p.x - proj.screen.x * 0.5) / p.z / maxf(dz, 0.1)
	var yaw := rad_to_deg(atan(heading) - atan(ray))
	if yaw > 16.0:
		return "r2"
	if yaw > 5.0:
		return "r1"
	if yaw < -16.0:
		return "l2"
	if yaw < -5.0:
		return "l1"
	return "c"


func _draw_car(k: int, it: Dictionary, p: Vector3, pal: Dictionary, alpha: float) -> void:
	if not bool(it.get("visible", true)):
		return
	var set_id := str(it.get("set", ""))
	var angle := _car_angle(k, it, p)
	var amb: Color = pal["ambient"]
	if bool(it.get("player", false)):
		amb = amb.lerp(Color.WHITE, 0.25)
	_sprite(set_id, angle, "base", p, 1.0, Color(amb, alpha))
	var tail := maxf(float(it.get("tail", 0.0)), float(pal.get("lights", 0.0)))
	if tail > 0.05 and SpriteDB.has_layer(set_id, "tail"):
		_sprite(set_id, angle, "tail", p, 1.0, Color(1, 1, 1, alpha * tail))
	if float(it.get("brake", 0.0)) > 0.05 and SpriteDB.has_layer(set_id, "brake"):
		_sprite(set_id, angle, "brake", p, 1.0, Color(1, 1, 1, alpha * float(it["brake"])))
	var beacon := str(it.get("beacon", ""))
	if beacon != "" and SpriteDB.has_layer(set_id, "beacon_" + beacon):
		_sprite(set_id, angle, "beacon_" + beacon, p, 1.0, Color(1, 1, 1, alpha))


func _draw_sign(it: Dictionary, p: Vector3, pal: Dictionary, alpha: float) -> void:
	var s := p.z
	var kind := str(it.get("sign", ""))
	var amb := (pal["ambient"] as Color).lerp(Color.WHITE, 0.45 * float(pal.get("lights", 0.0)))
	var post := Color(0.55, 0.57, 0.6) * amb
	post.a = alpha
	if kind == "finish":
		_draw_finish_banner(p, pal, alpha)
		return
	var board_w := 2.2
	var board_h := 1.5
	var height := 2.4
	var bg := Color("1f4fa8")
	var fg := Color.WHITE
	match kind:
		"limit", "unlimited":
			board_w = 1.0
			board_h = 1.0
		"radar":
			board_w = 1.0
			board_h = 1.6
		"town":
			bg = Color("f2c21b")
			fg = Color("111111")
			board_w = 3.4
			board_h = 1.4
		"distance":
			board_w = 3.8
			board_h = 1.2
			height = 2.8
		"border":
			board_w = 3.2
			board_h = 1.8
		"tunnel":
			board_w = 2.6
			board_h = 1.0
	var bw := board_w * s
	var bh := board_h * s
	if bw < 2.0:
		return
	var bottom := p.y - height * s
	draw_rect(Rect2(p.x - 0.06 * s, bottom, 0.12 * s, height * s), post)
	var rect := Rect2(p.x - bw * 0.5, bottom - bh, bw, bh)
	var bgc := bg * amb
	bgc.a = alpha
	var fgc := fg * amb
	fgc.a = alpha
	match kind:
		"limit", "unlimited", "radar":
			var c := Vector2(p.x, bottom - bh + 0.5 * s)
			if kind == "radar":
				draw_rect(Rect2(p.x - 0.5 * s, bottom - 0.6 * s, s, 0.55 * s), Color(Color.WHITE * amb, alpha))
				_text("RADAR", Vector2(p.x, bottom - 0.2 * s), 0.3 * s, Color(Color.BLACK, alpha))
			draw_circle(c, 0.5 * s, Color(Color.WHITE * amb, alpha))
			if kind == "unlimited":
				for i in 4:
					var o := (i - 1.5) * 0.12 * s
					draw_line(c + Vector2(-0.3 * s + o, 0.3 * s), c + Vector2(0.3 * s + o, -0.3 * s), Color(Color.BLACK, alpha), maxf(1.0, 0.03 * s))
			else:
				draw_arc(c, 0.42 * s, 0.0, TAU, 32, Color(Color("d42020") * amb, alpha), maxf(1.0, 0.13 * s))
				_text(str(it.get("value", "")), c + Vector2(0, 0.14 * s), 0.42 * s, Color(Color.BLACK, alpha))
		"fuel":
			draw_rect(rect, bgc)
			draw_rect(Rect2(rect.position.x + 0.25 * s, rect.position.y + 0.25 * s, 0.45 * s, 0.75 * s), fgc)
			_text(str(it.get("text", "")), Vector2(p.x + 0.35 * s, rect.position.y + 0.95 * s), 0.5 * s, fgc)
		"border":
			draw_rect(rect, bgc)
			var c := Vector2(p.x, rect.position.y + 0.65 * s)
			for i in 12:
				var a := TAU * i / 12.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 0.42 * s, 0.06 * s, Color(Color("ffd200") * amb, alpha))
			_text(str(it.get("text", "")), Vector2(p.x, rect.end.y - 0.18 * s), 0.34 * s, fgc)
		_:
			draw_rect(rect, bgc)
			if kind == "town":
				draw_rect(rect.grow(-0.08 * s), Color(fgc, alpha), false, maxf(1.0, 0.05 * s))
			_text(str(it.get("text", "")), Vector2(p.x, rect.position.y + bh * 0.68), 0.5 * s, fgc)


func _draw_finish_banner(p: Vector3, pal: Dictionary, alpha: float) -> void:
	var s := p.z
	var half := 8.5 * s
	var top := p.y - 6.0 * s
	var amb: Color = pal["ambient"]
	var post := Color(Color(0.8, 0.8, 0.82) * amb, alpha)
	draw_rect(Rect2(p.x - half, top, 0.3 * s, 6.0 * s), post)
	draw_rect(Rect2(p.x + half - 0.3 * s, top, 0.3 * s, 6.0 * s), post)
	draw_rect(Rect2(p.x - half, top, half * 2.0, 1.2 * s), Color(Color("c81e1e") * amb, alpha))
	_text("ZIEL", Vector2(p.x, top + 0.95 * s), 0.9 * s, Color(Color.WHITE * amb, alpha))


func _text(t: String, center_baseline: Vector2, size_px: float, col: Color) -> void:
	var fs := int(round(size_px / 2.0)) * 2
	if fs < 6 or t == "":
		return
	fs = mini(fs, 96)
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center_baseline - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- effects --------------------------------------------------------------------------------

func _draw_headlights(pal: Dictionary) -> void:
	var p: Dictionary = view.get("player", {})
	if p.is_empty():
		return
	var k := track.segment_index_at(float(p["z"])) - _base
	if k < 0 or k >= _n - 1:
		return
	var near_p := _item_screen(k, float(p["z"]), float(p["x"]))
	var far_k := mini(k + int(55.0 / track.seg_len), _n - 1)
	var far_z := (_base + far_k) * track.seg_len
	var far_p := _item_screen(far_k, far_z, float(p["x"]))
	if near_p.z <= 0.0 or far_p.z <= 0.0:
		return
	var a := 0.16 * float(pal.get("lights", 0.0))
	var c_near := Color(1.0, 0.95, 0.75, a)
	var c_far := Color(1.0, 0.95, 0.75, 0.0)
	var nw := 1.4 * near_p.z
	var fw := 6.0 * far_p.z
	draw_polygon(PackedVector2Array([Vector2(near_p.x - nw, near_p.y), Vector2(near_p.x + nw, near_p.y), Vector2(far_p.x + fw, far_p.y), Vector2(far_p.x - fw, far_p.y)]),
		PackedColorArray([c_near, c_near, c_far, c_far]))


func _draw_weather(pal: Dictionary) -> void:
	var weather := str(view.get("weather", "normal"))
	if weather == "normal" or _cam_in_tunnel:
		return
	var t := float(view.get("time", 0.0))
	var speed := float(view.get("speed", 0.0))
	var w := proj.screen.x
	var h := proj.screen.y
	var amb: Color = pal["ambient"]
	if weather == "rain":
		var col := Color(Color(0.75, 0.8, 0.9) * amb.lerp(Color.WHITE, 0.3), 0.45)
		for i in 170:
			var r1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
			var r2 := fposmod(sin(i * 78.233) * 12345.678, 1.0)
			var x := fposmod(r1 * w + t * 60.0, w)
			var y := fposmod(r2 * h + t * (900.0 + r1 * 300.0), h)
			var slant := (x - w * 0.5) / w * speed * 0.15
			draw_line(Vector2(x, y), Vector2(x + slant, y + 22.0 + speed * 0.05), col, 1.2)
	elif weather == "snow":
		var center := Vector2(w * 0.5, proj.horizon_y)
		var col := Color(Color.WHITE * amb.lerp(Color.WHITE, 0.4), 0.85)
		for i in 150:
			var r1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
			var r2 := fposmod(sin(i * 78.233) * 12345.678, 1.0)
			var ang := r1 * TAU
			var dist := fposmod(r2 + t * (0.05 + speed / 900.0) * (0.6 + r1), 1.0)
			var radius := pow(dist, 1.6) * w * 0.8
			var pos := center + Vector2(cos(ang), sin(ang) * 0.75) * radius + Vector2(sin(t * 2.0 + i) * 6.0, t * 25.0 * (1.0 - dist))
			if pos.y < 0.0 or pos.y > h:
				continue
			draw_circle(pos, 1.0 + dist * 3.0, col)
