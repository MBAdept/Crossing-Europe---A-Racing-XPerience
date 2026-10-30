class_name SignPainter
extends RefCounted
## Procedural road signs (they carry text, so they are not sprites). All sizes in metres and
## slightly exaggerated for readability at speed. Geometry goes into the shared GeoBatch, text is
## drawn with draw_string at a few cached font sizes, scaled to the exact size with a transform.
## Kinds: limit, unlimited, radar, fuel, fuel_lane, town, distance, border, tunnel, autobahn,
## autobahn_end, start (gantry with countdown lights), finish (gantry with "ZIEL" banner).
## Owner: race module.

const BLUE := Color("1d4f9c")
const BLUE_AB := Color("1f5aa8")
const YELLOW := Color("f5c418")
const RED := Color("d41f1f")
const WHITE := Color("f4f4f0")
const BLACK := Color("141414")
const POST := Color("8d9399")
const EU_BLUE := Color("1b3f94")
const EU_YELLOW := Color("ffd21f")
const FONT_SIZES := [8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96]

var font: Font
var batch: GeoBatch
var ci: CanvasItem
var base_offset := Vector2.ZERO   ## current base transform (camera shake) of the canvas item
var countdown := -1.0             ## seconds left of the start countdown (start gantry lights)


func setup(canvas: CanvasItem, geo: GeoBatch) -> void:
	ci = canvas
	batch = geo
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.55
	font = fv


## Draws one sign. p = (screen x, screen y of the ground point, pixels per metre);
## lit = colour multiplier (ambient + reflection); alpha = fog fade. edges = outer road edges
## (left/right, metres from the camera axis already projected: screen x) for gantries.
func draw(it: Dictionary, p: Vector3, lit: Color, alpha: float, edges_px: Vector2) -> void:
	var kind := str(it.get("sign", ""))
	var s := p.z
	if s < 0.6:
		return
	match kind:
		"limit", "unlimited":
			_round_sign(p, lit, alpha, kind == "unlimited", int(it.get("value", 0)))
		"radar":
			_radar_sign(p, lit, alpha, int(it.get("value", 0)), str(it.get("text", "")))
		"fuel":
			_fuel_sign(p, lit, alpha, str(it.get("text", "")))
		"fuel_lane":
			_fuel_lane_sign(p, lit, alpha)
		"town":
			_town_sign(p, lit, alpha, str(it.get("text", "")))
		"distance":
			_distance_sign(p, lit, alpha, str(it.get("text", "")), int(it.get("value", 0)), str(it.get("road", "autobahn")))
		"border":
			_border_sign(p, lit, alpha, str(it.get("text", "")), str(it.get("country", "")))
		"tunnel":
			_tunnel_sign(p, lit, alpha, str(it.get("text", "")), int(it.get("value", 0)))
		"autobahn", "autobahn_end":
			_autobahn_sign(p, lit, alpha, kind == "autobahn_end")
		"start":
			_gantry(p, lit, alpha, edges_px, tr("START"), true)
		"finish":
			_gantry(p, lit, alpha, edges_px, str(it.get("text", "ZIEL")), false)


# --- helpers --------------------------------------------------------------------------------

func _c(col: Color, lit: Color, alpha: float) -> Color:
	return Color(col.r * lit.r, col.g * lit.g, col.b * lit.b, alpha)


func _post(x: float, ground_y: float, top_y: float, w: float, lit: Color, alpha: float) -> void:
	batch.rect(Rect2(x - w * 0.5, top_y, w, ground_y - top_y), _c(POST, lit, alpha))


func _board(r: Rect2, col: Color, lit: Color, alpha: float, border: Color = Color(0, 0, 0, 0), border_w: float = 0.0) -> void:
	if border.a > 0.0 and border_w > 0.4:
		batch.rect(r, _c(border, lit, alpha))
		batch.rect(r.grow(-border_w), _c(col, lit, alpha))
	else:
		batch.rect(r, _c(col, lit, alpha))


