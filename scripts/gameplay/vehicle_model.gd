class_name VehicleModel
extends RefCounted
## Arcade driving model of the player car – pure logic (no nodes, no autoloads).
## Owner: gameplay module. Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
##
## Rules (design document "Fahrzeug und Steuerung", "Kollisionen"):
##  * the car follows the road; the player only steers sideways (x)
##  * max speed = vmax_kmh * env.vmax_factor (weather/night) * grade factor (uphill lowers it)
##  * no oversteer, no spin: too fast in a curve -> understeer: pushed outwards proportional to the
##    overshoot of the safe curve speed, and steering gets weaker
##  * collision: slow down to collision.target_speed_kmh within collision.slowdown_s while being pushed
##    sideways; end point collision.push_extra_s after reaching that speed; only then accelerate again;
##    invulnerable + blinking during slowdown and push
## STUB: simplified behaviour – the gameplay module replaces the internals.

enum State { DRIVING, CRASH, AUTO }

signal crash_started(push_dir: int)
signal crash_finished

var cfg: Dictionary = {}
var spec: Dictionary = {}        ## resolved vehicle spec, see resolve_spec()
var type_id := ""
var speed := 0.0                 ## km/h
var x := 0.0                     ## lateral position of the car centre (m), 0 = road centre, + = right
var state: int = State.DRIVING
var invulnerable := false
var blink_visible := true        ## false during the "off" phase of blinking
var steer_visual := 0.0          ## -1..1 smoothed steering (sprite selection)
var braking := false             ## brake lights on
var understeer := 0.0            ## 0..1 current understeer intensity (HUD/audio)
var off_road := 0                ## 0 = road, 1 = shoulder, 2 = guardrail contact this frame
var vmax_effective := 0.0        ## current max speed after all modifiers
var length_m := 4.6
var width_m := 1.85

var _auto_target := 0.0
var _auto_rate := 40.0
var _auto_steer_x := NAN
var _crash_t := 0.0
var _crash_v0 := 0.0
var _crash_x0 := 0.0
var _crash_dir := 0
var _blink_t := 0.0


func setup(config: Dictionary, vehicle_id: String) -> void:
	cfg = config
	spec = resolve_spec(config, vehicle_id)
	type_id = str(spec.get("id", vehicle_id))
	length_m = float(spec.get("length_m", 4.6))
	width_m = float(spec.get("width_m", 1.85))
	speed = 0.0
	x = 0.0
	state = State.DRIVING
	invulnerable = false
	blink_visible = true
	vmax_effective = float(spec.get("vmax_kmh", 245.0))


## Vehicle type from config "vehicles.types.<id>" plus derived values from the 1–5 ratings:
## t100_s, t200_s, steer_mps, lat_grip, consumption_factor, id.
static func resolve_spec(config: Dictionary, vehicle_id: String) -> Dictionary:
	var types: Dictionary = ConfigLoader.lookup(config, "vehicles.types", {})
	var id := vehicle_id
	if not types.has(id):
		id = str(ConfigLoader.lookup(config, "vehicles.default", "limousine"))
	var s: Dictionary = types.get(id, {}).duplicate(true)
	s["id"] = id
	var acc: Dictionary = ConfigLoader.lookup(config, "vehicles.accel_ratings.%d" % int(s.get("accel", 3)), {})
	var agi: Dictionary = ConfigLoader.lookup(config, "vehicles.agility_ratings.%d" % int(s.get("agility", 3)), {})
	s["t100_s"] = float(acc.get("t100_s", 5.6))
	s["t200_s"] = float(acc.get("t200_s", 14.5))
	s["steer_mps"] = float(agi.get("steer_mps", 8.5))
	s["lat_grip"] = float(agi.get("lat_grip", 9.0))
	s["consumption_factor"] = float(ConfigLoader.lookup(config, "vehicles.consumption_factors." + str(s.get("consumption", "mittel")), 1.0))
	return s


## input: {steer: -1..1, throttle: 0..1, brake: 0..1}
## road:  {curve: -1..1 (+ = right bend), grade: rise/run (+ = uphill), left_edge, right_edge (paved
##         edges in m, right edge includes an open fuel lane), shoulder_m, guardrail: bool, grip: 0..1}
## env:   {vmax_factor: weather/night factor}
func update(dt: float, input: Dictionary, road: Dictionary, env: Dictionary) -> void:
	vmax_effective = max_speed(float(road.get("grade", 0.0)), float(env.get("vmax_factor", 1.0)))
	off_road = 0
	match state:
		State.DRIVING:
			_update_driving(dt, input, road)
		State.CRASH:
			_update_crash(dt)
		State.AUTO:
			_update_auto(dt)
	_apply_road_limits(dt, road)


