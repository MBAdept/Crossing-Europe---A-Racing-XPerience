extends TestCase
## Procedural audio (SfxSynth): loop lengths, levels, seamless loops, WAV wrapping, virtual gearbox.


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
