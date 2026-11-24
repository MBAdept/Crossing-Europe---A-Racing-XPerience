class_name Marquee
extends Control
## Scrolling record ticker (Laufschrift) in LED style: text loops right-to-left, scanline overlay.

var text := ""
var speed := 90.0
var color := UiTheme.GOLD
var font_size := 26
var _offset := 0.0
var _font: Font


func _init(p_text: String = "") -> void:
	text = p_text
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.font(UiTheme.F.MONO)
	speed = float(ConfigLoader.lookup(ConfigLoader.load_merged(), "hud.marquee_speed_px_s", speed))


func _process(delta: float) -> void:
	_offset += speed * delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.03, 0.02, 0.0, 0.92))
	if text == "":
		return
	var seg := text + "   +++   "
	var tw := _font.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if tw <= 1.0:
		return
	var x := 24.0 - fmod(_offset, tw)
	var y := size.y * 0.5 + _font.get_ascent(font_size) * 0.38
	while x < size.x:
		draw_string(_font, Vector2(x, y), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, 0.25))
		draw_string(_font, Vector2(x, y - 1), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += tw
	var yy := 0.0
	while yy < size.y:
		draw_line(Vector2(0, yy), Vector2(size.x, yy), Color(0, 0, 0, 0.35), 1.0)
		yy += 3.0
	draw_rect(r, Color(color, 0.5), false, 1.5)
