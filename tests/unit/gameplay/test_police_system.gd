extends TestCase
## PoliceSystem: radar warning/zone/tolerance, chase gap, escape window, catch, stop, release.

const Fx := preload("res://tests/sim/fixtures.gd")
const Sim := preload("res://tests/sim/gameplay_sim.gd")
const DT := 1.0 / 60.0


func _police(c: Dictionary, radars: Array = [{"km": 30.0, "limit": 120}]) -> PoliceSystem:
	var p := PoliceSystem.new()
	p.setup(c, Fx.make_plan(c, 200.0, [], radars))
	return p


## Drives at constant speed from km for `seconds`; returns the km reached. cap = curve limit of the police car
## (PoliceSystem.update road_cap_kmh, INF = straight road).
func _drive(p: PoliceSystem, km: float, speed: float, seconds: float, cap: float = INF) -> float:
	var t := 0.0
	while t < seconds - 0.0001:
		km += Units.odometer_km_delta(speed, DT, 12.0)
		p.update(DT, km, speed, cap)
		t += DT
	return km


## Curves slow the police car down too (since the understeer rework): in a bend that allows it 150 km/h it drives
## 150, so a player at 150 keeps the gap and escapes after the window (the escape threshold is the police's own
## 12-s average); a slower player loses ground and does not escape.
func test_police_slows_in_curves_and_escape_follows() -> void:
	var c := cfg()
	var p := _police(c)
	p.update(DT, 30.5, 150.0, 150.0)
	assert_eq(p.state, PoliceSystem.State.CHASE, "geblitzt in der Kurve")
	assert_near(p.police_kmh, 150.0, 0.001, "Polizei fährt die Kurvengrenze, nicht 220")
	var g0 := p.gap_m
	var km := _drive(p, 30.5, 150.0, 11.0, 150.0)
	assert_near(p.gap_m, g0, 0.01, "gleich schnell: Abstand bleibt")
	assert_near(p.escape_kmh, 150.0, 0.001, "Fluchtschwelle = Ø der Polizei")
	assert_eq(p.state, PoliceSystem.State.CHASE, "Fenster noch nicht voll")
	_drive(p, km, 150.0, 1.2, 150.0)
	assert_eq(p.state, PoliceSystem.State.IDLE, "entkommen: 12 s so schnell wie die Polizei")
	var q := _police(c)
	q.update(DT, 30.5, 150.0, 150.0)
	_drive(q, 30.5, 140.0, 13.0, 150.0)
	assert_eq(q.state, PoliceSystem.State.CHASE, "langsamer als die Polizei: keine Flucht")
	assert_near(q.gap_m, float(ConfigLoader.lookup(c, "police.start_gap_m", 320.0)) - 10.0 / 3.6 * 13.0, 0.5, "Abstand schrumpft mit (v − Polizei)")
	assert_true(q.escape_progress < 0.95, "Fluchtbalken nicht voll (%.2f)" % q.escape_progress)


## After a curve the police speeds up again with police.curve_accel_mps2 over the distance driven (a speed profile
## along the road); without curves it is the design rule: police_speed_kmh, escape from escape_speed_kmh.
func test_police_accelerates_after_curve() -> void:
	var c := cfg()
	var a := float(ConfigLoader.lookup(c, "police.curve_accel_mps2", 1.5))
	var p := _police(c)
	p.update(DT, 30.5, 200.0, 150.0)
	var km := _drive(p, 30.5, 200.0, 1.0, 150.0)
	assert_near(p.police_kmh, 150.0, 0.001, "in der Kurve")
	km = _drive(p, km, 230.0, 2.0)
	var expect := sqrt(pow(150.0 / 3.6, 2.0) + 2.0 * a * 230.0 / 3.6 * 2.0) * 3.6
	assert_near(p.police_kmh, expect, 0.1, "beschleunigt über die gefahrene Strecke (%.1f km/h)" % expect)
	_drive(p, km, 230.0, 8.8)
	assert_eq(p.state, PoliceSystem.State.CHASE, "Fenster noch nicht voll")
	assert_eq(p.police_kmh, float(ConfigLoader.lookup(c, "police.police_speed_kmh", 220.0)), "nach ~670 m wieder 220")
	var r := _police(c)
	r.update(DT, 30.5, 230.0)
	assert_eq(r.police_kmh, 220.0, "ohne Kurven: 220")
	_drive(r, 30.5, 230.0, 5.0)
	assert_near(r.escape_kmh, 220.0, 1e-9, "Fluchtschwelle auf der Geraden 220")


