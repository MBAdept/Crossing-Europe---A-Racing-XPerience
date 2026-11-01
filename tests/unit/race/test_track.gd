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
	# generation runs generation_lead_m() further ahead (curve warning signs are placed back into the road)
	var lead := int(t.generation_lead_m() / t.seg_len) + 1
	var limit := t.keep_behind + int(ahead / t.seg_len) + lead + 4 + int(37.0 / t.seg_len) + 2
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
	var ann := float(ConfigLoader.lookup(cfg(), "city_limits.announce_km", 4.0))
	assert_true(ann >= 3.0, "City Limits mindestens 3 km (250 m) vorher angekündigt")
	assert_eq((signs.get("town_ahead", []) as Array).size(), 1, "ein Vorschild der City Limits")
	assert_true(_has_near(signs.get("town_ahead", []), p.city_limits_km - ann), "Vorschild %s km vor den City Limits" % str(ann))
	for k: float in signs.get("distance", []):
		assert_true(absf(k - (p.city_limits_km - ann)) > 0.3, "Vorschild steht nicht auf einem Entfernungsschild (km %.1f)" % k)
	assert_true(_has_near(signs.get("finish", []), p.length_km), "Ziel am Etappenende")
	assert_true(_has_near(signs.get("border", []), float(p.borders[0]["km"]), 0.4), "Grenzschild vor der Grenze")
	assert_true(_has_near(signs.get("tunnel", []), float(p.tunnels[0]["start_km"]), 0.8), "Tunnelschild vor dem Tunnel")
	assert_true(signs.has("streetlight"), "Straßenlaternen in der Stadt")
	assert_true(signs.has("props/customs_booth"), "Zollhäuschen an der Grenze")
	assert_true(signs.has("props/fuel_pump"), "Zapfsäulen an der Tankstelle")


## Stage with a long tunnel that holds fuel announcements, a destination sign and a radar zone.
func _tunnel_track() -> Track:
	var stage := {
		"id": "t_tunnel", "from": "a", "to": "b", "length_km": 150, "seed": 99,
		"sections": [
			{"length_km": 100, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "alps", "country": "DE", "speed_limit": null},
			{"length_km": 50, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "polder", "country": "NL"},
		],
		"fuel_stations_km": [90],
		"radars": [{"km": 65, "limit": 100}],
		"tunnels": [{"km": 45, "length_km": 35, "name": "Langtunnel"}],
		"borders": [{"km": 100, "to": "NL"}],
	}
	var t := Track.new()
	t.setup(StagePlan.build(stage, "a", CITIES, COUNTRIES, cfg()), cfg(), _scenery())
	return t


func test_signs_in_tunnels_hang_inside_the_tube() -> void:
	var t := _tunnel_track()
	var wall_signs := {}
	var z := 0.0
	while z < t.length_z:
		t.update_window(z, 10.0)
		var s := t.segment_at(z)
		var e := t.road_edges_at(s.z)
		for sp: Dictionary in s.sprites:
			var kind := str(sp.get("kind", ""))
			var side := int(sp.get("side", 1))
			if s.tunnel and side != 0:
				assert_eq(kind, "sign", "im Tunnel nur Schilder an der Wand (%s bei km %.2f)" % [str(sp.get("set", sp.get("obj", ""))), s.km])
				assert_true(bool(sp.get("wall", false)), "Schild an der Tunnelwand bei km %.2f" % s.km)
				var hw := SignPainter.board_half_width(str(sp.get("sign", ""))) * float(sp["scale"])
				var x := float(sp["x"])
				assert_true(x + hw <= e.y + t.shoulder_w + 0.001 and x - hw >= e.x - t.shoulder_w - 0.001,
					"Schild %s bei km %.2f ganz innerhalb der Röhre" % [str(sp["sign"]), s.km])
				var over := (e.y - (x - hw)) if side > 0 else ((x + hw) - e.x)
				assert_true(over <= Track.WALL_SIGN_OVERHANG_M + 0.001, "Schild ragt höchstens %.1f m über die Fahrbahn (%.2f)" % [Track.WALL_SIGN_OVERHANG_M, over])
				var key := str(sp["sign"])
				wall_signs[key] = int(wall_signs.get(key, 0)) + 1
			elif kind == "sign":
				assert_false(bool(sp.get("wall", false)), "außerhalb von Tunneln auf Pfosten")
		z += t.seg_len
	assert_eq(int(wall_signs.get("fuel", 0)), 2, "30- und 15-km-Ankündigung im Tunnel sichtbar")
	assert_true(wall_signs.has("distance"), "Entfernungsschild im Tunnel sichtbar")
	assert_true(wall_signs.has("radar") and int(wall_signs.get("limit", 0)) >= 2, "Radarwarnung und Tempolimits im Tunnel")


