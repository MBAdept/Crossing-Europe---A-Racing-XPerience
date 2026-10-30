class_name SkyPreview
extends Control
## Daytime preview for the start-time screen: a small landscape (sky, sun/moon, stars, fields, road)
## coloured with the race renderer's palette (Palette.compute, bound at runtime with a fallback so a
## change in the race module cannot break this script) for the chosen hour and weather,
## plus a 24-hour timeline with day/night bands and the selected time marker.

const PALETTE_SCRIPT := "res://scripts/race/palette.gd"
static var _palette_script: Script = null

var hour := 8.0
var weather := "normal"
var daytime: Dictionary = {}
var _t := 0.0
var _stars: Array[Vector2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	daytime = ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		_stars.append(Vector2(rng.randf(), rng.randf() * 0.5))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Palette of the race renderer for an hour (fallback: simple day/night colours).
static func palette(h: float, w: String, daytime_cfg: Dictionary) -> Dictionary:
	if _palette_script == null and ResourceLoader.exists(PALETTE_SCRIPT):
		_palette_script = load(PALETTE_SCRIPT)
	if _palette_script != null:
		var r: Variant = _palette_script.call("compute", h, w, daytime_cfg, false)
		if r is Dictionary and (r as Dictionary).has("sky_top"):
			return r
	var night := 1.0 if (h < 6.0 or h > 20.0) else 0.0
	return {"sky_top": Color("2a6ad8").lerp(Color("05070f"), night), "sky_bottom": Color("b3daf7").lerp(Color("15203d"), night),
		"ambient": Color.WHITE.lerp(Color("39415a"), night), "fog": Color("c9e0f2").lerp(Color("0b1020"), night),
		"stars": night, "lights": night, "sun_visible": night < 0.5, "sun_pos": Vector2(0.5, 0.3), "sun": Color("fff6d8")}


func _draw() -> void:
	var w := size.x
	var h := size.y - 44.0
	var hy := h * 0.55
	var pal := palette(hour, weather, daytime)
	var top: Color = pal.get("sky_top", Color.BLACK)
	var bottom: Color = pal.get("sky_bottom", Color.DIM_GRAY)
	var amb: Color = pal.get("ambient", Color.WHITE)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([top, top, bottom, bottom]))
	var stars := float(pal.get("stars", 0.0))
	if stars > 0.01:
		for s in _stars:
			draw_rect(Rect2(s.x * w, s.y * hy, 2, 2), Color(1, 1, 1, stars * (0.5 + 0.4 * sin(_t * 2.0 + s.x * 40.0))))
	if bool(pal.get("sun_visible", false)):
		var sp: Vector2 = pal.get("sun_pos", Vector2(0.5, 0.5))
		var sc := Vector2(sp.x * w, sp.y * hy)
		var sun_col: Color = pal.get("sun", Color.WHITE)
		draw_circle(sc, 34.0, Color(sun_col, 0.18))
		draw_circle(sc, 20.0, sun_col)
	elif stars > 0.5:
		UiIcons.moon(self, Vector2(w * 0.78, hy * 0.3), 18.0, Color("e6ecff"))
	var grass := Color("5d9a3e") * amb
	grass.a = 1.0
	draw_rect(Rect2(0, hy, w, h - hy), grass)
	var stripes := Color("56913a") * amb
	stripes.a = 1.0
	for i in 6:
		var y0 := hy + (h - hy) * pow(float(i) / 6.0, 1.6)
		var y1 := hy + (h - hy) * pow((float(i) + 0.5) / 6.0, 1.6)
		draw_rect(Rect2(0, y0, w, y1 - y0), stripes)
	var road := Color("5c5e64") * amb
	road.a = 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 4, hy), Vector2(w * 0.5 + 4, hy), Vector2(w * 0.5 + w * 0.32, h), Vector2(w * 0.5 - w * 0.32, h)]), road)
	var fog: Color = pal.get("fog", Color.GRAY)
	draw_polygon(PackedVector2Array([Vector2(0, hy - 8), Vector2(w, hy - 8), Vector2(w, hy + 26), Vector2(0, hy + 26)]),
		PackedColorArray([Color(fog, 0.0), Color(fog, 0.0), Color(fog, 0.5), Color(fog, 0.5)]))
	# tree silhouettes beside the road (tinted by the ambient light)
	var leaf := Color("3e7a32") * amb
	leaf.a = 1.0
	var trunk := Color("5a3d22") * amb
	trunk.a = 1.0
	for side: float in [-1.0, 1.0]:
		for i in 5:
			var f := pow(float(i + 1) / 6.0, 1.7)
			var base_y := hy + (h - hy) * f
			var x := w * 0.5 + side * (w * 0.05 + w * 0.5 * f)
			var sz := 6.0 + 40.0 * f
			draw_rect(Rect2(x - sz * 0.08, base_y - sz * 0.9, sz * 0.16, sz * 0.9), trunk)
			draw_circle(Vector2(x, base_y - sz * 1.1), sz * 0.45, leaf)
	var lights := float(pal.get("lights", 0.0))
	if lights > 0.3:
		for i in 4:
			var f := 0.2 + i * 0.22
			var p := Vector2(w * 0.5, hy).lerp(Vector2(w * 0.5 + w * 0.06, h), f)
			draw_circle(p, 3.0 + f * 5.0, Color(1.0, 0.25, 0.2, lights))
	draw_rect(Rect2(0, 0, w, h), Color(UiTheme.ACCENT_2, 0.4), false, 1.5)
	_draw_timeline(Rect2(0, h + 12, w, 22))


func _draw_timeline(r: Rect2) -> void:
	var n := 96
	for i in n:
		var hh := 24.0 * i / n
		var p := palette(hh, "normal", daytime)
		var c: Color = (p.get("sky_top", Color.BLACK) as Color).lerp(p.get("sky_bottom", Color.BLACK), 0.5)
		draw_rect(Rect2(r.position.x + r.size.x * i / n, r.position.y, r.size.x / n + 1.0, r.size.y), c)
	draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)
	var font := UiTheme.font(UiTheme.F.BODY)
	for hh: int in [0, 6, 12, 18]:
		var x := r.position.x + r.size.x * hh / 24.0
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.4), 1.0)
		draw_string(font, Vector2(x + 3, r.end.y - 4), "%02d" % hh, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
	var mx := r.position.x + r.size.x * fposmod(hour, 24.0) / 24.0
	draw_colored_polygon(PackedVector2Array([Vector2(mx - 7, r.position.y - 9), Vector2(mx + 7, r.position.y - 9), Vector2(mx, r.position.y + 1)]), UiTheme.GOLD)
	draw_line(Vector2(mx, r.position.y), Vector2(mx, r.end.y), UiTheme.GOLD, 2.0)
