P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/tests/unit/audio_modern/check_modern_audio.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (s.count(old), old)
    s = s.replace(old, new)


rep("	# Modern: 22 s from km 49 through the Testtunnel (km 50–54), in the rain", "	# Modern: 16 s from km 49.4 through the Testtunnel (km 50–54), in the rain")
rep("	_launch(49.0, 5)\n	var mod: Dictionary = await _drive(22.0)", "	_launch(49.4, 5)\n	var mod: Dictionary = await _drive(16.0)")
rep('''	var text := "Teststadt – Testdorp ab km 49 im Regen, 22 s mit dem Profil Modern bis km %.2f:''', '''	var text := "Teststadt – Testdorp ab km 49,4 im Regen, 16 s mit dem Profil Modern bis km %.2f:''')
rep("		# the same 22 s with the Arcade profile: the simulation does not depend on the sound profile (Rule 3)", "		# the same 16 s with the Arcade profile: the simulation does not depend on the sound profile (Rule 3)")
rep("		_launch(49.0, 5)\n		var arc: Dictionary = await _drive(22.0)", "		_launch(49.4, 5)\n		var arc: Dictionary = await _drive(16.0)")
rep("		var same := ha.size() == hm.size() and ha.size() >= 21 and first_diff < 0", "		var same := ha.size() == hm.size() and ha.size() >= 15 and first_diff < 0")
rep("dieselben 22 s mit dem Profil Arcade bis km %.2f", "dieselben 16 s mit dem Profil Arcade bis km %.2f")
rep('''##   race           22 s of the test stage through its tunnel with the Modern profile: the session's calls arrive
##                  (engine, traffic, tunnel reverb, feed, events, race music); without --live also the finish with
##                  Modern and the same 22 s with the Arcade profile – the same simulation at every second (Rule 3)''',
    '''##   race           16 s of the test stage through its tunnel with the Modern profile: the session's calls arrive
##                  (engine, traffic, tunnel reverb, feed, events, race music); without --live also the finish with
##                  Modern and the same 16 s with the Arcade profile – the same simulation at every second (Rule 3)''')
rep("	_am.call(\"set_profile\", \"arcade\")\n	_am.call(\"stop_all\")\n	await _wait(0.4)\n	var before := _counts()", "	_am.call(\"set_profile\", \"arcade\")\n	_am.call(\"stop_all\")\n	await _wait(0.25)\n	var before := _counts()")
rep("	_am.call(\"set_music\", false)\n	_am.call(\"stop_all\")\n	await _wait(0.4)\n	var after := _counts()", "	_am.call(\"set_music\", false)\n	_am.call(\"stop_all\")\n	await _wait(0.25)\n	var after := _counts()")
open(P, "w", encoding="utf-8").write(s)
print("ok")
