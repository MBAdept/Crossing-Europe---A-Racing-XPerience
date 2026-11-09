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


## v0.7.0: the first station lies 5–20 km after the start – before its 30- and 15-km announcements. It is announced at
## the start with its real distance; a station exactly at a threshold (15 km) by that threshold; a start in the middle
## of a stage stays silent as before; announce_start = false (the race countdown names it) only marks the thresholds.
func test_first_station_is_announced_at_the_start() -> void:
	var c := cfg()
	var runs := {12.0: [[12, 12.0], [5, 12.0]], 15.0: [[15, 15.0], [5, 15.0]], 16.0: [[15, 16.0], [5, 16.0]],
		44.0: [[30, 44.0], [15, 44.0], [5, 44.0]]}
	for first: float in runs:
		var f := _fuel(c, Fx.make_plan(c, 200.0, [first, first + 75.0]), 500.0)
		var got: Array = []
		f.announced.connect(func(k: int, s: float) -> void:
			if s == first:
				got.append([k, s]))
		var km := 0.0
		while km < first:
			f.update(DT, km, 0.05, 150.0, false, 1.0)
			km += 0.05
		assert_eq(got, runs[first], "erste Tankstelle bei km %.0f" % first)
	var mid := _fuel(c, Fx.make_plan(c, 200.0, [50.0]), 500.0)
	var got_mid: Array = []
	mid.announced.connect(func(k: int, s: float) -> void: got_mid.append([k, s]))
	mid.update(DT, 40.0, 0.0, 150.0, false, 1.0)
	assert_eq(got_mid, [], "Start mitten in der Etappe: keine Ansage mit krummer Entfernung")
	var quiet := _fuel(c, Fx.make_plan(c, 200.0, [12.0]), 500.0)
	quiet.announce_start = false
	var got_q: Array = []
	quiet.announced.connect(func(k: int, s: float) -> void: got_q.append([k, s]))
	var q := 0.0
	while q < 12.0:
		quiet.update(DT, q, 0.05, 150.0, false, 1.0)
		q += 0.05
	assert_eq(got_q, [[5, 12.0]], "announce_start aus: nur die 5-km-Ansage")


## v0.7.0, race: the tank of the last stage goes on – it replaces the stage's own filling (the tutorial's 35 %) and is
## clamped to the tank; -1 = the stage's own filling.
func test_carried_start_fuel() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 200.0, [12.0])
	var f := FuelSystem.new()
	f.setup(c, {"tank_l": 60.0}, plan)
	assert_near(f.fuel_l, 60.0 * float(ConfigLoader.lookup(c, "fuel.start_fill_fraction", 1.0)), 0.0001, "ohne Übernahme: Startfüllung der Konfiguration")
	plan.start_fuel_fraction = 0.35
	f.setup(c, {"tank_l": 60.0}, plan)
	assert_near(f.fuel_l, 21.0, 0.0001, "Startfüllung der Etappe (Tutorial)")
	assert_near(FuelSystem.start_fill_fraction(c, plan), 0.35, 0.0001, "start_fill_fraction")
	f.setup(c, {"tank_l": 60.0}, plan, 7.5)
	assert_near(f.fuel_l, 7.5, 0.0001, "übernommener Tank geht vor")
	f.setup(c, {"tank_l": 60.0}, plan, 0.0)
	assert_eq(f.fuel_l, 0.0, "auch ein leerer Tank wird übernommen")
	f.setup(c, {"tank_l": 60.0}, plan, 75.0)
	assert_eq(f.fuel_l, 60.0, "höchstens der Tank")
	f.setup(c, {"tank_l": 60.0}, plan, -1.0)
	assert_near(f.fuel_l, 21.0, 0.0001, "-1 = Startfüllung der Etappe")


