class_name VehicleLayers
extends ModernAudioModule
## Slot "layers" of the Modern sound: the natively mixed loops of the player's drivetrain on the bus MEngineFx
## (→ MCar) – turbo tones and flow hiss, driveline whine (package AU-B; contract D27). Each loop is a ModernAudioLoop
## whose level and pitch follow frame.engine (rpm, gear, load, boost of the engine slot in the same frame),
## frame.speed and frame.throttle; sounds come from assets/audio/modern/vehicle (ctx.stream("vehicle", id)).
##
## Stand-in of wave 0: nothing sounds – the Arcade bank of the stand-in engine carries its own turbo whistle.

var boost := 0.0                 ## last boost seen (tests: the slot receives the engine state)


func update(frame: ModernAudioFrame) -> void:
	boost = float(frame.engine.get("boost", 0.0))


func debug_state() -> Dictionary:
	return {"boost": boost, "loops": 0}
