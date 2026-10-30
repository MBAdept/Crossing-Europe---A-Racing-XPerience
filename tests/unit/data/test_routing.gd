extends TestCase
## Data module: routing (Dijkstra over stages + ferries, detour tolerance, waypoints, visited cities).

const NetworkTest := preload("res://tests/unit/data/test_network_data.gd")

var _cached: RoadNetwork = null

## Designed route choices: race id -> {city where a choice is offered: number of options}
const DESIGNED_CHOICES := {
	"kiel_nuernberg": {"hamburg": 2},
	"dresden_dortmund": {"leipzig": 2},
	"muenchen_bremen": {"wuerzburg": 2},
	"koenigsrennen": {"saragossa": 2},
}


func net() -> RoadNetwork:
	if _cached == null:
		_cached = NetworkTest.load_network(cfg())
	return _cached


func _to_ids(options: Array) -> Array[String]:
	var out: Array[String] = []
	for o in options:
		out.append(str(o["to"]))
	return out


func test_kiel_nuernberg_choice_at_hamburg() -> void:
	var n := net()
	var start := n.next_options("kiel_nuernberg", "kiel", 0, ["kiel"])
	assert_eq(_to_ids(start), ["hamburg"] as Array[String], "Kiel: nur Hamburg (Tutorial)")
	var opts := n.next_options("kiel_nuernberg", "hamburg", 0, ["kiel", "hamburg"])
	var ids := _to_ids(opts)
	assert_eq(opts.size(), 2, "Hamburg: genau zwei Optionen")
	assert_true(ids.has("hannover") and ids.has("bremen"), "Hamburg: Hannover (Ost) und Bremen (West): %s" % str(ids))
	assert_eq(str(opts[0]["to"]), "hannover", "Ostroute ist die kürzere")
	assert_true(bool(opts[0]["best"]), "beste Option markiert")
	assert_between(float(opts[1]["detour"]), 0.05, float(ConfigLoader.lookup(cfg(), "routing.detour_tolerance", 0.35)), "Westroute: Umweg innerhalb der Toleranz")
	assert_eq(str(opts[0]["board_key"]), "stage:hamburg_hannover:fwd", "Bestenlisten-Schlüssel der Option")
	assert_eq(str(opts[1]["via"][-1]), "nuernberg", "via endet am Ziel")


func test_kiel_nuernberg_two_balanced_routes() -> void:
	var n := net()
	var routes := n.race_routes("kiel_nuernberg")
	assert_eq(routes.size(), 2, "zwei Routen")
	if routes.size() != 2:
		return
	var east: Dictionary = routes[0]
	var west: Dictionary = routes[1]
	assert_true((east["cities"] as Array).has("kassel"), "Ostroute über Kassel")
	assert_true((west["cities"] as Array).has("frankfurt"), "Westroute über Frankfurt")
	assert_between(float(east["km"]), 680.0, 780.0, "Ostroute ca. 730 km")
	assert_between(float(west["km"]), 850.0, 960.0, "Westroute ca. 905 km")
	var es := _route_stats(n, east)
	var ws := _route_stats(n, west)
	assert_true(ws["unlimited_km"] > es["unlimited_km"], "Westroute: mehr Autobahn ohne Limit")
	assert_true(ws["traffic"] > es["traffic"], "Westroute: mehr Verkehr")
	assert_true(ws["radars"] < es["radars"], "Westroute: weniger Radar")
	assert_true(ws["stations"] > es["stations"], "Westroute: mehr Tankstellen")
	assert_true(es["max_hills"] >= 3, "Ostroute: Kasseler Berge / Rhön")


func _route_stats(n: RoadNetwork, route: Dictionary) -> Dictionary:
	var st := {"unlimited_km": 0.0, "traffic": 0.0, "radars": 0, "stations": 0, "max_hills": 0}
	var km := 0.0
	for leg: Dictionary in route["legs"]:
		if str(leg["kind"]) != "stage":
			continue
		var s := n.stage_summary(str(leg["id"]), str(leg["from"]))
		st["unlimited_km"] = float(st["unlimited_km"]) + float(s["unlimited_km"])
		st["traffic"] = float(st["traffic"]) + float(s["traffic"]) * float(s["length_km"])
		st["radars"] = int(st["radars"]) + int(s["radars"])
		st["stations"] = int(st["stations"]) + int(s["stations"])
		st["max_hills"] = maxi(int(st["max_hills"]), int(s["max_hills"]))
		km += float(s["length_km"])
	st["traffic"] = float(st["traffic"]) / maxf(km, 1.0)
	return st


func test_choices_only_where_designed() -> void:
	var n := net()
	for race_id in n.race_order:
		var designed: Dictionary = DESIGNED_CHOICES.get(race_id, {})
		var seen := {}
		for c in n.race_choices(race_id):
			var city := str(c["city"])
			seen[city] = true
			assert_true(designed.has(city), "%s: unerwartete Wahl in %s: %s" % [race_id, city, str(c["options"])])
			if designed.has(city):
				assert_eq((c["options"] as Array).size(), int(designed[city]), "%s: Optionen in %s" % [race_id, city])
		for city: String in designed:
			assert_true(seen.has(city), "%s: Wahl in %s vorhanden" % [race_id, city])


