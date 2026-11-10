class_name ImpactAudio
extends ModernAudioModule
## Slot "impact" of the Modern sound: collisions and the guardrail on the bus MImpact (→ MEnv; package AU-C1).
## The real slot builds its sounds from the session events – "collision" {speed_kmh, heavy, side} layered by speed
## and partner, "rail_hit" {impact_mps, side} and a continuous scrape while frame.state["rail_contact"] – and then
## names them in claims(), so the plain play("crash") / play("rail") of the same moment is dropped.
##
## Stand-in of wave 0: it claims nothing and plays today's two one-shots for play("crash") and play("rail", gain)
## with the Arcade levels (AudioManager's SfxSynth streams, or Modern files sfx/crash and sfx/rail once they exist).

const LEVEL_DB := {"crash": -1.0, "rail": -5.0}   ## as AudioManager.ONESHOT_DB

var voices := ModernAudioVoices.new()
var counts: Dictionary = {}      ## sound -> one-shots taken (tests)
var events: Dictionary = {}      ## event name -> count (tests)


func _setup() -> void:
	voices.attach(ctx, "MImpact", 4, "Impact")


func play(sound: String, gain_db: float) -> bool:
	if not LEVEL_DB.has(sound):
		return false
	counts[sound] = int(counts.get(sound, 0)) + 1
	voices.play(ctx.stream("sfx", sound, sound), float(LEVEL_DB[sound]) + gain_db)
	return true


func event(event_name: String, _args: Dictionary) -> void:
	if event_name == "collision" or event_name == "rail_hit":
		events[event_name] = int(events.get(event_name, 0)) + 1


func stop_all() -> void:
	voices.stop_all()


func teardown() -> void:
	voices.release()


func debug_state() -> Dictionary:
	return {"plays": counts.duplicate(), "events": events.duplicate(), "busy": voices.busy()}
