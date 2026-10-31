class_name VehiclePose
extends RefCounted
## Pure maths of the vehicle display v2 (docs/fahrzeug-darstellung.md, docs/renn-modul.md §8): display yaw of
## rear-pivot ortho sprites (contract formula with the vehicle length), critically damped smoothing, cell
## choice with hysteresis, visible yaw and body roll of the player car, perspective sprite scale.
## No nodes, no autoloads – unit tests: tests/unit/race/test_vehicle_pose.gd. Owner: race module.
##
## Camera space as in RoadProjection: x lateral (+ right), depth d ahead of the camera. Yaw + = the vehicle
## is turned to the right (its right flank becomes visible), radians unless the name says _deg.


## Display yaw (radians) of an ortho sprite that is rotated about its rear centre (contract §2):
##   sin psi = (d_r * tan(h + psi_c) - x_r) / (d_r + L), limited to ±limit_deg.
## d_r = depth of the rear centre, x_r = its lateral offset from the camera axis including the road offset,
## h = road heading relative to the camera axis (chord from the rear to the front of the vehicle),
## psi_c = own heading relative to the road (lane change), length = vehicle length L.
## The rear sits exactly at its projected point; with this yaw the front of the sprite (measured at the scale
## of the rear) lands where the true perspective shows it.
static func ortho_yaw(d_r: float, x_r: float, h: float, psi_c: float, length: float, limit_deg: float = 30.0) -> float:
	var d := maxf(d_r, 0.05)
	var lim := sin(deg_to_rad(limit_deg))
	return asin(clampf((d * tan(h + psi_c) - x_r) / (d + maxf(length, 0.0)), -lim, lim))


## Road heading h for ortho_yaw: the chord of the road centre from the rear (lateral offset xr_road) to the
## front (xf_road, one vehicle length further) – exact for a constant curve over the vehicle's length.
static func chord_heading(xr_road: float, xf_road: float, length: float) -> float:
	return atan((xf_road - xr_road) / maxf(length, 0.5))


## The old point formula (road heading minus view ray, no vehicle length) – kept for comparison in tests.
static func point_yaw(d_r: float, x_r: float, h: float) -> float:
	return h - atan2(x_r, maxf(d_r, 0.05))


## Own heading of a vehicle relative to the road (radians) from its lateral and longitudinal speed (m/s).
static func own_heading(lateral_mps: float, speed_mps: float) -> float:
	if speed_mps < 1.0:
		return 0.0
	return atan(lateral_mps / speed_mps)


## Screen x of the front centre of a rear-pivot ortho sprite (rear anchor at sx_r, scale s_r px/m).
static func ortho_front_x(sx_r: float, s_r: float, length: float, psi: float) -> float:
	return sx_r + length * sin(psi) * s_r


## One step of a critically damped follower with time constant tau (exact for a constant target, stable for
## any dt). Returns Vector2(value, velocity).
static func damp(value: float, velocity: float, target: float, dt: float, tau: float) -> Vector2:
	if tau <= 0.0:
		return Vector2(target, 0.0)
	if dt <= 0.0:
		return Vector2(value, velocity)
	var w := 1.0 / tau
	var x0 := value - target
	var c := (velocity + w * x0) * dt
	var e := exp(-w * dt)
	return Vector2(target + (x0 + c) * e, (velocity - w * c) * e)


## Cell for yaw_deg given the cell shown so far (-1 = none): the nearest cell, but the current one stays until
## another cell is closer by more than `hysteresis` steps (step = spacing of the two cells per index; contract
## §2: 0.3 steps). Yaw lists are ordered (left … right), as in the manifest.
static func pick_cell(yaws: PackedFloat32Array, yaw_deg: float, current: int, hysteresis: float = 0.3) -> int:
	var n := yaws.size()
	var best := -1
	var best_d := INF
	if current >= 0 and current < n:
		# ordered list: walk from the current cell towards the yaw (usually 0 or 1 step)
		best = current
		best_d = absf(yaws[current] - yaw_deg)
		var step := 1 if yaw_deg > yaws[current] else -1
		while best + step >= 0 and best + step < n and absf(yaws[best + step] - yaw_deg) < best_d:
			best += step
			best_d = absf(yaws[best] - yaw_deg)
	else:
		for i in n:
			var d := absf(yaws[i] - yaw_deg)
			if d < best_d:
				best_d = d
				best = i
	if current < 0 or current >= n or best == current or best < 0:
		return best
	var step := absf(yaws[best] - yaws[current]) / float(absi(best - current))
	if absf(yaw_deg - yaws[current]) - best_d > hysteresis * step:
		return best
	return current