func _update_driving(dt: float, input: Dictionary, road: Dictionary) -> void:
	var throttle := float(input.get("throttle", 0.0))
	var brake := float(input.get("brake", 0.0))
	braking = brake > 0.05
	var vmax := vmax_effective
	if brake > 0.0:
		speed -= float(ConfigLoader.lookup(cfg, "driving.brake_decel_kmh_s", 70.0)) * brake * dt
	elif throttle > 0.0 and speed < vmax:
		var a0 := 125.0 / float(spec.get("t100_s", 5.6))
		speed += a0 * maxf(0.05, 1.0 - speed / maxf(vmax, 1.0)) * throttle * dt
		speed = minf(speed, vmax)
	else:
		speed -= float(ConfigLoader.lookup(cfg, "driving.coast_decel_kmh_s", 5.0)) * dt
	if speed > vmax:
		speed = maxf(vmax, speed - 30.0 * dt)
	speed = maxf(speed, 0.0)

	var steer := clampf(float(input.get("steer", 0.0)), -1.0, 1.0)
	var curve := float(road.get("curve", 0.0))
	var safe := safe_curve_speed(curve, float(road.get("grip", 1.0)))
	var excess := 0.0 if is_inf(safe) else maxf(0.0, (speed - safe) / maxf(safe, 1.0))
	understeer = clampf(excess, 0.0, 1.0)
	var steer_factor := maxf(float(ConfigLoader.lookup(cfg, "driving.understeer.min_steer_factor", 0.25)),
		1.0 - excess * float(ConfigLoader.lookup(cfg, "driving.understeer.steer_loss_per_excess", 1.6)))
	var speed_factor := clampf(speed / float(ConfigLoader.lookup(cfg, "driving.steer_full_speed_kmh", 60.0)), 0.0, 1.0)
	x += steer * float(spec.get("steer_mps", 8.5)) * steer_factor * speed_factor * dt
	x += signf(curve) * excess * float(ConfigLoader.lookup(cfg, "driving.understeer.push_mps_per_excess", 14.0)) * dt
	steer_visual = move_toward(steer_visual, steer, dt / 0.15)


func _update_crash(dt: float) -> void:
	var slow_s := float(ConfigLoader.lookup(cfg, "collision.slowdown_s", 3.0))
	var extra_s := float(ConfigLoader.lookup(cfg, "collision.push_extra_s", 0.4))
	var target := float(ConfigLoader.lookup(cfg, "collision.target_speed_kmh", 10.0))
	var push := float(ConfigLoader.lookup(cfg, "collision.push_distance_m", 3.0))
	_crash_t += dt
	var t := clampf(_crash_t / slow_s, 0.0, 1.0)
	speed = lerpf(_crash_v0, target, t)
	var tp := clampf(_crash_t / (slow_s + extra_s), 0.0, 1.0)
	x = _crash_x0 + _crash_dir * push * (1.0 - pow(1.0 - tp, 2.0))
	_blink_t += dt
	blink_visible = fmod(_blink_t * float(ConfigLoader.lookup(cfg, "collision.blink_hz", 8.0)), 1.0) < 0.5
	braking = true
	if _crash_t >= slow_s + extra_s:
		state = State.DRIVING
		invulnerable = false
		blink_visible = true
		crash_finished.emit()


func _update_auto(dt: float) -> void:
	braking = speed > _auto_target + 0.5
	speed = move_toward(speed, _auto_target, _auto_rate * dt)
	if not is_nan(_auto_steer_x):
		x = move_toward(x, _auto_steer_x, 2.0 * dt)
	steer_visual = move_toward(steer_visual, 0.0, dt / 0.15)


func _apply_road_limits(dt: float, road: Dictionary) -> void:
	var half := width_m * 0.5
	var shoulder := float(road.get("shoulder_m", 2.5))
	var left := float(road.get("left_edge", -5.6))
	var right := float(road.get("right_edge", 5.6))
	if x - half < left or x + half > right:
		off_road = 1
		var vmax_sh := float(ConfigLoader.lookup(cfg, "driving.shoulder.max_speed_kmh", 90.0))
		if speed > vmax_sh:
			speed = maxf(vmax_sh, speed - float(ConfigLoader.lookup(cfg, "driving.shoulder.decel_kmh_s", 35.0)) * dt)
	var min_x := left - shoulder + half
	var max_x := right + shoulder - half
	if x < min_x or x > max_x:
		off_road = 2
		x = clampf(x, min_x, max_x)


## Starts the collision sequence (ignored while invulnerable). space_left/right = free metres beside the
## car (road edges and other cars) – used when the hit is exactly from behind/in front.
func start_crash(other_x: float, space_left: float, space_right: float) -> void:
	if invulnerable:
		return
	var dx := x - other_x
	var centre := float(ConfigLoader.lookup(cfg, "collision.center_hit_fraction", 0.25)) * width_m
	if absf(dx) > centre:
		_crash_dir = 1 if dx > 0.0 else -1
	else:
		_crash_dir = 1 if space_right > space_left else -1
	state = State.CRASH
	invulnerable = true
	_crash_t = 0.0
	_blink_t = 0.0
	_crash_v0 = speed
	_crash_x0 = x
	crash_started.emit(_crash_dir)


## Scripted control (refuelling stop, police stop, towing): move speed to target_kmh at rate_kmh_s,
## optionally steer towards steer_x. Player input is ignored until release_auto().
func auto_control(target_kmh: float, rate_kmh_s: float, steer_x: float = NAN) -> void:
	if state == State.CRASH:
		return
	state = State.AUTO
	_auto_target = target_kmh
	_auto_rate = rate_kmh_s
	_auto_steer_x = steer_x


func release_auto() -> void:
	if state == State.AUTO:
		state = State.DRIVING


func is_controllable() -> bool:
	return state == State.DRIVING


## Speed (km/h) above which the car understeers in a curve of the given strength (-1..1).
func safe_curve_speed(curve: float, grip: float = 1.0) -> float:
	var c := absf(curve)
	if c < 0.0001:
		return INF
	var radius := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)) / c
	return sqrt(float(spec.get("lat_grip", 9.0)) * grip * radius) * 3.6


## Max speed for the current grade (rise/run) and weather/night factor.
func max_speed(grade: float, vmax_factor: float) -> float:
	var loss := maxf(0.0, grade * 100.0) * float(ConfigLoader.lookup(cfg, "driving.grade_vmax_loss_per_percent", 0.012))
	return float(spec.get("vmax_kmh", 245.0)) * vmax_factor * maxf(0.5, 1.0 - loss)
