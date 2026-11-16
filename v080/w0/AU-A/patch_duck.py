"""Ducking key: the car's loudness after the plan (from the driving state) instead of a bus meter."""
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("scripts/audio/modern/modern_mix.gd", [
    ('''## Pure – no AudioServer: ModernAudio passes the measured peak level of the key bus each frame (step()) and writes
## static_db() / gain_db() / lowpass_hz() to the buses (ModernBuses). Every number comes from audio.modern.
''', '''## Pure – no AudioServer: ModernAudio passes the driving state each frame (car_lufs(), step()) and writes
## static_db() / gain_db() / lowpass_hz() to the buses (ModernBuses). Every number comes from audio.modern.
'''),
    ('''##   ducking       gain of duck.bus (MMusic) = −depth_db · clamp((level of duck.key − from_db) / (to_db − from_db), 0, 1),
##                 smoothed with attack_s when the music has to go down and release_s when it comes back.
''', '''##   ducking       gain of duck.bus (MMusic) = −depth_db · clamp((car − from_lufs) / (to_lufs − from_lufs), 0, 1),
##                 smoothed with attack_s when the music has to go down and release_s when it comes back. "car"
##                 is the loudness the plan gives the car in its driving state (car_lufs(): idle_lufs standing,
##                 cruise_lufs rolling at pace_cruise × top speed, full_throttle_lufs under full load) – scripted
##                 and the same in every run. It is not metered from the car bus: the engine offers only peak
##                 meters, and neither the peak nor the RMS of an engine sound follows its loudness (measured on
##                 the car bus with the stand-in engine, idle / 130 km/h / full throttle at −20.4 / −22.7 / −16.2
##                 LUFS: peak −6.4 / −11.1 / −0.3 dBFS, RMS −15.3 / −20.7 / −14.4 dBFS).
'''),
    ('''var duck_key := "MCar"
var duck_bus := "MMusic"
var duck_from_db := -30.0
var duck_to_db := -12.0
var duck_depth_db := 4.5
var duck_attack_s := 0.05
var duck_release_s := 0.45
var duck_db := 0.0                   ## current ducking gain (<= 0)
''', '''var duck_bus := "MMusic"
var duck_from_lufs := -23.0          ## car loudness up to which the music is not ducked …
var duck_to_lufs := -17.0            ## … and from which it is ducked by the full depth
var duck_depth_db := 4.5
var duck_attack_s := 0.05
var duck_release_s := 0.45
var pace_cruise := 0.55              ## share of the top speed at which a rolling car reaches cruise_lufs
var duck_db := 0.0                   ## current ducking gain (<= 0)
var car := KEY_FLOOR_DB              ## the car's loudness (LUFS after the plan) given to the last step()
'''),
    ('''		duck_key = str((d as Dictionary).get("key", duck_key))
		duck_bus = str((d as Dictionary).get("bus", duck_bus))
		duck_from_db = float((d as Dictionary).get("from_db", duck_from_db))
		duck_to_db = maxf(float((d as Dictionary).get("to_db", duck_to_db)), duck_from_db + 0.1)
''', '''		duck_bus = str((d as Dictionary).get("bus", duck_bus))
		duck_from_lufs = float((d as Dictionary).get("from_lufs", duck_from_lufs))
		duck_to_lufs = maxf(float((d as Dictionary).get("to_lufs", duck_to_lufs)), duck_from_lufs + 0.1)
		pace_cruise = clampf(float((d as Dictionary).get("pace_cruise", pace_cruise)), 0.05, 1.0)
'''),
    ('''## Wanted ducking gain (<= 0 dB) for a level of the key bus (dBFS peak).
func duck_target_db(key_db: float) -> float:
	return -duck_depth_db * clampf((key_db - duck_from_db) / (duck_to_db - duck_from_db), 0.0, 1.0)
''', '''## The loudness the plan gives the car in a driving state (LUFS at the default sliders): idle_lufs standing,
## towards cruise_lufs as it rolls faster (reached at pace_cruise × vmax), towards full_throttle_lufs with the
## engine load (0..1). KEY_FLOOR_DB when no car is driven (menus, pause, the session gone).
func car_lufs(alive: bool, speed_kmh: float, vmax_kmh: float, load: float) -> float:
	if not alive:
		return KEY_FLOOR_DB
	var idle := float(loudness.get("idle_lufs", -24.0))
	var cruise := float(loudness.get("cruise_lufs", -21.0))
	var full := float(loudness.get("full_throttle_lufs", -16.0))
	var pace := clampf(speed_kmh / maxf(vmax_kmh, 1.0) / pace_cruise, 0.0, 1.0)
	return lerpf(lerpf(idle, cruise, pace), full, clampf(load, 0.0, 1.0))


## Wanted ducking gain (<= 0 dB) for a loudness of the car (LUFS).
func duck_target_db(car_loudness: float) -> float:
	return -duck_depth_db * clampf((car_loudness - duck_from_lufs) / (duck_to_lufs - duck_from_lufs), 0.0, 1.0)
'''),
    ('''## One frame. key_db = peak level of the key bus (duck_key) in the last mix block; mute_request = the effects are
''', '''## One frame. car_loudness = car_lufs() of the driving state (or a measured value); mute_request = the effects are
'''),
    ('''func step(dt: float, key_db: float, mute_request: bool = false, tail_db: float = KEY_FLOOR_DB) -> void:
	if dt <= 0.0:
		return
''', '''func step(dt: float, car_loudness: float, mute_request: bool = false, tail_db: float = KEY_FLOOR_DB) -> void:
	if dt <= 0.0:
		return
	car = car_loudness
'''),
    ('''	var want := 0.0 if effects_muted else duck_target_db(key_db)
''', '''	var want := 0.0 if effects_muted else duck_target_db(car_loudness)
'''),
    ('''	return {"duck_db": duck_db, "snapshots": sn, "effects_muted": effects_muted, "sfx_volume": sfx_volume,
		"music_volume": music_volume}''', '''	return {"duck_db": duck_db, "car_lufs": car, "snapshots": sn, "effects_muted": effects_muted,
		"sfx_volume": sfx_volume, "music_volume": music_volume}'''),
])

