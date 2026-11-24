extends TestCase
## Race progression (RaceState): legs, totals, next stage world time = end + 8 h (since v0.7.0, before 12 h), waypoint
## advance, ferry legs, save round trip, conversion of a race saved with another time-lapse factor, weather modes, route
## enumeration.

const RACE := {"id": "tour", "name": "Kiel – Nürnberg", "start": "kiel", "finish": "nuernberg", "waypoints": ["kassel"]}


## Shipped time-lapse factor (time.time_scale, 10 since v0.7.0).
func _ts() -> float:
	return float(ConfigLoader.lookup(cfg(), "time.time_scale", 10.0))


## A race session result; ts = factor it was measured with (<= 0: the shipped one).
func _result(stage_id: String, from: String, to: String, time_s: float, start_min: float, km: float, ts: float = 0.0, penalty_s: float = 0.0) -> Dictionary:
	var f := ts if ts > 0.0 else _ts()
	return {"stage_id": stage_id, "from_city": from, "to_city": to, "time_s": time_s, "penalty_s": penalty_s,
		"avg_speed_kmh": Units.avg_speed_kmh(km, time_s, f), "distance_km": km, "weather": "rain",
		"start_world_minutes": start_min, "end_world_minutes": start_min + Units.world_minutes_delta(time_s, f),
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
	var t1 := 40.0 * 60.0 / _ts()   # 40 world minutes (factor 10: 240 s)
	var r1 := _result("kiel_hamburg", "kiel", "hamburg", t1, s.world_minutes, 95.0)
	s.apply_stage_result({"kind": "stage", "id": "kiel_hamburg", "from": "kiel", "to": "hamburg", "length_km": 95.0}, r1, c)
	assert_eq(s.current_city, "hamburg", "angekommen")
	assert_eq(s.legs.size(), 1, "eine Etappe")
	assert_near(s.total_time_s, t1, 0.001, "Gesamtzeit")
	assert_near(s.time_scale, _ts(), 0.0001, "Faktor der Zeiten")
	# 40 world minutes of driving; next stage = end + 8 h (design document "Tageszeit und Wetter", since v0.7.0)
	var end_min := 8.0 * 60.0 + 40.0
	assert_near(float(s.legs[0]["end_world_minutes"]), end_min, 0.001, "Ende Weltzeit")
	assert_near(s.world_minutes, end_min + 8.0 * 60.0, 0.001, "nächste Etappe = Ende + 8 h")
	assert_near(s.next_start_hour(), 16.0 + 40.0 / 60.0, 0.001, "Startuhrzeit 16:40")
	var r2 := _result("hamburg_kassel", "hamburg", "kassel", 400.0, s.world_minutes, 300.0)
	s.apply_stage_result({"kind": "stage", "id": "hamburg_kassel", "from": "hamburg", "to": "kassel", "length_km": 300.0}, r2, c)
	assert_near(s.total_time_s, t1 + 400.0, 0.001, "Summe der Etappenzeiten, Pausen zählen nicht")
	assert_near(s.total_distance_km(), 395.0, 0.001, "Distanz")
	assert_near(s.average_kmh(_ts()), Units.avg_speed_kmh(395.0, t1 + 400.0, _ts()), 0.001, "Durchschnitt")
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
	assert_near(s.average_kmh(_ts()), Units.avg_speed_kmh(200.0, 300.0, _ts()), 0.001, "Schnitt ohne Fährzeit")
	assert_true(s.is_finished(), "fertig")


## v0.7.0: the fuel at the finish of a stage is the fuel at the start of the next one – kept across a ferry, in the
## save game and in the leg record; unknown (-1) in a new race and in a save from v0.6.0 (the next stage starts
## with the stage's own filling once).
func test_fuel_carries_over() -> void:
	var c := cfg()
	var race := {"id": "r", "start": "warschau", "finish": "kiel", "waypoints": []}
	var s := RaceState.create(race, "kombi", 10.0, 3)
	assert_eq(s.fuel_l, -1.0, "neues Rennen: Startfüllung der Etappe")
	var r1 := _result("wr", "warschau", "riga", 300.0, s.world_minutes, 200.0)
	r1["fuel_start_l"] = 70.0
	r1["fuel_end_l"] = 23.4
	s.apply_stage_result({"id": "wr", "from": "warschau", "to": "riga"}, r1, c)
	assert_near(s.fuel_l, 23.4, 0.0001, "Tank im Ziel = Tank der nächsten Etappe")
	assert_near(float(s.legs[0]["fuel_start_l"]), 70.0, 0.0001, "Leg: Tank am Start")
	assert_near(float(s.legs[0]["fuel_end_l"]), 23.4, 0.0001, "Leg: Tank im Ziel")
	s.apply_ferry({"id": "riga_rostock", "from": "riga", "to": "rostock", "fixed_time_s": 240.0, "world_hours": 24.0},
		{"kind": "ferry", "id": "riga_rostock", "from": "riga", "to": "rostock"})
	assert_near(s.fuel_l, 23.4, 0.0001, "die Fähre ändert den Tank nicht")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var back := RaceState.from_dict(saved, race)
	assert_near(back.fuel_l, 23.4, 0.0001, "gespeichert und geladen")
	var old := s.to_dict()
	old.erase("fuel_l")
	assert_eq(RaceState.from_dict(old, race).fuel_l, -1.0, "Spielstand aus v0.6.0: unbekannt")
	s.apply_stage_result({"id": "rk", "from": "rostock", "to": "kiel"}, _result("rk", "rostock", "kiel", 300.0, s.world_minutes, 200.0), c)
	assert_eq(s.fuel_l, -1.0, "Ergebnis ohne Tankangabe: unbekannt")


## v0.7.0: the race's last stage (its tank goes into no further stage – GameFlow.stage_setup "last_stage").
func test_finishes_race() -> void:
	var c := cfg()
	var s := RaceState.create(RACE, "kombi", 8.0, 1)
	assert_false(s.finishes_race({"from": "kiel", "to": "nuernberg"}), "Pflichtziel Kassel fehlt noch")
	assert_false(s.finishes_race({"from": "kiel", "to": "kassel"}), "Kassel ist nicht das Ziel")
	s.apply_stage_result({"id": "b", "from": "kiel", "to": "kassel"}, _result("b", "kiel", "kassel", 100.0, s.world_minutes, 90.0), c)
	assert_true(s.finishes_race({"from": "kassel", "to": "nuernberg"}), "Kassel erreicht: nach Nürnberg ist Schluss")
	var tour := RaceState.create({"id": "t", "start": "kiel", "finish": "kiel", "waypoints": ["hamburg"]}, "kombi", 8.0, 1)
	assert_false(tour.finishes_race({"from": "kiel", "to": "hamburg"}), "Rundkurs: die erste Etappe endet ihn nicht")


func test_save_round_trip() -> void:
	var c := cfg()
	var s := RaceState.create(RACE, "limousine", 23.5, 99)
	s.apply_stage_result({"id": "a", "from": "kiel", "to": "hamburg"}, _result("a", "kiel", "hamburg", 123.4, s.world_minutes, 95.0), c)
	var json := JSON.stringify(s.to_dict())
	var back: Dictionary = JSON.parse_string(json)
	for k in ["race_id", "vehicle", "start_hour", "current_city", "waypoint_index", "legs", "total_time_s", "world_minutes", "route", "seed", "time_scale", "legacy_legs"]:
		assert_true(back.has(k), "Schlüssel " + k)
	assert_eq(int(back["version"]), RaceState.VERSION, "Version")
	var r := RaceState.from_dict(back, RACE, _ts())
	assert_eq(r.current_city, "hamburg", "Stadt")
	assert_eq(r.vehicle, "limousine", "Fahrzeug")
	assert_near(r.total_time_s, 123.4, 0.001, "Gesamtzeit")
	assert_near(r.world_minutes, s.world_minutes, 0.001, "Weltzeit")
	assert_eq(r.legs.size(), 1, "Legs")
	assert_eq(r.seed, 99, "Seed")
	assert_eq(r.next_target(), "kassel", "Ziel")
	assert_eq(r.stage_seed("x"), s.stage_seed("x"), "deterministischer Etappen-Seed")
	assert_near(r.time_scale, _ts(), 0.0001, "Faktor gespeichert, nichts umgerechnet")
	assert_near(float(r.legs[0]["time_s"]), 123.4, 0.0001, "gleicher Faktor: Etappenzeit unverändert")
	assert_eq(r.legacy_legs, 0, "Rennen von v0.7.0: keine Etappen nach alten Regeln")


## v0.7.0: time-lapse factor 10 instead of 12. A race saved by v0.6.0 (no "time_scale" = factor 12) continues with its
## times converted: stage times and penalties × 12/10, the average stays, the ferry keeps its fixed 240 s, the next
## start stays at the world time already shown (12-h pause). The pending stage result (closed at the name prompt) is
## converted with the same ratio. Works in both directions (time_scale override), a save at the current factor stays.
## Such a save has no tank either (fuel_l): its next stage starts with the stage's own filling once (lead decision v0.7.0).
func test_saved_race_converted_to_new_time_scale() -> void:
	var c12 := ConfigLoader.deep_merge(cfg(), {"time": {"time_scale": 12.0, "stage_pause_hours": 12.0}})
	var race := {"id": "r", "name": "Riga – Kiel", "start": "riga", "finish": "kiel", "waypoints": []}
	var s := RaceState.create(race, "kombi", 10.0, 3)
	s.apply_ferry({"id": "riga_rostock", "from": "riga", "to": "rostock", "fixed_time_s": 240.0, "world_hours": 24.0},
		{"kind": "ferry", "id": "riga_rostock", "from": "riga", "to": "rostock"})
	var res := _result("rl", "rostock", "luebeck", 300.0, s.world_minutes, 150.0, 12.0, 30.0)
	s.apply_stage_result({"id": "rl", "from": "rostock", "to": "luebeck"}, res, c12)
	var old_avg := s.average_kmh(12.0)
	var d := s.to_dict()
	d.erase("time_scale")   # as v0.6.0 saved it
	d.erase("fuel_l")
	d["version"] = 1
	assert_near(RaceState.saved_time_scale(d), 12.0, 0.0001, "Spielstand ohne Faktor: 12")
	var r := RaceState.from_dict(d, race, 10.0)
	assert_near(r.time_scale, 10.0, 0.0001, "umgerechnet auf Faktor 10")
	assert_eq(r.fuel_l, -1.0, "Spielstand aus v0.6.0 ohne Tank: die nächste Etappe startet einmal mit eigener Füllung")
	# QA v0.7.0: its stage ran under the rules of v0.6.0 (full tank, 12 h pause) – marked, so the race stays off the
	# new race board; the mark survives saving and further stages
	assert_eq(r.legacy_legs, 1, "eine Etappe nach den Regeln von v0.6.0")
	assert_eq(RaceState.from_dict(r.to_dict(), race, 10.0).legacy_legs, 1, "Markierung gespeichert")
	var later := RaceState.from_dict(r.to_dict(), race, 10.0)
	later.apply_stage_result({"id": "lk", "from": "luebeck", "to": "kiel"}, _result("lk", "luebeck", "kiel", 100.0, later.world_minutes, 80.0, 10.0), cfg())
	assert_eq(RaceState.from_dict(later.to_dict(), race, 10.0).legacy_legs, 1, "neue Etappen ändern die Markierung nicht")
	assert_near(float(r.legs[1]["time_s"]), 360.0, 0.001, "Etappenzeit × 12/10")
	assert_near(float(r.legs[1]["penalty_s"]), 36.0, 0.001, "Strafzeit × 12/10")
	assert_near(float(r.legs[1]["avg_kmh"]), float(res["avg_speed_kmh"]), 0.0001, "Etappenschnitt unverändert")
	assert_near(float(r.legs[0]["time_s"]), 240.0, 0.0001, "Fähre: feste Zeit bleibt")
	assert_near(r.total_time_s, 600.0, 0.001, "Gesamtzeit neu summiert")
	assert_near(r.average_kmh(10.0), old_avg, 0.0001, "Rennschnitt unverändert")
	assert_near(r.world_minutes, s.world_minutes, 0.0001, "nächster Start bleibt")
	assert_near(float(r.legs[1]["end_world_minutes"]), float(s.legs[1]["end_world_minutes"]), 0.0001, "Weltzeiten bleiben")
	var pending := RaceState.rescaled_result(res, RaceState.saved_time_scale(d) / 10.0)
	assert_near(float(pending["time_s"]), 360.0, 0.001, "offenes Etappenergebnis umgerechnet")
	assert_near(float(pending["penalty_s"]), 36.0, 0.001, "offenes Ergebnis: Strafzeit")
	assert_near(float(pending["avg_speed_kmh"]), float(res["avg_speed_kmh"]), 0.0001, "offenes Ergebnis: Schnitt bleibt")
	# saved again (version 2 with its factor): loading it again changes nothing, the way back gives the old times
	var again := RaceState.from_dict(r.to_dict(), race, 10.0)
	assert_near(float(again.legs[1]["time_s"]), 360.0, 0.001, "zweites Laden: unverändert")
	var back := RaceState.from_dict(r.to_dict(), race, 12.0)
	assert_near(float(back.legs[1]["time_s"]), 300.0, 0.001, "zurück auf Faktor 12")
	assert_near(back.total_time_s, 540.0, 0.001, "zurück: Gesamtzeit")
	# a stage driven with another factor converts the earlier ones first – a race total never mixes factors
	var mixed := RaceState.from_dict(d, race)
	assert_near(mixed.time_scale, 12.0, 0.0001, "ohne Zielfaktor: nichts umgerechnet")
	mixed.apply_stage_result({"id": "lk", "from": "luebeck", "to": "kiel"}, _result("lk", "luebeck", "kiel", 100.0, mixed.world_minutes, 80.0, 10.0), cfg())
	assert_near(mixed.total_time_s, 240.0 + 360.0 + 100.0, 0.001, "neue Etappe mit Faktor 10, frühere umgerechnet")
	assert_true(RaceState.saved_time_scale(RaceState.create(race, "kombi", 8.0, 1).to_dict()) == 0.0, "neues Rennen ohne Etappe: kein Faktor nötig")


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
