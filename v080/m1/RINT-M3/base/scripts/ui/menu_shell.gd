class_name MenuShell
extends Control
## Persistent menu root while no race is running: shared Theme, animated background and the current
## screen (with a short slide/fade-in transition).
## The screens keep the 16:9 design space (1280×720, `layer`, centred); the background fills the whole
## window. GameFlow sets the stretch aspect to "expand" while the menus are shown, so on a 16:10 screen
## (Steam Deck 1280×800) the background reaches into the 40 px that are black bars in the race.
## A screen with UiScreen.backdrop == "title" gets the photo backdrop (TitleBackdrop) instead of the synthwave
## scene: it cross-fades in PHOTO_FADE_S (at once for the first screen of the shell); the hidden background is
## not drawn.

const DESIGN_SIZE := Vector2(1280, 720)
const PHOTO_FADE_S := 0.35

var background: MenuBackground
var title_backdrop: TitleBackdrop     ## photo backdrop of the title screen (created on demand)
var layer: Control
var current_screen: Control
var _photo_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	background = MenuBackground.new()
	add_child(background)
	layer = Control.new()
	layer.set_anchors_preset(Control.PRESET_CENTER)
	layer.offset_left = -DESIGN_SIZE.x * 0.5
	layer.offset_right = DESIGN_SIZE.x * 0.5
	layer.offset_top = -DESIGN_SIZE.y * 0.5
	layer.offset_bottom = DESIGN_SIZE.y * 0.5
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)


func set_screen(s: Control) -> void:
	var first := current_screen == null
	if current_screen != null and is_instance_valid(current_screen):
		layer.remove_child(current_screen)
		current_screen.queue_free()
	current_screen = s
	layer.add_child(s)
	var dim := 0.55
	if s is UiScreen:
		dim = (s as UiScreen).bg_dim
	background.target_dim = dim
	_show_photo(s is UiScreen and (s as UiScreen).backdrop == "title", first)
	s.modulate.a = 0.0
	s.position.x = 28.0
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "modulate:a", 1.0, 0.18)
	tw.tween_property(s, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Photo backdrop on/off: cross-fades over the synthwave background (`instant` for the first screen).
func _show_photo(on: bool, instant: bool) -> void:
	if on and title_backdrop == null:
		title_backdrop = TitleBackdrop.new()
		add_child(title_backdrop)
		move_child(title_backdrop, background.get_index() + 1)
		title_backdrop.modulate.a = 0.0
	if title_backdrop == null:
		return
	if _photo_tween != null and _photo_tween.is_valid():
		_photo_tween.kill()
	title_backdrop.visible = true
	background.visible = true
	var done := func() -> void:
		background.visible = not on
		title_backdrop.visible = on
	if instant:
		title_backdrop.modulate.a = 1.0 if on else 0.0
		done.call()
		return
	_photo_tween = create_tween()
	_photo_tween.tween_property(title_backdrop, "modulate:a", 1.0 if on else 0.0, PHOTO_FADE_S)
	_photo_tween.tween_callback(done)