func test_signs_carry_country_and_road() -> void:
	var t := _tunnel_track()
	var seen := {}
	var z := 0.0
	while z < t.length_z:
		t.update_window(z, 10.0)
		var s := t.segment_at(z)
		for sp: Dictionary in s.sprites:
			if str(sp.get("kind", "")) != "sign" or int(sp.get("side", 1)) == 0:
				continue
			assert_true(sp.has("country") and sp.has("road"), "Schild mit Land und Straßentyp")
			var sign := str(sp["sign"])
			if sign == "border":
				assert_eq(str(sp["country"]), "NL", "Grenzschild nennt das neue Land")
			else:
				assert_eq(str(sp["country"]), s.country, "Schild im Stil des Landes, in dem es steht")
			seen["%s:%s" % [sign, str(sp["country"])]] = true
		z += t.seg_len
	assert_true(seen.has("town:NL"), "Ortsschild im Stil des Ziellandes")
	assert_true(seen.has("distance:DE") and seen.has("distance:NL"), "Wegweiser vor und hinter der Grenze")


func _has_near(list: Array, km: float, tol: float = 0.05) -> bool:
	for v: float in list:
		if absf(v - km) <= tol:
			return true
	return false


func test_geometry_bounds() -> void:
	var t := _track()
	var maxes: Array = ConfigLoader.lookup(cfg(), "road.curviness_max_curve", [0.0, 0.30, 0.45, 0.9])
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


## Curve signs (road.curve_warning_*): every sharp stretch (|curve| >= 0.3) has a warning sign with its
## direction 150–450 m before it on the right and chevron boards on the outside pointing into the bend;
## gentle curves get no chevrons.
func test_sharp_curves_have_warning_sign_and_chevrons() -> void:
	var t := _track()
	var n := int(t.length_z / t.seg_len)
	t.get_segment(n)   # generate the whole road first: warning signs are inserted into earlier segments
	var signs: Array[Dictionary] = []
	for i in n:
		var s := t.get_segment(i)
		for sp: Dictionary in s.sprites:
			var kind := str(sp.get("sign", ""))
			if kind == "curve" or kind == "chevron":
				signs.append({"kind": kind, "z": float(sp["z"]), "value": int(sp["value"]), "side": int(sp["side"]), "x": float(sp["x"]),
					"curve": t.curve_at(float(sp["z"])), "edges": t.road_edges_at(float(sp["z"]))})
	var stretches := 0
	var i := 0
	while i < n:
		var s := t.get_segment(i)
		if absf(s.curve) < 0.3 or s.tunnel or s.city or s.z < 400.0 or s.z > t.length_z - 400.0:
			i += 1
			continue
		var j := i
		while j < n and absf(t.get_segment(j).curve) >= 0.3:
			j += 1
		stretches += 1
		var dir := 1 if s.curve > 0.0 else -1
		var warned := false
		var chevrons := 0
		for sg in signs:
			var z := float(sg["z"])
			if sg["kind"] == "curve" and z >= s.z - 450.0 and z <= s.z - 150.0 and int(sg["value"]) == dir:
				warned = true
				assert_eq(int(sg["side"]), 1, "Warnschild rechts")
				assert_true(float(sg["x"]) > (sg["edges"] as Vector2).y, "Warnschild neben der Fahrbahn")
			if sg["kind"] == "chevron" and z >= s.z - 60.0 and z <= float(j) * t.seg_len + 60.0:
				chevrons += 1
				assert_eq(int(sg["value"]), dir, "Pfeile zeigen in die Kurve")
				assert_eq(int(sg["side"]), -dir, "Richtungstafel außen")
				var e: Vector2 = sg["edges"]
				assert_true(float(sg["x"]) > e.y if dir < 0 else float(sg["x"]) < e.x, "Richtungstafel neben der Fahrbahn")
		assert_true(warned, "Warnschild vor der scharfen Kurve bei km %.1f" % s.km)
		assert_true(chevrons >= 1, "Richtungstafeln an der scharfen Kurve bei km %.1f" % s.km)
		i = j
	assert_true(stretches >= 10, "Teststrecke hat scharfe Kurven (%d)" % stretches)
	for sg in signs:
		if sg["kind"] == "chevron":
			assert_true(absf(float(sg["curve"])) >= 0.14, "keine Richtungstafel an sanften Kurven (%.2f)" % float(sg["curve"]))


