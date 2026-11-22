class_name FrameCap
extends RefCounted
## Lower frame rate while nothing on the screen needs it: the pause menu of the race (the paused road picture is
## still drawn every frame – 290 draw calls) and a window without focus. While at least one reason holds,
## Engine.max_fps is IDLE_FPS (or the lower limit set before); afterwards the previous limit returns (0 = none,
## or the --max-fps of the command line). Saves battery on the Steam Deck – the OLED model draws 90 frames per
## second otherwise. Not in headless runs and Movie Maker recordings (tests, videos).

const IDLE_FPS := 30

static var _reasons: Dictionary = {}
static var _before := -1             ## Engine.max_fps before the cap (-1 = not capped)


## Sets or clears one reason ("pause", "focus" …) and applies the cap.
static func hold(reason: String, on: bool) -> void:
	if on:
		_reasons[reason] = true
	else:
		_reasons.erase(reason)
	if not _usable():
		return
	if not _reasons.is_empty():
		if _before < 0:
			_before = Engine.max_fps
			Engine.max_fps = IDLE_FPS if _before <= 0 else mini(_before, IDLE_FPS)
	elif _before >= 0:
		Engine.max_fps = _before
		_before = -1


## True while the cap is applied.
static func capped() -> bool:
	return _before >= 0


static func _usable() -> bool:
	return DisplayServer.get_name() != "headless" and OS.get_cmdline_args().find("--write-movie") < 0
