extends TestCase
## Individual cities (docs/staedte.md): data/cities.json against the network, the scenery and the sprite
## manifest; every arrival in every city (both directions of every stage) builds without warnings, bridges
## lie inside the stage and clear of tunnels, landmarks inside the City Limits.

const REQUIRED_LANDMARKS: Array[String] = ["eiffel_tower", "elbphilharmonie", "michel", "riesenrad", "stephansdom",
	"fernsehturm_berlin", "frauenkirche_dresden", "frauenkirche_muenchen", "sagrada_familia", "duomo_milano",
	"campanile_venezia", "parlament_budapest", "veitsdom_prag", "kulturpalast_warschau", "nevsky_kathedrale"]
const CONTRACT_STYLES: Array[String] = ["hanse", "german", "german_old", "dutch", "belgian", "paris", "french", "spanish",
	"italian", "vienna", "austrian", "swiss", "central", "eastern", "balkan", "baltic"]
const PROC_KINDS: Array[String] = ["lattice_tower", "tv_tower", "ferris_wheel", "column", "campanile", "domed_church",
	"parliament", "palace_tower", "skyscrapers"]

var _net: RoadNetwork = null


func _json(path: String) -> Dictionary:
	var d: Variant = ConfigLoader.load_json(path)
	return d if d is Dictionary else {}


func db() -> Dictionary:
	return _json("res://data/cities.json")


func scenery() -> Dictionary:
	return _json("res://data/scenery.json").get("scenery", {})


func sprites() -> Dictionary:
	return _json("res://assets/sprites/manifest.json").get("sets", {})


func net() -> RoadNetwork:
	if _net == null:
		_net = RoadNetwork.new()
		_net.setup(_json("res://data/network.json"), _json("res://data/countries.json").get("countries", {}), cfg(), {})
	return _net


func test_every_city_resolves_to_a_style() -> void:
	var d := db()
	var styles: Dictionary = d.get("styles", {})
	for st in CONTRACT_STYLES:
		assert_true(styles.has(st), "Stil %s aus dem Vertrag vorhanden" % st)
	for cid: String in net().cities:
		var c: Dictionary = net().cities[cid]
		if bool(c.get("dev", false)):
			continue
		assert_true(CityData.city_entry(d, cid).has("style"), "%s steht in cities.json" % cid)
		var st := CityData.style_for(d, cid, str(c.get("country", "")))
		assert_true(styles.has(st), "%s hat einen bekannten Stil (%s)" % [cid, st])
		var ids := CityData.scenery_ids(d, st)
		assert_true(scenery().has(str(ids["outskirts"])) and scenery().has(str(ids["center"])), "%s: beide Landschaften vorhanden" % cid)
	# examples of the contract
	assert_eq(CityData.style_for(d, "hamburg", "DE"), "hanse", "Hamburg Hanse")
	assert_eq(CityData.style_for(d, "wien", "AT"), "vienna", "Wien")
	assert_eq(CityData.style_for(d, "bialystok", "PL"), "eastern", "Białystok Osteuropa")
	assert_eq(CityData.style_for(d, "paris", "FR"), "paris", "Paris")


func test_style_fallbacks() -> void:
	var d := {"styles": {"german": {}, "eastern": {}}, "country_style": {"PL": "eastern"},
		"cities": {"x": {"style": "unbekannt"}}}
	assert_eq(CityData.style_for(d, "neu", "PL"), "eastern", "unbekannte Stadt: Stil des Landes")
	assert_eq(CityData.style_for(d, "neu", "XX"), "german", "unbekanntes Land: german")
	assert_eq(CityData.style_for(d, "x", "PL"), "eastern", "unbekannter Stil der Stadt: Stil des Landes")
	# a plan without city data keeps the generic City Limits scenery
	var stage := {"id": "t", "from": "a", "to": "b", "length_km": 60, "sections": [{"length_km": 60, "scenery": "polder", "country": "DE"}]}
	var cities := {"a": {"name": "A", "country": "DE"}, "b": {"name": "B", "country": "DE"}}
	var p := StagePlan.build(stage, "a", cities, {}, cfg())
	assert_eq(p.scenery_for(55.0, {"city": {}, "polder": {}}), "city", "ohne cities.json: city")
	assert_eq(p.scenery_for(10.0, {"city": {}}), "polder", "vor den City Limits: Abschnitt")
	var q := StagePlan.build(stage, "a", cities, {}, cfg(), {"styles": {"german": {"outskirts": "fehlt_a", "center": "fehlt_b"}}})
	assert_eq(q.city_style, "german", "Stil german")
	assert_eq(q.scenery_for(55.0, {"city": {}}), "city", "fehlende Stil-Landschaft: city")


