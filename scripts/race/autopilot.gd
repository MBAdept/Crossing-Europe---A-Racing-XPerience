class_name Autopilot
extends RefCounted
## Debug/test driver (CLI --autopilot, attract mode): holds a lane, overtakes slower traffic, brakes ahead of
## curves (look-ahead braking curve to curve_margin * the safe curve speed, so it never understeers),
## traffic and radar zones, uses the fuel lane when the fuel would not last to the station after next
## (or always / never, see refuel_mode; it moves over lane by lane into free gaps, a station it cannot reach
## that way is skipped) and – unless speeding is allowed – respects radar limits. Hands
## off while refuelling or towing (no throttle, so the FuelSystem's "Gas = Weiterfahren" never triggers
## by accident). curve_brake = false (debug, --autopilot-no-curve-brake) ignores curves: the car then
## enters them too fast and understeers (demo of the driving model).
## Weather (v0.5.0, docs/renn-modul.md §10): it plans with brake_fraction of the car's real braking on this road
## (VehicleModel.brake_decel_mps2 – snow about half), follows slower traffic on a braking curve (the closing
## speeds are huge in snow), counts a car with its indicator on as already in the lane it signals into, needs
## longer gaps for its own lane changes when the steering responds slowly, and steers with a PD controller tuned
## to the response time of the steering (VehicleModel.steer_response_s) – no swinging on a slippery road.
## Used by headless stage simulations (tests/race/run_stage.gd) and screenshot runs. Owner: race module.

var target_kmh := 235.0
var obey_radar := true
var refuel_mode := "auto"          ## auto | always | never
var brake_decel_mps2 := 15.0       ## planning deceleration on a dry road (below the car's real braking, 70 km/h/s)
var brake_fraction := 0.75         ## at most this share of the car's real braking in the weather (snow: ~7 m/s²)
var curve_brake := true            ## false: ignore curves (debug/demo: enters curves too fast)
var curve_margin := 0.96           ## target speed in a curve = curve_margin * safe curve speed
var curve_lookahead_m := 300.0     ## the braking curve covers this distance (more than any braking distance)
var curve_step_m := 10.0           ## sample spacing of the look-ahead
var curve_lead_m := 12.0           ## reach the curve speed this many metres before the sample point
var follow_time_s := 0.9           ## time gap behind a slower car (plus 12 m)
## false (difficulty measurements, tests/sim/difficulty_sim.gd "dryhabit"): plans its braking for traffic, its lane
## change gaps and its steering as on a dry road – curves still with the real grip – to show what the weather asks of
## a driver who does not adapt.
var weather_aware := true
var reserve_l := 4.0
var _lane := -1
var _station := -2.0               ## station km of the current refuel decision
var _refuel := false
var _was_refueling := false
var _hold_lane_t := 0.0
var _plan_decel := 15.0            ## planning deceleration of the current weather (see plan_decel())
var _lc_time := 1.4                ## seconds a lane change of this car takes in this weather (gap check)
var last_want := 0.0               ## target speed of the last decision (debug trace)
var last_reason := ""              ## what limited it (debug trace)


## Planning deceleration (m/s²) for a car on a road with tyre grip `grip`: brake_decel_mps2, but at most
## brake_fraction of the car's full braking there (VehicleModel.brake_decel_mps2).
func plan_decel(v: VehicleModel, grip: float) -> float:
	return minf(brake_decel_mps2, brake_fraction * v.brake_decel_mps2(grip))


