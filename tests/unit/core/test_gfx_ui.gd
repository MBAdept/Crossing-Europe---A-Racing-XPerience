extends TestCase
## v0.8.0, package UI1: what the menus decide about the graphics modes – the first-start chooser (contract D32), the
## slowness verdict against max(display frame time, 1/60 s) (A-2), the numbers and the suggestion of the
## Leistungstest (§4.8), the options' preset and single-value changes with their round trip through the settings
## file, the hidden "gfx" of leaderboard entries (D15) and the offers of the Leistungstest's result page.

const SettingsScript := preload("res://scripts/core/settings.gd")
const DIR := "user://test_gfx_ui"
const FILE := DIR + "/settings.json"
const MARKER := DIR + "/modern_start.lock"


func _settings(file_content: Variant = null) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	JsonFile.remove_all(FILE)
	if FileAccess.file_exists(MARKER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER))
	if file_content != null:
		JsonFile.save_atomic(FILE, file_content)
		JsonFile.remove(FILE + JsonFile.BAK_SUFFIX)
	var s: Node = SettingsScript.new()
	s.set("file_path", FILE)
	s.set("marker_path", MARKER)
	s.call("load_settings")
	return s


func _reload() -> Node:
	var t: Node = SettingsScript.new()
	t.set("file_path", FILE)
	t.set("marker_path", MARKER)
	t.call("load_settings")
	return t


func _stored() -> Dictionary:
	var d: Variant = ConfigLoader.load_json(FILE)
	return d if d is Dictionary else {}


func _gfx_cfg() -> Dictionary:
	return ConfigLoader.lookup(cfg(), "graphics", {})


# --- first-start chooser (D32) ---------------------------------------------------------------------------------

## The whole matrix: due only without a stored mode, without any user argument, with a display and without a mode
## forced by the configuration.
func test_chooser_condition_matrix() -> void:
	var due: Array[String] = []
	var n := 0
	for chosen: String in ["", "arcade", "modern", "Modern", "bogus"]:
		for args: int in [0, 1, 3]:
			for headless: bool in [false, true]:
				for force: String in ["", "arcade", "modern", "nonsense"]:
					n += 1
					if Gfx.chooser_due(chosen, args, headless, force):
						due.append("%s|%d|%s|%s" % [chosen, args, str(headless), force])
	assert_eq(n, 120, "120 Kombinationen geprüft")
	assert_eq(due, ["|0|false|", "|0|false|nonsense", "Modern|0|false|", "Modern|0|false|nonsense",
		"bogus|0|false|", "bogus|0|false|nonsense"],
		"nur ohne gültige Wahl, ohne Argument, mit Bildschirm und ohne erzwungenen Modus")
	# the cases one by one, as the player meets them
	assert_true(Gfx.chooser_due("", 0, false, ""), "neuer Spieler, normaler Start: Auswahl")
	assert_false(Gfx.chooser_due("arcade", 0, false, ""), "Arcade gewählt: nie wieder")
	assert_false(Gfx.chooser_due("modern", 0, false, ""), "Modern gewählt: nie wieder")
	assert_false(Gfx.chooser_due("", 1, false, ""), "ein Argument (Werkzeug, Test, --no-chooser): keine Auswahl")
	assert_false(Gfx.chooser_due("", 0, true, ""), "headless: keine Auswahl")
	assert_false(Gfx.chooser_due("", 0, false, "modern"), "Konfiguration erzwingt Modern: Auswahl wäre wirkungslos")


## The recommended card: Modern for deck / ok, Arcade for software / weak – and Arcade whenever Modern did not survive
## its last start.
func test_chooser_recommendation() -> void:
	for tier: String in ["software", "weak", "deck", "ok"]:
		var expect := "modern" if tier == "deck" or tier == "ok" else "arcade"
		assert_eq(GraphicsChoiceScreen.recommended_for(tier, false), expect, "Empfehlung für " + tier)
		assert_eq(GraphicsChoiceScreen.recommended_for(tier, true), "arcade", "nach Absturz-Marker Arcade (" + tier + ")")
	assert_eq(GraphicsChoiceScreen.warning_text("ok", false), "", "keine Warnung auf normaler Grafik")
	assert_true(GraphicsChoiceScreen.warning_text("software", false) != "", "Warnung auf Software-Grafik")
	assert_true(GraphicsChoiceScreen.warning_text("ok", true).contains("nicht richtig beendet"), "Warnung nach Absturz-Marker")


