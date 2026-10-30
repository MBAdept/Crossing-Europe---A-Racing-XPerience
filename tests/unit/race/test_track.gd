extends TestCase
## Track: determinism, window streaming, lane transitions, fuel lane, events, geometry bounds.
## Uses inline stage data (no autoloads).

const COUNTRIES := {
	"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}},
	"NL": {"name": "Niederlande", "name_local": "Nederland", "limits": {"autobahn": 100, "landstrasse": 80, "city": 50}},
}
const CITIES := {"a": {"name": "Astadt", "country": "DE"}, "b": {"name": "Bdorf", "country": "NL"}}


func _stage() -> Dictionary:
	return {
		"id": "t_track", "from": "a", "to": "b", "length_km": 120, "seed": 4711,
		"sections": [
			{"length_km": 40, "road": "autobahn", "curviness": 2, "hills": 2, "scenery": "north_plain", "country": "DE", "speed_limit": null},
			{"length_km": 30, "road": "landstrasse", "curviness": 3, "hills": 3, "scenery": "forest_hills", "country": "DE"},
			{"length_km": 50, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "polder", "country": "NL"},
		],
		"fuel_stations_km": [30, 85],
		"radars": [{"km": 15, "limit": 120}],
		"tunnels": [{"km": 50, "length_km": 3, "name": "Testtunnel"}],
		"borders": [{"km": 70, "to": "NL"}],
	}


func _plan() -> StagePlan:
	return StagePlan.build(_stage(), "a", CITIES, COUNTRIES, cfg())


func _scenery() -> Dictionary:
	var d: Variant = ConfigLoader.load_json("res://data/scenery.json")
	return (d as Dictionary).get("scenery", {}) if d is Dictionary else {}


func _track(seed_override: int = -1) -> Track:
	var t := Track.new()
	t.setup(_plan(), cfg(), _scenery(), seed_override)
	return t


func test_conversions() -> void:
	var t := _track()
	assert_near(t.km_to_z(12.0), 1000.0, 0.001, "12 km = 1000 sichtbare m bei Faktor 12")
	assert_near(t.z_to_km(t.km_to_z(37.5)), 37.5, 0.0001, "km <-> z")
	assert_near(t.length_z, t.km_to_z(120.0), 0.001, "Länge in m")
	assert_true(float(t.segment_count) * t.seg_len >= t.length_z + t.runout_m, "Auslaufstrecke hinter dem Ziel")


func test_determinism() -> void:
	var a := _track()
	var b := _track()
	var c := _track(99)
	var diff := 0
	for i in range(0, 4000, 7):
		var sa := a.get_segment(i)
		var sb := b.get_segment(i)
		assert_eq(sa.curve, sb.curve, "Kurve gleich bei Segment %d" % i)
		assert_eq(sa.y, sb.y, "Höhe gleich bei Segment %d" % i)
		assert_eq(sa.sprites.size(), sb.sprites.size(), "Requisiten gleich bei Segment %d" % i)
		if absf(sa.curve - c.get_segment(i).curve) > 0.0001 or absf(sa.y - c.get_segment(i).y) > 0.0001:
			diff += 1
	assert_true(diff > 50, "anderer Seed ergibt andere Strecke")


func test_window_streaming() -> void:
	var t := _track()
	var ahead := 900.0
	var z := 0.0
	var max_window := 0
	while z < 6000.0:
		t.update_window(z, ahead)
		max_window = maxi(max_window, t.window_size())
		var s := t.segment_at(z + 10.0)
		assert_eq(s.index, t.segment_index_at(z + 10.0), "Segment im Fenster bei z %.0f" % z)
		z += 37.0
	var limit := t.keep_behind + int(ahead / t.seg_len) + 4 + int(37.0 / t.seg_len) + 2
	assert_true(max_window <= limit, "Fenster begrenzt (%d <= %d)" % [max_window, limit])
	# segments behind the camera are discarded
	t.update_window(9000.0, ahead)
	assert_true(t.window_size() <= limit, "alte Segmente verworfen")
	assert_true(t.get_segment(10).index >= t.segment_index_at(9000.0) - t.keep_behind, "verworfene Indizes liefern das älteste gehaltene Segment")