## Returns {steer, throttle, brake} for the current situation.
func drive(session: Node) -> Dictionary:
	var track: Track = session.track
	var v: VehicleModel = session.vehicle
	var traffic: TrafficSystem = session.traffic
	var fuel: FuelSystem = session.fuel
	var plan: StagePlan = session.plan
	var z: float = session.pos_z
	var km: float = session.pos_km
	var grip: float = session.env.grip(session.weather)
	var dt := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var speed := v.speed
	var grip_plan := grip if weather_aware else 1.0
	_plan_decel = plan_decel(v, grip_plan)
	_lc_time = maxf(1.4, 0.6 + 2.0 * v.steer_response_s(grip_plan))

	# --- refuelling decision (once per station) and hands-off while the FuelSystem is in control
	var refueling := fuel.state != FuelSystem.State.NORMAL
	if _was_refueling and not refueling:
		_refuel = false
	_was_refueling = refueling
	if refueling:
		return {"steer": 0.0, "throttle": 0.0, "brake": 0.0}
	var next_st := plan.next_station_km(km)
	if next_st >= 0.0 and absf(next_st - _station) > 0.01 and next_st - km < 14.0:
		_station = next_st
		_refuel = _needs_fuel(fuel, plan, km, next_st)

	# --- lanes (look ahead for lane drops)
	var lanes := mini(track.lane_count_at(z), track.lane_count_at(z + 90.0))
	if _lane < 0:
		_lane = _nearest_lane(track, z, v.x)
	_lane = clampi(_lane, 0, lanes - 1)
	_hold_lane_t = maxf(0.0, _hold_lane_t - dt)
	var want := target_kmh
	last_reason = "free"
	var target_x := track.lane_center_x(z + 12.0, _lane)
	var use_fuel_lane := _refuel and next_st >= 0.0
	if use_fuel_lane:
		var to_lane := track.distance_to_fuel_lane(z)
		# over to the right lane one lane at a time, each into a free gap like when overtaking – never straight
		# across the lanes (in snow the traffic there is far slower); the fuel lane only from the right lane
		if to_lane < 700.0 and _lane < lanes - 1 and _hold_lane_t <= 0.0 \
				and absf(track.lane_center_x(z, _lane) - v.x) < 0.8 \
				and _lane_free(traffic, track, z, _lane + 1, speed):
			_lane += 1
			_hold_lane_t = maxf(0.8, _lc_time)
		target_x = track.lane_center_x(z + 12.0, _lane)
		var open := track.fuel_lane_factor(z + 14.0)
		if _lane >= lanes - 1 and (open > 0.5 or track.fuel_lane_factor(z) > 0.5):
			target_x = track.fuel_lane_x(z + 14.0)
			want = 40.0
		else:
			var fw := _speed_for(85.0, to_lane - 5.0)
			if fw < want:
				want = fw
				last_reason = "fuel"
	else:
		var tw := _traffic(traffic, track, z, v, lanes, speed, want)
		if tw < want:
			want = tw
			last_reason = "lane"
		target_x = track.lane_center_x(z + 12.0, _lane)
	# cars directly in our path (also while changing lanes / in the fuel lane), far enough ahead for the braking
	# distance of this weather
	var blocker := _car_in_path(traffic, track, z, v.x, target_x, _look_m(speed))
	if blocker != null:
		var gap := blocker.z - z - (blocker.length + v.length_m) * 0.5
		var fw := _follow_speed(blocker.speed, gap, speed)
		if fw < want:
			want = fw
			last_reason = "path %.0f@%.0fm" % [blocker.speed, gap]

	# --- radar zones
	if obey_radar:
		var r := plan.next_radar(km)
		if not r.is_empty():
			var lim := float(r["limit"]) * 1.06
			var to_zone := track.km_to_z(float(r["km"])) - z
			var rw := lim if to_zone <= 0.0 else _speed_for(lim, to_zone - 15.0)
			if rw < want:
				want = rw
				last_reason = "radar"

	# --- curves ahead (braking curve over the look-ahead)
	if curve_brake:
		var cw := curve_speed_ahead(track, v, z, grip)
		if cw < want:
			want = cw
			last_reason = "curve"

	last_want = want
	# --- controls
	var out := pedals(speed, want)
	if fuel.rolling_out:
		# empty tank: the FuelSystem rolls the car out. The brake works then (VehicleModel.auto_control), so brake
		# only where a curve needs it – braking for the fuel lane would stop the car short of it
		out = pedals(speed, curve_speed_ahead(track, v, z, grip) if curve_brake else INF)
		out["throttle"] = 0.0
		last_reason = "rollout"
	out["steer"] = steer_to(v, target_x, grip_plan)
	return out