## The warning sign is inserted into a segment generated earlier: streaming (the game's window) gives the
## same signs as generating the whole road at once, and every sign is in place before it can be seen.
func test_curve_signs_same_when_streamed() -> void:
	var whole := _track()
	var n := int(whole.length_z / whole.seg_len)
	whole.get_segment(n)
	var expect := {}
	for i in n:
		for sp: Dictionary in whole.get_segment(i).sprites:
			if str(sp.get("sign", "")) in ["curve", "chevron"]:
				expect["%s@%.1f" % [str(sp["sign"]), float(sp["z"])]] = true
	var streamed := _track()
	var got := {}
	var draw := float(ConfigLoader.lookup(cfg(), "render.draw_distance_m", 900.0))
	var z := -draw
	while z < streamed.length_z:
		streamed.update_window(maxf(z, 0.0), draw + 60.0)
		# the farthest segment the renderer can see now must already carry its signs
		var far := streamed.segment_at(clampf(z + draw, 0.0, streamed.length_z))
		for sp: Dictionary in far.sprites:
			if str(sp.get("sign", "")) in ["curve", "chevron"]:
				got["%s@%.1f" % [str(sp["sign"]), float(sp["z"])]] = true
		z += streamed.seg_len
	assert_true(expect.size() > 20, "Kurvenschilder vorhanden (%d)" % expect.size())
	assert_eq(got.size(), expect.size(), "gleiche Schilder beim Streamen, schon in Sichtweite vorhanden")
	for k: String in expect:
		assert_true(got.has(k), "Schild %s beim Streamen" % k)


## tests/sim/sight_check.gd on the test stage: with the warning signs every curve that needs braking is
## recognised early enough (1 s reaction + full braking) for the Gran Turismo – by day and in snow at night.
func test_curves_are_seen_in_time() -> void:
	var sight: GDScript = load("res://tests/sim/sight_check.gd")
	for from_id: String in ["a", "b"]:
		var plan := StagePlan.build(_stage(), from_id, CITIES, COUNTRIES, cfg())
		for opts: Dictionary in [{"vehicle": "gran_turismo"}, {"vehicle": "gran_turismo", "weather": "snow", "night": true}]:
			var r: Dictionary = sight.call("check", cfg(), plan, opts)
			var m: Variant = r["summary"]["min_margin_m"]
			assert_true(int(r["summary"]["stretches"]) > 5, "Kurven, die Bremsen verlangen (%s)" % str(opts))
			assert_true(m != null and float(m) >= 0.0, "ab %s, %s: Reserve %s m (schlechteste: %s)" % [from_id, str(opts), str(m),
				str((r["cases"] as Array).slice(0, 1))])


## Traffic case of the sight check (review v0.5.0 „Schnee in der Nacht“): from the moment the slowest traffic of the
## weather (City Limits queue in snow ≈ 21 km/h) comes out of the fog, the fastest car (Gran Turismo at its top
## speed in this weather) can stop with 1 s reaction and the full braking of the weather – also at night in snow
## (sight 338 m since the fix; with 248 m it was 47 m short) and at dusk. Crests are reported separately
## (docs/gameplay.md (i6)): only the fog part is decided by the weather.
func test_traffic_is_seen_in_time() -> void:
	var sight: GDScript = load("res://tests/sim/sight_check.gd")
	var plan := _plan()
	for opts: Dictionary in [{"weather": "snow", "night": true}, {"weather": "snow", "hour": 19.5}, {"weather": "rain", "night": true},
			{"weather": "normal", "night": true}, {"weather": "snow"}]:
		opts["vehicle"] = "gran_turismo"
		opts["crests"] = false
		opts["top_speed"] = true
		var r: Dictionary = sight.call("check_traffic", cfg(), plan, opts)
		var m: Variant = r["summary"]["min_margin_m"]
		assert_true(int(r["summary"]["points"]) > 500, "Punkte geprüft (%s)" % str(opts))
		assert_true(m != null and float(m) >= 10.0, "%s: Reserve %s m (schlechteste: %s)" % [str(opts), str(m), str((r["cases"] as Array).slice(0, 1))])
	# the old sight in snow at night (0.5 * 0.55 * 900 = 248 m) was too short – the check notices it
	var old := ConfigLoader.deep_merge(cfg(), {"weather": {"night_visibility_factor": 0.55}})
	var r2: Dictionary = sight.call("check_traffic", old, plan, {"vehicle": "gran_turismo", "weather": "snow", "night": true, "crests": false, "top_speed": true})
	assert_true(float(r2["summary"]["min_margin_m"]) < 0.0, "mit 248 m Sicht zu knapp: %s m" % str(r2["summary"]["min_margin_m"]))


