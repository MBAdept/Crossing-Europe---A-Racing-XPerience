class_name UiScreen
extends Control
## Base class of all menu screens: full-rect Control, built in code (build()), header + footer with
## input hints, default focus for keyboard/gamepad, ui_cancel -> on_cancel() (default: GameFlow.back()).
## Screens read their data from `params` (set by GameFlow) and call GameFlow for navigation.

var params: Dictionary = {}
var default_focus: Control
var bg_dim := 0.55
var backdrop := ""                  ## "" = synthwave background, "title" = photo backdrop (MenuShell)
var hints: Array = []
var footer: KeyHints


func _init(p_params: Dictionary = {}) -> void:
	params = p_params
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if hints.is_empty():
		hints = [[["Enter", "pad:A"], tr("Auswählen")], [["Esc", "pad:B"], tr("Zurück")]]
	build()
	footer = KeyHints.new(hints)
	UiKit.place(self, footer, Rect2(64, 676, 1152, 34))
	_grab_default.call_deferred()


func _grab_default() -> void:
	if is_inside_tree() and default_focus != null and is_instance_valid(default_focus) and default_focus.is_inside_tree():
		default_focus.grab_focus()


## Virtual: create the screen's controls.
func build() -> void:
	pass


## Virtual: ui_cancel / back.
func on_cancel() -> void:
	GameFlow.back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiKit.sound("ui_back")
		on_cancel()


func cfg() -> Dictionary:
	return ConfigLoader.load_merged()


## Screen title (Exo 2 ExtraBold Italic), gradient underline, optional subtitle and right-hand info.
func add_header(title: String, subtitle: String = "", right_text: String = "") -> void:
	var t := UiKit.label(title.to_upper(), UiTheme.F.TITLE, 42, Color.WHITE)
	t.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.55))
	t.add_theme_constant_override("shadow_offset_x", 3)
	t.add_theme_constant_override("shadow_offset_y", 3)
	UiKit.place(self, t, Rect2(60, 14, 900, 56))
	var bar := TextureRect.new()
	bar.texture = UiTheme.gradient_tex(UiTheme.ACCENT, Color(UiTheme.ACCENT_2, 0.0))
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, bar, Rect2(64, 72, 560, 4))
	if subtitle != "":
		var s := UiKit.label(subtitle, UiTheme.F.BODY_MEDIUM, 22, UiTheme.TEXT_DIM)
		var tw := UiTheme.font(UiTheme.F.TITLE).get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
		UiKit.place(self, s, Rect2(60 + tw + 22, 30, 1216 - (60 + tw + 22) - (240 if right_text != "" else 0), 34))
	if right_text != "":
		var r := UiKit.label(right_text, UiTheme.F.BODY_BOLD, 20, UiTheme.ACCENT_2, HORIZONTAL_ALIGNMENT_RIGHT)
		UiKit.place(self, r, Rect2(816, 30, 400, 34))


func set_hints(p: Array) -> void:
	hints = p
	if footer != null:
		footer.set_hints(p)


## Panel placed at an absolute rectangle; returns the content VBox.
func add_panel(rect: Rect2, accent: Color = Color(0, 0, 0, 0), sep: int = 8, bg: Color = UiTheme.PANEL) -> VBoxContainer:
	var p := UiKit.panel(bg, accent)
	UiKit.place(self, p, rect)
	var box := UiKit.vbox(sep)
	p.add_child(box)
	return box


## Focus a control on the next frame (after layout changes), if it is still in the tree.
func _focus_later(c: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(c) and c.is_inside_tree() and c.visible:
		c.grab_focus()
