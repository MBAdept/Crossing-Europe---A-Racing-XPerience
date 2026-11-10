extends TestCase
## ModernAudioAssets (contract §4.7.3): the manifests of assets/audio/modern and the placeholders of wave 0 –
## every folder has its manifest, placeholders are hidden unless asked for, the imported streams carry the loop
## points and tempo data of the manifest, raw engine data reads back, broken manifests are reported.

const BROKEN := "res://tests/unit/audio_modern/fixtures/broken"


func _assets(placeholders: bool = true) -> ModernAudioAssets:
	var a := ModernAudioAssets.new()
	a.use_placeholders = placeholders
	a.load_all()
	return a


func test_every_folder_has_a_manifest() -> void:
	var a := _assets()
	assert_true(a.errors.is_empty(), "keine Fehler: %s" % str(a.errors))
	assert_true(a.warnings.is_empty(), "keine Hinweise: %s" % str(a.warnings))
	assert_eq(a.folders_loaded.size(), ModernAudioAssets.FOLDERS.size(), "sieben Ordner")
	for f in ModernAudioAssets.FOLDERS:
		assert_true(a.folders_loaded.has(f), "Manifest für %s" % f)
		assert_true(FileAccess.file_exists(ModernAudioAssets.ROOT.path_join(f).path_join("manifest.json")), "Datei da")
	assert_eq(ModernAudioAssets.FOLDERS, ["engines", "vehicle", "traffic", "sfx", "ambience", "ui", "music"] as Array[String], "Ordner des Vertrags")


func test_placeholders_are_hidden_unless_asked_for() -> void:
	var hidden := _assets(false)
	for f in ModernAudioAssets.FOLDERS:
		for id in hidden.ids(f):
			var e := hidden.entry(f, id)
			assert_false(e.placeholder, "%s/%s sichtbar, obwohl Platzhalter" % [f, id])
	assert_false(hidden.has("ui", "platzhalter_blip"), "ohne Schalter kein Platzhalter")
	assert_true(hidden.stream("ui", "platzhalter_blip") == null, "auch kein Stream")
	assert_true(hidden.ids("music", "", "race").is_empty(), "keine Rennmusik aus Platzhaltern")
	var shown := _assets(true)
	assert_true(shown.has("ui", "platzhalter_blip"), "mit Schalter sichtbar")
	assert_eq(shown.ids("music", "", "race"), ["platzhalter_takt"] as Array[String], "Platzhalter-Rennstück nach Rolle")
	assert_eq(shown.ids("music", "music"), ["platzhalter_takt"] as Array[String], "nach Art")
	assert_true(shown.ids("music", "oneshot").is_empty(), "Art-Filter")
	# the shipped configuration does not use them
	assert_false(bool(ConfigLoader.lookup(cfg(), "audio.modern.placeholders", true)), "audio.modern.placeholders ist aus")
	var count := 0
	for e in hidden.all_entries():
		count += 1 if e.placeholder else 0
	assert_true(count >= 7, "all_entries() nennt auch die Platzhalter (%d)" % count)