## Target of the visible yaw of the player car (radians, before smoothing) – the sum of
##   curve look-ahead: road heading some metres ahead of the car relative to the camera axis (* curve_gain)
##   steering: steer (-1..1) * steer_deg
##   lane change: own heading from the steering lateral speed (* lateral_gain)
##   understeer: understeer (0..1) * understeer_deg, nose into the curve (curve_sign = sign of the bend)
##   view angle: minus view_gain * atan(lateral offset from the camera axis / depth) – the sprite is rendered
##   straight in front of the camera; a car beside the axis is seen slightly from the side.
## k: {curve_gain, steer_deg, lateral_gain, understeer_deg, view_gain, max_deg}
static func player_yaw_target(curve_heading: float, steer: float, lat_mps: float, speed_mps: float, understeer: float, curve_sign: float, view_angle: float, k: Dictionary) -> float:
	var yaw := curve_heading * float(k.get("curve_gain", 1.0))
	yaw += deg_to_rad(float(k.get("steer_deg", 3.0))) * clampf(steer, -1.0, 1.0)
	yaw += own_heading(lat_mps, speed_mps) * float(k.get("lateral_gain", 1.0))
	yaw += deg_to_rad(float(k.get("understeer_deg", 4.0))) * clampf(understeer, 0.0, 1.0) * signf(curve_sign)
	yaw -= view_angle * float(k.get("view_gain", 1.0))
	var lim := deg_to_rad(float(k.get("max_deg", 20.0)))
	return clampf(yaw, -lim, lim)


## Body roll of the player car (degrees, screen rotation, + = clockwise) from the lateral acceleration a_lat
## (m/s², + = towards the right): the body leans out of the curve, at most ±max_deg.
static func roll_target_deg(a_lat: float, deg_per_mps2: float, max_deg: float) -> float:
	return -clampf(a_lat * deg_per_mps2, -absf(max_deg), absf(max_deg))


## Perspective warp of a rear-pivot ortho sprite (docs/renn-modul.md §8): the rotated ortho sprite draws its
## front at the scale of the rear, so a car beside the camera looks too big and seems to cut across the lanes.
## The cell is cut into vertical strips; each strip edge is mapped to the point of the car it shows and drawn
## where the road projection puts that point, at that point's own scale.
## Columns as triples (sprite x in metres from the anchor, lateral s from the rear centre, distance t from the
## rear), ordered left to right: the rear face (t = 0, s = x / cos psi), the visible flank (s = ±width/2,
## t = 0 … length in n strips) and the space beyond the front corner (t = length). psi = yaw of the drawn cell
## (radians, + = turned right, right flank visible); x_left/x_right = cell edges in metres from the anchor.
## Empty when psi is too small to show a flank.
static func warp_columns(psi: float, width: float, length: float, x_left: float, x_right: float, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var sn := sin(psi)
	if absf(sn) < 0.005 or length <= 0.0 or x_right <= x_left:
		return out
	var c := cos(psi)
	var hw := width * 0.5
	var steps := maxi(1, n)
	if psi > 0.0:
		var corner := clampf(hw * c, x_left, x_right)
		var front := clampf(hw * c + length * sn, corner, x_right)
		if corner > x_left:
			out.append_array([x_left, x_left / c, 0.0])
		for i in steps + 1:
			var t := length * float(i) / float(steps)
			out.append_array([minf(hw * c + t * sn, x_right), hw, t])
		if x_right > front + 0.001:
			out.append_array([x_right, hw + (x_right - front) / c, length])
	else:
		var corner := clampf(-hw * c, x_left, x_right)
		var front := clampf(-hw * c + length * sn, x_left, corner)
		if x_left < front - 0.001:
			out.append_array([x_left, -hw - (front - x_left) / c, length])
		for i in range(steps, -1, -1):
			var t := length * float(i) / float(steps)
			out.append_array([maxf(-hw * c + t * sn, x_left), -hw, t])
		if corner < x_right:
			out.append_array([x_right, x_right / c, 0.0])
	return out


## Screen geometry of the warp columns: per column [x (metres from the anchor, as given), screen x, screen y of
## the cell top, screen y of the cell bottom]. road(z) -> Vector3(road centre x, road height relative to the
## camera, depth) as RoadRenderer.road_at; z_rear = world z of the rear, x = lateral position on the road,
## tan_c = tan(own heading relative to the road), v_top/v_bot = cell top/bottom in metres above the anchor,
## elev = elevation of the ortho render camera (radians): in the sprite a ground point of the car at depth
## offset dz appears dz * sin(elev) above the anchor; a pixel keeps its height above that local ground.
static func warp_screen(cols: PackedFloat32Array, psi: float, z_rear: float, x: float, tan_c: float, road: Callable,
		focal: float, half_w: float, horizon_y: float, near: float, v_top: float, v_bot: float, elev: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var sp := sin(psi)
	var cp := cos(psi)
	var se := sin(elev)
	for i in range(0, cols.size() - 2, 3):
		var s := cols[i + 1]
		var t := cols[i + 2]
		var ra: Vector3 = road.call(z_rear + t)
		var kpx := focal / maxf(ra.z, near)
		var sx := half_w + (ra.x + x + t * tan_c + s) * kpx
		var gy := horizon_y - ra.y * kpx
		var vg := (t * cp - s * sp) * se
		out.append_array([cols[i], sx, gy - (v_top - vg) * kpx, gy - (v_bot - vg) * kpx])
	return out


## Scale (game px per cell px) of a perspective sprite cell: distance_m of its render camera / actual depth of
## the vehicle centre / supersample (contract §3).
static func perspective_scale(camera_distance_m: float, depth: float, supersample: float) -> float:
	return camera_distance_m / maxf(depth, 0.01) / maxf(supersample, 0.01)