## Text centred on x with its baseline at y; height_px = cap height in pixels.
func text(t: String, center_baseline: Vector2, height_px: float, col: Color, max_width_px: float = -1.0) -> void:
	if t == "" or height_px < 1.0:
		return
	var em := height_px / 0.72
	if em < 5.0:
		# unreadable at this distance: a light bar instead of glyphs
		var w := em * 0.55 * float(t.length())
		if max_width_px > 0.0:
			w = minf(w, max_width_px)
		batch.rect(Rect2(center_baseline.x - w * 0.5, center_baseline.y - height_px, w, height_px), Color(col, col.a * 0.55))
		return
	var fs := 96
	for f: int in FONT_SIZES:
		if f >= em:
			fs = f
			break
	var k := em / float(fs)
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * k
	if max_width_px > 0.0 and w > max_width_px:
		k *= max_width_px / w
		w = max_width_px
	batch.flush()
	ci.draw_set_transform(base_offset + center_baseline, 0.0, Vector2(k, k))
	ci.draw_string(font, Vector2(-w * 0.5 / k, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	ci.draw_set_transform(base_offset, 0.0, Vector2.ONE)


func _star(c: Vector2, r: float, col: Color) -> void:
	if r < 1.2:
		batch.rect(Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), col)
		return
	var pts: Array[Vector2] = []
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	for i in 10:
		batch.tri(c, pts[i], pts[(i + 1) % 10], col)


# --- sign kinds -----------------------------------------------------------------------------

func _round_sign(p: Vector3, lit: Color, alpha: float, unlimited: bool, value: int) -> void:
	var s := p.z
	var r := 0.85 * s
	var cy := p.y - 2.75 * s
	_post(p.x, p.y, cy, 0.11 * s, lit, alpha)
	var seg := 20 if r > 12.0 else 12
	if unlimited:
		batch.ellipse(Vector2(p.x, cy), Vector2(r, r), _c(WHITE, lit, alpha), _c(WHITE, lit, alpha), seg)
		batch.ellipse(Vector2(p.x, cy), Vector2(r * 0.95, r * 0.95), _c(Color("e8e8e2"), lit, alpha), _c(Color("e8e8e2"), lit, alpha), seg)
		var stripe := _c(BLACK, lit, alpha)
		for i in 5:
			var o := (float(i) - 2.0) * 0.13 * s
			batch.line(Vector2(p.x - 0.55 * s + o, cy + 0.55 * s + o), Vector2(p.x + 0.55 * s + o, cy - 0.55 * s + o), maxf(1.0, 0.045 * s), stripe)
		return
	batch.ellipse(Vector2(p.x, cy), Vector2(r, r), _c(RED, lit, alpha), _c(RED, lit, alpha), seg)
	batch.ellipse(Vector2(p.x, cy), Vector2(r * 0.76, r * 0.76), _c(WHITE, lit, alpha), _c(WHITE, lit, alpha), seg)
	text(str(value), Vector2(p.x, cy + 0.33 * s), 0.66 * s, _c(BLACK, lit, alpha), 1.3 * s)


func _radar_sign(p: Vector3, lit: Color, alpha: float, limit: int, dist: String) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.05 * s, p.y - 4.6 * s, 2.1 * s, 3.1 * s)
	_post(p.x, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, BLUE, lit, alpha, WHITE, 0.07 * s)
	# camera pictogram
	var cam := Rect2(p.x - 0.42 * s, r.position.y + 0.25 * s, 0.84 * s, 0.5 * s)
	batch.rect(cam, _c(WHITE, lit, alpha))
	batch.rect(Rect2(cam.position.x + 0.1 * s, cam.position.y - 0.12 * s, 0.25 * s, 0.13 * s), _c(WHITE, lit, alpha))
	batch.ellipse(cam.get_center(), Vector2(0.17, 0.17) * s, _c(BLUE, lit, alpha), _c(BLUE, lit, alpha), 10)
	# limit disc
	var c := Vector2(p.x, r.position.y + 1.62 * s)
	batch.ellipse(c, Vector2(0.62, 0.62) * s, _c(RED, lit, alpha), _c(RED, lit, alpha), 16)
	batch.ellipse(c, Vector2(0.47, 0.47) * s, _c(WHITE, lit, alpha), _c(WHITE, lit, alpha), 16)
	text(str(limit), c + Vector2(0, 0.2 * s), 0.4 * s, _c(BLACK, lit, alpha), 0.85 * s)
	text(tr("RADAR"), Vector2(p.x, r.end.y - 0.55 * s), 0.3 * s, _c(WHITE, lit, alpha), 1.9 * s)
	text(dist, Vector2(p.x, r.end.y - 0.14 * s), 0.27 * s, _c(WHITE, lit, alpha), 1.9 * s)