func test_city_data_validates() -> void:
	for msg in CityData.validate(db(), net().cities, scenery(), sprites()):
		fail(msg)
	for msg in CityData.missing_props(scenery(), sprites()):
		fail(msg)


func test_city_sceneries_complete() -> void:
	var sc := scenery()
	for st in CONTRACT_STYLES:
		for part: String in ["outskirts", "center"]:
			var id := "city_%s_%s" % [st, part]
			assert_true(sc.has(id), "Landschaft %s vorhanden" % id)
			var s: Dictionary = sc.get(id, {})
			assert_eq((s.get("grass", []) as Array).size(), 2, "%s: zwei Bodenfarben" % id)
			var style := str(s.get("background", {}).get("style", ""))
			assert_true(style == "city" or style == "suburb", "%s: Hintergrund city/suburb" % id)
			assert_true(RaceBackdrop.STYLES.has(style), "%s: Hintergrundstil bekannt" % id)
			var props: Array = s.get("props", [])
			assert_true(props.size() >= 3, "%s: Requisiten-Regeln" % id)
			var own := 0
			for r: Dictionary in props:
				var set_id := str(r.get("set", ""))
				if set_id.begins_with("props/city_"):
					own += 1
					assert_true(r.has("fallback"), "%s: %s hat einen Ersatz" % [id, set_id])
			assert_true(own >= 1, "%s: eigene Gebäude des Stils" % id)
			if s.has("fence"):
				assert_true(["picket", "hedge", "wall", "iron"].has(str(s["fence"].get("style", ""))), "%s: Zaunstil" % id)
	# outskirts and centre look different (ground colour)
	for st in CONTRACT_STYLES:
		var a: Array = sc.get("city_%s_outskirts" % st, {}).get("grass", [])
		var b: Array = sc.get("city_%s_center" % st, {}).get("grass", [])
		assert_true(a != b, "%s: Stadtrand und Zentrum mit eigenem Boden" % st)


## Every arrival (both directions of every stage) with the real city data: no warnings, bridges inside the
## stage and clear of tunnels, landmarks inside the City Limits, centre scenery near the finish.
func test_arrivals_build_without_warnings() -> void:
	var n := net()
	var d := db()
	var sc := scenery()
	var arrivals := 0
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		var dirs: Array = [str(s["from"])] if bool(s.get("dev", false)) else [str(s["from"]), str(s["to"])]
		for from_id in dirs:
			var p := StagePlan.build(s, from_id, n.cities, n.countries, cfg(), d)
			var tag := "%s ab %s" % [id, from_id]
			arrivals += 1
			assert_true(p.warnings.is_empty(), "%s: %s" % [tag, str(p.warnings)])
			assert_true(p.city_style != "", tag + ": Stil")
			assert_eq(p.scenery_for(p.length_km - 0.5, sc), p.city_scenery_center, tag + ": Zentrum am Ziel")
			assert_eq(p.scenery_for(p.city_limits_km + 0.5, sc), p.city_scenery_outskirts, tag + ": Stadtrand am Ortsschild")
			for b in p.bridges:
				assert_true(float(b["start_km"]) >= 0.0 and float(b["end_km"]) <= p.length_km, tag + ": Brücke in der Etappe")
				for t in p.tunnels:
					assert_false(float(b["start_km"]) < float(t["end_km"]) and float(b["end_km"]) > float(t["start_km"]), tag + ": Brücke nicht im Tunnel")
			for lm in p.landmarks:
				assert_true(float(lm["km"]) >= p.city_limits_km and float(lm["km"]) <= p.length_km, tag + ": Wahrzeichen in den City Limits")
				assert_false(p.in_tunnel(float(lm["km"])), tag + ": Wahrzeichen nicht im Tunnel")
				assert_false(p.on_bridge(float(lm["km"])), tag + ": Wahrzeichen nicht im Wasser")
	assert_true(arrivals > 90, "alle Ankünfte geprüft (%d)" % arrivals)


