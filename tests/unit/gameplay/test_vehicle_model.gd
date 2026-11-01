extends TestCase
## VehicleModel: acceleration curve, max speed, steering, understeer, road edge, collision, auto control.

const Fx := preload("res://tests/sim/fixtures.gd")
const Sim := preload("res://tests/sim/gameplay_sim.gd")
const DT := 1.0 / 60.0


func _run(v: VehicleModel, seconds: float, input: Dictionary, road: Dictionary, vmax_factor: float = 1.0, dt: float = DT) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		v.update(dt, input, road, {"vmax_factor": vmax_factor})
		t += dt


func test_resolve_spec_has_derived_values() -> void:
	for id: String in Fx.VEHICLES:
		var s := VehicleModel.resolve_spec(cfg(), id)
		assert_eq(str(s["id"]), id, "id")
		for k in ["t100_s", "t200_s", "steer_mps", "lat_grip", "consumption_factor", "accel_a0", "accel_q", "top_speed_time_s"]:
			assert_true(s.has(k), "%s hat %s" % [id, k])
		assert_between(float(s["accel_q"]), 0.02, 1.0, id + " Kurvenexponent q")
		assert_true(float(s["top_speed_time_s"]) < 60.0, id + " erreicht vmax in endlicher Zeit")
	var fallback := VehicleModel.resolve_spec(cfg(), "gibt_es_nicht")
	assert_eq(str(fallback["id"]), str(ConfigLoader.lookup(cfg(), "vehicles.default", "")), "unbekannter Typ -> Standardfahrzeug")


func test_accel_times_match_ratings_within_10_percent() -> void:
	for id: String in Fx.VEHICLES:
		var r := Sim.accel_run(cfg(), id)
		var t100 := float(r["t100"])
		var t200 := float(r["t200"])
		assert_between(t100 / float(r["t100_target"]), 0.9, 1.1, id + " 0-100")
		assert_between(t200 / float(r["t200_target"]), 0.9, 1.1, id + " 0-200")
		assert_true(float(r["t_top"]) > 0.0, id + " erreicht vmax")
		assert_near(float(r["top"]), float(r["vmax"]), 0.01, id + " Endgeschwindigkeit = vmax")


func test_acceleration_is_frame_rate_independent() -> void:
	var a := Fx.vehicle(cfg(), "limousine")
	var b := Fx.vehicle(cfg(), "limousine")
	var road := Fx.flat_road()
	_run(a, 6.0, {"throttle": 1.0}, road, 1.0, 1.0 / 30.0)
	_run(b, 6.0, {"throttle": 1.0}, road, 1.0, 1.0 / 144.0)
	assert_near(a.speed, b.speed, 0.3, "30 Hz vs. 144 Hz")


func test_fit_curve_reproduces_targets() -> void:
	var fit := VehicleModel.fit_accel_curve(245.0, 5.6, 14.5)
	assert_near(VehicleModel.curve_time(100.0, 245.0, fit.x, fit.y), 5.6, 0.01, "t100")
	assert_near(VehicleModel.curve_time(200.0, 245.0, fit.x, fit.y), 14.5, 0.01, "t200")
	assert_near(VehicleModel.curve_speed(VehicleModel.curve_time(150.0, 245.0, fit.x, fit.y), 245.0, fit.x, fit.y), 150.0, 0.01, "Umkehrfunktion")
	assert_eq(VehicleModel.curve_speed(1000.0, 245.0, fit.x, fit.y), 245.0, "nach langer Zeit genau vmax")


func test_brake_and_coast() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var road := Fx.flat_road()
	v.speed = 200.0
	_run(v, 1.0, {"brake": 1.0}, road)
	assert_near(v.speed, 200.0 - float(ConfigLoader.lookup(c, "driving.brake_decel_kmh_s", 70.0)), 0.5, "Vollbremsung 1 s")
	assert_true(v.braking, "Bremslicht")
	v.speed = 150.0
	_run(v, 1.0, {}, road)
	assert_near(v.speed, 150.0 - float(ConfigLoader.lookup(c, "driving.coast_decel_kmh_s", 5.0)), 0.5, "Rollen 1 s")
	assert_false(v.braking, "kein Bremslicht beim Rollen")
	v.speed = 3.0
	_run(v, 3.0, {"brake": 1.0}, road)
	assert_eq(v.speed, 0.0, "nicht rückwärts")


func test_max_speed_weather_night_grade() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var vmax := float(v.spec["vmax_kmh"])
	assert_near(v.max_speed(0.0, 1.0), vmax, 0.001, "flach")
	assert_near(v.max_speed(-0.06, 1.0), vmax, 0.001, "bergab erhöht nicht")
	var loss := float(ConfigLoader.lookup(c, "driving.grade_vmax_loss_per_percent", 0.012))
	var free := float(ConfigLoader.lookup(c, "driving.grade_free_percent", 0.0))
	assert_near(v.max_speed(free / 100.0, 1.0), vmax, 0.001, "bis grade_free_percent kein Verlust")
	assert_near(v.max_speed(0.07, 1.0), vmax * (1.0 - (7.0 - free) * loss), 0.001, "7 % bergauf: Verlust je Prozent darüber")
	assert_true(v.max_speed(0.07, 1.0) < vmax - 5.0, "steile Steigung senkt das Maximum spürbar")
	assert_near(v.max_speed(0.0, 0.9), vmax * 0.9, 0.001, "Umweltfaktor")
	# above the current maximum (e.g. uphill) the car settles down to it
	var road := Fx.flat_road()
	road["grade"] = 0.07
	v.speed = vmax
	_run(v, 4.0, {"throttle": 1.0}, road)
	assert_near(v.speed, v.max_speed(0.07, 1.0), 0.5, "bergauf auf neues Maximum")
	assert_near(v.vmax_effective, v.max_speed(0.07, 1.0), 0.001, "vmax_effective")