func _pump_icon(c: Vector2, s: float, col: Color, bg: Color) -> void:
	batch.rect(Rect2(c.x - 0.28 * s, c.y - 0.42 * s, 0.42 * s, 0.84 * s), col)
	batch.rect(Rect2(c.x - 0.22 * s, c.y - 0.34 * s, 0.3 * s, 0.22 * s), bg)
	batch.rect(Rect2(c.x - 0.34 * s, c.y + 0.36 * s, 0.54 * s, 0.08 * s), col)
	batch.line(Vector2(c.x + 0.14 * s, c.y - 0.2 * s), Vector2(c.x + 0.3 * s, c.y - 0.05 * s), maxf(1.0, 0.07 * s), col)
	batch.line(Vector2(c.x + 0.3 * s, c.y - 0.05 * s), Vector2(c.x + 0.3 * s, c.y + 0.25 * s), maxf(1.0, 0.07 * s), col)


func _fuel_sign(p: Vector3, lit: Color, alpha: float, dist: String) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.5 * s, p.y - 4.1 * s, 3.0 * s, 2.1 * s)
	_post(p.x - 1.0 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_post(p.x + 1.0 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, BLUE_AB, lit, alpha, WHITE, 0.07 * s)
	_pump_icon(Vector2(r.position.x + 0.75 * s, r.position.y + 0.95 * s), s, _c(WHITE, lit, alpha), _c(BLUE_AB, lit, alpha))
	text(tr("Tankstelle"), Vector2(r.position.x + 1.95 * s, r.position.y + 0.72 * s), 0.3 * s, _c(WHITE, lit, alpha), 1.85 * s)
	text(dist, Vector2(r.position.x + 1.95 * s, r.position.y + 1.6 * s), 0.55 * s, _c(WHITE, lit, alpha), 1.85 * s)


func _fuel_lane_sign(p: Vector3, lit: Color, alpha: float) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.15 * s, p.y - 4.2 * s, 2.3 * s, 2.3 * s)
	_post(p.x, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, BLUE_AB, lit, alpha, WHITE, 0.07 * s)
	_pump_icon(Vector2(r.position.x + 0.75 * s, r.position.y + 0.85 * s), s * 0.9, _c(WHITE, lit, alpha), _c(BLUE_AB, lit, alpha))
	var a0 := Vector2(r.position.x + 0.55 * s, r.end.y - 0.5 * s)
	var a1 := Vector2(r.end.x - 0.45 * s, r.end.y - 0.5 * s)
	var w := maxf(1.0, 0.16 * s)
	batch.line(a0, a1, w, _c(WHITE, lit, alpha))
	batch.tri(a1 + Vector2(0.22 * s, 0), a1 + Vector2(-0.12 * s, -0.25 * s), a1 + Vector2(-0.12 * s, 0.25 * s), _c(WHITE, lit, alpha))
	batch.line(Vector2(r.end.x - 0.6 * s, r.position.y + 0.45 * s), Vector2(r.end.x - 0.6 * s, r.position.y + 1.3 * s), w, _c(WHITE, lit, alpha))


func _town_sign(p: Vector3, lit: Color, alpha: float, name: String) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.9 * s, p.y - 3.3 * s, 3.8 * s, 1.75 * s)
	_post(p.x - 1.3 * s, p.y, r.end.y, 0.1 * s, lit, alpha)
	_post(p.x + 1.3 * s, p.y, r.end.y, 0.1 * s, lit, alpha)
	_board(r, YELLOW, lit, alpha, BLACK, 0.05 * s)
	if 0.06 * s > 0.6:
		var inner := r.grow(-0.12 * s)
		batch.rect(inner, _c(BLACK, lit, alpha))
		batch.rect(inner.grow(-0.05 * s), _c(YELLOW, lit, alpha))
	text(name, Vector2(p.x, r.position.y + 1.08 * s), 0.62 * s, _c(BLACK, lit, alpha), 3.4 * s)
	text(tr("City Limits"), Vector2(p.x, r.end.y - 0.22 * s), 0.2 * s, _c(BLACK, lit, alpha), 3.0 * s)


