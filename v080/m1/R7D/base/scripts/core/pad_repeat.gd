class_name PadRepeat
extends RefCounted
## Key repeat for a held gamepad direction in the menus. Godot repeats a held key (the system's key repeat sends
## echo events), but not a held D-pad button or stick: holding ▼ moved the focus exactly once – 105 single presses
## through the leaderboards. The autoload InputSetup feeds every input event in (note()) and calls update() every
## frame; after `delay_s` (config input.repeat_delay_s, 0.5 s – a push of the stick shorter than that stays one step)
## of holding, every `interval_s` (0.1 s) one more
## step of that ui_* direction is due, which InputSetup pushes through the viewport as an InputEventAction – focus
## navigation and the ◀▶ value handlers (UiKit.ui_step) take it like a key's echo. Only a direction pressed by a
## gamepad repeats (a held key already has its echo), only one at a time (the last pressed), and only while a
## control has the focus (menus, pause menu – never in the running race). Pure logic, no autoload access.

const ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

var delay_s := 0.5
var interval_s := 0.1
## Is the action still held? Default: the Input singleton; tests replace it.
var is_held: Callable = func(action: StringName) -> bool: return Input.is_action_pressed(action)

var _held: StringName = &""          ## direction held by a gamepad ("" = none)
var _wait := 0.0                     ## seconds until the next repeat


func configure(cfg: Dictionary) -> void:
	delay_s = clampf(float(ConfigLoader.lookup(cfg, "input.repeat_delay_s", delay_s)), 0.1, 2.0)
	interval_s = clampf(float(ConfigLoader.lookup(cfg, "input.repeat_interval_s", interval_s)), 0.03, 1.0)


## The direction a gamepad holds right now (&"" = none).
func held() -> StringName:
	return _held


## Feeds an input event: a gamepad press of a ui_* direction starts the delay, a key press of a direction (the
## keyboard repeats by itself) or the release of the held one stops it.
func note(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed():
			for a in ACTIONS:
				if event.is_action(a):
					_held = &""
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	for a in ACTIONS:
		if not event.is_action(a):
			continue
		if event.is_action_pressed(a):
			if _held != a:
				_held = a
				_wait = delay_s
		elif _held == a:
			_held = &""


## Advances the timer; returns the direction to step once more now (&"" = none). `focus` = a control has the
## focus (otherwise nothing repeats and the timer waits).
func update(dt: float, focus: bool) -> StringName:
	if _held == &"":
		return &""
	if not bool(is_held.call(_held)):
		_held = &""
		return &""
	if not focus:
		_wait = maxf(_wait, interval_s)
		return &""
	_wait -= dt
	if _wait > 0.0:
		return &""
	_wait += interval_s
	if _wait <= 0.0:
		_wait = interval_s   # a long frame: one step, not a burst
	return _held


## The repeated step: an InputEventAction (pressed, full strength) – no device, so InputMode stays as it is.
static func repeat_event(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	e.strength = 1.0
	return e
