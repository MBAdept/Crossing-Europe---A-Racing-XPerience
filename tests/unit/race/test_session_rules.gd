extends TestCase
## Race session rules (SessionRules) and tutorial hints (TutorialCoach): collisions in scripted phases,
## HUD distance to the next station, empty tank rolling into a fuel lane, the police car's overtaking
## path, the tutorial hint queue and its texts with the configured numbers.

const COUNTRIES := {"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}}}
const CITIES := {"a": {"name": "Astadt", "country": "DE"}, "b": {"name": "Bdorf", "country": "DE"}}


func _plan() -> StagePlan:
	var stage := {"id": "t_rules", "from": "a", "to": "b", "length_km": 120, "seed": 7,
		"sections": [{"length_km": 120, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "north_plain", "country": "DE", "speed_limit": null}],
		"fuel_stations_km": [50], "radars": [], "tunnels": [], "borders": []}
	return StagePlan.build(stage, "a", CITIES, COUNTRIES, cfg())


func test_collisions_stay_active_unless_standing() -> void:
	var min_kmh := float(ConfigLoader.lookup(cfg(), "render.scripted_collision_min_kmh", 30.0))
	assert_between(min_kmh, 10.0, 60.0, "Mindesttempo für Kollisionen in geskripteten Phasen")
	assert_true(SessionRules.collisions_active(false, false, 120.0, false, min_kmh), "normal fahren")
	assert_false(SessionRules.collisions_active(true, false, 120.0, false, min_kmh), "unverwundbar (Kollision, Nachlauf)")
	assert_true(SessionRules.collisions_active(false, true, 200.0, true, min_kmh), "leerer Tank, Ausrollen bei 200 km/h")
	assert_true(SessionRules.collisions_active(false, true, 12.0, true, min_kmh), "leerer Tank: auch langsam")
	assert_true(SessionRules.collisions_active(false, true, 150.0, false, min_kmh), "Anhalten für die Polizei / Auslaufen nach dem Ziel")
	assert_false(SessionRules.collisions_active(false, true, 0.0, false, min_kmh), "Stillstand: Tanken, Polizeikontrolle, Abschleppen")
	assert_false(SessionRules.collisions_active(false, true, min_kmh - 1.0, false, min_kmh), "langsame geskriptete Phase")


func test_next_station_for_the_hud() -> void:
	var p := _plan()
	assert_eq(p.fuel_lanes.size(), 1, "eine Tankspur")
	var lane: Dictionary = p.fuel_lanes[0]
	var a := float(lane["start_km"])
	var b := float(lane["end_km"])
	var st := float(lane["station_km"])
	assert_near(SessionRules.next_station_km(p, a - 10.0, false), st - (a - 10.0), 0.0001, "vor der Spur: Entfernung zur Tankstelle")
	assert_near(SessionRules.next_station_km(p, (a + b) * 0.5, false), 0.0, 0.0001, "in der Tankspur: die Tankstelle ist hier")
	assert_near(SessionRules.next_station_km(p, (a + b) * 0.5, true), 0.0, 0.0001, "beim Tanken: hier")
	assert_near(SessionRules.next_station_km(p, b + 1.0, false), -1.0, 0.0001, "keine Tankstelle mehr")
	assert_near(SessionRules.next_station_km(null, 3.0, false), -1.0, 0.0001, "ohne Plan")


func test_empty_tank_can_roll_into_a_fuel_lane() -> void:
	var v0 := 130.0 / 3.6
	var v1 := 60.0 / 3.6
	var acc := 18.0 / 3.6
	var d60 := SessionRules.roll_distance_m(130.0, 60.0, 18.0)
	assert_near(d60, (v0 * v0 - v1 * v1) / (2.0 * acc), 0.001, "Rollweg v²/2a")
	assert_near(SessionRules.roll_distance_m(40.0, 60.0, 18.0), 0.0, 0.0001, "schon langsamer")
	var stop := SessionRules.roll_distance_m(130.0, 0.0, 18.0)
	assert_true(SessionRules.can_roll_into_lane(0.0, 130.0, 18.0, 60.0, d60 - 20.0, d60 + 100.0), "Spur in Reichweite")
	assert_false(SessionRules.can_roll_into_lane(0.0, 130.0, 18.0, 60.0, stop + 10.0, stop + 200.0), "Spur hinter dem Haltepunkt")
	assert_false(SessionRules.can_roll_into_lane(0.0, 130.0, 18.0, 60.0, d60 - 200.0, d60 - 100.0), "Spur endet, bevor der Wagen langsam genug ist")
	assert_false(SessionRules.can_roll_into_lane(500.0, 130.0, 18.0, 60.0, 0.0, 100.0), "Spur liegt hinter dem Wagen")
	assert_true(SessionRules.can_roll_into_lane(50.0, 40.0, 18.0, 60.0, 0.0, 100.0), "langsam in der offenen Spur")


func test_police_car_overtakes_beside_the_player() -> void:
	var lw := 3.75
	var clear := (4.8 + 4.85) * 0.5
	assert_eq(SessionRules.police_pass_side(0.0, -5.625, lw), -1.0, "mittlere Spur: links vorbei")
	assert_eq(SessionRules.police_pass_side(3.75, -5.625, lw), -1.0, "rechte Spur: links vorbei")
	assert_eq(SessionRules.police_pass_side(-3.75, -5.625, lw), 1.0, "linke Spur: rechts vorbei")
	assert_eq(SessionRules.police_pass_side(-1.875, -3.75, lw), 1.0, "Landstraße links: rechts vorbei")
	assert_near(SessionRules.police_car_x(-30.0, 0.0, -1.0, lw, 12.0, clear), -lw, 0.0001, "dahinter: eine Spur daneben")
	assert_near(SessionRules.police_car_x(12.0, 0.0, -1.0, lw, 12.0, clear), -0.4, 0.0001, "Haltepunkt vor dem Spieler")
	# while the cars overlap lengthwise they never overlap sideways (no driving through the player)
	var off := -clear
	var prev := -INF
	while off <= 12.0:
		var x := SessionRules.police_car_x(off, 0.0, -1.0, lw, 12.0, clear)
		if absf(off) < clear:
			assert_true(absf(x) >= (1.9 + 1.86) * 0.5, "nebeneinander bei Versatz %.1f m (x %.2f)" % [off, x])
		assert_true(x >= prev - 0.0001, "zieht stetig vor den Spieler (Versatz %.1f)" % off)
		prev = x
		off += 0.25
	assert_near(SessionRules.police_car_x(2.0, 2.0, 1.0, lw, 12.0, clear), 2.0 + lw, 0.0001, "rechts vorbei")


func test_tutorial_queue() -> void:
	var c := TutorialCoach.new()
	c.setup(cfg())
	assert_near(c.hint_s, float(ConfigLoader.lookup(cfg(), "render.tutorial_hint_s", 6.0)), 0.0001, "Anzeigedauer aus der Konfiguration")
	assert_eq(c.trigger("start"), 3, "drei Hinweise zur Steuerung")
	assert_eq(c.trigger("start"), 0, "jedes Thema nur einmal")
	assert_eq(c.trigger("unknown_topic"), 0, "unbekanntes Thema")
	c.hold(1.0)
	assert_eq(c.update(0.5), "", "nach LOS! kurz warten")
	var first := c.update(0.6)
	assert_true(first.begins_with("Tipp:") and first.contains("Lenken"), "erster Hinweis: Lenken (%s)" % first)
	assert_eq(c.update(1.0), "", "der nächste Hinweis wartet")
	# an urgent topic (fuel lane) jumps the queue and comes at once
	c.trigger("fuel_announce")
	c.trigger("fuel_lane")
	var urgent := c.update(0.016)
	assert_true(urgent.contains("Tankspur") and urgent.contains("60 km/h"), "Tankspur-Hinweis sofort (%s)" % urgent)
	# the rest follows one by one, hint_s + gap_s apart
	var t := 0.0
	var next := ""
	while next == "" and t < 30.0:
		t += 0.1
		next = c.update(0.1)
	assert_near(t, c.hint_s + c.gap_s, 0.11, "Abstand zwischen Hinweisen")
	assert_true(next.contains("Gas"), "danach die übrigen Steuerungshinweise (%s)" % next)
	var rest: Array[String] = []
	for i in 400:
		var h := c.update(0.1)
		if h != "":
			rest.append(h)
	assert_eq(rest.size(), 2, "Gamepad-Hinweis und Ankündigungs-Hinweis folgen")
	assert_eq(c.pending(), 0, "Warteschlange leer")
	assert_eq(c.shown, ["start", "fuel_announce", "fuel_lane"] as Array[String], "Themen in Reihenfolge")


func test_tutorial_texts_use_the_configuration() -> void:
	var c := TutorialCoach.new()
	c.setup(cfg())
	var tol := int(round(float(ConfigLoader.lookup(cfg(), "radar.tolerance", 0.15)) * 100.0))
	var radar := c.hints_for("radar", {"limit": 120.0})
	assert_true(radar[0].contains("%d %%" % tol) and radar[0].contains("%d km/h" % int(round(120.0 * (1.0 + tol / 100.0)))), "Radartoleranz (%s)" % radar[0])
	var chase := c.hints_for("chase")
	assert_eq(chase.size(), 2, "Fluchtregel und Kosten")
	assert_true(chase[0].contains("%d km/h" % int(ConfigLoader.lookup(cfg(), "police.escape_speed_kmh", 220.0))), "Fluchttempo (%s)" % chase[0])
	assert_true(chase[0].contains("%d Sekunden" % int(ConfigLoader.lookup(cfg(), "police.escape_window_s", 12.0))), "Fluchtfenster (%s)" % chase[0])
	assert_true(chase[1].contains("%d Sekunden" % int(ConfigLoader.lookup(cfg(), "police.stop_duration_s", 10.0))), "Haltedauer (%s)" % chase[1])
	assert_true(c.hints_for("city", {"limit": 50})[0].contains("Tempo 50"), "City Limits")
	assert_true(c.hints_for("fuel_announce")[0].contains("30, 15 und 5 km"), "Ankündigungen (%s)" % c.hints_for("fuel_announce")[0])
	assert_true(c.hints_for("fuel_low", {"percent": 35.0})[0].contains("35 %"), "Tankfüllung beim Start")
	assert_true(c.hints_for("collision")[0].contains("%d km/h" % int(ConfigLoader.lookup(cfg(), "collision.target_speed_kmh", 10.0))), "Kollision")
	assert_eq(c.hints_for("curve"), ["Tipp: Vor scharfen Kurven bremsen – sonst schiebt der Wagen nach außen"] as Array[String], "Kurven")
	assert_true(TutorialCoach.URGENT.has("curve"), "Kurvenhinweis sofort (die Kurve kommt gerade)")
	for topic: String in ["start", "fuel_low", "fuel_hud", "fuel_announce", "fuel_lane", "refuel", "radar", "chase", "unlimited", "city", "collision", "curve"]:
		for h in c.hints_for(topic, {"limit": 120.0, "percent": 35.0}):
			# one line in the HUD message box (the HUD shrinks the font from about 72 characters on)
			assert_true(h.length() <= 80, "Hinweis passt in eine Zeile (%d Zeichen): %s" % [h.length(), h])
			assert_true(h.begins_with("Tipp:"), "als Tipp erkennbar: %s" % h)


## Review v0.5.0: rain and snow cost a lot of braking – the HUD says so at the start of such a stage, with the
## factor from the configuration; the City Limits are announced city_limits.announce_km ahead (once, never inside).
func test_weather_hint_and_city_announcement() -> void:
	var c := cfg()
	assert_eq(SessionRules.weather_hint(c, "normal"), "", "trocken: kein Hinweis")
	var snow := SessionRules.weather_hint(c, "snow")
	assert_true(snow.begins_with("Schnee") and snow.contains("×2") and snow.contains("gegenlenken"), "Schnee: %s" % snow)
	var rain := SessionRules.weather_hint(c, "rain")
	assert_true(rain.begins_with("Regen") and rain.contains("×1,3"), "Regen: %s" % rain)
	var tuned := ConfigLoader.deep_merge(c, {"driving": {"weather_grip_factor": {"snow": 0.25}}})
	assert_true(SessionRules.weather_hint(tuned, "snow").contains("×3,3"), "Faktor aus der Konfiguration: %s" % SessionRules.weather_hint(tuned, "snow"))
	assert_true(snow.length() <= 90 and rain.length() <= 90, "kurz genug fürs HUD")
	assert_eq(SessionRules.city_announce_text("Würzburg", 4.0, 50), "City Limits Würzburg in 4 km – Tempo 50", "Ansage")
	assert_true(SessionRules.city_announce_due(175.9, 176.05, 180.0, 4.0), "beim Überfahren von km 176")
	assert_false(SessionRules.city_announce_due(176.05, 176.2, 180.0, 4.0), "nur einmal")
	assert_false(SessionRules.city_announce_due(175.0, 175.5, 180.0, 4.0), "noch nicht")
	assert_false(SessionRules.city_announce_due(170.0, 180.5, 180.0, 4.0), "nie in den City Limits (Start mitten in der Stadt)")
	assert_false(SessionRules.city_announce_due(175.9, 176.05, 180.0, 0.0), "0 = keine Ansage")
