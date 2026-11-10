class_name ModernMix
extends RefCounted
## Mix of the sound profile "Modern" (contract D29, docs/audio-modern.md "Pegelplan"): the loudness plan as bus
## levels, the scripted ducking of the music under the car and the snapshots (pause, impact, siren, result).
## Pure – no AudioServer: ModernAudio passes the measured peak level of the key bus each frame (step()) and writes
## static_db() / gain_db() / lowpass_hz() to the buses (ModernBuses). Every number comes from audio.modern.
##
##   static level  levels.<bus> (plan) + the volume setting ("Effekte" on MSfx, "Musik" on MMusic); a setting of 0
##                 mutes the bus. Master carries "Gesamtlautstärke" as in Arcade (shared bus).
##   ducking       gain of duck.bus (MMusic) = −depth_db · clamp((level of duck.key − from_db) / (to_db − from_db), 0, 1),
##                 smoothed with attack_s when the music has to go down and release_s when it comes back.
##   snapshots     named states with a weight 0..1 that moves with attack_s / release_s: gain_db per bus (added,
##                 weighted) and lowpass_hz per bus (cutoff glides from 20 kHz to the value; the lowest wins).
##                 set_active(name, on) holds one; trigger(name) fires it for its hold_s.
##   effects off   while the effects are muted (volume 0, attract demo) nothing ducks or dips the music.

const KEY_FLOOR_DB := -200.0
const LOWPASS_OFF_HZ := 20000.0
const DEFAULT_LEVELS := {"MMaster": 0.0, "MMusic": 0.0, "MSfx": 0.0, "MUI": 0.0, "MEnv": 0.0, "MCar": 0.0,
	"MEngine": 0.0, "MEngineFx": 0.0, "MRoad": 0.0, "MWind": 0.0, "MImpact": 0.0, "MWorld": 0.0, "MSiren": 0.0, "MAmb": 0.0}
## Contexts of the music (AudioManager.set_music_context).
const CONTEXTS: Array[String] = ["title", "menu", "race_menu", "race", "result", "off"]
const UNMUTE_PEAK_DB := -70.0    ## effects unmuted again once the reverb tail is below this …
const UNMUTE_MAX_S := 1.5        ## … or after this time


class Snapshot:
	var name := ""
	var attack_s := 0.2
	var release_s := 0.4
	var hold_s := 0.0
	var gain_db: Dictionary = {}       ## bus -> dB at weight 1
	var lowpass_hz: Dictionary = {}    ## bus -> cutoff at weight 1
	var weight := 0.0
	var active := false                ## held by set_active()
	var hold_left := 0.0               ## remaining time of a trigger()


var levels: Dictionary = DEFAULT_LEVELS.duplicate()
var loudness: Dictionary = {}        ## the plan's targets (LUFS / dB) as documented data for tests and tools
var context_db: Dictionary = {}      ## music context -> dB (player level of the MusicDirector)
var sfx_volume := 1.0
var music_volume := 0.7
var duck_key := "MCar"
var duck_bus := "MMusic"
var duck_from_db := -30.0
var duck_to_db := -12.0
var duck_depth_db := 4.5
var duck_attack_s := 0.05
var duck_release_s := 0.45
var duck_db := 0.0                   ## current ducking gain (<= 0)
var snapshots: Dictionary = {}       ## name -> Snapshot
var effects_muted := false           ## result of the last step()
var _mute_hold := 0.0


func setup(modern: Dictionary) -> void:
	levels = DEFAULT_LEVELS.duplicate()
	var lv: Variant = modern.get("levels", {})
	if lv is Dictionary:
		for k: String in lv:
			if not k.begins_with("_"):
				levels[k] = float(lv[k])
	var ld: Variant = modern.get("loudness", {})
	loudness = (ld as Dictionary).duplicate() if ld is Dictionary else {}
	var music: Variant = modern.get("music", {})
	context_db = {}
	if music is Dictionary and (music as Dictionary).get("context_db", null) is Dictionary:
		for k: String in (music as Dictionary)["context_db"]:
			context_db[k] = float((music as Dictionary)["context_db"][k])
	var d: Variant = modern.get("duck", {})
	if d is Dictionary:
		duck_key = str((d as Dictionary).get("key", duck_key))
		duck_bus = str((d as Dictionary).get("bus", duck_bus))
		duck_from_db = float((d as Dictionary).get("from_db", duck_from_db))
		duck_to_db = maxf(float((d as Dictionary).get("to_db", duck_to_db)), duck_from_db + 0.1)
		duck_depth_db = maxf(float((d as Dictionary).get("depth_db", duck_depth_db)), 0.0)
		duck_attack_s = maxf(float((d as Dictionary).get("attack_s", duck_attack_s)), 0.001)
		duck_release_s = maxf(float((d as Dictionary).get("release_s", duck_release_s)), 0.001)
	snapshots = {}
	var sn: Variant = modern.get("snapshots", {})
	if sn is Dictionary:
		for k: String in sn:
			var e: Variant = sn[k]
			if k.begins_with("_") or not (e is Dictionary):
				continue
			var s := Snapshot.new()
			s.name = k
			s.attack_s = maxf(float((e as Dictionary).get("attack_s", 0.2)), 0.001)
			s.release_s = maxf(float((e as Dictionary).get("release_s", 0.4)), 0.001)
			s.hold_s = maxf(float((e as Dictionary).get("hold_s", 0.0)), 0.0)
			for field: String in ["gain_db", "lowpass_hz"]:
				var m: Variant = (e as Dictionary).get(field, {})
				if m is Dictionary:
					var into: Dictionary = s.gain_db if field == "gain_db" else s.lowpass_hz
					for bus: String in m:
						into[bus] = float(m[bus])
			snapshots[k] = s
	duck_db = 0.0
	effects_muted = false
	_mute_hold = 0.0