## VEH-1: "Untergrenze 230 km/h, damit jedes Fahrzeug die 220 km/h für die Polizeiflucht auch bei leicht
## verschlechterten Bedingungen erreicht." Slightly worse = rain + night on normal hilly roads (hills levels
## 1–2, up to road.hills_max_grade[2] = 4.5 %): every car keeps >= 220 on every such climb and escapes at
## full throttle. Steep mountain climbs (hills 3) still lower the maximum.
func test_grade_keeps_escape_speed_in_slightly_worse_conditions() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var worse := env.vmax_factor(2.0, "rain")
	var maxes: Array = ConfigLoader.lookup(c, "road.hills_max_grade", [0.0, 0.025, 0.045, 0.07])
	var hills2 := float(maxes[2])
	var hills3 := float(maxes[3])
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(c, id)
		var g := 0.0
		while g <= hills2 + 0.00001:
			assert_true(v.max_speed(g, worse) >= 220.0, "%s Regen+Nacht, %.1f %% Steigung: %.1f km/h" % [id, g * 100.0, v.max_speed(g, worse)])
			assert_true(v.max_speed(g, env.vmax_factor(12.0, "rain")) >= 220.0, "%s Regen, %.1f %%" % [id, g * 100.0])
			g += 0.0025
		assert_true(v.max_speed(hills3, 1.0) < v.max_speed(0.0, 1.0) - 3.0, "%s: Hügelstufe 3 (%.0f %%) senkt das Maximum" % [id, hills3 * 100.0])
		var r := Sim.escape_run(c, id, 400.0, worse, 140.0, hills2)
		assert_eq(str(r["result"]), "escaped", "%s: Vollgas ab 140 km/h, Regen + Nacht, %.1f %% bergauf -> Flucht (vmax %.1f)" % [id, hills2 * 100.0, float(r["vmax_eff"])])


func test_all_vehicles_reach_220_in_rain_at_night() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var f := env.vmax_factor(2.0, "rain")
	for id: String in Fx.VEHICLES:
		var r := Sim.accel_run(c, id, f)
		assert_true(float(r["top"]) >= 220.0, "%s Regen+Nacht: %.1f km/h" % [id, float(r["top"])])
		assert_true(float(r["t220"]) > 0.0 and float(r["t220"]) < 40.0, id + " erreicht 220 in endlicher Zeit")
	# snow may prevent an escape for the slowest car
	var snow := Sim.accel_run(c, "kompakt", env.vmax_factor(12.0, "snow"))
	assert_true(float(snow["top"]) < 220.0, "Schnee senkt den Kompakt unter 220")


func test_steering_ramps_with_speed_and_agility() -> void:
	var c := cfg()
	var road := Fx.flat_road()
	var v := Fx.vehicle(c, "limousine")
	v.speed = 0.0
	_run(v, 1.0, {"steer": 1.0}, road)
	assert_near(v.x, 0.0, 0.0001, "im Stand kein Lenken")
	var full := float(v.spec["steer_mps"])
	var ramp_kmh := float(ConfigLoader.lookup(c, "driving.steer_full_speed_kmh", 60.0))
	v.reset()
	v.speed = ramp_kmh * 0.5
	_run(v, 1.0, {"steer": 1.0, "throttle": 0.0}, road)
	var half_lat := v.lat_speed
	v.reset()
	v.speed = 150.0
	_run(v, 1.0, {"steer": 1.0, "throttle": 1.0}, Fx.flat_road(8))
	assert_near(v.lat_speed, full, 0.05, "volle Lenkgeschwindigkeit")
	assert_true(half_lat < full * 0.6 and half_lat > full * 0.35, "halbe Rampe: %.2f" % half_lat)
	var agile := Fx.vehicle(c, "kompakt")
	var heavy := Fx.vehicle(c, "gran_turismo")
	agile.speed = 150.0
	heavy.speed = 150.0
	_run(agile, 0.5, {"steer": -1.0, "throttle": 1.0}, road)
	_run(heavy, 0.5, {"steer": -1.0, "throttle": 1.0}, road)
	assert_true(agile.x < heavy.x, "Agilität 5 lenkt schneller als Agilität 2")
	assert_true(agile.steer_visual < -0.9, "steer_visual folgt der Lenkung")


func test_steering_response_is_smooth() -> void:
	var v := Fx.vehicle(cfg(), "limousine")
	var road := Fx.flat_road()
	v.speed = 150.0
	v.update(DT, {"steer": 1.0, "throttle": 1.0}, road, {"vmax_factor": 1.0})
	var full := float(v.spec["steer_mps"])
	assert_true(v.lat_speed > 0.0 and v.lat_speed < full * 0.3, "nach einem Frame noch nicht voll: %.2f" % v.lat_speed)
	_run(v, 0.6, {"steer": 1.0, "throttle": 1.0}, road)
	assert_true(v.lat_speed > full * 0.95, "nach 0,6 s fast voll")


func test_car_follows_road_below_safe_speed() -> void:
	var v := Fx.vehicle(cfg(), "limousine")
	var road := Fx.flat_road(3, true, 0.6)
	var safe := v.safe_curve_speed(0.6, 1.0)
	v.speed = safe * 0.95
	v.x = 1.0
	_run(v, 3.0, {"throttle": 0.0}, road)
	assert_near(v.x, 1.0, 0.0001, "keine Abdrift unterhalb der sicheren Kurvengeschwindigkeit")
	assert_eq(v.understeer, 0.0, "kein Untersteuern")
	# right at the limit (full throttle holds the speed just below it): still no drift, no scrub
	var w := Fx.vehicle(cfg(), "limousine")
	w.speed = w.max_speed(0.0, 1.0)
	var at_limit := Fx.flat_road(3, true, Sim.curve_for_overspeed(w, w.speed, -0.005))
	_run(w, 3.0, {"throttle": 1.0}, at_limit)
	assert_near(w.x, 0.0, 0.0001, "an der Grenze keine Abdrift")
	assert_eq(w.push_speed, 0.0, "keine Driftgeschwindigkeit")
	assert_eq(w.lat_excess, 0.0, "kein Haftungsüberschuss")
	assert_near(w.speed, w.max_speed(0.0, 1.0), 0.001, "kein Radieren")


func test_safe_curve_speed_formula_and_excess() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var r1 := float(ConfigLoader.lookup(c, "road.curve_radius_at_1_m", 120.0))
	var grip := float(v.spec["lat_grip"])
	assert_near(v.safe_curve_speed(0.45, 1.0), sqrt(grip * r1 / 0.45) * 3.6, 0.001, "v = √(Haftung · R)")
	assert_near(v.safe_curve_speed(-0.45, 1.0), v.safe_curve_speed(0.45, 1.0), 0.0001, "Richtung egal")
	assert_eq(v.safe_curve_speed(0.0, 1.0), INF, "Gerade: keine Grenze")
	var ce := float(ConfigLoader.lookup(c, "driving.grip_effects.curve_exp", 1.0))
	assert_near(v.grip_accel(0.88), grip * pow(0.88, ce), 0.0001, "Haftung × Kurvenhaftung(Wetter) = Wetterhaftung^curve_exp")
	assert_near(v.curve_grip(1.0), 1.0, 0.0001, "trocken: volle Kurvenhaftung")
	var safe := v.safe_curve_speed(0.45, 1.0)
	assert_eq(v.lateral_excess(0.45, 1.0, safe * 0.99), 0.0, "unter der Grenze kein Überschuss")
	var vm := safe * 1.2 / 3.6
	assert_near(v.lateral_excess(0.45, 1.0, safe * 1.2), vm * vm * 0.45 / r1 - grip, 0.0001, "Überschuss = v²/R − Haftung")
	assert_near(v.lateral_excess(0.45, 1.0, safe * 1.2) / grip, 0.44, 0.0001, "20 % zu schnell = 44 % mehr Querbeschleunigung")


