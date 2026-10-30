extends TestCase
## Core conventions: time-lapse, units, config, stage plan rules (design document tables).


func test_time_table_from_design_document() -> void:
	var ts := float(ConfigLoader.lookup(cfg(), "time.time_scale", 0.0))
	assert_eq(ts, 12.0, "Zeitraffer-Faktor")
	assert_near(Units.game_seconds_for(100.0, 100.0, ts), 300.0, 0.01, "100 km bei 100 km/h = 5:00")
	assert_near(Units.game_seconds_for(100.0, 160.0, ts), 187.5, 0.01, "100 km bei 160 km/h = 3:08")
	assert_near(Units.game_seconds_for(100.0, 250.0, ts), 120.0, 0.01, "100 km bei 250 km/h = 2:00")
	assert_near(Units.game_seconds_for(60.0, 100.0, ts), 180.0, 0.01, "60 km bei 100 km/h = 3:00")
	assert_near(Units.game_seconds_for(90.0, 250.0, ts), 108.0, 0.01, "90 km bei 250 km/h = 1:48")


func test_avg_speed_matches_speedometer() -> void:
	assert_near(Units.avg_speed_kmh(100.0, 300.0, 12.0), 100.0, 0.001, "Durchschnitt")
	assert_near(Units.odometer_km_delta(250.0, 1.0, 12.0), 250.0 * 12.0 / 3600.0, 0.0001, "km pro Sekunde")


func test_format() -> void:
	assert_eq(Units.format_race_time(187.5), "3:07.50", "Zeitformat")
	assert_eq(Units.format_race_time(3725.25), "1:02:05.2", "Zeitformat Stunden")
	assert_eq(Units.format_clock(7.5 * 60.0 + 1440.0), "07:30", "Uhr")


func test_config_override_merge() -> void:
	var merged := ConfigLoader.deep_merge({"a": {"b": 1, "c": 2}}, {"a": {"c": 5}})
	assert_eq(merged["a"]["b"], 1, "unverändert")
	assert_eq(merged["a"]["c"], 5, "überschrieben")


func test_stage_plan_rules_and_reverse() -> void:
	var stage := {
		"id": "t", "from": "a", "to": "b", "length_km": 200,
		"sections": [{"length_km": 120, "road": "autobahn", "country": "DE", "speed_limit": null}, {"length_km": 80, "road": "autobahn", "country": "NL"}],
		"fuel_stations_km": [40, 110, 190],
		"radars": [{"km": 30, "limit": 120}, {"km": 160, "limit": 100}],
		"tunnels": [{"km": 50, "length_km": 3}],
		"borders": [{"km": 120, "to": "NL"}],
	}
	var countries := {"DE": {"limits": {"autobahn": null, "city": 50}}, "NL": {"name": "Niederlande", "name_local": "Nederland", "limits": {"autobahn": 100, "city": 50}}}
	var cities := {"a": {"name": "A", "country": "DE"}, "b": {"name": "B", "country": "NL"}}
	var p := StagePlan.build(stage, "a", cities, countries, cfg())
	assert_eq(p.city_limits_km, 180.0, "City Limits = letzte 20 km")
	assert_eq(p.fuel_stations_km.size(), 2, "Tankstelle bei km 190 (in den letzten 25 km) verworfen")
	assert_eq(p.radars.size(), 1, "Radar bei km 160 (in den letzten 30 km vor den City Limits) verworfen")
	assert_eq(p.speed_limit_at(10.0), 0, "Autobahn ohne Limit")
	assert_eq(p.speed_limit_at(150.0), 100, "NL-Standardlimit")
	assert_eq(p.borders.size(), 1, "eine Grenze")
	assert_eq(p.borders[0]["to"], "NL", "nach NL")
	var r := StagePlan.build(stage, "b", cities, countries, cfg())
	assert_true(r.reversed, "Rückrichtung")
	assert_eq(r.from_name, "B", "Start B")
	assert_near(float(r.tunnels[0]["start_km"]), 147.0, 0.01, "Tunnel gespiegelt")
	assert_eq(r.borders[0]["to"], "DE", "Grenze nach DE")
	assert_near(float(r.borders[0]["km"]), 80.0, 0.01, "Grenze gespiegelt")
	for s in r.fuel_stations_km:
		assert_true(s <= 175.0, "Rückrichtung: keine Tankstelle in den letzten 25 km")


func test_projection_visible_fraction() -> void:
	var pr := RoadProjection.new()
	pr.setup(ConfigLoader.lookup(cfg(), "render", {}), Vector2(1280, 720))
	assert_eq(pr.visible_fraction(0.1, 1.5), 0.0, "hinter der Kamera unsichtbar")
	assert_near(pr.visible_fraction(60.0, 1.5), 1.0, 0.001, "weit vorn ganz sichtbar")
	assert_true(pr.visible_fraction(2.5, 1.5) < 0.34, "knapp vor der Kamera nur teilweise sichtbar")
	assert_true(pr.visible_fraction(3.2, 1.5) > 0.34, "etwas weiter vorn mehr als ein Drittel sichtbar")
