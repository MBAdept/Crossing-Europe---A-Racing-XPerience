extends TestCase
## EngineBank2 – loader of the stereo engine banks of the sound profile "Modern" (format "ce-engine-bank-2",
## docs/motorsound.md "Modern"): what it builds from a description, what it refuses and what it only notes; the five
## shipped banks and their vehicle sounds.

const FX := preload("res://tests/unit/audio_modern/test_engine3_fixture.gd")
const CARS: Array[String] = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]


func _load(meta: Dictionary, samples: PackedFloat32Array) -> EngineBank2:
	return EngineBank2.from_dict(meta, samples.duplicate(), "test")


func test_fixture_is_flattened_for_the_mixer() -> void:
	var ms := FX.build()
	var meta: Dictionary = ms[0]
	var b := _load(meta, ms[1])
	assert_true(b.ok(), "lädt: %s" % str(b.errors))
	assert_eq(b.car, "fixture", "Name")
	assert_eq(b.sample_rate, FX.SR, "Abtastrate")
	assert_eq(b.rpms.size(), 4, "vier Drehzahlpunkte")
	assert_eq(b.bank_count(), 12, "drei Ebenen je Punkt")
	for i in 4:
		assert_near(b.rpms[i], FX.rpm_of(FX.PERIODS[i]), 0.01, "Drehzahl %d aufsteigend" % i)
		assert_near(b.log_rpms[i], log(b.rpms[i]), 1.0e-9, "log")
		for l in 3:
			var bi := i * 3 + l
			assert_near(b.periods[bi], float(FX.PERIODS[i]), 1.0e-9, "Periode")
			assert_eq(b.overlaps[bi], FX.OVERLAP, "Überlappung")
			assert_eq(b.var_count[bi], 4, "vier Varianten")
			for v in 4:
				var ci := b.var_first[bi] + v
				assert_eq(b.cyc_len[ci], FX.PERIODS[i] + FX.OVERLAP, "Zykluslänge")
				assert_eq(int(b.cyc_mono[ci]), 1 if l == EngineBank2.LAYER_IN else 0, "nur die Ansaugebene ist mono")
				if l == EngineBank2.LAYER_IN:
					assert_eq(b.cyc_base[ci] % 2, v % 2, "Mono-Varianten liegen abwechselnd im linken und rechten Kanal")
				else:
					assert_eq(b.cyc_base[ci] % 2, 0, "Stereo-Varianten beginnen beim linken Abtastwert")
		assert_near(b.power[i * 3 + EngineBank2.LAYER_ON], pow(10.0, float(meta["banks"][i * 3 + 1]["lufs"]) / 10.0), 1.0e-9, "Leistung aus lufs")
	assert_eq(b.frames, (ms[1] as PackedFloat32Array).size() / 2, "Frames")
	assert_eq(b.data.size(), (b.frames + EngineBank2.PAD) * 2, "Rohdaten mit Rand")
	assert_eq(b.clip_count("crackle"), 3, "Clips")
	assert_eq(b.clip_count("shift"), 2, "zwei Mono-Clips in einem Block")
	assert_eq(b.clip_count("start"), 1, "Startclip")
	assert_eq(b.clip_count("gibtsnicht"), 0, "unbekannter Clip")
	assert_near(b.clip_seconds("start"), 8000.0 / FX.SR, 1.0e-6, "Länge des Startclips")
	var sh: PackedInt32Array = b.clips["shift"]
	assert_eq(sh[2], 1, "Mono-Clip")
	assert_eq(sh[3], sh[0] + 1, "der zweite liegt im rechten Kanal desselben Blocks")
	assert_true(b.has_layer("limiter") and b.has_layer("turbo") and not b.has_layer("sirene"), "Ebenen")
	assert_eq(int(b.layer("limiter")["cut_cycles"]), 2, "Parameter einer Ebene")
	assert_true(b.layer("gibtsnicht").is_empty(), "fehlende Ebene: leer")
	assert_near(b.mix_gain, 1.0, 1.0e-9, "mix.gain")
	assert_near(b.idle_load, 0.0, 1.0e-9, "mix.idle_load")
	assert_near(float(b.clip_gain["crackle"]), 1.0, 1.0e-9, "mix.clip_gain je Clipgruppe")
	assert_true(b.summary().contains("4 Drehzahlpunkte"), "Zusammenfassung: %s" % b.summary())
	# the description alone
	assert_true(EngineBank2.read_meta("res://gibtsnicht.json").is_empty(), "read_meta ohne Datei")


func _broken(change: Callable, cut_samples: int = 0) -> EngineBank2:
	var ms := FX.build()
	var meta: Dictionary = (ms[0] as Dictionary).duplicate(true)
	change.call(meta)
	var samples: PackedFloat32Array = ms[1]
	if cut_samples > 0:
		samples.resize(samples.size() - cut_samples)
	return _load(meta, samples)


