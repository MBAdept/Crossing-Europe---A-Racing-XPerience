extends TestCase
## Data module: data/network.json, countries and map are consistent and every stage obeys the design rules
## in both driving directions (StagePlan.build without warnings).

var _cached: RoadNetwork = null


func net() -> RoadNetwork:
	if _cached == null:
		_cached = load_network(cfg())
	return _cached


static func load_network(config: Dictionary) -> RoadNetwork:
	var n := RoadNetwork.new()
	var data: Variant = ConfigLoader.load_json("res://data/network.json")
	var countries: Variant = ConfigLoader.load_json("res://data/countries.json")
	var map: Variant = ConfigLoader.load_json("res://data/map/europe_map.json")
	n.setup(data if data is Dictionary else {}, countries.get("countries", {}) if countries is Dictionary else {},
		config, map if map is Dictionary else {})
	return n


func test_network_loads() -> void:
	var n := net()
	assert_true(n.load_warnings.is_empty(), "keine Ladewarnungen: %s" % str(n.load_warnings))
	# 55 cities + 2 dev cities: towns passed by long Königsrennen stages (Groningen, Niš, …) are no stage ends;
	# v0.7.0: 10 cities and 13 stages for Wien – Hamburg and Bukarest – Calais
	assert_true(n.cities.size() >= 55, "mindestens 55 Städte, sind %d" % n.cities.size())
	assert_true(n.stages.size() >= 64, "mindestens 64 Etappen, sind %d" % n.stages.size())
	for id in ["kiel_nuernberg", "dresden_dortmund", "muenchen_bremen", "wien_hamburg", "bukarest_calais", "koenigsrennen"]:
		assert_true(n.races.has(id), "Rennen %s vorhanden" % id)
	assert_eq(n.race_order, ["kiel_nuernberg", "dresden_dortmund", "muenchen_bremen", "wien_hamburg", "bukarest_calais", "koenigsrennen"] as Array[String],
		"Reihenfolge der Rennen (Menü)")
	assert_true(n.ferries.has("riga_rostock"), "Fähre Riga – Rostock")


func test_validate_reports_nothing() -> void:
	var problems := net().validate()
	for p in problems:
		fail(p)


func test_every_stage_builds_both_directions_without_warnings() -> void:
	var n := net()
	var countries: Dictionary = n.countries
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		var dirs: Array = [str(s["from"])] if bool(s.get("dev", false)) else [str(s["from"]), str(s["to"])]
		for from_id in dirs:
			var p := StagePlan.build(s, from_id, n.cities, countries, cfg())
			assert_true(p.warnings.is_empty(), "%s ab %s: %s" % [id, from_id, str(p.warnings)])
			assert_eq(p.from_id, from_id, "%s Startstadt" % id)
			assert_true(p.fuel_stations_km.size() >= 1, "%s ab %s: mindestens eine Tankstelle" % [id, from_id])


func test_design_rules_both_directions() -> void:
	var n := net()
	var c := cfg()
	var spacing: Array = ConfigLoader.lookup(c, "fuel.station_spacing_km", [60, 90])
	var first_min := float(ConfigLoader.lookup(c, "fuel.first_station_min_km", 5.0))
	var first_max := float(ConfigLoader.lookup(c, "fuel.first_station_max_km", 20.0))
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		if bool(s.get("dev", false)):
			continue
		for from_id in [str(s["from"]), str(s["to"])]:
			var p := n.get_stage_plan(id, from_id)
			var tag := "%s ab %s" % [id, from_id]
			# v0.7.0 (the tank carries over in a race): the first station of every direction 5–20 km after the start
			assert_between(p.fuel_stations_km[0], first_min - 0.05, first_max + 0.05, tag + " erste Tankstelle 5–20 km nach dem Start")
			var prev := p.fuel_stations_km[0]
			for st in p.fuel_stations_km.slice(1):
				assert_between(st - prev, float(spacing[0]) - 0.5, float(spacing[1]) + 0.5, tag + " Tankabstand")
				prev = st
			assert_true(p.length_km - prev >= 25.0, tag + " letzte Tankstelle ≥ 25 km vor dem Ziel")
			assert_true(p.length_km - prev <= float(spacing[1]) + 0.5, tag + " letzte Tankstelle ≤ 90 km vor dem Ziel")
			assert_true(prev <= p.city_limits_km, tag + " keine Tankstelle in den City Limits")
			for r in p.radars:
				assert_true(float(r["end_km"]) <= p.length_km - 50.0 + 0.001, tag + " kein Radar in den letzten 50 km")
				assert_true(int(r["limit"]) > 0, tag + " Radar mit Limit")
				for sec in p.sections:
					if float(sec["end_km"]) > float(r["km"]) + 0.001 and float(sec["start_km"]) < float(r["end_km"]) - 0.001:
						assert_eq(int(sec["speed_limit"]), int(r["limit"]), tag + " Radarlimit = Tempolimit des Abschnitts")
			for t in p.tunnels:
				assert_true(float(t["start_km"]) >= 0.0 and float(t["end_km"]) <= p.length_km, tag + " Tunnel in der Etappe")


