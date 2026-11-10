class_name AmbienceAudio
extends ModernAudioModule
## Slot "ambience" of the Modern sound: the beds of the surroundings on the bus MAmb (→ MSfx, no reverb path –
## a bed carries its own space; package AU-C2): countryside by day and night, city, harbour, fuel station, tunnel
## fans, rain on the body, thunder, snow hush – chosen from frame.feed (zone, tunnel, cover, wet, snow), the hour
## and weather of frame.state, fading with the speed. Sounds: assets/audio/modern/ambience.
##
## Stand-in of wave 0: today's rain loop with the Arcade level (frame.rain: the session's set_rain() or the HUD
## hint; AudioManager's SfxSynth stream "rain", or the Modern file ambience/rain once it exists).

const TAU := 0.25

var rain := ModernAudioLoop.new()


func _setup() -> void:
	rain.attach(ctx, "MAmb", ctx.stream("ambience", "rain", "rain"), "Rain")


func update(frame: ModernAudioFrame) -> void:
	rain.drive(frame.rain * 0.38 if not frame.paused else 0.0, 1.0, 1.0 - exp(-frame.dt / TAU))


func stop_all() -> void:
	rain.silence()


func teardown() -> void:
	rain.release()


func debug_state() -> Dictionary:
	return {"rain": rain.level}
