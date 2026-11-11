extends TestCase
## MusicDirector (contract D30, §4.7; docs/audio-modern.md "Musik"): the state machine of the music slot without a
## scene tree and without players – which piece each context plays, the race piece armed by the context, started by
## "stage_start" so that the count-in lands on "LOS!", the ending at the finish, restarts, the option "Musik im
## Rennen", the count-in pausing with the countdown, and the interactive stream it builds. Runs on the shipped
## manifest of assets/audio/modern/music (the remastered title theme and race piece 1).

const DT := 1.0 / 60.0


func _modern(over: Dictionary = {}) -> ModernAudio:
	var c := cfg().duplicate(true)
	(c["audio"]["modern"] as Dictionary).merge(over, true)
	var m := ModernAudio.new()
	m.clock_ms = 1000
	m.start(c, {"live": false, "quiet": true})
	return m


func _done(m: ModernAudio) -> void:
	m.shutdown()
	m.free()


func _steps(m: ModernAudio, n: int, paused: bool = false) -> void:
	for i in n:
		m.clock_ms += 17
		m.step(DT, paused)


func _drive(m: ModernAudio, n: int) -> void:
	for i in n:
		m.set_engine(120.0, 1.0, 230.0, true)
		m.clock_ms += 17
		m.step(DT, false)


func _st(m: ModernAudio) -> Dictionary:
	return m.music.debug_state()


func test_menu_contexts_play_the_title_remaster() -> void:
	var m := _modern()
	var title := m.assets.entry("music", "titel_remaster")
	assert_true(title != null, "das Titel-Remaster steht im Manifest")
	if title == null:
		_done(m)
		return
	assert_eq(title.role, "title", "Rolle title")
	m.set_music(true)
	_steps(m, 30)
	assert_eq(m.music.context, "menu", "set_music(true) = Menü")
	assert_eq(m.music.current_key(), "music/titel_remaster", "Menü: das Remaster, nicht die Titelmelodie von v0.7.0")
	assert_near(float(_st(m)["db"]), m.mix.music_context_db("menu") + title.gain_db, 1.0e-5, "Pegel: Kontext + gain_db")
	for c in ["title", "race_menu", "result", "menu"]:
		m.set_music_context(c)
		_steps(m, 3)
		assert_eq(m.music.current_key(), "music/titel_remaster", "%s: dasselbe Stück läuft weiter (kein Neustart)" % c)
	m.set_music_context("off")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "", "off: still")
	_done(m)


func test_race_piece_waits_for_the_stage_and_lands_on_go() -> void:
	var m := _modern()
	m.set_music(true)
	_steps(m, 10)
	m.set_music(false)
	m.set_music_context("race", {"stage_id": "kiel_hamburg"})
	_steps(m, 30)
	var st := _st(m)
	assert_eq(str(st["race_phase"]), MusicDirector.RACE_ARMED, "Kontext race: das Rennstück ist bereit, spielt aber nicht")
	assert_eq(m.music.current_key(), "", "bis zum Start der Etappe still (die Menümusik blendet aus)")
	assert_eq(str(st["race_piece"]), "linke_spur", "Rennstück 1")
	var countin: float = st["countin_s"]
	assert_near(countin, 4.0 * 60.0 / 132.0, 1.0e-6, "Einzähler: ein Takt bei 132 bpm")
	# the countdown starts: play() is scheduled so that the downbeat after the count-in lands on "LOS!"
	m.event("stage_start", {"countdown_s": 3.0})
	st = _st(m)
	assert_eq(str(st["race_phase"]), MusicDirector.RACE_WAITING, "Start geplant")
	assert_near(float(st["start_in"]), 3.0 - countin, 1.0e-6, "Start nach Countdown − Einzähler")
	var t := 0.0
	var started_at := -1.0
	while t < 3.0 - 0.5 * DT:
		_steps(m, 1)
		t += DT
		if started_at < 0.0 and m.music.current_key() != "":
			started_at = t
	assert_near(started_at, 3.0 - countin, DT * 1.01, "das Stück beginnt %.3f s nach dem Start der Etappe" % started_at)
	assert_true(m.music.current_key().begins_with("race/linke_spur#"), "Schlüssel des Rennstücks (%s)" % m.music.current_key())
	assert_near(float(_st(m)["level"]), 1.0, 1.0e-6, "der Einzähler beginnt ohne Einblenden")
	m.event("go", {})
	st = _st(m)
	assert_true(absf(float(st["go_offset_s"])) <= DT, "der Schlag nach dem Einzähler fällt auf „LOS!“ (Abstand %.4f s)" % float(st["go_offset_s"]))
	assert_near(float(st["db"]), m.mix.music_context_db("race") + m.assets.entry("music", "linke_spur").gain_db, 1.0e-5, "Pegel des Rennens")
	_done(m)