## Steering towards target_x: PD controller on the lateral offset and the lateral speed, its gains from the
## response time τ of the steering on this road (VehicleModel.steer_response_s) and the lateral speed of full
## lock V – closed loop τ·x'' + (1 + V·kd)·x' + V·kp·x = 0 with ω = min(7, 1.7/τ) and damping 0.85. On a dry road
## that is the old proportional steering (kp ≈ 0.7); in snow it counter-steers early instead of swinging.
static func steer_to(v: VehicleModel, target_x: float, grip: float) -> float:
	var err := target_x - v.x
	var tau := v.steer_response_s(grip)
	var vmax := v.steer_speed_mps(grip) * clampf(v.speed / 60.0, 0.25, 1.0)
	var w := minf(7.0, 1.7 / tau)
	var kp := tau * w * w / vmax
	var kd := maxf(0.0, 2.0 * 0.85 * w * tau - 1.0) / vmax
	var s := kp * err - kd * v.lat_speed
	return 0.0 if absf(err) < 0.05 and absf(v.lat_speed) < 0.2 else clampf(s, -1.0, 1.0)


## Throttle and brake that hold the target speed want (km/h): full throttle below it, brake firmly (from 30 %,
## full at 12 km/h over) above it, so the car follows the braking curve of curve_speed_ahead().
static func pedals(speed: float, want: float) -> Dictionary:
	var throttle := 0.0
	var brake := 0.0
	if speed < want - 1.0:
		throttle = 1.0
	elif speed > want + 2.0:
		brake = clampf((speed - want) / 12.0, 0.3, 1.0)
	elif speed < want:
		throttle = 0.6
	return {"throttle": throttle, "brake": brake}


## Highest speed now that still reaches curve_margin * the safe speed of every curve point within
## curve_lookahead_m (curve_lead_m early, braking with the planning deceleration of the weather) – and of the
## point under the car. grip = weather grip; inside tunnels the road is dry (Track.grip_at).
func curve_speed_ahead(track: Track, v: VehicleModel, z: float, grip: float) -> float:
	_plan_decel = plan_decel(v, grip)
	var want := v.safe_curve_speed(track.curve_at(z), track.grip_at(z, grip)) * curve_margin
	var d := curve_step_m
	while d <= curve_lookahead_m:
		var c := track.curve_at(z + d)
		if absf(c) > 0.001:
			want = minf(want, _speed_for(v.safe_curve_speed(c, track.grip_at(z + d, grip)) * curve_margin, d - curve_lead_m))
		d += curve_step_m
	return want


## Highest speed now that still allows braking to v_target within distance_m (planning deceleration).
func _speed_for(v_target_kmh: float, distance_m: float) -> float:
	var vt := v_target_kmh / 3.6
	var d := maxf(0.0, distance_m)
	return sqrt(vt * vt + 2.0 * _plan_decel * d) * 3.6


## Speed to follow a car at lead_kmh, gap_m ahead: on the relative braking curve (planning deceleration) down to
## its speed at the safe gap 12 m + follow_time_s; closer than that, slower than it.
func _follow_speed(lead_kmh: float, gap_m: float, speed_kmh: float) -> float:
	var safe_gap := 12.0 + speed_kmh / 3.6 * follow_time_s
	if gap_m <= 4.0:
		return minf(lead_kmh * 0.8, 30.0)
	if gap_m < safe_gap:
		return maxf(0.0, lead_kmh - (safe_gap - gap_m) * 1.2)
	return lead_kmh + sqrt(2.0 * _plan_decel * (gap_m - safe_gap)) * 3.6


## How far ahead cars in the path matter: the braking distance from speed_kmh to standstill with the planning
## deceleration plus the safe gap (110–320 m).
func _look_m(speed_kmh: float) -> float:
	var vm := speed_kmh / 3.6
	return clampf(vm * vm / (2.0 * _plan_decel) + 12.0 + vm * follow_time_s + 20.0, 110.0, 320.0)


func _needs_fuel(fuel: FuelSystem, plan: StagePlan, km: float, station_km: float) -> bool:
	if refuel_mode == "always":
		return true
	if refuel_mode == "never":
		return false
	var after := plan.length_km
	for s in plan.fuel_stations_km:
		if s > station_km + 0.5:
			after = s
			break
	var cruise := clampf(target_kmh, 90.0, 260.0)
	var need := (after - km) * fuel.consumption_per_100km(cruise) / 100.0 * 1.12 + reserve_l
	return fuel.fuel_l < need


func _nearest_lane(track: Track, z: float, x: float) -> int:
	var best := 0
	var best_d := INF
	for i in track.lane_count_at(z):
		var dd := absf(track.lane_center_x(z, i) - x)
		if dd < best_d:
			best_d = dd
			best = i
	return best


