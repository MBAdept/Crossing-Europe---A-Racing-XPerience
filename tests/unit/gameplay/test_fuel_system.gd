extends TestCase
## FuelSystem: consumption, announcements, range, fuel lane refuelling (trigger, duration, abort), towing.

const Fx := preload("res://tests/sim/fixtures.gd")
const Sim := preload("res://tests/sim/gameplay_sim.gd")
const DT := 1.0 / 60.0


func _fuel(c: Dictionary, plan: StagePlan, tank: float = 50.0, factor: float = 1.0) -> FuelSystem:
	var f := FuelSystem.new()
	f.setup(c, {"tank_l": tank, "consumption_factor": factor}, plan)
	return f


func test_consumption_formula_and_vehicle_factors() -> void:
	var c := cfg()
	assert_near(FuelSystem.base_consumption(c, 100.0), 17.4, 0.001, "100 km/h")
	assert_near(FuelSystem.base_consumption(c, 130.0), 19.746, 0.001, "130 km/h")
	assert_near(FuelSystem.base_consumption(c, 180.0), 25.016, 0.001, "180 km/h")
	assert_near(FuelSystem.base_consumption(c, 250.0), 35.25, 0.001, "250 km/h")
	var plan := Fx.make_plan(c)
	for id: String in Fx.VEHICLES:
		var spec := VehicleModel.resolve_spec(c, id)
		var f := FuelSystem.new()
		f.setup(c, spec, plan)
		assert_eq(f.tank_l, float(spec["tank_l"]), id + " Tankgröße")
		assert_near(f.consumption_per_100km(130.0), FuelSystem.base_consumption(c, 130.0) * float(spec["consumption_factor"]), 0.0001, id + " Verbrauchsfaktor")
	var low := VehicleModel.resolve_spec(c, "kompakt")
	var high := VehicleModel.resolve_spec(c, "gran_turismo")
	assert_true(float(low["consumption_factor"]) < 1.0 and float(high["consumption_factor"]) > 1.0, "niedrig < mittel < sehr hoch")


func test_consumption_counts_odometer_km() -> void:
	var c := cfg()
	assert_near(Sim.consumption_run(c, 130.0, 100.0), FuelSystem.base_consumption(c, 130.0), 0.01, "100 km bei 130 km/h")
	assert_near(Sim.consumption_run(c, 250.0, 50.0), FuelSystem.base_consumption(c, 250.0) * 0.5, 0.01, "50 km bei 250 km/h")
	var f := _fuel(c, Fx.make_plan(c))
	f.update(DT, 0.0, 0.0, 200.0, false, 1.0)
	assert_eq(f.fuel_l, 50.0, "kein Verbrauch ohne gefahrene km")


func test_range_and_design_table() -> void:
	var c := cfg()
	var f := _fuel(c, Fx.make_plan(c))
	assert_near(f.range_km(100.0), 287.4, 1.0, "Reichweite bei 100 km/h ca. 290 km")
	assert_near(f.range_km(130.0), 253.2, 1.0, "bei 130 ca. 255 km")
	assert_near(f.range_km(180.0), 199.9, 1.0, "bei 180 ca. 200 km")
	assert_near(f.range_km(250.0), 141.8, 1.0, "bei 250 ca. 140 km")
	assert_near(f.range_km(0.0), f.range_km(60.0), 0.0001, "im Stand: Reichweite bei 60 km/h")


func test_announcements_once_per_station() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 200.0, [60.0, 140.0])
	var f := _fuel(c, plan, 500.0)
	var got: Array = []
	f.announced.connect(func(k: int, s: float) -> void: got.append([k, s]))
	var km := 0.0
	while km < 200.0:
		f.update(DT, km, 0.05, 150.0, false, 1.0)
		f.update(DT, km, 0.0, 150.0, false, 1.0)
		km += 0.05
	assert_eq(got.size(), 6, "3 Ansagen je Tankstelle")
	assert_eq(got[0], [30, 60.0], "30 km vorher")
	assert_eq(got[1], [15, 60.0], "15 km vorher")
	assert_eq(got[2], [5, 60.0], "5 km vorher")
	assert_eq(got[3][1], 140.0, "zweite Tankstelle")
	# start in the middle: thresholds long passed are skipped, the next one comes normally
	var g := _fuel(c, plan, 500.0)
	var got2: Array = []
	g.announced.connect(func(k: int, s: float) -> void: got2.append([k, s]))
	g.update(DT, 44.0, 0.0, 150.0, false, 1.0)
	assert_eq(got2.size(), 0, "keine veraltete 30-km-Ansage")
	g.update(DT, 45.2, 0.0, 150.0, false, 1.0)
	assert_eq(got2, [[15, 60.0]], "15-km-Ansage")


