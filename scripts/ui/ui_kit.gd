class_name UiKit
extends RefCounted
## Small factory helpers for building menu UI in code with the shared style.


static func label(text: String, kind: int = UiTheme.F.BODY, fs: int = 22, col: Color = UiTheme.TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(kind))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Menu button (slanted, theme styles); plays the confirm blip when pressed.
static func button(text: String, fs: int = 26, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = align
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(func() -> void: sound("ui_ok"))
	return b


## Panel with the standard background; accent colour draws a 3 px top line.
static func panel(bg: Color = UiTheme.PANEL, accent: Color = Color(0, 0, 0, 0), margin: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(bg, UiTheme.PANEL_LINE, accent, margin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


## Adds `child` to `parent` at an absolute rectangle (1280×720 design space).
static func place(parent: Control, child: Control, rect: Rect2) -> Control:
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size
	return child


## Vertical list inside a ScrollContainer that keeps the focused entry visible.
static func scroll_list(sep: int = 6) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	var box := vbox(sep)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	return [sc, box]


## Label + value line ("Länge ........ 155 km").
static func stat_line(caption: String, value: String, value_col: Color = UiTheme.TEXT, fs: int = 21) -> HBoxContainer:
	var row := hbox(6)
	var a := label(caption, UiTheme.F.BODY_MEDIUM, fs, UiTheme.TEXT_DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	var b := label(value, UiTheme.F.BODY_BOLD, fs, value_col, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(b)
	return row


static var _stick_frame := {}        ## action -> process frame of its last stick step (ui_step)


## One step of a ui_* direction in a custom handler (◀▶ values, ▲▼ scrolling). Keys count with their echo (the held
## key repeats), D-pad presses and the repeat of a held pad direction (PadRepeat, an InputEventAction) once each. A
## stick sends a motion event for every change of its position, and every one above the action's deadzone reads as
## "pressed" – so a stick counts only in the frame it enters the action (Input.is_action_just_pressed), and at
## most once per frame, like Godot's own focus navigation: one push = one step (QA v0.5.1: one push changed the
## vehicle 3–5 times and the start time by up to 14 hours).
static func ui_step(event: InputEvent, action: StringName) -> bool:
	if event is InputEventJoypadMotion:
		if not event.is_action_pressed(action) or not Input.is_action_just_pressed(action):
			return false
		var f := Engine.get_process_frames()
		if int(_stick_frame.get(action, -1)) == f:
			return false
		_stick_frame[action] = f
		return true
	return event.is_action_pressed(action, true)


## Index `index` moved by `d` entries in a list of `count`, clamped (LB / RB, page keys: ±PAGE_STEP without
## wrapping around, unlike the single steps of focus navigation).
static func page_index(index: int, d: int, count: int) -> int:
	if count <= 0:
		return 0
	return clampi(index + d, 0, count - 1)


## Entries LB / RB (PageUp / PageDown) jump in long lists.
const PAGE_STEP := 8


## LB / RB (PageUp / PageDown): moves the focus `PAGE_STEP` entries up or down in `list` (focusable controls in
## order) when one of them has the focus. Returns true if the event was a page step for this list.
static func page_focus(event: InputEvent, list: Array, focus_owner: Control) -> bool:
	var d := 0
	if event.is_action_pressed("ui_page_down", true):
		d = PAGE_STEP
	elif event.is_action_pressed("ui_page_up", true):
		d = -PAGE_STEP
	if d == 0 or focus_owner == null:
		return false
	var i := list.find(focus_owner)
	if i < 0:
		return false
	var target: Control = list[page_index(i, d, list.size())]
	if target != focus_owner:
		target.grab_focus()
	return true


static func sound(n: String) -> void:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var am: Node = (ml as SceneTree).root.get_node_or_null("AudioManager")
		if am != null:
			am.call("play", n)


## Links a list of controls vertically for focus navigation (wraps around).
static func chain_focus(ctrls: Array, wrap: bool = true) -> void:
	var n := ctrls.size()
	for i in n:
		var c: Control = ctrls[i]
		if i > 0 or wrap:
			c.focus_neighbor_top = c.get_path_to(ctrls[(i - 1 + n) % n])
		if i < n - 1 or wrap:
			c.focus_neighbor_bottom = c.get_path_to(ctrls[(i + 1) % n])
