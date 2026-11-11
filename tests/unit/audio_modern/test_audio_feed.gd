extends TestCase
## AudioFeed v0 (contract D28, §4.7.2): what the Modern sound derives from the Track at the player's car – surfaces
## per side, zone, structures with their in/out events and joints, passed roadside objects – on a synthetic track
## and on a real one. It only reads, and only at and behind the car.

const COUNTRIES := {"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}}}
const CITIES := {"a": {"name": "Astadt", "country": "DE"}, "b": {"name": "Bdorf", "country": "DE"}}


## A track with just what the feed reads; remembers the highest segment index asked for.
class FakeTrack:
	extends RefCounted
	var seg_len := 3.0
	var time_scale := 10.0
	var shoulder_w := 2.5
	var scenery_db := {"wald": {"background": {"style": "forest"}}, "berg": {"background": {"style": "alps"}},
		"flach": {"background": {"style": "plain"}}, "vorstadt": {"background": {"style": "suburb"}}}
	var bridges: Array[Dictionary] = []
	var zones: Array[Dictionary] = []
	var plan := FakePlan.new()
	var segs: Dictionary = {}
	var max_asked := -1
	var asked := 0
	var scenery := "flach"
	var city := false
	var guardrail := true
	var road := "autobahn"

	func get_segment(index: int) -> TrackSegment:
		max_asked = maxi(max_asked, index)
		asked += 1
		if not segs.has(index):
			var s := TrackSegment.new()
			s.index = index
			s.z = index * seg_len
			s.scenery = scenery
			s.city = city
			s.guardrail = guardrail
			s.road = road
			segs[index] = s
		return segs[index]

	func road_edges_at(_z: float) -> Vector2:
		return Vector2(-5.625, 5.625)

	func put(z: float, p: Dictionary) -> void:
		get_segment(int(floor(z / seg_len))).sprites.append(p)
		max_asked = -1
		asked = 0


class FakePlan:
	extends RefCounted
	var tunnels: Array[Dictionary] = []
	# v1 (AU-C1): what the paving reads – sections, the destination city and its centre
	var stage_id := "t_feed"
	var to_id := "b"
	var length_km := 100.0
	var city_style := ""
	var center_km := 1.0e9
	var sections: Array[Dictionary] = []

	func section_index_at(km: float) -> int:
		for i in sections.size():
			if km < float(sections[i]["end_km"]):
				return i
		return sections.size() - 1

	func section_at(km: float) -> Dictionary:
		return {} if sections.is_empty() else sections[section_index_at(km)]

	func in_city_center(km: float) -> bool:
		return km >= center_km


func _feed(track: Object) -> AudioFeed:
	var f := AudioFeed.new()
	var m: Variant = ConfigLoader.lookup(cfg(), "audio.modern", {})
	f.setup(m if m is Dictionary else {})
	f.set_track(track)
	return f


func _state(z: float, x: float = 0.0, extra: Dictionary = {}) -> Dictionary:
	var s := {"z": z, "x": x, "speed": 130.0, "road_left": -5.625, "road_right": 5.625, "shoulder_m": 2.5,
		"off_road": 0, "rail_contact": false, "weather": "normal"}
	s.merge(extra, true)
	return s


## Drives from z0 to z1 in steps and returns every event.
func _drive(f: AudioFeed, z0: float, z1: float, step: float = 1.2, x: float = 0.0, extra: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var z := z0
	while z <= z1:
		f.update(_state(z, x, extra))
		for e in f.events:
			out.append(e.duplicate())
		z += step
	return out


func _names(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(str(e["name"]))
	return out


func test_without_track_or_position_nothing_is_derived() -> void:
	var f := AudioFeed.new()
	f.update(_state(100.0))
	assert_false(f.valid, "ohne Strecke ungültig")
	assert_false(f.has_track(), "keine Strecke")
	f.set_track(FakeTrack.new())
	assert_true(f.has_track(), "Strecke gesetzt")
	f.update({"speed": 100.0})
	assert_false(f.valid, "ohne Position ungültig")
	f.update(_state(100.0))
	assert_true(f.valid, "mit Position gültig")
	f.set_track(null)
	assert_false(f.has_track(), "Strecke wieder weg")
	assert_eq(f.zone, "open", "neutrale Werte")


func test_surface_under_a_wheel() -> void:
	var f := AudioFeed.new()
	f.rumble_in_m = 0.3
	f.rumble_out_m = 0.5
	var l := -5.625
	var r := 5.625
	assert_eq(f.surface_at(0.0, l, r, 2.5, false), "asphalt", "Fahrbahnmitte")
	assert_eq(f.surface_at(r - 0.31, l, r, 2.5, false), "asphalt", "knapp vor der Randlinie")
	assert_eq(f.surface_at(r - 0.2, l, r, 2.5, false), "rumble", "auf der Randlinie")
	assert_eq(f.surface_at(r + 0.4, l, r, 2.5, false), "rumble", "auf dem Rüttelstreifen")
	assert_eq(f.surface_at(r + 0.6, l, r, 2.5, false), "shoulder", "Bankett")
	assert_eq(f.surface_at(l - 1.5, l, r, 2.5, false), "shoulder", "Bankett links")
	assert_eq(f.surface_at(r + 2.6, l, r, 2.5, false), "grass", "jenseits des Banketts")
	assert_eq(f.surface_at(r + 1.0, l, r, 2.5, true), "grass", "am offenen Rand: Gras")
	for s in [f.surface_at(0.0, l, r, 2.5, false), f.surface_at(r + 9.0, l, r, 2.5, false)]:
		assert_true(AudioFeed.SURFACES.has(s), "bekannte Oberfläche")


func test_surfaces_per_side_from_the_state() -> void:
	var f := _feed(FakeTrack.new())
	f.set_vehicle_width(1.86)
	assert_near(f.track_half_m, 0.78, 0.01, "halbe Spurweite aus der Fahrzeugbreite")
	f.update(_state(50.0, 0.0))
	assert_eq([f.surface_l, f.surface_r], ["asphalt", "asphalt"], "mittig")
	f.update(_state(51.0, 5.0))        # right wheels at 5.78: over the edge by 0.16 m
	assert_eq([f.surface_l, f.surface_r], ["asphalt", "rumble"], "rechte Räder auf dem Rüttelstreifen")
	f.update(_state(52.0, 6.0))        # right wheels on the shoulder, left wheels still on the road
	assert_eq([f.surface_l, f.surface_r], ["asphalt", "shoulder"], "rechts auf dem Bankett")
	f.update(_state(53.0, -6.0))
	assert_eq([f.surface_l, f.surface_r], ["shoulder", "asphalt"], "links auf dem Bankett")
	f.update(_state(53.5, 6.2))        # further out: the left wheels reach the edge line
	assert_eq([f.surface_l, f.surface_r], ["rumble", "shoulder"], "linke Räder auf der Randlinie")
	f.update(_state(54.0, 7.2, {"off_road": 2, "rail_contact": true}))
	assert_eq(f.surface_r, "shoulder", "an der Leitplanke: Bankett, kein Gras")
	f.update(_state(55.0, 7.2, {"off_road": 2, "rail_contact": false}))
	assert_eq(f.surface_r, "grass", "am offenen Rand rechts: Gras")
	assert_eq(f.surface_l, "shoulder", "die linken Räder noch auf dem Bankett")
	# weather: wet / snow outside, dry in a tunnel
	f.update(_state(56.0, 0.0, {"weather": "rain"}))
	assert_near(f.wet, 1.0, 1.0e-6, "Regen: nass")
	f.update(_state(57.0, 0.0, {"weather": "snow"}))
	assert_near(f.snow, 1.0, 1.0e-6, "Schnee")
	assert_near(f.wet, 0.0, 1.0e-6, "Schnee ist nicht nass")


func test_structures_and_their_events() -> void:
	var t := FakeTrack.new()
	t.plan.tunnels = [{"start_km": 3.0, "end_km": 4.0, "name": "T"}]          # z 300 … 400
	t.bridges = [{"z0": 600.0, "z1": 690.0, "type": "truss", "depth": 8.0}]
	t.zones = [{"kind": "fuel", "z0": 100.0, "z1": 200.0}, {"kind": "fuel_canopy", "z0": 120.0, "z1": 132.0},
		{"kind": "border", "z0": 800.0, "z1": 818.0, "country": "NL"}]
	var f := _feed(t)
	assert_eq(f.structures().size(), 4, "Tunnel, Brücke, zwei Dächer (die Tankzone selbst ist kein Bauwerk)")
	var ev := _drive(f, 90.0, 140.0)
	assert_eq(_names(ev), ["cover_in", "cover_out"] as Array[String], "unter dem Tankstellendach durch")
	assert_eq(str(ev[0]["kind"]), "fuel", "Art des Dachs")
	assert_near(float(ev[0]["z"]), 120.0, 1.0e-6, "Ort des Ereignisses")
	# tunnel
	ev = _drive(f, 280.0, 420.0, 1.2, 0.0, {"weather": "rain"})
	assert_eq(_names(ev), ["tunnel_in", "tunnel_out"] as Array[String], "Tunnel")
	f.update(_state(350.0, 0.0, {"weather": "rain"}))
	assert_true(f.tunnel, "im Tunnel")
	assert_eq(f.zone, "tunnel", "Zone Tunnel")
	assert_near(f.depth_m, 50.0, 1.0e-6, "50 m bis zum näheren Portal")
	assert_near(f.wet, 0.0, 1.0e-6, "im Tunnel trocken")
	# bridge (an unknown type: a concrete deck): joints at both ends and every 32 m in between
	f.update(_state(590.0))
	ev = _drive(f, 591.0, 700.0)
	var names := _names(ev)
	assert_eq(names[0], "bridge_in", "Brücke beginnt")
	assert_eq(names[1], "joint", "Fuge am Anfang")
	assert_eq(names[names.size() - 2], "joint", "Fuge am Ende")
	assert_eq(names[names.size() - 1], "bridge_out", "Brücke endet")
	var joints: Array[float] = []
	for e in ev:
		if str(e["name"]) == "joint":
			joints.append(float(e["z"]))
	assert_eq(joints, [600.0, 632.0, 664.0, 690.0] as Array[float], "Betondeck: Fugen alle 32 m und an den Enden (keine dicht vor dem Ende)")
	f.update(_state(640.0))
	assert_eq(f.bridge, "truss", "Brückentyp")
	assert_eq(f.zone, "bridge", "Zone Brücke")
	ev = _drive(f, 790.0, 830.0)
	assert_eq(_names(ev), ["cover_in", "cover_out"] as Array[String], "Grenzstation")
	assert_eq(str(ev[0]["kind"]), "border", "Grenzdach")


func test_zone_from_scenery_and_city() -> void:
	var t := FakeTrack.new()
	var f := _feed(t)
	for pair: Array in [["flach", "open"], ["wald", "forest"], ["berg", "valley"], ["vorstadt", "city"], ["unbekannt", "open"]]:
		t.scenery = str(pair[0])
		t.segs.clear()
		f.update(_state(30.0))
		assert_eq(f.zone, str(pair[1]), "Landschaft %s" % str(pair[0]))
		assert_true(AudioFeed.ZONES.has(f.zone), "bekannte Zone")
	t.scenery = "wald"
	t.city = true
	t.segs.clear()
	f.update(_state(33.0))
	assert_eq(f.zone, "city", "City Limits gehen vor")
	assert_true(f.city, "Stadt")
	assert_true(f.guardrail, "Leitplanke aus dem Segment")
	assert_eq(f.road, "autobahn", "Straßentyp")


func test_passed_objects() -> void:
	var t := FakeTrack.new()
	t.put(30.5, {"kind": "prop", "set": "props/tree_oak", "x": 9.0, "side": 1, "scale": 1.2, "z": 31.0})
	t.put(40.0, {"kind": "prop", "set": "props/bush_round", "x": 8.0, "side": 1, "scale": 1.0, "z": 40.5})
	t.put(51.0, {"kind": "sign", "sign": "limit", "x": -8.4, "side": -1, "scale": 1.0})
	t.put(60.0, {"kind": "sign", "sign": "start", "x": 0.0, "side": 0, "scale": 1.0})
	t.put(72.0, {"kind": "prop", "set": "props/wind_turbine", "x": 120.0, "side": 1, "scale": 1.0, "z": 72.5})
	t.put(81.0, {"kind": "object", "obj": "streetlight", "x": 7.5, "side": 1, "scale": 1.0, "z": 81.0})
	t.put(90.0, {"kind": "prop", "set": "props/city_hanse_gabled", "x": -11.0, "side": -1, "scale": 1.0, "z": 91.0})
	t.put(300.0, {"kind": "prop", "set": "props/tree_oak", "x": 9.0, "side": 1, "scale": 1.0, "z": 300.5})
	var f := _feed(t)
	var ev := _drive(f, 20.0, 110.0, 1.4, 1.875)
	assert_eq(_names(ev), ["pass_object", "pass_object", "pass_object", "pass_object", "pass_object"] as Array[String], "fünf Objekte am Rand, Busch und fernes Windrad nicht")
	assert_eq(str(ev[0]["kind"]), "tree", "Baum")
	assert_eq(int(ev[0]["side"]), 1, "rechts")
	assert_near(float(ev[0]["dist_m"]), 9.0 - 1.875, 1.0e-5, "Abstand vom Auto, nicht von der Mitte")
	assert_near(float(ev[0]["size"]), 1.2, 1.0e-5, "Größe mit Skalierung")
	assert_eq(str(ev[0]["set"]), "props/tree_oak", "Set")
	assert_eq([str(ev[1]["kind"]), int(ev[1]["side"])], ["sign", -1], "Schild links")
	assert_eq([str(ev[2]["kind"]), int(ev[2]["side"])], ["gantry", 0], "Schilderbrücke über der Fahrbahn")
	assert_near(float(ev[2]["dist_m"]), 0.0, 1.0e-6, "über dem Auto")
	assert_eq(str(ev[3]["kind"]), "post", "Laterne")
	assert_eq(str(ev[4]["kind"]), "building", "Haus")
	# each object once, in the order of the road
	var last := -1.0
	for e in ev:
		assert_true(float(e["z"]) > last, "in Fahrtrichtung geordnet")
		last = float(e["z"])
	# read-only and never ahead: the segment of the car is the farthest one asked for
	assert_eq(t.max_asked, int(floor(f.z / 3.0)), "kein Segment vor dem Auto angefasst")
	assert_true(t.asked < 400, "wenige Abfragen (%d)" % t.asked)
	# object kinds
	assert_eq(AudioFeed.object_kind({"kind": "prop", "set": "props/heather"})[0], "", "Heide klingt nicht")
	assert_eq(AudioFeed.object_kind({"kind": "prop", "set": "props/etwas_neues"})[0], "object", "Unbekanntes als Objekt")
	assert_eq(AudioFeed.object_kind({"kind": "prop", "set": "landmarks/michel"})[0], "building", "Wahrzeichen als Bauwerk")


func test_jumps_make_no_events() -> void:
	var t := FakeTrack.new()
	t.plan.tunnels = [{"start_km": 3.0, "end_km": 4.0, "name": "T"}]
	t.put(250.0, {"kind": "prop", "set": "props/tree_oak", "x": 8.0, "side": 1, "scale": 1.0, "z": 250.5})
	var f := _feed(t)
	f.update(_state(10.0))
	f.update(_state(500.0))      # start-km jump across a tree and a tunnel
	assert_true(f.events.is_empty(), "Versetzen: keine Ereignisse")
	assert_false(f.tunnel, "hinter dem Tunnel")
	f.update(_state(350.0))      # backwards (new stage)
	assert_true(f.events.is_empty(), "rückwärts: keine Ereignisse")
	assert_true(f.tunnel, "aber der Zustand stimmt")
	# the number of events per update is bounded
	var crowd := FakeTrack.new()
	for i in 40:
		crowd.put(30.0 + i * 0.05, {"kind": "prop", "set": "props/tree_oak", "x": 8.0, "side": 1, "scale": 1.0, "z": 30.0 + i * 0.05})
	var g := _feed(crowd)
	g.update(_state(20.0))
	g.update(_state(40.0))
	assert_eq(g.events.size(), g.max_events, "höchstens max_events je Bild")


## A real track: the feed finds its tunnel where the plan has it and never generates road ahead of the car.
func test_on_a_real_track() -> void:
	var stage := {"id": "t_feed", "from": "a", "to": "b", "length_km": 60, "seed": 4711,
		"sections": [{"length_km": 30, "road": "autobahn", "curviness": 2, "hills": 2, "scenery": "forest_hills", "country": "DE", "speed_limit": null},
			{"length_km": 30, "road": "landstrasse", "curviness": 3, "hills": 3, "scenery": "north_plain", "country": "DE"}],
		"fuel_stations_km": [20], "radars": [], "tunnels": [{"km": 10, "length_km": 2, "name": "Testtunnel"}], "borders": []}
	var plan := StagePlan.build(stage, "a", CITIES, COUNTRIES, cfg())
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var track := Track.new()
	track.setup(plan, cfg(), (sc as Dictionary).get("scenery", {}))
	var f := _feed(track)
	var has_tunnel := false
	for s in f.structures():
		has_tunnel = has_tunnel or str(s["kind"]) == "tunnel"
	assert_true(has_tunnel, "der Tunnel des Plans ist erfasst")
	var z0 := track.km_to_z(8.0)
	var z1 := track.km_to_z(12.5)
	var z := z0
	var names: Array[String] = []
	var passes := 0
	var mismatches := 0
	while z <= z1:
		track.update_window(z - 9.0, 300.0)   # as the race session does (camera behind the car)
		var gen_before := int(track.get("_gen_next"))
		f.update(_state(z, 0.0, {"road_left": track.road_edges_at(z).x, "road_right": track.road_edges_at(z).y}))
		assert_eq(int(track.get("_gen_next")), gen_before, "die Auswertung erzeugt keine Strecke")
		if f.tunnel != track.is_tunnel_at(z):
			mismatches += 1
		for e in f.events:
			if str(e["name"]) == "pass_object":
				passes += 1
			else:
				names.append(str(e["name"]))
		z += 130.0 / 3.6 / 60.0
	assert_eq(mismatches, 0, "Tunnel wie im Plan")
	assert_eq(names, ["tunnel_in", "tunnel_out"] as Array[String], "ein Tunnel durchfahren")
	assert_true(passes >= 3, "Objekte am Rand gemeldet (%d)" % passes)
	assert_eq(f.zone, "forest", "Mittelgebirge: Wald")
	assert_eq(f.road, "autobahn", "Straßentyp aus dem Segment")
	# alone (no session generating the road): asking at the car creates segments up to the car at most
	var fresh := Track.new()
	fresh.setup(plan, cfg(), (sc as Dictionary).get("scenery", {}))
	var g := _feed(fresh)
	g.update(_state(600.0))
	g.update(_state(601.0))
	assert_true(int(fresh.get("_gen_next")) <= fresh.segment_index_at(601.0) + 1, "nie weiter als bis zum Auto")


# --- v1 (AU-C1): paving, rumble roads, delineators, cutting -------------------------------------------------------

func _feed_with(track: Object, feed_cfg: Dictionary) -> AudioFeed:
	var f := AudioFeed.new()
	var m: Variant = ConfigLoader.lookup(cfg(), "audio.modern", {})
	var modern: Dictionary = (m as Dictionary).duplicate(true) if m is Dictionary else {}
	var fc: Dictionary = modern.get("feed", {})
	fc.merge(feed_cfg, true)
	modern["feed"] = fc
	f.setup(modern)
	f.set_track(track)
	return f


func test_paving_of_sections_cities_and_bridges() -> void:
	var t := FakeTrack.new()
	t.plan.sections = [{"name": "A1 Nord", "length_km": 5.0, "country": "DE", "scenery": "flach", "start_km": 0.0, "end_km": 5.0},
		{"name": "A1 Süd", "length_km": 5.0, "country": "FR", "scenery": "flach", "start_km": 5.0, "end_km": 10.0}]
	var f := _feed_with(t, {"concrete_share": {"DE": 1.0, "_": 0.0}})
	f.update(_state(100.0))
	assert_eq(f.paving, "concrete", "deutscher Abschnitt mit Anteil 1: Beton")
	assert_eq([f.surface_l, f.surface_r], ["concrete", "concrete"], "beide Seiten auf Beton")
	f.update(_state(700.0))            # km 7 (time_scale 10): the French section
	assert_eq(f.paving, "asphalt", "anderes Land mit Anteil 0: Asphalt")
	var g := _feed_with(t, {"concrete_share": {"_": 0.0}})
	g.update(_state(100.0))
	assert_eq(g.paving, "asphalt", "Anteil 0: Asphalt")
	# only roads of concrete_roads
	var h := _feed_with(t, {"concrete_share": {"DE": 1.0}, "concrete_roads": ["landstrasse"]})
	h.update(_state(100.0))
	assert_eq(h.paving, "asphalt", "Autobahn nicht in concrete_roads")
	# city centre of a cobbled style
	var c := FakeTrack.new()
	c.city = true
	c.plan.city_style = "hanse"
	c.plan.center_km = 0.0
	var cf := _feed_with(c, {"cobble_styles": ["hanse"], "cobble_share": 1.0})
	cf.update(_state(50.0))
	assert_eq(cf.paving, "cobbles", "Altstadt: Kopfsteinpflaster")
	assert_eq(cf.zone, "city", "Zone Stadt")
	cf.update(_state(51.0, 6.0))
	assert_eq(cf.surface_r, "cobbles", "in der Stadt ist der Rand gepflastert, kein Bankett")
	var cn := _feed_with(c, {"cobble_styles": ["paris"], "cobble_share": 1.0})
	cn.update(_state(50.0))
	assert_eq(cn.paving, "asphalt", "anderer Baustil: Asphalt")
	c.plan.center_km = 1.0e9
	var co := _feed_with(c, {"cobble_styles": ["hanse"], "cobble_share": 1.0})
	co.update(_state(50.0))
	assert_eq(co.paving, "asphalt", "Stadtrand: Asphalt")
	# bridges: steel deck, stone bridge, concrete deck
	for row: Array in [["cable_stayed", "steel", "deck"], ["truss_arch", "steel", "deck"], ["stone_arch", "stone", "cobbles"],
			["river", "concrete", "asphalt"], ["canal", "concrete", "asphalt"]]:
		var b := FakeTrack.new()
		b.bridges = [{"z0": 300.0, "z1": 500.0, "type": str(row[0])}]
		var bf := _feed_with(b, {})
		bf.update(_state(350.0))
		assert_eq([bf.deck, bf.paving], [str(row[1]), str(row[2])], "Brücke %s" % str(row[0]))
		bf.update(_state(351.0, 6.4))
		assert_eq(bf.surface_r, str(row[2]), "auf der Brücke kein Bankett (%s)" % str(row[0]))
		bf.update(_state(352.0))
		var ev := _drive(bf, 353.0, 520.0, 2.0)
		for e in ev:
			if str(e["name"]) == "joint":
				assert_eq(str(e["deck"]), str(row[1]), "Fuge kennt ihr Deck")
	assert_eq(AudioFeed.deck_of("gibtsnicht"), "concrete", "unbekannter Typ: Betondeck")
	# tunnel: asphalt, the shoulder is the walkway
	var tn := FakeTrack.new()
	tn.plan.tunnels = [{"start_km": 3.0, "end_km": 4.0, "name": "T"}]
	var tf := _feed_with(tn, {"concrete_share": {"_": 1.0}})
	tf.update(_state(350.0, 6.4))
	assert_eq([tf.paving, tf.surface_r], ["asphalt", "asphalt"], "im Tunnel Asphalt, Rand befestigt")
	for s in [f.paving, cf.paving, tf.paving]:
		assert_true(AudioFeed.PAVINGS.has(s) and AudioFeed.SURFACES.has(s), "bekannte Fahrbahn")


## The same section has the same paving in both driving directions; the share is roughly met.
func test_concrete_is_the_same_in_both_directions() -> void:
	var secs: Array = []
	for i in 12:
		secs.append({"length_km": 5 + i, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "north_plain", "country": "DE",
			"speed_limit": null, "name": "A7 Abschnitt %d" % i})
	var stage := {"id": "t_beton", "from": "a", "to": "b", "length_km": 126, "seed": 5, "sections": secs, "fuel_stations_km": [20],
		"radars": [], "tunnels": [], "borders": []}
	var fwd := StagePlan.build(stage, "a", CITIES, COUNTRIES, cfg())
	var rev := StagePlan.build(stage, "b", CITIES, COUNTRIES, cfg())
	assert_true(rev.reversed and not fwd.reversed, "zwei Richtungen")
	var t := FakeTrack.new()
	var ff := _feed_with(t, {"concrete_share": {"DE": 0.5}})
	ff.plan = fwd
	var fr := _feed_with(t, {"concrete_share": {"DE": 0.5}})
	fr.plan = rev
	var n := fwd.sections.size()
	var yes := 0
	for i in n:
		var sf: Dictionary = fwd.sections[i]
		var sr: Dictionary = rev.sections[n - 1 - i]
		assert_eq(str(sr.get("name", "")), str(sf.get("name", "")), "derselbe Abschnitt")
		var a := ff._concrete_section((float(sf["start_km"]) + float(sf["end_km"])) * 0.5)
		var b := fr._concrete_section((float(sr["start_km"]) + float(sr["end_km"])) * 0.5)
		assert_eq(a, b, "Abschnitt %d: in beiden Richtungen gleich" % i)
		yes += 1 if a else 0
	assert_between(float(yes), 2.0, 10.0, "Anteil 0,5 grob getroffen (%d von %d)" % [yes, n])
	assert_true(AudioFeed.unit_hash("x") >= 0.0 and AudioFeed.unit_hash("x") < 1.0, "Hash in [0, 1)")
	assert_near(AudioFeed.unit_hash("A7|Holstein"), AudioFeed.unit_hash("A7|Holstein"), 0.0, "Hash stabil")


func test_rumble_only_on_rumble_roads() -> void:
	var t := FakeTrack.new()
	var f := _feed_with(t, {})
	f.update(_state(50.0, 5.0))        # right wheels at 5.78
	assert_eq(f.surface_r, "rumble", "Autobahn: profilierte Randlinie")
	assert_true(f.rumble_road, "Rüttelstraße")
	t.road = "landstrasse"
	t.segs.clear()
	f.update(_state(51.0, 4.65))       # right wheels at 5.43: on the edge line, inside the paved edge
	assert_false(f.rumble_road, "Landstraße: keine Rüttellinie")
	assert_eq(f.surface_r, "asphalt", "Randlinie innen: Fahrbahn")
	f.update(_state(52.0, 5.0))        # 5.78: just outside the paved edge
	assert_eq(f.surface_r, "shoulder", "außen: Bankett statt Rüttelstreifen")
	var g := _feed_with(t, {"rumble_roads": ["landstrasse"]})
	g.update(_state(53.0, 5.0))
	assert_eq(g.surface_r, "rumble", "per Konfiguration auch auf der Landstraße")


func test_delineators_on_roads_without_guardrail() -> void:
	var t := FakeTrack.new()
	t.guardrail = false
	var f := _feed_with(t, {})
	f.set_vehicle_width(1.86)
	assert_near(f.body_half_m, 0.93, 1.0e-6, "halbe Karosseriebreite")
	var ev := _drive(f, 10.0, 260.0, 1.3, 1.875)
	var posts: Array[Dictionary] = []
	for e in ev:
		if str(e["name"]) == "pass_object" and str(e["set"]) == "delineator":
			posts.append(e)
	assert_eq(posts.size(), 10, "alle 50 m links und rechts ein Leitpfosten")
	assert_near(float(posts[0]["z"]), 50.0, 1.0e-6, "am Raster der Straße")
	assert_eq(str(posts[0]["kind"]), "post", "Art Pfosten")
	var right: Dictionary = posts[1] if int(posts[1]["side"]) == 1 else posts[0]
	assert_near(float(right["dist_m"]), 5.625 + 2.5 - AudioFeed.DELINEATOR_INSET_M - 1.875, 1.0e-4, "Abstand des rechten Pfostens")
	assert_false(bool(right["contact"]), "in der Spur: keine Berührung")
	# at the open limit the body overlaps the posts: contact on that side only
	var lim := 5.625 + 2.5 - 0.93
	var g := _feed_with(t, {})
	g.set_vehicle_width(1.86)
	ev = _drive(g, 10.0, 110.0, 1.3, lim, {"off_road": 2})
	var contacts := 0
	for e in ev:
		if str(e["name"]) == "pass_object" and bool(e.get("contact", false)):
			contacts += 1
			assert_eq(int(e["side"]), 1, "Berührung rechts")
	assert_eq(contacts, 2, "zwei Pfosten umgefahren (z 50 und 100)")
	# guardrail or City Limits: no delineators
	t.guardrail = true
	for s: TrackSegment in t.segs.values():
		s.guardrail = true
	var h := _feed_with(t, {})
	assert_true(_drive(h, 300.0, 420.0, 1.3, 1.875).is_empty(), "mit Leitplanke keine Leitpfosten")
	var c := FakeTrack.new()
	c.guardrail = false
	c.city = true
	var cf := _feed_with(c, {})
	assert_true(_drive(cf, 10.0, 130.0, 1.3, 1.875).is_empty(), "in der Stadt keine Leitpfosten")
	var nt := FakeTrack.new()
	nt.guardrail = false
	var off := _feed_with(nt, {"delineators": false})
	assert_true(_drive(off, 10.0, 130.0, 1.3, 1.875).is_empty(), "abschaltbar")


func test_cutting_between_rocks() -> void:
	var t := FakeTrack.new()
	t.put(40.0, {"kind": "prop", "set": "props/rock_a", "x": -(5.625 + 2.5 + 3.0), "side": -1, "scale": 1.0, "z": 40.0})
	t.put(46.0, {"kind": "prop", "set": "props/cliff", "x": 5.625 + 2.5 + 9.0, "side": 1, "scale": 1.0, "z": 46.0})
	t.put(400.0, {"kind": "prop", "set": "props/rock_a", "x": -(5.625 + 2.5 + 3.0), "side": -1, "scale": 1.0, "z": 400.0})
	t.put(404.0, {"kind": "prop", "set": "props/rock_a", "x": 5.625 + 2.5 + 30.0, "side": 1, "scale": 1.0, "z": 404.0})
	var f := _feed_with(t, {"cutting_dist_m": 14.0, "cutting_window_m": 60.0})
	_drive(f, 20.0, 60.0, 1.0)
	assert_eq(f.zone, "cutting", "Fels links und rechts nah am Rand: Einschnitt")
	assert_true(AudioFeed.ZONES.has(f.zone), "bekannte Zone")
	_drive(f, 61.0, 120.0, 1.0)
	assert_eq(f.zone, "open", "60 m danach wieder offen")
	_drive(f, 390.0, 420.0, 1.0)
	assert_eq(f.zone, "open", "ein ferner Fels auf einer Seite macht keinen Einschnitt")


# --- AU-R: joints per deck, no rumble at the fuel lane, a mixed hash ----------------------------------------------

## Expansion joints by deck material: steel at both ends and about every 100 m between the spans, a concrete
## viaduct every 32 m, a stone arch none at all (KRITIK-FAHRBAHN B5).
func test_joints_per_deck() -> void:
	var expect := {"cable_stayed": [300.0, 400.0, 500.0, 561.0], "truss_arch": [300.0, 400.0, 500.0, 561.0],
		"river": [300.0, 332.0, 364.0, 396.0, 428.0, 460.0, 492.0, 524.0, 561.0], "stone_arch": []}
	for type: String in expect:
		var b := FakeTrack.new()
		b.bridges = [{"z0": 300.0, "z1": 561.0, "type": type}]
		var bf := _feed_with(b, {})
		bf.update(_state(290.0))
		var ev := _drive(bf, 291.0, 580.0, 1.7)
		var joints: Array = []
		for e in ev:
			if str(e["name"]) == "joint":
				joints.append(float(e["z"]))
		assert_eq(joints, expect[type], "Fugen auf %s" % type)
		assert_true(_names(ev).has("bridge_in") and _names(ev).has("bridge_out"), "Brücke %s gemeldet" % type)
	# one number for every deck (the format before AU-R); 0 = only the ends
	var t := FakeTrack.new()
	t.bridges = [{"z0": 300.0, "z1": 400.0, "type": "stone_arch"}]
	var f := _feed_with(t, {"joint_every_m": 0.0})
	f.update(_state(290.0))
	var zs: Array = []
	for e in _drive(f, 291.0, 420.0, 1.7):
		if str(e["name"]) == "joint":
			zs.append(float(e["z"]))
	assert_eq(zs, [300.0, 400.0], "eine Zahl für alle Decks: 0 = nur an den Enden")
	assert_near(f.joint_spacing("gibtsnicht"), 0.0, 1.0e-6, "unbekanntes Deck wie Beton")


## While the segment has a fuel lane the right edge is a plain dashed line: no rumble on the right.
func test_no_rumble_at_the_fuel_lane() -> void:
	var t := FakeTrack.new()
	var f := _feed_with(t, {})
	f.update(_state(50.0, 5.0))        # right wheels at 5.78: on the profiled edge line
	assert_eq(f.surface_r, "rumble", "ohne Tankspur: Rüttellinie")
	for i in range(15, 40):
		t.get_segment(i).fuel_lane = 0.6
	f.update(_state(60.0, 5.0))
	assert_near(f.fuel_lane, 0.6, 1.0e-6, "Tankspur am Auto")
	assert_eq(f.surface_r, "asphalt", "Rand der Tankspur: Fahrbahn, keine Rüttellinie")
	f.update(_state(61.0, 5.6))        # right wheels at 6.38: outside the paved edge
	assert_eq(f.surface_r, "shoulder", "außen: Bankett")
	f.update(_state(62.0, -5.0))       # left wheels at -5.78: the left edge keeps its profile
	assert_eq(f.surface_l, "rumble", "links bleibt die Rüttellinie")


## The hash mixes keys that differ only in their last character (KRITIK-FAHRBAHN B2: djb2 gave every block of a
## city the same decision); the values are those of the reference in Python (murmur3 fmix32 over djb2).
func test_unit_hash_mixes_neighbouring_keys() -> void:
	assert_near(AudioFeed.unit_hash("hamburg|0"), 0.3253776431083679, 1.0e-9, "Bezugswert (Python)")
	assert_near(AudioFeed.unit_hash("hamburg|1"), 0.7149350643157959, 1.0e-9, "Bezugswert (Python)")
	assert_near(AudioFeed.unit_hash("A7|Holstein"), 0.48531436920166016, 1.0e-9, "Bezugswert (Python)")
	var yes := 0
	var n := 0
	var sum := 0.0
	for city in 40:
		for block in 10:
			var u := AudioFeed.unit_hash("stadt%d|%d" % [city, block])
			assert_true(u >= 0.0 and u < 1.0, "in [0, 1)")
			sum += u
			yes += 1 if u < 0.6 else 0
			n += 1
	assert_near(sum / n, 0.5, 0.03, "gleich verteilt (Mittel %.3f)" % (sum / n))
	assert_near(float(yes) / n, 0.6, 0.05, "Anteil 0,6 getroffen (%.3f)" % (float(yes) / n))
	var same := 0
	for city in 40:
		var first := AudioFeed.unit_hash("stadt%d|0" % city) < 0.6
		var all_same := true
		for block in range(1, 10):
			all_same = all_same and ((AudioFeed.unit_hash("stadt%d|%d" % [city, block]) < 0.6) == first)
		same += 1 if all_same else 0
	assert_true(same <= 2, "kaum eine Stadt ganz oder gar nicht gepflastert (%d von 40; erwartet 0,4)" % same)
