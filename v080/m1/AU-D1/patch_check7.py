import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = s[s.index("func _scenario_quit(race: bool) -> void:"):]
new = '''func _scenario_quit(race: bool) -> void:
	_am.call("set_profile", "modern")
	await _frames(2)
	if race:
		_am.call("set_music", false)
		_am.call("set_music_context", "race", {"stage_id": "x"})
		_am.call("event", "stage_start", {"countdown_s": 0.0})
	else:
		_am.call("set_music", true)
		_am.call("set_music_context", "title")
	var wall := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 1500:
		await process_frame
	var m := _modern()
	var st: Dictionary = (m.get("music") as Object).call("debug_state")
	var playing := bool(st.get("playing", false))
	# the profile ends while the music plays (what ModernAudio._exit_tree does when the game quits): every player of
	# the director stops and is freed at once; the engine frees a stopped playback on a later frame of the main thread,
	# so the game gets three frames before quit() – then nothing may be left ("leaked at exit" is checked by the
	# launcher). An immediate quit() leaves the engine no such frame, with either profile (docs/audio-modern.md).
	m.call("shutdown")
	var players := 0
	for c in m.get_children():
		if c is AudioStreamPlayer and not (c as AudioStreamPlayer).is_queued_for_deletion():
			players += 1
	await _frames(3)
	_check("quit_race" if race else "quit_menu", playing and players == 0,
		"Musik spielte (%s, %s); Profil beendet: %d Player übrig, drei Bilder später quit()" % [str(st.get("key", "")), str(st.get("race_phase", "")), players])
	quit(0 if _failed.is_empty() else 1)
'''
s = s.replace(old, new)
open(p, "w", encoding="utf-8").write(s)
print("ok")
