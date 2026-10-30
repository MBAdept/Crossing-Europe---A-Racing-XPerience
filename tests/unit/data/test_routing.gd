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


func _leg_ids(legs: Array) -> Array[String]:
	var out: Array[String] = []
	for l in legs:
		out.append(str(l["id"]))
	return out


## Review ROUTE-1: the route choice must be able to show the whole route to the next target. The first leg alone
## reverses the trade-off (Hamburg – Bremen 120 km looks shorter than Hamburg – Hannover 150 km, but the route
## via Frankfurt is 810 km against 635 km via Kassel), so every option carries continuation, route_km,
## route_cities, route_summary and via_distinct.
func test_route_options_show_whole_route() -> void:
	var n := net()
	var opts := n.next_options("kiel_nuernberg", "hamburg", 0, ["kiel", "hamburg"])
	assert_eq(opts.size(), 2, "zwei Optionen")
	if opts.size() != 2:
		return
	var east: Dictionary = opts[0]
	var west: Dictionary = opts[1]
	for key in ["kind", "id", "from", "to", "length_km", "remaining_km", "total_km", "detour", "best", "target",
			"target_index", "via", "name", "board_key"]:
		assert_true(east.has(key) and west.has(key), "bisheriger Schlüssel %s bleibt" % key)
	# the first leg alone points the wrong way …
	assert_true(float(west["length_km"]) < float(east["length_km"]), "erste Etappe West kürzer (120 < 150 km)")
	# … the whole route shows the real trade-off
	assert_near(float(east["route_km"]), 635.0, 0.01, "Ost: Hamburg → Nürnberg 635 km")
	assert_near(float(west["route_km"]), 810.0, 0.01, "West: 810 km")
	assert_near(float(west["route_km"]), float(west["total_km"]), 0.001, "route_km = total_km")
	assert_eq(_leg_ids(east["continuation"]), ["hannover_kassel", "kassel_wuerzburg", "wuerzburg_nuernberg"] as Array[String], "Ost: Fortsetzung")
	assert_eq(_leg_ids(west["continuation"]), ["bremen_dortmund", "dortmund_frankfurt", "frankfurt_wuerzburg", "wuerzburg_nuernberg"] as Array[String], "West: Fortsetzung")
	var c0: Dictionary = west["continuation"][0]
	assert_eq(str(c0["name"]), "Bremen – Dortmund", "Fortsetzung mit Namen")
	assert_eq(str(c0["board_key"]), "stage:bremen_dortmund:fwd", "Fortsetzung mit Bestenlisten-Schlüssel")
	assert_eq(east["route_cities"], ["hamburg", "hannover", "kassel", "wuerzburg", "nuernberg"] as Array[String], "Ost: Städte der Route")
	assert_eq(east["via_distinct"], ["hannover", "kassel"] as Array[String], "Ost: Route über Hannover, Kassel")
	assert_eq(west["via_distinct"], ["bremen", "dortmund", "frankfurt"] as Array[String], "West: Route über Bremen, Dortmund, Frankfurt")
	var es: Dictionary = east["route_summary"]
	var ws: Dictionary = west["route_summary"]
	assert_near(float(es["length_km"]), 635.0, 0.01, "Zusammenfassung Ost: Länge")
	assert_eq(int(es["stages"]), 4, "Ost: 4 Etappen")
	assert_eq(int(ws["stages"]), 5, "West: 5 Etappen")
	assert_eq(int(es["radars"]), 7, "Ost: 7 Radarfallen")
	assert_eq(int(ws["radars"]), 3, "West: 3 Radarfallen")
	assert_eq(int(es["stations"]), 8, "Ost: 8 Tankstellen")
	assert_eq(int(ws["stations"]), 11, "West: 11 Tankstellen")
	assert_near(float(es["unlimited_km"]), 250.0, 0.01, "Ost: 250 km frei")
	assert_near(float(ws["unlimited_km"]), 475.0, 0.01, "West: 475 km frei")
	assert_eq(int(es["tunnels"]), 1, "Ost: Elbtunnel")
	assert_eq(int(ws["borders"]), 0, "keine Grenze")
	# design balance: longer with more traffic, but more free autobahn, fewer radars, more fuel stations
	assert_true(float(ws["traffic"]) > float(es["traffic"]), "West: mehr Verkehr")
	assert_true(int(es["max_hills"]) >= 3, "Ost: Kasseler Berge / Rhön")
	assert_eq(ws["countries"], ["DE"] as Array[String], "Länder der Route")
	# reversed stages: München – Bremen at Würzburg drives Kassel – Würzburg and Hannover – Kassel backwards
	var mb := n.next_options("muenchen_bremen", "wuerzburg", 0, ["muenchen", "nuernberg", "wuerzburg"])
	assert_eq(_to_ids(mb), ["kassel", "frankfurt"] as Array[String], "Würzburg: Kassel / Frankfurt")
	if mb.size() == 2:
		assert_eq(str(mb[0]["continuation"][0]["board_key"]), "stage:hannover_kassel:rev", "Fortsetzung in Gegenrichtung")
		assert_near(float(mb[0]["route_km"]), 500.0, 0.01, "über Kassel 500 km")
		assert_near(float(mb[1]["route_km"]), 580.0, 0.01, "über Frankfurt 580 km")
		assert_true(int(mb[1]["route_summary"]["stations"]) > int(mb[0]["route_summary"]["stations"]), "über Frankfurt mehr Tankstellen")
		assert_true(float(mb[1]["route_summary"]["unlimited_km"]) > float(mb[0]["route_summary"]["unlimited_km"]), "über Frankfurt mehr freie Autobahn")


