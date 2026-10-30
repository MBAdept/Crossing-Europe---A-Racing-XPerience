extends TestCase
## Numeric simulations proving the design document numbers (tests/sim/gameplay_sim.gd). Each test prints
## its table; the full set is also printed by: godot --headless --path . -s res://tests/sim/run_sims.gd

const Fx := preload("res://tests/sim/fixtures.gd")
const Sim := preload("res://tests/sim/gameplay_sim.gd")


func test_a_collision_at_200_costs_7_to_10_s() -> void:
	var c := cfg()
	print(Sim.table_collision(c))
	for id: String in Fx.VEHICLES:
		var r := Sim.collision_cost(c, id, 200.0)
		assert_near(float(r["slow_s"]), float(ConfigLoader.lookup(c, "collision.slowdown_s", 3.0)), 0.02, id + ": in 3 s auf 10 km/h")
		var lost := float(r["lost_s"])
		if int(ConfigLoader.lookup(c, "vehicles.types.%s.accel" % id, 0)) == 3:
			assert_between(lost, 7.0, 10.0, id + " (Beschleunigung 3): Verlust")
		else:
			assert_between(lost, 5.5, 10.5, id + ": Verlust in der Nähe von 7–10 s")


func test_b_police_stop_costs_15_to_20_s() -> void:
	var c := cfg()
	print(Sim.table_police(c))
	for id: String in Fx.VEHICLES:
		for cruise: float in [160.0, 180.0]:
			var r := Sim.police_caught_cost(c, id, cruise)
			assert_between(float(r["lost_s"]), 15.0, 20.0, "%s bei %d km/h" % [id, int(cruise)])
			assert_near(float(r["stand_s"]), float(ConfigLoader.lookup(c, "police.stop_duration_s", 10.0)), 0.05, id + ": 10 s stehen")


func test_c_refuel_empty_50l_takes_25_s() -> void:
	var c := cfg()
	print(Sim.table_refuel(c))
	var r := Sim.refuel_run(c, 50.0, 50.0)
	assert_near(float(r["duration_s"]), 25.0, 0.05, "leerer 50-L-Tank")


func test_d_consumption_and_range_table() -> void:
	var c := cfg()
	print(Sim.table_consumption(c))
	var expected := {100.0: [17.4, 290.0], 130.0: [19.7, 255.0], 180.0: [25.0, 200.0], 250.0: [35.3, 140.0]}
	for v: float in expected:
		var row: Array = expected[v]
		var per100 := Sim.consumption_run(c, v, 100.0)
		assert_near(per100, float(row[0]), 0.06, "Verbrauch bei %d km/h" % int(v))
		assert_near(50.0 / per100 * 100.0, float(row[1]), 5.0, "Reichweite (50 L) bei %d km/h" % int(v))


func test_e_escape_at_222_but_not_at_210() -> void:
	var c := cfg()
	print(Sim.table_escape(c))
	for id: String in Fx.VEHICLES:
		assert_eq(str(Sim.escape_run(c, id, 222.0)["result"]), "escaped", id + ": 222 km/h halten -> Flucht")
		assert_eq(str(Sim.escape_run(c, id, 210.0)["result"]), "caught", id + ": 210 km/h -> erwischt")
	var env := EnvironmentModel.new()
	env.setup(c)
	for id: String in Fx.VEHICLES:
		var r := Sim.escape_run(c, id, 400.0, env.vmax_factor(2.0, "rain"), 140.0)
		assert_eq(str(r["result"]), "escaped", id + ": Vollgas ab 140 km/h bei Regen in der Nacht -> Flucht")


func test_f_all_vehicles_reach_220_in_rain_at_night() -> void:
	var c := cfg()
	print(Sim.table_rain_night(c))
	var env := EnvironmentModel.new()
	env.setup(c)
	for id: String in Fx.VEHICLES:
		var r := Sim.accel_run(c, id, env.vmax_factor(2.0, "rain"))
		assert_true(float(r["top"]) >= 220.0, "%s: %.1f km/h" % [id, float(r["top"])])


func test_g_traffic_density_speed_chase_city() -> void:
	var c := cfg()
	print(Sim.table_traffic(c))
	var d8 := Sim.density_at(c, 8.0)
	var d3 := Sim.density_at(c, 3.0)
	assert_true(d8 > d3 * 4.0, "08:00 deutlich mehr Verkehr als 03:00 (%.2f vs %.2f)" % [d8, d3])
	assert_near(Sim.density_at(c, 12.0, true) / Sim.density_at(c, 12.0), 0.2, 0.0001, "Verfolgung -80 %")
	assert_near(Sim.density_at(c, 12.0, false, "city", true) / Sim.density_at(c, 12.0, false, "city", false), 2.5, 0.0001, "City Limits x2,5")
	var ts := TrafficSystem.new()
	var empty: Array[String] = []
	ts.setup(c, Fx.FakeTrack.new(), empty, empty, 1)
	assert_near(ts.speed_factor(0.5) / ts.speed_factor(12.0), 1.15, 0.0001, "nachts +15 %")


func test_h_acceleration_times() -> void:
	var c := cfg()
	print(Sim.table_accel(c))
	for id: String in Fx.VEHICLES:
		var r := Sim.accel_run(c, id)
		assert_between(float(r["t100"]) / float(r["t100_target"]), 0.9, 1.1, id + " 0-100")
		assert_between(float(r["t200"]) / float(r["t200_target"]), 0.9, 1.1, id + " 0-200")
