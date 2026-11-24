class_name VehicleModel
extends RefCounted
## Arcade driving model of the player car – pure logic (no nodes, no autoloads).
## Owner: gameplay module. Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
## Rules, decisions and tuning numbers: docs/gameplay.md.
##
## Rules (design document "Fahrzeug und Steuerung", "Kollisionen"):
##  * the car follows the road; the player only steers sideways (x is road-relative)
##  * acceleration curve dv/dt = a0 * (1 - v/vmax)^(1-q); a0 and q are fitted per vehicle so that the
##    0–100 / 0–200 km/h times of its accel rating are met; integrated analytically (frame-rate independent),
##    vmax is reached in finite time (q > 0)
##  * max speed = vmax_kmh * env.vmax_factor (weather/night) * grade factor. Only climbs steeper than
##    driving.grade_free_percent lower it (driving.grade_vmax_loss_per_percent per % above that), so that
##    the slowest car (230) still reaches the 220 km/h police escape speed in "slightly worse conditions"
##    (rain + night on normal hilly roads up to hills level 2, i.e. <= 4.5 %); downhill never raises it
##  * steering: lateral speed from the agility rating, ramps up with speed, smoothed response
##  * weather (road "grip" g: tyre grip of the surface, driving.weather_grip_factor, dry 1.0 inside tunnels)
##    limits every control, each with its own sensitivity (driving.grip_effects, docs/gameplay.md "Wetter"):
##    curves use the curve grip g^curve_exp, braking driving.brake_decel_kmh_s · g^brake_exp (snow about half),
##    acceleration at most traction_mps2 · g^traction_exp (snow: traction-limited at low speed), steering
##    builds the lateral speed with the response time steer_response_s / g^steer_response_exp and keeps sliding
##    after the input ends (counter-steering stops it sooner), up to steer_mps · g^steer_speed_exp. Never
##    oversteer or spin
##  * no oversteer, no spin: too fast in a curve -> understeer. The curve needs the lateral acceleration
##    a_req = v^2 / R (R = road.curve_radius_at_1_m / |curve|), the tyres give a_grip = lat_grip (agility)
##    * curve grip (weather). Below that limit the car follows the road without any drift. Above it the excess
##    a_ex = a_req - a_grip accelerates an outward drift (push_speed, driving.understeer.push_gain * a_ex),
##    steering towards the inside loses effect with the excess (saturated front tyres: counter-steering
##    helps when slightly too fast, not when clearly too fast) and the sliding tyres scrub speed
##    (scrub_per_excess * a_ex, at most scrub_max_mps2). Back below the limit the drift decays quickly
##    (recover_s). Lifting or braking is the remedy
##  * road edge: the shoulder (Bankett) slows to driving.shoulder.max_speed_kmh and has only
##    driving.shoulder.grip_factor of the grip; hard limit at edge + shoulder (stops the drift): guardrail
##    (hit: speed factor + bounce, a drift into it costs more, rail_hit_factor; scraping only while steering or
##    the drift push the car into it – a car standing at it always drives off) or, without guardrail,
##    grass (stronger slowdown). So sliding wide never beats braking for the curve
##  * collision: slow down to collision.target_speed_kmh within collision.slowdown_s while being pushed
##    sideways; end point collision.push_extra_s after reaching that speed; only then accelerate again;
##    invulnerable + blinking during slowdown and push (+ collision.invulnerable_grace_s afterwards)

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
var off_road := 0                ## 0 = road, 1 = shoulder, 2 = hard limit (guardrail contact or grass)
var vmax_effective := 0.0        ## current max speed after all modifiers
var length_m := 4.6
var width_m := 1.85

# --- additions to the documented API (docs/gameplay.md) ---
var lat_speed := 0.0             ## lateral speed from steering (m/s, + = right), without understeer push
var push_speed := 0.0            ## understeer drift relative to the road (m/s, + = right), see _steer()
var lat_excess := 0.0            ## lateral acceleration the tyres cannot give (m/s², 0 below the limit)
var on_grass := false            ## at the hard limit of a road without guardrail (grass)
var rail_contact := false        ## touching the guardrail this frame
var rail_hit := false            ## a new guardrail hit (speed factor + bounce) happened this frame
var rail_impact := 0.0           ## understeer drift (m/s) that hit the guardrail at the last rail_hit
var crash_dir := 0               ## push direction of the running/last collision: -1 left, +1 right
var crash_time := 0.0            ## seconds since the running collision started
var grace_left := 0.0            ## remaining invulnerability after the collision end point (s)
var accel_a0 := 30.0             ## fitted acceleration at standstill (km/h per s)
var accel_q := 0.5               ## fitted curve exponent: dv/dt = a0 * (1 - v/vmax)^(1-q)

