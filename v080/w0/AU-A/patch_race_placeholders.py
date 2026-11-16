"""check race: the placeholders are on for the race in both variants (acceptance: a headless race with Modern and placeholders)."""
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("tests/unit/audio_modern/check_modern_audio.gd", [
    ('''	# Modern: 16 s from km 49.4 through the Testtunnel (km 50–54), in the rain
	_am.call("set_profile", "modern")
''', '''	# Modern with the placeholder sounds (also in the plain headless run, where the other scenarios use the shipped
	# setting without them): 16 s from km 49.4 through the Testtunnel (km 50–54), in the rain
	var modern_cfg: Dictionary = (_am.get("_audio_cfg") as Dictionary)["audio"]["modern"]
	var placeholders_before := bool(modern_cfg.get("placeholders", false))
	modern_cfg["placeholders"] = true
	_am.call("set_profile", "modern")
'''),
    ('''	var music_ok := str(music["context"]) == "race" and ((str(music["key"]) == "music/platzhalter_takt") == _live)
''', '''	var music_ok := str(music["context"]) == "race" and str(music["key"]) == "music/platzhalter_takt" and bool(st["placeholders"])
'''),
    ('''	var text := "Teststadt – Testdorp ab km 49,4 im Regen, 16 s mit dem Profil Modern bis km %.2f: Motor bis''',
     '''	var text := "Teststadt – Testdorp ab km 49,4 im Regen, 16 s mit dem Profil Modern und Platzhaltern bis km %.2f: Motor bis'''),
    ('''	Engine.max_physics_steps_per_frame = 8
	_am.call("set_profile", "arcade")
	_check("race", ok, text''', '''	Engine.max_physics_steps_per_frame = 8
	_am.call("set_profile", "arcade")
	modern_cfg["placeholders"] = placeholders_before
	_check("race", ok, text'''),
    ('''##   race           16 s of the test stage through its tunnel with the Modern profile: the session's calls arrive
##                  (engine, traffic, tunnel reverb, feed, events, race music); without --live also the finish with
##                  Modern and the same 16 s with the Arcade profile – the same simulation at every second (Rule 3)''',
     '''##   race           16 s of the test stage through its tunnel with the Modern profile and the placeholder sounds:
##                  the session's calls arrive (engine, traffic, tunnel reverb, feed, events, race music); without
##                  --live also the finish with Modern and the same 16 s with the Arcade profile – the same
##                  simulation at every second (Rule 3)'''),
    ('''## --live: plays although the run is headless – builds the Arcade sounds as on a display (the AudioManager's own
## functions), ModernAudio.force_live, and switches the placeholders on (audio.modern.placeholders).''',
     '''## --live: plays although the run is headless – builds the Arcade sounds as on a display (the AudioManager's own
## functions), ModernAudio.force_live, and switches the placeholders on for every scenario
## (audio.modern.placeholders; without --live only the race uses them).'''),
])
print("ok")
