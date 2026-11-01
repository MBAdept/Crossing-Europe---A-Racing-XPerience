extends TestCase
## Race progression (RaceState): legs, totals, next stage world time = end + 12 h, waypoint advance,
## ferry legs, save round trip, weather modes, route enumeration.

const RACE := {"id": "tour", "name": "Kiel – Nürnberg", "start": "kiel", "finish": "nuernberg", "waypoints": ["kassel"]}


func _result(stage_id: String, from: String, to: String, time_s: float, start_min: float, km: float) -> Dictionary:
	return {"stage_id": stage_id, "from_city": from, "to_city": to, "time_s": time_s, "penalty_s": 0.0,
		"avg_speed_kmh": Units.avg_speed_kmh(km, time_s, 12.0), "distance_km": km, "weather": "rain",
		"start_world_minutes": start_min, "end_world_minutes": start_min + Units.world_minutes_delta(time_s, 12.0),
		"stage_name": "%s – %s" % [from, to], "daytime": "day"}


func test_create_initial_state() -> void:
	var s := RaceState.create(RACE, "sportwagen", 8.5, 42)
	assert_eq(s.current_city, "kiel", "Startstadt")
	assert_eq(s.route, ["kiel"] as Array[String], "Route beginnt mit Start")
	assert_near(s.world_minutes, 8.5 * 60.0, 0.001, "Weltzeit = Startuhrzeit")
	assert_eq(s.next_target(), "kassel", "erstes Pflichtziel")
	assert_eq(s.next_stage_number(), 1, "Etappe 1")
	assert_false(s.is_finished(), "nicht fertig")


func test_stage_legs_totals_and_pause() -> void:
	var c := cfg()
	var s := RaceState.create(RACE, "kombi", 8.0, 1)
	var r1 := _result("kiel_hamburg", "kiel", "hamburg", 200.0, s.world_minutes, 95.0)
	s.apply_stage_result({"kind": "stage", "id": "kiel_hamburg", "from": "kiel", "to": "hamburg", "length_km": 95.0}, r1, c)
	assert_eq(s.current_city, "hamburg", "angekommen")
	assert_eq(s.legs.size(), 1, "eine Etappe")
	assert_near(s.total_time_s, 200.0, 0.001, "Gesamtzeit")
	# 200 s game time = 40 world minutes; next stage = end + 12 h
	var end_min := 8.0 * 60.0 + 40.0
	assert_near(float(s.legs[0]["end_world_minutes"]), end_min, 0.001, "Ende Weltzeit")
	assert_near(s.world_minutes, end_min + 12.0 * 60.0, 0.001, "nächste Etappe = Ende + 12 h")
	assert_near(s.next_start_hour(), 20.0 + 40.0 / 60.0, 0.001, "Startuhrzeit 20:40")
	var r2 := _result("hamburg_kassel", "hamburg", "kassel", 400.0, s.world_minutes, 300.0)
	s.apply_stage_result({"kind": "stage", "id": "hamburg_kassel", "from": "hamburg", "to": "kassel", "length_km": 300.0}, r2, c)
	assert_near(s.total_time_s, 600.0, 0.001, "Summe der Etappenzeiten, Pausen zählen nicht")
	assert_near(s.total_distance_km(), 395.0, 0.001, "Distanz")
	assert_near(s.average_kmh(12.0), Units.avg_speed_kmh(395.0, 600.0, 12.0), 0.001, "Durchschnitt")
	assert_eq(s.next_stage_number(), 3, "Etappe 3")


func test_waypoint_advance_and_finish() -> void:
	var c := cfg()
	var s := RaceState.create(RACE, "kombi", 8.0, 1)
	s.apply_stage_result({"id": "a", "from": "kiel", "to": "hamburg"}, _result("a", "kiel", "hamburg", 100.0, s.world_minutes, 90.0), c)
	assert_eq(s.waypoint_index, 0, "Hamburg ist kein Pflichtziel")
	s.apply_stage_result({"id": "b", "from": "hamburg", "to": "kassel"}, _result("b", "hamburg", "kassel", 100.0, s.world_minutes, 90.0), c)
	assert_eq(s.waypoint_index, 1, "Kassel erreicht -> nächstes Ziel")
	assert_eq(s.next_target(), "nuernberg", "jetzt das Ziel")
	assert_false(s.is_finished(), "noch nicht am Ziel")
	s.apply_stage_result({"id": "c", "from": "kassel", "to": "nuernberg"}, _result("c", "kassel", "nuernberg", 100.0, s.world_minutes, 90.0), c)
	assert_true(s.is_finished(), "Ziel erreicht")
	assert_eq(s.route, ["kiel", "hamburg", "kassel", "nuernberg"] as Array[String], "Route")


func test_finish_reached_early_without_waypoint_is_not_finished() -> void:
	var c := cfg()
	var s := RaceState.create(RACE, "kombi", 8.0, 1)
	s.apply_stage_result({"id": "x", "from": "kiel", "to": "nuernberg"}, _result("x", "kiel", "nuernberg", 100.0, s.world_minutes, 90.0), c)
	assert_false(s.is_finished(), "Pflichtziel Kassel fehlt noch")