## v0.7.0: start_check – does a carried tank reach the first fuel lane (open = lane start + taper)? "ok" even at vmax,
## "tight" only up to max_kmh (a multiple of 5 that really reaches it), "tow" not even at the lane trigger speed.
func test_start_check() -> void:
	var c := cfg()
	var spec := VehicleModel.resolve_spec(c, "gran_turismo")
	var plan := Fx.make_plan(c, 150.0, [12.0, 86.0], [], 1.5)
	var taper := Units.visual_m_to_km(float(ConfigLoader.lookup(c, "road.fuel_lane_taper_m", 40.0)), float(ConfigLoader.lookup(c, "time.time_scale", 12.0)))
	var lane := 10.5 + taper
	var trigger := float(ConfigLoader.lookup(c, "fuel.lane_trigger_speed_kmh", 60.0))
	var vmax := float(spec["vmax_kmh"])
	var per := func(v: float) -> float: return FuelSystem.consumption_for(c, spec, v) / 100.0
	var ok := FuelSystem.start_check(c, spec, plan, lane * per.call(vmax) + 0.01)
	assert_eq(str(ok["state"]), "ok", "reicht mit Vollgas")
	assert_near(float(ok["first_km"]), 12.0, 0.0001, "erste Tankstelle")
	assert_near(float(ok["lane_km"]), lane, 0.0001, "offene Tankspur = Spuranfang + Einfädelstrecke")
	assert_eq(float(ok["max_kmh"]), vmax, "max = vmax")
	var tow := FuelSystem.start_check(c, spec, plan, lane * per.call(trigger) - 0.01)
	assert_eq(str(tow["state"]), "tow", "reicht nicht einmal mit %d km/h" % roundi(trigger))
	assert_near(float(tow["need_l"]), lane * per.call(trigger), 0.0001, "Bedarf bei der Auslösegeschwindigkeit")
	for litres: float in [lane * per.call(trigger) + 0.01, 3.0, lane * per.call(vmax) - 0.05]:
		var t := FuelSystem.start_check(c, spec, plan, litres)
		var m := float(t["max_kmh"])
		assert_eq(str(t["state"]), "tight", "%.2f L: nur mit Gefühl" % litres)
		assert_near(fmod(m, 5.0), 0.0, 0.0001, "%.2f L: auf 5 km/h abgerundet" % litres)
		assert_true(lane * per.call(m) <= litres + 0.0001, "%.2f L: %d km/h reichen" % [litres, roundi(m)])
		assert_true(m >= vmax - 5.0 or lane * per.call(m + 5.0) > litres, "%.2f L: 5 km/h mehr reichen nicht" % litres)
	# fuel study, Gran Turismo from Hamburg (first station 12 km): 1.9 L → tow before the start, 3 L → gently
	assert_eq(str(FuelSystem.start_check(c, spec, plan, 1.9)["state"]), "tow", "GT mit 1,9 L: Abschleppdienst")
	assert_eq(str(FuelSystem.start_check(c, spec, plan, 3.0)["state"]), "tight", "GT mit 3 L: nur mit Gefühl")
	var none := FuelSystem.start_check(c, spec, Fx.make_plan(c, 150.0, []), 10.0)
	assert_eq(float(none["first_km"]), -1.0, "ohne Tankstelle")
	assert_near(float(none["lane_km"]), 150.0, 0.0001, "dann zählt das Ziel")


## Guarantee of the fuel rules (v0.7.0, the tank carries over in a race): whoever fills up at the last station of a
## stage reaches the next stage's first fuel lane at full speed in every car – the last station at most
## station_spacing_km[1] (90) km before the finish, refuelled at the start of its lane (lane_length_km[1] before
## it), the next first station at most first_station_max_km (20) km after the start plus the lane's taper. With
## Gran Turismo (60 L, ×1.3, 270 km/h): 119 km range against 112.5 km. A change of tank sizes, consumption or the
## 90/20 km rules that breaks it fails here.
func test_full_tank_at_the_last_station_reaches_the_next_first_station() -> void:
	var c := cfg()
	var spacing: Array = ConfigLoader.lookup(c, "fuel.station_spacing_km", [60, 90])
	var lane_len: Array = ConfigLoader.lookup(c, "fuel.lane_length_km", [1.0, 2.0])
	var taper := Units.visual_m_to_km(float(ConfigLoader.lookup(c, "road.fuel_lane_taper_m", 40.0)), float(ConfigLoader.lookup(c, "time.time_scale", 12.0)))
	var need_km := float(spacing[1]) + float(lane_len[1]) + float(ConfigLoader.lookup(c, "fuel.first_station_max_km", 20.0)) + taper
	for id: String in Fx.VEHICLES:
		var spec := VehicleModel.resolve_spec(c, id)
		var range_km := float(spec["tank_l"]) / FuelSystem.consumption_for(c, spec, float(spec["vmax_kmh"])) * 100.0
		assert_true(range_km >= need_km, "%s: voller Tank reicht bei %d km/h %.1f km, nötig %.1f km" % [id, int(spec["vmax_kmh"]), range_km, need_km])


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
	var log := {"dry": 0, "tow": -1.0, "started": 0}
	f.ran_dry.connect(func() -> void: log["dry"] = int(log["dry"]) + 1)
	f.tow_finished.connect(func(p: float) -> void: log["tow"] = p)
	f.tow_started.connect(func() -> void: log["started"] = int(log["started"]) + 1)
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
			assert_true(f.holds_car(), "hält den Wagen")
		if float(log["tow"]) >= 0.0:
			break
	assert_eq(int(log["dry"]), 1, "ran_dry einmal")
	assert_eq(int(log["started"]), 1, "tow_started einmal (echtes Abschleppen)")
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


