extends TestCase
## ModernBuses (contract §4.7.3): the bus names, their sends and index order, the base effects, faders / snapshot
## low-passes / music EQ, effective compressor ratio, clean removal – and that buses of other names (the Arcade
## ones) are left alone. The unit runner has only "Master" when a test starts; every test leaves it that way.

const CONTRACT_NAMES: Array[String] = ["MMaster", "MMusic", "MUI", "MSfx", "MCar", "MEngine", "MEngineFx", "MRoad",
	"MWind", "MImpact", "MWorld", "MTrafficV0", "MTrafficV1", "MTrafficV2", "MTrafficV3", "MTrafficV4", "MTrafficV5",
	"MTrafficV6", "MTrafficV7", "MSiren", "MAmb", "MEnv"]


func _modern_cfg() -> Dictionary:
	var m: Variant = ConfigLoader.lookup(cfg(), "audio.modern", {})
	return m if m is Dictionary else {}


func _built() -> ModernBuses:
	var b := ModernBuses.new()
	b.build(_modern_cfg())
	return b


func _classes(bus: String) -> Array[String]:
	var out: Array[String] = []
	var idx := AudioServer.get_bus_index(bus)
	for j in AudioServer.get_bus_effect_count(idx):
		out.append(AudioServer.get_bus_effect(idx, j).get_class())
	return out


func test_names_are_exactly_the_contract_list() -> void:
	var names := ModernBuses.names()
	assert_eq(names.size(), CONTRACT_NAMES.size(), "22 Busse")
	for n in CONTRACT_NAMES:
		assert_true(names.has(n), "%s gehört dazu" % n)
	var seen := {}
	for n in names:
		assert_true(n.begins_with("M"), "%s beginnt mit M" % n)
		assert_false(seen.has(n), "%s nur einmal" % n)
		seen[n] = true
	assert_eq(ModernBuses.send_of("MMaster"), "Master", "MMaster sendet an Master")
	assert_eq(ModernBuses.send_of("MTrafficV3"), "MWorld", "Verkehrsstimme sendet an MWorld")
	assert_eq(ModernBuses.send_of("Gibtsnicht"), "", "unbekannter Bus")


func test_build_creates_every_bus_after_the_existing_ones() -> void:
	assert_eq(AudioServer.bus_count, 1, "Ausgangslage: nur Master")
	var b := _built()
	assert_eq(AudioServer.bus_count, 1 + CONTRACT_NAMES.size(), "22 Busse dazu")
	assert_true(b.verify().is_empty(), "Graph in Ordnung: %s" % str(b.verify()))
	# every send goes to a bus with a lower index (otherwise the engine silently sends to Master)
	for n in ModernBuses.names():
		var idx := AudioServer.get_bus_index(n)
		var send := str(AudioServer.get_bus_send(idx))
		assert_eq(send, ModernBuses.send_of(n), "Send von %s" % n)
		assert_true(AudioServer.get_bus_index(send) < idx, "%s (%d) sendet nach links an %s (%d)" % [n, idx, send, AudioServer.get_bus_index(send)])
		assert_near(AudioServer.get_bus_volume_db(idx), 0.0, 1.0e-6, "%s bei 0 dB" % n)
		assert_false(AudioServer.is_bus_mute(idx), "%s nicht stumm" % n)
	# the environment path: everything of the world goes through MEnv, the music and the UI do not
	for n: String in ["MEngine", "MEngineFx", "MRoad", "MWind", "MImpact", "MTrafficV0", "MSiren"]:
		assert_true(_path(n).has("MEnv"), "%s läuft durch MEnv" % n)
		assert_true(_path(n).has("MSfx"), "%s läuft durch MSfx" % n)
	for n: String in ["MMusic", "MUI", "MAmb"]:
		assert_false(_path(n).has("MEnv"), "%s läuft nicht durch MEnv" % n)
	assert_true(_path("MUI").has("MSfx"), "MUI hängt am Regler „Effekte“")
	assert_false(_path("MMusic").has("MSfx"), "Musik hängt nicht am Regler „Effekte“")
	for n in ModernBuses.names():
		assert_true(_path(n).has("MMaster") or n == "MMaster", "%s endet in MMaster" % n)
	b.remove()
	assert_eq(AudioServer.bus_count, 1, "wieder nur Master")