## Design: "Agilität bestimmt … die Kurvengeschwindigkeit, ab der Untersteuern einsetzt" – higher agility,
## higher safe speed; at the same speed the agile car drifts less (or not at all).
func test_agility_orders_curve_speeds() -> void:
	var c := cfg()
	var by_agility := {}
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(c, id)
		by_agility[int(v.spec["agility"])] = v.safe_curve_speed(0.45, 1.0)
	var levels := by_agility.keys()
	levels.sort()
	for i in range(1, levels.size()):
		assert_true(float(by_agility[levels[i]]) > float(by_agility[levels[i - 1]]) + 3.0,
			"Agilität %d (%.0f km/h) > Agilität %d (%.0f km/h)" % [levels[i], by_agility[levels[i]], levels[i - 1], by_agility[levels[i - 1]]])
	# curviness 2 (sharpest curve): about 140–170 km/h, mountain roads (curviness 3) about 100–120
	var maxes: Array = ConfigLoader.lookup(c, "road.curviness_max_curve", [0.0, 0.30, 0.45, 0.9])
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(c, id)
		assert_between(v.safe_curve_speed(float(maxes[2]), 1.0), 140.0, 170.0, id + " Kurvigkeit 2")
		assert_between(v.safe_curve_speed(float(maxes[3]), 1.0), 98.0, 120.0, id + " Kurvigkeit 3")
	# playtest v0.3.0 "Kurven immer mit Top Speed": the sharpest autobahn curve (curviness 1) needs a lift with every
	# car – more than the 5 % that counter-steering holds –, the median one only the heavy cars
	var kompakt := Fx.vehicle(c, "kompakt")
	var gt := Fx.vehicle(c, "gran_turismo")
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(c, id)
		assert_true(v.safe_curve_speed(float(maxes[1]), 1.0) * 1.05 < v.max_speed(0.0, 1.0),
			"%s: schärfste Kurve Kurvigkeit 1 verlangt Gas weg (%.0f km/h)" % [id, v.safe_curve_speed(float(maxes[1]), 1.0)])
	assert_true(kompakt.safe_curve_speed(float(maxes[1]) * 0.675, 1.0) > kompakt.max_speed(0.0, 1.0), "Kompakt: mittlere Kurve Kurvigkeit 1 mit Vollgas")
	assert_true(gt.safe_curve_speed(float(maxes[1]) * 0.675, 1.0) < gt.max_speed(0.0, 1.0) * 0.9, "Gran Turismo: auch die mittlere verlangt Gas weg")
	# same speed, same curve: the agile car stays on its line, the heavy one drifts
	var road := Fx.flat_road(3, true, 0.35)
	kompakt.speed = 180.0
	gt.speed = 180.0
	_run(kompakt, 1.0, {"throttle": 0.5}, road)
	_run(gt, 1.0, {"throttle": 0.5}, road)
	assert_near(kompakt.x, 0.0, 0.0001, "Kompakt hält die Linie")
	assert_true(gt.x < -0.3, "Gran Turismo schiebt nach außen (%.2f m)" % gt.x)


## The drift is an acceleration: it builds up while the car is too fast, faster the bigger the excess,
## always towards the outside of the bend.
func test_understeer_drift_grows_with_excess_and_time() -> void:
	var c := cfg()
	var pushes: Array[float] = []
	for over: float in [0.05, 0.10, 0.20]:
		var v := Fx.vehicle(c, "limousine")
		v.speed = v.max_speed(0.0, 1.0)
		var road := Fx.flat_road(3, true, Sim.curve_for_overspeed(v, v.speed, over))
		_run(v, 0.25, {"throttle": 1.0}, road)
		var early := v.push_speed
		_run(v, 0.25, {"throttle": 1.0}, road)
		assert_true(early < 0.0, "%d %%: Rechtskurve drückt nach links (außen)" % roundi(over * 100.0))
		assert_true(v.push_speed < early * 1.6, "%d %%: Drift wächst mit der Zeit (%.2f -> %.2f m/s)" % [roundi(over * 100.0), early, v.push_speed])
		assert_true(v.x < 0.0, "nach außen gewandert")
		assert_true(v.understeer > 0.0 and v.lat_excess > 0.0, "Untersteuern gemeldet")
		pushes.append(v.push_speed)
	assert_true(pushes[1] < pushes[0] * 1.5 and pushes[2] < pushes[1] * 1.5, "mehr Überschreitung, stärkere Drift: %s" % str(pushes))
	# initial build-up = push_gain * excess (before scrub and steering matter)
	var p := Fx.vehicle(c, "limousine")
	p.speed = p.max_speed(0.0, 1.0)
	var bend := Fx.flat_road(3, true, Sim.curve_for_overspeed(p, p.speed, 0.15))
	var a_ex := p.lateral_excess(float(bend["curve"]), 1.0, p.speed)
	p.update(0.05, {"throttle": 1.0}, bend, {"vmax_factor": 1.0})
	assert_near(p.push_speed, -float(ConfigLoader.lookup(c, "driving.understeer.push_gain", 2.5)) * a_ex * 0.05, 0.01, "Driftbeschleunigung = push_gain · a_ex")
	# left bend: towards the right
	var l := Fx.vehicle(c, "limousine")
	l.speed = l.max_speed(0.0, 1.0)
	_run(l, 0.5, {"throttle": 1.0}, Fx.flat_road(3, true, -Sim.curve_for_overspeed(l, l.speed, 0.15)))
	assert_true(l.push_speed > 0.0 and l.x > 0.0, "Linkskurve drückt nach rechts (außen)")
	# understeer intensity: 0..1, full at driving.understeer.full_excess
	var full := float(ConfigLoader.lookup(c, "driving.understeer.full_excess", 0.5))
	var u := Fx.vehicle(c, "limousine")
	u.speed = u.max_speed(0.0, 1.0)
	u.update(DT, {"throttle": 1.0}, Fx.flat_road(3, true, Sim.curve_for_overspeed(u, u.speed, sqrt(1.0 + full * 2.0) - 1.0)), {"vmax_factor": 1.0})
	assert_near(u.understeer, 1.0, 0.0001, "voll bei doppeltem full_excess")
	u.reset()
	u.speed = u.max_speed(0.0, 1.0)
	u.update(DT, {"throttle": 1.0}, Fx.flat_road(3, true, Sim.curve_for_overspeed(u, u.speed, sqrt(1.0 + full * 0.5) - 1.0)), {"vmax_factor": 1.0})
	assert_near(u.understeer, 0.5, 0.02, "halb bei halbem full_excess")


