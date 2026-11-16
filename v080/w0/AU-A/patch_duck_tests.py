R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("tests/unit/audio_modern/test_modern_mix.gd", [
    ('''func _run(mix: ModernMix, seconds: float, key_db: float, mute: bool = false, tail_db: float = -200.0) -> void:
	var n := int(round(seconds / DT))
	for i in n:
		mix.step(DT, key_db, mute, tail_db)
''', '''## Steps the mix for a while with a loudness of the car (LUFS).
func _run(mix: ModernMix, seconds: float, car_lufs: float, mute: bool = false, tail_db: float = -200.0) -> void:
	var n := int(round(seconds / DT))
	for i in n:
		mix.step(DT, car_lufs, mute, tail_db)
'''),
    ('''func test_duck_target_curve() -> void:
	var mix := _mix({"duck": {"from_db": -24.0, "to_db": -10.0, "depth_db": 4.5}})
''', '''## The key of the ducking: the loudness the plan gives the car in its driving state.
func test_car_loudness_after_the_plan() -> void:
	var mix := _mix({"loudness": {"idle_lufs": -24.0, "cruise_lufs": -21.0, "full_throttle_lufs": -16.0}, "duck": {"pace_cruise": 0.5}})
	assert_near(mix.car_lufs(true, 0.0, 250.0, 0.0), -24.0, 1.0e-6, "im Stand: Leerlauf")
	assert_near(mix.car_lufs(true, 125.0, 250.0, 0.0), -21.0, 1.0e-6, "rollt mit halbem Höchsttempo: Reisetempo")
	assert_near(mix.car_lufs(true, 250.0, 250.0, 0.0), -21.0, 1.0e-6, "schneller rollen macht den Plan nicht lauter")
	assert_near(mix.car_lufs(true, 62.5, 250.0, 0.0), -22.5, 1.0e-6, "dazwischen linear")
	assert_near(mix.car_lufs(true, 0.0, 250.0, 1.0), -16.0, 1.0e-6, "Vollgas im Stand")
	assert_near(mix.car_lufs(true, 200.0, 250.0, 1.0), -16.0, 1.0e-6, "Vollgas in Fahrt")
	assert_near(mix.car_lufs(true, 125.0, 250.0, 0.2), -20.0, 1.0e-6, "Reisetempo mit etwas Last")
	assert_near(mix.car_lufs(true, 125.0, 250.0, 7.0), -16.0, 1.0e-6, "Last begrenzt")
	assert_near(mix.car_lufs(false, 200.0, 250.0, 1.0), ModernMix.KEY_FLOOR_DB, 1.0e-6, "niemand fährt: still")
	# with the shipped thresholds: nothing at idle, about half at cruise, the full depth at full throttle
	var plan := _mix()
	assert_near(plan.duck_target_db(plan.car_lufs(true, 0.0, 250.0, 0.0)), 0.0, 1.0e-6, "Leerlauf: Musik oben")
	assert_near(plan.duck_target_db(plan.car_lufs(true, 250.0, 250.0, 1.0)), -plan.duck_depth_db, 1.0e-6, "Vollgas: volle Tiefe")
	assert_between(plan.duck_target_db(plan.car_lufs(true, 140.0, 250.0, 0.2)), -0.75 * plan.duck_depth_db, -0.25 * plan.duck_depth_db, "Reisetempo: teilweise")
	assert_near(plan.duck_target_db(plan.car_lufs(false, 250.0, 250.0, 1.0)), 0.0, 1.0e-6, "ohne Auto keine Absenkung")


func test_duck_target_curve() -> void:
	var mix := _mix({"duck": {"from_lufs": -24.0, "to_lufs": -10.0, "depth_db": 4.5}})
'''),
    ('''	var mix := _mix({"duck": {"from_db": -24.0, "to_db": -10.0, "depth_db": 4.0, "attack_s": 0.05, "release_s": 0.45}, "snapshots": {}})''',
     '''	var mix := _mix({"duck": {"from_lufs": -24.0, "to_lufs": -10.0, "depth_db": 4.0, "attack_s": 0.05, "release_s": 0.45}, "snapshots": {}})'''),
    ('''	assert_eq(mix.duck_key, "MCar", "gesteuert vom Auto-Bus")
	assert_eq(mix.duck_bus, "MMusic", "wirkt auf die Musik")''', '''	assert_eq(mix.duck_bus, "MMusic", "wirkt auf die Musik")
	assert_true(mix.duck_from_lufs > float(mix.loudness["idle_lufs"]), "im Leerlauf keine Absenkung")
	assert_true(mix.duck_to_lufs <= float(mix.loudness["full_throttle_lufs"]), "bei Vollgas die volle Tiefe")'''),
])