func test_required_landmarks_and_bridges() -> void:
	var d := db()
	var sets: Dictionary = d.get("landmark_sets", {})
	var used := {}
	for cid: String in d.get("cities", {}):
		var e := CityData.city_entry(d, cid)
		for lm: Dictionary in e.get("landmarks", []):
			used[str(lm["set"])] = cid
	for name in REQUIRED_LANDMARKS:
		var sid := "landmarks/" + name
		assert_true(sets.has(sid), "Pflicht-Wahrzeichen %s im Katalog" % name)
		assert_true(bool((sets.get(sid, {}) as Dictionary).get("required", false)), "%s als Pflicht markiert" % name)
		assert_true(used.has(sid), "%s steht in einer Stadt" % name)
	for sid: String in sets:
		var proc := str((sets[sid] as Dictionary).get("proc", ""))
		assert_true(proc == "" or PROC_KINDS.has(proc), "%s: bekannter prozeduraler Ersatz" % sid)
	assert_eq(str(used.get("landmarks/eiffel_tower", "")), "paris", "Eiffelturm in Paris")
	assert_eq(str(used.get("landmarks/riesenrad", "")), "wien", "Riesenrad in Wien")
	var types := func(cid: String) -> Array:
		var out: Array = []
		for b: Dictionary in CityData.city_entry(d, cid).get("bridges", []):
			out.append(str(b["type"]))
		return out
	var hh: Array = types.call("hamburg")
	assert_true(hh.has("cable_stayed") and hh.has("truss_arch"), "Hamburg: Schrägseil- und Fachwerkbogenbrücke")
	assert_true((types.call("amsterdam") as Array).count("canal") >= 3, "Amsterdam: mehrere Grachtenbrücken")
	assert_true((types.call("venedig") as Array).has("causeway"), "Venedig: Damm über die Lagune")
	var kiel: Array = CityData.city_entry(d, "kiel").get("bridges", [])
	assert_true(not kiel.is_empty() and float((kiel[0] as Dictionary).get("height_m", 0.0)) >= 12.0, "Kiel: Hochbrücke über den Kanal")
	for cid: String in ["paris", "prag", "dresden", "budapest", "wien", "bordeaux", "lyon", "belgrad", "riga", "warschau"]:
		assert_false((types.call(cid) as Array).is_empty(), "%s: Flussbrücke" % cid)


func test_bridge_and_landmark_resolution() -> void:
	var n := net()
	var p := StagePlan.build(n.stages["hamburg_hannover"], "hannover", n.cities, n.countries, cfg(), db())
	assert_eq(p.to_id, "hamburg", "Ankunft in Hamburg")
	assert_eq(p.bridges.size(), 2, "zwei Brücken")
	var ts := float(ConfigLoader.lookup(cfg(), "time.time_scale", 12.0))
	var kb: Dictionary = p.bridges[0]
	assert_eq(str(kb["type"]), "cable_stayed", "erst die Köhlbrandbrücke")
	assert_near(float(kb["start_km"]), p.length_km - 17.0, 0.001, "Anfang km_to_finish")
	assert_near(float(kb["end_km"]) - float(kb["start_km"]), 260.0 * ts / 1000.0, 0.001, "Länge in sichtbaren Metern")
	assert_true(p.on_bridge(float(kb["start_km"]) + 0.1) and not p.on_bridge(float(kb["start_km"]) - 0.1), "on_bridge")
	assert_eq(p.landmarks.size(), 2, "zwei Wahrzeichen")
	assert_eq(str(p.landmarks[0]["set"]), "landmarks/elbphilharmonie", "nach km sortiert")
	assert_true(float(p.landmarks[0]["height_m"]) > 100.0, "Höhe aus dem Katalog")
	assert_eq(p.skyline.size(), 2, "Skyline")
	assert_true(float(p.skyline[0]["prop_km"]) > p.city_limits_km, "Skyline kennt die Requisite gleichen Namens")
	# bridges overlapping a tunnel or leaving the stage are dropped with a warning
	var bad := db()
	bad["cities"]["hamburg"]["bridges"] = [{"km_to_finish": 6.0, "length_m": 50, "type": "river", "name": "Im Tunnel"},
		{"km_to_finish": 0.1, "length_m": 500, "type": "river", "name": "Hinter dem Ziel"}]
	var q := StagePlan.build(n.stages["hamburg_hannover"], "hannover", n.cities, n.countries, cfg(), bad)
	assert_eq(q.bridges.size(), 0, "ungültige Brücken verworfen")
	assert_eq(q.warnings.size(), 2, "zwei Warnungen")
