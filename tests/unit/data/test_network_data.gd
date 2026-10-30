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
	assert_true(n.cities.size() >= 50, "mindestens 50 Städte, sind %d" % n.cities.size())
	assert_true(n.stages.size() >= 50, "mindestens 50 Etappen, sind %d" % n.stages.size())
	for id in ["kiel_nuernberg", "dresden_dortmund", "muenchen_bremen", "koenigsrennen"]:
		assert_true(n.races.has(id), "Rennen %s vorhanden" % id)
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
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		if bool(s.get("dev", false)):
			continue
		for from_id in [str(s["from"]), str(s["to"])]:
			var p := n.get_stage_plan(id, from_id)
			var tag := "%s ab %s" % [id, from_id]
			var prev := 0.0
			for st in p.fuel_stations_km:
				var gap := st - prev
				if prev > 0.0:
					assert_between(gap, float(spacing[0]) - 0.5, float(spacing[1]) + 0.5, tag + " Tankabstand")
				else:
					assert_true(gap <= float(spacing[1]) + 0.5, tag + " erste Tankstelle spätestens nach 90 km")
				prev = st
			assert_true(p.length_km - prev >= 25.0, tag + " letzte Tankstelle ≥ 25 km vor dem Ziel")
			assert_true(prev <= p.city_limits_km, tag + " keine Tankstelle in den City Limits")
			for r in p.radars:
				assert_true(float(r["end_km"]) <= p.length_km - 50.0 + 0.001, tag + " kein Radar in den letzten 50 km")
				assert_true(int(r["limit"]) > 0, tag + " Radar mit Limit")
				for sec in p.sections:
					if float(sec["end_km"]) > float(r["km"]) + 0.001 and float(sec["start_km"]) < float(r["end_km"]) - 0.001:
						assert_eq(int(sec["speed_limit"]), int(r["limit"]), tag + " Radarlimit = Tempolimit des Abschnitts")
			for t in p.tunnels:
				assert_true(float(t["start_km"]) >= 0.0 and float(t["end_km"]) <= p.length_km, tag + " Tunnel in der Etappe")


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
	var g := n.get_stage_plan("bremen_groningen", "groningen")
	assert_eq(str(g.borders[0]["to"]), "DE", "Rückrichtung Groningen → Bremen nach DE")


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
