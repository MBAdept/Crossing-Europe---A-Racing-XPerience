class_name PauseMenu
extends Control
## In-race pause overlay. Owner: UI module. Public API = contract (ARCHITECTURE.md §9):
## open(), close(), signals resume_requested, restart_requested, quit_requested.
## Esc / P / gamepad Start or B resume; keyboard and gamepad navigation with focus.
## Debug: CLI --pause-demo opens it right away (screenshots).

signal resume_requested
signal restart_requested
signal quit_requested

var _buttons: Array[Button] = []
var _opened_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.07, 0.74)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UiKit.panel(UiTheme.PANEL, UiTheme.ACCENT, 28)
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var box := UiKit.vbox(12)
	panel.add_child(box)
	var title := UiKit.label(tr("PAUSE"), UiTheme.F.TITLE, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)
	var bar := TextureRect.new()
	bar.texture = UiTheme.gradient_tex(Color(UiTheme.ACCENT_2, 0.0), UiTheme.ACCENT)
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.custom_minimum_size = Vector2(400, 4)
	box.add_child(bar)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	box.add_child(sp)
	for pair in [[tr("Weiterfahren"), resume_requested], [tr("Etappe neu starten"), restart_requested], [tr("Aufgeben"), quit_requested]]:
		var b := UiKit.button(str(pair[0]), 26, HORIZONTAL_ALIGNMENT_CENTER)
		b.custom_minimum_size = Vector2(400, 52)
		var sig: Signal = pair[1]
		b.pressed.connect(func() -> void: sig.emit())
		b.focus_entered.connect(func() -> void:
			if Time.get_ticks_msec() - _opened_at > 120:
				UiKit.sound("ui_move"))
		box.add_child(b)
		_buttons.append(b)
	var hint := KeyHints.new([[["Enter", "pad:A"], tr("Auswählen")], [["Esc", "pad:B"], tr("Weiterfahren")]])
	hint.align = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(400, 34)
	box.add_child(hint)
	hide()
	if CliArgs.has("pause-demo"):
		open.call_deferred()


func open() -> void:
	show()
	_opened_at = Time.get_ticks_msec()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
	UiKit.sound("ui_ok")


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Time.get_ticks_msec() - _opened_at < 120:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		UiKit.sound("ui_back")
		resume_requested.emit()
