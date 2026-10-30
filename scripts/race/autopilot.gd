class_name Autopilot
extends RefCounted
## Debug/test driver (CLI --autopilot): keeps a lane, overtakes slower traffic, brakes for sharp
## curves, refuels when needed and (unless speeding is allowed) respects radar limits.
## Used by headless stage simulations and screenshot runs. Owner: race module.

var target_kmh := 235.0
var obey_radar := true
var refuel_below_fraction := 0.45
var _lane := -1


## Returns {steer, throttle, brake} for the current situation.
func drive(session: Node) -> Dictionary:
	var track: Track = session.track
	var v: VehicleModel = session.vehicle
	var traffic: TrafficSystem = session.traffic
	var fuel: FuelSystem = session.fuel
	var z: float = session.pos_z
	var km: float = session.pos_km
	var lanes := track.lane_count_at(z + 40.0)
	if _lane < 0 or _lane >= lanes:
		_lane = lanes - 1
	var want := target_kmh
	# refuelling: head for the fuel lane when low and a station is near
	var to_station := fuel.distance_to_next_station(km)
	var go_fuel := fuel.fuel_l < fuel.tank_l * refuel_below_fraction and to_station >= 0.0 and to_station < 6.0
	var target_x := track.lane_center_x(z + 20.0, _lane)
	if go_fuel:
		_lane = lanes - 1
		target_x = track.lane_center_x(z + 20.0, _lane)
		if track.fuel_lane_at(z + 15.0) or track.fuel_lane_at(z):
			target_x = track.fuel_lane_x(z + 15.0)
			want = 45.0
		elif to_station < 2.5:
			want = 90.0
	else:
		# overtake slower cars ahead
		var ahead := _car_ahead(traffic, z, target_x, 90.0)
		if ahead != null and ahead.speed < v.speed - 5.0:
			var best := _lane
			for cand in [_lane - 1, _lane + 1]:
				if cand >= 0 and cand < lanes and _lane_free(traffic, track, z, cand):
					best = cand
					break
			if best == _lane:
				want = minf(want, ahead.speed)
			_lane = best
			target_x = track.lane_center_x(z + 20.0, _lane)
	# radar zones
	if obey_radar:
		var r: Dictionary = session.plan.next_radar(km)
		if not r.is_empty() and km > float(r["km"]) - 2.0:
			want = minf(want, float(r["limit"]) * 1.08)
	# curves ahead
	var look := track.curve_at(z + 60.0)
	var safe := v.safe_curve_speed(look, session.env.grip(session.weather))
	want = minf(want, safe * 0.98)
	var steer := clampf((target_x - v.x) * 0.6, -1.0, 1.0)
	var throttle := 1.0 if v.speed < want - 2.0 else 0.0
	var brake := 1.0 if v.speed > want + 8.0 else 0.0
	return {"steer": steer, "throttle": throttle, "brake": brake}


func _car_ahead(traffic: TrafficSystem, z: float, x: float, dist: float) -> TrafficSystem.Car:
	var best: TrafficSystem.Car = null
	for c in traffic.cars:
		if c.z > z and c.z - z < dist and absf(c.x - x) < 2.2:
			if best == null or c.z < best.z:
				best = c
	return best


func _lane_free(traffic: TrafficSystem, track: Track, z: float, lane: int) -> bool:
	var x := track.lane_center_x(z, lane)
	for c in traffic.cars:
		if absf(c.x - x) < 2.4 and c.z > z - 25.0 and c.z < z + 70.0:
			return false
	return true