# vehicle values
var _vmax := 245.0
var _steer_mps := 8.5
var _lat_grip := 9.0
# cached configuration (read in setup)
var _brake_decel := 70.0
var _coast_decel := 5.0
var _over_decel := 12.0
var _steer_full := 60.0
var _steer_tau := 0.12
var _us_gain := 2.5
var _us_loss := 3.0
var _us_min := 0.15
var _us_full := 0.5
var _us_recover := 0.25
var _us_scrub := 0.5
var _us_scrub_max := 3.0
var _grade_loss := 0.012
var _grade_free := 4.0
var _grade_min := 0.5
var _sh_max := 90.0
var _sh_decel := 35.0
var _sh_tol := 0.5
var _sh_grip := 0.6
var _rail_factor := 0.9
var _rail_bounce := 1.5
var _rail_cooldown := 0.6
var _rail_scrape := 20.0
var _rail_free := 1.0
var _rail_loss := 0.05
var _rail_min := 0.5
var _grass_max := 40.0
var _grass_decel := 60.0
var _auto_steer := 3.0
var _radius_at_1 := 120.0
var _g_curve_exp := 1.0
var _g_brake_exp := 0.0
var _g_traction := 0.0           ## traction limit on a dry road (m/s², 0 = none)
var _g_traction_exp := 1.0
var _g_resp_exp := 0.0
var _g_speed_exp := 0.0
var _c_target := 10.0
var _c_slow := 3.0
var _c_extra := 0.4
var _c_push := 3.0
var _c_centre := 0.25
var _c_blink := 8.0
var _c_grace := 0.0
var _c_exp := 1.0
var _c_equal := 0.25
# runtime state
var _auto_target := 0.0
var _auto_rate := 40.0
var _auto_steer_x := NAN
var _crash_v0 := 0.0
var _crash_push_done := 0.0
var _blink_t := 0.0
var _rail_cd_left := 0.0
var _was_rail := false


func setup(config: Dictionary, vehicle_id: String) -> void:
	cfg = config
	spec = resolve_spec(config, vehicle_id)
	type_id = str(spec.get("id", vehicle_id))
	length_m = float(spec.get("length_m", 4.6))
	width_m = float(spec.get("width_m", 1.85))
	_vmax = float(spec.get("vmax_kmh", 245.0))
	_steer_mps = float(spec.get("steer_mps", 8.5))
	_lat_grip = float(spec.get("lat_grip", 9.0))
	accel_a0 = float(spec.get("accel_a0", 30.0))
	accel_q = float(spec.get("accel_q", 0.5))
	_read_config()
	reset()


## Back to standstill on the road centre, all effects cleared (setup() calls it).
func reset() -> void:
	speed = 0.0
	x = 0.0
	state = State.DRIVING
	invulnerable = false
	blink_visible = true
	steer_visual = 0.0
	braking = false
	understeer = 0.0
	off_road = 0
	on_grass = false
	rail_contact = false
	rail_hit = false
	rail_impact = 0.0
	lat_speed = 0.0
	push_speed = 0.0
	lat_excess = 0.0
	crash_dir = 0
	crash_time = 0.0
	grace_left = 0.0
	vmax_effective = _vmax
	_blink_t = 0.0
	_rail_cd_left = 0.0
	_was_rail = false
	_auto_steer_x = NAN


func _f(path: String, default: float) -> float:
	return float(ConfigLoader.lookup(cfg, path, default))


