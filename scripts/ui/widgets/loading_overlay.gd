class_name LoadingOverlay
extends Control
## "Etappe wird geladen …" over the current menu screen while GameFlow.start_pending_stage() builds the race scene
## (synchronous, 0.3–0.8 s here, more on a Steam Deck): the screen dims, a small panel says what is happening, and
## clicks, keys and gamepad buttons are swallowed (a B in these frames must not leave the screen while the race
## starts). It goes away with the screen when the race scene replaces the menus.
## v0.8.0: the race session shows the same panel over an opaque cover while a Modern renderer prepares the stage
## (render self-test, models, shader warm-up – several frames up to seconds) and reports how far it is with
## set_progress(p): a thin bar appears under the text and fills up. Without a call the panel is exactly the one of
## v0.7.0 (the menus' use, both graphics modes).

const BAR_SIZE := Vector2(360, 8)

var text := ""
var progress := -1.0               ## 0..1 once set_progress() was called; < 0 = no bar
var _bar: Control


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
	var box := UiKit.vbox(14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(UiKit.label(text if text != "" else tr("Etappe wird geladen …"), UiTheme.F.TITLE, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_bar = _Bar.new()
	(_bar as _Bar).overlay = self
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.visible = progress >= 0.0   # a hidden child takes no room in the box: the panel keeps its size of v0.7.0
	box.add_child(_bar)


## Progress of the preparation, 0..1 (v0.8.0, the race session while a Modern renderer prepares the stage): shows
## the bar from the first call on. It never runs backwards – a renderer that reports a later step with a lower
## number does not make the bar jump back.
func set_progress(p: float) -> void:
	progress = maxf(progress, clampf(p, 0.0, 1.0))
	if _bar != null:
		_bar.visible = true
		_bar.queue_redraw()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


class _Bar extends Control:
	var overlay: LoadingOverlay

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.12))
		var p := clampf(overlay.progress if overlay != null else 0.0, 0.0, 1.0)
		if p > 0.0:
			draw_rect(Rect2(0, 0, size.x * p, size.y), UiTheme.ACCENT_2)
		draw_rect(r, Color(UiTheme.ACCENT_2, 0.45), false, 1.0)
