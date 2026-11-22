extends TestCase
## MusicDirector (contract D30, §4.7; docs/audio-modern.md "Musik"): the state machine of the music slot without a
## scene tree and without players – which piece each context plays, the race piece armed by the context, started by
## "stage_start" so that the count-in lands on "LOS!", the ending at the finish (and its variants), restarts, the option
## "Musik im Rennen", the count-in pausing with the countdown, the rotation of the race pieces, the interlude between
## the stages, the stingers and the interactive stream it builds. Runs on the shipped manifest of
## assets/audio/modern/music (title remaster, three race pieces with their endings and stingers, interlude).

const DT := 1.0 / 60.0
const PIECES: Array[String] = ["linke_spur", "nachtfahrt", "rueckenwind"]


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


## A stage with its piece playing right away (countdown 0); returns the piece id.
func _race(m: ModernAudio) -> String:
	m.set_music(false)
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 0.0})
	_steps(m, 2)
	return str(_st(m)["race_piece"])


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
	m.set_music_context("title")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "music/titel_remaster", "title: dasselbe Stück läuft weiter (kein Neustart)")
	m.set_music_context("off")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "", "off: still")
	_done(m)


func test_interlude_between_the_stages() -> void:
	var m := _modern()
	var z := m.assets.entry("music", "zwischenspiel")
	assert_true(z != null and z.role == "interlude", "das Zwischenspiel steht im Manifest (Rolle interlude)")
	if z == null:
		_done(m)
		return
	assert_true(z.loops() and z.loop_end == z.frames, "Schleife bis zum Dateiende")
	assert_between(float(z.loop_end - z.loop_begin) / 44100.0, 60.0, 90.0, "Schleife 60–90 s (%.1f s)" % (float(z.loop_end - z.loop_begin) / 44100.0))
	m.set_music(true)
	_steps(m, 10)
	assert_eq(m.music.current_key(), "music/titel_remaster", "Menü: Titel")
	# the stage screen: the interlude fades in, the title out
	m.set_music_context("race_menu")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "music/zwischenspiel", "race_menu: das Zwischenspiel")
	assert_near(float(_st(m)["db"]), m.mix.music_context_db("race_menu") + z.gain_db, 1.0e-5, "Pegel des Zwischenspiels")
	# the result screen has no piece of its own: the interlude, and on to the stage screen without a restart
	m.set_music_context("result")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "music/zwischenspiel", "result: das Zwischenspiel läuft weiter")
	m.set_music_context("race_menu")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "music/zwischenspiel", "zurück zum Etappenbildschirm: kein Neustart")
	m.set_music_context("title")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "music/titel_remaster", "Titel: wieder das Remaster")
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
	assert_eq(str(st["race_piece"]), "linke_spur", "die erste Etappe: Rennstück 1")
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


func test_rotation_of_the_race_pieces() -> void:
	var m := _modern()
	assert_eq(m.music.race_ids(), PIECES, "drei Rennstücke in der Reihenfolge ihrer Rotation")
	var keys: Array[String] = []
	var bpm := {"linke_spur": 132.0, "nachtfahrt": 105.0, "rueckenwind": 150.0}
	for i in 4:
		var id := _race(m)
		assert_eq(id, PIECES[i % 3], "Etappe %d: %s" % [i + 1, PIECES[i % 3]])
		var p := m.music.race_piece(i)
		assert_near(float(p["countin_s"]), 4.0 * 60.0 / float(bpm[id]), 1.0e-6, "%s: Einzähler ein Takt" % id)
		assert_true(p["main"] is AudioStreamOggVorbis and p["ending"] is AudioStreamOggVorbis, "%s: Hauptdatei und Schluss" % id)
		assert_eq((p["variants"] as Dictionary).keys().size(), 2, "%s: Schluss „rekord“ und „finale“" % id)
		assert_true(str(p["ziel"]) != "", "%s: Schlag an der Ziellinie" % id)
		assert_eq((p["stingers"] as Dictionary).keys().size(), 2, "%s: Stinger busted und out_of_fuel" % id)
		keys.append(m.music.current_key())
	assert_true(keys[0] != keys[3] and keys[0].get_slice("#", 0) == keys[3].get_slice("#", 0), "die vierte Etappe: wieder Stück 1, neuer Schlüssel")
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
	var st := _st(m)
	assert_eq(str(st["race_phase"]), MusicDirector.RACE_ENDING, "Ziel: der Schluss ist angefordert")
	assert_eq(str(st["ending_variant"]), "normal", "der normale Schluss")
	assert_eq(m.music.current_key(), key, "dasselbe Stück spielt seinen Schluss (kein Ausblenden, kein neues Stück)")
	var hold := float(st["hold_left"])
	assert_between(hold, 2.0, MusicDirector.HOLD_MAX_S, "der Schluss klingt aus, bevor die Menümusik kommt (%.2f s)" % hold)
	# the result screen: the ending rings out first, then the interlude
	m.set_music_context("result")
	_steps(m, 3)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_IDLE, "nach dem Rennen")
	assert_eq(m.music.current_key(), key, "Ergebnis: der Schluss klingt noch")
	_steps(m, int(hold / DT) + 4)
	assert_eq(m.music.current_key(), "music/zwischenspiel", "danach das Zwischenspiel")
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
	# the finish before the piece started: no race piece, the ending sounds as the finish sound of the stage
	m.set_music_context("race")
	m.event("stage_start", {"countdown_s": 3.0})
	var piece := str(_st(m)["race_piece"])
	m.event("stage_finish", {"record": false, "last_stage": false})
	_steps(m, 200)
	assert_eq(str(_st(m)["race_phase"]), MusicDirector.RACE_OVER, "Ziel vor dem Start")
	assert_eq(m.music.current_key(), "", "das Rennstück bleibt still")
	assert_eq(str(_st(m)["last_sting"]), piece + "_schluss", "der Schluss als Zielklang")
	_done(m)