patch("scripts/audio/modern/modern_audio.gd", [
    ('''##   • mix: feeds ModernMix the level of the car bus, holds the snapshots (pause while the tree is paused, siren
##     during a chase, result from "stage_finish" until the stage is left, impact on a collision) and writes
##     fader gains, low-passes and the music EQ to the buses;
''', '''##   • mix: gives ModernMix the driving state (the car's loudness after the plan steers the ducking of the music),
##     holds the snapshots (pause while the tree is paused, siren during a chase, result from "stage_finish" until
##     the stage is left, impact on a collision) and writes fader gains, low-passes and the music EQ to the buses;
'''),
    ('''## Tests / headless: level of the key bus used instead of its meter while nothing plays (dBFS).
var key_db_override := ModernMix.KEY_FLOOR_DB
''', '''## Tests: loudness of the car (LUFS) used for the ducking instead of the one of the driving state.
var car_lufs_override := ModernMix.KEY_FLOOR_DB
'''),
    ('''	# mix
	var mute_request := mix.static_mute("MSfx") or _arcade_effects_muted()
	mix.set_active("pause", paused)
	mix.set_active("siren", f.siren_on)
	mix.set_active("result", _result)
	mix.step(delta, _key_db(), mute_request, buses.peak_db("MEnv") if ctx.live else ModernMix.KEY_FLOOR_DB)
	f.effects_muted = mix.effects_muted
	# slots
	for m in modules:
		m.update(f)
		if m == engine:
			f.engine = engine.state()
	_apply_mix()
''', '''	# slots (they see the effects mute of the frame before)
	for m in modules:
		m.update(f)
		if m == engine:
			f.engine = engine.state()
	# mix
	var mute_request := mix.static_mute("MSfx") or _arcade_effects_muted()
	mix.set_active("pause", paused)
	mix.set_active("siren", f.siren_on)
	mix.set_active("result", _result)
	var car := mix.car_lufs(f.alive, f.speed, f.vmax, float(f.engine.get("load", f.throttle)))
	if car_lufs_override > ModernMix.KEY_FLOOR_DB:
		car = car_lufs_override
	mix.step(delta, car, mute_request, buses.peak_db("MEnv") if ctx.live else ModernMix.KEY_FLOOR_DB)
	f.effects_muted = mix.effects_muted
	_apply_mix()
'''),
    ('''func _key_db() -> float:
	if ctx.live and key_db_override <= ModernMix.KEY_FLOOR_DB:
		return buses.peak_db(mix.duck_key)
	return key_db_override


''', ''''''),
])

# --- configuration
P = R + "config/game_config.json"
s = open(P, encoding="utf-8").read()
old = '"duck": {"key": "MCar", "bus": "MMusic", "from_db": -24.0, "to_db": -10.0, "depth_db": 4.5, "attack_s": 0.05, "release_s": 0.45},'
new = '"duck": {"bus": "MMusic", "from_lufs": -23.0, "to_lufs": -17.0, "depth_db": 4.5, "attack_s": 0.05, "release_s": 0.45, "pace_cruise": 0.55},'
assert s.count(old) == 1
s = s.replace(old, new)
old = ("duck = Absenken der Musik unter dem Auto: Pegel des Busses key (Spitze in dBFS) von from_db bis to_db senkt bus "
       "um 0 bis depth_db, schnell hinunter (attack_s), langsam zurück (release_s). ")
new = ("duck = Absenken der Musik unter dem Auto: die Lautheit, die der Pegelplan dem Auto in seinem Fahrzustand gibt "
       "(Leerlauf im Stand, Reisetempo beim Rollen ab pace_cruise × Höchsttempo, Vollgas bei voller Motorlast), senkt "
       "bus von from_lufs bis to_lufs um 0 bis depth_db, schnell hinunter (attack_s), langsam zurück (release_s). ")
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)
open(P, "w", encoding="utf-8").write(s)
print("ok")
