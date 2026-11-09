extends TestCase
## Core conventions: time-lapse, units, config, stage plan rules (design document tables).


## Design document "Zeit und Strecke" (since v0.7.0 factor 10, 1 hour world time = 6 game minutes; until v0.6.0 factor 12).
func test_time_table_from_design_document() -> void:
	var ts := float(ConfigLoader.lookup(cfg(), "time.time_scale", 0.0))
	assert_eq(ts, 10.0, "Zeitraffer-Faktor")
	assert_near(Units.game_seconds_for(100.0, 100.0, ts), 360.0, 0.01, "100 km bei 100 km/h = 6:00")
	assert_near(Units.game_seconds_for(100.0, 160.0, ts), 225.0, 0.01, "100 km bei 160 km/h = 3:45")
	assert_near(Units.game_seconds_for(100.0, 250.0, ts), 144.0, 0.01, "100 km bei 250 km/h = 2:24")
	assert_near(Units.game_seconds_for(60.0, 100.0, ts), 216.0, 0.01, "60 km bei 100 km/h = 3:36")
	assert_near(Units.game_seconds_for(90.0, 250.0, ts), 129.6, 0.01, "90 km bei 250 km/h = 2:10")
	assert_near(Units.world_minutes_delta(360.0, ts), 60.0, 0.0001, "1 Stunde Weltzeit = 6 Spielminuten")


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


## v0.7.0: fuel stations per driving direction – {"km", "dir"} counts only in that direction (km from 'from' like
## radars, mirrored in reverse), a number in both. A station a few km after the start of one direction lies in the
## other direction's City Limits: it is skipped before the drop (no warning); an unknown direction counts for both.
func test_stage_plan_fuel_stations_per_direction() -> void:
	var stage := {
		"id": "t", "from": "a", "to": "b", "length_km": 150,
		"sections": [{"length_km": 150, "road": "autobahn", "country": "DE"}],
		"fuel_stations_km": [{"km": 12, "dir": "fwd"}, {"km": 64, "dir": "rev"}, {"km": 86, "dir": "fwd"}, {"km": 141.5, "dir": "rev"}],
	}
	var countries := {"DE": {"limits": {"autobahn": null, "city": 50}}}
	var cities := {"a": {"name": "A", "country": "DE"}, "b": {"name": "B", "country": "DE"}}
	var p := StagePlan.build(stage, "a", cities, countries, cfg())
	assert_eq(p.fuel_stations_km, [12.0, 86.0] as Array[float], "vorwärts nur die fwd-Tankstellen")
	assert_eq(p.fuel_lanes.size(), 2, "je Tankstelle eine Tankspur")
	assert_true(p.warnings.is_empty(), "vorwärts ohne Warnung: %s" % str(p.warnings))
	var r := StagePlan.build(stage, "b", cities, countries, cfg())
	assert_eq(r.fuel_stations_km, [8.5, 86.0] as Array[float], "rückwärts die rev-Tankstellen, gespiegelt (150 − 141,5; 150 − 64)")
	assert_true(r.warnings.is_empty(), "die fwd-Tankstelle bei km 12 landet nicht in den City Limits der Rückrichtung: %s" % str(r.warnings))
	stage["fuel_stations_km"] = [60, {"km": 10, "dir": "fwd"}]
	assert_eq(StagePlan.build(stage, "a", cities, countries, cfg()).fuel_stations_km, [10.0, 60.0] as Array[float], "Zahl = beide Richtungen")
	assert_eq(StagePlan.build(stage, "b", cities, countries, cfg()).fuel_stations_km, [90.0] as Array[float], "rückwärts nur die Zahl")
	stage["fuel_stations_km"] = [{"km": 70, "dir": "hin"}]
	var u := StagePlan.build(stage, "b", cities, countries, cfg())
	assert_eq(u.fuel_stations_km, [80.0] as Array[float], "unbekannte Richtung gilt in beiden")
	assert_true(str(u.warnings).contains("unbekannter Richtung"), "mit Warnung")
	# without a list (old or test data): generated from the seed, the first one 5–20 km after the start
	stage.erase("fuel_stations_km")
	stage["length_km"] = 300
	stage["sections"] = [{"length_km": 300, "road": "autobahn", "country": "DE"}]
	for from_id in ["a", "b"]:
		var g := StagePlan.build(stage, from_id, cities, countries, cfg())
		assert_between(g.fuel_stations_km[0], float(ConfigLoader.lookup(cfg(), "fuel.first_station_min_km", 5.0)),
			float(ConfigLoader.lookup(cfg(), "fuel.first_station_max_km", 20.0)), "erzeugt ab %s: erste Tankstelle nach 5–20 km" % from_id)
		assert_true(g.warnings.is_empty(), "erzeugt ab %s ohne Warnung" % from_id)


func test_projection_visible_fraction() -> void:
	var pr := RoadProjection.new()
	pr.setup(ConfigLoader.lookup(cfg(), "render", {}), Vector2(1280, 720))
	assert_eq(pr.visible_fraction(0.1, 1.5), 0.0, "hinter der Kamera unsichtbar")
	assert_near(pr.visible_fraction(60.0, 1.5), 1.0, 0.001, "weit vorn ganz sichtbar")
	# the visible share grows monotonically with depth and passes 1/3 a few metres ahead of the camera
	var prev := 0.0
	var third_at := -1.0
	for i in range(1, 400):
		var dz := i * 0.05
		var f := pr.visible_fraction(dz, 1.5)
		assert_true(f >= prev - 0.0001, "monoton bei dz=%.2f" % dz)
		prev = f
		if third_at < 0.0 and f >= 1.0 / 3.0:
			third_at = dz
	assert_between(third_at, 1.0, pr.cam_distance, "ein Drittel sichtbar zwischen Kamera und Spielerauto")