## Inside a tunnel the road is dry: Track.grip_at gives 1.0 there and the weather grip outside (curve limits of the
## driving model, the autopilot, the police and the sight check).
func test_tunnel_road_is_dry() -> void:
	var t := _track()
	var inside := t.km_to_z(51.5)
	var outside := t.km_to_z(20.0)
	assert_true(t.segment_at(inside).tunnel and not t.segment_at(outside).tunnel, "Testtunnel bei km 50–53")
	assert_eq(t.grip_at(inside, 0.72), 1.0, "Schnee draußen, trocken im Tunnel")
	assert_eq(t.grip_at(outside, 0.72), 0.72, "draußen die Wetterhaftung")
	assert_eq(t.grip_at(outside, 1.0), 1.0, "trocken")


## Sharp stretches of a real stage (|curve| >= road.curve_warning_min_curve, outside tunnels and the calm zones at
## start and finish): how many, how many without a warning sign 0–260 m before their curve piece, chevrons in City
## Limits.
func _sign_coverage(t: Track) -> Dictionary:
	var minc := float(ConfigLoader.lookup(cfg(), "road.curve_warning_min_curve", 0.25))
	var n := t.segment_count
	t.get_segment(n - 1)
	var warn: Array[float] = []
	var out := {"stretches": 0, "missing": [], "city_stretches": 0, "city_chevrons": 0}
	for i in n:
		var sg := t.get_segment(i)
		for sp: Dictionary in sg.sprites:
			if str(sp.get("sign", "")) == "curve":
				warn.append(float(sp["z"]))
			elif str(sp.get("sign", "")) == "chevron" and sg.city:
				out["city_chevrons"] = int(out["city_chevrons"]) + 1
	var i := 0
	while i < n:
		var s := t.get_segment(i)
		if absf(s.curve) < minc or s.runout:
			i += 1
			continue
		var j := i
		while j < n and absf(t.get_segment(j).curve) >= minc * 0.5:
			j += 1
		var k := i   # start of the curve piece: back while |curve| still decreases
		while k > 0 and absf(t.get_segment(k - 1).curve) > 0.0005 and absf(t.get_segment(k - 1).curve) <= absf(t.get_segment(k).curve) + 1e-6:
			k -= 1
		if not s.tunnel and s.z > 400.0 and s.z < t.length_z - 300.0:
			out["stretches"] = int(out["stretches"]) + 1
			if s.city:
				out["city_stretches"] = int(out["city_stretches"]) + 1
			var ok := false
			for zw in warn:
				ok = ok or (zw >= float(k) * t.seg_len - 260.0 and zw <= s.z)
			if not ok:
				(out["missing"] as Array).append("km %.1f%s" % [s.km, " (City)" if s.city else ""])
		i = j
	return out


func _network_track(stage_id: String, from_id: String) -> Track:
	var net: Variant = ConfigLoader.load_json("res://data/network.json")
	var ctry: Variant = ConfigLoader.load_json("res://data/countries.json")
	var cities := {}
	for c: Dictionary in (net as Dictionary).get("cities", []):
		cities[str(c["id"])] = c
	for st: Dictionary in (net as Dictionary).get("stages", []):
		if str(st["id"]) == stage_id:
			var t := Track.new()
			t.setup(StagePlan.build(st, from_id, cities, (ctry as Dictionary).get("countries", {}), cfg()), cfg(), {})
			return t
	return null


## A section or tunnel break that cuts a sharp curve piece during its ramp-in (where the sign is decided) no
## longer drops its warning sign: the piece's peak decides (review: 5 sharp curves without sign). Sharp curves in
## City Limits get the warning sign too (no radar there, cars arrive at full speed), but no chevron boards.
func test_every_sharp_curve_has_a_warning_sign() -> void:
	var cut := 0
	var city := 0
	for case: Array in [["dev_testetappe", "dev_start"], ["bremen_dortmund", "bremen"], ["hamburg_bremen", "bremen"]]:
		var t := _network_track(str(case[0]), str(case[1]))
		assert_true(t != null, "Etappe %s" % case[0])
		var r := _sign_coverage(t)
		assert_true(int(r["stretches"]) >= 1, "%s: scharfe Kurven (%d)" % [case[0], int(r["stretches"])])
		assert_eq((r["missing"] as Array).size(), 0, "%s ab %s: Warnschild vor jeder scharfen Kurve, fehlt bei %s" % [case[0], case[1], str(r["missing"])])
		assert_eq(int(r["city_chevrons"]), 0, "%s: keine Richtungstafeln in den City Limits" % case[0])
		cut += t.curve_signs_cut
		city += int(r["city_stretches"])
	assert_true(cut >= 2, "Kurvenstücke, die ein Abschnittswechsel abschneidet, behalten ihr Schild (%d)" % cut)
	assert_true(city >= 1, "scharfe Kurve in den City Limits geprüft (%d)" % city)