func test_lane_transitions() -> void:
	var t := _track()
	var z_change := t.km_to_z(40.0)
	var trans := float(ConfigLoader.lookup(cfg(), "road.lane_transition_m", 180.0))
	assert_near(t.lanes_at(z_change - 50.0), 3.0, 0.0001, "Autobahn 3 Spuren")
	assert_near(t.lanes_at(z_change + trans + 10.0), 2.0, 0.0001, "Landstraße 2 Spuren")
	var prev := 3.0
	var z := z_change
	while z < z_change + trans:
		var l := t.lanes_at(z)
		assert_true(l <= prev + 0.0001 and l >= 2.0 - 0.0001, "Übergang monoton bei z %.0f" % z)
		prev = l
		z += 6.0
	assert_eq(t.lane_count_at(z_change - trans * 0.5), 2, "vor dem Übergang nutzt der Verkehr schon 2 Spuren")
	assert_eq(t.lane_count_at(z_change + trans * 0.5), 2, "im Übergang 2 Spuren")
	assert_eq(t.lane_count_at(z_change - trans * 1.5), 3, "vorher 3 Spuren")
	# lane centres stay inside the paved road during the transition
	z = z_change - 20.0
	while z < z_change + trans + 20.0:
		var edges := t.road_edges_at(z)
		for lane in t.lane_count_at(z):
			var x := t.lane_center_x(z, lane)
			assert_true(x > edges.x and x < edges.y, "Spurmitte %d innerhalb der Fahrbahn bei z %.0f" % [lane, z])
		z += 9.0
	# City Limits use the city lane count and road type
	var zc := t.km_to_z(t.plan.city_limits_km + 5.0)
	assert_eq(t.road_type_at(zc), "city", "City Limits")
	assert_eq(t.lane_count_at(zc), int(ConfigLoader.lookup(cfg(), "road.lanes.city", 2)), "Spuren in der Stadt")
	assert_true(t.is_city_at(zc), "is_city_at")


func test_fuel_lane_factor() -> void:
	var t := _track()
	var lane: Dictionary = t.plan.fuel_lanes[0]
	var z0 := t.km_to_z(float(lane["start_km"]))
	var z1 := t.km_to_z(float(lane["end_km"]))
	var taper := float(ConfigLoader.lookup(cfg(), "road.fuel_lane_taper_m", 40.0))
	assert_near(t.fuel_lane_factor(z0 - 5.0), 0.0, 0.0001, "vor der Tankspur zu")
	var mid := t.fuel_lane_factor(z0 + taper * 0.5)
	assert_true(mid > 0.05 and mid < 0.95, "Spur öffnet sich allmählich (%.2f)" % mid)
	assert_near(t.fuel_lane_factor((z0 + z1) * 0.5), 1.0, 0.0001, "Mitte offen")
	assert_true(t.fuel_lane_factor(z1 + taper * 0.5) < 0.95, "Spur mündet nach der Tankstelle ein")
	assert_near(t.fuel_lane_factor(z1 + taper + 5.0), 0.0, 0.0001, "danach zu")
	assert_false(t.fuel_lane_at(z0 + 2.0), "Tanken erst, wenn die Spur ganz offen ist")
	assert_true(t.fuel_lane_at((z0 + z1) * 0.5), "Tanken in der offenen Spur")
	assert_false(t.fuel_lane_at(z1 + taper * 0.5), "nicht mehr hinter der Tankstelle")
	var zm := (z0 + z1) * 0.5
	assert_near(t.road_edges_at(zm).y, t.main_right_edge(zm) + t.lane_w, 0.0001, "rechter Rand inkl. Tankspur")
	assert_near(t.fuel_lane_x(zm), t.lane_center_x(zm, t.lane_count_at(zm)), 0.0001, "Tankspur = Spur lane_count")
	assert_near(t.distance_to_fuel_lane(z0 - 100.0), 100.0, 0.01, "Abstand zur Tankspur")
	# station structures (pump islands, canopies) beside the lane
	var seg := t.segment_at(zm)
	assert_true((seg.fuel_zone & TrackSegment.FUEL_ISLAND) != 0, "Zapfsäuleninsel neben der Spur")


func test_events() -> void:
	var t := _track()
	var p := t.plan
	var signs := {}
	var z := 0.0
	while z < t.length_z + 10.0:
		t.update_window(z, 300.0)
		var s := t.segment_at(z)
		for sp: Dictionary in s.sprites:
			var key := str(sp.get("sign", sp.get("obj", sp.get("set", ""))))
			if not signs.has(key):
				signs[key] = []
			(signs[key] as Array).append(t.z_to_km(float(sp.get("z", s.z))))
			assert_true(float(sp.get("z", s.z)) >= s.z - 0.001 and float(sp.get("z", s.z)) < s.z + t.seg_len + 0.001, "Requisit liegt in seinem Segment")
		z += t.seg_len
	for st in p.fuel_stations_km:
		for k: float in [30.0, 15.0, 5.0]:
			if st - k > 0.0:
				assert_true(_has_near(signs.get("fuel", []), st - k), "Tankstellenschild %d km vor km %.0f" % [int(k), st])
	assert_true(_has_near(signs.get("radar", []), float(p.radars[0]["warn_km"])), "Radarwarnung 10 km vorher")
	assert_true(_has_near(signs.get("limit", []), float(p.radars[0]["km"])), "Tempolimit am Radar")
	assert_true(_has_near(signs.get("town", []), p.city_limits_km), "Ortsschild an den City Limits")
	assert_true(_has_near(signs.get("finish", []), p.length_km), "Ziel am Etappenende")
	assert_true(_has_near(signs.get("border", []), float(p.borders[0]["km"]), 0.4), "Grenzschild vor der Grenze")
	assert_true(_has_near(signs.get("tunnel", []), float(p.tunnels[0]["start_km"]), 0.8), "Tunnelschild vor dem Tunnel")
	assert_true(signs.has("streetlight"), "Straßenlaternen in der Stadt")
	assert_true(signs.has("props/customs_booth"), "Zollhäuschen an der Grenze")
	assert_true(signs.has("props/fuel_pump"), "Zapfsäulen an der Tankstelle")


