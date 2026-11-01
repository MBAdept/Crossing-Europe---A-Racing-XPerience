class_name SignPainter
extends RefCounted
## Procedural road signs (they carry text, so they are not sprites – documented decision, see
## docs/renn-modul.md §6). All sizes in metres and slightly exaggerated for readability at speed.
## Geometry goes into the shared GeoBatch, text is drawn with draw_string at a few cached font sizes,
## scaled to the exact size with a transform.
## Kinds: limit, unlimited, radar, fuel, fuel_lane, town, town_ahead (advance sign of the City Limits: town board,
## "in <n> km" plate and the city speed limit), distance, border, tunnel, autobahn,
## autobahn_end, start (gantry with countdown lights), finish (gantry with "ZIEL" banner), curve (warning
## triangle "Kurve", value = direction +1 right / -1 left) and chevron (red-white direction board on the
## outside of a sharp curve, arrows pointing into the bend).
## Country styles (design document: „Grenzübergänge: Wechsel von Schildern …"): the sign's "country"
## selects the colours from countries.json signs {motorway, town_bg, town_fg, town_border} (optional
## road / road_fg for direction signs off the motorway), see style_for(). Motorway direction signs, the
## motorway sign and fuel signs on the motorway use the motorway colour; the town sign the town colours.
## Signs with "wall": true are mounted on a tunnel wall (no posts). Owner: race module.

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
## Half width (m, scale 1) of the board of each sign kind (tunnel walls: Track fits the board inside).
const HALF_WIDTH_M := {"limit": 0.85, "unlimited": 0.85, "radar": 1.05, "fuel": 1.5, "fuel_lane": 1.15,
	"town": 1.9, "town_ahead": 1.9, "distance": 2.4, "border": 1.75, "tunnel": 1.7, "autobahn": 0.95, "autobahn_end": 0.95,
	"curve": 0.9, "crest": 0.9, "chevron": 0.95}

var font: Font
var batch: GeoBatch
var ci: CanvasItem
var base_offset := Vector2.ZERO   ## current base transform (camera shake) of the canvas item
var countdown := -1.0             ## seconds left of the start countdown (start gantry lights)
var countries: Dictionary = {}    ## country code -> countries.json entry (GameData.countries), for sign styles
var _styles: Dictionary = {}      ## country code -> style_for() (cache)
var _wall := false                ## the sign being drawn hangs on a tunnel wall (no posts)


## Half width (m) of the board of a sign kind at scale 1.
static func board_half_width(kind: String) -> float:
	return float(HALF_WIDTH_M.get(kind, 1.5))


## Sign colours of a country: {motorway, motorway_fg, road, road_fg, town_bg, town_fg, town_border}.
## From countries[code].signs (colour strings); missing values fall back to the German style (blue
## motorway signs, yellow town sign). Direction signs off the motorway use signs.road / road_fg when
## given, else blue/white in countries with green motorway signs (CH, IT, …) and the town sign colours
## elsewhere (yellow in DE, blue in NL, white in FR …).
static func style_for(country_data: Dictionary, code: String) -> Dictionary:
	var c: Dictionary = country_data.get(code, {})
	var s: Dictionary = c.get("signs", {}) if c.get("signs", {}) is Dictionary else {}
	var st := {
		"motorway": _col(s, "motorway", BLUE_AB),
		"motorway_fg": _col(s, "motorway_fg", WHITE),
		"town_bg": _col(s, "town_bg", YELLOW),
		"town_fg": _col(s, "town_fg", BLACK),
		"town_border": _col(s, "town_border", BLACK),
	}
	var mw: Color = st["motorway"]
	if s.has("road"):
		st["road"] = _col(s, "road", YELLOW)
		st["road_fg"] = _col(s, "road_fg", contrast(st["road"]))
	elif mw.g > mw.b and mw.g > mw.r:
		st["road"] = BLUE_AB
		st["road_fg"] = WHITE
	else:
		st["road"] = st["town_bg"]
		st["road_fg"] = st["town_fg"]
	return st