func test_ending_variants_and_the_stab_at_the_finish_line() -> void:
	var m := _modern()
	assert_eq(Array(m.music.claims()), ["stage_finish"], "das Ziel gehört der Musik (kein Arcade-Zieljingle dazu)")
	# the AudioManager's "finish" one-shot of the same moment is dropped (ModernAudio.PLAY_EVENTS)
	_race(m)
	m.play("finish")
	m.event("stage_finish", {"record": true, "last_stage": false})
	assert_eq(int(m.dropped.get("finish", 0)), 1, "der Zieljingle fällt weg")
	assert_eq(str(_st(m)["ending_variant"]), "rekord", "neuer Rekord: Schluss „rekord“")
	_race(m)
	m.event("stage_finish", {"record": true, "last_stage": true})
	assert_eq(str(_st(m)["ending_variant"]), "finale", "letzte Etappe: Schluss „finale“ (auch bei Rekord)")
	# the stab: only when the bar line of the ending is further than ZIEL_MIN_S away
	var id := _race(m)
	var bar := float(m.music.race_piece(int(_st(m)["race_index"]))["bar_s"])
	var far := int((0.25 * bar) / DT)
	_steps(m, far)
	var to_bar := m.music.time_to_bar()
	assert_true(to_bar > MusicDirector.ZIEL_MIN_S, "Taktstrich in %.2f s" % to_bar)
	m.event("stage_finish", {"record": false, "last_stage": false})
	assert_eq(str(_st(m)["sting_waiting"]), id + "_ziel", "der Schlag kommt sofort")
	_steps(m, 1)
	assert_eq(str(_st(m)["last_sting"]), id + "_ziel", "gespielt")
	_steps(m, 4)
	assert_near(float(_st(m)["duck_db"]), m.music.sting_duck_db, 0.05, "die Schleife darunter abgesenkt")
	_steps(m, int(to_bar / DT) + 2)
	assert_near(float(_st(m)["duck_db"]), 0.0, 0.05, "am Taktstrich des Schlusses wieder voll")
	# close to the bar line: no stab (the ending's downbeat is the reaction)
	id = _race(m)
	bar = float(m.music.race_piece(int(_st(m)["race_index"]))["bar_s"])
	_steps(m, int((bar - 0.15) / DT) - 2)
	assert_true(m.music.time_to_bar() < MusicDirector.ZIEL_MIN_S, "Taktstrich in %.2f s" % m.music.time_to_bar())
	m.event("stage_finish", {"record": false, "last_stage": false})
	assert_eq(str(_st(m)["sting_waiting"]), "", "kein Schlag so kurz vor dem Schluss")
	_done(m)


func test_stingers_on_the_beat_over_the_ducked_piece() -> void:
	var m := _modern()
	var id := _race(m)
	var p := m.music.race_piece(int(_st(m)["race_index"]))
	var beat := float(p["bar_s"]) / 4.0
	_steps(m, 20)
	var to_beat := m.music.time_to_beat()
	m.event("busted", {})
	assert_eq(str(_st(m)["sting_waiting"]), id + "_polizei", "Erwischt: der Stinger des Stücks wartet auf den Schlag")
	var waited := 0
	while str(_st(m)["last_sting"]) != id + "_polizei" and waited < 120:
		_steps(m, 1)
		waited += 1
	assert_near(waited * DT, to_beat, DT * 1.5, "auf dem nächsten Schlag (nach %.3f s, Schlag in %.3f s)" % [waited * DT, to_beat])
	_steps(m, 5)
	assert_near(float(_st(m)["duck_db"]), m.music.sting_duck_db, 0.05, "das Rennstück ist abgesenkt (%.1f dB)" % float(_st(m)["duck_db"]))
	var e := m.assets.entry("music", id + "_polizei")
	var hold := float(e.meta.get("bars", 1)) * float(p["bar_s"])
	_steps(m, int((hold + m.music.sting_release_s) / DT) + 4)
	assert_near(float(_st(m)["duck_db"]), 0.0, 0.05, "und kommt zurück")
	m.event("out_of_fuel", {})
	_steps(m, int(beat / DT) + 2)
	assert_eq(str(_st(m)["last_sting"]), id + "_tank", "Tank leer: sein Stinger")
	assert_eq(int((_st(m)["stingers_played"] as Dictionary).get(id + "_tank", 0)), 1, "einmal")
	# "Musik im Rennen: Aus": no stingers (they are music)
	m.set_race_music(false)
	_steps(m, 2)
	m.event("busted", {})
	_steps(m, 60)
	assert_eq(int((_st(m)["stingers_played"] as Dictionary).get(id + "_polizei", 0)), 1, "ohne Rennmusik kein Stinger")
	# after the finish: no stingers either
	m.set_race_music(true)
	_steps(m, 2)
	m.event("stage_finish", {"record": false, "last_stage": false})
	m.event("out_of_fuel", {})
	_steps(m, 60)
	assert_eq(int((_st(m)["stingers_played"] as Dictionary).get(id + "_tank", 0)), 1, "nach dem Ziel kein Stinger")
	_done(m)