## The choice is stored at once and leaves "Klang" at "Wie Grafik": picture and sound switch together.
func test_choice_sets_mode_and_sound_follows() -> void:
	var s := _settings({"settings_version": 2, "master_volume": 0.5, "player_name": "Anke"})
	var log: Array[String] = []
	s.connect("graphics_changed", func(m: String) -> void: log.append("gfx:" + m))
	s.connect("sound_profile_changed", func(p: String) -> void: log.append("sound:" + p))
	assert_true(Gfx.chooser_due(str(s.get("graphics_mode")), 0, false, ""), "bestehender Spieler ohne Wahl: Auswahl fällig")
	s.set("graphics_mode", "modern")
	s.call("save_settings")
	assert_eq(" ".join(log), "gfx:modern sound:modern", "Modern gewählt: Grafik und Klang zusammen")
	var d := _stored()
	assert_eq(str(d.get("graphics_mode", "")), "modern", "gespeichert")
	assert_false(d.has("sound_profile"), "Klang bleibt ungewählt (Wie Grafik)")
	assert_eq(str(d.get("player_name", "")), "Anke", "alles andere bleibt")
	s.free()
	var t := _reload()
	assert_false(Gfx.chooser_due(str(t.get("graphics_mode")), 0, false, ""), "beim nächsten Start keine Auswahl mehr")
	assert_eq(str(t.call("sound")), "modern", "Klang folgt der gewählten Grafik")
	t.free()


# --- watchdog against max(display frame time, 1/60 s) (A-2) ---------------------------------------------------

func test_watchdog_never_judges_below_60_hz() -> void:
	var wd: Dictionary = ConfigLoader.lookup(cfg(), "graphics.watchdog", {})
	var hz144 := 1000.0 / 144.0
	var hz120 := 1000.0 / 120.0
	assert_eq(Gfx.watchdog_verdict(16.7, 18.0, hz144, wd, false), "ok", "stetige 60 Bilder/s an 144 Hz sind nicht langsam")
	assert_eq(Gfx.watchdog_verdict(16.7, 18.0, hz120, wd, true), "ok", "stetige 60 Bilder/s an 120 Hz, niedrigste Stufe")
	assert_eq(Gfx.watchdog_verdict(9.0, 12.0, hz144, wd, false), "ok", "110 Bilder/s an 144 Hz")
	assert_eq(Gfx.watchdog_verdict(24.0, 30.0, hz144, wd, false), "slow", "~40 Bilder/s an 144 Hz: langsam gegen 60 Hz")
	assert_eq(Gfx.watchdog_verdict(40.0, 55.0, hz144, wd, true), "too_slow", "25 Bilder/s an 144 Hz, niedrigste Stufe")
	# a slower target than 60 Hz still counts as it is (Steam Deck at 40 Hz)
	assert_eq(Gfx.watchdog_verdict(25.0, 27.0, 25.0, wd, false), "ok", "40 Hz voll erreicht")
	assert_eq(Gfx.watchdog_verdict(36.0, 40.0, 25.0, wd, false), "slow", "28 Bilder/s an 40 Hz")
	assert_near(Gfx.watchdog_target_ms(hz144), 1000.0 / 60.0, 0.001, "Ziel an 144 Hz: 1/60 s")
	assert_near(Gfx.watchdog_target_ms(25.0), 25.0, 0.001, "Ziel an 40 Hz: 25 ms")
	assert_near(Gfx.watchdog_target_ms(-1.0), 1000.0 / 60.0, 0.001, "unbekannt: 60 Hz")
	assert_near(Gfx.target_ms_for_refresh(144.0), 1000.0 / 60.0, 0.001, "144 Hz -> 16,7 ms")
	assert_near(Gfx.target_ms_for_refresh(40.0), 25.0, 0.001, "40 Hz -> 25 ms")
	assert_near(Gfx.target_ms_for_refresh(-1.0), 1000.0 / 60.0, 0.001, "-1 (unbekannt) -> 60 Hz")
	assert_near(Gfx.target_ms_for_refresh(0.0), 1000.0 / 60.0, 0.001, "0 -> 60 Hz")
	assert_near(Gfx.target_ms_for_refresh(NAN), 1000.0 / 60.0, 0.001, "NaN -> 60 Hz")


# --- Leistungstest: statistics and suggestion ------------------------------------------------------------------

