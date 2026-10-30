extends TestCase
## UI text formatting: German decimals, deltas, start time steps, marquee text, pace delta.


func test_decimal_and_units() -> void:
	assert_eq(UiFormat.decimal(12.46, 1), "12,5", "Dezimalkomma")
	assert_eq(UiFormat.decimal(0.04, 1), "0,0", "klein")
	assert_eq(UiFormat.decimal(-0.4, 1), "-0,4", "negativ unter 1")
	assert_eq(UiFormat.decimal(11250.0, 0), "11.250", "Tausenderpunkt")
	assert_eq(UiFormat.decimal(1250.0, 0), "1250", "vierstellig ohne Punkt")
	assert_eq(UiFormat.km(8.04, 1), "8,0 km", "km")
	assert_eq(UiFormat.kmh(187.6), "188 km/h", "km/h")
	assert_eq(UiFormat.liters(33.6), "34 L", "Liter")
	assert_eq(UiFormat.grouped(-12345), "-12.345", "negativ gruppiert")


func test_time_and_delta() -> void:
	assert_eq(UiFormat.time(187.5), "3:07.50", "Zeit")
	assert_eq(UiFormat.delta(2.31), "+0:02.31", "Delta positiv")
	assert_eq(UiFormat.delta(-61.5), "-1:01.50", "Delta negativ")
	assert_eq(UiFormat.delta_short(2.314), "+2.31", "kurzes Delta")
	assert_eq(UiFormat.delta_short(-75.0), "-1:15.00", "kurzes Delta > 1 min")
	assert_eq(UiFormat.delta_short(NAN), "--", "kein Delta")


func test_start_time_steps() -> void:
	var steps := UiFormat.start_time_steps(30)
	assert_eq(steps.size(), 48, "00:00–23:30 in 30-min-Schritten")
	assert_eq(steps[0], 0, "erster Schritt")
	assert_eq(steps[-1], 23 * 60 + 30, "letzter Schritt 23:30")
	assert_eq(UiFormat.clock_hour(23.5), "23:30", "Uhrzeit")
	assert_eq(UiFormat.clock_hour(0.0), "00:00", "Mitternacht")


func test_marquee_text() -> void:
	var rec := {"name": "Anke", "time_s": 225.1, "avg_kmh": 187.4, "vehicle": "sportwagen", "date": "2026-10-30"}
	var txt := UiFormat.marquee_text(rec, "Kiel – Hamburg", cfg())
	assert_true(txt.contains("Anke"), "Name in der Laufschrift")
	assert_true(txt.contains("3:45.10"), "Zeit in der Laufschrift")
	assert_true(txt.contains("187 km/h"), "Durchschnitt in der Laufschrift")
	assert_true(txt.contains("Sportwagen"), "Fahrzeug")
	assert_true(txt.contains("30.10.2026"), "Datum deutsch")
	var empty := UiFormat.marquee_text({}, "Kiel – Hamburg", cfg())
	assert_true(empty.contains("Kiel – Hamburg") and empty.contains("kein Rekord"), "ohne Rekord")


func test_pace_delta() -> void:
	assert_near(UiFormat.pace_delta(110.0, 200.0, 50.0, 100.0), 10.0, 0.001, "10 s hinter Rekordtempo")
	assert_near(UiFormat.pace_delta(90.0, 200.0, 50.0, 100.0), -10.0, 0.001, "10 s vor Rekordtempo")
	assert_true(is_nan(UiFormat.pace_delta(90.0, -1.0, 50.0, 100.0)), "kein Rekord")


func test_names() -> void:
	assert_eq(UiFormat.weather_name("rain"), "Regen", "Regen")
	assert_eq(UiFormat.weather_name("snow"), "Schnee", "Schnee")
	assert_eq(UiFormat.daytime_name("dusk"), "Abenddämmerung", "Dämmerung")
	assert_eq(UiFormat.vehicle_name("gran_turismo", cfg()), "Gran Turismo", "Fahrzeugname")
	assert_eq(UiFormat.vehicle_name("all", cfg()), "Alle Fahrzeuge", "Filter alle")
	assert_eq(UiFormat.traffic_level(1.0), "mittel", "Verkehr mittel")
	assert_eq(UiFormat.traffic_level(1.6), "sehr hoch", "Verkehr sehr hoch")
	assert_eq(UiFormat.date_de("2026-01-05T10:00:00"), "05.01.2026", "Datum")
	assert_eq(UiFormat.countries_chain(["DE", "NL"]), "DE › NL", "Länderkette")