func _read_config() -> void:
	_brake_decel = _f("driving.brake_decel_kmh_s", 70.0)
	_coast_decel = _f("driving.coast_decel_kmh_s", 5.0)
	_over_decel = _f("driving.overspeed_decel_kmh_s", 12.0)
	_steer_full = maxf(1.0, _f("driving.steer_full_speed_kmh", 60.0))
	_steer_tau = maxf(0.001, _f("driving.steer_response_s", 0.12))
	_us_gain = maxf(0.0, _f("driving.understeer.push_gain", 2.5))
	_us_loss = maxf(0.0, _f("driving.understeer.steer_loss_per_excess", 3.0))
	_us_min = clampf(_f("driving.understeer.min_steer_factor", 0.15), 0.0, 1.0)
	_us_full = maxf(0.01, _f("driving.understeer.full_excess", 0.5))
	_us_recover = maxf(0.01, _f("driving.understeer.recover_s", 0.25))
	_us_scrub = maxf(0.0, _f("driving.understeer.scrub_per_excess", 0.5))
	_us_scrub_max = maxf(0.0, _f("driving.understeer.scrub_max_mps2", 3.0))
	_grade_loss = _f("driving.grade_vmax_loss_per_percent", 0.012)
	_grade_free = maxf(0.0, _f("driving.grade_free_percent", 4.0))
	_grade_min = _f("driving.grade_min_factor", 0.5)
	_sh_max = _f("driving.shoulder.max_speed_kmh", 90.0)
	_sh_decel = _f("driving.shoulder.decel_kmh_s", 35.0)
	_sh_tol = _f("driving.shoulder.tolerance_m", 0.5)
	_sh_grip = clampf(_f("driving.shoulder.grip_factor", 0.6), 0.05, 1.0)
	_rail_factor = _f("driving.guardrail.speed_factor_per_hit", 0.9)
	_rail_bounce = _f("driving.guardrail.bounce_mps", 1.5)
	_rail_cooldown = _f("driving.guardrail.hit_cooldown_s", 0.6)
	_rail_scrape = _f("driving.guardrail.scrape_decel_kmh_s", 20.0)
	_rail_free = maxf(0.0, _f("driving.guardrail.impact_free_mps", 1.0))
	_rail_loss = maxf(0.0, _f("driving.guardrail.impact_loss_per_mps", 0.05))
	_rail_min = clampf(_f("driving.guardrail.min_speed_factor", 0.5), 0.0, 1.0)
	_grass_max = _f("driving.grass.max_speed_kmh", 40.0)
	_grass_decel = _f("driving.grass.decel_kmh_s", 60.0)
	_auto_steer = _f("driving.auto_steer_mps", 3.0)
	_radius_at_1 = _f("road.curve_radius_at_1_m", 120.0)
	_g_curve_exp = maxf(0.0, _f("driving.grip_effects.curve_exp", 1.0))
	_g_brake_exp = maxf(0.0, _f("driving.grip_effects.brake_exp", 0.0))
	_g_traction = maxf(0.0, _f("driving.grip_effects.traction_mps2", 0.0))
	_g_traction_exp = maxf(0.0, _f("driving.grip_effects.traction_exp", 1.0))
	_g_resp_exp = maxf(0.0, _f("driving.grip_effects.steer_response_exp", 0.0))
	_g_speed_exp = maxf(0.0, _f("driving.grip_effects.steer_speed_exp", 0.0))
	_c_target = _f("collision.target_speed_kmh", 10.0)
	_c_slow = maxf(0.05, _f("collision.slowdown_s", 3.0))
	_c_extra = maxf(0.0, _f("collision.push_extra_s", 0.4))
	_c_push = _f("collision.push_distance_m", 3.0)
	_c_centre = _f("collision.center_hit_fraction", 0.25)
	_c_blink = _f("collision.blink_hz", 8.0)
	_c_grace = maxf(0.0, _f("collision.invulnerable_grace_s", 0.0))
	_c_exp = maxf(0.1, _f("collision.slowdown_exp", 1.0))
	_c_equal = _f("collision.equal_space_tolerance_m", 0.25)


## Vehicle type from config "vehicles.types.<id>" plus derived values from the 1–5 ratings:
## t100_s, t200_s, steer_mps, lat_grip, consumption_factor, id – and the fitted acceleration curve
## accel_a0 (km/h per s at standstill), accel_q, top_speed_time_s (0 -> vmax).
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
	var vmax := float(s.get("vmax_kmh", 245.0))
	var fit := fit_accel_curve(vmax, float(s["t100_s"]), float(s["t200_s"]))
	s["accel_a0"] = fit.x
	s["accel_q"] = fit.y
	s["top_speed_time_s"] = top_speed_time(vmax, fit.x, fit.y)
	return s


