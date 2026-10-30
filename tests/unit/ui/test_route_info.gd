extends TestCase
## Route choice as whole routes (ROUTE-1): continuation of an option to its target from the data
## module's "continuation", from complete race routes or from "via" cities; totals over all legs;
## data-module summaries win. Plus a check against the real network: the card's big number is the
## distance to the next target, not the length of the first stage.

## Synthetic network Hamburg -> Nürnberg: via Hannover/Kassel (short, more radars) or via
## Bremen/Frankfurt (long, fewer radars, more stations, more free autobahn).
const LEGS := {
	"hh_h": {"kind": "stage", "id": "hh_h", "from": "hamburg", "to": "hannover", "length_km": 150.0},
	"h_ks": {"kind": "stage", "id": "h_ks", "from": "hannover", "to": "kassel", "length_km": 165.0},
	"ks_n": {"kind": "stage", "id": "ks_n", "from": "kassel", "to": "nuernberg", "length_km": 320.0},
	"hh_hb": {"kind": "stage", "id": "hh_hb", "from": "hamburg", "to": "bremen", "length_km": 120.0},
	"hb_f": {"kind": "stage", "id": "hb_f", "from": "bremen", "to": "frankfurt", "length_km": 440.0},
	"f_n": {"kind": "stage", "id": "f_n", "from": "frankfurt", "to": "nuernberg", "length_km": 250.0},
}
const SUMMARIES := {
	"hh_h": {"length_km": 150.0, "autobahn_km": 150.0, "unlimited_km": 75.0, "radars": 2, "stations": 2, "tunnels": 1, "traffic": 1.0, "countries": ["DE"]},
	"h_ks": {"length_km": 165.0, "autobahn_km": 165.0, "unlimited_km": 40.0, "radars": 3, "stations": 2, "tunnels": 2, "traffic": 1.0, "countries": ["DE"]},
	"ks_n": {"length_km": 320.0, "autobahn_km": 300.0, "unlimited_km": 135.0, "radars": 2, "stations": 4, "tunnels": 0, "traffic": 0.8, "countries": ["DE"]},
	"hh_hb": {"length_km": 120.0, "autobahn_km": 120.0, "unlimited_km": 80.0, "radars": 0, "stations": 2, "tunnels": 0, "traffic": 1.1, "countries": ["DE"]},
	"hb_f": {"length_km": 440.0, "autobahn_km": 440.0, "unlimited_km": 250.0, "radars": 2, "stations": 6, "tunnels": 0, "traffic": 1.4, "countries": ["DE", "NL"]},
	"f_n": {"length_km": 250.0, "autobahn_km": 250.0, "unlimited_km": 145.0, "radars": 1, "stations": 3, "tunnels": 0, "traffic": 1.3, "countries": ["DE"]},
}


func _leg(id: String) -> Dictionary:
	return (LEGS[id] as Dictionary).duplicate()


func _summary(leg: Dictionary) -> Dictionary:
	return SUMMARIES.get(str(leg.get("id", "")), {})


func _link(a: String, b: String) -> Dictionary:
	for id in LEGS:
		var l: Dictionary = LEGS[id]
		if str(l["from"]) == a and str(l["to"]) == b:
			return l.duplicate()
	return {}


func _routes() -> Array:
	var kiel := {"kind": "stage", "id": "k_hh", "from": "kiel", "to": "hamburg", "length_km": 95.0}
	return [
		[kiel, _leg("hh_h"), _leg("h_ks"), _leg("ks_n")],
		[kiel, _leg("hh_hb"), _leg("hb_f"), _leg("f_n")],
	]


func test_continuation_from_data_module_wins() -> void:
	var opt := _leg("hh_h")
	opt["continuation"] = [_leg("h_ks"), _leg("ks_n")]
	var cont := RouteInfo.continuation(opt, "nuernberg", ["kiel", "hamburg"], [], Callable())
	assert_eq(cont.size(), 2, "zwei Folge-Etappen")
	assert_eq(str(cont[1]["to"]), "nuernberg", "endet am Ziel")


func test_continuation_from_race_routes() -> void:
	var cont := RouteInfo.continuation(_leg("hh_hb"), "nuernberg", ["kiel", "hamburg"], _routes(), Callable())
	assert_eq(cont.size(), 2, "Bremen -> Frankfurt -> Nürnberg")
	assert_eq(str(cont[0]["id"]), "hb_f", "über Frankfurt")
	# a route with another driven prefix does not match
	var none := RouteInfo.continuation(_leg("hh_hb"), "nuernberg", ["luebeck", "hamburg"], _routes(), Callable())
	assert_true(none.is_empty(), "anderer Rennverlauf passt nicht")


func test_continuation_from_via_cities() -> void:
	var opt := _leg("hh_h")
	opt["via"] = ["kassel", "nuernberg"]
	var cont := RouteInfo.continuation(opt, "nuernberg", ["kiel", "hamburg"], [], _link)
	assert_eq(cont.size(), 2, "Legs aus via rekonstruiert")
	assert_eq(str(cont[0]["id"]), "h_ks", "Hannover -> Kassel")
	var direct := _leg("ks_n")
	assert_true(RouteInfo.continuation(direct, "nuernberg", [], [], _link).is_empty(), "Option endet am Ziel: keine Fortsetzung")