func _distance_sign(p: Vector3, lit: Color, alpha: float, name: String, km: int, road: String) -> void:
	var s := p.z
	var yellow := road != "autobahn"
	var bg := YELLOW if yellow else BLUE_AB
	var fg := BLACK if yellow else WHITE
	var r := Rect2(p.x - 2.4 * s, p.y - 4.0 * s, 4.8 * s, 1.35 * s)
	_post(p.x - 1.7 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_post(p.x + 1.7 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, bg, lit, alpha, fg, 0.06 * s)
	var h := 0.52 * s
	text(name, Vector2(r.position.x + 1.65 * s, r.position.y + 0.92 * s), h, _c(fg, lit, alpha), 3.0 * s)
	text("%d km" % km, Vector2(r.end.x - 0.75 * s, r.position.y + 0.92 * s), h, _c(fg, lit, alpha), 1.3 * s)


func _border_sign(p: Vector3, lit: Color, alpha: float, name: String, country: String) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.75 * s, p.y - 4.0 * s, 3.5 * s, 2.5 * s)
	_post(p.x - 1.2 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_post(p.x + 1.2 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, EU_BLUE, lit, alpha, WHITE, 0.05 * s)
	var c := Vector2(p.x, r.position.y + 0.95 * s)
	var star := _c(EU_YELLOW, lit, alpha)
	for i in 12:
		var a := TAU * float(i) / 12.0
		_star(c + Vector2(cos(a), sin(a)) * 0.62 * s, 0.1 * s, star)
	text(country, c + Vector2(0, 0.2 * s), 0.42 * s, _c(WHITE, lit, alpha), 0.9 * s)
	text(name, Vector2(p.x, r.end.y - 0.3 * s), 0.38 * s, _c(WHITE, lit, alpha), 3.2 * s)


func _tunnel_sign(p: Vector3, lit: Color, alpha: float, name: String, length_m: int) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.7 * s, p.y - 4.0 * s, 3.4 * s, 1.5 * s)
	_post(p.x - 1.1 * s, p.y, r.end.y, 0.1 * s, lit, alpha)
	_post(p.x + 1.1 * s, p.y, r.end.y, 0.1 * s, lit, alpha)
	_board(r, BLUE_AB, lit, alpha, WHITE, 0.06 * s)
	# tunnel pictogram: white arch with a dark opening and a road
	var c := Vector2(r.position.x + 0.7 * s, r.end.y - 0.18 * s)
	batch.half_ellipse(c, Vector2(0.5, 0.95) * s, _c(WHITE, lit, alpha))
	batch.half_ellipse(c, Vector2(0.32, 0.72) * s, _c(BLACK, lit, alpha))
	batch.quad(Vector2(c.x - 0.08 * s, c.y), Vector2(c.x + 0.08 * s, c.y), Vector2(c.x + 0.02 * s, c.y - 0.5 * s), Vector2(c.x - 0.02 * s, c.y - 0.5 * s), _c(WHITE, lit, alpha))
	text(name, Vector2(r.position.x + 2.2 * s, r.position.y + 0.66 * s), 0.38 * s, _c(WHITE, lit, alpha), 2.1 * s)
	if length_m > 0:
		text("%d m" % length_m, Vector2(r.position.x + 2.2 * s, r.end.y - 0.22 * s), 0.3 * s, _c(WHITE, lit, alpha), 2.1 * s)


