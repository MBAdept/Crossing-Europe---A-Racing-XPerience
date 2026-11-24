class_name NameEntry
extends VBoxContainer
## Name entry for a top-10 placement: LineEdit (keyboard) plus an on-screen keyboard grid for
## gamepads. Enter / gamepad A on the line or "OK" submits; the name is remembered in Settings.
## Gamepad: D-pad moves between the line and the keys, A types / submits (ui_accept, gamepad A is
## mapped by InputSetup), B deletes the last character (also when the field starts with the remembered
## name selected – QA v0.5.1: the first B deleted the whole name), Start submits. A or Start in an empty
## field does not enter "Unbekannt" but moves to the keys (pressing A to get past the result screen
## must not file a nameless entry). With `can_close` (NameEntryBox) B in the empty field closes the box
## without a change (`close_requested`). The footer hints follow the focus (`hints_changed`): "Tippen"
## on the keys, "Eintragen" in the field and on OK, "Schließen" for B in the empty field.
## A keyboard types into the field even when the focus reached it by navigation (the LineEdit is then
## not in edit mode and dropped the keys).

signal submitted(player_name: String)
signal close_requested
signal hints_changed(hints: Array)

const MAX_LEN := 14
const KEYS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
	"K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
	"U", "V", "W", "X", "Y", "Z", "Ä", "Ö", "Ü", "ß",
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

var line: LineEdit
var grid: GridContainer
var ok_button: Button
var can_close := false               ## B in the empty field asks to close (NameEntryBox)
var _done := false
var _on_key := false                 ## the focus is on a key of the grid / Leerzeichen / Löschen
var _on_ok := false                  ## the focus is on OK


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
	line.text_changed.connect(func(_t: String) -> void: _emit_hints())
	line.focus_entered.connect(func() -> void: _set_on_key(false))
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
	for c in grid.get_children():
		(c as Control).focus_entered.connect(func() -> void: _set_on_key(true))
	for c in row.get_children():
		var b := c as Control
		b.focus_entered.connect(func() -> void: _set_on_key(b != ok_button, b == ok_button))


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
	_emit_hints()


## Deletes the last character – also when the whole (remembered) name is selected: B and the "Löschen" key
## never wipe the name at once.
func _backspace() -> void:
	line.deselect()
	line.text = line.text.left(maxi(line.text.length() - 1, 0))
	line.caret_column = line.text.length()
	_emit_hints()


func _on_line_input(event: InputEvent) -> void:
	# gamepad "A" on the text field submits (keyboard uses Enter via text_submitted); in an empty field it
	# moves to the keys instead
	if event is InputEventJoypadButton and event.is_action_pressed("ui_accept"):
		line.accept_event()
		if not submit_or_type():
			UiKit.sound("ui_move")
		return
	if event is InputEventKey:
		begin_typing(line, event as InputEventKey)


## A key typed into a LineEdit that is not in edit mode (the focus came by D-pad / arrow navigation): starts
## editing, so this very key – which reaches the LineEdit right after its gui_input signal – is typed. Returns
## true if it started editing.
static func begin_typing(field: LineEdit, k: InputEventKey) -> bool:
	if not types_text(k) or field.is_editing() or not field.editable:
		return false
	field.caret_column = field.text.length()
	if field.is_inside_tree():
		field.edit()
	return true


## True for a key press that types into a text field (a character, Backspace, Delete).
static func types_text(k: InputEventKey) -> bool:
	return k.pressed and (k.unicode >= 32 or k.keycode in [KEY_BACKSPACE, KEY_DELETE])


## A / Start in the field: submits a typed name; in an empty field the focus moves to the keys (no "Unbekannt"
## by accident). Returns true if submitted.
func submit_or_type() -> bool:
	if typed_name() == "":
		var first := line.get_node_or_null(line.focus_neighbor_bottom) as Control
		if first != null and first.is_inside_tree():
			first.grab_focus()
		return false
	_submit()
	return true


## Gamepad B (ui_cancel) inside the entry deletes the last character – the screens behind it have no
## "back" while a name is pending; Start submits. Keyboard Esc is left alone (Backspace works in the field).
func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	var fo := get_viewport().gui_get_focus_owner()
	if handle_gamepad_cancel(event, fo) or handle_gamepad_start(event, fo):
		get_viewport().set_input_as_handled()


func _has_focus_inside(focus_owner: Control) -> bool:
	return focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner))


## Gamepad B while the focus is inside the entry: delete the last character; in the empty field with
## `can_close`: ask to close (close_requested). Returns true if handled.
func handle_gamepad_cancel(event: InputEvent, focus_owner: Control) -> bool:
	if _done or not event is InputEventJoypadButton or not event.is_action_pressed("ui_cancel"):
		return false
	if not _has_focus_inside(focus_owner):
		return false
	if can_close and line.text == "":
		close_requested.emit()
		return true
	_backspace()
	return true


## Gamepad Start while the focus is inside the entry: like OK, but an empty field moves to the keys.
func handle_gamepad_start(event: InputEvent, focus_owner: Control) -> bool:
	if _done or not event is InputEventJoypadButton or (event as InputEventJoypadButton).button_index != JOY_BUTTON_START \
			or not event.is_pressed():
		return false
	if not _has_focus_inside(focus_owner):
		return false
	submit_or_type()
	return true


## Footer hints for screens showing a name entry: A types on the keys and enters in the field / on OK; B deletes
## (closes an empty box when `close` is set); Start enters.
static func key_hints(on_key: bool = false, close: bool = false) -> Array:
	return [[["Enter", "pad:A"], UiFormat.t("Tippen") if on_key else UiFormat.t("Eintragen")],
		[["ud", "lr"], UiFormat.t("Tastatur")], [["pad:B"], UiFormat.t("Schließen") if close else UiFormat.t("Löschen")],
		[["pad:Start"], UiFormat.t("Fertig")]]


## The hints for the current focus and text: A types on the keys and in the empty field (it moves to the keys),
## enters in a field with a name and on OK.
func current_hints() -> Array:
	return key_hints(_on_key or (not _on_ok and typed_name() == ""), can_close and line.text == "")


func _set_on_key(v: bool, ok: bool = false) -> void:
	_on_key = v
	_on_ok = ok
	_emit_hints()


func _emit_hints() -> void:
	hints_changed.emit(current_hints())


## The name as typed (stripped, may be empty).
func typed_name() -> String:
	return line.text.strip_edges()


func player_name() -> String:
	var n := typed_name()
	return n if n != "" else tr("Unbekannt")


func _submit() -> void:
	if _done:
		return
	_done = true
	submitted.emit(player_name())
