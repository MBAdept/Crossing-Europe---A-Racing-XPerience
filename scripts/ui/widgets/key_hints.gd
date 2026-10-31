class_name KeyHints
extends Control
## Footer with input hints, keyboard keycaps and gamepad buttons side by side:
##   hints = [[["Enter", "pad:A"], "Auswählen"], [["Esc", "pad:B"], "Zurück"], [["lr"], "Ändern"]]
## Special key names: "lr" / "ud" (arrow pairs), "left" / "right" / "up" / "down" (single arrows),
## "pad:A|B|X|Y|LB|RB|LT|RT|LS|RS|Start", "dpad:<directions>" (D-pad with the arms u/d/l/r lit).
## While a gamepad is the active input (InputMode.gamepad) only gamepad glyphs are drawn
## (visible_hints()); a key press switches back to keycaps and pad buttons side by side.

const PAD_COLORS := {"A": Color("3fbf5f"), "B": Color("e0434f"), "X": Color("3b7be8"), "Y": Color("e8b53b")}
const ARROWS := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}
const ARROW_DIRS := {"left": "l", "right": "r", "up": "u", "down": "d", "lr": "lr", "ud": "ud"}
const STICKS := ["LS", "RS"]

var hints: Array = []
var align := HORIZONTAL_ALIGNMENT_LEFT
var _font: Font
var _font_bold: Font
var _gamepad_drawn := false


func _init(p_hints: Array = []) -> void:
	hints = p_hints
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.font(UiTheme.F.BODY)
	_font_bold = UiTheme.font(UiTheme.F.BODY_BOLD)


func _process(_delta: float) -> void:
	if InputMode.gamepad != _gamepad_drawn:
		queue_redraw()


func set_hints(p: Array) -> void:
	hints = p
	queue_redraw()


## The hints as drawn. Keyboard: unchanged. Gamepad: pad buttons stay; arrow keys become one D-pad
## glyph where the hint has no pad button (menus: D-pad / stick move the focus); all other keys are
## dropped, and a hint left without a glyph is left out.
static func visible_hints(p_hints: Array, gamepad: bool) -> Array:
	if not gamepad:
		return p_hints
	var out: Array = []
	for h in p_hints:
		var pads: Array = []
		var dirs := ""
		for k in h[0]:
			var key := str(k)
			if key.begins_with("pad:") or key.begins_with("dpad:"):
				pads.append(key)
			elif ARROW_DIRS.has(key):
				dirs += str(ARROW_DIRS[key])
		if pads.is_empty() and dirs != "":
			var arms := ""
			for d in "udlr":
				if dirs.contains(d):
					arms += d
			pads.append("dpad:" + arms)
		if not pads.is_empty():
			out.append([pads, h[1]])
	return out


func _key_width(k: String) -> float:
	if k.begins_with("pad:"):
		var b := k.substr(4)
		if b.length() == 1 or STICKS.has(b):
			return 26.0
		return _font_bold.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0
	if k.begins_with("dpad:"):
		return 26.0
	if k == "lr" or k == "ud":
		return 44.0
	if ARROWS.has(k):
		return 26.0
	return maxf(26.0, _font_bold.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0)


func _total_width(shown: Array) -> float:
	var w := 0.0
	for h in shown:
		for k in h[0]:
			w += _key_width(str(k)) + 4.0
		w += _font.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 30.0
	return w


func _draw() -> void:
	_gamepad_drawn = InputMode.gamepad
	var shown := visible_hints(hints, _gamepad_drawn)
	var x := 0.0
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - _total_width(shown)
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - _total_width(shown)) * 0.5
	var cy := size.y * 0.5
	for h in shown:
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
	if key.begins_with("dpad:"):
		_draw_dpad(r, key.substr(5))
		return
	if key.begins_with("pad:"):
		var b := key.substr(4)
		var col: Color = PAD_COLORS.get(b, Color(0.35, 0.38, 0.5))
		var c := r.get_center()
		if b.length() == 1:
			draw_circle(c, 12.0, Color(0.05, 0.06, 0.12))
			draw_arc(c, 12.0, 0.0, TAU, 24, col, 2.0, true)
			draw_string(_font_bold, Vector2(r.position.x, c.y + 5.5), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, col)
		elif STICKS.has(b):
			# thumbstick: lighter cap inside the ring
			draw_circle(c, 12.5, Color(0.05, 0.06, 0.12))
			draw_circle(c, 10.5, Color(0.16, 0.18, 0.3))
			draw_arc(c, 12.5, 0.0, TAU, 28, Color(0.5, 0.55, 0.7), 2.0, true)
			draw_string(_font_bold, Vector2(r.position.x, c.y + 5.0), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, UiTheme.TEXT)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.05, 0.06, 0.12)
			sb.border_color = Color(0.5, 0.55, 0.7)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(9)
			draw_style_box(sb, r)
			draw_string(_font_bold, Vector2(r.position.x, r.position.y + 18.5), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, UiTheme.TEXT)
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


## D-pad (Xbox / Steam Deck): a cross, the arms in `arms` ("u", "d", "l", "r") lit.
func _draw_dpad(r: Rect2, arms: String) -> void:
	var c := r.get_center()
	var reach := 12.0      # centre to arm end
	var half := 4.5        # half arm width
	var rim := Color(0.5, 0.55, 0.7)
	var base := Color(0.05, 0.06, 0.12)
	var lit := Color(0.88, 0.9, 0.97)
	draw_rect(Rect2(c.x - reach, c.y - half, reach * 2.0, half * 2.0), rim)
	draw_rect(Rect2(c.x - half, c.y - reach, half * 2.0, reach * 2.0), rim)
	var inner := reach - 1.5
	var ih := half - 1.5
	draw_rect(Rect2(c.x - inner, c.y - ih, inner * 2.0, ih * 2.0), base)
	draw_rect(Rect2(c.x - ih, c.y - inner, ih * 2.0, inner * 2.0), base)
	var dirs := {"u": Vector2(0, -1), "d": Vector2(0, 1), "l": Vector2(-1, 0), "r": Vector2(1, 0)}
	for a in arms:
		if not dirs.has(a):
			continue
		var d: Vector2 = dirs[a]
		var n := Vector2(-d.y, d.x)
		# lit arm: from just outside the centre to the arm end
		var p0 := c + d * (ih + 1.0)
		var p1 := c + d * inner
		var q := PackedVector2Array([p0 + n * ih, p1 + n * ih, p1 - n * ih, p0 - n * ih])
		draw_colored_polygon(q, lit)