## The police car (police.agility 1) takes every curve slower than any player car (agility 2–5), in every weather:
## escaping is always possible – as every car reaches 220 km/h.
func test_police_curve_speed_below_every_car() -> void:
	var c := cfg()
	var p := _police(c)
	var lat := float(ConfigLoader.lookup(c, "vehicles.agility_ratings.%d.lat_grip" % int(ConfigLoader.lookup(c, "police.agility", 1)), 0.0))
	var r1 := float(ConfigLoader.lookup(c, "road.curve_radius_at_1_m", 120.0))
	var ce := float(ConfigLoader.lookup(c, "driving.grip_effects.curve_exp", 1.0))
	assert_near(p.curve_speed_mps(0.45, 0.88), sqrt(lat * pow(0.88, ce) * r1 / 0.45), 0.0001, "v = √(Haftung · Kurvenhaftung(Wetter) · R)")
	assert_eq(p.curve_speed_mps(0.0, 1.0), INF, "Gerade: keine Grenze")
	var env := EnvironmentModel.new()
	env.setup(c)
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(c, id)
		assert_near(p.curve_speed_mps(0.3, env.grip("snow")) / p.curve_speed_mps(0.3, 1.0), sqrt(v.curve_grip(env.grip("snow"))), 0.0001,
			"Polizei und Spieler: dieselbe Kurvenhaftung im Schnee")
		for grip: float in [1.0, env.grip("rain"), env.grip("snow")]:
			for curve: float in [0.1, 0.3, 0.9]:
				assert_true(p.curve_speed_mps(curve, grip) * 3.6 < v.safe_curve_speed(curve, grip) - 1.0,
					"%s schneller als die Polizei (Kurve %.1f, Haftung %.2f)" % [id, curve, grip])


func test_warning_once_with_limit() -> void:
	var c := cfg()
	var p := _police(c)
	var warned: Array = []
	p.radar_warning.connect(func(r: Dictionary) -> void: warned.append(int(r["limit"])))
	p.update(DT, 19.0, 100.0)
	assert_eq(warned.size(), 0, "vor der Warnung")
	assert_true(p.active_radar.is_empty(), "noch kein aktives Radar")
	p.update(DT, 20.0, 100.0)
	assert_eq(warned, [120], "Warnung 10 km vorher mit Limit")
	assert_eq(int(p.active_radar.get("limit", 0)), 120, "aktives Radar")
	p.update(DT, 21.0, 100.0)
	p.update(DT, 25.0, 100.0)
	assert_eq(warned.size(), 1, "nur einmal")
	# start right before the zone: no warning naming a wrong distance
	var q := _police(c)
	var w2: Array = []
	q.radar_warning.connect(func(r: Dictionary) -> void: w2.append(r))
	q.update(DT, 27.0, 100.0)
	assert_eq(w2.size(), 0, "keine veraltete Warnung")
	assert_false(q.active_radar.is_empty(), "Radar trotzdem aktiv (HUD)")