func test_frame_stats() -> void:
	var ms := PackedFloat32Array()
	for i in 99:
		ms.append(10.0)
	ms.append(50.0)                      # one hitch in 100 frames
	var st := Gfx.frame_stats(ms)
	assert_eq(int(st["frames"]), 100, "100 Bilder")
	assert_near(float(st["avg_fps"]), 100.0 * 1000.0 / 1040.0, 0.01, "Mittel = Bilder / Gesamtzeit")
	assert_near(float(st["low1_fps"]), 20.0, 0.01, "1 % niedrig = das langsamste Bild (50 ms)")
	assert_near(float(st["frame_ms_median"]), 10.0, 0.001, "Median")
	assert_near(float(st["frame_ms_p95"]), 10.0, 0.001, "95 %")
	assert_near(float(st["frame_ms_p99"]), 10.0, 0.001, "99 % (Rang 99 von 100)")
	assert_near(float(st["frame_ms_max"]), 50.0, 0.001, "Maximum")
	var two := PackedFloat32Array([10.0, 20.0, -5.0, NAN, INF, 0.0])
	var st2 := Gfx.frame_stats(two)
	assert_eq(int(st2["frames"]), 2, "nicht positive und unendliche Zeiten zählen nicht")
	assert_near(float(st2["avg_fps"]), 2000.0 / 30.0, 0.01, "Mittel aus 10 und 20 ms")
	var empty := Gfx.frame_stats(PackedFloat32Array())
	assert_eq(int(empty["frames"]), 0, "leer")
	assert_eq(float(empty["avg_fps"]), 0.0, "leer: 0 Bilder/s")


func test_preset_ladder() -> void:
	var presets: Dictionary = _gfx_cfg().get("presets", {})
	assert_eq(Gfx.preset_ladder("deck", presets), ["low", "deck", "medium", "high"], "Steam Deck: mit der Deck-Stufe")
	assert_eq(Gfx.preset_ladder("ok", presets), ["low", "medium", "high"], "sonst ohne")
	assert_true(Gfx.quality_cost(Gfx.preset_values("low", presets)) < Gfx.quality_cost(Gfx.preset_values("deck", presets)), "low < deck")
	assert_true(Gfx.quality_cost(Gfx.preset_values("medium", presets)) < Gfx.quality_cost(Gfx.preset_values("high", presets)), "medium < high")


func _scene(id: String, median: float, p95: float = -1.0, p99: float = -1.0) -> Dictionary:
	return {"id": id, "frames": 1000, "frame_ms_median": median, "frame_ms_p95": p95 if p95 > 0.0 else median * 1.1,
		"frame_ms_p99": p99 if p99 > 0.0 else median * 1.2}


func test_bench_suggestion() -> void:
	var g := _gfx_cfg()
	var presets: Dictionary = g.get("presets", {})
	var t60 := 1000.0 / 60.0
	var medium := Gfx.quality("medium", {}, presets)
	var low := Gfx.quality("low", {}, presets)
	var deck := Gfx.quality("deck", {}, presets)
	var high := Gfx.quality("high", {}, presets)
	# fluid with headroom: one step up
	var s := Gfx.bench_suggestion(medium, [_scene("a", 6.0), _scene("b", 8.0), _scene("c", 7.0)], t60, "ok", g)
	assert_eq(str(s["verdict"]), "ok", "flüssig")
	assert_eq(str(s["suggested_preset"]), "high", "Reserve: eine Stufe höher")
	assert_eq(str(s["worst"]), "b", "die langsamste Szene entscheidet")
	assert_eq(str(s["suggested_mode"]), "modern", "Modern")
	# fluid without headroom: stays
	s = Gfx.bench_suggestion(medium, [_scene("a", 14.0)], t60, "ok", g)
	assert_eq(str(s["suggested_preset"]), "medium", "flüssig ohne Reserve: bleibt")
	# the highest preset: nothing above
	s = Gfx.bench_suggestion(high, [_scene("a", 5.0)], t60, "ok", g)
	assert_eq(str(s["suggested_preset"]), "high", "Hoch bleibt Hoch")
	# slow: one step down
	s = Gfx.bench_suggestion(medium, [_scene("a", 12.0), _scene("b", 25.0)], t60, "ok", g)
	assert_eq(str(s["verdict"]), "slow", "langsam")
	assert_eq(str(s["suggested_preset"]), "low", "eine Stufe tiefer (ohne Deck-Stufe)")
	s = Gfx.bench_suggestion(medium, [_scene("a", 25.0)], t60, "deck", g)
	assert_eq(str(s["suggested_preset"]), "deck", "Steam Deck: Mittel -> Steam Deck")
	s = Gfx.bench_suggestion(deck, [_scene("a", 25.0)], t60, "deck", g)
	assert_eq(str(s["suggested_preset"]), "low", "Steam Deck: Steam Deck -> Niedrig")
	# far too slow on the cheapest preset: Arcade
	s = Gfx.bench_suggestion(low, [_scene("a", 45.0)], t60, "software", g)
	assert_eq(str(s["verdict"]), "too_slow", "viel zu langsam")
	assert_eq(str(s["suggested_mode"]), "arcade", "Vorschlag Arcade")
	# the display's refresh does not make 60 fps slow (A-2)
	s = Gfx.bench_suggestion(medium, [_scene("a", 16.0, 17.0, 18.0)], 1000.0 / 144.0, "ok", g)
	assert_eq(str(s["verdict"]), "ok", "60 Bilder/s an 144 Hz: flüssig")
	# nothing measured
	s = Gfx.bench_suggestion(medium, [], t60, "ok", g)
	assert_eq(str(s["verdict"]), "", "nichts gemessen: kein Urteil")
	assert_eq(str(s["suggested_preset"]), "medium", "nichts gemessen: die Voreinstellung bleibt")


