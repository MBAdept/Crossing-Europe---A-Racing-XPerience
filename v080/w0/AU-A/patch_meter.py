R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("scripts/audio/modern/modern_buses.gd", [
    ('''## Buses with a low-pass for snapshots (pause): disabled while not needed.
const LOWPASS_BUSES: Array[String] = ["MMusic", "MEnv", "MAmb"]
''', '''## Buses with a low-pass for snapshots (pause): disabled while not needed.
const LOWPASS_BUSES: Array[String] = ["MMusic", "MEnv", "MAmb"]
## Buses with a level meter (AudioEffectCapture behind the fader, read by level_db()): the car bus steers the
## ducking of the music. The engine only offers peak meters per bus; the peak of an engine sound says little about
## its loudness (measured with the stand-in engine: peak −5.7 dBFS at idle, −0.5 dBFS at full throttle, 8 dB apart
## in loudness), so the meter takes the RMS of what passed.
const METER_BUSES: Array[String] = ["MCar"]
const METER_STRIDE := 4          ## every n-th frame is enough for a level
'''),
    ('''var _gain_db: Dictionary = {}     ## bus -> last fader value
''', '''var _gain_db: Dictionary = {}     ## bus -> last fader value
var _meters: Dictionary = {}      ## bus -> AudioEffectCapture
var _meter_db: Dictionary = {}    ## bus -> last level
'''),
    ('''	# traffic voices and the siren: low-pass of the air absorption (parameters: slot TrafficExtras)
''', '''	for n in METER_BUSES:
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 0.1
		AudioServer.add_bus_effect(index(n), cap)
		_meters[n] = cap
		_meter_db[n] = PEAK_FLOOR_DB
	# traffic voices and the siren: low-pass of the air absorption (parameters: slot TrafficExtras)
'''),
    ('''	_faders.clear()
	_lowpass.clear()
	_gain_db.clear()
''', '''	_faders.clear()
	_lowpass.clear()
	_meters.clear()
	_meter_db.clear()
	_gain_db.clear()
'''),
    ('''		if fx.get_class() == cls and fx != _faders.get(bus) and fx != _lowpass.get(bus):
			return fx
''', '''		if fx.get_class() == cls and fx != _faders.get(bus) and fx != _lowpass.get(bus) and fx != _meters.get(bus):
			return fx
'''),
    ('''## Static gain in dB from a bus to the Master input: the bus volumes along its sends (faders not included).''',
     '''## RMS level of a meter bus (METER_BUSES) since the last call, in dBFS as it leaves the bus (mean of both channels,
## after effects, fader and volume). Keeps the last value while no new audio has been mixed; PEAK_FLOOR_DB when
## silent or for a bus without a meter.
func level_db(bus: String) -> float:
	var cap: AudioEffectCapture = _meters.get(bus)
	if cap == null:
		return PEAK_FLOOR_DB
	var n := cap.get_frames_available()
	if n < 64:
		return float(_meter_db[bus])
	var frames := cap.get_buffer(n)
	var sum := 0.0
	var count := 0
	for i in range(0, frames.size(), METER_STRIDE):
		var v := frames[i]
		sum += v.x * v.x + v.y * v.y
		count += 1
	var db := PEAK_FLOOR_DB
	if sum > 1.0e-20 and count > 0:
		db = 10.0 * log(sum / (2.0 * count)) / log(10.0) + AudioServer.get_bus_volume_db(index(bus))
	_meter_db[bus] = db
	return db


## Static gain in dB from a bus to the Master input: the bus volumes along its sends (faders not included).'''),
])

patch("scripts/audio/modern/modern_audio.gd", [
    ('''func _key_db() -> float:
	if ctx.live and key_db_override <= ModernMix.KEY_FLOOR_DB:
		return buses.peak_db(mix.duck_key)
	return key_db_override
''', '''func _key_db() -> float:
	if ctx.live and key_db_override <= ModernMix.KEY_FLOOR_DB:
		return buses.level_db(mix.duck_key) if ModernBuses.METER_BUSES.has(mix.duck_key) else buses.peak_db(mix.duck_key)
	return key_db_override
'''),
    ('''## Tests / headless: level of the key bus used instead of its meter while nothing plays (dBFS).''',
     '''## Tests / headless: level of the key bus used instead of its meter while nothing plays (dBFS RMS).'''),
])

patch("scripts/audio/modern/modern_mix.gd", [
    ('''##   ducking       gain of duck.bus (MMusic) = −depth_db · clamp((level of duck.key − from_db) / (to_db − from_db), 0, 1),
##                 smoothed with attack_s when the music has to go down and release_s when it comes back.''',
     '''##   ducking       gain of duck.bus (MMusic) = −depth_db · clamp((level of duck.key − from_db) / (to_db − from_db), 0, 1),
##                 smoothed with attack_s when the music has to go down and release_s when it comes back. The
##                 level is the RMS of the key bus in dBFS (ModernBuses.level_db).'''),
    ('''## Wanted ducking gain (<= 0 dB) for a level of the key bus (dBFS peak).''', '''## Wanted ducking gain (<= 0 dB) for a level of the key bus (dBFS RMS).'''),
    ('''## One frame. key_db = peak level of the key bus (duck_key) in the last mix block; mute_request = the effects are''',
     '''## One frame. key_db = RMS level of the key bus (duck_key) since the last frame; mute_request = the effects are'''),
])

patch("tests/unit/audio_modern/test_modern_buses.gd", [
    ('''	assert_eq(_classes("MCar"), ["AudioEffectAmplify"] as Array[String], "MCar: Fader")''',
     '''	assert_eq(_classes("MCar"), ["AudioEffectAmplify", "AudioEffectCapture"] as Array[String], "MCar: Fader und Pegelmesser dahinter")
	assert_near(b.level_db("MCar"), ModernBuses.PEAK_FLOOR_DB, 1.0e-6, "Pegelmesser: Stille")
	assert_near(b.level_db("MMusic"), ModernBuses.PEAK_FLOOR_DB, 1.0e-6, "Bus ohne Pegelmesser")'''),
])
print("ok")