patch("tests/unit/audio_modern/test_modern_audio.gd", [
    ('''func test_ducking_uses_the_level_of_the_car_bus() -> void:
	var m := _modern()
	assert_eq(m.mix.duck_key, "MCar", "Schlüsselbus")
	m.key_db_override = -6.0   # a loud car (the meter itself needs a running AudioServer: check_modern_audio.gd)
	_steps(m, 60)
	var depth := float(ConfigLoader.lookup(cfg(), "audio.modern.duck.depth_db", 0.0))
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.05, "Musik um die volle Tiefe abgesenkt")
	assert_true(depth >= 3.0, "mindestens 3 dB")
	m.key_db_override = -60.0
	_steps(m, 240)
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.02, "und wieder zurück")
	_done(m)
''', '''func test_ducking_follows_the_car() -> void:
	var m := _modern()
	var depth := float(ConfigLoader.lookup(cfg(), "audio.modern.duck.depth_db", 0.0))
	assert_true(depth >= 3.0, "mindestens 3 dB")
	m.set_vehicle("kompakt")
	_drive(m, 90, 0.0, 0.0)
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.02, "im Leerlauf bleibt die Musik oben")
	assert_near(m.mix.car, float(m.mix.loudness["idle_lufs"]), 0.5, "Auto nach Plan im Leerlauf")
	_drive(m, 150, 150.0, 1.0)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.1, "Vollgas: Musik um die volle Tiefe abgesenkt")
	assert_near(m.mix.car, float(m.mix.loudness["full_throttle_lufs"]), 0.5, "Auto nach Plan bei Vollgas")
	# the session leaves (stop calling): the music comes back within about two seconds
	_steps(m, 150)
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.05, "und wieder zurück")
	# tests may give the loudness of the car directly
	m.car_lufs_override = -16.0
	_steps(m, 60)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.05, "vorgegebene Lautheit des Autos")
	_done(m)
'''),
    ('''	var msfx := AudioServer.get_bus_index("MSfx")
	m.key_db_override = -6.0
''', '''	var msfx := AudioServer.get_bus_index("MSfx")
	m.car_lufs_override = -16.0
'''),
])

patch("tests/unit/audio_modern/check_modern_audio.gd", [
    ('''	# 2. ducking: the music (still playing) under a loud tone on the car bus, then released
	var before: float = await _level(music_cap, 0.3)
	var car := _player("MRoad", _tone(180.0, 0.5, 0.6))
	await _wait(0.5)
	var ducked: float = await _level(music_cap, 0.3)
	var duck_state := float(((m.call("debug_state") as Dictionary)["mix"] as Dictionary)["duck_db"])
	car.stop()
	await _wait(1.8)
	var after: float = await _level(music_cap, 0.3)
	car.queue_free()
	var duck_ok := before - ducked >= 3.0 and absf(after - before) < 0.5 and duck_state <= -3.0
''', '''	# 2. ducking: the music (still playing) while the car is driven flat out, then after the session stopped calling
	var before: float = await _level(music_cap, 0.3)
	_am.call("set_vehicle", "limousine")
	var until := Time.get_ticks_msec() + 800
	var ducked := 0.0
	while Time.get_ticks_msec() < until + 300:
		_am.call("set_engine", 200.0, 1.0, 245.0, true)
		if Time.get_ticks_msec() >= until and ducked == 0.0:
			music_cap.clear_buffer()
			ducked = -1.0
		await process_frame
	var fr := music_cap.get_buffer(music_cap.get_frames_available())
	var sq := 0.0
	for v in fr:
		sq += v.x * v.x + v.y * v.y
	ducked = 10.0 * log(maxf(sq / (2.0 * maxf(fr.size(), 1.0)), 1.0e-20)) / log(10.0)
	var duck_state := float(((m.call("debug_state") as Dictionary)["mix"] as Dictionary)["duck_db"])
	_am.call("stop_all")
	await _wait(1.8)
	var after: float = await _level(music_cap, 0.3)
	var duck_ok := before - ducked >= 3.0 and absf(after - before) < 0.5 and duck_state <= -3.0
'''),
    ('''Ducking: Musik %.2f → %.2f dB unter lautem Auto-Bus (−%.1f dB, Zustand %.1f dB), danach %.2f dB;''',
     '''Ducking: Musik %.2f → %.2f dB bei Vollgas (−%.1f dB, Zustand %.1f dB), danach %.2f dB;'''),
    ('''##   mix            (--live) a tone through the Modern buses, captured: the level chain of the plan, the music ducks
##                  under a loud car bus and comes back, the pause low-pass closes and opens''',
     '''##   mix            (--live) a tone through the Modern buses, captured: the level chain of the plan, the music ducks
##                  while the car is driven flat out and comes back, the pause low-pass closes and opens'''),
])

patch("tools/audio/modern/capture_mix.gd", [
    ('''var _key_sum := 0.0              # Modern: power of the ducking key level (car bus) over the running phase
var _key_n := 0
var _peak := -200.0              # Modern: highest block peak of the car bus in the running phase
var _duck_sum := 0.0
''', '''var _key_sum := 0.0              # Modern: the car's loudness after the plan (ducking key) over the running phase
var _key_n := 0
var _peak := -200.0              # Modern: highest block peak of the car bus in the running phase
var _duck_sum := 0.0
'''),
    ('''	if _key_n > 0:
		p["car_bus_rms_db"] = snappedf(10.0 * log(maxf(_key_sum / _key_n, 1.0e-20)) / log(10.0), 0.01)
		p["car_bus_peak_db"] = snappedf(_peak, 0.01)
		p["duck_db"] = snappedf(_duck_sum / _key_n, 0.01)
''', '''	if _key_n > 0:
		p["car_plan_lufs"] = snappedf(_key_sum / _key_n, 0.01)
		p["car_bus_peak_db"] = snappedf(_peak, 0.01)
		p["duck_db"] = snappedf(_duck_sum / _key_n, 0.01)
'''),
    ('''	if mo.mix.key_db > -150.0:
		_key_sum += pow(10.0, mo.mix.key_db / 10.0)
		_key_n += 1
		_duck_sum += mo.mix.duck_db
''', '''	if mo.mix.car > -150.0:
		_key_sum += mo.mix.car
		_key_n += 1
		_duck_sum += mo.mix.duck_db
'''),
    ('''## each phase also has what the mix saw of the car bus: car_bus_rms_db (the ducking key), car_bus_peak_db, duck_db.''',
     '''## each phase also has car_plan_lufs (the car's loudness after the plan, the key of the ducking), duck_db (the
## ducking of the music) and car_bus_peak_db (the highest block peak of the car bus).'''),
])
print("ok")
