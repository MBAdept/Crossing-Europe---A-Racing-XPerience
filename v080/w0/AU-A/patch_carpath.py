"""Ducking key: what the mix states take from the car (result state) counts – a car turned down does not duck the music."""
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("scripts/audio/modern/modern_mix.gd", [
    ('''##                 cruise_lufs rolling at pace_cruise × top speed, full_throttle_lufs under full load) – scripted
##                 and the same in every run. It is not metered from the car bus: the engine offers only peak
''', '''##                 cruise_lufs rolling at pace_cruise × top speed, full_throttle_lufs under full load), less what
##                 the mix states take from the car (car_path_db(): behind the finish line it is turned down and
##                 no longer ducks the music) – scripted and the same in every run. It is not metered from the
##                 car bus: the engine offers only peak
'''),
    ('''## Wanted ducking gain (<= 0 dB) for a loudness of the car (LUFS).
''', '''## What the mix states take from the car on its way out, in dB (<= 0): the scripted gains of the car's bus and of
## the environment path it runs through (state "result": the car is turned down).
func car_path_db() -> float:
	return gain_db("MCar") + gain_db("MEnv")


## Wanted ducking gain (<= 0 dB) for a loudness of the car (LUFS).
'''),
])

patch("scripts/audio/modern/modern_audio.gd", [
    ('''	var car := mix.car_lufs(f.alive, f.speed, f.vmax, float(f.engine.get("load", f.throttle)))
	if car_lufs_override > ModernMix.KEY_FLOOR_DB:
''', '''	var car := mix.car_lufs(f.alive, f.speed, f.vmax, float(f.engine.get("load", f.throttle)))
	if car > ModernMix.KEY_FLOOR_DB:
		car += mix.car_path_db()   # a car the mix has turned down (behind the finish line) does not duck the music
	if car_lufs_override > ModernMix.KEY_FLOOR_DB:
'''),
])

patch("tests/unit/audio_modern/test_modern_mix.gd", [
    ('''func test_duck_target_curve() -> void:
''', '''## A car the mix states have turned down counts with what is left of it.
func test_car_path_counts_the_mix_states() -> void:
	var mix := _mix()
	assert_near(mix.car_path_db(), 0.0, 1.0e-6, "ohne Zustand: nichts")
	mix.set_active("result", true)
	_run(mix, 6.0, ModernMix.KEY_FLOOR_DB)
	var dips: Dictionary = ConfigLoader.lookup(cfg(), "audio.modern.snapshots.result.gain_db", {})
	var want := float(dips.get("MCar", 0.0)) + float(dips.get("MEnv", 0.0))
	assert_true(want <= -6.0, "hinter der Ziellinie wird das Auto deutlich leiser gestellt (%.1f dB)" % want)
	assert_near(mix.car_path_db(), want, 0.05, "Zustand result: der Weg des Autos")
	# full throttle behind the finish line: what is left of the car no longer ducks the music
	var left := mix.car_lufs(true, 200.0, 250.0, 1.0) + mix.car_path_db()
	assert_near(mix.duck_target_db(left), 0.0, 1.0e-6, "kein Ducking für ein leise gestelltes Auto")


func test_duck_target_curve() -> void:
'''),
])

patch("tests/unit/audio_modern/test_modern_audio.gd", [
    ('''	# tests may give the loudness of the car directly
	m.car_lufs_override = -16.0
	_steps(m, 60)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.05, "vorgegebene Lautheit des Autos")
	_done(m)
''', '''	# tests may give the loudness of the car directly
	m.car_lufs_override = -16.0
	_steps(m, 60)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.05, "vorgegebene Lautheit des Autos")
	_done(m)


func test_no_ducking_for_a_car_the_mix_turned_down() -> void:
	var m := _modern()
	var depth := float(ConfigLoader.lookup(cfg(), "audio.modern.duck.depth_db", 0.0))
	m.set_vehicle("kompakt")
	_drive(m, 150, 150.0, 1.0)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.1, "Vollgas: Musik abgesenkt")
	# behind the finish line the state "result" turns the car down: still flat out, but the music comes back
	m.event("stage_finish", {"record": false, "last_stage": false})
	_drive(m, 240, 150.0, 1.0)
	assert_true(m.buses.gain_db("MCar") < -6.0, "Auto leise gestellt (%.1f dB)" % m.buses.gain_db("MCar"))
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.1, "ein leise gestelltes Auto senkt die Musik nicht ab")
	_done(m)
'''),
])

patch("docs/audio-modern.md", [
    ('''Motorlast aus `frame.engine.load`. Ohne fahrendes Auto (Menü, Pause, Sitzung weg) gibt es keine Absenkung.
''', '''Motorlast aus `frame.engine.load`. Was die Mischzustände dem Auto nehmen, wird abgezogen: Hinter der Ziellinie ist
das Auto 9 dB leiser gestellt und senkt die Musik nicht mehr ab. Ohne fahrendes Auto (Menü, Pause, Sitzung weg) gibt
es keine Absenkung.
'''),
])
print("ok")
