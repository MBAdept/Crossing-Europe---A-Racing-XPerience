class_name KeyHints
extends Control
## Footer with input hints, keyboard keycaps and gamepad buttons side by side:
##   hints = [[["Enter", "pad:A"], "Auswählen"], [["Esc", "pad:B"], "Zurück"], [["lr"], "Ändern"]]
## Special key names: "lr" / "ud" (arrow pairs), "left" / "right" / "up" / "down" (single arrows),
## "pad:A|B|X|Y|LB|RB|LT|RT|Start".

const PAD_COLORS := {"A": Color("3fbf5f"), "B": Color("e0434f"), "X": Color("3b7be8"), "Y": Color("e8b53b")}
const ARROWS := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}

var hints: Array = []
var align := HORIZONTAL_ALIGNMENT_LEFT
var _font: Font
var _font_bold: Font


func _init(p_hints: Array = []) -> void:
	hints = p_hints
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.font(UiTheme.F.BODY)
	_font_bold = UiTheme.font(UiTheme.F.BODY_BOLD)


func set_hints(p: Array) -> void:
	hints = p
	queue_redraw()


func _key_width(k: String) -> float:
	if k.begins_with("pad:"):
		var b := k.substr(4)
		return 26.0 if b.length() == 1 else _font_bold.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
	if k == "lr" or k == "ud":
		return 44.0
	if ARROWS.has(k):
		return 26.0
	return maxf(26.0, _font_bold.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0)


func _total_width() -> float:
	var w := 0.0
	for h in hints:
		for k in h[0]:
			w += _key_width(str(k)) + 4.0
		w += _font.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 30.0
	return w


func _draw() -> void:
	var x := 0.0
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - _total_width()
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - _total_width()) * 0.5
	var cy := size.y * 0.5
	for h in hints:
		for k in h[0]:
			var key := str(k)
			var kw := _key_width(key)
			_draw_key(Rect2(x, cy - 13, kw, 26), key)
			x += kw + 4.0
		x += 4.0
		var label := str(h[1])
		draw_string(_font, Vector2(x, cy + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiTheme.TEXT_DIM)
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 26.0


func _draw_key(r: Rect2, key: String) -> void:
	if key.begins_with("pad:"):
		var b := key.substr(4)
		var col: Color = PAD_COLORS.get(b, Color(0.35, 0.38, 0.5))
		if b.length() == 1:
			var c := r.get_center()
			draw_circle(c, 12.0, Color(0.05, 0.06, 0.12))
			draw_arc(c, 12.0, 0.0, TAU, 24, col, 2.0, true)
			draw_string(_font_bold, Vector2(r.position.x, c.y + 5.5), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, col)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.05, 0.06, 0.12)
			sb.border_color = Color(0.5, 0.55, 0.7)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(9)
			draw_style_box(sb, r)
			draw_string(_font_bold, Vector2(r.position.x, r.position.y + 18), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, UiTheme.TEXT)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.85, 0.87, 0.95, 0.95)
	box.border_color = Color(0.45, 0.48, 0.6)
	box.border_width_bottom = 3
	box.set_corner_radius_all(4)
	draw_style_box(box, r)
	var ink := Color(0.08, 0.09, 0.16)
	if ARROWS.has(key):
		var d: Vector2 = ARROWS[key]
		var n := Vector2(-d.y, d.x)
		var c1 := r.get_center() + Vector2(0, -1)
		draw_colored_polygon(PackedVector2Array([c1 + d * 5.0, c1 - d * 3.0 + n * 5.0, c1 - d * 3.0 - n * 5.0]), ink)
		return
	if key == "lr" or key == "ud":
		var c2 := r.get_center() + Vector2(0, -1)
		for s in [-1.0, 1.0]:
			var p := c2 + (Vector2(s * 10.0, 0) if key == "lr" else Vector2(s * 9.0, 0))
			var tri := PackedVector2Array()
			if key == "lr":
				tri = PackedVector2Array([p + Vector2(s * 5.0, 0), p + Vector2(-s * 3.0, -5.0), p + Vector2(-s * 3.0, 5.0)])
			else:
				tri = PackedVector2Array([p + Vector2(0, s * 5.0), p + Vector2(-5.0, -s * 3.0), p + Vector2(5.0, -s * 3.0)])
			draw_colored_polygon(tri, ink)
		return
	draw_string(_font_bold, Vector2(r.position.x, r.position.y + 18), key, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, ink)