## Feel targets (docs/gameplay.md, tables (i2), (i2b)): top speed into a bend that is X % too fast, middle lane of
## a three-lane autobahn: a player who keeps the lane (counter-steer proportional to the deviation) holds it at 5 %
## through a whole real curve piece (ramps, up to 520 m); at 10 % the long piece ends at the guardrail. With full
## counter-steer 15 % still drifts a lane outwards within ~1.5 s, 30 % reaches the shoulder / guardrail in ~1–1.5 s.
func test_counter_steer_holds_slightly_but_not_clearly_too_fast() -> void:
	var c := cfg()
	for id: String in Fx.VEHICLES:
		for length_m: float in [150.0, 300.0, 520.0]:
			var hold := Sim.curve_piece_run(c, id, 0.05, length_m)
			assert_true(float(hold["dev_max"]) < 1.0 and not bool(hold["shoulder"]),
				"%s 5 %%, %d m: Spur gehalten (höchstens %.2f m daneben)" % [id, roundi(length_m), float(hold["dev_max"])])
		var lost := Sim.curve_piece_run(c, id, 0.10, 520.0)
		assert_true(bool(lost["limit"]), "%s 10 %%, 520 m: trotz Gegenlenken an der Leitplanke (%.2f m)" % [id, float(lost["out_max"])])
	for id: String in ["kompakt", "limousine", "gran_turismo"]:
		var free5 := Sim.understeer_run(c, id, 0.05, 0.0, 2.5)
		assert_true(float(free5["x_min"]) < -2.5, "%s 5 %%: ohne Lenken schiebt der Wagen (x min %.2f)" % [id, float(free5["x_min"])])
		var r15 := Sim.understeer_run(c, id, 0.15, 1.0, 3.0)
		assert_between(float(r15["t_lane"]), 1.1, 1.8, "%s 15 %%: trotz Gegenlenken eine Spur nach außen" % id)
		var r30 := Sim.understeer_run(c, id, 0.30, 1.0, 3.0)
		assert_between(float(r30["t_shoulder"]), 0.8, 1.4, "%s 30 %%: Bankett" % id)
		assert_between(float(r30["t_limit"]), 1.0, 1.6, "%s 30 %%: Leitplanke" % id)
	# steering towards the inside loses effect, steering out of the bend keeps it
	var s_in := Fx.vehicle(c, "limousine")
	var s_out := Fx.vehicle(c, "limousine")
	var s_straight := Fx.vehicle(c, "limousine")
	for v: VehicleModel in [s_in, s_out, s_straight]:
		v.speed = v.max_speed(0.0, 1.0)
	var bend := Fx.flat_road(3, true, Sim.curve_for_overspeed(s_in, s_in.speed, 0.15))
	_run(s_in, 0.5, {"steer": 1.0, "throttle": 1.0}, bend)
	_run(s_out, 0.5, {"steer": -1.0, "throttle": 1.0}, bend)
	_run(s_straight, 0.5, {"steer": 1.0, "throttle": 1.0}, Fx.flat_road())
	assert_true(s_in.lat_speed < s_straight.lat_speed * 0.4, "Lenken nach innen greift kaum (%.2f vs. %.2f m/s)" % [s_in.lat_speed, s_straight.lat_speed])
	assert_near(-s_out.lat_speed, s_straight.lat_speed, 0.05, "Lenken nach außen voll wirksam")


## Lifting/braking is the remedy: once below the limit the drift decays quickly (recover_s).
func test_drift_recovers_after_braking() -> void:
	var c := cfg()
	var r := Sim.understeer_run(c, "limousine", 0.15, 1.0, 3.0, 1.0, DT, 0.6)
	assert_true(float(r["push_peak"]) > 2.0, "deutliche Drift vor dem Bremsen (%.1f m/s)" % float(r["push_peak"]))
	assert_between(float(r["t_below"]) - 0.6, 0.1, 0.8, "Bremsen bringt den Wagen schnell unter die Grenze")
	assert_between(float(r["t_recovered"]) - float(r["t_below"]), 0.0, 0.8, "Drift klingt danach schnell ab")
	assert_true(float(r["drift_after_m"]) < 0.6, "kaum noch weiter nach außen (%.2f m)" % float(r["drift_after_m"]))
	assert_true(float(r["x_min"]) > -3.75, "bleibt in der Nachbarspur (x min %.2f)" % float(r["x_min"]))
	# a car that is back below the limit drifts no more: exponential decay with recover_s
	var v := Fx.vehicle(c, "limousine")
	v.speed = 120.0
	v.push_speed = -4.0
	var tau := float(ConfigLoader.lookup(c, "driving.understeer.recover_s", 0.25))
	_run(v, tau, {"throttle": 0.5}, Fx.flat_road())
	assert_near(v.push_speed, -4.0 * exp(-1.0), 0.02, "Abklingen mit recover_s")
	assert_near(v.x, -4.0 * tau * (1.0 - exp(-1.0)), 0.01, "Weg während des Abklingens")


## The sliding tyres scrub speed in proportion to the excess (km/h/s = 3.6 · scrub_per_excess · a_ex).
func test_sliding_scrubs_speed() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	v.speed = 200.0
	var road := Fx.flat_road(3, true, Sim.curve_for_overspeed(v, 200.0, 0.2))
	var a_ex := v.lateral_excess(float(road["curve"]), 1.0, 200.0)
	_run(v, 0.1, {"throttle": 0.0}, road)
	var coast := float(ConfigLoader.lookup(c, "driving.coast_decel_kmh_s", 5.0))
	var scrub := float(ConfigLoader.lookup(c, "driving.understeer.scrub_per_excess", 0.5))
	assert_near(200.0 - v.speed, (coast + 3.6 * scrub * a_ex) * 0.1, 0.15, "Rollen + Radieren")
	var straight := Fx.vehicle(c, "limousine")
	straight.speed = 200.0
	_run(straight, 0.1, {"throttle": 0.0}, Fx.flat_road())
	assert_true(v.speed < straight.speed - 0.5, "rutschend langsamer als geradeaus")