## The result page offers what the suggestion changes, nothing for a stub, an abort or the preset already in use.
func test_benchmark_offers() -> void:
	var stored := {"preset": "medium", "shadows": 2, "details": 1, "scale": 100, "aa": 1, "effects": 1}
	var res := {"scenes": [{"id": "a"}], "suggested_preset": "high", "suggested_mode": "modern"}
	assert_eq(str(BenchmarkScreen.offer_of(res, stored, "modern").get("preset", "")), "high", "Hoch übernehmen")
	res["suggested_preset"] = "medium"
	assert_true(BenchmarkScreen.offer_of(res, stored, "modern").is_empty(), "schon eingestellt: nichts anzubieten")
	res["suggested_mode"] = "arcade"
	assert_eq(str(BenchmarkScreen.offer_of(res, stored, "modern").get("mode", "")), "arcade", "zu Arcade wechseln")
	assert_true(BenchmarkScreen.offer_of(res, stored, "arcade").is_empty(), "schon Arcade")
	res["suggested_mode"] = "modern"
	res["suggested_preset"] = "low"
	res["renderer_stub"] = true
	assert_true(BenchmarkScreen.offer_of(res, stored, "modern").is_empty(), "Gerüst-Renderer: kein Vorschlag")
	res.erase("renderer_stub")
	res["aborted"] = true
	assert_true(BenchmarkScreen.offer_of(res, stored, "modern").is_empty(), "abgebrochen: kein Vorschlag")


# --- options: preset and single values, round trip -------------------------------------------------------------

func test_options_preset_and_single_values() -> void:
	var s := _settings({"settings_version": 3})
	var log: Array[String] = []
	s.connect("quality_changed", func(q: Dictionary) -> void: log.append(str(q["preset"])))
	var start: Dictionary = s.call("stored_quality")
	assert_eq(str(start["preset"]), "medium", "ohne Wahl: die Empfehlung der Grafikkarte (headless: ok -> Mittel)")
	s.call("set_quality_value", "shadows", 3)
	assert_eq(str(s.get("gfx_preset")), "custom", "ein einzelner Wert: Eigene")
	assert_eq((s.call("stored_quality") as Dictionary)["shadows"], 3, "Schatten Hoch")
	assert_eq((s.call("stored_quality") as Dictionary)["details"], 1, "der Rest bleibt wie bei Mittel")
	assert_eq(log, ["custom"], "genau ein Signal")
	log.clear()
	s.call("set_quality_value", "shadows", 2)
	assert_eq(str(s.get("gfx_preset")), "medium", "wieder gleich einer Voreinstellung: diese")
	assert_eq(log, ["medium"], "ein Signal")
	log.clear()
	s.call("choose_preset", "high")
	assert_eq(str(s.get("gfx_preset")), "high", "Hoch gewählt")
	assert_eq(log, ["high"], "ein Signal")
	s.call("choose_preset", "custom")
	assert_eq((s.call("stored_quality") as Dictionary)["shadows"], 3, "Eigene: die letzten eigenen Werte (Schatten Hoch) überleben den Besuch der festen Stufen")
	log.clear()
	s.call("choose_preset", "custom")
	assert_eq(log, [], "dieselbe Wahl: kein Signal")
	s.call("choose_preset", "bogus")
	assert_eq(str(s.get("gfx_preset")), "custom", "unbekannte Voreinstellung: nichts")
	s.call("set_quality_value", "scale", 1000)
	assert_eq((s.call("stored_quality") as Dictionary)["scale"], 150, "Auflösung auf den Bereich begrenzt")
	s.call("set_quality_value", "nonsense", 1)
	assert_eq((s.call("stored_quality") as Dictionary).size(), 6, "unbekannter Schlüssel: nichts")
	s.free()