func test_tour_start_equals_finish() -> void:
	var c := cfg()
	var tour := {"id": "tour", "start": "kiel", "finish": "kiel", "waypoints": ["hamburg"]}
	var s := RaceState.create(tour, "kombi", 8.0, 1)
	assert_false(s.is_finished(), "Rundkurs: am Start nicht fertig")
	s.apply_stage_result({"id": "a", "from": "kiel", "to": "hamburg"}, _result("a", "kiel", "hamburg", 100.0, s.world_minutes, 90.0), c)
	s.apply_stage_result({"id": "a", "from": "hamburg", "to": "kiel"}, _result("a", "hamburg", "kiel", 100.0, s.world_minutes, 90.0), c)
	assert_true(s.is_finished(), "Rundkurs beendet")


func test_ferry_leg() -> void:
	var c := cfg()
	var race := {"id": "r", "start": "riga", "finish": "kiel", "waypoints": []}
	var s := RaceState.create(race, "kombi", 10.0, 3)
	var ferry := {"id": "riga_rostock", "from": "riga", "to": "rostock", "name": "Fähre Riga – Rostock", "fixed_time_s": 240.0, "world_hours": 24.0}
	var start := s.world_minutes
	s.apply_ferry(ferry, {"kind": "ferry", "id": "riga_rostock", "from": "riga", "to": "rostock"})
	assert_eq(s.current_city, "rostock", "Fähre angekommen")
	assert_near(s.total_time_s, 240.0, 0.001, "feste Fährzeit zählt zur Rennzeit")
	assert_near(s.world_minutes, start + 24.0 * 60.0, 0.001, "Weltzeit +24 h, nächste Etappe bei Ankunft")
	assert_eq(s.stage_count(), 0, "Fähre ist keine Etappe")
	assert_eq(s.legs[0]["kind"], "ferry", "Fähren-Leg")
	s.apply_stage_result({"id": "rk", "from": "rostock", "to": "kiel"}, _result("rk", "rostock", "kiel", 300.0, s.world_minutes, 200.0), c)
	assert_near(s.total_time_s, 540.0, 0.001, "Fähre + Etappe")
	assert_near(s.average_kmh(12.0), Units.avg_speed_kmh(200.0, 300.0, 12.0), 0.001, "Schnitt ohne Fährzeit")
	assert_true(s.is_finished(), "fertig")


func test_save_round_trip() -> void:
	var c := cfg()
	var s := RaceState.create(RACE, "limousine", 23.5, 99)
	s.apply_stage_result({"id": "a", "from": "kiel", "to": "hamburg"}, _result("a", "kiel", "hamburg", 123.4, s.world_minutes, 95.0), c)
	var json := JSON.stringify(s.to_dict())
	var back: Dictionary = JSON.parse_string(json)
	for k in ["race_id", "vehicle", "start_hour", "current_city", "waypoint_index", "legs", "total_time_s", "world_minutes", "route", "seed"]:
		assert_true(back.has(k), "Schlüssel " + k)
	var r := RaceState.from_dict(back, RACE)
	assert_eq(r.current_city, "hamburg", "Stadt")
	assert_eq(r.vehicle, "limousine", "Fahrzeug")
	assert_near(r.total_time_s, 123.4, 0.001, "Gesamtzeit")
	assert_near(r.world_minutes, s.world_minutes, 0.001, "Weltzeit")
	assert_eq(r.legs.size(), 1, "Legs")
	assert_eq(r.seed, 99, "Seed")
	assert_eq(r.next_target(), "kassel", "Ziel")
	assert_eq(r.stage_seed("x"), s.stage_seed("x"), "deterministischer Etappen-Seed")


func test_weather_modes() -> void:
	var c := cfg()
	var fixed := ConfigLoader.deep_merge(c, {"weather": {"race_mode": "fixed"}})
	assert_eq(RaceState.choose_weather(fixed, "north", "snow", 5), "snow", "fixed = Wetterfeld der Etappe")
	assert_eq(RaceState.choose_weather(fixed, "north", "", 5), "normal", "fixed ohne Feld = normal")
	var region := ConfigLoader.deep_merge(c, {"weather": {"race_mode": "region"}})
	var w := RaceState.choose_weather(region, "mediterranean", "", 7)
	assert_true(["normal", "rain", "snow"].has(w), "region liefert gültiges Wetter")
	assert_eq(RaceState.choose_weather(region, "mediterranean", "", 7), w, "deterministisch")
	var counts := {"normal": 0, "rain": 0, "snow": 0}
	var rnd := ConfigLoader.deep_merge(c, {"weather": {"race_mode": "random"}})
	for i in 300:
		counts[RaceState.choose_weather(rnd, "north", "", i)] += 1
	for k in counts:
		assert_true(int(counts[k]) > 50, "random ~ gleichverteilt: " + k)


