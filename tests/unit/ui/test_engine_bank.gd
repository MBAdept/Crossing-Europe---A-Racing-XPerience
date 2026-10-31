extends TestCase
## EngineBank: loading and validating engine cycle banks (format docs/motorsound.md §1) – the valid fixture,
## broken fixture files and in-memory variants (tests/fixtures/make_engine_fixtures.py).

const DIR := "res://tests/fixtures/engines/"


func _good() -> EngineBank:
	return EngineBank.load_file(DIR + "fixture_v4.json")


func _meta() -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(DIR + "fixture_v4.json"))
	return json.data


func _samples() -> PackedFloat32Array:
	return FileAccess.get_file_as_bytes(DIR + "fixture_v4.f32").to_float32_array()


func _errors_of(meta: Dictionary) -> String:
	return " | ".join(EngineBank.from_dict(meta, _samples()).errors)


func _warnings_of(meta: Dictionary) -> String:
	return " | ".join(EngineBank.from_dict(meta, _samples()).warnings)


func test_valid_fixture_loads() -> void:
	var b := _good()
	assert_true(b.ok(), "gültige Bank: %s" % str(b.errors))
	assert_eq(b.car, "fixture_v4", "car")
	assert_eq(b.sample_rate, 16000, "Abtastrate")
	assert_eq(b.rpms.size(), 4, "Drehzahlpunkte")
	assert_eq(b.bank_count(), 8, "je Punkt beide Lasten")
	for i in b.rpms.size() - 1:
		assert_true(b.rpms[i + 1] > b.rpms[i], "aufsteigend")
		assert_true(b.rpms[i + 1] / b.rpms[i] <= 1.2501, "Abstand höchstens Faktor 1,25")
	for bi in b.bank_count():
		assert_eq(b.var_count[bi], 8, "8 Varianten")
		var p := b.periods[bi]
		assert_near(p, 120.0 / b.rpms[bi / 2] * b.sample_rate, 0.01, "period = 120 / rpm · sample_rate")
		for v in b.var_count[bi]:
			assert_eq(b.cyc_len[b.var_first[bi] + v], int(round(p)) + b.overlaps[bi], "Zykluslänge")
	assert_eq(b.clip_count("crackle"), 3, "drei Knall-Varianten")
	for c in ["blowoff", "shift", "start"]:
		assert_eq(b.clip_count(c), 1, "Clip " + c)
	assert_true(b.clip_seconds("start") > 0.3, "Startclip-Länge")
	for l in ["turbo", "crackle", "blowoff", "limiter"]:
		assert_true(b.has_layer(l), "Ebene " + l)
	assert_eq(int(b.layer("limiter")["cut_cycles"]), 2, "Begrenzer-Muster")
	assert_near(b.off_gain, 0.5, 0.0001, "mix.off_gain")
	assert_near(b.idle_load, 0.2, 0.0001, "mix.idle_load Standard")
	assert_eq(b.warnings.size(), 1, "nur die Abtastraten-Warnung: %s" % str(b.warnings))
	assert_true(b.warnings[0].contains("32000"), "Warnung nennt den Vertragswert")


func test_data_is_padded_for_safe_reads() -> void:
	var b := _good()
	var raw := _samples()
	assert_eq(b.data.size(), raw.size() + EngineBank.PAD, "Nullen angehängt")
	for i in EngineBank.PAD:
		assert_eq(b.data[raw.size() + i], 0.0, "Polster ist still")
	assert_eq(raw.size(), _samples().size(), "Eingabe unverändert")


func test_broken_fixture_files() -> void:
	var cases := {
		"broken_format": "Format",
		"broken_missing_load": "fehlt",
		"broken_cycle_range": "außerhalb der Rohdaten",
		"broken_length": "Zykluslänge",
		"broken_no_data": "Rohdaten fehlen",
	}
	for name in cases:
		var b := EngineBank.load_file(DIR + name + ".json")
		assert_false(b.ok(), name + " ist ungültig")
		var all := " | ".join(b.errors)
		assert_true(all.contains(str(cases[name])), "%s: verständlicher Fehler (%s)" % [name, all])
	var missing := EngineBank.load_file(DIR + "gibt_es_nicht.json")
	assert_false(missing.ok(), "fehlende Datei")
	assert_true(missing.errors[0].contains("fehlt"), "fehlende Datei gemeldet")