func test_refuses_broken_descriptions() -> void:
	var cases := {
		"falsches Format": func(m: Dictionary) -> void: m["format"] = "ce-engine-bank-1",
		"ein Kanal": func(m: Dictionary) -> void: m["channels"] = 1,
		"Abtastrate außerhalb": func(m: Dictionary) -> void: m["sample_rate"] = 4000,
		"Abtastrate fehlt": func(m: Dictionary) -> void: m.erase("sample_rate"),
		"engine fehlt": func(m: Dictionary) -> void: m.erase("engine"),
		"Getriebe kaputt": func(m: Dictionary) -> void: m["gearbox"]["kmh_per_1000rpm"] = [30.0, 20.0],
		"banks leer": func(m: Dictionary) -> void: m["banks"] = [],
		"Ebene fehlt": func(m: Dictionary) -> void: (m["banks"] as Array).remove_at(2),
		"Ebene unbekannt": func(m: Dictionary) -> void: m["banks"][0]["layer"] = "halb",
		"Bank doppelt": func(m: Dictionary) -> void: (m["banks"] as Array).append((m["banks"][0] as Dictionary).duplicate(true)),
		"Periode passt nicht zur Drehzahl": func(m: Dictionary) -> void: m["banks"][0]["period"] = 700.0,
		"Zyklus außerhalb der Daten": func(m: Dictionary) -> void: m["banks"][0]["cycles"][0][0] = 99999999,
		"Zykluslänge falsch": func(m: Dictionary) -> void: m["banks"][0]["cycles"][1][1] = 500,
		"Modus unbekannt": func(m: Dictionary) -> void: m["banks"][0]["cycles"][0][2] = 3,
		"nur ein Zyklus": func(m: Dictionary) -> void: m["banks"][0]["cycles"] = [m["banks"][0]["cycles"][0]],
		"gain 0": func(m: Dictionary) -> void: m["banks"][0]["gain"] = 0.0,
		"Überlappung zu klein": func(m: Dictionary) -> void: m["banks"][0]["overlap"] = 2,
		"Clip außerhalb": func(m: Dictionary) -> void: m["clips"]["crackle"][0][1] = 99999999,
		"clips kein Objekt": func(m: Dictionary) -> void: m["clips"] = [1, 2],
		"layers kein Objekt": func(m: Dictionary) -> void: m["layers"] = "x",
		"mix.gain keine Zahl": func(m: Dictionary) -> void: m["mix"]["gain"] = "laut",
		"mix.gain zu groß": func(m: Dictionary) -> void: m["mix"]["gain"] = 20.0,
	}
	for label: String in cases:
		var b := _broken(cases[label])
		assert_false(b.ok(), "%s wird abgelehnt" % label)
		assert_true(b.data.is_empty(), "%s: keine Daten übernommen" % label)
	assert_false(_broken(func(_m: Dictionary) -> void: pass, 1).ok(), "ungerade Zahl von Abtastwerten")
	var missing := EngineBank2.load_file("res://assets/audio/modern/engines/gibtsnicht.json")
	assert_false(missing.ok(), "fehlende Datei")


func test_notes_tolerated_deviations() -> void:
	# a gap of more than a factor 1.25 between two rpm points
	var gap := _broken(func(m: Dictionary) -> void:
		var keep: Array = []
		for e: Dictionary in m["banks"]:
			if absf(float(e["rpm"]) - FX.rpm_of(FX.PERIODS[1])) > 1.0:
				keep.append(e)
		m["banks"] = keep)
	assert_true(gap.ok(), "lädt trotzdem: %s" % str(gap.errors))
	assert_true(str(gap.warnings).contains("auseinander"), "Hinweis auf den Abstand: %s" % str(gap.warnings))
	var idle := _broken(func(m: Dictionary) -> void: m["engine"]["idle_rpm"] = 1500)
	assert_true(idle.ok() and str(idle.warnings).contains("Leerlauf"), "tiefster Punkt über dem Leerlauf: %s" % str(idle.warnings))
	var clip := _broken(func(m: Dictionary) -> void: m["clips"]["hupe"] = [m["clips"]["start"][0]])
	assert_true(clip.ok() and str(clip.warnings).contains("hupe"), "unbekannter Clip: %s" % str(clip.warnings))
	var car := _broken(func(m: Dictionary) -> void: m.erase("car"))
	assert_true(car.ok() and not car.warnings.is_empty(), "car fehlt: Name aus dem Pfad")


