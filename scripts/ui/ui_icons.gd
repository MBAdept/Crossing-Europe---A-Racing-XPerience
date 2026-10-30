class_name UiIcons
extends RefCounted
## Vector icons drawn with CanvasItem primitives (crisp at any size, no texture assets needed):
## weather, daytime, fuel pump, radar camera, police beacon, flags, speed-limit signs, checkered flag.
## If the sprite manifest provides "ui/<icon>" sets (weather_*, daytime_*), those are used instead.


static func _sprite_icon(ci: CanvasItem, set_id: String, c: Vector2, s: float, tint: Color) -> bool:
	if not ci.is_inside_tree():
		return false
	var db: Node = ci.get_node_or_null("/root/SpriteDB")
	if db == null or not db.call("has_set", set_id):
		return false
	var tex: Texture2D = db.call("texture", set_id)
	if tex == null:
		return false
	var region: Rect2 = db.call("region", set_id, "c", "base")
	if region.size.x <= 0.0:
		return false
	var aspect := region.size.x / maxf(region.size.y, 1.0)
	var size := Vector2(s * aspect, s) if aspect < 1.0 else Vector2(s, s / aspect)
	ci.draw_texture_rect_region(tex, Rect2(c - size * 0.5, size), region, tint)
	return true


## Weather icon ("normal" sun, "rain" cloud + drops, "snow" cloud + flakes); s = icon size in px.
static func weather(ci: CanvasItem, kind: String, c: Vector2, s: float, tint: Color = Color.WHITE) -> void:
	if _sprite_icon(ci, "ui/weather_" + kind, c, s, tint):
		return
	match kind:
		"rain":
			cloud(ci, c + Vector2(0, -s * 0.1), s * 0.8, Color("c9d6ea") * tint)
			var drop_col := Color("6fb0ff") * tint
			for i in 3:
				var x := c.x - s * 0.22 + i * s * 0.22
				var y := c.y + s * 0.2
				ci.draw_line(Vector2(x, y), Vector2(x - s * 0.08, y + s * 0.22), drop_col, maxf(1.5, s * 0.07), true)
		"snow":
			cloud(ci, c + Vector2(0, -s * 0.1), s * 0.8, Color("dfe8f5") * tint)
			for i in 3:
				var p := Vector2(c.x - s * 0.22 + i * s * 0.22, c.y + s * 0.3 + (i % 2) * s * 0.06)
				snowflake(ci, p, s * 0.1, Color.WHITE * tint)
		_:
			sun(ci, c, s * 0.5, Color("ffd23f") * tint)


static func sun(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r * 0.52, col)
	for i in 8:
		var a := i * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * r * 0.7, c + d * r * 0.98, col, maxf(1.5, r * 0.13), true)


static func cloud(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.22, s * 0.05), s * 0.2, col)
	ci.draw_circle(c + Vector2(0.0, -s * 0.08), s * 0.27, col)
	ci.draw_circle(c + Vector2(s * 0.24, s * 0.06), s * 0.19, col)
	ci.draw_rect(Rect2(c.x - s * 0.42, c.y + s * 0.02, s * 0.84, s * 0.22), col)
	ci.draw_circle(c + Vector2(-s * 0.42, s * 0.13), s * 0.11, col)
	ci.draw_circle(c + Vector2(s * 0.42, s * 0.13), s * 0.11, col)