func test_truncated_data_file() -> void:
	var b := EngineBank.from_dict(_meta(), _samples().slice(0, 1000))
	assert_false(b.ok(), "zu kurze Rohdaten")
	assert_true(" ".join(b.errors).contains("außerhalb der Rohdaten"), "Zyklus außerhalb gemeldet")


func test_structural_errors() -> void:
	var m := _meta()
	m.erase("gearbox")
	assert_true(_errors_of(m).contains("gearbox"), "gearbox fehlt")
	m = _meta()
	m["sample_rate"] = 4000
	assert_true(_errors_of(m).contains("sample_rate"), "Abtastrate außerhalb")
	m = _meta()
	m["engine"]["limiter_rpm"] = 3000
	assert_true(_errors_of(m).contains("limiter_rpm"), "Begrenzer unter der Nenndrehzahl")
	m = _meta()
	m["gearbox"]["kmh_per_1000rpm"] = [12.0, 10.0]
	assert_true(_errors_of(m).contains("aufsteigend"), "Übersetzungen nicht aufsteigend")
	m = _meta()
	m["gearbox"]["upshift_rpm"] = [2600, 4500]
	assert_true(_errors_of(m).contains("upshift_rpm"), "Hochschalten über dem Begrenzer")
	m = _meta()
	m["gearbox"]["downshift_rpm"] = [2700, 2800]
	assert_true(_errors_of(m).contains("Hysterese"), "Rückschalten über dem Hochschalten")
	m = _meta()
	m["banks"][0]["period"] = 800.0
	assert_true(_errors_of(m).contains("period"), "period passt nicht zur Drehzahl")
	m = _meta()
	m["banks"][0]["overlap"] = 4
	assert_true(_errors_of(m).contains("overlap"), "overlap zu klein")
	m = _meta()
	m["banks"][0]["cycles"] = [m["banks"][0]["cycles"][0]]
	assert_true(_errors_of(m).contains("mindestens 2 Zyklen"), "eine Variante reicht nicht")
	m = _meta()
	m["banks"][1]["load"] = "half"
	assert_true(_errors_of(m).contains("load"), "unbekannte Last")
	m = _meta()
	m["banks"].append(m["banks"][0].duplicate(true))
	assert_true(_errors_of(m).contains("doppelt"), "doppelte Bank")
	m = _meta()
	m["clips"]["crackle"][0] = [-5, 10]
	assert_true(_errors_of(m).contains("clips.crackle"), "Clip außerhalb")
	m = _meta()
	m["layers"]["turbo"]["whistle_hz"] = 3000
	assert_true(_errors_of(m).contains("whistle_hz"), "Ebenen-Feld falscher Typ")
	m = _meta()
	m["mix"]["gain"] = 0.0
	assert_true(_errors_of(m).contains("mix.gain"), "Pegel 0")


func test_contract_deviations_are_warnings() -> void:
	var m := _meta()
	for b in m["banks"]:
		(b as Dictionary)["cycles"] = (b["cycles"] as Array).slice(0, 4)
	var b4 := EngineBank.from_dict(m, _samples())
	assert_true(b4.ok(), "4 Varianten funktionieren")
	assert_true(" ".join(b4.warnings).contains("mindestens 8"), "weniger als 8 Varianten: Warnung")
	m = _meta()
	m["banks"] = (m["banks"] as Array).filter(func(e: Dictionary) -> bool: return int(e["rpm"]) != 2500)
	var gap := EngineBank.from_dict(m, _samples())
	assert_true(gap.ok(), "Lücke im Raster funktioniert")
	assert_true(" ".join(gap.warnings).contains("Faktor"), "Abstand > 1,25: Warnung")
	m = _meta()
	m["layers"]["sirene"] = {"level": 1.0}
	m["layers"]["crackle"].erase("rate_hz")
	var lay := EngineBank.from_dict(m, _samples())
	assert_true(lay.ok(), "unbekannte Ebene bricht nichts")
	assert_true(" ".join(lay.warnings).contains("sirene"), "unbekannte Ebene: Warnung")
	assert_near(float(lay.layer("crackle")["rate_hz"]), 7.0, 0.001, "fehlendes Feld: Standardwert")
	m = _meta()
	m.erase("layers")
	m.erase("clips")
	m.erase("mix")
	var bare := EngineBank.from_dict(m, _samples())
	assert_true(bare.ok(), "ohne optionale Felder gültig")
	assert_false(bare.has_layer("turbo"), "fehlende Ebene = aus")
	assert_eq(bare.clip_count("start"), 0, "kein Startclip")
	assert_near(bare.mix_gain, 1.0, 0.0001, "Standardpegel")