## v0.7.0: in a race the tank carries over – whoever fills up at the last station of a stage (at the start of its lane)
## reaches the first station of the next stage (also across the ferry) at full speed in every car, on every route of
## every race: its stage screen and countdown then say "reicht auch mit Vollgas" (FuelSystem.start_check counts to the
## station itself since QA v0.7.0). The generic rule behind it: test_full_tank_at_the_last_station_reaches_the_next_first_station.
func test_race_legs_full_tank_reaches_the_next_first_station() -> void:
	var n := net()
	var c := cfg()
	var range_min := INF
	for id in ConfigLoader.lookup(c, "vehicles.order", []):
		var spec := VehicleModel.resolve_spec(c, str(id))
		range_min = minf(range_min, float(spec["tank_l"]) / FuelSystem.consumption_for(c, spec, float(spec["vmax_kmh"])) * 100.0)
	assert_true(range_min < INF, "Fahrzeuge in der Konfiguration")
	var worst := 0.0
	for race_id in n.race_order:
		for route in n.race_routes(race_id):
			var prev: StagePlan = null
			for leg: Dictionary in route["legs"]:
				if str(leg["kind"]) != "stage":
					continue   # the ferry: the tank goes on as it is
				var p := n.get_stage_plan(str(leg["id"]), str(leg["from"]))
				if prev != null:
					var gap := prev.length_km - float(prev.fuel_lanes[-1]["start_km"]) + float(p.fuel_lanes[0]["station_km"])
					worst = maxf(worst, gap)
					assert_true(gap <= range_min, "%s: %s → %s: %.1f km von der letzten Tankspur bis zur ersten Tankstelle, Reichweite bei vmax %.1f km" % [
						race_id, prev.display_name, p.display_name, gap, range_min])
				prev = p
	assert_between(worst, 1.0, range_min, "Etappenübergänge geprüft (größter Abstand %.1f km)" % worst)


func test_sections_sum_and_allowed_values() -> void:
	var n := net()
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		var sum := 0.0
		for sec in s["sections"]:
			sum += float(sec["length_km"])
			assert_true(RoadNetwork.SCENERY_IDS.has(str(sec["scenery"])), "%s: Landschaft %s" % [id, str(sec["scenery"])])
			assert_true(n.countries.has(str(sec["country"])), "%s: Land %s" % [id, str(sec["country"])])
			if sec.has("speed_limit") and sec["speed_limit"] == null:
				assert_true(str(sec["country"]) == "DE" and str(sec["road"]) == "autobahn", "%s: 'ohne Limit' nur auf deutscher Autobahn" % id)
		assert_near(sum, float(s["length_km"]), 0.01, "%s: Summe der Abschnitte" % id)