func test_zone_signals_and_tolerance() -> void:
	var c := cfg()
	var p := _police(c)
	var zone: Array = []
	var flashes: Array = []
	p.radar_zone.connect(func(_r: Dictionary, entered: bool) -> void: zone.append(entered))
	p.flashed.connect(func(_r: Dictionary, v: float) -> void: flashes.append(v))
	assert_near(p.trigger_speed(120.0), 138.0, 0.0001, "120 -> 138")
	assert_near(p.trigger_speed(100.0), 115.0, 0.0001, "100 -> 115")
	p.update(DT, 29.9, 200.0)
	assert_eq(flashes.size(), 0, "vor dem Feld kein Blitz")
	p.update(DT, 30.0, 137.9)
	assert_eq(zone, [true], "Feld betreten")
	assert_eq(flashes.size(), 0, "137,9 km/h: kein Blitz")
	p.update(DT, 32.0, 120.0)
	p.update(DT, 34.9, 137.99)
	assert_eq(flashes.size(), 0, "knapp unter der Toleranz")
	p.update(DT, 35.0, 200.0)
	assert_eq(zone, [true, false], "Feld verlassen")
	assert_eq(flashes.size(), 0, "nach dem Feld kein Blitz")
	var q := _police(c)
	var f2: Array = []
	q.flashed.connect(func(_r: Dictionary, v: float) -> void: f2.append(v))
	q.update(DT, 33.0, 138.0)
	assert_eq(f2, [138.0], "ab 138 km/h geblitzt")
	assert_eq(q.state, PoliceSystem.State.CHASE, "Verfolgung")
	assert_eq(q.flashes, 1, "Zähler")


func test_chase_gap_shrinks_and_grows() -> void:
	var c := cfg()
	var p := _police(c)
	var started := {"n": 0}
	p.chase_started.connect(func() -> void: started["n"] = int(started["n"]) + 1)
	p.update(DT, 30.5, 160.0)
	assert_eq(int(started["n"]), 1, "chase_started")
	var g0 := p.gap_m
	assert_eq(g0, float(ConfigLoader.lookup(c, "police.start_gap_m", 320.0)), "Startabstand")
	assert_near(p.police_car_offset_m(), -g0, 0.0001, "Polizeiwagen hinter dem Spieler")
	_drive(p, 30.5, 160.0, 2.0)
	assert_near(p.gap_m, g0 - (220.0 - 160.0) / 3.6 * 2.0, 0.2, "langsamer als 220: Abstand schrumpft")
	var g1 := p.gap_m
	_drive(p, 31.0, 250.0, 2.0)
	assert_near(p.gap_m, g1 + 30.0 / 3.6 * 2.0, 0.2, "schneller als 220: Abstand wächst")
	assert_near(p.traffic_factor(), float(ConfigLoader.lookup(c, "traffic.chase_density_factor", 0.2)), 0.0001, "Verkehr -80 %")
	assert_true(p.chase_active(), "Verfolgung aktiv")
	assert_true(p.siren_level() > 0.0, "Sirene")


func test_escape_when_holding_222_but_not_210() -> void:
	var c := cfg()
	var ok := Sim.escape_run(c, "limousine", 222.0)
	assert_eq(str(ok["result"]), "escaped", "222 km/h halten: Flucht gelingt")
	assert_near(float(ok["chase_s"]), float(ConfigLoader.lookup(c, "police.escape_window_s", 12.0)), 0.05, "nach dem Fenster")
	var fail := Sim.escape_run(c, "limousine", 210.0)
	assert_eq(str(fail["result"]), "caught", "210 km/h: erwischt")
	var fail2 := Sim.escape_run(c, "limousine", 219.0)
	assert_eq(str(fail2["result"]), "caught", "219 km/h: erwischt (Durchschnitt < 220)")


func test_escape_needs_full_window_and_average() -> void:
	var c := cfg()
	var p := _police(c)
	var esc := {"n": 0}
	p.escaped.connect(func() -> void: esc["n"] = int(esc["n"]) + 1)
	p.update(DT, 30.5, 260.0)
	var km := _drive(p, 30.5, 260.0, 11.0)
	assert_eq(int(esc["n"]), 0, "vor Ablauf des Fensters keine Flucht, auch bei 260")
	assert_true(p.escape_progress > 0.85 and p.escape_progress < 1.0, "Fortschritt %.2f" % p.escape_progress)
	km = _drive(p, km, 260.0, 1.2)
	assert_eq(int(esc["n"]), 1, "Flucht nach 12 s")
	assert_eq(p.state, PoliceSystem.State.IDLE, "wieder frei")
	assert_true(is_nan(p.police_car_offset_m()), "kein Polizeiwagen mehr")
	assert_eq(p.traffic_factor(), 1.0, "Verkehr normal")
	# a rolling average: a slow phase inside the window delays the escape
	var q := _police(c)
	q.update(DT, 30.5, 240.0)
	var k2 := _drive(q, 30.5, 240.0, 6.0)
	k2 = _drive(q, k2, 150.0, 3.0)
	k2 = _drive(q, k2, 240.0, 4.0)
	assert_eq(q.state, PoliceSystem.State.CHASE, "Ø über 12 s < 220 -> noch keine Flucht")
	assert_near(q.avg_speed, (3.0 * 240.0 + 3.0 * 150.0 + 4.0 * 240.0 + 2.0 * 240.0) / 12.0, 0.6, "gleitender Durchschnitt über 12 s")


