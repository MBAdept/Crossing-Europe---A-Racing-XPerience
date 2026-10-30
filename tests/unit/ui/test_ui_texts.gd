extends TestCase
## Player texts and small UI rules from the review: numbers in texts come from the configuration
## (CFG-1/TEXT-1), tutorial tips (TUT-1), tow overlay (FUEL-2), "hier" at the station (FUEL-7),
## top-10 headline for vehicle-only placements (LB-2), icons next to the time (LB-3), default
## leaderboard filter from the config (CFG-2).


func _cfg_with(over: Dictionary) -> Dictionary:
	return ConfigLoader.deep_merge(cfg(), over)


func test_number_and_hours() -> void:
	assert_eq(UiFormat.number(12.0), "12", "ganze Zahl ohne Komma")
	assert_eq(UiFormat.number(10.5), "10,5", "deutsches Komma")
	assert_eq(UiFormat.number(3.75), "3,75", "zwei Stellen")
	assert_eq(UiFormat.number(100.0, 0), "100", "keine Stellen")
	assert_eq(UiFormat.hours(12.0), "12 Stunden", "Stunden")
	assert_eq(UiFormat.hours(1.0), "1 Stunde", "Einzahl")


func test_texts_follow_config_values() -> void:
	var shipped := cfg()
	assert_true(StartTimeScreen.start_note(shipped).contains("12 Stunden"), "Pause 12 h")
	assert_true(StartTimeScreen.start_note(shipped).contains("1 Stunde dauert 5 Spielminuten"), "Zeitraffer 12")
	assert_eq(ResultScreen.next_start_caption(shipped), "Nächster Start (12 h Pause)", "Ergebnis: Pause")
	assert_true(OptionsScreen.lane_note(shipped).contains("unter 60 km/h"), "Tankspur 60")
	var tuned := _cfg_with({"time": {"stage_pause_hours": 10.0, "time_scale": 10.0}, "fuel": {"lane_trigger_speed_kmh": 50.0}})
	assert_true(StartTimeScreen.start_note(tuned).contains("10 Stunden"), "Pause aus der Konfiguration")
	assert_true(StartTimeScreen.start_note(tuned).contains("1 Stunde dauert 6 Spielminuten"), "Zeitraffer aus der Konfiguration")
	assert_false(StartTimeScreen.start_note(tuned).contains("12"), "keine fest verdrahtete 12 mehr")
	assert_eq(ResultScreen.next_start_caption(tuned), "Nächster Start (10 h Pause)", "Ergebnis: Pause aus der Konfiguration")
	assert_true(OptionsScreen.lane_note(tuned).contains("unter 50 km/h"), "Tankspur aus der Konfiguration")


func test_tutorial_tips_from_config_and_stage() -> void:
	var tips := UiFormat.tutorial_tips(cfg(), 120.0, 0.35)
	assert_eq(tips.size(), 2, "Tanken + Radar")
	assert_true(tips[0].contains("Tankspur") and tips[0].contains("unter 60 km/h"), "Tankspur-Regel: " + tips[0])
	assert_true(tips[0].contains("Gas bricht ab"), "Gas bricht ab")
	assert_true(tips[0].contains("35 %"), "Startfüllung der Etappe")
	assert_true(tips[1].contains("15 % Toleranz") and tips[1].contains("Limit 120 km/h") and tips[1].contains("ab 138 km/h"), "Radar-Toleranz: " + tips[1])
	assert_true(tips[1].contains("220 km/h"), "Polizeiflucht")
	var tuned := _cfg_with({"radar": {"tolerance": 0.1}, "fuel": {"lane_trigger_speed_kmh": 50.0}, "police": {"escape_speed_kmh": 210.0}})
	var t2 := UiFormat.tutorial_tips(tuned, 100.0, -1.0)
	assert_true(t2[0].contains("unter 50 km/h"), "Tankspur aus der Konfiguration")
	assert_false(t2[0].contains("startest"), "ohne eigene Startfüllung kein Hinweis")
	assert_true(t2[1].contains("10 % Toleranz") and t2[1].contains("ab 110 km/h") and t2[1].contains("210 km/h"), "Radar aus der Konfiguration: " + t2[1])
	assert_near(UiFormat.radar_trigger_kmh(120.0, cfg()), 138.0, 0.001, "Auslöseschwelle wie PoliceSystem")