func test_countdown_numbers_reanchor_the_start() -> void:
	var m := _modern()
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 3.0})
	m.event("countdown", {"n": 3})
	var countin: float = _st(m)["countin_s"]
	assert_near(float(_st(m)["start_in"]), 3.0 - countin, 1.0e-6, "„3“: wie geplant")
	# the frames ran ahead of the countdown (a hitch the physics did not catch up): 0.5 s of frames, but the
	# countdown says "2" – the start follows the countdown, not the frames
	_steps(m, 30)
	assert_near(float(_st(m)["start_in"]), 3.0 - countin - 0.5, 1.0e-3, "nach 0,5 s Bildzeit")
	m.event("countdown", {"n": 2})
	assert_near(float(_st(m)["start_in"]), 2.0 - countin, 1.0e-6, "„2“: neu verankert, %.3f s vor dem Start" % (2.0 - countin))
	m.event("countdown", {"n": 1})
	assert_near(float(_st(m)["start_in"]), 2.0 - countin, 1.0e-6, "„1“ kommt nach dem Start des Einzählers: ändert nichts")
	_done(m)


func test_short_countdown_go_and_fallback_start() -> void:
	var m := _modern()
	# a countdown shorter than the count-in: the piece starts at once
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 1.0})
	assert_near(float(_st(m)["start_in"]), 0.0, 1.0e-9, "Countdown 1 s: sofort")
	_steps(m, 1)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_PLAYING, "spielt")
	# "go" without "stage_start": starts at "go"
	m.set_music_context("race")
	_steps(m, 5)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_ARMED, "neue Etappe: wieder bereit")
	m.event("go", {})
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_PLAYING, "„LOS!“ ohne stage_start startet das Stück")
	# no session events at all (a tool drives): the piece starts once the car has been driven a moment
	m.set_music_context("race")
	_drive(m, int(MusicDirector.START_FALLBACK_S / DT) - 3)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_ARMED, "noch nicht")
	_drive(m, 5)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_PLAYING, "nach %.1f s Fahrt ohne Ereignisse" % MusicDirector.START_FALLBACK_S)
	_done(m)


func test_finish_restart_and_leaving_the_race() -> void:
	var m := _modern()
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 0.0})
	_steps(m, 3)
	var key := m.music.current_key()
	assert_true(key.begins_with("race/"), "spielt (%s)" % key)
	m.event("stage_finish", {"record": false, "last_stage": false})
	_steps(m, 3)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_ENDING, "Ziel: der Schluss ist angefordert")
	assert_eq(m.music.current_key(), key, "dasselbe Stück spielt seinen Schluss (kein Ausblenden, kein neues Stück)")
	# the result screen: the race piece fades out, the menu piece follows
	m.set_music_context("result")
	_steps(m, 3)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_IDLE, "nach dem Rennen")
	assert_eq(m.music.current_key(), "music/titel_remaster", "Ergebnis: Titel-Remaster (es gibt noch kein eigenes Stück)")
	# a restart of the same stage is a new piece (from its count-in), even without a context in between
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 0.0})
	_steps(m, 2)
	var k1 := m.music.current_key()
	m.set_music(false)
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 0.0})
	_steps(m, 2)
	var k2 := m.music.current_key()
	assert_true(k1 != "" and k2 != "" and k1 != k2, "Neustart: neuer Schlüssel (%s -> %s)" % [k1, k2])
	assert_eq(int(_st(m)["race_index"]), 2, "drei Etappen mit Rennkontext gezählt")
	# the finish before the piece started: it stays silent
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 3.0})
	m.event("stage_finish", {"record": false, "last_stage": false})
	_steps(m, 200)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_OVER, "Ziel vor dem Start")
	assert_eq(m.music.current_key(), "", "bleibt still")
	_done(m)