func test_caught_stop_and_release() -> void:
	var c := cfg()
	var p := _police(c)
	var log: Array = []
	p.pull_over.connect(func() -> void: log.append("pull_over"))
	p.caught.connect(func() -> void: log.append("caught"))
	p.released.connect(func() -> void: log.append("released"))
	p.update(DT, 30.5, 140.0)
	var km := _drive(p, 30.5, 140.0, 13.0)
	assert_eq(p.state, PoliceSystem.State.CHASE, "noch nicht eingeholt")
	km = _drive(p, km, 140.0, 2.0)
	assert_eq(p.state, PoliceSystem.State.STOPPING, "Abstand 0 -> erwischt")
	assert_eq(log, ["pull_over"], "pull_over beim Zugriff")
	var req := p.control_request()
	assert_eq(float(req["target_kmh"]), 0.0, "anhalten")
	assert_eq(float(req["rate_kmh_s"]), float(ConfigLoader.lookup(c, "police.stop_decel_kmh_s", 40.0)), "Verzögerung")
	assert_true(p.police_car_offset_m() < 0.0, "Polizeiwagen kommt von hinten (überholt erst)")
	assert_true(p.chase_active(), "während des Anhaltens noch Verfolgung (Verkehr reduziert)")
	_drive(p, km, 140.0, float(ConfigLoader.lookup(c, "police.overtake_s", 2.2)))
	assert_near(p.police_car_offset_m(), float(ConfigLoader.lookup(c, "police.pull_over_offset_m", 12.0)), 0.0001, "Polizeiwagen nach dem Überholen vorn")
	assert_eq(p.state, PoliceSystem.State.STOPPING, "fährt noch (bremst)")
	p.update(DT, km, 0.0)
	assert_eq(p.state, PoliceSystem.State.STOPPED, "steht")
	assert_eq(log, ["pull_over", "caught"], "caught im Stand (Führerschein, bitte!)")
	var stop := float(ConfigLoader.lookup(c, "police.stop_duration_s", 10.0))
	assert_near(p.stop_time_left, stop, 0.0001, "10 s stehen")
	assert_false(p.control_request().is_empty(), "bleibt stehen")
	_drive(p, km, 0.0, stop - 0.1)
	assert_eq(p.state, PoliceSystem.State.STOPPED, "noch nicht frei")
	_drive(p, km, 0.0, 0.2)
	assert_eq(p.state, PoliceSystem.State.IDLE, "freigegeben")
	assert_eq(log, ["pull_over", "caught", "released"], "released")
	assert_true(p.control_request().is_empty(), "Kontrolle zurück, Anfahren aus dem Stand")
	assert_eq(p.stops, 1, "Zähler")


func test_catch_timeout() -> void:
	var c := cfg()
	var p := _police(c)
	p.update(DT, 30.5, 215.0)
	_drive(p, 30.5, 215.0, float(ConfigLoader.lookup(c, "police.catch_timeout_s", 40.0)) - 0.5)
	assert_eq(p.state, PoliceSystem.State.CHASE, "vor dem Zeitlimit")
	assert_true(p.gap_m > 100.0, "Abstand noch groß")
	_drive(p, 40.0, 215.0, 1.0)
	assert_eq(p.state, PoliceSystem.State.STOPPING, "Zeitlimit -> erwischt")


