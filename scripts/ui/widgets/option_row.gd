class_name OptionRow
extends Button
## Focusable settings row "Label   ◀ Value ▶": ui_left / ui_right change the value (keyboard, d-pad,
## stick), ui_accept / click cycles forward. bar_mode shows the value as a segmented bar (volumes).

signal value_changed(index: int)

var label_text := ""
var values: Array[String] = []
var index := 0
var bar_mode := false
var wrap := true
var value_color := UiTheme.GOLD
var value_width := 250.0
var _font: Font
var _font_val: Font
var _flash := 0.0


func _init(p_label: String = "", p_values: Array = [], p_index: int = 0) -> void:
	label_text = p_label
	for v in p_values:
		values.append(str(v))
	index = clampi(p_index, 0, maxi(values.size() - 1, 0))
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 50)
	text = ""
	pressed.connect(func() -> void: step(1))


func _ready() -> void:
	_font = UiTheme.font(UiTheme.F.HEADING)
	_font_val = UiTheme.font(UiTheme.F.BODY_BOLD)


func set_values(p_values: Array, p_index: int) -> void:
	values.clear()
	for v in p_values:
		values.append(str(v))
	index = clampi(p_index, 0, maxi(values.size() - 1, 0))
	queue_redraw()


func current() -> String:
	return values[index] if index < values.size() else ""


func step(d: int) -> void:
	if values.is_empty():
		return
	var n := index + d
	if wrap:
		n = posmod(n, values.size())
	else:
		n = clampi(n, 0, values.size() - 1)
	if n == index:
		return
	index = n
	_flash = 1.0
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play", "ui_move")
	value_changed.emit(index)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mx := (event as InputEventMouseButton).position.x
		if mx < size.x - value_width - 50.0:
			return
		step(-1 if mx < size.x - 30.0 - value_width * 0.5 else 1)
		accept_event()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var focused := has_focus()
	var cy := size.y * 0.5
	var right := size.x - 30.0
	var vw := value_width
	draw_string(_font, Vector2(30, cy + 9), label_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - vw - 90.0, 24, Color.WHITE if focused else UiTheme.TEXT)
	var vx := right - vw
	var arrow_col := UiTheme.ACCENT if focused else Color(UiTheme.TEXT_DIM, 0.6)
	UiIcons.chevron(self, Vector2(vx - 14, cy), 16.0, -1.0, arrow_col, 3.0)
	UiIcons.chevron(self, Vector2(right + 6, cy), 16.0, 1.0, arrow_col, 3.0)
	var col := value_color.lerp(Color.WHITE, _flash)
	if bar_mode and values.size() > 1:
		var segs := values.size() - 1
		var sw := (vw - 20.0) / segs
		for i in segs:
			var lit := i < index
			var r := Rect2(vx + 10 + i * sw + 1, cy - 9, sw - 3, 18)
			draw_rect(r, col if lit else Color(1, 1, 1, 0.12))
		return
	draw_string(_font_val, Vector2(vx, cy + 9), current(), HORIZONTAL_ALIGNMENT_CENTER, vw, 24, col)