func test_stage_lengths_and_intermediate_cities() -> void:
	var n := net()
	var split_above := float(ConfigLoader.lookup(cfg(), "stages.split_above_km", 300.0))
	var max_length := float(ConfigLoader.lookup(cfg(), "stages.max_length_km", 400.0))
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		if bool(s.get("dev", false)):
			continue
		var length := float(s["length_km"])
		assert_between(length, 90.0, max_length, "%s: Etappenlänge" % id)
		# Kiel – Nürnberg: stages above ~300 km get an intermediate city
		if ["kiel_hamburg", "hamburg_hannover", "hannover_kassel", "kassel_wuerzburg", "hamburg_bremen",
				"bremen_dortmund", "dortmund_frankfurt", "frankfurt_wuerzburg", "wuerzburg_nuernberg"].has(id):
			assert_true(length <= split_above, "%s: höchstens %.0f km" % [id, split_above])


func test_tutorial_stage() -> void:
	var p := net().get_stage_plan("kiel_hamburg", "kiel")
	assert_between(p.length_km, 90.0, 100.0, "Kiel – Hamburg ca. 95 km")
	assert_eq(p.fuel_stations_km.size(), 1, "eine Tankstelle")
	assert_eq(p.radars.size(), 1, "ein Radar")
	for s in p.sections:
		assert_eq(str(s["road"]), "autobahn", "nur Autobahn")
		assert_true(int(s["curviness"]) <= 1 and int(s["hills"]) <= 1, "einfache Strecke")
	var r := net().get_stage_plan("kiel_hamburg", "hamburg")
	assert_eq(r.radars.size(), 1, "Rückrichtung: ein Radar (Gegenrichtung)")
	# tutorial data: flagged stage, starts with ~1/3 tank so the fuel stop is part of the tutorial
	assert_true(p.tutorial, "Kiel – Hamburg ist die Tutorial-Etappe")
	assert_near(p.start_fuel_fraction, 0.35, 0.001, "Start mit 35 % Tank")
	# the way back is no tutorial (QA v0.5.0: Hamburg – Kiel had tutorial tips, a 35 % tank and the dry rule)
	assert_false(r.tutorial, "Gegenrichtung Hamburg – Kiel ist kein Tutorial")
	assert_eq(r.start_fuel_fraction, -1.0, "Gegenrichtung: Starttank aus der Konfiguration")
	for id in net().stage_order:
		if id != "kiel_hamburg":
			var other := net().get_stage_plan(id, "")
			assert_false(other.tutorial, "%s ist kein Tutorial" % id)
			assert_eq(other.start_fuel_fraction, -1.0, "%s: Starttank aus der Konfiguration" % id)


## data/countries.json: every country has the sign colours used for country-typical signs (border crossings
## change the signs) and the data the network needs.
func test_country_sign_colours() -> void:
	var n := net()
	for code: String in n.countries:
		var c: Dictionary = n.countries[code]
		var signs: Dictionary = c.get("signs", {})
		for key in ["motorway", "town_bg", "town_fg", "town_border"]:
			assert_true(signs.has(key) and Color.html_is_valid(str(signs[key])), "%s: Schilderfarbe %s" % [code, key])
		assert_true(str(c.get("police", "")).begins_with("police/"), "%s: Polizei-Sprite" % code)
		assert_true((c.get("limits", {}) as Dictionary).has("city"), "%s: Tempolimit City" % code)