func _autobahn_sign(p: Vector3, lit: Color, alpha: float, ended: bool) -> void:
	var s := p.z
	var r := Rect2(p.x - 0.95 * s, p.y - 3.7 * s, 1.9 * s, 1.9 * s)
	_post(p.x, p.y, r.end.y, 0.11 * s, lit, alpha)
	_board(r, BLUE_AB, lit, alpha, WHITE, 0.05 * s)
	var w := _c(WHITE, lit, alpha)
	var b := _c(BLUE_AB, lit, alpha)
	var bottom := r.end.y - 0.18 * s
	var top := r.position.y + 0.55 * s
	batch.quad(Vector2(p.x - 0.75 * s, bottom), Vector2(p.x + 0.75 * s, bottom), Vector2(p.x + 0.12 * s, top), Vector2(p.x - 0.12 * s, top), w)
	batch.quad(Vector2(p.x - 0.05 * s, bottom), Vector2(p.x + 0.05 * s, bottom), Vector2(p.x + 0.015 * s, top), Vector2(p.x - 0.015 * s, top), b)
	batch.rect(Rect2(r.position.x + 0.2 * s, r.position.y + 0.42 * s, r.size.x - 0.4 * s, 0.16 * s), w)
	batch.rect(Rect2(r.position.x + 0.35 * s, r.position.y + 0.58 * s, 0.1 * s, 0.35 * s), w)
	batch.rect(Rect2(r.end.x - 0.45 * s, r.position.y + 0.58 * s, 0.1 * s, 0.35 * s), w)
	if ended:
		batch.line(Vector2(r.position.x + 0.1 * s, r.end.y - 0.1 * s), Vector2(r.end.x - 0.1 * s, r.position.y + 0.1 * s), maxf(1.0, 0.18 * s), _c(RED, lit, alpha))


## Gantry over the whole road (posts at the outer shoulder edges) with a banner.
func _gantry(p: Vector3, lit: Color, alpha: float, edges_px: Vector2, label: String, start: bool) -> void:
	var s := p.z
	var left := edges_px.x
	var right := edges_px.y
	var top := p.y - 7.0 * s
	var post_w := 0.45 * s
	var steel := _c(Color("c9ccd1"), lit, alpha)
	batch.rect(Rect2(left - post_w, top, post_w, p.y - top), steel)
	batch.rect(Rect2(right, top, post_w, p.y - top), steel)
	var banner := Rect2(left - post_w, top, right - left + post_w * 2.0, 1.6 * s)
	if start:
		batch.rect(banner, _c(Color("1b1f2a"), lit, alpha))
		batch.rect(Rect2(banner.position.x, banner.end.y - 0.12 * s, banner.size.x, 0.12 * s), _c(Color("e8e8e8"), lit, alpha))
		text(label, Vector2(p.x - 2.4 * s, banner.position.y + 1.18 * s), 0.85 * s, _c(WHITE, lit, alpha), banner.size.x * 0.4)
		# three countdown lights: red while counting, all green at the start
		var on := 0 if countdown <= 0.0 else clampi(4 - int(ceil(countdown)), 1, 3)
		for i in 3:
			var c := Vector2(p.x + (1.4 + float(i) * 1.15) * s, banner.position.y + 0.8 * s)
			var col := Color("3a1010")
			if countdown <= 0.0 and countdown > -100.0:
				col = Color("35ff55")
			elif i < on:
				col = Color("ff2a1a")
			batch.ellipse(c, Vector2(0.45, 0.45) * s, Color(0.05, 0.05, 0.05, alpha), Color(0.05, 0.05, 0.05, alpha), 12)
			batch.ellipse(c, Vector2(0.36, 0.36) * s, Color(col, alpha), Color(col, alpha), 12)
		return
	batch.rect(banner, _c(Color("c81e1e"), lit, alpha))
	var cells := int(clampf(banner.size.x / maxf(0.5 * s, 1.0), 4.0, 64.0))
	var cw := banner.size.x / float(cells)
	for i in cells:
		var col := WHITE if i % 2 == 0 else BLACK
		batch.rect(Rect2(banner.position.x + cw * i, banner.position.y, cw, 0.22 * s), _c(col, lit, alpha))
		var col2 := BLACK if i % 2 == 0 else WHITE
		batch.rect(Rect2(banner.position.x + cw * i, banner.end.y - 0.22 * s, cw, 0.22 * s), _c(col2, lit, alpha))
	text(label, Vector2(p.x, banner.position.y + 1.22 * s), 0.85 * s, _c(WHITE, lit, alpha), banner.size.x * 0.6)