func _path(bus: String) -> Array[String]:
	var out: Array[String] = []
	var n := bus
	for i in 12:
		n = str(AudioServer.get_bus_send(AudioServer.get_bus_index(n)))
		out.append(n)
		if n == "Master":
			break
	return out


func test_base_effects() -> void:
	var b := _built()
	assert_eq(_classes("MMaster"), ["AudioEffectCompressor", "AudioEffectHardLimiter"] as Array[String], "MMaster: Summenkompressor, dahinter der Begrenzer (AU-R)")
	assert_eq(_classes("MMusic"), ["AudioEffectLowShelfFilter", "AudioEffectLowShelfFilter", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "MMusic: Renn-EQ (zwei Kuhschwanzfilter), Tiefpass, Fader")
	assert_eq(_classes("MEnv"), ["AudioEffectDelay", "AudioEffectReverb", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "MEnv: trocken + Reflexionen + Hall")
	assert_eq(_classes("MCar"), ["AudioEffectAmplify"] as Array[String], "MCar: Fader")
	assert_eq(_classes("MWorld"), ["AudioEffectAmplify"] as Array[String], "MWorld: Fader")
	assert_eq(_classes("MAmb"), ["AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "MAmb")
	for n: String in ["MSfx", "MUI", "MEngine", "MEngineFx", "MRoad", "MWind", "MImpact"]:
		assert_true(_classes(n).is_empty(), "%s ohne Effekte" % n)
	for i in ModernBuses.TRAFFIC_VOICES + 1:
		var lp := b.voice_filter(i)
		assert_true(lp != null, "Tiefpass der Stimme %d" % i)
		if lp != null:
			assert_near(lp.cutoff_hz, 20000.0, 0.01, "offen")
	# the environment path passes the dry signal and starts without reflections and reverb
	assert_near(b.reflections().dry, 1.0, 1.0e-6, "Reflexionen: trocken 1")
	assert_near(b.reverb().dry, 1.0, 1.0e-6, "Hall: trocken 1")
	assert_near(b.reverb().wet, 0.0, 1.0e-6, "Hall: nass 0")
	assert_false(b.reflections().feedback_active, "kein Echo-Feedback")
	# snapshot low-passes and the race EQ are off, the faders neutral
	for n in ModernBuses.LOWPASS_BUSES:
		assert_false(_enabled(n, "AudioEffectLowPassFilter"), "Tiefpass von %s aus" % n)
	assert_false(b.music_eq_on(), "Renn-EQ aus")
	for fx in b.music_eq():
		assert_false(_enabled_fx("MMusic", fx), "Filter des Renn-EQ aus")
		assert_near(fx.gain, 1.0, 1.0e-6, "und neutral")
	for n in ModernBuses.FADER_BUSES:
		assert_near(b.gain_db(n), 0.0, 1.0e-6, "Fader %s neutral" % n)
		assert_true(_enabled(n, "AudioEffectAmplify"), "Fader %s an" % n)
	b.remove()


func _enabled(bus: String, cls: String) -> bool:
	var idx := AudioServer.get_bus_index(bus)
	for j in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, j).get_class() == cls:
			return AudioServer.is_bus_effect_enabled(idx, j)
	return false


func _enabled_fx(bus: String, fx: AudioEffect) -> bool:
	var idx := AudioServer.get_bus_index(bus)
	for j in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, j) == fx:
			return AudioServer.is_bus_effect_enabled(idx, j)
	return false


func _shelf_db(fx: AudioEffectFilter) -> float:
	return 40.0 * log(fx.gain) / log(10.0)   # the gain of the shelf is the square of the filter's "gain"


func _effect(bus: String, cls: String) -> AudioEffect:
	var idx := AudioServer.get_bus_index(bus)
	for j in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, j).get_class() == cls:
			return AudioServer.get_bus_effect(idx, j)
	return null


func test_fader_lowpass_and_eq() -> void:
	var b := _built()
	b.set_gain_db("MMusic", -4.5)
	assert_near((_effect("MMusic", "AudioEffectAmplify") as AudioEffectAmplify).volume_db, -4.5, 1.0e-5, "Fader der Musik")
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MMusic")), 0.0, 1.0e-6, "die Buslautstärke bleibt")
	b.set_gain_db("MSfx", -3.0)   # no fader there
	assert_near(b.gain_db("MSfx"), 0.0, 1.0e-6, "Bus ohne Fader: nichts")
	b.set_lowpass_hz("MMusic", 900.0)
	assert_true(_enabled("MMusic", "AudioEffectLowPassFilter"), "Tiefpass an")
	assert_near((_effect("MMusic", "AudioEffectLowPassFilter") as AudioEffectLowPassFilter).cutoff_hz, 900.0, 0.01, "900 Hz")
	b.set_lowpass_hz("MMusic", 20000.0)
	assert_false(_enabled("MMusic", "AudioEffectLowPassFilter"), "bei 20 kHz wieder aus")
	b.set_lowpass_hz("MMusic", 0.0)
	assert_false(_enabled("MMusic", "AudioEffectLowPassFilter"), "0 = aus")
	# race EQ: shelving filters in series (a broad dip around 500 Hz that makes room for the engine); its response
	# is measured by check_modern_audio.gd --live
	var eq := b.music_eq()
	var want: Array = ConfigLoader.lookup(cfg(), "audio.modern.music.race_eq", [])
	assert_eq(eq.size(), want.size(), "ein Filter je Eintrag")
	assert_true(eq.size() >= 1, "es gibt eine Klangregelung fürs Rennen")
	b.set_music_eq(true)
	assert_true(b.music_eq_on(), "Renn-EQ an")
	var bass_db := 0.0
	for i in eq.size():
		var spec: Dictionary = want[i]
		assert_true(_enabled_fx("MMusic", eq[i]), "Filter %d an" % i)
		assert_true(eq[i] is AudioEffectLowShelfFilter or eq[i] is AudioEffectHighShelfFilter, "Kuhschwanzfilter")
		assert_near(eq[i].cutoff_hz, float(spec["hz"]), 0.01, "Eckfrequenz %d" % i)
		assert_near(_shelf_db(eq[i]), float(spec["db"]), 1.0e-3, "Gewinn der Stufe %d" % i)
		assert_near(eq[i].resonance, 0.5, 1.0e-6, "ohne Überhöhung")
		assert_eq(int(eq[i].db), int(AudioEffectFilter.FILTER_6DB), "Flankeneinstellung, für die der Gewinn gemessen ist")
		if eq[i] is AudioEffectLowShelfFilter:
			bass_db += _shelf_db(eq[i])
	assert_between(bass_db, -2.0, 0.0, "der Bass bleibt fast, wie er ist (%.1f dB)" % bass_db)
	b.set_music_eq_amount(0.5)
	assert_near(b.music_eq_amount(), 0.5, 1.0e-6, "halb eingeblendet")
	for i in eq.size():
		assert_near(_shelf_db(eq[i]), 0.5 * float((want[i] as Dictionary)["db"]), 1.0e-3, "halber Gewinn der Stufe %d" % i)
		assert_true(_enabled_fx("MMusic", eq[i]), "Filter %d bleibt an" % i)
	b.set_music_eq(false)
	assert_false(b.music_eq_on(), "Renn-EQ aus")
	for i in eq.size():
		assert_false(_enabled_fx("MMusic", eq[i]), "Filter %d aus" % i)
		assert_near(eq[i].gain, 1.0, 1.0e-6, "neutral")
	assert_near(ModernBuses.shelf_gain(-6.0), 0.70795, 1.0e-4, "−6 dB: Gewinn 0,708 (gemessen −6,00 dB)")
	assert_true(ModernBuses.shelf_filter({"shelf": "low", "hz": 200.0, "db": 0.0}) == null, "0 dB: kein Filter")
	assert_true(ModernBuses.shelf_filter({"shelf": "high", "hz": 4000.0, "db": 2.0}) is AudioEffectHighShelfFilter, "Höhen")
	b.set_static_db("MSfx", -3.0, true)
	var si := AudioServer.get_bus_index("MSfx")
	assert_near(AudioServer.get_bus_volume_db(si), -3.0, 1.0e-5, "fester Pegel")
	assert_true(AudioServer.is_bus_mute(si), "stumm")
	b.set_mute("MSfx", false)
	assert_false(AudioServer.is_bus_mute(si), "wieder an")
	assert_near(b.path_db("MEngine"), -3.0, 1.0e-5, "Pegelkette MEngine → Master (MSfx −3 dB)")
	b.remove()


func test_slot_effect_goes_before_lowpass_and_fader() -> void:
	var b := _built()
	var width := b.effect("MEngine", "AudioEffectReverb")
	assert_true(width is AudioEffectReverb, "Effekt eines Bausteins angelegt")
	assert_true(b.effect("MEngine", "AudioEffectReverb") == width, "derselbe beim zweiten Mal")
	var chorus := b.effect("MMusic", "AudioEffectChorus")
	assert_true(chorus != null, "auf einem Bus mit Fader")
	assert_eq(_classes("MMusic"), ["AudioEffectLowShelfFilter", "AudioEffectLowShelfFilter", "AudioEffectChorus", "AudioEffectLowPassFilter", "AudioEffectAmplify"] as Array[String], "vor Tiefpass und Fader")
	assert_true(b.effect("MMusic", "AudioEffectLowShelfFilter", false) == null, "die Filter des Renn-EQ werden nicht herausgegeben")
	assert_true(b.effect("MMusic", "AudioEffectAmplify", false) == null, "der Fader selbst wird nicht herausgegeben")
	assert_true(b.effect("Gibtsnicht", "AudioEffectReverb") == null, "unbekannter Bus")
	b.remove()


func test_glue_compressor_from_config() -> void:
	var b := _built()
	var g: Dictionary = ConfigLoader.lookup(cfg(), "audio.modern.glue", {})
	var c := b.glue()
	assert_near(c.threshold, float(g["threshold_db"]), 1.0e-5, "Schwelle")
	assert_near(c.ratio, ModernBuses.compressor_ratio(float(g["ratio"])), 1.0e-5, "umgerechnetes Verhältnis")
	assert_near(c.attack_us, float(g["attack_ms"]) * 1000.0, 0.01, "Attack")
	assert_near(c.release_ms, float(g["release_ms"]), 0.01, "Release")
	assert_eq(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("MMaster"), 0), bool(g["enabled"]), "an/aus")
	b.remove()
	var off := ModernBuses.new()
	off.build({"glue": {"enabled": false}})
	assert_false(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("MMaster"), 0), "abschaltbar")
	off.remove()


