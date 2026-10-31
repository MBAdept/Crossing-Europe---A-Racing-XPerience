class_name ConfirmBox
extends Control
## Modal yes/no question in the menu style: dimmed backdrop, panel with title, message and two
## buttons. The safe answer ("no") has the default focus; Enter / gamepad A picks the focused button,
## Esc / gamepad B answers "no". Focus stays inside the box, clicks outside it are swallowed.
## Usage: var box := ConfirmBox.new(title, message, yes_text, no_text); box.confirmed.connect(...);
##        screen.add_child(box)   – the box frees itself after an answer.

signal confirmed
signal cancelled

var title_text := ""
var message := ""
var yes_text := ""
var no_text := ""
var yes_button: Button
var no_button: Button
var _prev_focus: Control
var _answered := false


func _init(p_title: String = "", p_message: String = "", p_yes: String = "", p_no: String = "") -> void:
	title_text = p_title
	message = p_message
	yes_text = p_yes
	no_text = p_no


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.07, 0.8)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the screen is the 1280×720 frame; the dimmer also covers the menu background around it (16:10)
	bg.offset_left = -1000.0
	bg.offset_right = 1000.0
	bg.offset_top = -400.0
	bg.offset_bottom = 400.0
	add_child(bg)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.panel(UiTheme.PANEL, UiTheme.WARN, 28)
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)
	var box := UiKit.vbox(16)
	panel.add_child(box)
	var t := UiKit.label(title_text, UiTheme.F.TITLE, 32, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	var m := UiKit.label(message, UiTheme.F.BODY_MEDIUM, 22, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(600, 0)
	box.add_child(m)
	var row := UiKit.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	no_button = UiKit.button(no_text, 24, HORIZONTAL_ALIGNMENT_CENTER)
	no_button.custom_minimum_size = Vector2(250, 50)
	no_button.pressed.connect(func() -> void: _answer(false))
	row.add_child(no_button)
	yes_button = UiKit.button(yes_text, 24, HORIZONTAL_ALIGNMENT_CENTER)
	yes_button.custom_minimum_size = Vector2(250, 50)
	yes_button.add_theme_color_override("font_color", UiTheme.WARN)
	yes_button.pressed.connect(func() -> void: _answer(true))
	row.add_child(yes_button)
	# trap the focus inside the box (◀▶ switch, ▲▼ / Tab stay)
	for b: Button in [no_button, yes_button]:
		var other: Button = yes_button if b == no_button else no_button
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)
	_prev_focus = get_viewport().gui_get_focus_owner()
	no_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiKit.sound("ui_back")
		_answer(false)


func _answer(yes: bool) -> void:
	if _answered:
		return
	_answered = true
	hide()
	if not yes and _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		_prev_focus.grab_focus()
	if yes:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()
