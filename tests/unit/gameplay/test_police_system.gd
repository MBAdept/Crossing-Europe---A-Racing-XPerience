extends TestCase
## PoliceSystem: radar warning/zone/tolerance, chase gap, escape window, catch, stop, release.

const Fx := preload("res://tests/sim/fixtures.gd")
const Sim := preload("res://tests/sim/gameplay_sim.gd")
const DT := 1.0 / 60.0


func _police(c: Dictionary, radars: Array = [{"km": 30.0, "limit": 120}]) -> PoliceSystem:
	var p := PoliceSystem.new()
	p.setup(c, Fx.make_plan(c, 200.0, [], radars))
	return p


## Drives at constant speed from km for `seconds`; returns the km reached.
func _drive(p: PoliceSystem, km: float, speed: float, seconds: float) -> float:
	var t := 0.0
	while t < seconds - 0.0001:
		km += Units.odometer_km_delta(speed, DT, 12.0)
		p.update(DT, km, speed)
		t += DT
	return km


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
	assert_near(p.police_car_offset_m(), float(ConfigLoader.lookup(c, "police.pull_over_offset_m", 12.0)), 0.0001, "Polizeiwagen vorn")
	assert_true(p.chase_active(), "während des Anhaltens noch Verfolgung (Verkehr reduziert)")
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


func test_chase_continues_into_city_limits() -> void:
	var c := cfg()
	var p := PoliceSystem.new()
	var plan := Fx.make_plan(c, 100.0, [], [{"km": 40.0, "limit": 120}])
	p.setup(c, plan)
	p.update(DT, 41.0, 180.0)
	assert_eq(p.state, PoliceSystem.State.CHASE, "Verfolgung")
	var km := 79.0
	_drive(p, km, 180.0, 3.0)
	assert_true(plan.is_city(km + 1.0), "in den City Limits")
	assert_eq(p.state, PoliceSystem.State.CHASE, "Verfolgung läuft in den City Limits weiter")