func test_finish_without_race_music() -> void:
	var m := _modern()
	m.set_race_music(false)
	var id := _race(m)
	assert_eq(m.music.current_key(), "", "„Musik im Rennen: Aus“: still")
	m.event("stage_finish", {"record": true, "last_stage": false})
	_steps(m, 2)
	assert_eq(str(_st(m)["last_sting"]), id + "_schluss_rekord", "der Schluss „rekord“ ist der Zielklang")
	var hold := float(_st(m)["hold_left"])
	assert_true(hold > 1.0, "er klingt aus (%.2f s)" % hold)
	m.set_music_context("result")
	_steps(m, 3)
	assert_eq(m.music.current_key(), "", "die Menümusik wartet")
	_steps(m, int(hold / DT) + 2)
	assert_eq(m.music.current_key(), "music/zwischenspiel", "dann das Zwischenspiel")
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
	# after "LOS!" a pause only filters the music (ModernMix), the stream runs on – and so does its bar clock
	_steps(m, int(float(_st(m)["countin_s"]) / DT) + 5)
	var mt: float = _st(m)["music_t"]
	_steps(m, 10, true)
	assert_false(bool(_st(m)["countdown_paused"]), "nach dem Einzähler hält die Pause den Stream nicht an")
	assert_near(float(_st(m)["music_t"]), mt + 10 * DT, 1.0e-6, "die Taktuhr des Stücks läuft in der Pause weiter")
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
		# the variants: two more clips, the same transition
		var full := m.music.race_stream(piece) as AudioStreamInteractive
		assert_eq(full.clip_count, 4, "vier Clips: Lauf, Schluss, Rekord, Finale")
		for i in [2, 3]:
			assert_true(full.has_transition(0, i), "Übergang zu Clip %d" % i)
			assert_eq(full.get_transition_from_time(0, i), AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, "Clip %d am Taktstrich" % i)
			assert_eq(full.get_transition_fade_mode(0, i), AudioStreamInteractive.FADE_DISABLED, "Clip %d ohne Überblenden" % i)
			assert_false((full.get_clip_stream(i) as AudioStreamOggVorbis).loop, "Clip %d spielt einmal" % i)
		assert_eq(full.get_clip_name(2), MusicDirector.VARIANT_CLIPS["rekord"], "Clip 2: Rekord")
		assert_eq(full.get_clip_name(3), MusicDirector.VARIANT_CLIPS["finale"], "Clip 3: Finale")
		assert_true(m.music.race_stream(piece) == m.music.race_stream(piece), "ein Stream je Stück (zwischengespeichert)")
	# every race piece: its main file loops from the first frame of its body, the clips have the piece's tempo
	for id in PIECES:
		var e := m.assets.entry("music", id)
		var s := m.assets.stream("music", id) as AudioStreamOggVorbis
		assert_true(s != null and s.loop and int(s.loop_offset * 44100.0) == e.loop_begin, "%s: Schleife ab Frame %d" % [id, e.loop_begin])
		assert_near(float(e.loop_end - e.loop_begin) / 44100.0, float(e.meta["loop_bars"]) * 240.0 / e.bpm, 1.0e-6,
			"%s: die Schleife ist %d ganze Takte" % [id, int(e.meta["loop_bars"])])
		for k in ["ziel", "polizei", "tank", "schluss", "schluss_rekord", "schluss_finale"]:
			var c := m.assets.entry("music", "%s_%s" % [id, k])
			assert_true(c != null and is_equal_approx(c.bpm, e.bpm) and c.gain_db == e.gain_db, "%s_%s: Tempo und Pegel des Stücks" % [id, k])
	_done(m)


func test_placeholders_never_replace_a_real_piece() -> void:
	var m := _modern({"placeholders": true})
	for i in 6:
		assert_eq(str(m.music.race_piece(i).get("id", "")), PIECES[i % 3], "Etappe %d: ein echtes Rennstück, nie der Platzhalter" % i)
	_done(m)
