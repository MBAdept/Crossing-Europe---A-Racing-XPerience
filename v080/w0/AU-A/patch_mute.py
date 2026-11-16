R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("scripts/audio/modern/modern_audio.gd", [
    ('''	for bus_name in CliArgs.get_string("mute-bus", "").split(",", false):
		if ModernBuses.names().has(bus_name):
			buses.set_mute(bus_name, true)
''', '''	# debug: --mute-bus=MEnv,… (as for the Arcade buses) keeps these Modern buses muted
	var muted: Variant = opts.get("mute_buses", CliArgs.get_string("mute-bus", "").split(",", false))
	_debug_muted.clear()
	for bus_name: String in muted:
		if ModernBuses.names().has(bus_name):
			_debug_muted[bus_name] = true
'''),
    ('''var _sfx_volume := 1.0
var _music_volume := 0.7
''', '''var _sfx_volume := 1.0
var _music_volume := 0.7
var _debug_muted: Dictionary = {}   ## Modern buses muted by --mute-bus
'''),
    ('''	for bus: String in mix.levels:
		if bus == "MSfx":
			buses.set_static_db(bus, mix.static_db(bus), mix.static_mute(bus) or mix.effects_muted)
		else:
			buses.set_static_db(bus, mix.static_db(bus), mix.static_mute(bus))
''', '''	for bus: String in mix.levels:
		var mute := mix.static_mute(bus) or _debug_muted.has(bus) or (bus == "MSfx" and mix.effects_muted)
		buses.set_static_db(bus, mix.static_db(bus), mute)
	for bus: String in _debug_muted:
		buses.set_mute(bus, true)
'''),
    ('''	buses.set_mute("MSfx", mix.effects_muted)
''', '''	buses.set_mute("MSfx", mix.effects_muted or _debug_muted.has("MSfx"))
'''),
    ('''## (Callable id -> EngineBank), "live" (create players; default: not headless), "sync" (no mixer thread), "quiet"
## (no start line in the log).''', '''## (Callable id -> EngineBank), "live" (create players; default: not headless), "sync" (no mixer thread), "quiet"
## (no start line in the log), "mute_buses" (Modern bus names kept muted; default: --mute-bus).'''),
])

patch("tests/unit/audio_modern/test_modern_audio.gd", [
    ('''	m.apply_volumes(1.0, 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MMusic")), "Musik 0: stumm")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("MSfx")), "Effekte hörbar")
	_done(m)
''', '''	m.apply_volumes(1.0, 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MMusic")), "Musik 0: stumm")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("MSfx")), "Effekte hörbar")
	_done(m)
	# debug: --mute-bus names stay muted through every volume change and frame
	var d := _modern({}, {"mute_buses": ["MEnv", "MMusic", "Gibtsnicht"]})
	d.apply_volumes(1.0, 1.0)
	_steps(d, 3)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MEnv")), "--mute-bus=MEnv bleibt stumm")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MMusic")), "--mute-bus=MMusic bleibt stumm")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("MSfx")), "die anderen nicht")
	assert_false(d.frame.effects_muted, "ein stummer Teilbus gilt nicht als „Effekte aus“")
	_done(d)
'''),
])
print("ok")