func _has_near(list: Array, km: float, tol: float = 0.05) -> bool:
	for v: float in list:
		if absf(v - km) <= tol:
			return true
	return false


func test_geometry_bounds() -> void:
	var t := _track()
	var maxes: Array = ConfigLoader.lookup(cfg(), "road.curviness_max_curve", [0.0, 0.22, 0.45, 0.9])
	var grades: Array = ConfigLoader.lookup(cfg(), "road.hills_max_grade", [0.0, 0.025, 0.045, 0.07])
	var z := 0.0
	var max_all_c := 0.0
	var max_all_g := 0.0
	for m: float in maxes:
		max_all_c = maxf(max_all_c, m)
	for g: float in grades:
		max_all_g = maxf(max_all_g, g)
	while z < t.length_z:
		t.update_window(z, 10.0)
		var s := t.segment_at(z)
		var sec := t.plan.section_at(s.km)
		# shortly after a section change the previous road piece fades out
		var settled := t.km_to_z(s.km) - t.km_to_z(float(sec["start_km"])) > 260.0
		var cmax := float(maxes[int(sec["curviness"])]) if settled else max_all_c
		var gmax := float(grades[int(sec["hills"])]) if settled else max_all_g
		assert_true(absf(s.curve) <= cmax + 0.0001, "Kurve im Rahmen bei km %.1f" % s.km)
		assert_true(absf(t.grade_at(z)) <= gmax + 0.0001, "Steigung im Rahmen bei km %.1f" % s.km)
		if s.tunnel:
			assert_true(absf(s.curve) <= 0.25 + 0.0001, "sanfte Kurven im Tunnel")
		z += 30.0
	var fresh := _track()
	assert_near(fresh.curve_at(5.0), 0.0, 0.0001, "gerader Start")
	assert_near(fresh.grade_at(5.0), 0.0, 0.0001, "ebener Start")
	t.update_window(t.length_z, 300.0)
	assert_near(t.curve_at(t.length_z + 50.0), 0.0, 0.0001, "gerade Auslaufstrecke")
	assert_true(t.segment_at(t.length_z + 50.0).runout, "Auslauf markiert")


func test_scenery_props_outside_road() -> void:
	var t := _track()
	var z := 0.0
	var count := 0
	while z < t.km_to_z(60.0):
		t.update_window(z, 10.0)
		var s := t.segment_at(z)
		var edges := t.road_edges_at(s.z)
		for sp: Dictionary in s.sprites:
			if str(sp.get("kind", "")) == "prop" and not str(sp.get("set", "")).contains("fuel") and not str(sp.get("set", "")).contains("customs"):
				count += 1
				var x := float(sp["x"])
				assert_true(x < edges.x - t.shoulder_w + 0.01 or x > edges.y + t.shoulder_w - 0.01, "Requisit neben der Straße (x %.1f)" % x)
		z += t.seg_len
	assert_true(count > 100, "Landschaft hat Requisiten (%d)" % count)
	var fresh := _track()
	assert_eq(fresh.segment_at(fresh.km_to_z(10.0)).scenery, "north_plain", "Szenerie aus dem Abschnitt")
	assert_eq(fresh.segment_at(fresh.km_to_z(45.0)).scenery, "forest_hills", "Szenerie wechselt mit dem Abschnitt")
	assert_eq(fresh.segment_at(fresh.km_to_z(fresh.plan.city_limits_km + 1.0)).scenery, "city", "Szenerie city in den City Limits")


func test_scenery_file_complete() -> void:
	var sc := _scenery()
	for id: String in ["north_plain", "heath", "forest_hills", "rhine_main", "industrial", "polder", "ardennes",
			"farmland_fr", "loire", "pyrenees", "meseta", "mediterranean", "alps", "lombardy", "karst",
			"balkan_hills", "pannonian_plain", "bohemian", "east_plain", "baltic_forest", "coast", "city"]:
		assert_true(sc.has(id), "Szenerie %s vorhanden" % id)
		var s: Dictionary = sc.get(id, {})
		assert_eq((s.get("grass", []) as Array).size(), 2, "%s: zwei Grasfarben" % id)
		assert_true(RaceBackdrop.STYLES.has(str(s.get("background", {}).get("style", ""))), "%s: bekannter Hintergrundstil" % id)
		assert_true(["north", "continental", "alpine", "mediterranean", "default"].has(str(s.get("climate", ""))), "%s: Klima" % id)
		assert_true(not (s.get("props", []) as Array).is_empty(), "%s: Requisiten-Regeln" % id)
		for r: Dictionary in s.get("props", []):
			assert_true(str(r.get("set", "")).begins_with("props/"), "%s: Sprite-Set-ID" % id)