## Weather grip lowers the safe speed (∝ √grip): a speed that is fine in the dry understeers in snow.
func test_weather_grip_lowers_curve_speed() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := Fx.vehicle(c, "limousine")
	var dry := v.safe_curve_speed(0.45, env.grip("normal"))
	assert_near(v.safe_curve_speed(0.45, env.grip("rain")), dry * sqrt(v.curve_grip(env.grip("rain"))), 0.01, "Regen")
	assert_near(v.safe_curve_speed(0.45, env.grip("snow")), dry * sqrt(v.curve_grip(env.grip("snow"))), 0.01, "Schnee")
	# retuned with the lower grip of v0.5.0 (snow 0.45, rain 0.75): curves 10 % / 26 % slower than dry
	assert_between(v.safe_curve_speed(0.45, env.grip("rain")) / dry, 0.86, 0.93, "Regen: Kurven etwa 10 % langsamer")
	assert_between(v.safe_curve_speed(0.45, env.grip("snow")) / dry, 0.70, 0.78, "Schnee: Kurven etwa 26 % langsamer")
	var speed := dry * 0.97
	var a := Fx.vehicle(c, "limousine")
	var b := Fx.vehicle(c, "limousine")
	a.speed = speed
	b.speed = speed
	_run(a, 1.0, {"throttle": 0.3}, Fx.flat_road(3, true, 0.45, env.grip("normal")))
	_run(b, 1.0, {"throttle": 0.3}, Fx.flat_road(3, true, 0.45, env.grip("snow")))
	assert_near(a.x, 0.0, 0.0001, "trocken: hält die Linie")
	assert_true(b.x < -1.0, "Schnee: schiebt nach außen (%.2f m)" % b.x)


## Rolling out with an empty tank (scripted 18 km/h/s, the player steers) the brake still works: in a bend 25 %
## too fast the scripted roll-out alone slides into the guardrail, braking avoids it.
func test_brake_works_while_rolling_out() -> void:
	var c := cfg()
	for use_brake: bool in [false, true]:
		var v := Fx.vehicle(c, "limousine")
		v.speed = v.max_speed(0.0, 1.0)
		var bend := Fx.flat_road(3, true, Sim.curve_for_overspeed(v, v.speed, 0.25))
		var hits := 0
		var t := 0.0
		while t < 3.0:
			v.auto_control(0.0, 18.0)
			v.update(DT, {"steer": clampf(-v.x * 1.5, -1.0, 1.0), "brake": 1.0 if use_brake else 0.0}, bend, {"vmax_factor": 1.0})
			t += DT
			hits += 1 if v.rail_hit else 0
		if use_brake:
			assert_eq(hits, 0, "mit Bremse: keine Leitplanke (x %.2f)" % v.x)
			assert_true(v.x > -3.75, "mit Bremse: bleibt in der Nachbarspur (x %.2f)" % v.x)
		else:
			assert_true(hits > 0, "nur Ausrollen: rutscht in die Leitplanke")
	# the brake only adds: a weak pedal does not slow the scripted roll-out down
	var a := Fx.vehicle(c, "limousine")
	var b := Fx.vehicle(c, "limousine")
	a.speed = 200.0
	b.speed = 200.0
	a.auto_control(0.0, 18.0)
	b.auto_control(0.0, 18.0)
	a.update(0.5, {}, Fx.flat_road(), {"vmax_factor": 1.0})
	b.update(0.5, {"brake": 0.1, "throttle": 1.0}, Fx.flat_road(), {"vmax_factor": 1.0})
	assert_near(a.speed, 191.0, 0.01, "Ausrollen 18 km/h/s")
	assert_near(b.speed, 191.0, 0.01, "schwache Bremse (7 km/h/s) und Gas ändern nichts")


## The drift integrates exactly per step: 30 Hz and 144 Hz give the same path.
func test_understeer_is_frame_rate_independent() -> void:
	var c := cfg()
	var r30 := Sim.understeer_run(c, "limousine", 0.15, 0.0, 1.2, 1.0, 1.0 / 30.0)
	var r144 := Sim.understeer_run(c, "limousine", 0.15, 0.0, 1.2, 1.0, 1.0 / 144.0)
	assert_near(float(r30["x_end"]), float(r144["x_end"]), 0.12, "Weg 30 Hz vs. 144 Hz")
	assert_near(float(r30["v_end"]), float(r144["v_end"]), 0.3, "Tempo 30 Hz vs. 144 Hz")
	var d30 := Sim.understeer_run(c, "limousine", 0.15, 1.0, 1.8, 1.0, 1.0 / 30.0, 0.6)
	var d144 := Sim.understeer_run(c, "limousine", 0.15, 1.0, 1.8, 1.0, 1.0 / 144.0, 0.6)
	assert_near(float(d30["x_min"]), float(d144["x_min"]), 0.15, "Erholung 30 Hz vs. 144 Hz")


## Sliding into the guardrail stops the drift and costs more than a touch: rail_hit_factor falls with the
## drift speed (driving.guardrail.impact_*).
func test_drift_into_guardrail_is_costly() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var touch := float(ConfigLoader.lookup(c, "driving.guardrail.speed_factor_per_hit", 0.9))
	var floor_f := float(ConfigLoader.lookup(c, "driving.guardrail.min_speed_factor", 0.5))
	assert_near(v.rail_hit_factor(0.0), touch, 0.0001, "Berühren wie bisher")
	assert_true(v.rail_hit_factor(6.0) < touch - 0.1, "harter Aufprall kostet mehr")
	assert_near(v.rail_hit_factor(100.0), floor_f, 0.0001, "Untergrenze")
	v.speed = v.max_speed(0.0, 1.0)
	var road := Fx.flat_road(3, true, Sim.curve_for_overspeed(v, v.speed, 0.3))
	var hit_v := -1.0
	var before := 0.0
	for i in 180:
		var b := v.speed
		v.update(DT, {"throttle": 1.0}, road, {"vmax_factor": 1.0})
		if v.rail_hit and hit_v < 0.0:
			hit_v = v.speed
			before = b
			assert_true(v.rail_impact > 4.0, "mit Drift in die Leitplanke (%.1f m/s)" % v.rail_impact)
			assert_true(v.push_speed >= 0.0, "Leitplanke stoppt die Drift")
	assert_true(hit_v > 0.0, "Leitplanke erreicht")
	assert_true(hit_v < before * 0.8, "harter Aufprall: %.0f -> %.0f km/h" % [before, hit_v])


