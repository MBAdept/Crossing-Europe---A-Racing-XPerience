class_name NameEntry
extends VBoxContainer
## Name entry for a top-10 placement: LineEdit (keyboard) plus an on-screen keyboard grid for
## gamepads. Enter / gamepad A on the line or "OK" submits; the name is remembered in Settings.
## Gamepad: D-pad moves between the line and the keys, A types / submits (ui_accept, gamepad A is
## mapped by InputSetup), B deletes the last character.

signal submitted(player_name: String)

const MAX_LEN := 14
const KEYS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
	"K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
	"U", "V", "W", "X", "Y", "Z", "Ä", "Ö", "Ü", "ß",
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

var line: LineEdit
var grid: GridContainer
var ok_button: Button
var _done := false


func _init(initial: String = "") -> void:
	add_theme_constant_override("separation", 12)
	line = LineEdit.new()
	line.max_length = MAX_LEN
	line.text = initial
	line.placeholder_text = tr("Dein Name")
	line.custom_minimum_size = Vector2(420, 58)
	line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.select_all_on_focus = true
	line.text_submitted.connect(func(_t: String) -> void: _submit())
	line.gui_input.connect(_on_line_input)
	add_child(line)
	grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	add_child(grid)
	for k in KEYS:
		grid.add_child(_key_button(k, func() -> void: _type(k)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	row.add_child(_wide_button(tr("Leerzeichen"), func() -> void: _type(" ")))
	row.add_child(_wide_button(tr("Löschen"), _backspace))
	ok_button = _wide_button(tr("OK"), _submit)
	ok_button.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(ok_button)
	_wire_focus(row)


## Explicit D-pad / arrow navigation (the geometric search jumped e.g. from "OK" into the text field):
## key rows wrap left/right, ▲ from the first row -> text field, ▼ from the last row -> the button
## row below (Leerzeichen / Löschen / OK, wraps), ▼ from the text field -> the keys.
func _wire_focus(row: HBoxContainer) -> void:
	var keys: Array[Button] = []
	for c in grid.get_children():
		keys.append(c as Button)
	var bottom: Array[Button] = []
	for c in row.get_children():
		bottom.append(c as Button)
	var cols := grid.columns
	var rows := ceili(keys.size() / float(cols))
	for i in keys.size():
		var b := keys[i]
		var r := floori(float(i) / cols)
		var c := i % cols
		var row_len := mini(cols, keys.size() - r * cols)
		b.focus_neighbor_left = b.get_path_to(keys[r * cols + posmod(c - 1, row_len)])
		b.focus_neighbor_right = b.get_path_to(keys[r * cols + posmod(c + 1, row_len)])
		b.focus_neighbor_top = b.get_path_to(line) if r == 0 else b.get_path_to(keys[i - cols])
		if r == rows - 1 or i + cols >= keys.size():
			b.focus_neighbor_bottom = b.get_path_to(bottom[mini(floori(float(c) * bottom.size() / cols), bottom.size() - 1)])
		else:
			b.focus_neighbor_bottom = b.get_path_to(keys[i + cols])
	for j in bottom.size():
		var b := bottom[j]
		b.focus_neighbor_left = b.get_path_to(bottom[posmod(j - 1, bottom.size())])
		b.focus_neighbor_right = b.get_path_to(bottom[posmod(j + 1, bottom.size())])
		var above := (rows - 1) * cols + mini(floori((j + 0.5) * cols / bottom.size()), cols - 1)
		b.focus_neighbor_top = b.get_path_to(keys[mini(above, keys.size() - 1)])
		b.focus_neighbor_bottom = b.get_path_to(b)
	line.focus_neighbor_bottom = line.get_path_to(keys[mini(floori(cols / 2.0) - 1, keys.size() - 1)])
	line.focus_neighbor_top = line.get_path_to(line)
	line.focus_neighbor_left = line.get_path_to(line)
	line.focus_neighbor_right = line.get_path_to(line)


func _key_button(k: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = k
	b.custom_minimum_size = Vector2(40, 38)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_constant_override("h_separation", 0)
	UiTheme.apply_square_button(b, 2)
	b.pressed.connect(cb)
	return b


func _wide_button(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(150, 44)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	return b


func focus_line() -> void:
	line.grab_focus()
	line.caret_column = line.text.length()


func _type(ch: String) -> void:
	if line.text.length() >= MAX_LEN:
		return
	if line.has_selection():
		line.text = ""
	var t := line.text
	if t.length() > 0 and ch.length() == 1 and ch != " " and t.right(1) != " ":
		ch = ch.to_lower()
	line.text = t + ch
	line.caret_column = line.text.length()


func _backspace() -> void:
	if line.has_selection():
		line.text = ""
	else:
		line.text = line.text.left(maxi(line.text.length() - 1, 0))
	line.caret_column = line.text.length()


func _on_line_input(event: InputEvent) -> void:
	# gamepad "A" on the text field submits (keyboard uses Enter via text_submitted)
	if event is InputEventJoypadButton and event.is_action_pressed("ui_accept"):
		_submit()
		line.accept_event()


## Gamepad B (ui_cancel) inside the entry deletes the last character – the screens behind it have no
## "back" while a name is pending. Keyboard Esc is left alone (Backspace works in the field).
func _unhandled_input(event: InputEvent) -> void:
	if is_inside_tree() and handle_gamepad_cancel(event, get_viewport().gui_get_focus_owner()):
		get_viewport().set_input_as_handled()


## Gamepad B while the focus is inside the entry: delete the last character. Returns true if handled.
func handle_gamepad_cancel(event: InputEvent, focus_owner: Control) -> bool:
	if _done or not event is InputEventJoypadButton or not event.is_action_pressed("ui_cancel"):
		return false
	if focus_owner == null or not (focus_owner == self or is_ancestor_of(focus_owner)):
		return false
	_backspace()
	return true


## Footer hints for screens showing a name entry.
static func key_hints() -> Array:
	return [[["Enter", "pad:A"], UiFormat.t("Eintragen")], [["ud", "lr"], UiFormat.t("Tastatur")], [["pad:B"], UiFormat.t("Löschen")]]


func player_name() -> String:
	var n := line.text.strip_edges()
	return n if n != "" else tr("Unbekannt")


func _submit() -> void:
	if _done:
		return
	_done = true
	submitted.emit(player_name())