## FUEL-4: a car that rolled into the fuel lane with an empty tank refuels; a gas press while (almost) nothing
## is in the tank does not abort ("Weiterfahren" is impossible) and never calls the tow service at the pump.
## Once fuel.abort_min_fuel_l is in, a fresh press aborts as usual and the car drives on with that fuel.
func test_empty_tank_refuel_is_not_aborted_into_a_tow() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 200.0, [60.0], [], 1.5)
	var f := _fuel(c, plan)
	f.fuel_l = 0.0
	var log := {"dry": 0, "tow": 0, "finished": []}
	f.ran_dry.connect(func() -> void: log["dry"] = int(log["dry"]) + 1)
	f.tow_started.connect(func() -> void: log["tow"] = int(log["tow"]) + 1)
	f.refuel_finished.connect(func(l: float, a: bool) -> void: log["finished"] = [l, a])
	var v := Fx.vehicle(c, "limousine")
	v.speed = 30.0
	var km := 58.8
	var t := 0.0
	var min_abort := float(ConfigLoader.lookup(c, "fuel.abort_min_fuel_l", 1.0))
	# fresh presses (0.3 s each): two in the fixed part (tank empty), one while the first litre flows (5.2 s:
	# ~0.4 L), one with ~2 L in the tank (5.9 s)
	var press_at := [2.0, 4.0, 5.2, 5.9]
	var aborted_at := -1.0
	while t < 12.0:
		var throttle := 0.0
		for p: float in press_at:
			if t >= p and t < p + 0.3:
				throttle = 1.0
		if f.state == FuelSystem.State.REFUELING and throttle > 0.0 and f.fuel_l < min_abort:
			assert_false(f.can_abort_refuel(), "t=%.2f: mit %.2f L kein Abbruch möglich" % [t, f.fuel_l])
		var req := f.control_request()
		if req.is_empty():
			v.release_auto()
		else:
			v.auto_control(float(req["target_kmh"]), float(req["rate_kmh_s"]))
		v.update(DT, {"throttle": throttle}, Fx.flat_road(), {"vmax_factor": 1.0})
		var dkm := Units.visual_m_to_km(v.speed / 3.6 * DT, 12.0)
		km += dkm
		var before := f.state
		f.update(DT, km, dkm, v.speed, true, throttle)
		t += DT
		if before == FuelSystem.State.REFUELING and f.state != FuelSystem.State.REFUELING and aborted_at < 0.0:
			aborted_at = t
			break
		assert_true(f.state != FuelSystem.State.TOWING, "t=%.2f: kein Abschleppen an der Zapfsäule" % t)
	assert_eq(int(log["dry"]), 1, "ran_dry genau einmal")
	assert_eq(int(log["tow"]), 0, "kein Abschleppdienst")
	assert_true(aborted_at >= 5.88 and aborted_at < 6.0, "erst der Gasstoß mit Sprit im Tank bricht ab (t=%.2f)" % aborted_at)
	assert_true(bool(log["finished"][1]), "abgebrochen")
	assert_true(f.fuel_l >= min_abort, "fährt mit %.2f L weiter" % f.fuel_l)
	assert_false(f.rolling_out, "nicht mehr leer")
	assert_eq(f.take_penalty(), 0.0, "keine Zeitstrafe")
	# the lane lock after an abort never strands an EMPTY car in the lane: it refuels again
	f.fuel_l = 0.0
	f.update(DT, km, 0.0, 0.0, true, 0.0)
	assert_eq(f.state, FuelSystem.State.REFUELING, "leer in der Tankspur: tankt wieder, statt abgeschleppt zu werden")
	assert_true(f.holds_car(), "hält den Wagen (Polizei wartet)")


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
