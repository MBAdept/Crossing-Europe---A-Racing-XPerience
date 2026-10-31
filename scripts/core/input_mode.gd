class_name InputMode
extends RefCounted
## The input device the player is using right now, for key hints and tutorial texts: `gamepad` turns
## true with a gamepad button or a clear stick/trigger movement and false again with a key press.
## Mouse and touch input do not switch (on the Steam Deck the trackpads and the touch screen send
## mouse events). The autoload InputSetup feeds every input event in (note()) and sets the start value
## from the connected gamepads (on the Steam Deck the built-in controller is always connected).

## Stick/trigger deflection that counts as gamepad use (filters resting noise).
const AXIS_THRESHOLD := 0.5

static var gamepad := false


## Updates the mode from an input event. Returns true if it changed.
static func note(event: InputEvent) -> bool:
	var pad := gamepad
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD:
			pad = true
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			pad = false
	if pad == gamepad:
		return false
	gamepad = pad
	return true