func test_distance_to_next_station() -> void:
	var c := cfg()
	var f := _fuel(c, Fx.make_plan(c, 200.0, [60.0, 140.0]))
	assert_near(f.distance_to_next_station(10.0), 50.0, 0.0001, "nächste")
	assert_near(f.distance_to_next_station(100.0), 40.0, 0.0001, "übernächste")
	assert_eq(f.distance_to_next_station(150.0), -1.0, "keine mehr")


func test_refuel_duration_empty_tank_25s() -> void:
	var c := cfg()
	var r := Sim.refuel_run(c, 50.0, 50.0)
	assert_near(float(r["duration_s"]), 25.0, 0.05, "leerer 50-L-Tank: 25 s")
	assert_near(float(r["liters"]), 50.0, 0.001, "50 L getankt")
	var half := Sim.refuel_run(c, 50.0, 20.0)
	assert_near(float(half["duration_s"]), 5.0 + 8.0, 0.05, "20 L: 5 s + 8 s")
	assert_true(float(r["stop_s"]) < float(ConfigLoader.lookup(c, "fuel.refuel_fixed_s", 5.0)), "Anhalten im festen Anteil")


func test_refuel_trigger_flow_and_control() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 200.0, [60.0], [], 1.5)
	var f := _fuel(c, plan)
	f.fuel_l = 10.0
	var log := {"started": 0, "finished": [], "km": 59.0}
	f.refuel_started.connect(func() -> void: log["started"] = int(log["started"]) + 1)
	f.refuel_finished.connect(func(l: float, a: bool) -> void: log["finished"] = [l, a])
	# fast through the lane: no refuel
	f.update(DT, 59.0, 0.0, 61.0, true, 1.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "schneller als 60 -> durchfahren")
	# not in the lane: nothing
	f.update(DT, 59.0, 0.0, 30.0, false, 0.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "nicht in der Spur")
	# below 60 in the lane: refuel starts and wants the car stopped
	f.update(DT, 59.0, 0.0, 55.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.REFUELING, "Tanken startet automatisch")
	assert_eq(int(log["started"]), 1, "refuel_started")
	var req := f.control_request()
	assert_eq(float(req["target_kmh"]), 0.0, "anhalten")
	assert_eq(float(req["rate_kmh_s"]), float(ConfigLoader.lookup(c, "fuel.stop_decel_kmh_s", 50.0)), "Verzögerung")
	assert_near(f.refuel_time_left, 5.0 + 2.0 * 40.0 / 5.0, 0.001, "Dauer 5 s + 16 s")
	# fixed part: no litres yet
	for i in int(4.0 / DT):
		f.update(DT, 59.0, 0.0, 0.0, true, 0.0)
	assert_eq(f.liters_added, 0.0, "fester Anteil ohne Liter")
	assert_false(f.pumping, "noch nicht gepumpt")
	for i in int(3.0 / DT):
		f.update(DT, 59.0, 0.0, 0.0, true, 0.0)
	assert_near(f.liters_added, 2.0 * 5.0 / 2.0, 0.1, "2 s gepumpt = 5 L")
	assert_true(f.pumping, "pumpt")
	assert_near(f.fuel_l, 10.0 + f.liters_added, 0.0001, "Liter fließen in den Tank")
	assert_between(f.refuel_progress, 0.3, 0.4, "Fortschritt")
	for i in int(20.0 / DT):
		f.update(DT, 59.0, 0.0, 0.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "fertig")
	assert_eq(f.fuel_l, 50.0, "voll")
	assert_eq(log["finished"], [40.0, false], "refuel_finished(40, false)")
	assert_true(f.control_request().is_empty(), "Kontrolle zurück")
	# no immediate restart while still slow in the lane
	f.fuel_l = 45.0
	f.update(DT, 59.1, 0.0, 10.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "kein erneutes Tanken direkt danach")