func test_no_new_radar_during_chase_and_each_radar_once() -> void:
	var c := cfg()
	var p := _police(c, [{"km": 30.0, "limit": 120}, {"km": 40.0, "limit": 100}])
	var flashes := {"n": 0}
	p.flashed.connect(func(_r: Dictionary, _v: float) -> void: flashes["n"] = int(flashes["n"]) + 1)
	p.update(DT, 34.0, 200.0)
	assert_eq(int(flashes["n"]), 1, "erstes Radar")
	p.update(DT, 41.0, 200.0)
	assert_eq(int(flashes["n"]), 1, "während der Verfolgung kein neues Radar")
	assert_eq(p.state, PoliceSystem.State.CHASE, "Verfolgung läuft")
	# after escaping, the same radar does not flash again, a new one does
	var q := _police(c, [{"km": 30.0, "limit": 120}, {"km": 60.0, "limit": 100}])
	var n2 := {"n": 0}
	q.flashed.connect(func(_r: Dictionary, _v: float) -> void: n2["n"] = int(n2["n"]) + 1)
	q.update(DT, 30.1, 250.0)
	var km := _drive(q, 30.1, 250.0, 12.5)
	assert_eq(q.state, PoliceSystem.State.IDLE, "entkommen")
	assert_true(km > 40.0, "Feld 1 verlassen")
	q.update(DT, 61.0, 250.0)
	assert_eq(int(n2["n"]), 2, "nächstes Radar blitzt wieder")


## Design: "Eine Verfolgung kann in die City Limits hineinlaufen und gilt dort normal weiter." Driven
## continuously (no jumps) with the real VehicleModel from a radar zone at the closest distance the StagePlan
## allows (zone end radar.no_radar_before_city_km before the City Limits): a player who tries to flee but only
## averages 200–219 km/h is still being chased inside the City Limits – and the chase ends normally there.
func test_chase_continues_into_city_limits() -> void:
	var c := cfg()
	var gap := float(ConfigLoader.lookup(c, "radar.no_radar_before_city_km", 30.0))
	var zone := float(ConfigLoader.lookup(c, "radar.zone_length_km", 5.0))
	var plan := Fx.make_plan(c, 120.0, [], [{"km": 100.0 - gap - zone, "limit": 120}])
	assert_near(plan.city_limits_km, 100.0, 0.001, "Testaufbau: City Limits ab km 100")
	for hold: float in [200.0, 210.0, 219.0]:
		var r := Sim.chase_into_city_run(c, plan, "limousine", hold)
		assert_true(float(r["flash_km"]) <= plan.radars[0]["km"] + 0.05, "%d km/h: am Feldanfang geblitzt (%.2f)" % [int(hold), float(r["flash_km"])])
		assert_true(float(r["city_chase_km"]) > 0.0, "%d km/h: Verfolgung läuft in die City Limits (%.2f km darin, Ende %s bei km %.1f)" % [int(hold), float(r["city_chase_km"]), str(r["end"]), float(r["end_km"])])
		assert_eq(str(r["end"]), "caught", "%d km/h: endet normal (erwischt)" % int(hold))
		assert_true(float(r["end_km"]) > plan.city_limits_km, "%d km/h: Zugriff in den City Limits" % int(hold))
	# escaping still works inside the City Limits: flee only once there
	var esc := Sim.chase_into_city_run(c, plan, "sportwagen", 205.0, 250.0)
	assert_eq(str(esc["end"]), "escaped", "Flucht in den City Limits möglich")
	assert_true(float(esc["end_km"]) > plan.city_limits_km, "entkommen in den City Limits (km %.1f)" % float(esc["end_km"]))