## Volume settings 0..1 ("Effekte", "Musik"); "Gesamtlautstärke" stays on Master (AudioManager.apply_volumes).
func set_volumes(sfx: float, music: float) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)


## Static level of a bus in dB: plan level plus the volume setting on the two group buses.
func static_db(bus: String) -> float:
	var db := float(levels.get(bus, 0.0))
	if bus == "MSfx":
		db += linear_to_db(maxf(sfx_volume, 0.0001))
	elif bus == "MMusic":
		db += linear_to_db(maxf(music_volume, 0.0001))
	return db


## A volume setting of 0 mutes its group bus.
func static_mute(bus: String) -> bool:
	if bus == "MSfx":
		return sfx_volume <= 0.001
	if bus == "MMusic":
		return music_volume <= 0.001
	return false


## Level of the music players in a context (dB on a master at loudness.master_lufs).
func music_context_db(context: String) -> float:
	return float(context_db.get(context, 0.0))


func has_snapshot(snapshot: String) -> bool:
	return snapshots.has(snapshot)


## Holds a snapshot (pause, siren, result) or lets it go.
func set_active(snapshot: String, on: bool) -> void:
	var s: Snapshot = snapshots.get(snapshot)
	if s != null:
		s.active = on


## Fires a snapshot for its hold_s (impact).
func trigger(snapshot: String) -> void:
	var s: Snapshot = snapshots.get(snapshot)
	if s != null:
		s.hold_left = maxf(s.hold_s, 0.001)


func weight(snapshot: String) -> float:
	var s: Snapshot = snapshots.get(snapshot)
	return s.weight if s != null else 0.0


## Everything back to neutral at once (profile start, tests).
func reset() -> void:
	duck_db = 0.0
	_mute_hold = 0.0
	for k: String in snapshots:
		var s: Snapshot = snapshots[k]
		s.weight = 0.0
		s.active = false
		s.hold_left = 0.0


## Wanted ducking gain (<= 0 dB) for a level of the key bus (dBFS peak).
func duck_target_db(key_db: float) -> float:
	return -duck_depth_db * clampf((key_db - duck_from_db) / (duck_to_db - duck_from_db), 0.0, 1.0)


## One frame. key_db = peak level of the key bus (duck_key) in the last mix block; mute_request = the effects are
## to be silent (volume 0, attract demo); tail_db = level of the reverb path (the effects come back only once it
## has died away or after UNMUTE_MAX_S).
func step(dt: float, key_db: float, mute_request: bool = false, tail_db: float = KEY_FLOOR_DB) -> void:
	if dt <= 0.0:
		return
	if mute_request:
		_mute_hold = UNMUTE_MAX_S
		effects_muted = true
	elif effects_muted:
		_mute_hold -= dt
		if _mute_hold <= 0.0 or tail_db < UNMUTE_PEAK_DB:
			effects_muted = false
			_mute_hold = 0.0
	var want := 0.0 if effects_muted else duck_target_db(key_db)
	var tau := duck_attack_s if want < duck_db else duck_release_s
	duck_db += (want - duck_db) * (1.0 - exp(-dt / tau))
	if absf(duck_db) < 0.001 and want == 0.0:
		duck_db = 0.0
	for k: String in snapshots:
		var s: Snapshot = snapshots[k]
		var on := (s.active or s.hold_left > 0.0) and not effects_muted
		s.hold_left = maxf(0.0, s.hold_left - dt)
		s.weight = move_toward(s.weight, 1.0 if on else 0.0, dt / (s.attack_s if on else s.release_s))


## Scripted gain of a bus in dB (for its fader): ducking + the snapshots' dips.
func gain_db(bus: String) -> float:
	var db := duck_db if bus == duck_bus else 0.0
	for k: String in snapshots:
		var s: Snapshot = snapshots[k]
		if s.weight > 0.0 and s.gain_db.has(bus):
			db += s.weight * float(s.gain_db[bus])
	return db


## Snapshot low-pass of a bus: LOWPASS_OFF_HZ = none. The cutoff glides on a logarithmic scale.
func lowpass_hz(bus: String) -> float:
	var hz := LOWPASS_OFF_HZ
	for k: String in snapshots:
		var s: Snapshot = snapshots[k]
		if s.weight > 0.0 and s.lowpass_hz.has(bus):
			var target := clampf(float(s.lowpass_hz[bus]), 60.0, LOWPASS_OFF_HZ)
			hz = minf(hz, exp(lerpf(log(LOWPASS_OFF_HZ), log(target), s.weight)))
	return hz


## Plain data for tests and the debug overlay.
func state() -> Dictionary:
	var sn := {}
	for k: String in snapshots:
		sn[k] = (snapshots[k] as Snapshot).weight
	return {"duck_db": duck_db, "snapshots": sn, "effects_muted": effects_muted, "sfx_volume": sfx_volume,
		"music_volume": music_volume}
