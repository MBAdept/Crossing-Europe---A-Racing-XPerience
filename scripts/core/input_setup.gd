extends Node
## Autoload "InputSetup": registers the game's input actions at startup (keyboard + gamepad),
## so project.godot does not need hand-written InputEvent blobs.
##   steer_left / steer_right  : arrows, A/D, left stick, d-pad
##   accelerate                : Up, W, right trigger, gamepad A
##   brake                     : Down, S, left trigger, gamepad X
##   pause                     : Escape, P, gamepad Start
## Menus use the built-in ui_* actions (Enter/Space/gamepad A = ui_accept, Escape/gamepad B = ui_cancel).

const STEER_DEADZONE := 0.2
const PEDAL_DEADZONE := 0.1


func _init() -> void:
	_action("steer_left", STEER_DEADZONE, [_key(KEY_LEFT), _key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT)])
	_action("steer_right", STEER_DEADZONE, [_key(KEY_RIGHT), _key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)])
	_action("accelerate", PEDAL_DEADZONE, [_key(KEY_UP), _key(KEY_W), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _button(JOY_BUTTON_A)])
	_action("brake", PEDAL_DEADZONE, [_key(KEY_DOWN), _key(KEY_S), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _button(JOY_BUTTON_X)])
	_action("pause", 0.5, [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])
	# Menus: Godot's built-in ui_accept/ui_cancel have no gamepad buttons – add A / B.
	_action("ui_accept", 0.5, [_button(JOY_BUTTON_A)])
	_action("ui_cancel", 0.5, [_button(JOY_BUTTON_B)])


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
	e.axis = axis
	e.axis_value = value
	return e


func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e