# --- Acceleration curve ---------------------------------------------------------------------

## Fits dv/dt = a0 * (1 - v/vmax)^(1-q) to the 0–100 and 0–200 km/h times. Returns Vector2(a0, q)
## (a0 in km/h per s). q is limited to [0.02, 1]: q > 0 keeps the time to vmax finite, q = 1 is
## constant acceleration. Without a solution in that range the 0–100 time is matched exactly.
static func fit_accel_curve(vmax: float, t100: float, t200: float) -> Vector2:
	var v1 := 100.0
	var v2 := 200.0
	var q := 0.5
	if vmax > v2 + 0.5 and t100 > 0.0 and t200 > t100:
		var target := t200 / t100
		var lo := 0.02
		var hi := 1.0
		if target >= _time_ratio(lo, vmax, v1, v2):
			q = lo
		elif target <= _time_ratio(hi, vmax, v1, v2):
			q = hi
		else:
			for i in 64:
				var mid := (lo + hi) * 0.5
				if _time_ratio(mid, vmax, v1, v2) > target:
					lo = mid
				else:
					hi = mid
			q = (lo + hi) * 0.5
	var u1 := clampf(v1 / maxf(vmax, 1.0), 0.0, 0.999)
	var a0 := maxf(vmax, 1.0) * (1.0 - pow(1.0 - u1, q)) / (q * maxf(t100, 0.1))
	return Vector2(a0, q)


## t(v2)/t(v1) of the curve with exponent q (decreasing in q).
static func _time_ratio(q: float, vmax: float, v1: float, v2: float) -> float:
	return (1.0 - pow(1.0 - v2 / vmax, q)) / (1.0 - pow(1.0 - v1 / vmax, q))


## Seconds to accelerate from standstill to v on the curve with top speed vtop.
static func curve_time(v: float, vtop: float, a0: float, q: float) -> float:
	if vtop <= 0.0 or a0 <= 0.0 or q <= 0.0:
		return 0.0
	var u := clampf(v / vtop, 0.0, 1.0)
	return vtop / (a0 * q) * (1.0 - pow(1.0 - u, q))


## Speed after t seconds of full throttle from standstill (inverse of curve_time).
static func curve_speed(t: float, vtop: float, a0: float, q: float) -> float:
	if vtop <= 0.0 or a0 <= 0.0 or q <= 0.0:
		return 0.0
	var t_top := top_speed_time(vtop, a0, q)
	if t >= t_top:
		return vtop
	return vtop * (1.0 - pow(1.0 - maxf(t, 0.0) / t_top, 1.0 / q))


## Seconds from standstill to the top speed vtop (finite for q > 0).
static func top_speed_time(vtop: float, a0: float, q: float) -> float:
	if a0 <= 0.0 or q <= 0.0:
		return INF
	return vtop / (a0 * q)


## Speed after t seconds of full throttle starting at v, with top speed vtop (this vehicle's curve). trac_kmh_s
## = traction limit of the road (km/h per s, traction_mps2(grip) · 3.6; INF = none): below the speed where the
## curve's acceleration drops to it (traction_crossover) the car gains exactly trac_kmh_s – integrated exactly.
func accelerate(v: float, vtop: float, t: float, trac_kmh_s: float = INF) -> float:
	if v >= vtop:
		return v
	if trac_kmh_s < INF:
		if trac_kmh_s <= 0.0:
			return v
		var vc := traction_crossover(vtop, trac_kmh_s)
		if v < vc:
			var tc := (vc - v) / trac_kmh_s
			if t <= tc:
				return v + trac_kmh_s * t
			v = vc
			t -= tc
	return curve_speed(curve_time(v, vtop, accel_a0, accel_q) + t, vtop, accel_a0, accel_q)


## Speed (km/h) below which a traction limit of trac_kmh_s caps this car's acceleration curve (top speed vtop):
## where a0 · (1 - v/vtop)^(1-q) = trac_kmh_s. 0 when the curve never exceeds the limit.
func traction_crossover(vtop: float, trac_kmh_s: float) -> float:
	if trac_kmh_s >= accel_a0:
		return 0.0
	if accel_q >= 0.999:
		return vtop
	return vtop * (1.0 - pow(maxf(trac_kmh_s, 0.0) / accel_a0, 1.0 / (1.0 - accel_q)))