static func _col(d: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = d.get(key)
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return fallback


## Black or white, whichever reads better on bg.
static func contrast(bg: Color) -> Color:
	return BLACK if bg.get_luminance() > 0.5 else WHITE


func _style(code: String) -> Dictionary:
	var st: Variant = _styles.get(code)
	if st == null:
		st = style_for(countries, code)
		_styles[code] = st
	return st


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
## Sign keys used here: sign (kind), text, value, country (style; border signs: the country entered),
## road (road type at the sign), wall (tunnel wall mount). The caller scales p.z by the sign's scale.
func draw(it: Dictionary, p: Vector3, lit: Color, alpha: float, edges_px: Vector2) -> void:
	var kind := str(it.get("sign", ""))
	var s := p.z
	if s < 0.6:
		return
	_wall = bool(it.get("wall", false))
	var st := _style(str(it.get("country", "")))
	var motorway := str(it.get("road", "autobahn")) == "autobahn"
	match kind:
		"limit", "unlimited":
			_round_sign(p, lit, alpha, kind == "unlimited", int(it.get("value", 0)))
		"radar":
			_radar_sign(p, lit, alpha, int(it.get("value", 0)), str(it.get("text", "")))
		"fuel":
			_fuel_sign(p, lit, alpha, str(it.get("text", "")), st["motorway"] if motorway else BLUE_AB)
		"fuel_lane":
			_fuel_lane_sign(p, lit, alpha, st["motorway"] if motorway else BLUE_AB)
		"town":
			_town_sign(p, lit, alpha, str(it.get("text", "")), st)
		"town_ahead":
			_town_ahead_sign(p, lit, alpha, str(it.get("text", "")), int(it.get("value", 0)), int(it.get("limit", 0)), st)
		"distance":
			_distance_sign(p, lit, alpha, str(it.get("text", "")), int(it.get("value", 0)),
				st["motorway"] if motorway else st["road"], st["motorway_fg"] if motorway else st["road_fg"])
		"border":
			_border_sign(p, lit, alpha, str(it.get("text", "")), str(it.get("country", "")))
		"tunnel":
			_tunnel_sign(p, lit, alpha, str(it.get("text", "")), int(it.get("value", 0)))
		"autobahn", "autobahn_end":
			_autobahn_sign(p, lit, alpha, kind == "autobahn_end", st["motorway"])
		"curve":
			_curve_sign(p, lit, alpha, int(it.get("value", 1)))
		"crest":
			_crest_sign(p, lit, alpha)
		"chevron":
			_chevron_board(p, lit, alpha, int(it.get("value", 1)))
		"start":
			_gantry(p, lit, alpha, edges_px, tr("START"), true)
		"finish":
			_gantry(p, lit, alpha, edges_px, str(it.get("text", "ZIEL")), false)
	_wall = false


# --- helpers --------------------------------------------------------------------------------

func _c(col: Color, lit: Color, alpha: float) -> Color:
	return Color(col.r * lit.r, col.g * lit.g, col.b * lit.b, alpha)


func _post(x: float, ground_y: float, top_y: float, w: float, lit: Color, alpha: float) -> void:
	if _wall:
		return   # mounted on the tunnel wall
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


func _fuel_sign(p: Vector3, lit: Color, alpha: float, dist: String, bg: Color) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.5 * s, p.y - 4.1 * s, 3.0 * s, 2.1 * s)
	_post(p.x - 1.0 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_post(p.x + 1.0 * s, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, bg, lit, alpha, WHITE, 0.07 * s)
	_pump_icon(Vector2(r.position.x + 0.75 * s, r.position.y + 0.95 * s), s, _c(WHITE, lit, alpha), _c(bg, lit, alpha))
	text(tr("Tankstelle"), Vector2(r.position.x + 1.95 * s, r.position.y + 0.72 * s), 0.3 * s, _c(WHITE, lit, alpha), 1.85 * s)
	text(dist, Vector2(r.position.x + 1.95 * s, r.position.y + 1.6 * s), 0.55 * s, _c(WHITE, lit, alpha), 1.85 * s)


func _fuel_lane_sign(p: Vector3, lit: Color, alpha: float, bg: Color) -> void:
	var s := p.z
	var r := Rect2(p.x - 1.15 * s, p.y - 4.2 * s, 2.3 * s, 2.3 * s)
	_post(p.x, p.y, r.end.y, 0.12 * s, lit, alpha)
	_board(r, bg, lit, alpha, WHITE, 0.07 * s)
	_pump_icon(Vector2(r.position.x + 0.75 * s, r.position.y + 0.85 * s), s * 0.9, _c(WHITE, lit, alpha), _c(bg, lit, alpha))
	var a0 := Vector2(r.position.x + 0.55 * s, r.end.y - 0.5 * s)
	var a1 := Vector2(r.end.x - 0.45 * s, r.end.y - 0.5 * s)
	var w := maxf(1.0, 0.16 * s)
	batch.line(a0, a1, w, _c(WHITE, lit, alpha))
	batch.tri(a1 + Vector2(0.22 * s, 0), a1 + Vector2(-0.12 * s, -0.25 * s), a1 + Vector2(-0.12 * s, 0.25 * s), _c(WHITE, lit, alpha))
	batch.line(Vector2(r.end.x - 0.6 * s, r.position.y + 0.45 * s), Vector2(r.end.x - 0.6 * s, r.position.y + 1.3 * s), w, _c(WHITE, lit, alpha))


## Town sign of the destination in the style of its country (DE yellow/black, NL and CH blue/white,
## FR white with a red border …).
func _town_sign(p: Vector3, lit: Color, alpha: float, name: String, st: Dictionary) -> void:
	var s := p.z
	var bg: Color = st["town_bg"]
	var fg: Color = st["town_fg"]
	var border: Color = st["town_border"]
	var r := Rect2(p.x - 1.9 * s, p.y - 3.3 * s, 3.8 * s, 1.75 * s)
	_post(p.x - 1.3 * s, p.y, r.end.y, 0.1 * s, lit, alpha)
	_post(p.x + 1.3 * s, p.y, r.end.y, 0.1 * s, lit, alpha)
	var thick := not border.is_equal_approx(fg)   # a coloured (e.g. red) border is drawn wider
	_board(r, bg, lit, alpha, border, (0.11 if thick else 0.05) * s)
	if 0.06 * s > 0.6:
		var inner := r.grow(-(0.2 if thick else 0.12) * s)
		batch.rect(inner, _c(border, lit, alpha))
		batch.rect(inner.grow(-0.05 * s), _c(bg, lit, alpha))
	text(name, Vector2(p.x, r.position.y + 1.08 * s), 0.62 * s, _c(fg, lit, alpha), 3.3 * s)
	text(tr("City Limits"), Vector2(p.x, r.end.y - 0.26 * s), 0.2 * s, _c(fg, lit, alpha), 3.0 * s)


## Advance sign of the City Limits (review v0.5.0: in snow the slow, dense city traffic right behind the town sign
## must not come as a surprise): the town board raised on its posts, below it a white plate "in <n> km" with the
## city speed limit as a small disc beside the text.
func _town_ahead_sign(p: Vector3, lit: Color, alpha: float, name: String, km: int, limit: int, st: Dictionary) -> void:
	var s := p.z
	var bg: Color = st["town_bg"]
	var fg: Color = st["town_fg"]
	var border: Color = st["town_border"]
	var r := Rect2(p.x - 1.9 * s, p.y - 4.2 * s, 3.8 * s, 1.75 * s)
	var plate := Rect2(p.x - 1.5 * s, r.end.y + 0.12 * s, 3.0 * s, 0.75 * s)
	_post(p.x - 1.3 * s, p.y, plate.end.y, 0.1 * s, lit, alpha)
	_post(p.x + 1.3 * s, p.y, plate.end.y, 0.1 * s, lit, alpha)
	var thick := not border.is_equal_approx(fg)
	_board(r, bg, lit, alpha, border, (0.11 if thick else 0.05) * s)
	if 0.06 * s > 0.6:
		var inner := r.grow(-(0.2 if thick else 0.12) * s)
		batch.rect(inner, _c(border, lit, alpha))
		batch.rect(inner.grow(-0.05 * s), _c(bg, lit, alpha))
	text(name, Vector2(p.x, r.position.y + 1.08 * s), 0.62 * s, _c(fg, lit, alpha), 3.3 * s)
	text(tr("City Limits"), Vector2(p.x, r.end.y - 0.26 * s), 0.2 * s, _c(fg, lit, alpha), 3.0 * s)
	_board(plate, WHITE, lit, alpha, BLACK, 0.04 * s)
	var tx := p.x if limit <= 0 else p.x - 0.42 * s
	text(tr("in %d km") % km, Vector2(tx, plate.end.y - 0.2 * s), 0.38 * s, _c(BLACK, lit, alpha), 1.9 * s)
	if limit > 0:
		var c := Vector2(plate.end.x - 0.45 * s, plate.get_center().y)
		var rr := 0.32 * s
		batch.ellipse(c, Vector2(rr, rr), _c(RED, lit, alpha), _c(RED, lit, alpha), 12)
		batch.ellipse(c, Vector2(rr * 0.76, rr * 0.76), _c(WHITE, lit, alpha), _c(WHITE, lit, alpha), 12)
		text(str(limit), Vector2(c.x, c.y + 0.12 * s), 0.24 * s, _c(BLACK, lit, alpha), 0.5 * s)


## Direction sign "<destination>  <n> km" in the country's colours (motorway or other road).
func _distance_sign(p: Vector3, lit: Color, alpha: float, name: String, km: int, bg: Color, fg: Color) -> void:
	var s := p.z
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


## Motorway begin/end sign (pictogram of a motorway bridge) in the country's motorway colour.
func _autobahn_sign(p: Vector3, lit: Color, alpha: float, ended: bool, bg: Color) -> void:
	var s := p.z
	var r := Rect2(p.x - 0.95 * s, p.y - 3.7 * s, 1.9 * s, 1.9 * s)
	_post(p.x, p.y, r.end.y, 0.11 * s, lit, alpha)
	_board(r, bg, lit, alpha, WHITE, 0.05 * s)
	var w := _c(WHITE, lit, alpha)
	var b := _c(bg, lit, alpha)
	var bottom := r.end.y - 0.18 * s
	var top := r.position.y + 0.55 * s
	batch.quad(Vector2(p.x - 0.75 * s, bottom), Vector2(p.x + 0.75 * s, bottom), Vector2(p.x + 0.12 * s, top), Vector2(p.x - 0.12 * s, top), w)
	batch.quad(Vector2(p.x - 0.05 * s, bottom), Vector2(p.x + 0.05 * s, bottom), Vector2(p.x + 0.015 * s, top), Vector2(p.x - 0.015 * s, top), b)
	batch.rect(Rect2(r.position.x + 0.2 * s, r.position.y + 0.42 * s, r.size.x - 0.4 * s, 0.16 * s), w)
	batch.rect(Rect2(r.position.x + 0.35 * s, r.position.y + 0.58 * s, 0.1 * s, 0.35 * s), w)
	batch.rect(Rect2(r.end.x - 0.45 * s, r.position.y + 0.58 * s, 0.1 * s, 0.35 * s), w)
	if ended:
		batch.line(Vector2(r.position.x + 0.1 * s, r.end.y - 0.1 * s), Vector2(r.end.x - 0.1 * s, r.position.y + 0.1 * s), maxf(1.0, 0.18 * s), _c(RED, lit, alpha))


## Warning sign "Kurve" (Gefahrzeichen): white triangle with a red border and a black bent arrow towards
## dir (+1 right bend, -1 left bend). Slightly larger than real (readable at speed).
func _curve_sign(p: Vector3, lit: Color, alpha: float, dir: int) -> void:
	var s := p.z
	var d := 1.0 if dir >= 0 else -1.0
	var base := p.y - 2.0 * s
	var top := base - 1.55 * s
	_post(p.x, p.y, base, 0.11 * s, lit, alpha)
	var red := _c(RED, lit, alpha)
	var white := _c(WHITE, lit, alpha)
	var black := _c(BLACK, lit, alpha)
	batch.tri(Vector2(p.x, top), Vector2(p.x + 0.9 * s, base), Vector2(p.x - 0.9 * s, base), red)
	batch.tri(Vector2(p.x, top + 0.36 * s), Vector2(p.x + 0.6 * s, base - 0.15 * s), Vector2(p.x - 0.6 * s, base - 0.15 * s), white)
	if s < 3.0:
		return   # too small for the pictogram
	var w := maxf(1.0, 0.09 * s)
	var a := Vector2(p.x - 0.1 * d * s, base - 0.25 * s)
	var b := Vector2(p.x - 0.1 * d * s, base - 0.6 * s)
	var c := Vector2(p.x + 0.12 * d * s, base - 0.86 * s)
	batch.line(a, b, w, black)
	batch.line(b, c, w, black)
	var dirv := (c - b).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	batch.tri(c + dirv * 0.16 * s, c + nrm * 0.12 * s, c - nrm * 0.12 * s, black)


## Warning sign "Kuppe" before a blind crest (Track, road.crest_warning_*): the red warning triangle like the curve
## sign, inside a black hump with the road running over it.
func _crest_sign(p: Vector3, lit: Color, alpha: float) -> void:
	var s := p.z
	var base := p.y - 2.0 * s
	var top := base - 1.55 * s
	_post(p.x, p.y, base, 0.11 * s, lit, alpha)
	var red := _c(RED, lit, alpha)
	var white := _c(WHITE, lit, alpha)
	var black := _c(BLACK, lit, alpha)
	batch.tri(Vector2(p.x, top), Vector2(p.x + 0.9 * s, base), Vector2(p.x - 0.9 * s, base), red)
	batch.tri(Vector2(p.x, top + 0.36 * s), Vector2(p.x + 0.6 * s, base - 0.15 * s), Vector2(p.x - 0.6 * s, base - 0.15 * s), white)
	if s < 3.0:
		return   # too small for the pictogram
	# the hump: a fan of triangles from the middle of its foot along a half ellipse
	var foot := Vector2(p.x, base - 0.24 * s)
	var prev := Vector2(p.x - 0.42 * s, foot.y)
	for i in range(1, 9):
		var a := PI * (1.0 - float(i) / 8.0)
		var q := Vector2(p.x + cos(a) * 0.42 * s, foot.y - sin(a) * 0.4 * s)
		batch.tri(foot, prev, q, black)
		prev = q


## Red-white direction board (Richtungstafel) on the outside of a sharp curve: red board, three white
## chevrons pointing into the bend (dir +1 right, -1 left), on two short posts.
func _chevron_board(p: Vector3, lit: Color, alpha: float, dir: int) -> void:
	var s := p.z
	var d := 1.0 if dir >= 0 else -1.0
	var r := Rect2(p.x - 0.95 * s, p.y - 1.95 * s, 1.9 * s, 0.75 * s)
	_post(p.x - 0.6 * s, p.y, r.end.y, 0.09 * s, lit, alpha)
	_post(p.x + 0.6 * s, p.y, r.end.y, 0.09 * s, lit, alpha)
	_board(r, RED, lit, alpha, WHITE, 0.05 * s)
	var white := _c(WHITE, lit, alpha)
	var w := maxf(1.0, 0.13 * s)
	var my := r.get_center().y
	for i in 3:
		var cx := p.x + (float(i) - 1.0) * 0.55 * s
		var tip := Vector2(cx + 0.16 * d * s, my)
		batch.line(Vector2(cx - 0.12 * d * s, r.position.y + 0.12 * s), tip, w, white)
		batch.line(tip, Vector2(cx - 0.12 * d * s, r.end.y - 0.12 * s), w, white)


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