## Every option at every step of every race route: the details describe exactly the shortest continuation to
## the option's target, and the summary equals the per-stage summaries of that chain.
func test_route_details_consistent_everywhere() -> void:
	var n := net()
	var checked := 0
	for race_id in n.race_order:
		for route in n.race_routes(race_id):
			var city := str(route["cities"][0])
			var visited: Array = [city]
			var idx := 0
			for leg: Dictionary in route["legs"]:
				var opts := n.next_options(race_id, city, idx, visited)
				var chosen := {}
				for i in opts.size():
					var o: Dictionary = opts[i]
					checked += 1
					_check_option(n, race_id, city, o, opts, i)
					if str(o["id"]) == str(leg["id"]) and str(o["to"]) == str(leg["to"]):
						chosen = o
				assert_false(chosen.is_empty(), "%s: Etappe %s ist eine Option in %s" % [race_id, str(leg["id"]), city])
				if chosen.is_empty():
					break
				city = str(leg["to"])
				visited.append(city)
				idx = n.advance_waypoint_index(race_id, city, int(chosen["target_index"]))
	assert_true(checked > 50, "genug Optionen geprüft (%d)" % checked)


func _check_option(n: RoadNetwork, race_id: String, city: String, o: Dictionary, opts: Array, index: int) -> void:
	var tag := "%s ab %s → %s" % [race_id, city, str(o["to"])]
	var chain: Array = [o]
	chain.append_array(o["continuation"])
	var prev := city
	var km := 0.0
	var radars := 0
	var stations := 0
	for l: Dictionary in chain:
		assert_eq(str(l["from"]), prev, tag + ": Kette lückenlos")
		prev = str(l["to"])
		km += float(l["length_km"])
		if str(l["kind"]) == "stage":
			var s := n.stage_summary(str(l["id"]), str(l["from"]))
			radars += int(s["radars"])
			stations += int(s["stations"])
	assert_eq(prev, str(o["target"]), tag + ": Kette endet am Ziel")
	assert_near(float(o["route_km"]), km, 0.01, tag + ": route_km = Summe der Kette")
	assert_near(float(o["route_km"]), float(o["total_km"]), 0.01, tag + ": route_km = total_km")
	var rs: Dictionary = o["route_summary"]
	assert_near(float(rs["length_km"]), km, 0.01, tag + ": Zusammenfassung Länge (Fähre 0 km)")
	assert_eq(int(rs["radars"]), radars, tag + ": Radarfallen in Fahrtrichtung")
	assert_eq(int(rs["stations"]), stations, tag + ": Tankstellen")
	assert_eq(rs["cities"], o["route_cities"], tag + ": Städte")
	var rc: Array = o["route_cities"]
	assert_eq(str(rc[0]), city, tag + ": beginnt in der aktuellen Stadt")
	assert_eq(rc.slice(2), o["via"], tag + ": via = Städte nach dieser Etappe")
	for c in o["via_distinct"]:
		assert_true(rc.has(c) and str(c) != str(o["target"]), tag + ": via_distinct auf der Route")
		for j in opts.size():
			if j != index:
				assert_false((opts[j]["route_cities"] as Array).has(c), tag + ": %s nur auf dieser Route" % str(c))