func test_shoulder_slows_down() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var road := Fx.flat_road(3, true)
	v.speed = 200.0
	v.x = float(road["right_edge"]) + 0.5
	_run(v, 6.0, {"throttle": 1.0}, road)
	assert_eq(v.off_road, 1, "Bankett")
	assert_near(v.speed, float(ConfigLoader.lookup(c, "driving.shoulder.max_speed_kmh", 90.0)), 0.5, "auf Bankett-Tempo gebremst")
	v.x = 0.0
	_run(v, 0.1, {"throttle": 1.0}, road)
	assert_eq(v.off_road, 0, "zurück auf der Fahrbahn")


func test_guardrail_scrape_and_bounce() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var road := Fx.flat_road(3, true)
	v.speed = 150.0
	v.x = float(road["right_edge"]) + 0.3
	var hit_speed_before := -1.0
	var hit_speed_after := -1.0
	var bounced := false
	var max_x := -INF
	for i in 120:
		var before := v.speed
		v.update(DT, {"steer": 1.0, "throttle": 1.0}, road, {"vmax_factor": 1.0})
		max_x = maxf(max_x, v.x)
		if v.rail_hit and hit_speed_before < 0.0:
			hit_speed_before = before
			hit_speed_after = v.speed
			bounced = v.lat_speed < 0.0
	var limit := float(road["right_edge"]) + 2.5 - v.width_m * 0.5
	assert_true(hit_speed_before > 0.0, "Leitplanke berührt")
	assert_true(hit_speed_after <= hit_speed_before * 0.91, "Geschwindigkeitsfaktor beim Treffer")
	assert_true(bounced, "Abprallen nach innen")
	assert_true(max_x <= limit + 0.0001, "harte Grenze an der Leitplanke")
	assert_eq(v.off_road, 2, "off_road 2 bei Kontakt")
	assert_false(v.on_grass, "kein Gras mit Leitplanke")


## Regression v0.5.0 (QA Windows, snow race Bern – Mailand): a car that stood at the guardrail could never move
## again in snow – the traction limit (11.9 km/h/s) is below the guardrail scrape (20 km/h/s), and at 0 km/h the
## steering does nothing. Now the rail scrapes only while the car is pushed into it: from standstill at either rail,
## every car leaves it with throttle and steering away (or drives off along it with throttle alone) in every weather.
func test_guardrail_never_pins_a_standing_car() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	for w: String in ["normal", "rain", "snow"]:
		var road := Fx.flat_road(3, true, 0.0, env.grip(w))
		for id: String in Fx.VEHICLES:
			for side: int in [-1, 1]:
				for steer_away: bool in [true, false]:
					var v := Fx.vehicle(c, id)
					# standing at the rail (as after a collision push into it or pulling over): the hard limit
					# puts the car there, the hit and its bounce are over
					v.x = float(side) * 9.0
					v.speed = 0.0
					v.update(DT, {}, road, {"vmax_factor": 1.0})
					v.lat_speed = 0.0
					var tag := "%s %s %s %s" % [w, id, "rechts" if side > 0 else "links",
						"Gas + weglenken" if steer_away else "nur Gas"]
					assert_true(v.rail_contact and v.speed < 0.5, tag + ": steht an der Leitplanke (%.1f km/h)" % v.speed)
					var t := 0.0
					var left_rail := -1.0
					var reached := -1.0
					while t < 5.0 and reached < 0.0:
						v.update(DT, {"throttle": 1.0, "steer": -float(side) if steer_away else 0.0}, road, {"vmax_factor": 1.0})
						t += DT
						if left_rail < 0.0 and not v.rail_contact:
							left_rail = t
						if v.speed >= 20.0:
							reached = t
					assert_true(reached > 0.0, tag + ": in 5 s auf 20 km/h (%.1f km/h)" % v.speed)
					if steer_away:
						assert_true(left_rail > 0.0 and left_rail < 3.0, tag + ": verlässt die Leitplanke (%.2f s)" % left_rail)


## Pressing into the rail still scrapes: steering into it costs speed (driving.guardrail.scrape_decel_kmh_s), a car that
## only touches it (no steering towards it) just coasts.
func test_guardrail_scrapes_while_pressed_into_it() -> void:
	var c := cfg()
	var road := Fx.flat_road(3, true)
	var scrape := float(ConfigLoader.lookup(c, "driving.guardrail.scrape_decel_kmh_s", 20.0))
	var coast := float(ConfigLoader.lookup(c, "driving.coast_decel_kmh_s", 5.0))
	var v := Fx.vehicle(c, "limousine")
	v.x = 7.0
	v.speed = 100.0
	_run(v, 1.5, {"steer": 1.0}, road)   # hit and bounce are over, the car leans on the rail
	var v0 := v.speed
	_run(v, 1.0, {"steer": 1.0}, road)
	assert_true(v.rail_contact, "an der Leitplanke")
	assert_true(v0 - v.speed > (scrape + coast) * 0.8, "Schleifen bremst: %.1f -> %.1f km/h" % [v0, v.speed])
	var v1 := v.speed
	_run(v, 1.0, {}, road)
	assert_true(v.rail_contact, "berührt die Leitplanke weiter")
	assert_true(v1 - v.speed < coast * 1.05, "nur berühren schleift nicht: %.1f -> %.1f km/h" % [v1, v.speed])


func test_grass_without_guardrail() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var road := Fx.flat_road(2, false)
	v.speed = 150.0
	v.x = float(road["right_edge"]) + 1.0
	_run(v, 3.0, {"steer": 1.0, "throttle": 1.0}, road)
	assert_true(v.on_grass, "Gras")
	assert_eq(v.off_road, 2, "harte Grenze")
	assert_near(v.speed, float(ConfigLoader.lookup(c, "driving.grass.max_speed_kmh", 40.0)), 0.5, "stark gebremst")
	assert_true(v.x <= float(road["right_edge"]) + 2.5 - v.width_m * 0.5 + 0.0001, "nicht weiter als Rand + Bankett")