func test_all_races_routable_and_visit_waypoints_in_order() -> void:
	var n := net()
	for race_id in n.race_order:
		var routes := n.race_routes(race_id)
		assert_false(routes.is_empty(), "%s fahrbar" % race_id)
		var race: Dictionary = n.races[race_id]
		for route in routes:
			var cities: Array = route["cities"]
			assert_eq(str(cities[0]), str(race["start"]), "%s: Start" % race_id)
			assert_eq(str(cities[-1]), str(race["finish"]), "%s: Ziel" % race_id)
			var pos := 0
			for w in race["waypoints"]:
				var found := cities.find(str(w), pos)
				assert_true(found >= 0, "%s: Pflichtstation %s in Reihenfolge" % [race_id, str(w)])
				pos = maxi(found, pos)
			for leg: Dictionary in route["legs"]:
				assert_false(n.is_dev_leg(leg), "%s: keine Entwickler-Etappe" % race_id)


func test_koenigsrennen() -> void:
	var n := net()
	var s := n.race_summary("koenigsrennen")
	assert_eq(int(s["routes"]), 2, "zwei Varianten (Küste / Somport)")
	assert_between(float(s["min_km"]), 8800.0, 12500.0, "Gesamtlänge")
	assert_eq(int(s["ferries"]), 1, "eine Fähre")
	assert_true(int(s["min_stages"]) >= 35, "viele Etappen")
	var route: Dictionary = n.race_routes("koenigsrennen")[0]
	var has_ferry := false
	for leg: Dictionary in route["legs"]:
		if str(leg["kind"]) == "ferry":
			has_ferry = true
			assert_eq(str(leg["from"]), "riga", "Fähre ab Riga")
			assert_eq(str(leg["to"]), "rostock", "Fähre nach Rostock")
	assert_true(has_ferry, "Route nutzt die Fähre")
	var countries: Array = s["countries"]
	for c in ["DE", "NL", "BE", "FR", "ES", "CH", "IT", "SI", "HR", "RS", "BG", "HU", "AT", "CZ", "PL", "LT", "LV"]:
		assert_true(countries.has(c), "Königsrennen durch %s" % c)


func test_revisit_allowed_in_new_leg() -> void:
	# Sofia → Budapest drives back through Niš and Belgrad (visited on the way to Sofia).
	var n := net()
	var visited := ["kiel", "mailand", "venedig", "ljubljana", "zagreb", "slavonski_brod", "belgrad", "nis", "sofia"]
	var idx := n.advance_waypoint_index("koenigsrennen", "sofia", 8)
	assert_eq(n.next_target("koenigsrennen", idx), "budapest", "nach Sofia: Budapest")
	var opts := n.next_options("koenigsrennen", "sofia", idx, visited)
	assert_eq(_to_ids(opts), ["nis"] as Array[String], "Sofia → Niš trotz Besuch im vorigen Abschnitt")
	var at_nis := n.next_options("koenigsrennen", "nis", idx, visited + ["nis"])
	assert_eq(_to_ids(at_nis), ["belgrad"] as Array[String], "Niš → Belgrad (Sofia ist gesperrt)")


func test_ferry_leg() -> void:
	var n := net()
	var idx := n.race_targets("koenigsrennen").find("riga")
	var opts := n.next_options("koenigsrennen", "riga", idx, ["warschau", "bialystok", "kaunas", "riga"])
	assert_eq(opts.size(), 1, "in Riga nur die Fähre")
	if opts.size() == 1:
		assert_eq(str(opts[0]["kind"]), "ferry", "Fähre")
		assert_eq(str(opts[0]["to"]), "rostock", "nach Rostock")
		assert_true(float(opts[0]["fixed_time_s"]) > 0.0, "feste Zeit")
		assert_true(float(opts[0]["world_hours"]) > 0.0, "Weltzeit")


func test_waypoint_helpers() -> void:
	var n := net()
	var t := n.race_targets("koenigsrennen")
	assert_eq(t[0], "hamburg", "erstes Ziel")
	assert_eq(t[-1], "kiel", "Ziel = Kiel")
	assert_eq(n.next_target("koenigsrennen", 0), "hamburg", "next_target 0")
	assert_eq(n.next_target("koenigsrennen", t.size()), "", "fertig")
	assert_eq(n.advance_waypoint_index("koenigsrennen", "hamburg", 0), 1, "Hamburg erreicht")
	assert_eq(n.advance_waypoint_index("koenigsrennen", "hannover", 1), 1, "Zwischenstadt ändert nichts")
	assert_false(n.is_race_finished("koenigsrennen", "kiel", 0), "Kiel am Start ist nicht das Ziel")
	assert_true(n.is_race_finished("koenigsrennen", "kiel", t.size() - 1), "Kiel am Ende ist das Ziel")
	assert_true(n.is_race_finished("kiel_nuernberg", "nuernberg", 0), "Nürnberg beendet Kiel – Nürnberg")
	assert_true(n.next_options("kiel_nuernberg", "nuernberg", 0, ["kiel", "hamburg", "hannover", "kassel", "wuerzburg", "nuernberg"]).is_empty(), "keine Optionen nach dem Ziel")


