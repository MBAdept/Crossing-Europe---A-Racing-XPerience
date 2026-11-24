extends TestCase
## Individual cities in the Track (docs/staedte.md): outskirts / centre scenery, bridges as zones (water,
## bank, portals, pylons, lamps, boats), landmarks as km events with cleared surroundings, far list.
## Inline stage and city data, real scenery (no autoloads).

const COUNTRIES := {"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}}}
const CITIES := {"a": {"name": "Astadt", "country": "DE"}, "b": {"name": "Bstadt", "country": "DE"}}


func _stage() -> Dictionary:
	return {"id": "t_city", "from": "a", "to": "b", "length_km": 80, "seed": 4242,
		"sections": [{"length_km": 80, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "north_plain", "country": "DE", "speed_limit": null}],
		"fuel_stations_km": [30]}


func _db() -> Dictionary:
	return {
		"center_km": 8.0,
		"country_style": {"DE": "german"},
		"styles": {"hanse": {"outskirts": "city_hanse_outskirts", "center": "city_hanse_center"},
			"german": {"outskirts": "city_german_outskirts", "center": "city_german_center"}},
		"landmark_sets": {"landmarks/test_tower": {"name": "Testturm", "height_m": 200, "width_m": 30, "proc": "tv_tower",
			"fallback": "props/building_tall", "fallback_scale": 3.0}},
		"cities": {"b": {"style": "hanse",
			"landmarks": [{"set": "landmarks/test_tower", "km_to_finish": 2.0, "side": 1, "x_m": 60.0},
				{"set": "props/church", "km_to_finish": 5.0, "side": -1, "x_m": 20.0, "scale": 2.0, "tint": "#c09080", "name": "Dom"}],
			"skyline": ["landmarks/test_tower", {"set": "props/church", "azimuth_deg": -20, "scale": 2.0}],
			"bridges": [{"km_to_finish": 18.0, "length_m": 200, "type": "cable_stayed", "name": "Schrägseilbrücke"},
				{"km_to_finish": 14.0, "length_m": 180, "type": "truss_arch", "name": "Bogenbrücke"},
				{"km_to_finish": 10.0, "length_m": 120, "type": "stone_arch", "name": "Steinbrücke"},
				{"km_to_finish": 7.0, "length_m": 40, "type": "canal", "name": "Gracht"},
				{"km_to_finish": 4.0, "length_m": 60, "type": "river", "name": "Hochbrücke", "height_m": 25, "ships": 1}]}},
	}


func _scenery() -> Dictionary:
	var d: Variant = ConfigLoader.load_json("res://data/scenery.json")
	return (d as Dictionary).get("scenery", {}) if d is Dictionary else {}


func _track() -> Track:
	var p := StagePlan.build(_stage(), "a", CITIES, COUNTRIES, cfg(), _db())
	var t := Track.new()
	t.setup(p, cfg(), _scenery())
	return t


## All segments of the City Limits (generated in order).
func _city_segments(t: Track) -> Array[TrackSegment]:
	var out: Array[TrackSegment] = []
	var z := t.km_to_z(t.plan.city_limits_km - 1.0)
	while z < t.length_z:
		t.update_window(z, 10.0)
		out.append(t.segment_at(z))
		z += t.seg_len
	return out


func test_plan_has_no_warnings() -> void:
	var t := _track()
	assert_true(t.plan.warnings.is_empty(), "keine Warnungen: %s" % str(t.plan.warnings))
	assert_eq(t.plan.city_style, "hanse", "Stil der Zielstadt")
	assert_eq(t.bridges.size(), 5, "fünf Brücken als Zonen")
	assert_eq(t.landmarks.size(), 2, "zwei Wahrzeichen in der Fernliste")


func test_outskirts_and_center_scenery() -> void:
	var t := _track()
	var p := t.plan
	assert_eq(t.segment_at(t.km_to_z(p.city_limits_km - 2.0)).scenery, "north_plain", "vor den City Limits: Abschnitt")
	assert_eq(t.segment_at(t.km_to_z(p.city_limits_km + 0.5)).scenery, "city_hanse_outskirts", "Stadtrand")
	assert_eq(t.segment_at(t.km_to_z(p.length_km - 7.9)).scenery, "city_hanse_center", "Zentrum ab center_km")
	assert_eq(t.segment_at(t.km_to_z(p.length_km - 8.1)).scenery, "city_hanse_outskirts", "kurz vor center_km noch Stadtrand")


func test_bridges_are_water_zones_with_a_bank() -> void:
	var t := _track()
	var segs := _city_segments(t)
	var water := {}
	var banks := 0
	var prev_water := false
	for s in segs:
		if s.water:
			water[s.bridge] = int(water.get(s.bridge, 0)) + 1
			assert_true(s.water_depth > 0.5, "Wasser unter der Fahrbahn")
			assert_true(s.bridge_i >= 0 and t.bridges[s.bridge_i]["type"] == s.bridge, "Brückenindex")
			assert_true(s.water_level <= 0.0 and s.water_level >= -s.water_depth - 0.001, "Boden unter der Brücke zwischen Wasser und Straße")
		if s.bank:
			banks += 1
			assert_true(prev_water, "Ufer direkt hinter dem Wasser")
			assert_true(s.water_depth > 0.5, "Ufer kennt die Wassertiefe")
		prev_water = s.water
	for typ: String in ["cable_stayed", "truss_arch", "stone_arch", "canal", "river"]:
		assert_true(water.has(typ), "Wassersegmente der Brücke %s" % typ)
	assert_eq(banks, 5, "ein Ufer je Brücke")
	# lengths in visible metres
	assert_near(float(water["truss_arch"]) * t.seg_len, 180.0, t.seg_len * 1.01, "Bogenbrücke 180 sichtbare m")
	assert_near(float(water["canal"]) * t.seg_len, 40.0, t.seg_len * 1.01, "Gracht 40 sichtbare m")
	var high: Dictionary = t.bridges[4]
	assert_near(float(high["depth"]), 25.0, 0.001, "Hochbrücke: height_m")
	assert_eq(t.bridge_at(float(high["z0"]) + 5.0), high, "bridge_at")
	# terrain under the deck: quay walls (one segment) in the city, long embankments under the high bridge
	var mid := (float(high["z0"]) + float(high["z1"])) * 0.5
	assert_near(Track.water_level_at(mid, high), -25.0, 0.001, "Wasser in der Mitte der Hochbrücke")
	assert_near(Track.water_level_at(float(high["z0"]), high), 0.0, 0.001, "Widerlager auf Straßenhöhe")
	var half := Track.water_level_at(float(high["z1"]) - float(high["slope"]) * 0.5, high)
	assert_near(half, -12.5, 0.01, "Böschung steigt zum Ufer")
	var canal: Dictionary = t.bridges[3]
	assert_near(float(canal["slope"]), t.seg_len, 0.001, "Gracht: Kaimauer (ein Segment)")


func test_no_scenery_props_on_water() -> void:
	var t := _track()
	for s in _city_segments(t):
		if not s.water:
			continue
		for sp: Dictionary in s.sprites:
			var kind := str(sp.get("kind", ""))
			var set_id := str(sp.get("set", ""))
			if kind == "prop":
				assert_true(set_id.begins_with("props/bridge_") or set_id == "props/houseboat" or set_id == "props/ferry_ship",
					"auf Brücken nur Brückenteile und Boote (%s bei km %.2f)" % [set_id, s.km])


func test_bridge_structures() -> void:
	var t := _track()
	var portals: Array[float] = []
	var pylons := 0
	var lamps := 0
	var boats := 0
	var ships := 0
	for s in _city_segments(t):
		var edges := t.road_edges_at(s.z)
		for sp: Dictionary in s.sprites:
			match str(sp.get("set", "")):
				"props/bridge_truss_arch":
					portals.append(float(sp["z"]))
					assert_eq(int(sp["side"]), 0, "Portal mittig")
					assert_true(bool(sp.get("overhead", false)), "Portal über der Fahrbahn")
					assert_eq(str(sp.get("proc", "")), "truss_portal", "prozeduraler Ersatz")
					assert_true(float(sp["fit_w"]) > edges.y - edges.x + 2.0 * t.shoulder_w, "Portal überspannt Fahrbahn und Gehwege")
				"props/bridge_pylon":
					pylons += 1
					assert_true(absf(float(sp["x"])) > edges.y + t.shoulder_w, "Pylon neben dem Deck")
					assert_true(float(sp.get("cables", 0.0)) > 10.0, "Seilfächer")
					# the procedural pylon beats the sprite (cables as 3D lines along the deck, pylon_m high)
					assert_eq(str(sp.get("proc", "")), "pylon", "prozeduraler Pylon")
					assert_true(bool(sp.get("prefer_proc", false)), "Pylon prozedural statt Sprite")
				"props/bridge_lamp":
					lamps += 1
				"props/houseboat":
					boats += 1
					assert_near(float(sp["h"]), -s.water_depth, 0.001, "Hausboot auf dem Wasser")
					assert_eq(str(sp.get("fallback", "")), "props/ferry_ship", "Ersatz-Sprite")
				"props/ferry_ship":
					ships += 1
					assert_true(float(sp["h"]) < -20.0, "Schiff tief unter der Hochbrücke")
	assert_true(portals.size() >= 4, "Portale über der Bogenbrücke (%d)" % portals.size())
	for i in range(1, portals.size()):
		assert_near(portals[i] - portals[i - 1], Track.BRIDGE_PORTAL_EVERY_M, 0.01, "Portal alle 40 m")
	assert_eq(pylons, 4, "zwei Pylonpaare an der Schrägseilbrücke")
	assert_true(lamps >= 8 and lamps % 2 == 0, "Laternen beidseitig auf der Steinbrücke (%d)" % lamps)
	assert_eq(boats, 2, "zwei Hausboote in der Gracht")
	assert_eq(ships, 1, "ein Schiff unter der Hochbrücke")


func test_landmarks_as_events_with_cleared_surroundings() -> void:
	var t := _track()
	var lm_z := t.km_to_z(t.plan.length_km - 2.0)
	var found := {}
	for s in _city_segments(t):
		var edges := t.road_edges_at(s.z)
		for sp: Dictionary in s.sprites:
			if bool(sp.get("landmark", false)):
				found[str(sp["set"])] = sp
				var side := int(sp["side"])
				var near := (float(sp["x"]) - edges.y) if side > 0 else (edges.x - float(sp["x"]))
				assert_true(near > 15.0, "Wahrzeichen mit Abstand vom Fahrbahnrand (%.1f)" % near)
				assert_eq(str(sp.get("align", "")), "edge", "Vorderkante an x_m")
			elif str(sp.get("kind", "")) == "prop" and int(sp.get("side", 0)) > 0:
				var z := float(sp.get("z", s.z))
				var set_id := str(sp.get("set", ""))
				if z > lm_z - 95.0 and z < lm_z + 35.0 and set_id.begins_with("props/city_"):
					fail("Gebäude %s im freigehaltenen Platz vor dem Wahrzeichen (z %.0f)" % [set_id, z - lm_z])
	assert_true(found.has("landmarks/test_tower"), "Wahrzeichen als Requisite")
	assert_true(found.has("props/church"), "Kirche als Wahrzeichen")
	var tower: Dictionary = found.get("landmarks/test_tower", {})
	assert_eq(str(tower.get("proc", "")), "tv_tower", "prozeduraler Ersatz statt Ersatz-Sprite")
	assert_false(tower.has("fallback"), "proc ersetzt das Ersatz-Sprite")
	assert_near(float(tower.get("height_m", 0.0)), 200.0, 0.001, "Höhe aus dem Katalog")
	assert_near(float(tower.get("z", 0.0)), lm_z, 0.01, "an km_to_finish")
	var church: Dictionary = found.get("props/church", {})
	assert_eq(str(church.get("tint", "")), "#c09080", "Farbton der Stadt")
	# far list: same placement, with z and x
	var far: Dictionary = t.landmarks[1]
	assert_eq(str(far["set"]), "landmarks/test_tower", "Fernliste nach km sortiert")
	assert_near(float(far["z"]), lm_z, 0.01, "z in der Fernliste")
	assert_near(float(far["x"]), float(tower.get("x", 0.0)), 0.01, "x in der Fernliste wie die Requisite")


func test_city_track_is_deterministic() -> void:
	var a := _track()
	var b := _track()
	var sa := _city_segments(a)
	var sb := _city_segments(b)
	assert_eq(sa.size(), sb.size(), "gleich viele Segmente")
	for i in range(0, sa.size(), 5):
		assert_eq(sa[i].sprites.size(), sb[i].sprites.size(), "gleiche Requisiten")
		assert_eq(sa[i].water, sb[i].water, "gleiches Wasser")


## QA regression: the park trees of a landmark plaza (placed up to clear_m[0] before the landmark) stood in
## the river when a bridge ended shortly before the landmark (Bern, Slavonski Brod, Posen, Riga, Lüttich …).
## Landmarks right behind the canal and the high bridge: no plaza tree on a bridge or within
## Track.PARK_TREE_BRIDGE_GAP_M of one, and on the water only bridge parts and boats.
func test_park_trees_keep_off_bridges() -> void:
	var d := _db()
	var lms: Array = d["cities"]["b"]["landmarks"]
	lms.append({"set": "props/church", "km_to_finish": 6.45, "side": 1, "x_m": 40.0, "scale": 2.0, "name": "Kirche an der Gracht"})
	lms.append({"set": "props/church", "km_to_finish": 3.2, "side": -1, "x_m": 30.0, "scale": 2.0, "name": "Kirche an der Hochbrücke"})
	var p := StagePlan.build(_stage(), "a", CITIES, COUNTRIES, cfg(), d)
	assert_true(p.warnings.is_empty(), "keine Warnungen: %s" % str(p.warnings))
	var t := Track.new()
	t.setup(p, cfg(), _scenery())
	assert_eq(t.landmarks.size(), 4, "vier Wahrzeichen")
	var trees := 0
	for i in t.segment_count:
		for ev: Dictionary in t.events_for_segment(i):
			var set_id := str(ev.get("set", ""))
			if not set_id.begins_with("props/tree_"):
				continue
			trees += 1
			var z := float(ev["z"])
			assert_true(t.bridge_at(z).is_empty(), "Parkbaum nicht auf der Brücke (%s bei z %.0f)" % [set_id, z])
			assert_false(t.near_bridge(z, Track.PARK_TREE_BRIDGE_GAP_M - 0.01), "Parkbaum mit Abstand zur Brücke (z %.0f)" % z)
			assert_true(bool(ev.get("mirror", false)), "Parkbaum links gespiegelt (Schatten von der Straße weg)")
	assert_true(trees >= 10, "die Plätze haben trotzdem Parkbäume (%d)" % trees)
	for s in _city_segments(t):
		if not s.water:
			continue
		for sp: Dictionary in s.sprites:
			var set_id := str(sp.get("set", ""))
			if str(sp.get("kind", "")) == "prop":
				assert_true(set_id.begins_with("props/bridge_") or set_id == "props/houseboat" or set_id == "props/ferry_ship",
					"auf Brücken nur Brückenteile und Boote (%s bei km %.2f)" % [set_id, s.km])


## The same with the real data: every arrival in every city (both directions of every stage) – no park tree
## of a landmark plaza on or next to a bridge (QA: 19 of 31 arrivals in the French, Belgian and Baltic cities
## alone had trees in the river), and every cable-stayed pylon drawn procedurally.
func test_real_arrivals_keep_park_trees_off_bridges() -> void:
	var load_json := func(path: String) -> Dictionary:
		var d: Variant = ConfigLoader.load_json(path)
		return d if d is Dictionary else {}
	var net := RoadNetwork.new()
	net.setup(load_json.call("res://data/network.json"), (load_json.call("res://data/countries.json") as Dictionary).get("countries", {}), cfg(), {})
	var db: Dictionary = load_json.call("res://data/cities.json")
	var sc := _scenery()
	var arrivals := 0
	var trees := 0
	var pylons := 0
	for id in net.stage_order:
		var st: Dictionary = net.stages[id]
		var dirs: Array = [str(st["from"])] if bool(st.get("dev", false)) else [str(st["from"]), str(st["to"])]
		for from_id in dirs:
			var p := StagePlan.build(st, from_id, net.cities, net.countries, cfg(), db)
			if p.landmarks.is_empty() and p.bridges.is_empty():
				continue
			arrivals += 1
			var t := Track.new()
			t.setup(p, cfg(), sc)
			for i in range(t.segment_index_at(t.km_to_z(p.city_limits_km)), t.segment_count):
				for ev: Dictionary in t.events_for_segment(i):
					var set_id := str(ev.get("set", ""))
					var z := float(ev["z"])
					if set_id == "props/bridge_pylon":
						pylons += 1
						assert_true(bool(ev.get("prefer_proc", false)), "%s ab %s: Pylon prozedural" % [id, from_id])
					elif set_id.begins_with("props/tree_"):
						trees += 1
						assert_false(t.near_bridge(z, Track.PARK_TREE_BRIDGE_GAP_M - 0.01),
							"%s ab %s: Parkbaum bei km %.2f nicht an einer Brücke" % [id, from_id, t.z_to_km(z)])
	assert_true(arrivals > 80, "Ankünfte mit Wahrzeichen oder Brücken geprüft (%d)" % arrivals)
	assert_true(trees > 200, "Parkbäume geprüft (%d)" % trees)
	assert_true(pylons >= 8, "Pylone der Schrägseilbrücken geprüft (%d)" % pylons)
