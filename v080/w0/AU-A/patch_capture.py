P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/tools/audio/modern/capture_mix.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old)
    s = s.replace(old, new)


rep('''var _duck_sum := 0.0
''', '''var _duck_sum := 0.0
var _sample_from := 0.0          # the phase is measured from this time on
''')
rep('''	var m: Variant = _am.get("_modern")
	if not (m is ModernAudio):
		return
''', '''	var m: Variant = _am.get("_modern")
	if not (m is ModernAudio) or _now() < _sample_from:
		return
''')
rep('''	var t0 := _now()
	while _now() - t0 < 3.0:
		_send(0.0, 0.0, vmax)
		await process_frame
	_phase("idle", t0 + 1.5, _now())
	t0 = _now()
	var v := 0.0
''', '''	var t0 := _now()
	_sample_from = t0 + 1.5
	while _now() - t0 < 3.0:
		_send(0.0, 0.0, vmax)
		await process_frame
	_phase("idle", t0 + 1.5, _now())
	t0 = _now()
	_sample_from = t0 + 1.0
	var v := 0.0
''')
rep('''	_phase("full_throttle", t0 + 1.0, _now())
	t0 = _now()
''', '''	_phase("full_throttle", t0 + 1.0, _now())
	t0 = _now()
	_sample_from = t0
''')
rep('''	_phase("lift", t0, _now())
	t0 = _now()
''', '''	_phase("lift", t0, _now())
	t0 = _now()
	_sample_from = t0 + 2.0
''')
rep('''## Output: <out>.wav (16 bit, 44.1 kHz, the signal after the Master volume and limiter – what reaches the sound
## card) and <out>.json with the phases of the scenario {name, t0, t1} and the settings.''', '''## Output: <out>.wav (16 bit, 44.1 kHz, the signal after the Master volume and limiter – what reaches the sound
## card) and <out>.json with the phases of the scenario {name, t0, t1} and the settings; with the Modern profile
## each phase also has what the mix saw of the car bus: car_bus_rms_db (the ducking key), car_bus_peak_db, duck_db.''')
open(P, "w", encoding="utf-8").write(s)
print("ok")