func test_shortest_path_and_board_length() -> void:
	var n := net()
	var p := n.shortest_path("kiel", "nuernberg")
	assert_near(float(p["km"]), 730.0, 0.01, "Kiel → Nürnberg kürzester Weg")
	assert_eq(str(p["cities"][2]), "hannover", "über Hannover")
	assert_near(n.board_length_km("race:kiel_nuernberg"), 730.0, 0.01, "Rennlänge = kürzeste Route")
	assert_near(n.board_length_km("stage:kiel_hamburg:rev"), 95.0, 0.01, "Etappenlänge")
	assert_eq(n.board_length_km("race:gibtsnicht"), 0.0, "unbekanntes Rennen")
	assert_true(is_inf(float(n.shortest_path("kiel", "dev_ziel")["km"])), "Entwickler-Etappe nicht im Netz")


func test_tolerance_from_config() -> void:
	var c := cfg().duplicate(true)
	c["routing"]["detour_tolerance"] = 0.1
	var strict := NetworkTest.load_network(c)
	assert_eq(strict.next_options("kiel_nuernberg", "hamburg", 0, ["kiel", "hamburg"]).size(), 1, "Toleranz 10 %: nur die Ostroute")
	c["routing"]["detour_tolerance"] = 0.35
	c["routing"]["max_options"] = 1
	var capped := NetworkTest.load_network(c)
	assert_eq(capped.next_options("kiel_nuernberg", "hamburg", 0, ["kiel"]).size(), 1, "max_options begrenzt")


func test_synthetic_network_rules() -> void:
	# a-b-d (100+100) vs a-c-d (100+120) vs a-e-d (100+300); ferry d~f; waypoint d, finish f
	var stage := func(id: String, a: String, b: String, km: float, fuel: Array) -> Dictionary:
		return {"id": id, "from": a, "to": b, "length_km": km, "fuel_stations_km": fuel,
			"sections": [{"length_km": km, "road": "autobahn", "country": "DE", "scenery": "north_plain"}]}
	var cities: Array = []
	for id in ["a", "b", "c", "d", "e", "f"]:
		cities.append({"id": id, "name": id.to_upper(), "country": "DE", "latlon": [50, 10]})
	var data := {
		"cities": cities,
		"stages": [stage.call("ab", "a", "b", 100.0, [50]), stage.call("bd", "b", "d", 100.0, [50]),
			stage.call("ac", "a", "c", 100.0, [50]), stage.call("cd", "c", "d", 120.0, [60]),
			stage.call("ae", "a", "e", 100.0, [50]), stage.call("ed", "e", "d", 300.0, [50, 120, 190, 250])],
		"ferries": [{"id": "df", "from": "f", "to": "d", "name": "Fähre", "fixed_time_s": 100, "world_hours": 5}],
		"races": [
			{"id": "r", "name": "R", "start": "a", "finish": "f", "waypoints": ["d"]},
			{"id": "r2", "name": "R2", "start": "a", "finish": "d", "waypoints": [], "avoid_stages": ["ab"]},
		],
	}
	var n := RoadNetwork.new()
	n.setup(data, {"DE": {"limits": {"autobahn": null}}}, cfg())
	var o := n.next_options("r", "a", 0, ["a"])
	assert_eq(_to_ids(o), ["b", "c"] as Array[String], "e ist ein zu großer Umweg (400 > 1,35 · 200)")
	var via_b := n.next_options("r", "b", 0, ["a", "b"])
	assert_eq(_to_ids(via_b), ["d"] as Array[String], "b: weiter nach d (a gesperrt)")
	var at_d := n.next_options("r", "d", 0, ["a", "b", "d"])
	assert_eq(_to_ids(at_d), ["f"] as Array[String], "Pflichtstation d erreicht: Fähre nach f (in Gegenrichtung definiert)")
	assert_eq(str(at_d[0]["kind"]), "ferry", "Fähren sind in beide Richtungen nutzbar")
	assert_eq(n.race_routes("r").size(), 2, "zwei Routen")
	assert_eq(_to_ids(n.next_options("r2", "a", 0, ["a"])), ["c"] as Array[String], "avoid_stages sperrt a–b")
	assert_true(n.validate().is_empty(), "synthetisches Netz gültig: %s" % str(n.validate()))
	var free := n.next_options("", "a", 0, ["a", "b"])
	assert_eq(_to_ids(free), ["c", "e"] as Array[String], "ohne Rennen: alle unbesuchten Verbindungen")