## Review v0.5.0: the tutorial stage (Kiel – Hamburg, first stage of the first race) got the race weather – 8 % snow
## in the north – and a first-time player then had half the braking. Now it is always dry (weather.tutorial_weather);
## every other stage keeps the race weather.
func test_tutorial_stage_is_dry() -> void:
	var c := cfg()
	var tut := StagePlan.new()
	tut.stage_id = "kiel_hamburg"
	tut.tutorial = true
	tut.climate = "north"
	var other := StagePlan.new()
	other.stage_id = "hamburg_bremen"
	other.climate = "north"
	var counts := {"normal": 0, "rain": 0, "snow": 0}
	for mode in ["region", "random"]:
		var mc := ConfigLoader.deep_merge(c, {"weather": {"race_mode": mode}})
		for i in 400:
			assert_eq(RaceState.leg_weather(mc, tut, i), "normal", "Tutorial-Etappe trocken (%s, Seed %d)" % [mode, i])
			counts[RaceState.leg_weather(mc, other, i)] += 1
			assert_eq(RaceState.leg_weather(mc, other, i), RaceState.choose_weather(mc, "north", "", i), "andere Etappen: Rennwetter")
	assert_true(int(counts["rain"]) > 100 and int(counts["snow"]) > 20, "andere Etappen weiter mit Regen und Schnee: %s" % str(counts))
	var fixed := ConfigLoader.deep_merge(c, {"weather": {"race_mode": "fixed"}})
	tut.weather_hint = "snow"
	assert_eq(RaceState.leg_weather(fixed, tut, 3), "normal", "auch mit Wetterfeld")
	var off := ConfigLoader.deep_merge(c, {"weather": {"race_mode": "fixed", "tutorial_weather": ""}})
	assert_eq(RaceState.leg_weather(off, tut, 3), "snow", "tutorial_weather leer = Rennwetter")
	var env := EnvironmentModel.new()
	env.setup(c)
	for i in 100:
		assert_eq(env.race_weather(tut, i, 0), "normal", "EnvironmentModel.race_weather: Tutorial trocken")
	# the real network: Kiel – Hamburg is the tutorial stage
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var found := false
	for st: Dictionary in net.get("stages", []):
		if str(st.get("id", "")) == "kiel_hamburg":
			found = bool(st.get("tutorial", false))
	assert_true(found, "Kiel – Hamburg ist die Tutorial-Etappe")


func test_route_enumeration() -> void:
	# kiel - hamburg, then hamburg -> kassel -> nuernberg or hamburg -> frankfurt -> nuernberg (no waypoint)
	var graph := {
		"kiel": [{"kind": "stage", "id": "kh", "to": "hamburg", "length_km": 95.0}],
		"hamburg": [{"kind": "stage", "id": "hk", "to": "kassel", "length_km": 300.0}, {"kind": "stage", "id": "hf", "to": "frankfurt", "length_km": 490.0}],
		"kassel": [{"kind": "stage", "id": "kn", "to": "nuernberg", "length_km": 300.0}, {"kind": "stage", "id": "kf", "to": "frankfurt", "length_km": 190.0}],
		"frankfurt": [{"kind": "stage", "id": "fn", "to": "nuernberg", "length_km": 225.0}, {"kind": "stage", "id": "kf", "to": "kassel", "length_km": 190.0}],
	}
	var fn := func(_race_id: String, city: String, _wp: int, _visited: Array) -> Array:
		var out: Array = []
		for leg in graph.get(city, []):
			var l: Dictionary = (leg as Dictionary).duplicate()
			l["from"] = city
			out.append(l)
		return out
	var race := {"id": "kn", "start": "kiel", "finish": "nuernberg", "waypoints": []}
	var routes := RaceState.enumerate_routes(race, fn)
	assert_eq(routes.size(), 4, "vier Routen ohne Wiederholung")
	var st := RaceState.route_stats(routes)
	assert_near(float(st["min_km"]), 95.0 + 300.0 + 300.0, 0.01, "kürzeste Route")
	assert_near(float(st["max_km"]), 95.0 + 490.0 + 190.0 + 300.0, 0.01, "längste Route")
	assert_eq(int(st["min_stages"]), 3, "min Etappen")
	assert_eq(int(st["max_stages"]), 4, "max Etappen")
	var with_wp := {"id": "kn", "start": "kiel", "finish": "nuernberg", "waypoints": ["frankfurt"]}
	assert_eq(RaceState.enumerate_routes(with_wp, fn).size(), 3, "nur Routen über Frankfurt (H-F-N, H-K-F-N, H-F-K-N)")
	assert_eq(RaceState.enumerate_routes(race, fn, 2).size(), 2, "Begrenzung max_routes")
	var slow := func(rid: String, city: String, wp: int, visited: Array) -> Array:
		OS.delay_msec(4)
		return fn.call(rid, city, wp, visited)
	var t0 := Time.get_ticks_msec()
	RaceState.enumerate_routes(race, slow, 64, 60, 3000, 10.0)
	assert_true(Time.get_ticks_msec() - t0 < 60, "Zeitbudget wird eingehalten")