## legs_summary() over a whole race route matches the per-stage summaries (route tables in docs/daten.md).
func test_legs_summary_of_race_routes() -> void:
	var n := net()
	var routes := n.race_routes("kiel_nuernberg")
	var east := n.legs_summary(routes[0]["legs"])
	assert_near(float(east["length_km"]), 730.0, 0.01, "Ost 730 km")
	assert_eq(int(east["radars"]), 8, "Ost: 8 Radarfallen")
	assert_eq(int(east["stations"]), 9, "Ost: 9 Tankstellen")
	assert_near(float(east["unlimited_km"]), 283.0, 0.01, "Ost: 283 km frei")
	for race_id in n.race_order:
		for route in n.race_routes(race_id):
			var s := n.legs_summary(route["legs"])
			var ref := _route_stats(n, route)
			assert_near(float(s["length_km"]), float(route["km"]), 0.01, "%s: Länge" % race_id)
			assert_eq(int(s["stages"]), int(route["stages"]), "%s: Etappen" % race_id)
			assert_eq(int(s["ferries"]), int(route["ferries"]), "%s: Fähren" % race_id)
			assert_eq(int(s["radars"]), int(ref["radars"]), "%s: Radar" % race_id)
			assert_eq(int(s["stations"]), int(ref["stations"]), "%s: Tankstellen" % race_id)
			assert_near(float(s["unlimited_km"]), float(ref["unlimited_km"]), 0.01, "%s: frei" % race_id)
			assert_near(float(s["traffic"]), float(ref["traffic"]), 0.0001, "%s: Verkehr" % race_id)
			assert_eq(s["cities"], route["cities"], "%s: Städte" % race_id)
	var k := n.legs_summary(n.race_routes("koenigsrennen")[0]["legs"])
	assert_eq(int(k["ferries"]), 1, "Königsrennen: eine Fähre")
	assert_true(float(k["ferry_time_s"]) > 0.0, "Fährzeit")
	assert_true((k["countries"] as Array).has("LV") and (k["countries"] as Array).has("BG"), "Länder der Tour")
	var segs := n.target_segments("koenigsrennen", n.race_routes("koenigsrennen")[0]["legs"])
	assert_eq(segs.size(), n.race_targets("koenigsrennen").size(), "ein Abschnitt je Ziel")
	assert_eq(str(segs[2][0]["id"]), "bremen_amsterdam", "Bremen → Amsterdam in einer Etappe")


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
	# ~9.200 km in stages of mostly 200–400 km
	assert_between(float(s["min_stages"]), 30.0, 40.0, "viele Etappen")
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
	# Sofia → Budapest drives back to Belgrad (visited on the way to Sofia).
	var n := net()
	var visited := ["kiel", "mailand", "venedig", "ljubljana", "slavonski_brod", "belgrad", "sofia"]
	var idx := n.advance_waypoint_index("koenigsrennen", "sofia", 8)
	assert_eq(n.next_target("koenigsrennen", idx), "budapest", "nach Sofia: Budapest")
	var opts := n.next_options("koenigsrennen", "sofia", idx, visited)
	assert_eq(_to_ids(opts), ["belgrad"] as Array[String], "Sofia → Belgrad trotz Besuch im vorigen Abschnitt")
	var at_belgrad := n.next_options("koenigsrennen", "belgrad", idx, visited + ["belgrad"])
	assert_eq(_to_ids(at_belgrad), ["budapest"] as Array[String], "Belgrad → Budapest (Sofia ist gesperrt)")


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
