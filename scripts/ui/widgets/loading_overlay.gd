class_name LoadingOverlay
extends Control
## "Etappe wird geladen …" over the current menu screen while GameFlow.start_pending_stage() builds the race scene
## (synchronous, 0.3–0.8 s here, more on a Steam Deck): the screen dims, a small panel says what is happening, and
## clicks, keys and gamepad buttons are swallowed (a B in these frames must not leave the screen while the race
## starts). It goes away with the screen when the race scene replaces the menus.

var text := ""


func _init(p_text: String = "") -> void:
	text = p_text


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.07, 0.6)
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
	center.add_child(panel)
	panel.add_child(UiKit.label(text if text != "" else tr("Etappe wird geladen …"), UiTheme.F.TITLE, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
