extends TestCase
## Autopilot in bad weather (v0.5.0, docs/renn-modul.md §10): it plans with the braking of the weather, steers
## without swinging on a slippery road and gets through dense traffic in snow and rain without a collision, off-road
## excursion or understeer – it drives the tests, demos and the attract mode.

const DT := 1.0 / 60.0

## Duck-typed race session for Autopilot.drive (the fields it reads).
class SimSession extends Node:
	var track: Track
	var vehicle: VehicleModel
	var traffic: TrafficSystem
	var fuel: FuelSystem
	var plan: StagePlan
	var env: EnvironmentModel
	var weather := "normal"
	var pos_z := 0.0
	var pos_km := 0.0


const COUNTRIES := {"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}}}
const CITIES := {"a": {"name": "Astadt", "country": "DE"}, "b": {"name": "Bdorf", "country": "DE"}}


func _stage() -> Dictionary:
	return {"id": "t_ap_weather", "from": "a", "to": "b", "length_km": 150, "seed": 77,
		"sections": [
			{"length_km": 60, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "north_plain", "country": "DE", "speed_limit": null, "traffic": 1.4},
			{"length_km": 40, "road": "landstrasse", "curviness": 2, "hills": 2, "scenery": "forest_hills", "country": "DE"},
			{"length_km": 50, "road": "autobahn", "curviness": 2, "hills": 1, "scenery": "north_plain", "country": "DE", "speed_limit": 120, "traffic": 1.2},
		],
		"fuel_stations_km": [], "radars": [], "tunnels": [], "borders": []}


## The autopilot's PD steering is tuned to the response of the steering on this road: a lane change (3.75 m) at
## 200 km/h overshoots the target by less than 0.4 m and settles within 2.5 s – also on snow, where the car keeps
## sliding (VehicleModel.steer_response_s); the old proportional steering swung there.
func test_steering_does_not_swing_on_snow() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	for w: String in ["normal", "rain", "snow"]:
		var g := env.grip(w)
		var v := VehicleModel.new()
		v.setup(c, "limousine")
		v.speed = 200.0
		v.x = 3.75
		var road := {"curve": 0.0, "grade": 0.0, "left_edge": -5.625, "right_edge": 5.625, "shoulder_m": 2.5, "guardrail": true, "grip": g}
		var over := 0.0
		var settled := -1.0
		var t := 0.0
		while t < 4.0:
			v.update(DT, {"steer": Autopilot.steer_to(v, 0.0, g)}, road, {"vmax_factor": 10.0})
			v.speed = 200.0
			t += DT
			over = maxf(over, -v.x)
			if settled < 0.0 and absf(v.x) < 0.15 and absf(v.lat_speed) < 0.3:
				settled = t
		assert_true(over < 0.4, "%s: überschwingt %.2f m" % [w, over])
		assert_true(settled > 0.0 and settled < 2.5, "%s: nach %.2f s in der Spur" % [w, settled])


## It plans its braking with brake_fraction of the car's braking in this weather (snow about half of the dry value).
func test_plans_with_the_braking_of_the_weather() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := VehicleModel.new()
	v.setup(c, "limousine")
	var ap := Autopilot.new()
	assert_near(ap.plan_decel(v, 1.0), minf(ap.brake_decel_mps2, ap.brake_fraction * v.brake_decel_mps2(1.0)), 0.0001, "trocken")
	assert_near(ap.plan_decel(v, env.grip("snow")), ap.brake_fraction * v.brake_decel_mps2(env.grip("snow")), 0.0001, "Schnee")
	assert_true(ap.plan_decel(v, env.grip("snow")) < ap.plan_decel(v, 1.0) * 0.6, "Schnee: plant viel früher zu bremsen")
	# following a slow truck: the snow braking curve allows less speed at the same gap
	ap.plan_decel(v, 1.0)
	ap._plan_decel = ap.plan_decel(v, 1.0)
	var dry := ap._follow_speed(60.0, 150.0, 200.0)
	ap._plan_decel = ap.plan_decel(v, env.grip("snow"))
	var snow := ap._follow_speed(60.0, 150.0, 200.0)
	assert_true(snow < dry - 20.0, "Folgetempo bei 150 m: Schnee %.0f, trocken %.0f km/h" % [snow, dry])


## On its way to the fuel lane it moves over one lane at a time, each into a free gap, and enters the fuel lane only
## from the right lane. Before, it steered straight across all lanes 700 m ahead of the fuel lane – in snow it hit a
## car doing 86 km/h 22 m ahead in the middle lane (sports car, 181 km/h, Saragossa – Pau).
func test_fuel_lane_approach_waits_for_a_gap() -> void:
	var c := cfg()
	var st := _stage()
	st["fuel_stations_km"] = [30]
	var plan := StagePlan.build(st, "a", CITIES, COUNTRIES, c)
	assert_eq(plan.fuel_lanes.size(), 1, "Tankspur")
	var track := Track.new()
	track.setup(plan, c, {})
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := VehicleModel.new()
	v.setup(c, "sportwagen")
	var traffic := TrafficSystem.new()
	var sets: Array[String] = ["traffic/sedan_blue"]
	var heavy: Array[String] = []
	traffic.setup(c, track, sets, heavy, 5)
	var fuel := FuelSystem.new()
	fuel.setup(c, v.spec, plan)
	var sess := SimSession.new()
	sess.track = track
	sess.vehicle = v
	sess.traffic = traffic
	sess.fuel = fuel
	sess.plan = plan
	sess.env = env
	sess.weather = "snow"
	var ap := Autopilot.new()
	ap.target_kmh = 300.0
	ap.obey_radar = false
	ap.refuel_mode = "always"
	var z := track.km_to_z(float(plan.fuel_lanes[0]["start_km"])) - 600.0
	sess.pos_z = z
	sess.pos_km = track.z_to_km(z)
	v.x = track.lane_center_x(z, 0)
	v.speed = 181.0
	var slow := TrafficSystem.Car.new()
	slow.id = 1
	slow.lane = 1
	slow.z = z + 22.0 + (slow.length + v.length_m) * 0.5
	slow.x = track.lane_center_x(slow.z, 1)
	slow.speed = 86.0
	slow.cruise_speed = 86.0
	traffic.cars.append(slow)
	var out := {}
	for i in 60:
		out = ap.drive(sess)
	assert_eq(ap._lane, 0, "wartet links, solange die Mittelspur nicht frei ist")
	assert_true(absf(float(out["steer"])) < 0.05, "lenkt nicht hinüber (%.2f)" % float(out["steer"]))
	# the gap opens: one lane, not two
	traffic.cars.clear()
	out = ap.drive(sess)
	assert_eq(ap._lane, 1, "eine Spur weiter")
	for i in 30:
		out = ap.drive(sess)
	assert_eq(ap._lane, 1, "erst in der Mittelspur ankommen")
	v.x = track.lane_center_x(z, 1)
	for i in 120:
		out = ap.drive(sess)
	assert_eq(ap._lane, 2, "dann in die rechte Spur")
	# beside the open fuel lane, but still in the middle lane with a car on the right: no fuel lane yet
	var zf := track.km_to_z(float(plan.fuel_lanes[0]["start_km"])) + 40.0
	var ap2 := Autopilot.new()
	ap2.obey_radar = false
	ap2.refuel_mode = "always"
	sess.pos_z = zf
	sess.pos_km = track.z_to_km(zf)
	v.x = track.lane_center_x(zf, 1)
	v.speed = 90.0
	var right := TrafficSystem.Car.new()
	right.id = 2
	right.lane = 2
	right.z = zf + 3.0
	right.x = track.lane_center_x(zf, 2)
	right.speed = 90.0
	right.cruise_speed = 90.0
	traffic.cars.append(right)
	out = ap2.drive(sess)
	assert_eq(ap2._lane, 1, "bleibt in der Mittelspur")
	assert_true(absf(float(out["steer"])) < 0.05 and ap2.last_want > 60.0, "nicht in die Tankspur (Lenkung %.2f, Ziel %.0f km/h)"
		% [float(out["steer"]), ap2.last_want])
	traffic.cars.clear()
	v.x = track.lane_center_x(zf, 2)
	ap2._lane = 2
	out = ap2.drive(sess)
	assert_near(ap2.last_want, 40.0, 0.01, "aus der rechten Spur in die Tankspur")
	assert_true(float(out["steer"]) > 0.3, "lenkt in die Tankspur (%.2f)" % float(out["steer"]))
	sess.free()


## Session on the test stage with scripted traffic (no TrafficSystem AI: every car keeps its lane x and speed).
func _scripted_session(c: Dictionary, st: Dictionary, vehicle_id: String) -> SimSession:
	var plan := StagePlan.build(st, "a", CITIES, COUNTRIES, c)
	var sess := SimSession.new()
	sess.plan = plan
	sess.track = Track.new()
	sess.track.setup(plan, c, {})
	sess.env = EnvironmentModel.new()
	sess.env.setup(c)
	sess.vehicle = VehicleModel.new()
	sess.vehicle.setup(c, vehicle_id)
	sess.traffic = TrafficSystem.new()
	var sets: Array[String] = ["traffic/sedan_blue"]
	var heavy: Array[String] = []
	sess.traffic.setup(c, sess.track, sets, heavy, 5)
	sess.fuel = FuelSystem.new()
	sess.fuel.setup(c, sess.vehicle.spec, plan)
	return sess


func _scripted_car(sess: SimSession, id: int, lane: int, z: float, kmh: float) -> TrafficSystem.Car:
	var car := TrafficSystem.Car.new()
	car.id = id
	car.lane = lane
	car.z = z
	car.x = sess.track.lane_center_x(z, lane)
	car.speed = kmh
	car.cruise_speed = kmh
	sess.traffic.cars.append(car)
	return car


## Drives the autopilot for `seconds` among the scripted cars; returns {collisions, min_gap (bodies overlapping
## sideways), max_lane, lanes ([] of the autopilot's lane per second)}.
func _run_scripted(sess: SimSession, ap: Autopilot, seconds: float, on_step: Callable = Callable()) -> Dictionary:
	var v := sess.vehicle
	var track := sess.track
	var grip := sess.env.grip(sess.weather)
	var out := {"collisions": 0, "min_gap": INF, "max_lane": -1, "min_x": INF}
	var touching := false
	var t := 0.0
	while t < seconds:
		var z := sess.pos_z
		sess.pos_km = track.z_to_km(z)
		var input := ap.drive(sess)
		var e := track.road_edges_at(z)
		var road := {"curve": track.curve_at(z), "grade": track.grade_at(z), "left_edge": e.x, "right_edge": e.y,
			"shoulder_m": track.shoulder_w, "guardrail": true, "grip": track.grip_at(z, grip)}
		v.update(DT, input, road, {"vmax_factor": 1.0})
		sess.pos_z += v.speed / 3.6 * DT
		var hit := false
		for car in sess.traffic.cars:
			car.z += car.speed / 3.6 * DT
			car.x = track.lane_center_x(car.z, car.lane)
			if absf(car.x - v.x) < (car.width + v.width_m) * 0.5:
				var gap := absf(car.z - sess.pos_z) - (car.length + v.length_m) * 0.5
				out["min_gap"] = minf(float(out["min_gap"]), gap)
				hit = hit or gap < 0.0
		if hit and not touching:
			out["collisions"] = int(out["collisions"]) + 1
		touching = hit
		out["max_lane"] = maxi(int(out["max_lane"]), ap._lane)
		out["min_x"] = minf(float(out["min_x"]), v.x)
		if on_step.is_valid():
			on_step.call(t)
		t += DT
	return out


## Lane drop 3 -> 2 (QA v0.5.0, Königsrennen, Bremen – Amsterdam): the autopilot overtook in the empty right lane
## that ended 250 m later, and 90 m before its end a forced lane choice without a gap check pushed it into the
## middle lane, where the merge queue stood – 157 km/h into a standing car. Now: in the ending lane with a standing
## jam in the middle lane it brakes and stops before the end instead of forcing its way over.
func test_lane_end_stops_instead_of_forcing_into_a_jam() -> void:
	var c := cfg()
	var sess := _scripted_session(c, _stage(), "limousine")
	var track := sess.track
	var drop_z := track.km_to_z(60.0)
	var z_end := drop_z - float(ConfigLoader.lookup(c, "road.lane_transition_m", 180.0))
	assert_near(track.lane_end_ahead(z_end - 400.0, 2, 1000.0), 400.0, 0.01, "Spur 2 endet für den Verkehr")
	assert_eq(track.lane_end_ahead(z_end - 400.0, 1, 1000.0), INF, "Spur 1 geht weiter")
	var z := z_end - 450.0
	sess.pos_z = z
	sess.vehicle.x = track.lane_center_x(z, 2)
	sess.vehicle.speed = 200.0
	for k in 22:   # standing jam in the middle lane up to the end of the right lane
		_scripted_car(sess, 10 + k, 1, z_end - 6.0 - 19.5 * float(k), 0.0)
	var ap := Autopilot.new()
	ap.obey_radar = false
	ap.refuel_mode = "never"
	var r := _run_scripted(sess, ap, 25.0)
	assert_eq(int(r["collisions"]), 0, "keine Kollision")
	assert_true(sess.vehicle.speed < 1.0, "steht (%.1f km/h)" % sess.vehicle.speed)
	assert_true(sess.pos_z < z_end, "vor dem Spurende (%.1f m davor)" % (z_end - sess.pos_z))
	assert_true(float(r["min_x"]) > track.lane_center_x(z_end, 2) - 1.0, "zieht nicht in die Mittelspur (x min %.2f)" % float(r["min_x"]))
	sess.free()


## It never changes into a lane that ends within its lane horizon, even when it is empty (everybody has left it).
func test_does_not_overtake_in_an_ending_lane() -> void:
	var c := cfg()
	var sess := _scripted_session(c, _stage(), "limousine")
	var track := sess.track
	var z_end := track.km_to_z(60.0) - float(ConfigLoader.lookup(c, "road.lane_transition_m", 180.0))
	var z := z_end - 340.0
	sess.pos_z = z
	sess.vehicle.x = track.lane_center_x(z, 1)
	sess.vehicle.speed = 150.0
	_scripted_car(sess, 1, 1, z + 70.0, 80.0)     # slow car ahead in the middle lane
	_scripted_car(sess, 2, 0, z + 2.0, 150.0)     # left lane taken
	_scripted_car(sess, 3, 0, z + 30.0, 150.0)
	var ap := Autopilot.new()
	ap.obey_radar = false
	ap.refuel_mode = "never"
	var r := _run_scripted(sess, ap, 6.0)
	assert_true(int(r["max_lane"]) <= 1, "nicht in die endende rechte Spur (Spur %d)" % int(r["max_lane"]))
	assert_eq(int(r["collisions"]), 0, "keine Kollision")
	sess.free()


## Leaving the fuel lane after refuelling (QA v0.5.0, Hamburg – Hannover, sports car): it pulled out at 31 km/h in
## front of a car doing 100 in the right lane. Now it accelerates along the fuel lane and merges once the gap behind
## is long enough.
func test_fuel_lane_exit_waits_for_the_traffic_behind() -> void:
	var c := cfg()
	var st := _stage()
	st["fuel_stations_km"] = [30]
	var sess := _scripted_session(c, st, "sportwagen")
	var track := sess.track
	var lane := sess.plan.fuel_lanes[0]
	var z0 := track.km_to_z(float(lane["start_km"]))
	var z := z0 + 45.0
	sess.pos_z = z
	sess.vehicle.x = track.fuel_lane_x(z)
	sess.vehicle.speed = 0.0
	var fast := _scripted_car(sess, 1, 2, z - 40.0, 100.0)
	var ap := Autopilot.new()
	ap.obey_radar = false
	ap.refuel_mode = "never"
	var merged_while_close := [false]
	var r := _run_scripted(sess, ap, 12.0, func(_t: float) -> void:
		var v := sess.vehicle
		if v.x < track.main_right_edge(sess.pos_z) and fast.z < sess.pos_z + 10.0:
			merged_while_close[0] = true)
	assert_false(bool(merged_while_close[0]), "wartet, bis das schnelle Auto vorbei ist")
	assert_eq(int(r["collisions"]), 0, "keine Kollision")
	assert_true(sess.vehicle.x < track.main_right_edge(sess.pos_z), "danach zurück in der rechten Spur (x %.2f)" % sess.vehicle.x)
	sess.free()


## Drives the stage with traffic at rush hour (08:00, dense: section factors 1.2–1.4) and returns the stats.
func _drive(weather: String, vehicle_id: String, km_to: float) -> Dictionary:
	var c := cfg()
	var plan := StagePlan.build(_stage(), "a", CITIES, COUNTRIES, c)
	var track := Track.new()
	track.setup(plan, c, {})
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := VehicleModel.new()
	v.setup(c, vehicle_id)
	var traffic := TrafficSystem.new()
	var sets: Array[String] = ["traffic/sedan_blue", "traffic/hatch_green", "traffic/van_white", "traffic/suv_grey", "traffic/wagon_white"]
	var heavy: Array[String] = ["traffic/truck_white", "traffic/truck_red", "traffic/bus_blue"]
	traffic.setup(c, track, sets, heavy, plan.seed + 17)
	var fuel := FuelSystem.new()
	fuel.setup(c, v.spec, plan)
	var clock := WorldClock.new()
	clock.setup(c, 8.0 * 60.0)
	var proj := RoadProjection.new()
	proj.setup(ConfigLoader.lookup(c, "render", {}), Vector2(1280, 720))
	var sess := SimSession.new()
	sess.track = track
	sess.vehicle = v
	sess.traffic = traffic
	sess.fuel = fuel
	sess.plan = plan
	sess.env = env
	sess.weather = weather
	var ap := Autopilot.new()
	ap.target_kmh = 300.0
	ap.obey_radar = false
	ap.refuel_mode = "never"
	var grip := env.grip(weather)
	var z := track.km_to_z(0.5)
	v.x = track.lane_center_x(z, track.lane_count_at(z) - 1)
	v.speed = 100.0
	var out := {"collisions": 0, "off_road_s": 0.0, "understeer_max": 0.0, "time_s": 0.0, "cut_ins": 0, "km": 0.0}
	var draw := float(ConfigLoader.lookup(c, "render.draw_distance_m", 900.0))
	track.update_window(z - proj.cam_distance, draw + 60.0)
	traffic.update(0.0, {"z": z, "x": v.x, "speed": v.speed}, {"hour": 8.0, "camera_z": z - proj.cam_distance, "weather": weather})
	var crash := false
	var t := 0.0
	while track.z_to_km(z) < km_to and t < 1500.0:
		sess.pos_z = z
		sess.pos_km = track.z_to_km(z)
		fuel.fuel_l = fuel.tank_l
		var input := ap.drive(sess)
		var e := track.road_edges_at(z)
		var seg := track.segment_at(z)
		var road := {"curve": track.curve_at(z), "grade": track.grade_at(z), "left_edge": e.x, "right_edge": e.y,
			"shoulder_m": track.shoulder_w, "guardrail": seg.guardrail or seg.tunnel, "grip": track.grip_at(z, grip)}
		v.update(DT, input, road, {"vmax_factor": env.vmax_factor(clock.hour(), weather)})
		z += v.speed / 3.6 * DT
		var cam_z := z - proj.cam_distance
		track.update_window(cam_z, draw + 60.0)
		traffic.update(DT, {"z": z, "x": v.x, "speed": v.speed}, {"hour": clock.hour(), "chase": false, "camera_z": cam_z,
			"visibility_m": draw * env.visibility_factor(clock.hour(), weather, track.is_tunnel_at(cam_z + 5.0)), "weather": weather,
			"brake_mps2": v.brake_decel_mps2(grip)})
		if not v.invulnerable:
			var hit := traffic.find_collision({"z": z, "x": v.x, "length": v.length_m, "width": v.width_m}, cam_z, proj.visible_fraction)
			if hit != null:
				var sp := traffic.space_beside(z, v.x, v.length_m * 0.5, e.x - track.shoulder_w, e.y + track.shoulder_w, hit)
				v.start_crash(hit.x, sp.x, sp.y)
		if v.state == VehicleModel.State.CRASH and not crash:
			out["collisions"] = int(out["collisions"]) + 1
		crash = v.state == VehicleModel.State.CRASH
		if v.off_road > 0:
			out["off_road_s"] = float(out["off_road_s"]) + DT
		out["understeer_max"] = maxf(float(out["understeer_max"]), v.understeer)
		clock.advance(DT)
		t += DT
	out["time_s"] = t
	out["km"] = track.z_to_km(z) - 0.5
	out["cut_ins"] = traffic.cut_ins
	out["avg_kmh"] = Units.avg_speed_kmh(float(out["km"]), t, float(ConfigLoader.lookup(c, "time.time_scale", 12.0)))
	sess.free()
	return out


## The autopilot finishes dense rush-hour traffic in snow and rain (autobahn, curvy Landstraße, autobahn with a
## limit) without a collision, without leaving the road and without understeering – while the traffic pulls out in
## front of it (cut-ins) and is much slower than it.
func test_autopilot_gets_through_traffic_in_snow_and_rain() -> void:
	for spec: Array in [["snow", "gran_turismo", 110.0], ["rain", "kompakt", 80.0]]:
		var r := _drive(str(spec[0]), str(spec[1]), float(spec[2]))
		var label := "%s, %s, %.0f km" % [spec[0], spec[1], float(r["km"])]
		assert_true(float(r["km"]) > float(spec[2]) - 1.5, label + ": angekommen")
		assert_eq(int(r["collisions"]), 0, label + ": keine Kollision")
		assert_near(float(r["off_road_s"]), 0.0, 0.001, label + ": nie neben der Fahrbahn")
		assert_true(float(r["understeer_max"]) < 0.05, label + ": kein Untersteuern (%.3f)" % float(r["understeer_max"]))
		print("    %s: Ø %.0f km/h, %d Mal vor ihm eingeschert" % [label, float(r["avg_kmh"]), int(r["cut_ins"])])