## AU-R (KRITIK-FAHRBAHN B7, D29 <= -1 dBTP): the limiter of the Modern sound on MMaster behind the glue compressor –
## in front of Master's volume, so it holds at every Gesamtlautstärke; the Arcade limiter on Master is not touched.
func test_limiter_from_config() -> void:
	var master_fx := AudioServer.get_bus_effect_count(0)
	var b := _built()
	var l: Dictionary = ConfigLoader.lookup(cfg(), "audio.modern.limiter", {})
	assert_near(float(l["ceiling_db"]), -2.0, 1.0e-6, "Obergrenze −2 dB (Plan: True Peak ≤ −1 dBTP)")
	var lim := b.limiter()
	assert_true(lim != null and lim == _effect("MMaster", "AudioEffectHardLimiter"), "Begrenzer auf MMaster")
	assert_near(lim.ceiling_db, float(l["ceiling_db"]), 1.0e-5, "Obergrenze aus der Konfiguration")
	assert_near(lim.release, float(l["release_s"]), 1.0e-5, "Release")
	assert_near(lim.pre_gain_db, float(l.get("pre_gain_db", 0.0)), 1.0e-5, "ohne Vorverstärkung")
	assert_true(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("MMaster"), 1), "an")
	assert_eq(AudioServer.get_bus_effect_count(0), master_fx, "Master behält seine Effekte")
	b.remove()
	var off := ModernBuses.new()
	off.build({"limiter": {"enabled": false}})
	assert_false(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("MMaster"), 1), "abschaltbar")
	assert_near(off.limiter().ceiling_db, -2.0, 1.0e-6, "ohne Eintrag −2 dB")
	off.remove()
	assert_true(off.limiter() == null, "mit den Bussen entfernt")