func test_collision_sequence() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var road := Fx.flat_road()
	var log := {"started": 0, "finished": 0, "dir": 0}
	v.crash_started.connect(func(d: int) -> void:
		log["started"] = int(log["started"]) + 1
		log["dir"] = d)
	v.crash_finished.connect(func() -> void: log["finished"] = int(log["finished"]) + 1)
	v.speed = 200.0
	v.start_crash(-1.0, 3.0, 3.0)
	assert_eq(int(log["started"]), 1, "crash_started")
	assert_eq(int(log["dir"]), 1, "Treffer von links -> nach rechts")
	assert_true(v.invulnerable, "unverwundbar")
	var slow := float(ConfigLoader.lookup(c, "collision.slowdown_s", 3.0))
	var extra := float(ConfigLoader.lookup(c, "collision.push_extra_s", 0.5))
	var target := float(ConfigLoader.lookup(c, "collision.target_speed_kmh", 10.0))
	var blinks := {}
	var t := 0.0
	while t < slow - 0.05:
		v.update(DT, {"throttle": 1.0, "steer": -1.0}, road, {"vmax_factor": 1.0})
		t += DT
		blinks[v.blink_visible] = true
		assert_true(v.invulnerable, "unverwundbar während des Abbremsens")
	assert_true(blinks.has(true) and blinks.has(false), "blinkt")
	assert_true(v.speed > target and v.speed < 20.0, "kurz vor Ablauf fast 10 km/h: %.1f" % v.speed)
	_run(v, 0.1, {"throttle": 1.0}, road)
	assert_near(v.speed, target, 0.001, "nach slowdown_s genau 10 km/h")
	assert_eq(v.state, VehicleModel.State.CRASH, "Endpunkt noch nicht erreicht")
	_run(v, extra - 0.15, {"throttle": 1.0}, road)
	assert_near(v.speed, target, 0.001, "kein Gas vor dem Endpunkt")
	_run(v, 0.1, {"throttle": 1.0}, road)
	assert_eq(int(log["finished"]), 1, "crash_finished am Endpunkt")
	assert_near(v.x, float(ConfigLoader.lookup(c, "collision.push_distance_m", 3.0)), 0.05, "seitlich geschoben")
	assert_eq(v.state, VehicleModel.State.DRIVING, "fährt wieder")
	var grace := float(ConfigLoader.lookup(c, "collision.invulnerable_grace_s", 0.0))
	if grace > 0.0:
		assert_true(v.invulnerable, "Schonfrist nach dem Endpunkt")
	_run(v, grace + 0.1, {"throttle": 1.0}, road)
	assert_false(v.invulnerable, "Kollisionen zählen wieder")
	assert_true(v.blink_visible, "sichtbar")
	assert_true(v.speed > target + 1.0, "beschleunigt wieder")


func test_crash_ignored_while_invulnerable() -> void:
	var v := Fx.vehicle(cfg(), "limousine")
	var count := {"n": 0}
	v.crash_started.connect(func(_d: int) -> void: count["n"] = int(count["n"]) + 1)
	v.speed = 150.0
	v.start_crash(0.0, 1.0, 2.0)
	_run(v, 1.0, {}, Fx.flat_road())
	v.start_crash(0.0, 1.0, 2.0)
	assert_eq(int(count["n"]), 1, "zweiter Treffer während des Unfalls zählt nicht")


func test_push_direction_rules() -> void:
	var v := Fx.vehicle(cfg(), "limousine")
	var centre := float(ConfigLoader.lookup(cfg(), "collision.center_hit_fraction", 0.25)) * v.width_m
	assert_eq(v.push_direction(1.0, 5.0, 0.0), 1, "Auto links getroffen -> nach rechts (auch bei wenig Platz)")
	assert_eq(v.push_direction(-1.0, 0.0, 5.0), -1, "Auto rechts getroffen -> nach links")
	assert_eq(v.push_direction(centre * 0.5, 1.0, 4.0), 1, "mittig: rechts mehr Platz")
	assert_eq(v.push_direction(-centre * 0.5, 4.0, 1.0), -1, "mittig: links mehr Platz")
	assert_eq(v.push_direction(0.0, 2.0, 2.0), -1, "gleich viel Platz -> links")
	assert_eq(v.push_direction(0.0, 2.0, 2.1), -1, "fast gleich viel Platz -> links")


func test_auto_control_and_release() -> void:
	var c := cfg()
	var v := Fx.vehicle(c, "limousine")
	var road := Fx.flat_road()
	v.speed = 100.0
	v.auto_control(0.0, 50.0)
	assert_false(v.is_controllable(), "Automatik")
	_run(v, 1.0, {"throttle": 1.0}, road)
	assert_near(v.speed, 50.0, 0.5, "50 km/h/s Verzögerung, Gas ignoriert")
	assert_true(v.braking, "Bremslicht beim automatischen Bremsen")
	_run(v, 1.5, {"throttle": 1.0}, road)
	assert_eq(v.speed, 0.0, "steht")
	v.release_auto()
	assert_true(v.is_controllable(), "freigegeben")
	_run(v, 1.0, {"throttle": 1.0}, road)
	assert_true(v.speed > 10.0, "fährt aus dem Stand an")
	# steer_x steers the car, without it the player keeps steering
	v.speed = 40.0
	v.x = 0.0
	v.auto_control(40.0, 10.0, 2.0)
	_run(v, 2.0, {"steer": -1.0}, road)
	assert_near(v.x, 2.0, 0.01, "steer_x")
	v.auto_control(40.0, 10.0)
	_run(v, 0.5, {"steer": -1.0}, road)
	assert_true(v.x < 2.0, "ohne steer_x lenkt der Spieler")
	# no auto control during a collision
	v.release_auto()
	v.speed = 120.0
	v.start_crash(v.x - 1.0, 1.0, 1.0)
	v.auto_control(0.0, 50.0)
	assert_eq(v.state, VehicleModel.State.CRASH, "Unfall hat Vorrang")


# --- v0.5.0: weather handling (docs/gameplay.md "Wetter") ---------------------------------------------------------

## Distance (m) and time (s) of a full braking from v0 to v1 on a straight road with tyre grip g.
func _brake_run(c: Dictionary, id: String, g: float, v0: float, v1: float) -> Vector2:
	var v := Fx.vehicle(c, id)
	v.speed = v0
	var d := 0.0
	var t := 0.0
	while v.speed > v1 and t < 30.0:
		v.update(DT, {"brake": 1.0}, Fx.flat_road(3, true, 0.0, g), {"vmax_factor": 1.0})
		d += v.speed / 3.6 * DT
		t += DT
	return Vector2(d, t)