func test_tow_text_matches_mechanic() -> void:
	var t := UiFormat.tow_text(0.5)
	assert_true(t.contains("halben Tank"), "Sprit für einen halben Tank: " + t)
	assert_false(t.contains("Tankstelle"), "kein Transport zur Tankstelle")
	assert_true(UiFormat.tow_text(0.4).contains("40 %"), "andere Füllung aus der Konfiguration")
	assert_true(UiFormat.tow_text(1.0).contains("vollen Tank"), "voller Tank")


func test_station_distance_here() -> void:
	assert_eq(UiFormat.station_distance(0.0), "hier", "an der Tankstelle")
	assert_eq(UiFormat.station_distance(-1.0), "keine mehr", "keine Tankstelle mehr")
	assert_eq(UiFormat.station_distance(1.43), "1,4 km", "Entfernung")


func test_placement_headline() -> void:
	assert_eq(UiFormat.placement_headline(true, 3, 1, "Kompakt"), "RENNEN-TOP-10 – PLATZ 3!", "Gesamtliste")
	assert_eq(UiFormat.placement_headline(true, 0, 3, "Kompakt"), "RENNEN-TOP-10 KOMPAKT – PLATZ 3!", "nur Fahrzeugliste, benannt")
	assert_eq(UiFormat.placement_headline(false, 0, 2, "Kombi"), "TOP 10 KOMBI – PLATZ 2!", "Etappe, nur Fahrzeugliste")
	assert_eq(UiFormat.placement_headline(false, 7, 2, "Kombi"), "TOP 10 – PLATZ 7!", "Etappe, Gesamtliste")


func test_entry_index_finds_submitted_entry() -> void:
	var entry := {"name": "Vonly", "time_s": 1740.18, "vehicle": "kompakt"}
	var list: Array = [{"name": "Frank", "time_s": 1327.27}, {"name": "Vonly", "time_s": 1740.18}]
	assert_eq(UiData.entry_index(list, entry), 1, "gefunden")
	assert_eq(UiData.entry_index([{"name": "Vonly", "time_s": 1740.5}], entry), -1, "andere Zeit")
	assert_eq(UiData.entry_index([], entry), -1, "leere Liste")


func test_default_filter_from_config() -> void:
	var c := cfg()
	assert_eq(UiData.effective_filter(c, null), str(ConfigLoader.lookup(c, "leaderboard.default_filter", "all")), "ohne Wahl: Konfiguration")
	var tuned := _cfg_with({"leaderboard": {"default_filter": "kombi"}})
	assert_eq(UiData.effective_filter(tuned, null), "kombi", "default_filter wirkt")
	assert_eq(UiData.effective_filter(tuned, "all"), "all", "gespeicherte Wahl gewinnt")
	assert_eq(UiData.effective_filter(tuned, "sportwagen"), "sportwagen", "gespeichertes Fahrzeug")
	assert_eq(UiData.effective_filter(tuned, "trabant"), "kombi", "unbekannter Filter -> Standard")
	assert_eq(UiData.effective_filter(_cfg_with({"leaderboard": {"default_filter": "xyz"}}), null), "all", "ungültiger Standard -> all")


func test_leaderboard_icons_next_to_time() -> void:
	var t := LeaderboardTable.new()
	t.set_entries([{"name": "Jörg", "time_s": 272.73, "vehicle": "gran_turismo"}, {"name": "Elif", "time_s": 4021.5, "vehicle": "kompakt"}])
	var mono := UiTheme.font(UiTheme.F.MONO)
	for w in [500.0, 556.0, 690.0]:
		var c := t.columns(w)
		var tw := mono.get_string_size(UiFormat.time(4021.5), HORIZONTAL_ALIGNMENT_LEFT, -1, LeaderboardTable.TIME_FS).x
		var gap := float(c["icons"]) - (float(c["time"]) + tw)
		assert_between(gap, 0.0, 16.0, "Symbole direkt neben der längsten Zeit (w=%d)" % w)
		assert_true(float(c["avg"]) > float(c["icons"]) + 46.0, "Ø km/h nach den Symbolen")
		assert_true(float(c["vehicle"]) > float(c["avg"]), "Fahrzeug danach")
		assert_true(float(c["vehicle"]) + 80.0 <= w, "Platz für den Fahrzeugnamen (w=%d)" % w)
		assert_true(float(c["time"]) >= 134.0, "Platz für Namen")
	t.free()