func test_option_race_music_and_countin_pause() -> void:
	var m := _modern()
	m.set_race_music(false)
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 0.0})
	_steps(m, 5)
	assert_eq(m.music.current_key(), "", "„Musik im Rennen: Aus“: still")
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_PLAYING, "die Etappe läuft trotzdem mit")
	m.set_race_music(true)
	_steps(m, 2)
	assert_true(m.music.current_key().begins_with("race/"), "wieder an: das Stück spielt")
	# the tree is paused during the count-in: the stream pauses with the countdown, the clock stands still
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 3.0})
	_steps(m, int((3.0 - float(_st(m)["countin_s"])) / DT) + 6)
	var t0: float = _st(m)["race_t"]
	assert_true(t0 > 0.0 and t0 < float(_st(m)["countin_s"]), "im Einzähler (%.3f s)" % t0)
	_steps(m, 30, true)
	assert_true(bool(_st(m)["countdown_paused"]), "Pause im Einzähler: Stream angehalten")
	assert_near(float(_st(m)["race_t"]), t0, 1.0e-9, "die Uhr des Stücks steht")
	_steps(m, 1)
	assert_false(bool(_st(m)["countdown_paused"]), "weiter")
	# after "LOS!" a pause only filters the music (ModernMix), the stream runs on
	_steps(m, int(float(_st(m)["countin_s"]) / DT) + 5)
	_steps(m, 10, true)
	assert_false(bool(_st(m)["countdown_paused"]), "nach dem Einzähler hält die Pause den Stream nicht an")
	_done(m)


func test_race_stream_of_the_piece() -> void:
	var m := _modern()
	var piece := m.music.race_piece(0)
	assert_eq(str(piece.get("id", "")), "linke_spur", "Stück")
	var main: Variant = piece.get("main")
	var ending: Variant = piece.get("ending")
	assert_true(main is AudioStreamOggVorbis and ending is AudioStreamOggVorbis, "Hauptdatei und Schluss geladen")
	if main is AudioStreamOggVorbis and ending is AudioStreamOggVorbis:
		var mo := main as AudioStreamOggVorbis
		var e := m.assets.entry("music", "linke_spur")
		assert_true(mo.loop, "die Hauptdatei läuft in Schleife")
		assert_eq(int(mo.loop_offset * 44100.0), e.loop_begin, "loop_offset trifft den ersten Frame der Schleife")
		assert_near(mo.bpm, 132.0, 1.0e-9, "Tempo für den Taktwechsel")
		assert_eq(mo.bar_beats, 4, "4/4")
		assert_eq(mo.beat_count, 0, "kein beat_count (Godot zählt ihn vom Dateianfang)")
		assert_false((ending as AudioStreamOggVorbis).loop, "der Schluss spielt einmal")
		var s := MusicDirector.build_race_stream(mo, ending as AudioStream)
		assert_eq(s.clip_count, 2, "zwei Clips")
		assert_eq(s.get_clip_name(0), MusicDirector.MAIN_CLIP, "Clip 0")
		assert_eq(s.get_clip_name(1), MusicDirector.ENDING_CLIP, "Clip 1")
		assert_eq(s.initial_clip, 0, "beginnt mit dem Hauptclip")
		assert_eq(s.get_clip_auto_advance(0), AudioStreamInteractive.AUTO_ADVANCE_DISABLED, "kein Auto-Advance")
		assert_true(s.has_transition(0, 1), "Übergang zum Schluss")
		assert_eq(s.get_transition_from_time(0, 1), AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, "am nächsten Taktstrich")
		assert_eq(s.get_transition_to_time(0, 1), AudioStreamInteractive.TRANSITION_TO_TIME_START, "vom Anfang des Schlusses")
		assert_eq(s.get_transition_fade_mode(0, 1), AudioStreamInteractive.FADE_DISABLED,
			"die Schleife endet am Taktstrich (1 ms), der Schluss setzt voll ein – kein doppelter Schlag")
		assert_true(m.music.race_stream(piece) == m.music.race_stream(piece), "ein Stream je Stück (zwischengespeichert)")
	_done(m)


func test_placeholders_never_replace_a_real_piece() -> void:
	var m := _modern({"placeholders": true})
	for i in 4:
		assert_eq(str(m.music.race_piece(i).get("id", "")), "linke_spur", "Etappe %d: das echte Rennstück, nie der Platzhalter" % i)
	_done(m)
