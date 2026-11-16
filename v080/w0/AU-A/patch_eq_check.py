"""Live check: measure the race EQ of the music (shelves) with tones."""
R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"


def patch(path, pairs):
    s = open(R + path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, s.count(old), old)
        s = s.replace(old, new)
    open(R + path, "w", encoding="utf-8").write(s)


patch("tests/unit/audio_modern/check_modern_audio.gd", [
    ('''	var pause_ok := open - closed >= 12.0 and absf(reopened - open) < 0.6 and lp < 2000.0
	p.stop()
	p.queue_free()
''', '''	var pause_ok := open - closed >= 12.0 and absf(reopened - open) < 0.6 and lp < 2000.0
	# 4. race EQ of the music: in the context "race" (no race music plays here) tones at 62 Hz / 500 Hz / 5 kHz leave
	#    the bus about 1 / 3 / 0 dB lower than outside a race; neutral again afterwards
	_am.call("set_race_music", false)
	var eq_drop: Array[float] = []
	for hz: float in [62.0, 500.0, 5000.0]:
		p.stream = _tone(hz, 0.5, 0.1)
		p.play()
		_am.call("set_music_context", "off", {})
		await _wait(0.7)
		var flat: float = await _level(music_cap, 0.3)
		_am.call("set_music_context", "race", {})
		await _wait(0.7)
		var shaped: float = await _level(music_cap, 0.3)
		eq_drop.append(flat - shaped)
	_am.call("set_music_context", "off", {})
	_am.call("set_race_music", true)
	await _wait(0.7)
	var eq_ok := absf(eq_drop[0] - 1.0) < 0.4 and absf(eq_drop[1] - 3.0) < 0.4 and absf(eq_drop[2]) < 0.3 and not buses.music_eq_on()
	p.stop()
	p.queue_free()
'''),
    ('''	_check("mix", chain_ok and duck_ok and pause_ok, "Pegelkette: Ton über MUI %.2f dB (Plan %.2f), über MMusic %.2f dB (Plan %.2f); Ducking: Musik %.2f → %.2f dB bei Vollgas (−%.1f dB, Zustand %.1f dB), danach %.2f dB; Pause: 5-kHz-Ton %.1f → %.1f dB (Tiefpass %.0f Hz), danach %.1f dB" % [
		ui_db, want_ui, music_db, want_music, before, ducked, before - ducked, duck_state, after, open, closed, lp, reopened])''',
     '''	_check("mix", chain_ok and duck_ok and pause_ok and eq_ok, "Pegelkette: Ton über MUI %.2f dB (Plan %.2f), über MMusic %.2f dB (Plan %.2f); Ducking: Musik %.2f → %.2f dB bei Vollgas (−%.1f dB, Zustand %.1f dB), danach %.2f dB; Pause: 5-kHz-Ton %.1f → %.1f dB (Tiefpass %.0f Hz), danach %.1f dB; Renn-EQ der Musik: 62 Hz −%.2f dB, 500 Hz −%.2f dB, 5 kHz −%.2f dB" % [
		ui_db, want_ui, music_db, want_music, before, ducked, before - ducked, duck_state, after, open, closed, lp, reopened,
		eq_drop[0], eq_drop[1], eq_drop[2]])'''),
    ('''##                  while the car is driven flat out and comes back, the pause low-pass closes and opens''',
     '''##                  while the car is driven flat out and comes back, the pause low-pass closes and opens, the race
##                  EQ of the music takes about 1 / 3 / 0 dB at 62 Hz / 500 Hz / 5 kHz'''),
])
print("ok")
