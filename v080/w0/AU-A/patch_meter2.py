R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("scripts/audio/modern/modern_mix.gd", [
    ('''var duck_db := 0.0                   ## current ducking gain (<= 0)
''', '''var duck_db := 0.0                   ## current ducking gain (<= 0)
var key_db := KEY_FLOOR_DB           ## level of the key bus in the last step()
'''),
    ('''func step(dt: float, key_db: float, mute_request: bool = false, tail_db: float = KEY_FLOOR_DB) -> void:
	if dt <= 0.0:
		return
''', '''func step(dt: float, p_key_db: float, mute_request: bool = false, tail_db: float = KEY_FLOOR_DB) -> void:
	if dt <= 0.0:
		return
	key_db = p_key_db
'''),
    ('''	return {"duck_db": duck_db, "snapshots": sn, "effects_muted": effects_muted, "sfx_volume": sfx_volume,
		"music_volume": music_volume}''', '''	return {"duck_db": duck_db, "key_db": key_db, "snapshots": sn, "effects_muted": effects_muted,
		"sfx_volume": sfx_volume, "music_volume": music_volume}'''),
])

patch("tools/audio/modern/capture_mix.gd", [
    ('''var _phases: Array = []
var _t0 := 0
''', '''var _phases: Array = []
var _t0 := 0
var _key_sum := 0.0              # Modern: power of the ducking key level (car bus) over the running phase
var _key_n := 0
var _peak := -200.0              # Modern: highest block peak of the car bus in the running phase
var _duck_sum := 0.0
'''),
    ('''func _phase(phase_name: String, t0: float, t1: float) -> void:
	_phases.append({"name": phase_name, "t0": snappedf(t0, 0.001), "t1": snappedf(t1, 0.001)})
''', '''func _phase(phase_name: String, t0: float, t1: float) -> void:
	var p := {"name": phase_name, "t0": snappedf(t0, 0.001), "t1": snappedf(t1, 0.001)}
	if _key_n > 0:
		p["car_bus_rms_db"] = snappedf(10.0 * log(maxf(_key_sum / _key_n, 1.0e-20)) / log(10.0), 0.01)
		p["car_bus_peak_db"] = snappedf(_peak, 0.01)
		p["duck_db"] = snappedf(_duck_sum / _key_n, 0.01)
	_phases.append(p)
	_key_sum = 0.0
	_key_n = 0
	_peak = -200.0
	_duck_sum = 0.0


## Modern: what the mix saw of the car bus in this frame.
func _sample_mix() -> void:
	var m: Variant = _am.get("_modern")
	if not (m is ModernAudio):
		return
	var mo: ModernAudio = m
	if mo.mix.key_db > -150.0:
		_key_sum += pow(10.0, mo.mix.key_db / 10.0)
		_key_n += 1
		_duck_sum += mo.mix.duck_db
	_peak = maxf(_peak, mo.buses.peak_db("MCar"))
'''),
    ('''	_am.call("set_engine", speed, throttle, vmax, true)
	_am.call("set_wind", speed)
	_am.call("set_environment", {"tunnel": false})
''', '''	_am.call("set_engine", speed, throttle, vmax, true)
	_am.call("set_wind", speed)
	_am.call("set_environment", {"tunnel": false})
	_sample_mix()
'''),
    ('''	_phase("idle", t0 + 1.5, _now())
	t0 = _now()
''', '''	_phase("idle", t0 + 1.5, _now())
	t0 = _now()
'''),
])
print("ok")