## The same with the real network data: from the radar zone closest to the City Limits (both directions of
## all stages) a chase at 210 km/h runs into the City Limits.
func test_chase_into_city_limits_on_real_stage() -> void:
	var c := cfg()
	var best := Sim.closest_radar_to_city(c)
	assert_false(best.is_empty(), "Netz geladen")
	var plan: StagePlan = best["plan"]
	var r := Sim.chase_into_city_run(c, plan, "kompakt", 210.0, -1.0, best["radar"])
	assert_true(float(r["city_chase_km"]) > 0.0, "%s: Verfolgung in den City Limits (%.2f km, Ende %s bei km %.1f, City ab %.1f)" % [
		plan.display_name, float(r["city_chase_km"]), str(r["end"]), float(r["end_km"]), plan.city_limits_km])


## POL-1: "wer erwischt wird, verliert effektiv 15–20 Sekunden" – also when the capture happens at a fuel
## station. Real FuelSystem + PoliceSystem + VehicleModel with the session's priority (fuel before police) and
## set_blocked(fuel.holds_car()): the standstill is the refuel PLUS the full police stop, in both orders.
func test_police_stop_adds_to_refuel_time() -> void:
	var c := cfg()
	var stop := float(ConfigLoader.lookup(c, "police.stop_duration_s", 10.0))
	var ref := Sim.police_refuel_run(c, "refuel_only")
	assert_true(float(ref["refuel_s"]) > 15.0, "Referenz: Tanken ohne Polizei (%.1f s)" % float(ref["refuel_s"]))
	assert_near(float(ref["police_extra_s"]), 0.0, 0.05, "Referenz: Stand endet mit dem Tanken")
	# the car stops inside the fixed part of the refuel: standing time = refuel minus the braking
	assert_between(float(ref["standstill_s"]), float(ref["refuel_s"]) - 2.0, float(ref["refuel_s"]), "Referenz: Stand ~ Tankdauer")
	for mode: String in ["refuel_first", "caught_first"]:
		var r := Sim.police_refuel_run(c, mode)
		var names: Array = []
		for e: Array in r["events"]:
			names.append(e[1])
		assert_eq(int(r["stops"]), 1, "%s: ein Polizeistopp (%s)" % [mode, str(names)])
		assert_true(float(r["police_extra_s"]) >= stop - 0.1,
			"%s: Stand %.1f s = Tanken %.1f s + Polizei %.1f s (>= %.0f s) (%s)" % [mode, float(r["standstill_s"]), float(r["refuel_stand_s"]),
				float(r["police_extra_s"]), stop, str(names)])
		assert_true(float(r["standstill_s"]) >= float(ref["standstill_s"]) + stop - 1.0,
			"%s: mindestens 10 s länger als Tanken allein (%.1f vs %.1f s)" % [mode, float(r["standstill_s"]), float(ref["standstill_s"])])
		assert_true(names.find("caught") > names.find("refuel_finished"), "%s: \"Führerschein, bitte!\" erst nach dem Tanken (%s)" % [mode, str(names)])
		assert_true(names.find("pull_over") >= 0 and names.find("refuel_started") >= 0, "%s: beides passiert" % mode)
	var first := Sim.police_refuel_run(c, "refuel_first")
	var names1: Array = []
	for e: Array in first["events"]:
		names1.append(e[1])
	assert_true(names1.find("refuel_started") < names1.find("pull_over"), "refuel_first: Zugriff während des Tankens (%s)" % str(names1))
	var second := Sim.police_refuel_run(c, "caught_first")
	var names2: Array = []
	for e: Array in second["events"]:
		names2.append(e[1])
	assert_true(names2.find("pull_over") < names2.find("refuel_started"), "caught_first: Tanken während des Anhaltens (%s)" % str(names2))