func test_refuel_abort_needs_fresh_throttle_press() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 200.0, [60.0], [], 1.5)
	var f := _fuel(c, plan)
	f.fuel_l = 0.5
	var log := {"finished": []}
	f.refuel_finished.connect(func(l: float, a: bool) -> void: log["finished"] = [l, a])
	# entering with the pedal held: holding does not abort
	f.update(DT, 59.0, 0.0, 50.0, true, 1.0)
	assert_eq(f.state, FuelSystem.State.REFUELING, "startet")
	for i in int(8.0 / DT):
		f.update(DT, 59.0, 0.0, 0.0, true, 1.0)
	assert_eq(f.state, FuelSystem.State.REFUELING, "gehaltenes Gas bricht nicht ab")
	f.update(DT, 59.0, 0.0, 0.0, true, 0.0)
	var pumped := f.liters_added
	assert_true(pumped > 5.0, "schon getankt: %.1f L" % pumped)
	f.update(DT, 59.0, 0.0, 0.0, true, 1.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "frischer Gasstoß bricht ab")
	assert_true(bool(log["finished"][1]), "aborted = true")
	assert_near(float(log["finished"][0]), pumped, 0.0001, "behält die Liter")
	assert_near(f.fuel_l, 0.5 + pumped, 0.0001, "Tankstand")
	assert_true(f.control_request().is_empty(), "weiterfahren")
	# after accelerating above 60 the lane is armed again
	f.update(DT, 59.2, 0.0, 30.0, true, 1.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "direkt danach kein neues Tanken")
	f.update(DT, 59.3, 0.0, 65.0, true, 1.0)
	f.update(DT, 59.4, 0.0, 50.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.REFUELING, "nach >60 wieder bereit")


func test_full_tank_does_not_stop() -> void:
	var c := cfg()
	var f := _fuel(c, Fx.make_plan(c, 200.0, [60.0]))
	f.update(DT, 59.0, 0.0, 40.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.NORMAL, "voller Tank: kein Tankstopp")


func test_empty_tank_tow() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 200.0)
	var f := _fuel(c, plan)
	f.fuel_l = 0.01
	var log := {"dry": 0, "tow": -1.0}
	f.ran_dry.connect(func() -> void: log["dry"] = int(log["dry"]) + 1)
	f.tow_finished.connect(func(p: float) -> void: log["tow"] = p)
	var v := Fx.vehicle(c, "limousine")
	v.speed = 150.0
	var km := 30.0
	var t := 0.0
	var towing_seen := 0.0
	while t < 60.0:
		var req := f.control_request()
		if req.is_empty():
			v.release_auto()
		else:
			v.auto_control(float(req["target_kmh"]), float(req["rate_kmh_s"]))
		v.update(DT, {"throttle": 1.0}, Fx.flat_road(), {"vmax_factor": 1.0})
		var dkm := Units.visual_m_to_km(v.speed / 3.6 * DT, 12.0)
		km += dkm
		f.update(DT, km, dkm, v.speed, false, 1.0)
		t += DT
		if f.state == FuelSystem.State.TOWING:
			towing_seen += DT
			assert_true(v.speed <= 0.5, "Abschleppen erst im Stand")
		if float(log["tow"]) >= 0.0:
			break
	assert_eq(int(log["dry"]), 1, "ran_dry einmal")
	assert_near(towing_seen, float(ConfigLoader.lookup(c, "fuel.tow_overlay_s", 4.0)), 0.05, "Einblendung tow_overlay_s")
	var penalty := float(ConfigLoader.lookup(c, "fuel.tow_penalty_s", 90.0))
	assert_eq(float(log["tow"]), penalty, "tow_finished(Strafe)")
	assert_eq(f.take_penalty(), penalty, "take_penalty liefert die Zeitstrafe")
	assert_eq(f.take_penalty(), 0.0, "nur einmal")
	assert_near(f.fuel_l, 50.0 * float(ConfigLoader.lookup(c, "fuel.tow_refill_fraction", 0.5)), 0.0001, "halb voll")
	assert_eq(f.state, FuelSystem.State.NORMAL, "weiter")
	assert_true(f.control_request().is_empty(), "Kontrolle zurück")


func test_empty_tank_can_still_roll_into_the_fuel_lane() -> void:
	var c := cfg()
	var f := _fuel(c, Fx.make_plan(c, 200.0, [60.0], [], 1.5))
	f.fuel_l = 0.0
	f.update(DT, 58.0, 0.001, 70.0, false, 0.0)
	assert_true(f.rolling_out, "rollt aus")
	assert_false(f.control_request().is_empty(), "rollt kontrolliert aus")
	f.update(DT, 58.7, 0.001, 45.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.REFUELING, "rollt in die Tankspur und tankt")
	assert_false(f.rolling_out, "kein Abschleppen")


func test_reserve_signal() -> void:
	var c := cfg()
	var f := _fuel(c, Fx.make_plan(c))
	var n := {"n": 0}
	f.reserve_reached.connect(func() -> void: n["n"] = int(n["n"]) + 1)
	f.fuel_l = float(ConfigLoader.lookup(c, "fuel.reserve_warning_l", 8.0)) + 0.01
	f.update(DT, 10.0, 0.5, 150.0, false, 1.0)
	f.update(DT, 10.5, 0.5, 150.0, false, 1.0)
	assert_eq(int(n["n"]), 1, "Reserve einmal gemeldet")
	assert_true(f.low_fuel, "low_fuel")
