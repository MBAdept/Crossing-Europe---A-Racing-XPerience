extends Node
## Autoload "InputSetup": registers the game's input actions at startup (keyboard + gamepad),
## so project.godot does not need hand-written InputEvent blobs.
##   steer_left / steer_right  : arrows, A/D, d-pad (full lock) – the left stick is not bound: the race reads the
##                               stick of the active pad only (InputMode.device, race_session.gd player_steer())
##   accelerate                : Up, W, right trigger, gamepad A
##   brake                     : Down, S, left trigger, gamepad X
##   pause                     : Escape, P, gamepad Start
## Menus use the built-in ui_* actions (Enter/Space/gamepad A = ui_accept, Escape/gamepad B = ui_cancel,
## PageUp/PageDown/gamepad LB/RB = ui_page_up/ui_page_down for a page in long lists).
## Every gamepad binding is for all devices (InputMap device -1, like Godot's own ui_* bindings): a docked Steam
## Deck with an external pad or a PC with two pads drives with whichever pad is used, not only with device 0.
## Steering with the stick follows the pad used last (a button or a clear stick / trigger push, InputMode): with every
## pad's stick in the action, a resting second pad with a drifting stick (above the stick deadzone 0.12) steered.
## Also tracks the active input device (InputMode: gamepad or keyboard) for the key hints, repeats a held
## D-pad / stick direction in the menus (PadRepeat – Godot repeats keys, but not gamepad buttons) and reports a
## disconnected gamepad with whether it was in use (pad_disconnected – the race pauses then).

## A gamepad was disconnected: `in_use` if it was the active pad or still held a button, stick or trigger
## (InputMode.pad_lost) – the race pauses then.
signal pad_disconnected(device: int, in_use: bool)

const STEER_DEADZONE := 0.2
const PEDAL_DEADZONE := 0.1
## InputMap's "all devices" (as Godot's own ui_* bindings).
const ALL_DEVICES := -1

var repeat := PadRepeat.new()


func _init() -> void:
	_action("steer_left", STEER_DEADZONE, [_key(KEY_LEFT), _key(KEY_A), _button(JOY_BUTTON_DPAD_LEFT)])
	_action("steer_right", STEER_DEADZONE, [_key(KEY_RIGHT), _key(KEY_D), _button(JOY_BUTTON_DPAD_RIGHT)])
	_action("accelerate", PEDAL_DEADZONE, [_key(KEY_UP), _key(KEY_W), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _button(JOY_BUTTON_A)])
	_action("brake", PEDAL_DEADZONE, [_key(KEY_DOWN), _key(KEY_S), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _button(JOY_BUTTON_X)])
	_action("pause", 0.5, [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])
	# Menus: Godot's built-in ui_accept/ui_cancel have no gamepad buttons – add A / B; LB / RB page long lists.
	_action("ui_accept", 0.5, [_button(JOY_BUTTON_A)])
	_action("ui_cancel", 0.5, [_button(JOY_BUTTON_B)])
	_action("ui_page_up", 0.5, [_button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("ui_page_down", 0.5, [_button(JOY_BUTTON_RIGHT_SHOULDER)])


func _ready() -> void:
	# a connected gamepad (Steam Deck: always) starts with gamepad hints and steers; the first key press switches
	var pads := Input.get_connected_joypads()
	InputMode.gamepad = not pads.is_empty()
	if not pads.is_empty():
		InputMode.device = pads[0]
	if CliArgs.has("input"):   # debug/screenshots: --input=gamepad|keyboard
		InputMode.gamepad = CliArgs.get_string("input") == "gamepad"
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	repeat.configure(ConfigLoader.load_merged())
	process_mode = Node.PROCESS_MODE_ALWAYS   # the pause menu of the race repeats as well


func _input(event: InputEvent) -> void:
	InputMode.note(event)
	repeat.note(event)


## Held D-pad / stick direction in the menus: the repeated step goes through the viewport like a key's echo.
func _process(delta: float) -> void:
	var vp := get_viewport()
	var action := repeat.update(delta, vp != null and vp.gui_get_focus_owner() != null)
	if action != &"" and vp != null:
		vp.push_input(PadRepeat.repeat_event(action))


## A gamepad was connected (gamepad hints) or disconnected (battery, Bluetooth, the docked Steam Deck's external pad).
## The engine has already released what that pad held – only its own state: keys and other pads keep theirs – and
## reads its axes as 0; whether it was in use comes from what InputMode noted (InputMode.pad_lost), decided here before
## the mode changes and reported to the race (pad_disconnected).
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		InputMode.pad_connected(device)   # unused until pressed: no steering by its stick, no pause when it drops again
		InputMode.gamepad = true
		return
	pad_disconnected.emit(device, InputMode.pad_lost(device, Input.get_connected_joypads()))


func _action(action_name: String, deadzone: float, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)
	for e in events:
		InputMap.action_add_event(action_name, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = ALL_DEVICES
	e.axis = axis
	e.axis_value = value
	return e


func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = ALL_DEVICES
	e.button_index = button
	return e