## Seconds of full throttle from v_from to v_to on a flat road (top speed vtop, default = vmax_kmh).
func time_to_speed(v_from: float, v_to: float, vtop: float = -1.0) -> float:
	var top := _vmax if vtop <= 0.0 else vtop
	if v_to > top:
		return INF
	return maxf(0.0, curve_time(v_to, top, accel_a0, accel_q) - curve_time(v_from, top, accel_a0, accel_q))


# --- Per-frame update -----------------------------------------------------------------------

## input: {steer: -1..1, throttle: 0..1, brake: 0..1}
## road:  {curve: -1..1 (+ = right bend), grade: rise/run (+ = uphill), left_edge, right_edge (paved
##         edges in m, right edge includes an open fuel lane), shoulder_m, guardrail: bool, grip: 0..1}
## env:   {vmax_factor: weather/night factor}
func update(dt: float, input: Dictionary, road: Dictionary, env: Dictionary) -> void:
	if dt <= 0.0:
		return
	vmax_effective = max_speed(float(road.get("grade", 0.0)), float(env.get("vmax_factor", 1.0)))
	rail_hit = false
	match state:
		State.DRIVING:
			_update_driving(dt, input, road)
		State.CRASH:
			_update_crash(dt)
		State.AUTO:
			_update_auto(dt, input, road)
	_apply_road_limits(dt, road)
	_update_invulnerability(dt)


func _update_driving(dt: float, input: Dictionary, road: Dictionary) -> void:
	var throttle := clampf(float(input.get("throttle", 0.0)), 0.0, 1.0)
	var brake := clampf(float(input.get("brake", 0.0)), 0.0, 1.0)
	var g := float(road.get("grip", 1.0))
	braking = brake > 0.05
	if braking:
		speed = maxf(0.0, speed - brake_decel_mps2(g) * 3.6 * brake * dt)
	elif speed > vmax_effective:
		# above the current maximum (uphill, weather, after a bonus): settle down to it
		speed = maxf(vmax_effective, speed - maxf(_over_decel, _coast_decel) * dt)
	elif throttle > 0.0:
		speed = accelerate(speed, vmax_effective, dt * throttle, traction_mps2(g) * 3.6)
	else:
		speed = maxf(0.0, speed - _coast_decel * dt)
	_steer(dt, float(input.get("steer", 0.0)), road)


## Lateral movement: steering (ramped with speed, smoothed) plus the understeer drift in curves.
## Grip (docs/gameplay.md "Wetter"): on a slippery road the lateral speed follows the steering more slowly
## (steer_response_s(grip)) – it builds up late and keeps sliding once the input ends, steering the other way
## (counter-steer) stops it sooner – and reaches at most steer_speed_mps(grip).
## Understeer (docs/gameplay.md "Untersteuern"): the excess lateral acceleration a_ex = v²/R − a_grip
## accelerates the outward drift push_speed (push_gain · a_ex; + curve = right bend -> outside = left),
## steering towards the inside of the bend keeps max(min_steer_factor, 1 − steer_loss_per_excess · a_ex/a_grip)
## of its effect, and the sliding tyres scrub min(scrub_per_excess · a_ex, scrub_max_mps2) off the speed.
## On the shoulder (loose gravel, off_road of the last step) the grip is driving.shoulder.grip_factor lower.
## Below the limit the drift decays with recover_s. Integrated exactly per step (constant a_ex), so the
## drift does not depend on the frame rate.
func _steer(dt: float, steer_input: float, road: Dictionary) -> void:
	var steer := clampf(steer_input, -1.0, 1.0)
	var curve := float(road.get("curve", 0.0))
	var g_road := float(road.get("grip", 1.0))
	var grip := g_road * (_sh_grip if off_road >= 1 else 1.0)
	var a_grip := grip_accel(grip)
	lat_excess = lateral_excess(curve, grip, speed)
	var ratio := lat_excess / a_grip
	understeer = clampf(ratio / _us_full, 0.0, 1.0)
	# saturated front tyres: steering towards the inside of the bend loses effect, steering out does not
	var steer_factor := 1.0
	if ratio > 0.0 and steer * curve > 0.0:
		steer_factor = maxf(_us_min, 1.0 - ratio * _us_loss)
	var ramp := clampf(speed / _steer_full, 0.0, 1.0)
	var target := steer * steer_speed_mps(g_road) * ramp * steer_factor
	lat_speed = lerpf(lat_speed, target, 1.0 - exp(-dt / steer_response_s(g_road)))
	var dx := lat_speed * dt
	if lat_excess > 0.0:
		var a := -signf(curve) * _us_gain * lat_excess
		dx += push_speed * dt + 0.5 * a * dt * dt
		push_speed += a * dt
		speed = maxf(0.0, speed - minf(_us_scrub * lat_excess, _us_scrub_max) * 3.6 * dt)
	else:
		var k := exp(-dt / _us_recover)
		dx += push_speed * _us_recover * (1.0 - k)
		push_speed *= k
		if absf(push_speed) < 0.001:
			push_speed = 0.0
	x += dx
	steer_visual = move_toward(steer_visual, steer if speed > 2.0 else 0.0, dt / 0.15)


