class_name SessionRules
extends RefCounted
## Pure rules of the race session (scripts/race/race_session.gd), kept out of the scene so that they can
## be unit-tested without autoloads: when collisions are checked, what the HUD shows as the next fuel
## station, whether an empty tank can still roll into a fuel lane, where the police car drives while
## it overtakes the player and how fast the curves let it chase. Owner: race module.


## True when TrafficSystem.find_collision runs in this simulation step.
## Off while the car is invulnerable (crash sequence and grace time) and during scripted standstill
## phases (refuelling, police stop, tow). On while the car rolls out with an empty tank and in every
## scripted phase faster than min_scripted_kmh (render.scripted_collision_min_kmh: braking for a police
## stop or into the pumps, the finish roll-out) – the player's car never drives through traffic.
## scripted = VehicleModel state AUTO (or the finish roll-out).
static func collisions_active(invulnerable: bool, scripted: bool, speed_kmh: float, rolling_out: bool, min_scripted_kmh: float) -> bool:
	if invulnerable:
		return false
	return not scripted or rolling_out or speed_kmh > min_scripted_kmh


## Distance (odometer km) to the next fuel station for the HUD ("Entfernung zur nächsten Tankstelle").
## 0 while the car is at a station – inside the km span of a fuel lane (the pumps line the whole lane,
## StagePlan.station_km is the lane end) or refuelling –, else the distance to the next station ahead,
## -1 when none is left.
static func next_station_km(plan: StagePlan, km: float, refueling: bool) -> float:
	if plan == null:
		return -1.0
	if refueling or not plan.fuel_lane_at(km).is_empty():
		return 0.0
	var s := plan.next_station_km(km)
	return s - km if s >= 0.0 else -1.0


## Visual metres a car rolls from speed_kmh down to target_kmh at decel_kmh_s (0 if already slower).
static func roll_distance_m(speed_kmh: float, target_kmh: float, decel_kmh_s: float) -> float:
	var v0 := maxf(speed_kmh, 0.0) / 3.6
	var v1 := clampf(target_kmh, 0.0, maxf(speed_kmh, 0.0)) / 3.6
	var a := maxf(decel_kmh_s, 0.001) / 3.6
	return (v0 * v0 - v1 * v1) / (2.0 * a)


## True when a car rolling out with an empty tank (decel_kmh_s, from z at speed_kmh) can still refuel in
## a fuel lane: it must drop below trigger_kmh before the lane ends (lane_z1) and still roll when the lane
## is fully open (lane_open_z). Lanes behind the car are ignored.
static func can_roll_into_lane(z: float, speed_kmh: float, decel_kmh_s: float, trigger_kmh: float, lane_open_z: float, lane_z1: float) -> bool:
	if lane_z1 < z:
		return false
	var slow_at := z + roll_distance_m(speed_kmh, trigger_kmh, decel_kmh_s)
	var stop_at := z + roll_distance_m(speed_kmh, 0.0, decel_kmh_s)
	return slow_at <= lane_z1 and stop_at > lane_open_z


## Side (-1 left, +1 right) on which the police car passes the player: left when there is a lane left
## of the player (left_edge = left edge of the paved road), else right.
static func police_pass_side(player_x: float, left_edge: float, lane_w: float) -> float:
	return -1.0 if player_x - lane_w >= left_edge + lane_w * 0.4 else 1.0


## Lateral position (m) of the police car. offset_m = police car centre minus player car centre (visual m,
## PoliceSystem.police_car_offset_m()). While the police car is behind or level with the player it drives
## one lane beside him (side), once its rear is clear of the player's front it pulls in and ends up
## slightly left of the player's line at pull_over_m (the stop position ahead of the player).
static func police_car_x(offset_m: float, player_x: float, side: float, lane_w: float, pull_over_m: float, clear_m: float) -> float:
	var beside := 1.0 - smoothstep(clear_m, maxf(clear_m + 0.5, pull_over_m), offset_m)
	return player_x - 0.4 * (1.0 - beside) + side * lane_w * beside


## Curve limit of the police car at z (km/h; PoliceSystem.update road_cap_kmh): the highest speed from which it
## can still brake with police.curve_brake_mps2 to its own curve speed (PoliceSystem.curve_speed_mps, grip of
## the road there – Track.grip_at, dry in tunnels) at every point within police.curve_lookahead_m, sampled
## every police.curve_step_m. INF when no curve is ahead.
static func police_curve_cap_kmh(track: Track, police: PoliceSystem, z: float, weather_grip: float) -> float:
	var cap := INF
	var d := 0.0
	while d <= police.curve_lookahead_m + 0.001:
		var zz := z + d
		var vs := police.curve_speed_mps(track.curve_at(zz), track.grip_at(zz, weather_grip))
		if vs < INF:
			cap = minf(cap, sqrt(vs * vs + 2.0 * police.curve_brake_mps2 * d))
		d += police.curve_step_m
	return cap * 3.6
