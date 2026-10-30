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


func test_understeer_pushes_outwards_proportionally() -> void:
	var c := cfg()
	var right_bend := Fx.flat_road(3, true, 0.6)
	var a := Fx.vehicle(c, "limousine")
	var safe := a.safe_curve_speed(0.6, 1.0)
	a.speed = safe * 1.1
	a.update(DT, {}, right_bend, {"vmax_factor": 1.0})
	var b := Fx.vehicle(c, "limousine")
	b.speed = safe * 1.2
	b.update(DT, {}, right_bend, {"vmax_factor": 1.0})
	assert_true(a.push_speed < 0.0, "Rechtskurve drückt nach links (außen)")
	assert_near(b.push_speed / a.push_speed, 2.0, 0.05, "proportional zur Überschreitung")
	assert_true(b.understeer > a.understeer and a.understeer > 0.0, "Untersteuer-Intensität")
	var left_bend := Fx.flat_road(3, true, -0.6)
	var l := Fx.vehicle(c, "limousine")
	l.speed = safe * 1.1
	l.update(DT, {}, left_bend, {"vmax_factor": 1.0})
	assert_true(l.push_speed > 0.0, "Linkskurve drückt nach rechts (außen)")
	# steering gets weaker: same input, less lateral speed than on a straight
	var s1 := Fx.vehicle(c, "limousine")
	var s2 := Fx.vehicle(c, "limousine")
	s1.speed = safe * 1.3
	s2.speed = safe * 1.3
	_run(s1, 0.5, {"steer": 1.0}, right_bend)
	_run(s2, 0.5, {"steer": 1.0}, Fx.flat_road())
	assert_true(s1.lat_speed < s2.lat_speed * 0.7, "Lenkung greift schwächer beim Untersteuern")
	# grip: rain lowers the safe speed
	assert_true(a.safe_curve_speed(0.6, 0.88) < safe, "Regen senkt die sichere Kurvengeschwindigkeit")
	assert_eq(a.safe_curve_speed(0.0, 1.0), INF, "Gerade: keine Grenze")


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