func _update_crash(dt: float) -> void:
	crash_time += dt
	var v_end := minf(_crash_v0, _c_target)
	if crash_time < _c_slow:
		speed = v_end + (_crash_v0 - v_end) * pow(1.0 - crash_time / _c_slow, _c_exp)
	else:
		speed = v_end
	var total := _c_slow + _c_extra
	var tp := clampf(crash_time / maxf(total, 0.001), 0.0, 1.0)
	var eased := 1.0 - (1.0 - tp) * (1.0 - tp)
	x += float(crash_dir) * _c_push * (eased - _crash_push_done)
	_crash_push_done = eased
	lat_speed = 0.0
	push_speed = 0.0
	lat_excess = 0.0
	understeer = 0.0
	braking = true
	steer_visual = move_toward(steer_visual, float(crash_dir) * 0.6 * (1.0 - tp), dt / 0.15)
	if crash_time >= total:
		state = State.DRIVING
		grace_left = _c_grace
		braking = false
		crash_finished.emit()


func _update_auto(dt: float, input: Dictionary, road: Dictionary) -> void:
	braking = speed > _auto_target + 0.5
	var rate := _auto_rate
	if is_nan(_auto_steer_x):
		# the player still steers – and may brake harder than the scripted rate (an empty tank or a police
		# stop does not disable the brakes: rolling out at 245 km/h towards a sharp curve, braking avoids the slide)
		var full := brake_decel_mps2(float(road.get("grip", 1.0))) * 3.6
		rate = maxf(rate, clampf(float(input.get("brake", 0.0)), 0.0, 1.0) * full)
	speed = maxf(0.0, move_toward(speed, _auto_target, rate * dt))
	if not is_nan(_auto_steer_x):
		x = move_toward(x, _auto_steer_x, _auto_steer * dt)
		lat_speed = 0.0
		push_speed = 0.0
		lat_excess = 0.0
		understeer = 0.0
		steer_visual = move_toward(steer_visual, 0.0, dt / 0.15)
	else:
		# speed is scripted, steering stays with the player (pull over, roll out)
		_steer(dt, float(input.get("steer", 0.0)), road)


