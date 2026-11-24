class_name InputMode
extends RefCounted
## The input device the player is using right now, for key hints and tutorial texts: `gamepad` turns
## true with a gamepad button or a clear stick/trigger movement and false again with a key press.
## Mouse and touch input do not switch (on the Steam Deck the trackpads and the touch screen send
## mouse events). The autoload InputSetup feeds every input event in (note()) and sets the start value
## from the connected gamepads (on the Steam Deck the built-in controller is always connected).
## `device` is the gamepad used last: the race steers with its stick only (a resting second pad with a drifting
## stick does not steer) and vibrates it. note() also keeps what every pad still holds, so that a disconnected
## pad can be judged (pad_lost()) – the engine has forgotten its state by the time it reports the disconnection.

## Stick/trigger deflection that counts as gamepad use (filters resting noise).
const AXIS_THRESHOLD := 0.5
## Stick/trigger deflection up to which a pad counts as resting when it is disconnected (noise; a worn stick drifts by
## up to ~0.2 – the steering actions' deadzone, InputSetup.STEER_DEADZONE).
const REST := 0.2

static var gamepad := false
## Device id of the gamepad used last (vibration goes to it, the race reads its stick – on a docked Steam Deck or a PC
## with two pads the active one is not always device 0).
static var device := 0
## What each pad still holds, as its events left it: device -> {"b<button>": 1.0, "a<axis>": value} – pressed buttons
## and axes beyond REST.
static var _held := {}
## Pads used since they connected (a button press or a stick/trigger push of at least AXIS_THRESHOLD): device -> true.
## Only a used pad steers (stick_device()) and counts as in use when it disconnects (pad_lost()) – a pad lying around
## unused, e.g. next to a keyboard player, steers nothing with a drifting stick and pauses nothing when it switches off.
static var _used := {}


## Updates the mode from an input event. Returns true if it changed.
static func note(event: InputEvent) -> bool:
	var pad := gamepad
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		_hold(b.device, "b%d" % b.button_index, 1.0 if b.pressed else 0.0)
		if b.pressed:
			pad = true
			device = b.device
			_used[b.device] = true
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		_hold(m.device, "a%d" % m.axis, m.axis_value)
		if absf(m.axis_value) >= AXIS_THRESHOLD:
			pad = true
			device = m.device
			_used[m.device] = true
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			pad = false
	if pad == gamepad:
		return false
	gamepad = pad
	return true


static func _hold(dev: int, key: String, value: float) -> void:
	var d: Dictionary = _held.get(dev, {})
	if absf(value) > REST:
		d[key] = value
	else:
		d.erase(key)
	if d.is_empty():
		_held.erase(dev)
	else:
		_held[dev] = d


## True while the pad `dev` holds a button or a stick / trigger beyond REST (as its last events left it).
static func holds(dev: int) -> bool:
	return _held.has(dev)


## True if the pad `dev` was used since it connected (a button press or a clear stick/trigger push).
static func used(dev: int) -> bool:
	return _used.has(dev)


## The pad whose stick steers: the active pad (`device`) once it has been used since it connected, else -1 (no stick
## steers – keys and the D-pad still do). A keyboard player's resting pad with a drifting stick therefore steers nothing.
static func stick_device() -> int:
	return device if _used.has(device) else -1


## A gamepad was (re)connected (InputSetup): it starts unused and holding nothing.
static func pad_connected(dev: int) -> void:
	_used.erase(dev)
	_held.erase(dev)


## A gamepad was disconnected (InputSetup): returns true if it was in use – the active pad (`device` while a gamepad is
## the active input, and used since it connected) or one still holding a button or a stick / trigger beyond REST. A keyboard player's idle pad
## switching off, or a second pad lying around, is not. Forgets the pad's inputs; when it was the active pad, the first
## pad still connected (`remaining`) takes over; with none left the keyboard is the active input.
static func pad_lost(dev: int, remaining: Array) -> bool:
	var in_use := (gamepad and dev == device and _used.has(dev)) or holds(dev)
	_held.erase(dev)
	_used.erase(dev)
	if dev == device and not remaining.is_empty():
		device = int(remaining[0])
	if remaining.is_empty():
		gamepad = false
	return in_use