func test_totals_show_the_trade_off() -> void:
	var east: Array = [_leg("hh_h"), _leg("h_ks"), _leg("ks_n")]
	var west: Array = [_leg("hh_hb"), _leg("hb_f"), _leg("f_n")]
	var te := RouteInfo.totals(east, _summary)
	var tw := RouteInfo.totals(west, _summary)
	assert_near(float(te["km"]), 635.0, 0.01, "Ostroute bis zum Ziel")
	assert_near(float(tw["km"]), 810.0, 0.01, "Westroute bis zum Ziel")
	assert_eq(int(te["radars"]), 7, "Radar summiert")
	assert_eq(int(tw["radars"]), 3, "Westroute weniger Radar")
	assert_eq(int(tw["stations"]), 11, "Westroute mehr Tankstellen")
	assert_near(float(tw["unlimited_km"]), 475.0, 0.01, "Westroute mehr freie Autobahn")
	assert_eq(int(te["stages"]), 3, "Etappen")
	assert_eq(tw["countries"], ["DE", "NL"] as Array[String], "Länder in Reihenfolge, ohne Doppelte")
	var traffic_w := (120.0 * 1.1 + 440.0 * 1.4 + 250.0 * 1.3) / 810.0
	assert_near(float(tw["traffic"]), traffic_w, 0.0001, "Verkehr längengewichtet")
	# the first stage alone points the wrong way – the totals do not
	assert_true(float(SUMMARIES["hh_hb"]["length_km"]) < float(SUMMARIES["hh_h"]["length_km"]), "erste Etappe West kürzer")
	assert_true(float(tw["km"]) > float(te["km"]), "Route West insgesamt länger")


func test_ferry_legs_are_counted_not_summed() -> void:
	var t := RouteInfo.totals([_leg("hh_h"), {"kind": "ferry", "id": "f", "from": "hannover", "to": "x", "length_km": 0.0}], _summary)
	assert_eq(int(t["ferries"]), 1, "Fähre gezählt")
	assert_eq(int(t["stages"]), 1, "eine Etappe")
	assert_near(float(t["km"]), 150.0, 0.01, "Fähre ohne km")


func test_data_summary_overrides_computed_values() -> void:
	var t := RouteInfo.totals([_leg("hh_h")], _summary)
	var opt := _leg("hh_h")
	opt["route_km"] = 640.0
	opt["route_summary"] = {"radars": 9, "stations": 7}
	RouteInfo.apply_data_summary(t, opt)
	assert_near(float(t["km"]), 640.0, 0.01, "route_km gewinnt")
	assert_eq(int(t["radars"]), 9, "Radar aus der Daten-Zusammenfassung")
	assert_eq(int(t["stations"]), 7, "Tankstellen aus der Daten-Zusammenfassung")
	assert_near(float(t["unlimited_km"]), 75.0, 0.01, "fehlende Schlüssel bleiben berechnet")


func test_via_cities_exclude_target() -> void:
	var cont: Array = [_leg("h_ks"), _leg("ks_n")]
	assert_eq(RouteInfo.via_cities(_leg("hh_h"), cont, "nuernberg"), ["hannover", "kassel"] as Array[String], "Zwischenstationen")
	assert_eq(UiFormat.route_via(["Hannover", "Kassel"], "Nürnberg"), "Route über Hannover › Kassel", "Untertitel")
	assert_eq(UiFormat.route_via([], "Nürnberg"), "direkt nach Nürnberg", "direkt zum Ziel")


## Real network (GameData autoload, present in the test runner): at every first route choice of the
## visible races the card's number is the distance to the next target (next_options total_km) and the
## totals cover the option plus its continuation.
func test_real_route_options_cover_the_whole_route() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("GameData") == null:
		return
	var checked := 0
	for rid in UiData.visible_race_ids():
		var race := RaceState.create(UiData.race(rid), "limousine", 8.0, 1)
		var guard := 0
		while not race.is_finished() and guard < 80:
			guard += 1
			var opts := UiData.next_options(race.race_id, race.current_city, race.waypoint_index, race.visited())
			if opts.is_empty():
				break
			if opts.size() > 1:
				for o in opts:
					var info := UiData.route_option(o, race.race_id, race.visited(), race.next_target())
					var t: Dictionary = info["totals"]
					assert_near(float(info["km"]), float(o.get("route_km", o.get("total_km", -1.0))), 0.6,
						"%s ab %s nach %s: km bis zum Ziel" % [rid, race.current_city, o["to"]])
					var cont: Array = info["continuation"]
					assert_eq(int(t["stages"]) + int(t["ferries"]), 1 + cont.size(), "%s: Summen über alle Legs" % rid)
					if not cont.is_empty():
						assert_eq(str((cont[-1] as Dictionary)["to"]), str(info["target"]), "%s: Fortsetzung endet am Ziel" % rid)
					# the card shows the route, not the first stage
					var card := RouteCard.new(o, info)
					assert_eq(card.km_text, UiFormat.km(float(info["km"])), "%s: große Zahl = km bis zum Ziel" % rid)
					assert_true(card.via.begins_with("Route über") or card.via.begins_with("direkt nach"), "%s: Untertitel %s" % [rid, card.via])
					assert_true(card.target_text.contains(UiData.city_name(str(info["target"]))), "%s: Ziel genannt" % rid)
					card.free()
					checked += 1
				break
			var leg: Dictionary = opts[0]
			if str(leg.get("kind", "")) == "ferry":
				race.apply_ferry(UiData.ferries().get(str(leg["id"]), {}), leg)
			else:
				race.apply_stage_result(leg, {"time_s": 100.0, "start_world_minutes": race.world_minutes, "end_world_minutes": race.world_minutes + 20.0}, cfg())
	assert_true(checked >= 2, "mindestens zwei Routenoptionen geprüft (%d)" % checked)