func test_real_tunnels_and_borders() -> void:
	var n := net()
	var found := {}
	for id in n.stage_order:
		for t in n.stages[id].get("tunnels", []):
			found[str(t["name"])] = float(t["length_km"])
	assert_near(float(found.get("Gotthard-Strassentunnel", 0.0)), 16.9, 0.2, "Gotthard ca. 17 km")
	assert_true(found.has("Elbtunnel"), "Elbtunnel")
	assert_true(found.has("Somport-Tunnel"), "Pyrenäentunnel (Somport)")
	assert_true(found.has("Seelisbergtunnel"), "Alpentunnel Seelisberg")
	var p := n.get_stage_plan("bern_mailand", "bern")
	assert_true(p.in_tunnel(195.0), "Gotthard bei km 195 vorwärts")
	assert_eq(p.borders.size(), 1, "Bern – Mailand: eine Grenze")
	assert_eq(str(p.borders[0]["to"]), "IT", "nach Italien")
	var g := n.get_stage_plan("bremen_amsterdam", "amsterdam")
	assert_true(g != null, "Etappe Bremen – Amsterdam vorhanden")
	if g == null:
		return
	assert_eq(g.borders.size(), 1, "Amsterdam → Bremen: eine Grenze")
	assert_eq(str(g.borders[0]["to"]), "DE", "Rückrichtung Amsterdam → Bremen nach DE")
	# v0.7.0: the D5 tunnel near Plzeň, the five new borders of Wien – Hamburg and Bukarest – Calais
	assert_near(float(found.get("Tunel Valík", 0.0)), 0.4, 0.05, "Valík-Tunnel bei Plzeň")
	var expect := {"linz_passau": ["linz", 89.0, "DE"], "timisoara_budapest": ["timisoara", 115.0, "HU"],
		"prag_nuernberg": ["prag", 160.0, "DE"], "koeln_bruessel": ["koeln", 80.0, "BE"], "bruessel_calais": ["bruessel", 160.0, "FR"]}
	for id: String in expect:
		var e: Array = expect[id]
		var b := n.get_stage_plan(id, str(e[0]))
		assert_eq(b.borders.size(), 1, "%s: eine Grenze" % id)
		if b.borders.size() == 1:
			assert_near(float(b.borders[0]["km"]), float(e[1]), 0.01, "%s: Grenze bei km %.0f" % [id, float(e[1])])
			assert_eq(str(b.borders[0]["to"]), str(e[2]), "%s: nach %s" % [id, str(e[2])])
	var ro := n.get_stage_plan("timisoara_budapest", "budapest")
	assert_eq(str(ro.borders[0]["to"]), "RO", "Budapest → Timișoara nach Rumänien")
	assert_eq(str(n.countries["RO"]["police"]), "police/ro", "rumänische Polizei")


## Design: "Grenzübergänge: Wechsel von Schildern, Landschaft und Polizeifahrzeugen" (review BORDER-1: 15 of 20
## borders kept the scenery). Every border changes the scenery and lies outside the City Limits (both
## directions; inside them both sides would show the "city" scenery).
func test_landscape_changes_at_every_border() -> void:
	var n := net()
	var margin := float(ConfigLoader.lookup(cfg(), "stages.border_min_before_city_km", 5.0))
	var borders := 0
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		var secs: Array = s["sections"]
		for i in range(1, secs.size()):
			if str(secs[i]["country"]) != str(secs[i - 1]["country"]):
				borders += 1
				assert_true(str(secs[i]["scenery"]) != str(secs[i - 1]["scenery"]), "%s: Grenze %s → %s mit Landschaftswechsel (%s)" % [
					id, str(secs[i - 1]["country"]), str(secs[i]["country"]), str(secs[i]["scenery"])])
		var dirs: Array = [str(s["from"])] if bool(s.get("dev", false)) else [str(s["from"]), str(s["to"])]
		for from_id in dirs:
			var p := n.get_stage_plan(id, from_id)
			for b in p.borders:
				var km := float(b["km"])
				assert_true(p.scenery_at(km - 0.05) != p.scenery_at(km + 0.05), "%s ab %s: Landschaft wechselt bei km %.1f" % [id, from_id, km])
				assert_true(km <= p.city_limits_km - margin + 0.001, "%s ab %s: Grenze bei km %.1f vor den City Limits (%.1f)" % [id, from_id, km, p.city_limits_km])
				assert_eq(p.country_at(km + 0.05), str(b["to"]), "%s ab %s: Land nach der Grenze" % [id, from_id])
	assert_true(borders >= 24, "alle Grenzen geprüft (%d)" % borders)


