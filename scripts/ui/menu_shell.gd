class_name MenuShell
extends Control
## Persistent menu root while no race is running: shared Theme, animated background and the current
## screen (with a short slide/fade-in transition).
## The screens keep the 16:9 design space (1280×720, `layer`, centred); the background fills the whole
## window. GameFlow sets the stretch aspect to "expand" while the menus are shown, so on a 16:10 screen
## (Steam Deck 1280×800) the background reaches into the 40 px that are black bars in the race.

const DESIGN_SIZE := Vector2(1280, 720)

var background: MenuBackground
var layer: Control
var current_screen: Control


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
	if current_screen != null and is_instance_valid(current_screen):
		layer.remove_child(current_screen)
		current_screen.queue_free()
	current_screen = s
	layer.add_child(s)
	var dim := 0.55
	if s is UiScreen:
		dim = (s as UiScreen).bg_dim
	background.target_dim = dim
	s.modulate.a = 0.0
	s.position.x = 28.0
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "modulate:a", 1.0, 0.18)
	tw.tween_property(s, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