func test_stop_waits_while_another_system_holds_the_car() -> void:
	var c := cfg()
	var p := _police(c)
	var log: Array = []
	p.caught.connect(func() -> void: log.append("caught"))
	p.released.connect(func() -> void: log.append("released"))
	p.update(DT, 30.5, 140.0)
	var km := _drive(p, 30.5, 140.0, 16.0)
	assert_eq(p.state, PoliceSystem.State.STOPPING, "erwischt")
	# the car stands at the pump: the stop must not start (or run) while refuelling
	p.set_blocked(true)
	_drive(p, km, 0.0, 20.0)
	assert_eq(p.state, PoliceSystem.State.STOPPING, "blockiert: Polizeistopp wartet")
	assert_eq(log, [], "noch kein \"Führerschein, bitte!\"")
	assert_false(p.control_request().is_empty(), "Polizei will den Wagen weiter anhalten")
	p.set_blocked(false)
	p.update(DT, km, 0.0)
	assert_eq(p.state, PoliceSystem.State.STOPPED, "frei: jetzt beginnt der Stopp")
	assert_eq(log, ["caught"], "caught erst nach dem Tanken")
	var stop := float(ConfigLoader.lookup(c, "police.stop_duration_s", 10.0))
	_drive(p, km, 0.0, 4.0)
	# blocked again in the middle of the stop (e.g. refuelling starts): the countdown pauses
	p.set_blocked(true)
	var left := p.stop_time_left
	_drive(p, km, 0.0, 30.0)
	assert_near(p.stop_time_left, left, 0.0001, "Countdown pausiert")
	assert_eq(p.state, PoliceSystem.State.STOPPED, "steht noch")
	p.set_blocked(false)
	_drive(p, km, 0.0, stop - 4.0 - 0.1)
	assert_eq(p.state, PoliceSystem.State.STOPPED, "Reststandzeit läuft")
	_drive(p, km, 0.0, 0.2)
	assert_eq(log, ["caught", "released"], "danach frei")


## POL-3: the police car does not pop up in front of the player – during the chase it stays behind the
## camera, on pull_over it comes from there, overtakes (moving only forward, no jumps, it really passes the
## player) and stops at the pull-over position. The race module draws it one lane beside the player while
## they overlap and latches that side while the car is out of sight (offset < -camera distance - 6 m).
func test_police_car_overtakes_into_pull_over_position() -> void:
	var c := cfg()
	var pull := float(ConfigLoader.lookup(c, "police.pull_over_offset_m", 12.0))
	var cam := float(ConfigLoader.lookup(c, "render.camera_distance_m", 9.0))
	var overtake_s := float(ConfigLoader.lookup(c, "police.overtake_s", 2.2))
	var police_len := 4.8
	var player_len := 4.85
	for catch_speed: float in [160.0, 215.0]:   # caught by the gap / by the time limit (gap still large)
		var p := _police(c)
		p.update(DT, 30.5, catch_speed)
		var km := 30.5
		var frames := 0
		while p.state == PoliceSystem.State.CHASE and frames < 6000:
			km = _drive(p, km, catch_speed, DT)
			frames += 1
			assert_true(p.police_car_offset_m() + police_len * 0.5 < -cam, "Verfolgung: Polizeiwagen hinter der Kamera")
		assert_eq(p.state, PoliceSystem.State.STOPPING, "erwischt (%d km/h)" % int(catch_speed))
		assert_true(p.overtaking(), "Überholen läuft")
		var prev := p.police_car_offset_m()
		assert_true(prev < -cam - 6.0, "Überholen beginnt außer Sicht hinter der Kamera (%.1f m)" % prev)
		var max_step := 0.0
		var beside_s := 0.0
		var t := 0.0
		var v := catch_speed
		while t < 6.0:
			v = maxf(0.0, v - 40.0 * DT)
			p.update(DT, km, v)
			t += DT
			var off := p.police_car_offset_m()
			max_step = maxf(max_step, absf(off - prev))
			assert_true(off >= prev - 0.0001, "fährt nur nach vorn")
			prev = off
			if absf(off) < (police_len + player_len) * 0.5:
				beside_s += DT
		assert_true(max_step < 0.5, "kein Sprung (größter Schritt %.2f m je Bild)" % max_step)
		assert_true(beside_s > 0.2 and beside_s < overtake_s, "überholt sichtbar (%.2f s neben dem Spieler)" % beside_s)
		assert_near(p.police_car_offset_m(), pull, 0.0001, "steht vorn auf pull_over_offset_m")
		assert_false(p.overtaking(), "Überholen abgeschlossen")
	var idle := _police(c)
	assert_true(is_nan(idle.police_car_offset_m()), "ohne Verfolgung kein Polizeiwagen")
