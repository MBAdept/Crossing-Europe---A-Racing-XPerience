class_name RoadAudio
extends ModernAudioModule
## Slot "road" of the Modern sound: what the player's car does on the road – tyres per side and surface, rumble
## strip, shoulder, expansion joints, pass-by whooshes of roadside objects on the bus MRoad, wind on MWind (both
## → MCar; package AU-C1). Inputs: frame.speed, frame.skid, frame.has_state / frame.state (lateral speed, brake,
## off_road, rail_contact, …), frame.feed (surface_l / surface_r, wet, snow, zone, bridge) and the feed's events
## through event() ("joint", "pass_object", "tunnel_in", …).
##
## Stand-in of wave 0: today's two loops with the Arcade levels – the wind (∝ speed) and the tyre squeal of
## understeer (AudioManager's SfxSynth streams "wind" and "skid", or Modern files vehicle/wind and vehicle/skid once
## they exist).

const TAU_SLOW := 0.25
const TAU_FAST := 0.06

var wind := ModernAudioLoop.new()
var skid := ModernAudioLoop.new()
var joints := 0                  ## feed events seen (tests)
var passes := 0


func _setup() -> void:
	wind.attach(ctx, "MWind", ctx.stream("vehicle", "wind", "wind"), "Wind")
	skid.attach(ctx, "MRoad", ctx.stream("vehicle", "skid", "skid"), "Skid")


func update(frame: ModernAudioFrame) -> void:
	var k_fast := 1.0 - exp(-frame.dt / TAU_FAST)
	var k_slow := 1.0 - exp(-frame.dt / TAU_SLOW)
	var w := 0.0
	if frame.alive:
		w = pow(clampf((frame.wind_speed - 35.0) / 220.0, 0.0, 1.0), 1.4) * 0.55
	wind.drive(w, 0.85 + 0.4 * clampf(frame.wind_speed / 250.0, 0.0, 1.2), k_slow)
	var s := clampf(frame.skid - 0.15, 0.0, 1.0) * 0.45 if frame.alive else 0.0
	skid.drive(s, 1.0 + 0.05 * sin(frame.time * 9.0), k_fast)


func event(event_name: String, _args: Dictionary) -> void:
	if event_name == "joint":
		joints += 1
	elif event_name == "pass_object":
		passes += 1


func stop_all() -> void:
	wind.silence()
	skid.silence()


func teardown() -> void:
	wind.release()
	skid.release()


func debug_state() -> Dictionary:
	return {"wind": wind.level, "skid": skid.level, "joints": joints, "passes": passes}
