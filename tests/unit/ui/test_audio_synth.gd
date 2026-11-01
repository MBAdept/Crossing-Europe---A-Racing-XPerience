extends TestCase
## Procedural audio (SfxSynth): loop lengths, levels, seamless loops, WAV wrapping, virtual gearbox.
## Title theme (assets/audio/music/title_theme.ogg, tools/audio/music_synth.py): import settings and loop seam.

const TITLE_THEME := "res://assets/audio/music/title_theme.ogg"
const INTRO_S := 15.0            ## 8 bars at 128 bpm: plays once, the loop starts here


func _peak(b: PackedFloat32Array) -> float:
	var m := 0.0
	for v in b:
		m = maxf(m, absf(v))
	return m


func test_engine_loop_is_seamless_and_normalized() -> void:
	var b := SfxSynth.engine_loop(true, 16)
	assert_eq(b.size(), SfxSynth.ENGINE_PERIOD * 16, "ganze Perioden")
	assert_near(_peak(b), 0.85, 0.001, "normalisiert")
	assert_true(absf(b[0] - b[b.size() - 1]) < 0.25, "Schleifenübergang ohne Sprung")
	assert_near(SfxSynth.ENGINE_BASE_HZ, 22050.0 / 256.0, 0.001, "Grundfrequenz")


func test_siren_two_tones() -> void:
	var b := SfxSynth.siren_loop(440.0, 587.0, 0.5)
	var seg := int(0.5 * SfxSynth.RATE)
	assert_eq(b.size(), seg * 2, "zwei Töne")
	assert_true(absf(b[0]) < 0.05 and absf(b[b.size() - 1]) < 0.05, "weich ein- und ausgeblendet")
	assert_true(_peak(b) <= 0.8001, "Pegel")


func test_one_shots_in_range() -> void:
	for b: PackedFloat32Array in [SfxSynth.crash(), SfxSynth.rail_hit(), SfxSynth.radar_flash(), SfxSynth.beep(784.0, 0.18), SfxSynth.finish_jingle(), SfxSynth.ui_tick()]:
		assert_true(b.size() > 100, "nicht leer")
		assert_true(_peak(b) <= 0.951, "kein Clipping")


func test_wav_wrapping() -> void:
	var b := SfxSynth.beep(880.0, 0.1)
	var w := SfxSynth.to_wav(b, true)
	assert_eq(w.data.size(), b.size() * 2, "16 Bit")
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Schleife")
	assert_eq(w.loop_end, b.size(), "Schleifenende")
	assert_eq(w.mix_rate, SfxSynth.RATE, "Abtastrate")


func test_virtual_gearbox() -> void:
	var g1 := SfxSynth.gear_for(20.0, 250.0, 6)
	assert_eq(int(g1.x), 1, "1. Gang beim Anfahren")
	var g6 := SfxSynth.gear_for(245.0, 250.0, 6)
	assert_eq(int(g6.x), 6, "6. Gang bei Höchstgeschwindigkeit")
	assert_true(g6.y < 1.0, "Drehzahl unter Begrenzer bei vmax")
	# shifting up drops the rpm (saw-tooth)
	var before := SfxSynth.gear_for(250.0 * 0.31 - 0.5, 250.0, 6)
	var after := SfxSynth.gear_for(250.0 * 0.31 + 0.5, 250.0, 6)
	assert_eq(int(after.x), int(before.x) + 1, "Gangwechsel")
	assert_true(after.y < before.y - 0.2, "Drehzahl fällt nach dem Hochschalten")
	var last := 0
	for v in range(0, 260, 5):
		var g := int(SfxSynth.gear_for(float(v), 250.0, 6).x)
		assert_true(g >= last, "Gänge steigen monoton")
		last = g
	assert_eq(int(SfxSynth.gear_for(300.0, 250.0, 5).x), 5, "5-Gang-Getriebe")


func _title_theme() -> AudioStreamOggVorbis:
	if not ResourceLoader.exists(TITLE_THEME):
		return null
	var s: Variant = load(TITLE_THEME)
	return s as AudioStreamOggVorbis if s is AudioStreamOggVorbis else null


func test_title_theme_loops_after_the_intro() -> void:
	var ogg := _title_theme()
	assert_true(ogg != null, "Titelmelodie %s ist eine OGG-Vorbis-Datei" % TITLE_THEME)
	if ogg == null:
		return
	assert_true(ogg.loop, "Import: läuft als Schleife")
	assert_near(ogg.loop_offset, INTRO_S, 0.000001, "Import: Schleife ab dem Ende des Intros")
	assert_eq(int(ogg.loop_offset * 44100.0), 661500, "Schleifenbeginn auf einem ganzen Sample")
	assert_near(ogg.bpm, 0.0, 0.0001, "Schleife am Dateiende (keine Taktschleife mit Überblendung)")
	assert_between(ogg.get_length(), 150.0, 210.0, "Länge 2:30–3:30")
	assert_eq(str(ConfigLoader.lookup(cfg(), "audio.music_file", "")), TITLE_THEME, "audio.music_file")


## Godot's own Vorbis playback across the end of the file: it continues exactly at loop_offset - the frames after
## the seam are the frames of a playback started at loop_offset, and nothing jumps at the seam.
func test_title_theme_seam_through_godot_playback() -> void:
	var ogg := _title_theme()
	if ogg == null:
		fail("Titelmelodie fehlt")
		return
	var before := 11025                    # 0.25 s before the end of the file (an exact time: sample-exact seek)
	var pb := ogg.instantiate_playback()
	pb.start(ogg.get_length() - before / 44100.0)
	var across := pb.mix_audio(1.0, before + 8820)
	assert_eq(pb.get_loop_count(), 1, "an den Schleifenbeginn gesprungen")
	var pb2 := ogg.instantiate_playback()
	pb2.start(ogg.loop_offset)
	var direct := pb2.mix_audio(1.0, 8820)
	var diff := 0.0
	for i in range(64, 8820):                # the first frames of a fresh start lack the resampler history
		diff = maxf(diff, (across[before + i] - direct[i]).abs().length())
	assert_true(diff < 0.002, "nach der Naht dieselben Samples wie ab loop_offset (Abweichung %.5f)" % diff)
	# the step across the seam (a few frames of resampler latency) stays within the steps of the music around it
	var seam_step := 0.0
	var max_step := 0.0
	for i in range(before - 2205, before + 2205):
		var step := (across[i] - across[i - 1]).abs().length()
		if i >= before - 2 and i <= before + 6:
			seam_step = maxf(seam_step, step)
		else:
			max_step = maxf(max_step, step)
	assert_true(seam_step <= max_step, "kein Sprung an der Naht (%.4f, Umgebung bis %.4f)" % [seam_step, max_step])