## Snow: roughly half the deceleration of a dry road, rain in between – the braking distance grows accordingly.
func test_braking_limited_by_grip() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := Fx.vehicle(c, "limousine")
	var full := float(ConfigLoader.lookup(c, "driving.brake_decel_kmh_s", 70.0)) / 3.6
	assert_near(v.brake_decel_mps2(1.0), full, 0.0001, "trocken: volle Bremsung (70 km/h/s)")
	assert_between(v.brake_decel_mps2(env.grip("snow")) / full, 0.45, 0.55, "Schnee: etwa die halbe Verzögerung")
	assert_between(v.brake_decel_mps2(env.grip("rain")) / full, 0.7, 0.85, "Regen dazwischen")
	var dry := _brake_run(c, "limousine", 1.0, 200.0, 100.0)
	var rain := _brake_run(c, "limousine", env.grip("rain"), 200.0, 100.0)
	var snow := _brake_run(c, "limousine", env.grip("snow"), 200.0, 100.0)
	assert_between(snow.x / dry.x, 1.8, 2.2, "Bremsweg 200 -> 100 km/h im Schnee etwa doppelt (%.0f statt %.0f m)" % [snow.x, dry.x])
	assert_true(rain.x > dry.x * 1.15 and rain.x < snow.x, "Regen: %.0f m" % rain.x)
	# the player's brake while rolling out (auto control without steer_x) is limited the same way
	var r := Fx.vehicle(c, "limousine")
	r.speed = 200.0
	r.auto_control(0.0, 18.0)
	_run(r, 1.0, {"brake": 1.0}, Fx.flat_road(3, true, 0.0, env.grip("snow")))
	assert_near(r.speed, 200.0 - v.brake_decel_mps2(env.grip("snow")) * 3.6, 0.5, "Ausrollen: Bremse wie bei Schnee")


## Seconds from standstill to 100 km/h with full throttle on tyre grip g (top speed of a dry road).
func _t100(c: Dictionary, id: String, g: float, dt: float) -> float:
	var v := Fx.vehicle(c, id)
	var t := 0.0
	while v.speed < 100.0 and t < 60.0:
		v.update(dt, {"throttle": 1.0}, Fx.flat_road(3, true, 0.0, g), {"vmax_factor": 1.0})
		t += dt
	return t


## In snow the acceleration is traction-limited at low speed (driving.grip_effects.traction_mps2 · grip): every car
## needs clearly longer to 100 km/h and the strong ones lose their advantage; a dry road changes nothing; exact
## integration (frame-rate independent).
func test_traction_limits_the_start_in_snow() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var snow_times: Array[float] = []
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(c, id)
		var dry := _t100(c, id, 1.0, DT)
		var snow := _t100(c, id, env.grip("snow"), DT)
		assert_near(dry, float(v.spec["t100_s"]), 0.1, id + ": trocken unverändert")
		assert_true(snow > dry * 1.15, "%s: Schnee 0–100 in %.2f s statt %.2f s" % [id, snow, dry])
		assert_near(_t100(c, id, env.grip("snow"), 1.0 / 30.0), snow, 0.05, id + ": bildratenunabhängig")
		assert_true(_t100(c, id, env.grip("rain"), DT) < snow, id + ": Regen dazwischen")
		snow_times.append(snow)
		# the traction limit only caps the start: the curve above the crossover speed is the normal one
		var vc := v.traction_crossover(v.vmax_effective, v.traction_mps2(env.grip("snow")) * 3.6)
		assert_true(vc > 60.0 and vc < v.vmax_effective, "%s: Traktion begrenzt bis %.0f km/h" % [id, vc])
	snow_times.sort()
	assert_true(snow_times[snow_times.size() - 1] - snow_times[0] < 1.0, "Schnee: die starken Autos verlieren ihren Vorsprung beim Anfahren")


## Lane change at 200 km/h from x 3.75 to the lane centre 0 on tyre grip g: full lock until the car is there, then
## either let go or counter-steer until the lateral speed is gone. Returns the slide beyond the target (m).
func _lane_change_slide(c: Dictionary, g: float, counter: bool, dt: float = DT) -> float:
	var v := Fx.vehicle(c, "limousine")
	v.speed = 200.0
	v.x = 3.75
	var road := Fx.flat_road(3, true, 0.0, g)
	var phase := 0
	var over := 0.0
	var t := 0.0
	while t < 5.0:
		var steer := 0.0
		if phase == 0:
			steer = -1.0
			if v.x <= 0.0:
				phase = 1
		elif phase == 1 and counter:
			steer = 1.0
			if v.lat_speed >= 0.0:
				phase = 2
		v.update(dt, {"steer": steer}, road, {"vmax_factor": 10.0})
		v.speed = 200.0
		assert_true(absf(v.lat_speed) <= v.steer_speed_mps(g) + 0.001, "nie mehr Querbewegung als voller Lenkeinschlag (kein Dreher)")
		if phase >= 1:
			over = maxf(over, -v.x)
		t += dt
	return over


## Steering on a slippery road: the lateral speed builds up more slowly and the car keeps sliding once the input
## ends – released at the target lane it slides on far into the next lane on snow (rain in between); counter-steer
## stops it much sooner. Frame-rate independent; the lateral speed never exceeds full lock (no spin).
func test_steering_slides_on_snow() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := Fx.vehicle(c, "limousine")
	assert_near(v.steer_response_s(1.0), float(ConfigLoader.lookup(c, "driving.steer_response_s", 0.12)), 0.0001, "trocken unverändert")
	assert_true(v.steer_response_s(env.grip("snow")) > 3.0 * v.steer_response_s(1.0), "Schnee: Lenkung spricht viel träger an")
	assert_true(v.steer_speed_mps(env.grip("snow")) < v.steer_speed_mps(1.0), "Schnee: weniger Querbewegung")
	var dry := _lane_change_slide(c, 1.0, false)
	var rain := _lane_change_slide(c, env.grip("rain"), false)
	var snow := _lane_change_slide(c, env.grip("snow"), false)
	var snow_counter := _lane_change_slide(c, env.grip("snow"), true)
	assert_true(dry < 1.5, "trocken: rutscht %.2f m nach" % dry)
	assert_true(snow > 2.0 and snow > dry * 2.0, "Schnee: rutscht %.2f m in die Nachbarspur (trocken %.2f m)" % [snow, dry])
	assert_true(rain > dry and rain < snow, "Regen dazwischen: %.2f m" % rain)
	assert_true(snow_counter < snow * 0.5, "Gegenlenken hilft: %.2f statt %.2f m" % [snow_counter, snow])
	assert_near(_lane_change_slide(c, env.grip("snow"), false, 1.0 / 30.0), snow, 0.15, "bildratenunabhängig (30 Hz)")