func test_shipped_banks_and_their_vehicle_sounds() -> void:
	var assets := ModernAudioAssets.new()
	assert_true(assets.load_all(), "Manifeste laden: %s" % str(assets.errors))
	var want_clips := {"kompakt": [12, 2, 1], "kombi": [0, 0, 1], "limousine": [12, 0, 1], "sportwagen": [12, 2, 1], "gran_turismo": [12, 2, 1]}
	var want_turbo := {"kompakt": "turbo_single", "kombi": "turbo_single", "limousine": "turbo_single", "sportwagen": "", "gran_turismo": "turbo_twin"}
	var want_blowoff := {"kompakt": "blowoff_hatch", "kombi": "", "limousine": "blowoff_soft", "sportwagen": "", "gran_turismo": "blowoff_gt"}
	for car in CARS:
		var e := assets.entry("engines", car)
		assert_true(e != null and e.kind == "bank" and e.sample_rate == 32000 and e.channels == 2, "%s: Manifest-Eintrag einer Bank" % car)
		var meta := EngineBank2.read_meta(EngineBank2.path_for(car))
		assert_eq(str(meta.get("car", "")), car, "%s: Beschreibung lesbar" % car)
		var b := EngineBank2.load_file(EngineBank2.path_for(car))
		assert_true(b.ok(), "%s lädt: %s" % [car, str(b.errors)])
		if not b.ok():
			continue
		assert_true(b.warnings.is_empty(), "%s ohne Hinweise: %s" % [car, str(b.warnings)])
		assert_eq(b.sample_rate, EngineBank2.CONTRACT_RATE, "%s: 32 kHz" % car)
		assert_true(b.rpms.size() >= 10, "%s: %d Drehzahlpunkte" % [car, b.rpms.size()])
		assert_true(b.rpms[0] <= float(b.engine["idle_rpm"]) * 1.01, "%s: beginnt am Leerlauf" % car)
		assert_true(b.rpms[b.rpms.size() - 1] >= float(b.engine["limiter_rpm"]) * 0.99, "%s: reicht bis zum Begrenzer" % car)
		for i in range(1, b.rpms.size()):
			assert_true(b.rpms[i] / b.rpms[i - 1] <= EngineBank2.MAX_SPACING + 0.01, "%s: Abstand der Punkte %d/%d" % [car, i - 1, i])
		var clips: Array = want_clips[car]
		assert_eq([b.clip_count("crackle"), b.clip_count("shift"), b.clip_count("start")], clips, "%s: Clips Knallen / Schaltknall / Start" % car)
		assert_true(b.mix_gain > 0.15 and b.mix_gain <= 1.0, "%s: mix.gain %.3f" % [car, b.mix_gain])
		var peak := 0.0
		for x in b.data:
			peak = maxf(peak, absf(x))
		assert_true(peak > 0.5 and peak <= 1.0, "%s: Rohdaten ausgesteuert und nicht übersteuert (%.3f)" % [car, peak])
		# character: turbo, blow-off, crackles as the table says; every sound a layer names exists
		var t := b.layer("turbo")
		assert_eq(str(t.get("tone", "")), str(want_turbo[car]), "%s: Laderton" % car)
		if not t.is_empty():
			assert_true(assets.has("vehicle", str(t["tone"])) and assets.has("vehicle", str(t["hiss"])), "%s: Laderklänge vorhanden" % car)
			assert_true(float(t["tone_level"]) > 0.0 and float(t["tone_level"]) < 0.1, "%s: Laderton dezent (%.3f)" % [car, float(t["tone_level"])])
		assert_eq(str(b.layer("blowoff").get("sound", "")), str(want_blowoff[car]), "%s: Schubumluft" % car)
		if str(want_blowoff[car]) != "":
			assert_true(assets.has("vehicle", str(want_blowoff[car])), "%s: Schubumluft-Klang vorhanden" % car)
		assert_eq(b.has_layer("crackle"), int(clips[0]) > 0, "%s: Schubknallen nur mit Clips" % car)
		for key: String in ["driveline", "tipin", "thump"]:
			assert_true(assets.has("vehicle", str(b.layer(key).get("sound", "?"))), "%s: Klang der Ebene %s vorhanden" % [car, key])
		var dl := b.layer("driveline")
		assert_true(float(dl["fd_level"]) <= 0.015 and float(dl["gm_level"]) <= 0.015, "%s: Antriebsheulen bleibt leise" % car)
		assert_true(b.has_layer("limiter") and b.has_layer("saturation"), "%s: Begrenzer und Sättigung" % car)
	# every vehicle sound of this package is a loop or a one-shot on the engine effects bus
	var own := 0
	for id in assets.ids("vehicle"):
		var ve := assets.entry("vehicle", id)
		if str(ve.meta.get("generator", "")) != "tools/audio/modern/engine_synth3.py":
			continue      # sounds of other packages share the folder
		own += 1
		assert_eq(ve.bus, "MEngineFx", "vehicle/%s auf MEngineFx" % id)
		if ve.kind == "loop":
			# Godot reads the frame at the loop end before it wraps: the loop's first frames follow its end once more
			# (a loop that ends with its data plays one wrong frame at every seam – measured, docs/motorsound.md 6.9)
			assert_true(ve.loops() and ve.loop_begin == 0 and ve.frames - ve.loop_end >= 4, "vehicle/%s: Schleife mit Fortsetzung hinter ihrem Ende (%d Frames)" % [id, ve.frames - ve.loop_end])
			var st := assets.stream("vehicle", id) as AudioStreamWAV
			assert_true(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD and st.loop_end == ve.loop_end, "vehicle/%s: Import mit denselben Schleifenpunkten" % id)
	assert_eq(own, 9, "neun Fahrzeugklänge dieses Pakets")