## Godot's compressor reduces 2.0814 × overshoot × (ratio − 1) / ratio: the nominal ratio for a wanted one.
func test_compressor_ratio_conversion() -> void:
	assert_near(ModernBuses.compressor_ratio(1.0), 1.0, 1.0e-6, "1:1 bleibt 1:1")
	for eff: float in [1.5, 2.0, 3.0, 4.0]:
		var r := ModernBuses.compressor_ratio(eff)
		var reduction_per_db := 2.08136898 * (r - 1.0) / r
		assert_near(reduction_per_db, 1.0 - 1.0 / eff, 1.0e-5, "wirksam %.1f:1 (Nennwert %.3f)" % [eff, r])
	assert_between(ModernBuses.compressor_ratio(2.0), 1.31, 1.32, "2:1 braucht den Nennwert 1,316")
	assert_true(ModernBuses.compressor_ratio(1000.0) <= 48.0, "im Wertebereich des Effekts")


func test_other_buses_are_left_alone() -> void:
	# stand-ins for the Arcade buses, with an effect and odd settings
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "SFX")
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_volume_db(1, -7.5)
	AudioServer.add_bus()
	AudioServer.set_bus_name(2, "Room")
	AudioServer.set_bus_send(2, "SFX")
	var rev := AudioEffectReverb.new()
	rev.wet = 0.123
	AudioServer.add_bus_effect(2, rev)
	AudioServer.set_bus_mute(2, true)
	var tool: GDScript = load("res://tests/unit/audio_modern/golden/arcade_golden.gd")
	var before: Array = tool.call("bus_layout")
	var b := _built()
	assert_eq(AudioServer.get_bus_index("SFX"), 1, "SFX bleibt an seiner Stelle")
	assert_eq(AudioServer.get_bus_index("Room"), 2, "Room bleibt an seiner Stelle")
	assert_eq(AudioServer.get_bus_index("MMaster"), 3, "Modern-Busse dahinter")
	var during: Array[String] = tool.call("layout_diff", before, tool.call("bus_layout"), ModernBuses.names())
	assert_true(during.is_empty(), "die anderen Busse unverändert, solange Modern besteht: %s" % str(during))
	b.set_gain_db("MMusic", -6.0)
	b.set_static_db("MSfx", -3.0, true)
	b.remove()
	var after: Array[String] = tool.call("layout_diff", before, tool.call("bus_layout"))
	assert_true(after.is_empty(), "nach dem Entfernen alles wie vorher: %s" % str(after))
	AudioServer.remove_bus(2)
	AudioServer.remove_bus(1)
	assert_eq(AudioServer.bus_count, 1, "aufgeräumt")


func test_build_twice_and_leftovers() -> void:
	var a := _built()
	a.build(_modern_cfg())
	assert_eq(AudioServer.bus_count, 1 + CONTRACT_NAMES.size(), "zweites build() ändert nichts")
	assert_eq(_classes("MMusic").size(), 4, "keine doppelten Effekte (zwei Filter des Renn-EQ, Tiefpass, Fader)")
	# buses left behind by an object that was never removed: a new one starts clean
	var b := ModernBuses.new()
	b.build(_modern_cfg())
	assert_eq(AudioServer.bus_count, 1 + CONTRACT_NAMES.size(), "keine doppelten Busse")
	assert_eq(_classes("MMusic").size(), 4, "Effekte einmal")
	assert_true(b.verify().is_empty(), "Graph in Ordnung")
	b.remove()
	assert_eq(AudioServer.bus_count, 1, "aufgeräumt")
	assert_false(b.verify().is_empty(), "verify() meldet fehlende Busse")