static func snowflake(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var a := i * PI / 3.0 + PI / 2.0
		var d := Vector2(cos(a), sin(a)) * r
		ci.draw_line(c - d, c + d, col, maxf(1.2, r * 0.25), true)


## Daytime icon: day sun, night crescent + star, dawn/dusk half sun over the horizon.
static func daytime(ci: CanvasItem, cat: String, c: Vector2, s: float, tint: Color = Color.WHITE) -> void:
	if _sprite_icon(ci, "ui/daytime_" + cat, c, s, tint):
		return
	match cat:
		"night":
			moon(ci, c + Vector2(s * 0.04, 0), s * 0.42, Color("dfe6ff") * tint)
			star(ci, c + Vector2(s * 0.3, -s * 0.28), s * 0.1, Color("ffe9a8") * tint)
		"dawn", "dusk":
			var col := (Color("ffb347") if cat == "dawn" else Color("ff7a45")) * tint
			var base := c + Vector2(0, s * 0.14)
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI + i * PI / 16.0
				pts.append(base + Vector2(cos(a), sin(a)) * s * 0.26)
			ci.draw_colored_polygon(pts, col)
			for i in 5:
				var a := PI + (i + 1) * PI / 6.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(base + d * s * 0.34, base + d * s * 0.47, col, maxf(1.5, s * 0.06), true)
			ci.draw_line(base + Vector2(-s * 0.5, 0), base + Vector2(s * 0.5, 0), col, maxf(1.5, s * 0.06), true)
			# small arrow below the horizon: up = sunrise, down = sunset
			var up := cat == "dawn"
			var tip := base + Vector2(0, s * (0.16 if up else 0.36))
			var tail := base + Vector2(0, s * (0.36 if up else 0.16))
			var wv := maxf(1.2, s * 0.05)
			ci.draw_line(tail, tip, col, wv, true)
			var back := s * (0.08 if up else -0.08)
			ci.draw_line(tip, tip + Vector2(-s * 0.08, back), col, wv, true)
			ci.draw_line(tip, tip + Vector2(s * 0.08, back), col, wv, true)
		_:
			sun(ci, c, s * 0.5, Color("ffd23f") * tint)


## Crescent moon (lit on the left).
static func moon(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var t := i * PI / n
		pts.append(Vector2(c.x - r * sin(t), c.y - r * cos(t)))
	for i in range(n, -1, -1):
		var t := i * PI / n
		pts.append(Vector2(c.x - r * 0.25 * sin(t), c.y - r * cos(t)))
	ci.draw_colored_polygon(pts, col)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0 - PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.38
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


## Fuel pump.
static func pump(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.46
	var h := s * 0.72
	var body := Rect2(c.x - s * 0.36, c.y - h * 0.5, w, h)
	ci.draw_rect(body, col)
	ci.draw_rect(Rect2(body.position + Vector2(w * 0.18, h * 0.12), Vector2(w * 0.64, h * 0.26)), Color(0, 0, 0, 0.55))
	ci.draw_rect(Rect2(c.x - s * 0.42, c.y + h * 0.5 - s * 0.06, w + s * 0.12, s * 0.08), col)
	var hose := PackedVector2Array([
		Vector2(body.end.x, body.position.y + h * 0.22), Vector2(body.end.x + s * 0.16, body.position.y + h * 0.3),
		Vector2(body.end.x + s * 0.16, body.position.y + h * 0.78), Vector2(body.end.x + s * 0.26, body.position.y + h * 0.78),
		Vector2(body.end.x + s * 0.26, body.position.y + h * 0.2)])
	ci.draw_polyline(hose, col, maxf(1.5, s * 0.07), true)


## Radar camera with flash rays.
static func radar(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var box := Rect2(c.x - s * 0.36, c.y - s * 0.2, s * 0.56, s * 0.4)
	ci.draw_rect(box, col)
	ci.draw_circle(Vector2(box.end.x - s * 0.06, c.y), s * 0.13, col)
	ci.draw_circle(Vector2(box.end.x - s * 0.06, c.y), s * 0.07, Color(0, 0, 0, 0.6))
	ci.draw_line(Vector2(c.x - s * 0.1, box.end.y), Vector2(c.x - s * 0.1, c.y + s * 0.48), col, maxf(1.5, s * 0.08), true)
	for i in 3:
		var a := -0.5 + i * 0.5
		var d := Vector2(cos(a), sin(a))
		var p := Vector2(box.end.x + s * 0.12, c.y)
		ci.draw_line(p + d * s * 0.1, p + d * s * 0.3, col, maxf(1.2, s * 0.06), true)


## Blue beacon (police); phase 0..1 animates the light.
static func beacon(ci: CanvasItem, c: Vector2, s: float, phase: float) -> void:
	var on := fmod(phase, 1.0) < 0.5
	var col := Color("3d8bff") if on else Color("1b3a7a")
	if on:
		ci.draw_circle(c + Vector2(0, -s * 0.05), s * 0.55, Color(0.25, 0.5, 1.0, 0.25))
	var pts := PackedVector2Array()
	for i in 11:
		var a := PI + i * PI / 10.0
		pts.append(c + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.34))
	ci.draw_colored_polygon(pts, col)
	ci.draw_rect(Rect2(c.x - s * 0.38, c.y, s * 0.76, s * 0.14), Color("c9d2e8"))


## Three flag stripes (horizontal) from countries.json colours.
static func flag(ci: CanvasItem, rect: Rect2, colors: Array, vertical: bool = false) -> void:
	if colors.is_empty():
		ci.draw_rect(rect, Color(0.5, 0.5, 0.6))
		return
	var n := colors.size()
	for i in n:
		var col := Color.html(str(colors[i])) if str(colors[i]).begins_with("#") else Color(0.5, 0.5, 0.6)
		var r := Rect2(rect.position.x + rect.size.x * i / n, rect.position.y, rect.size.x / n, rect.size.y) if vertical \
			else Rect2(rect.position.x, rect.position.y + rect.size.y * i / n, rect.size.x, rect.size.y / n)
		ci.draw_rect(r, col)
	ci.draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)


static func checkered(ci: CanvasItem, rect: Rect2, cells_x: int, cells_y: int, a: Color = Color.WHITE, b: Color = Color(0.08, 0.08, 0.1)) -> void:
	var cw := rect.size.x / cells_x
	var chh := rect.size.y / cells_y
	for y in cells_y:
		for x in cells_x:
			ci.draw_rect(Rect2(rect.position + Vector2(x * cw, y * chh), Vector2(cw, chh)), a if (x + y) % 2 == 0 else b)


## Round speed-limit sign (red ring, number) or – for limit 0 – the German "end of all restrictions"
## sign (white disc, diagonal black stripes).
static func speed_sign(ci: CanvasItem, c: Vector2, r: float, limit: int, font: Font, alpha: float = 1.0) -> void:
	ci.draw_circle(c, r + 1.5, Color(0, 0, 0, 0.35 * alpha))
	ci.draw_circle(c, r, Color(0.97, 0.97, 0.95, alpha))
	if limit > 0:
		ci.draw_arc(c, r - r * 0.1, 0.0, TAU, 48, Color(0.86, 0.1, 0.12, alpha), r * 0.2, true)
		var txt := str(limit)
		var fs := int(r * (0.95 if txt.length() <= 2 else 0.78))
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var base := Vector2(c.x - sz.x * 0.5, c.y + font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.35)
		ci.draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.08, 0.08, alpha))
	else:
		ci.draw_arc(c, r - 1.0, 0.0, TAU, 48, Color(0.2, 0.2, 0.2, alpha), 2.0, true)
		var u := Vector2(0.7071, -0.7071)
		var n := Vector2(0.7071, 0.7071)
		for i in 5:
			var d := (i - 2) * r * 0.17
			var half := sqrt(maxf(0.0, (r * 0.86) * (r * 0.86) - d * d))
			var p := c + n * d
			ci.draw_line(p - u * half, p + u * half, Color(0.12, 0.12, 0.12, alpha), maxf(1.5, r * 0.06), true)


## Small chevron arrow (dir -1 = left, +1 = right).
static func chevron(ci: CanvasItem, c: Vector2, s: float, dir: float, col: Color, width: float = 3.0) -> void:
	var pts := PackedVector2Array([c + Vector2(-dir * s * 0.3, -s * 0.5), c + Vector2(dir * s * 0.3, 0), c + Vector2(-dir * s * 0.3, s * 0.5)])
	ci.draw_polyline(pts, col, width, true)


## Polygon of a rectangle with chamfered top-left and bottom-right corners (retro panel shape).
static func chamfer_rect(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + cut, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y),
		Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + cut)])


## Filled chamfered panel with an optional border.
static func panel(ci: CanvasItem, r: Rect2, bg: Color, border: Color = Color(0, 0, 0, 0), cut: float = 10.0, border_w: float = 1.5) -> void:
	var pts := chamfer_rect(r, cut)
	ci.draw_colored_polygon(pts, bg)
	if border.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, border, border_w, true)