## Design (Königsrennen): "Lange Abschnitte werden in Etappen von 200–400 km geteilt" (review KOEN-LEN-1). Every
## way between two consecutive waypoints that needs several stages uses stages of 200–400 km; only a single
## natural stage between two waypoints may be shorter. Independent of RoadNetwork.split_violations().
func test_koenigsrennen_split_stages_200_400() -> void:
	var n := net()
	var bounds: Array = ConfigLoader.lookup(cfg(), "stages.split_length_km", [200, 400])
	assert_true(float(bounds[0]) == 200.0 and float(bounds[1]) == 400.0, "Design: 200–400 km, ist %s" % str(bounds))
	assert_true(bool(n.races["koenigsrennen"].get("tour", false)), "Königsrennen ist als Tour markiert")
	var targets: Array = (n.races["koenigsrennen"]["waypoints"] as Array).duplicate()
	targets.append(n.races["koenigsrennen"]["finish"])
	var natural := {}
	for route in n.race_routes("koenigsrennen"):
		var idx := 0
		var seg: Array[Dictionary] = []
		for leg: Dictionary in route["legs"]:
			if str(leg["kind"]) == "stage":
				seg.append(leg)
			if idx < targets.size() and str(leg["to"]) == str(targets[idx]):
				idx += 1
				if seg.size() == 1:
					natural[str(seg[0]["id"])] = float(seg[0]["length_km"])
				else:
					for st in seg:
						assert_between(float(st["length_km"]), float(bounds[0]), float(bounds[1]),
							"Königsrennen: geteilte Etappe %s (%s → %s)" % [str(st["id"]), str(st["from"]), str(st["to"])])
				seg = []
		assert_eq(idx, targets.size(), "alle Pflichtstationen erreicht")
	# the short stages left are natural legs between consecutive waypoints (Kiel – Hamburg 95, Hamburg – Bremen 120,
	# Leipzig – Berlin 190), all within the general limits
	for id: String in natural:
		assert_between(float(natural[id]), 90.0, float(bounds[1]), "natürliche Etappe %s" % id)
	assert_true(natural.has("kiel_hamburg") and natural.has("leipzig_berlin"), "natürliche Etappen erkannt: %s" % str(natural.keys()))
	assert_true(n.split_violations("koenigsrennen", n.race_routes("koenigsrennen")).is_empty(), "RoadNetwork.split_violations leer")


## validate() reports both new rules on a small synthetic network (regression for the checks themselves).
func test_validation_reports_border_and_split_problems() -> void:
	var sec := func(km: float, country: String, scenery: String) -> Dictionary:
		return {"length_km": km, "road": "autobahn", "country": country, "scenery": scenery, "speed_limit": 120}
	var data := {
		"cities": [{"id": "a", "name": "A", "country": "DE", "latlon": [50, 10]},
			{"id": "b", "name": "B", "country": "NL", "latlon": [51, 9]},
			{"id": "c", "name": "C", "country": "NL", "latlon": [52, 8]}],
		"stages": [
			# border at km 100 of 200 without a landscape change
			{"id": "ab", "from": "a", "to": "b", "length_km": 200, "fuel_stations_km": [70, 140],
				"sections": [sec.call(100.0, "DE", "north_plain"), sec.call(100.0, "NL", "north_plain")]},
			# 150 km: too short as one of two stages between the waypoints a and c of a tour
			{"id": "bc", "from": "b", "to": "c", "length_km": 150, "fuel_stations_km": [75],
				"sections": [sec.call(150.0, "NL", "polder")]},
		],
		"races": [{"id": "t", "name": "T", "start": "a", "finish": "c", "waypoints": [], "tour": true},
			{"id": "plain", "name": "P", "start": "a", "finish": "c", "waypoints": []}],
	}
	var countries := {"DE": {"limits": {"autobahn": null, "landstrasse": 100, "city": 50}},
		"NL": {"limits": {"autobahn": 100, "landstrasse": 80, "city": 50}}}
	var n := RoadNetwork.new()
	n.setup(data, countries, cfg())
	var problems := "\n".join(n.validate())
	assert_true(problems.contains("ohne Landschaftswechsel"), "Grenze ohne Landschaftswechsel gemeldet: %s" % problems)
	assert_true(problems.contains("Rennen t: Etappe bc"), "zu kurze geteilte Etappe der Tour gemeldet: %s" % problems)
	assert_false(problems.contains("Rennen plain:"), "Rennen ohne tour: keine 200–400-km-Regel")
	(data["stages"][0]["sections"][1] as Dictionary)["scenery"] = "polder"
	(data["stages"][0]["sections"][0] as Dictionary)["length_km"] = 185.0
	(data["stages"][0]["sections"][1] as Dictionary)["length_km"] = 15.0
	n.setup(data, countries, cfg())
	problems = "\n".join(n.validate())
	assert_false(problems.contains("ohne Landschaftswechsel"), "mit Landschaftswechsel kein Fehler")
	assert_true(problems.contains("vor den City Limits"), "Grenze in den City Limits gemeldet: %s" % problems)