## Shoulder slowdown and the hard limit at paved edge + shoulder (guardrail or grass).
func _apply_road_limits(dt: float, road: Dictionary) -> void:
	var half := width_m * 0.5
	var left := float(road.get("left_edge", -5.625))
	var right := float(road.get("right_edge", 5.625))
	var shoulder := maxf(0.0, float(road.get("shoulder_m", 2.5)))
	var rail := bool(road.get("guardrail", false))
	off_road = 0
	on_grass = false
	rail_contact = false
	var lim_l := left - shoulder + half
	var lim_r := right + shoulder - half
	if lim_l > lim_r:
		lim_l = (left + right) * 0.5
		lim_r = lim_l
	var side := 0
	if x <= lim_l + 0.0005:
		x = lim_l
		side = -1
	elif x >= lim_r - 0.0005:
		x = lim_r
		side = 1
	var over := maxf((x + half) - right, left - (x - half))
	if over > _sh_tol:
		off_road = 1
		if speed > _sh_max:
			speed = maxf(_sh_max, speed - _sh_decel * dt)
	_rail_cd_left = maxf(0.0, _rail_cd_left - dt)
	if side != 0:
		off_road = 2
		# the car presses against the limit only while the steering or the understeer drift pushes it there
		var pressing := lat_speed * float(side) > 0.0 or push_speed * float(side) > 0.0
		if lat_speed * float(side) > 0.0:
			lat_speed = 0.0
		var drift_in := maxf(0.0, push_speed * float(side))
		if drift_in > 0.0:
			push_speed = 0.0   # the guardrail / the end of the shoulder stops the drift
		if rail:
			rail_contact = true
			if not _was_rail and _rail_cd_left <= 0.0:
				speed *= rail_hit_factor(drift_in)
				rail_impact = drift_in
				lat_speed = -float(side) * _rail_bounce
				_rail_cd_left = _rail_cooldown
				rail_hit = true
			elif pressing:
				# scraping costs speed only while the car is pushed into the rail: a car that merely touches it
				# (e.g. pushed there by a collision, or stopped there) drives off – in snow the traction limit
				# (11.9 km/h/s) is below the scrape, the car would stay pinned at 0 km/h forever
				speed = maxf(0.0, speed - _rail_scrape * dt)
		else:
			on_grass = true
			if speed > _grass_max:
				speed = maxf(_grass_max, speed - _grass_decel * dt)
	_was_rail = rail_contact


func _update_invulnerability(dt: float) -> void:
	if state == State.CRASH:
		invulnerable = true
	elif grace_left > 0.0:
		grace_left = maxf(0.0, grace_left - dt)
		invulnerable = grace_left > 0.0
	else:
		invulnerable = false
	if invulnerable:
		_blink_t += dt
		blink_visible = fmod(_blink_t * _c_blink, 1.0) >= 0.5
	else:
		_blink_t = 0.0
		blink_visible = true


## Starts the collision sequence (ignored while invulnerable). space_left/right = free metres beside the
## car (road edges and other cars) – used when the hit is exactly from behind/in front.
## Push direction: away from the side of the hit car; centre hit (|dx| <= center_hit_fraction * width) ->
## the side with more space; (about) equal space -> left, because the fuel stations are on the right.
func start_crash(other_x: float, space_left: float, space_right: float) -> void:
	if invulnerable:
		return
	crash_dir = push_direction(x - other_x, space_left, space_right)
	state = State.CRASH
	invulnerable = true
	crash_time = 0.0
	grace_left = 0.0
	_blink_t = 0.0
	_crash_v0 = speed
	_crash_push_done = 0.0
	lat_speed = 0.0
	crash_started.emit(crash_dir)


## Push direction (-1 left, +1 right) for a hit with lateral offset dx = player.x - other.x.
func push_direction(dx: float, space_left: float, space_right: float) -> int:
	if absf(dx) > _c_centre * width_m:
		return 1 if dx > 0.0 else -1
	return 1 if space_right > space_left + _c_equal else -1


## Scripted control (refuelling stop, police stop, towing): move speed to target_kmh at rate_kmh_s.
## With steer_x the car is steered there; without it (NAN) the player keeps steering and may brake harder
## than rate_kmh_s (input "brake" × driving.brake_decel_kmh_s, e.g. before a curve while rolling out with an
## empty tank). Throttle is ignored until release_auto(). Ignored during a collision. Safe to call every frame.
func auto_control(target_kmh: float, rate_kmh_s: float, steer_x: float = NAN) -> void:
	if state == State.CRASH:
		return
	state = State.AUTO
	_auto_target = maxf(0.0, target_kmh)
	_auto_rate = rate_kmh_s if rate_kmh_s > 0.0 else 40.0
	_auto_steer_x = steer_x


func release_auto() -> void:
	if state == State.AUTO:
		state = State.DRIVING


func is_controllable() -> bool:
	return state == State.DRIVING