func test_placeholder_entries_and_streams() -> void:
	var a := _assets()
	# one-shot, mono WAV
	var blip := a.entry("ui", "platzhalter_blip")
	assert_true(blip != null, "ui/platzhalter_blip")
	if blip == null:
		return
	assert_eq(blip.kind, "oneshot", "Art")
	assert_eq(blip.bus, "MUI", "Bus")
	assert_eq(blip.channels, 1, "mono")
	assert_eq(blip.sample_rate, 44100, "44,1 kHz")
	assert_false(blip.loops(), "keine Schleife")
	assert_near(blip.seconds(), 0.12, 0.001, "Länge")
	assert_true(blip.true_peak_db <= -1.0, "True Peak mit Reserve (%.1f)" % blip.true_peak_db)
	var s := a.stream("ui", "platzhalter_blip")
	assert_true(s is AudioStreamWAV, "importierter WAV-Stream")
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		assert_eq(w.loop_mode, AudioStreamWAV.LOOP_DISABLED, "Einmalklang ohne Schleife")
		assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS, "16 Bit PCM, nicht komprimiert")
		assert_eq(w.mix_rate, 44100, "Abtastrate")
		assert_false(w.stereo, "mono")
		assert_eq(w.data.size(), blip.frames * 2, "Frames wie im Manifest")
	assert_true(a.stream("ui", "platzhalter_blip") == s, "Stream wird gemerkt")
	# loop, stereo WAV: the import carries the manifest's loop points
	var loop := a.entry("vehicle", "platzhalter_loop")
	assert_true(loop.loops(), "Schleife")
	assert_eq([loop.loop_begin, loop.loop_end], [0, 44100], "Schleifenpunkte")
	var ls := a.stream("vehicle", "platzhalter_loop") as AudioStreamWAV
	assert_true(ls != null, "Stream")
	if ls != null:
		assert_eq(ls.loop_mode, AudioStreamWAV.LOOP_FORWARD, "vorwärts")
		assert_eq(ls.loop_begin, loop.loop_begin, "Beginn")
		assert_eq(ls.loop_end, loop.loop_end, "Ende")
		assert_true(ls.stereo, "stereo")
	var tl := a.stream("traffic", "platzhalter_loop") as AudioStreamWAV
	assert_true(tl != null and not tl.stereo and tl.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Verkehrsschleife mono")
	# Vorbis: ambience bed and music with tempo data
	var bed := a.stream("ambience", "platzhalter_bed") as AudioStreamOggVorbis
	assert_true(bed != null and bed.loop, "Ambiente: Ogg Vorbis in Schleife")
	var music := a.entry("music", "platzhalter_takt")
	assert_eq(music.kind, "music", "Art")
	assert_eq(music.role, "race", "Rolle")
	assert_near(music.lufs, -14.0, 1.0, "auf −14 LUFS gemastert (%.2f)" % music.lufs)
	assert_true(music.true_peak_db <= -1.0, "True Peak ≤ −1 dBTP nach Vorbis (%.2f)" % music.true_peak_db)
	var ms := a.stream("music", "platzhalter_takt") as AudioStreamOggVorbis
	assert_true(ms != null, "Musik-Stream")
	if ms != null:
		assert_true(ms.loop, "Schleife")
		assert_near(ms.loop_offset, 0.0, 1.0e-6, "ab Anfang")
		assert_near(ms.bpm, music.bpm, 1.0e-6, "Tempo")
		assert_eq(ms.beat_count, music.beats, "Schläge")
		assert_eq(ms.bar_beats, music.bar_beats, "Schläge je Takt")
		assert_near(ms.get_length(), music.seconds(), 0.01, "Länge")
		assert_near(float(music.beats) * 60.0 / music.bpm, music.seconds(), 0.001, "Takte füllen die Datei")
	assert_true(a.warnings.is_empty(), "alles ladbar: %s" % str(a.warnings))
	assert_true(a.bytes_total() > 300000, "Größe aus den Manifesten (%d Bytes)" % a.bytes_total())
	assert_eq(a.bytes_total("ui"), blip.bytes, "je Ordner")
	a.release()


func test_raw_engine_data_reads_back() -> void:
	var a := _assets()
	var e := a.entry("engines", "platzhalter")
	assert_true(e != null and e.kind == "bank", "engines/platzhalter ist eine Bank")
	if e == null:
		return
	assert_eq(e.sample_rate, 32000, "32 kHz")
	assert_eq(e.channels, 2, "stereo")
	assert_true(a.stream("engines", "platzhalter") == null, "eine Bank ist kein Stream")
	assert_true(e.files[0].ends_with(".i16"), "Rohdaten .i16")
	var data := ModernAudioAssets.read_i16(e.files[0])
	assert_eq(data.size(), e.frames * e.channels, "Frames × Kanäle")
	var peak := 0.0
	var diff := 0.0
	for i in range(0, data.size(), 2):
		peak = maxf(peak, maxf(absf(data[i]), absf(data[i + 1])))
		diff = maxf(diff, absf(data[i] - data[i + 1]))
	assert_near(peak, 0.35, 0.01, "Spitze wie erzeugt")
	assert_true(diff > 0.05, "zwei verschiedene Kanäle")
	assert_true(FileAccess.file_exists(e.files[0].get_basename() + ".json"), "Beschreibung daneben")
	assert_true(ModernAudioAssets.read_i16("res://gibt/es/nicht.i16").is_empty(), "fehlende Datei: leer")


func test_broken_manifests_are_reported() -> void:
	var a := ModernAudioAssets.new()
	a.use_placeholders = true
	assert_false(a.load_all(BROKEN), "Fehler gemeldet")
	var text := "\n".join(a.errors)
	assert_true(text.contains("ein-anderes-format"), "falsches Format: %s" % text)
	assert_true(text.contains("music/manifest.json") and text.contains("kein gültiges JSON-Objekt"), "kein Objekt")
	assert_true(text.contains("\"sounds\" fehlt"), "sounds kein Objekt")
	assert_true(text.contains("sfx/fehlt") and text.contains("gibt_es_nicht.wav"), "fehlende Datei")
	assert_true(text.contains("sfx/kaputte_schleife"), "Schleife außerhalb der Datei")
	assert_true(text.contains("kein_objekt"), "Eintrag kein Objekt")
	assert_true(text.contains("sfx/ohne_datei"), "weder file noch files")
	assert_true(text.contains("sfx/ohne_schleife"), "loop ohne Schleifenpunkte")
	assert_true(text.contains("sfx/unbekannt") and text.contains("zauber"), "unbekannte Art")
	assert_eq(a.errors.size(), 9, "genau diese neun Fehler: %s" % text)
	# missing manifests are only a note; good entries of a faulty manifest stay usable
	assert_eq(a.warnings.size(), 3, "drei Ordner ohne Manifest: %s" % str(a.warnings))
	var good := a.entry("sfx", "gut")
	assert_true(good != null, "der gute Eintrag bleibt")
	if good != null:
		assert_eq(good.bus, "MUI", "Bus")
		assert_near(good.gain_db, -2.5, 1.0e-6, "Pegel")
		assert_eq(str(good.meta.get("extra", "")), "bleibt in meta", "zusätzliche Schlüssel bleiben erhalten")
	assert_eq(a.variant_count("sfx", "varianten"), 3, "drei Varianten")
	assert_eq(a.entry("sfx", "varianten").bytes, 6, "Bytes der Varianten summiert")
	a.use_placeholders = false
	assert_eq(a.variant_count("sfx", "varianten"), 0, "Platzhalter ohne Schalter unsichtbar")
	assert_eq(a.ids("sfx"), ["gut"] as Array[String], "nur der echte Eintrag")
	assert_true(a.stream("sfx", "gut") == null, "kein Klang hinter dem Eintrag")
	assert_false(a.warnings.size() == 3, "nicht ladbarer Stream als Hinweis vermerkt")