func test_directional_radars() -> void:
	var stage := {"id": "d", "from": "a", "to": "b", "length_km": 200,
		"sections": [{"length_km": 200, "road": "autobahn", "country": "DE", "speed_limit": 120}],
		"fuel_stations_km": [70, 130],
		"radars": [{"km": 20, "limit": 120, "dir": "fwd"}, {"km": 170, "limit": 120, "dir": "rev"}, {"km": 100, "limit": 120}]}
	var cities := {"a": {"name": "A", "country": "DE"}, "b": {"name": "B", "country": "DE"}}
	var countries := {"DE": {"limits": {"autobahn": null, "city": 50}}}
	var f := StagePlan.build(stage, "a", cities, countries, cfg())
	assert_eq(f.radars.size(), 2, "vorwärts: fwd + beidseitig")
	assert_true(f.warnings.is_empty(), "keine Warnung vorwärts: %s" % str(f.warnings))
	var r := StagePlan.build(stage, "b", cities, countries, cfg())
	assert_eq(r.radars.size(), 2, "rückwärts: rev + beidseitig")
	assert_true(r.warnings.is_empty(), "keine Warnung rückwärts: %s" % str(r.warnings))
	assert_near(float(r.radars[0]["km"]), 25.0, 0.01, "rev-Radar gespiegelt (200 - 170 - 5)")


func test_cities_inside_map_and_projection_consistent() -> void:
	var n := net()
	var size := n.map_size()
	assert_true(size.x > 100.0 and size.y > 100.0, "Kartengröße")
	for id: String in n.cities:
		var pos := n.city_map_pos(id)
		assert_true(pos.x > 0.0 and pos.y > 0.0 and pos.x < size.x and pos.y < size.y, "%s auf der Karte" % id)
		var ll: Array = n.cities[id]["latlon"]
		assert_true(n.project_latlon(float(ll[0]), float(ll[1])).distance_to(pos) < 1.0, "%s: map_pos = Projektion(latlon)" % id)
	# west/east and north/south order sanity
	assert_true(n.city_map_pos("madrid").x < n.city_map_pos("paris").x, "Madrid westlich von Paris")
	assert_true(n.city_map_pos("riga").y < n.city_map_pos("sofia").y, "Riga nördlich von Sofia")


func test_map_file_polygons_drawable() -> void:
	var f := FileAccess.open("res://data/map/europe_map.json", FileAccess.READ)
	assert_true(f != null, "Kartendatei vorhanden")
	if f == null:
		return
	assert_true(f.get_length() < 1500 * 1024, "Karte < 1,5 MB")
	var map: Dictionary = net().map_data
	var codes := {}
	var polys := 0
	for c in map.get("countries", []):
		var code := str(c.get("code", ""))
		assert_eq(code.length(), 2, "ISO-A2-Code für %s" % str(c.get("name", "")))
		codes[code] = true
		for poly in c.get("polygons", []):
			var pts := PackedVector2Array()
			for p in poly:
				pts.append(Vector2(float(p[0]), float(p[1])))
			polys += 1
			assert_true(pts.size() >= 3, "%s: Polygon mit mindestens 3 Punkten" % code)
			assert_false(Geometry2D.triangulate_polygon(pts).is_empty(), "%s: Polygon triangulierbar (%d Punkte)" % [code, pts.size()])
	assert_true(polys > 40, "genug Polygone")
	for code: String in net().countries:
		assert_true(codes.has(code), "Land %s auf der Karte" % code)