## Speed (km/h) above which the car understeers in a curve of the given strength (-1..1).
## Lateral acceleration limit = lat_grip (agility) * curve_grip(grip); radius = road.curve_radius_at_1_m / |curve|.
func safe_curve_speed(curve: float, grip: float = 1.0) -> float:
	var c := absf(curve)
	if c < 0.0001:
		return INF
	var radius := _radius_at_1 / c
	return sqrt(maxf(0.0, _lat_grip * curve_grip(grip) * radius)) * 3.6


## Speed factor of a guardrail hit: a touch (steering, scraping) keeps driving.guardrail.speed_factor_per_hit;
## an understeer slide hits it unbraked – every m/s of drift above impact_free_mps costs impact_loss_per_mps
## more, down to min_speed_factor. So sliding into the rail costs more than braking for the curve would have.
func rail_hit_factor(drift_mps: float) -> float:
	var f := _rail_factor - _rail_loss * maxf(0.0, drift_mps - _rail_free)
	return clampf(f, minf(_rail_min, _rail_factor), _rail_factor)


## Lateral acceleration (m/s²) the tyres can give in a curve: lat_grip of the agility rating * curve_grip(grip).
func grip_accel(grip: float = 1.0) -> float:
	return maxf(0.01, _lat_grip * curve_grip(grip))


# --- Grip effects (docs/gameplay.md "Wetter"). One tyre grip g per surface: the weather
# --- (driving.weather_grip_factor; dry 1.0 inside tunnels, Track.grip_at), for the curve limit also times
# --- driving.shoulder.grip_factor on the loose shoulder. Every control has its own sensitivity
# --- (driving.grip_effects); g = 1 (dry) changes nothing.

## Share of the dry curve grip (lat_grip) left at tyre grip g: g^curve_exp (snow 0.45 -> 0.55, rain 0.75 -> 0.81).
## Arcade: the dry curve limit is already low, so it falls less than the grip itself.
func curve_grip(grip: float) -> float:
	return pow(clampf(grip, 0.0001, 1.0), _g_curve_exp)


## Full braking (m/s²) at tyre grip g: driving.brake_decel_kmh_s · g^brake_exp (snow about half, rain ~80 %).
func brake_decel_mps2(grip: float = 1.0) -> float:
	return _brake_decel / 3.6 * pow(clampf(grip, 0.0001, 1.0), _g_brake_exp)


## Traction limit of the acceleration (m/s²) at tyre grip g: traction_mps2 · g^traction_exp (INF without a limit).
## Above every car's standstill acceleration in the dry; in snow it caps the start (0–100 km/h) of every car.
func traction_mps2(grip: float = 1.0) -> float:
	if _g_traction <= 0.0:
		return INF
	return _g_traction * pow(clampf(grip, 0.0001, 1.0), _g_traction_exp)


## Response time (s) of the lateral speed to the steering at tyre grip g: driving.steer_response_s / g^exp.
## Also the time constant of the slide once the input ends (left-over drift ≈ lateral speed · response time).
func steer_response_s(grip: float = 1.0) -> float:
	return _steer_tau / pow(clampf(grip, 0.0001, 1.0), _g_resp_exp)


## Highest lateral speed (m/s) from steering at tyre grip g (at or above driving.steer_full_speed_kmh):
## steer_mps of the agility rating · g^steer_speed_exp.
func steer_speed_mps(grip: float = 1.0) -> float:
	return _steer_mps * pow(clampf(grip, 0.0001, 1.0), _g_speed_exp)


## Lateral acceleration (m/s²) a curve needs at speed_kmh beyond what the tyres give (0 at or below the
## safe curve speed): v² · |curve| / road.curve_radius_at_1_m − grip_accel(grip).
func lateral_excess(curve: float, grip: float, speed_kmh: float) -> float:
	var vm := speed_kmh / 3.6
	return maxf(0.0, vm * vm * absf(curve) / maxf(_radius_at_1, 0.001) - grip_accel(grip))


## Max speed for the current grade (rise/run) and weather/night factor. Climbs up to
## driving.grade_free_percent cost nothing, every % above it driving.grade_vmax_loss_per_percent
## (floor driving.grade_min_factor). Downhill does not raise it.
func max_speed(grade: float, vmax_factor: float) -> float:
	var loss := maxf(0.0, grade * 100.0 - _grade_free) * _grade_loss
	return _vmax * vmax_factor * maxf(_grade_min, 1.0 - loss)
