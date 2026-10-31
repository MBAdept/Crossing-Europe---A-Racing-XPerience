class_name NameEntryBox
extends Control
## Modal on-screen keyboard for a name (gamepad without a keyboard, e.g. Steam Deck): dimmed backdrop,
## panel with a title and a NameEntry. A on "OK" or in the field takes the name (`submitted`, may be
## empty), B deletes the last character (NameEntry), keyboard Esc closes without a change
## (`cancelled`). The box frees itself after an answer. Used by the options screen (player name).

signal submitted(player_name: String)
signal cancelled

var title_text := ""
var initial := ""
var entry: NameEntry
var _answered := false


func _init(p_title: String = "", p_initial: String = "") -> void:
	title_text = p_title
	initial = p_initial
	entry = NameEntry.new(initial)
	entry.alignment = BoxContainer.ALIGNMENT_CENTER
	entry.submitted.connect(func(_n: String) -> void: answer(true))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.07, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# like ConfirmBox: also dims the menu background around the 1280×720 screen (16:10)
	bg.offset_left = -1000.0
	bg.offset_right = 1000.0
	bg.offset_top = -400.0
	bg.offset_bottom = 400.0
	add_child(bg)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.panel(UiTheme.PANEL, UiTheme.ACCENT_2, 24)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := UiKit.vbox(14)
	panel.add_child(box)
	box.add_child(UiKit.label(title_text.to_upper(), UiTheme.F.TITLE, 30, UiTheme.ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(entry)
	# the screen's footer is dimmed behind the box: the hints of the entry inside it
	var keys := KeyHints.new(NameEntry.key_hints())
	keys.align = HORIZONTAL_ALIGNMENT_CENTER
	keys.custom_minimum_size = Vector2(500, 34)
	box.add_child(keys)
	entry.focus_line.call_deferred()


## The entry is built in _init (usable before the box enters the tree) and only parented in _ready:
## a box freed without ever entering the tree frees it too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(entry) and entry.get_parent() == null:
		entry.free()


## Keyboard Esc closes the box without a change (gamepad B is handled by the NameEntry: delete).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiKit.sound("ui_back")
		answer(false)


func answer(take: bool) -> void:
	if _answered:
		return
	_answered = true
	hide()
	if take:
		submitted.emit(entry.line.text.strip_edges())
	else:
		cancelled.emit()
	queue_free()