## Every new option survives saving and loading exactly – and only what was chosen is written.
func test_round_trip_of_every_new_option() -> void:
	for mode: String in ["arcade", "modern"]:
		for profile: String in ["auto", "arcade", "modern"]:
			for preset: String in Gfx.PRESET_ORDER:
				for music: bool in [false, true]:
					var s := _settings({"settings_version": 3})
					s.set("graphics_mode", mode)
					s.set("sound_profile", profile)
					if preset == "custom":
						s.call("set_quality_value", "aa", 2)
						s.call("set_quality_value", "scale", 67)
					else:
						s.call("choose_preset", preset)
					s.set("race_music", music)
					var q_before: Dictionary = s.call("stored_quality")
					var sound_before := str(s.call("sound"))
					assert_true(bool(s.call("save_settings")), "gespeichert")
					s.free()
					var t := _reload()
					var tag := "%s/%s/%s/%s" % [mode, profile, preset, str(music)]
					assert_eq(str(t.get("graphics_mode")), mode, "Grafik " + tag)
					assert_eq(str(t.get("sound_profile")), profile, "Klang " + tag)
					assert_eq(str(t.call("sound")), sound_before, "aufgelöster Klang " + tag)
					assert_eq(t.call("stored_quality"), q_before, "Qualität " + tag)
					assert_eq(bool(t.get("race_music")), music, "Musik im Rennen " + tag)
					assert_false(bool(t.call("has_unsaved_changes")), "gelesen = gespeichert " + tag)
					t.free()
	# untouched options are not written (the defaults of a later version may differ)
	var n := _settings({"settings_version": 3})
	n.call("save_settings")
	var d := _stored()
	for key: String in ["graphics_mode", "sound_profile", "gfx_preset", "gfx_custom", "race_music"]:
		assert_false(d.has(key), key + " ungewählt: nicht gespeichert")
	assert_eq(int(d.get("settings_version", 0)), 3, "Version 3")
	n.free()


# --- hidden "gfx" of leaderboard entries (D15) -----------------------------------------------------------------

func test_leaderboard_entries_carry_the_mode() -> void:
	var res := {"time_s": 3600.0, "avg_speed_kmh": 120.0, "vehicle": "kompakt", "weather": "rain", "start_hour": 21.0,
		"gfx": "modern"}
	var e := ResultScreen.leaderboard_entry(res, "night")
	assert_eq(str(e.get("gfx", "")), "modern", "Modus im Eintrag")
	assert_false(e.has("gfx_fallback"), "kein Rückfall")
	assert_eq(ResultScreen.fallback_note(res), "", "kein Hinweis ohne Rückfall")
	res["gfx"] = "arcade"
	res["gfx_fallback"] = "selftest:shader"
	e = ResultScreen.leaderboard_entry(res, "night")
	assert_eq(str(e.get("gfx", "")), "arcade", "nach Rückfall: Arcade")
	assert_eq(str(e.get("gfx_fallback", "")), "selftest:shader", "Grund im Eintrag")
	assert_true(ResultScreen.fallback_note(res) != "", "Hinweis nach Rückfall")
	var legacy := ResultScreen.leaderboard_entry({"time_s": 10.0}, "day")
	assert_eq(str(legacy.get("gfx", "")), "arcade", "Ergebnis ohne Modus: Arcade")
	# sanitize_entry keeps the hidden fields (the stored list holds them)
	var kept := LeaderboardStore.sanitize_entry(e)
	assert_eq(str(kept.get("gfx", "")), "arcade", "bleibt beim Speichern erhalten")
	assert_eq(str(kept.get("gfx_fallback", "")), "selftest:shader", "Grund bleibt erhalten")


func test_race_entry_mode_summary() -> void:
	var r := RaceState.new()
	assert_eq(r.gfx_summary(), "arcade", "ohne Etappe: Arcade")
	r.legs = [{"kind": "stage", "gfx": "modern"}, {"kind": "ferry"}, {"kind": "stage", "gfx": "modern"}]
	assert_eq(r.gfx_summary(), "modern", "alle Etappen in Modern")
	r.legs.append({"kind": "stage"})
	assert_eq(r.gfx_summary(), "mixed", "eine Etappe von vor v0.8.0 (Arcade) dazu: gemischt")
	r.legs = [{"kind": "stage", "gfx": "arcade"}, {"kind": "stage"}]
	assert_eq(r.gfx_summary(), "arcade", "nur Arcade")
	var leg := r.apply_stage_result({"id": "kiel_hamburg", "from": "kiel", "to": "hamburg"},
		{"time_s": 100.0, "gfx": "modern"}, cfg())
	assert_eq(str(leg.get("gfx", "")), "modern", "der Rennstand merkt sich den Modus jeder Etappe")
