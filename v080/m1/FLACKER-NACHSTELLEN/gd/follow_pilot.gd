extends Autopilot
## FLACKER-NACHSTELLEN (scratch, not part of the game): a driver that behaves like a player following a car.
## On top of the frozen Autopilot (lane keeping, curves, radar) it picks a traffic car ahead – a preferred set first
## (e.g. "_white" model cars), else the nearest car ahead in its lane – and keeps a bumper gap that sweeps slowly
## between gap_lo and gap_hi (period gap_period_s) with a small quick wobble (a human's throttle), and steers towards
## that car's x with a small sine on top ("steers a little"). Loaded at run time (load(<abs path>)), never preloaded.

var gap_lo := 18.0
var gap_hi := 70.0
var gap_period_s := 36.0
var wobble_m := 2.5
var wobble_period_s := 3.3
var wiggle := 0.10              ## steering amplitude added (of full lock)
var wiggle_period_s := 2.6
var prefer := ""                ## substring of the set id to prefer ("" = any)
var models_only := true         ## only cars whose set has a 3D model (needs model_sets)
var model_sets: Dictionary = {} ## set id -> true
var target_id := -1
var target_set := ""
var gap_now := -1.0
var gap_want := -1.0
var steer_extra := 0.0
var _t := 0.0
var _lost_t := 0.0


func drive(session: Node) -> Dictionary:
	var out: Dictionary = super.drive(session)
	var dt := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	_t += dt
	var traffic: TrafficSystem = session.traffic
	var v: VehicleModel = session.vehicle
	var track: Track = session.track
	var z: float = session.pos_z
	var fuel: FuelSystem = session.fuel
	if fuel.state != FuelSystem.State.NORMAL:
		return out
	var target: TrafficSystem.Car = null
	for c: TrafficSystem.Car in traffic.cars:
		if c.id == target_id:
			target = c
			break
	var front := z + v.length_m * 0.5
	if target != null:
		var g := target.z - target.length * 0.5 - front
		if g < 5.0 or g > 220.0:
			target = null
	if target == null:
		target = _pick(traffic, track, z, front, v.x)
		target_id = target.id if target != null else -1
		target_set = target.set_id if target != null else ""
	if target == null:
		gap_now = -1.0
		return out
	var gap := target.z - target.length * 0.5 - front
	gap_now = gap
	var phase := 0.5 + 0.5 * sin(TAU * _t / gap_period_s)
	gap_want = lerpf(gap_lo, gap_hi, phase) + wobble_m * sin(TAU * _t / wobble_period_s)
	var want := target.speed + clampf((gap - gap_want) * 1.5, -40.0, 40.0)
	# the base driver's limits (curves, radar, lane end) still hold
	want = minf(want, last_want)
	var p := pedals(v.speed, want)
	out["throttle"] = p["throttle"]
	out["brake"] = p["brake"]
	var grip: float = session.env.grip(session.weather)
	steer_extra = wiggle * sin(TAU * _t / wiggle_period_s)
	out["steer"] = clampf(steer_to(v, target.x, grip) + steer_extra, -1.0, 1.0)
	last_reason = "follow %d %s %.0fm" % [target.id, target.set_id, gap]
	return out


func _pick(traffic: TrafficSystem, track: Track, z: float, front: float, x: float) -> TrafficSystem.Car:
	var best: TrafficSystem.Car = null
	var best_d := INF
	var pref: TrafficSystem.Car = null
	var pref_d := INF
	for c: TrafficSystem.Car in traffic.cars:
		var g := c.z - c.length * 0.5 - front
		if g < 8.0 or g > 200.0 or c.heavy:
			continue
		if models_only and not model_sets.is_empty() and not model_sets.has(c.set_id):
			continue
		if prefer != "" and c.set_id.contains(prefer) and g < pref_d:
			pref = c
			pref_d = g
		if absf(c.x - x) < 1.8 and g < best_d:
			best = c
			best_d = g
	return pref if pref != null else best