## Overtaking logic: picks the adjacent lane with the best achievable speed (car ahead in it and its
## distance) if it is safe to enter, with hysteresis; returns the speed allowed in the chosen lane.
func _traffic(traffic: TrafficSystem, track: Track, z: float, v: VehicleModel, lanes: int, speed: float, desired: float) -> float:
	var here := _lane_speed(traffic, track, z, _lane, desired)
	if _hold_lane_t <= 0.0 and here < desired - 4.0 and absf(track.lane_center_x(z, _lane) - v.x) < 0.8:
		var best := _lane
		var best_v := here + 6.0
		for cand: int in [_lane - 1, _lane + 1]:
			if cand < 0 or cand >= lanes or not _lane_free(traffic, track, z, cand, speed):
				continue
			var lv := _lane_speed(traffic, track, z, cand, desired) + (2.0 if cand < _lane else 0.0)
			if lv > best_v:
				best = cand
				best_v = lv
		if best != _lane:
			_lane = best
			_hold_lane_t = maxf(0.8, _lc_time)
			here = _lane_speed(traffic, track, z, _lane, desired)
	var ahead := _car_ahead_in_lane(traffic, track, z, _lane, maxf(160.0, _look_m(speed)))
	if ahead == null:
		return INF
	var gap := ahead.z - z - (ahead.length + v.length_m) * 0.5
	if ahead.speed < desired - 1.0:
		return _follow_speed(ahead.speed, gap, speed)
	return INF


## Speed one can expect in a lane: limited by the next car in it, the less the farther away it is.
func _lane_speed(traffic: TrafficSystem, track: Track, z: float, lane: int, desired: float) -> float:
	var c := _car_ahead_in_lane(traffic, track, z, lane, 220.0)
	if c == null:
		return desired
	var gap := c.z - z
	return lerpf(minf(c.speed, desired), desired, clampf((gap - 30.0) / 190.0, 0.0, 1.0))


## A car counts for a lane when its body is near the lane centre or it signals into that lane (indicator on).
static func _in_lane(track: Track, c: TrafficSystem.Car, lane: int) -> bool:
	if absf(c.x - track.lane_center_x(c.z, lane)) < 2.2:
		return true
	return c.signal_dir != 0 and c.signal_lane == lane


func _car_ahead_in_lane(traffic: TrafficSystem, track: Track, z: float, lane: int, dist: float) -> TrafficSystem.Car:
	var best: TrafficSystem.Car = null
	for c in traffic.cars:
		if c.z <= z or c.z - z > dist:
			continue
		if _in_lane(track, c, lane):
			if best == null or c.z < best.z:
				best = c
	return best


## Nearest car ahead whose body overlaps the corridor from the car to target_x – or that signals into it.
func _car_in_path(traffic: TrafficSystem, track: Track, z: float, x: float, target_x: float,
		dist: float) -> TrafficSystem.Car:
	var best: TrafficSystem.Car = null
	var lo := minf(x, target_x) - 1.9
	var hi := maxf(x, target_x) + 1.9
	for c in traffic.cars:
		if c.z <= z - 1.0 or c.z - z > dist:
			continue
		var cx0 := c.x - c.width * 0.5
		var cx1 := c.x + c.width * 0.5
		if c.signal_dir != 0 and c.signal_lane != TrafficSystem.FUEL_LANE:
			var sx := track.lane_center_x(c.z, c.signal_lane)
			cx0 = minf(cx0, sx - c.width * 0.5)
			cx1 = maxf(cx1, sx + c.width * 0.5)
		if cx1 > lo and cx0 < hi:
			if best == null or c.z < best.z:
				best = c
	return best


## Room to change into `lane`: no car beside or just ahead/behind in it (or signalling into it); the gap ahead must
## cover the time a lane change takes in this weather at the closing speed plus the relative braking distance.
func _lane_free(traffic: TrafficSystem, track: Track, z: float, lane: int, speed: float) -> bool:
	for c in traffic.cars:
		if not _in_lane(track, c, lane) and absf(c.x - track.lane_center_x(c.z, lane)) > 2.6:
			continue
		var rel := c.z - z
		var closing := maxf(0.0, (speed - c.speed) / 3.6)
		var behind_need := 12.0 + maxf(0.0, (c.speed - speed) / 3.6) * 2.0
		var ahead_need := 18.0 + closing * _lc_time + closing * closing / (2.0 * _plan_decel)
		if rel > -behind_need and rel < ahead_need:
			return false
	return true
