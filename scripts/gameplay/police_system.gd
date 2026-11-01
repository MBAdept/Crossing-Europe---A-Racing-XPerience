class_name PoliceSystem
extends RefCounted
## Radar traps and police chases – pure logic. Owner: gameplay module.
## Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
## Rules, decisions and tuning numbers: docs/gameplay.md.
##
## Rules (design document "Radar, Polizei und City Limits"):
##  * warning radar.warning_km before a radar zone, showing the limit (signal radar_warning, once)
##  * zone radar.zone_length_km long; triggers when speed >= limit * (1 + tolerance) anywhere inside
##    (120 -> from 138 km/h); each radar triggers at most once, never during a chase or a stop
##  * triggered -> flash + police chase. The police car starts police.start_gap_m behind and drives
##    police.police_speed_kmh (220): the gap shrinks while the player is slower, grows while faster
##  * curves (since the understeer rework): the police car obeys the same curve physics. update() takes the
##    curve limit of the road at the player's position (road_cap_kmh, computed by the race session with
##    curve_speed_mps() – police.agility 1, below every player car – and police.curve_brake_mps2 braking
##    for the curves ahead); after a curve the police speed rises again with police.curve_accel_mps2 over the
##    distance driven. police_kmh = min(police_speed_kmh, that profile) drives the gap
##  * escape: average speed over the last police.escape_window_s >= escape_kmh and the chase lasted at
##    least that window. escape_kmh = the average of min(escape_speed_kmh, police profile) over the same
##    window: 220 on a straight (design rule unchanged), less where curves slow the police down too –
##    "faster than the police for 12 s"
##  * caught: gap reaches 0 or police.catch_timeout_s passed -> STOPPING (control_request brakes the car to
##    a standstill) -> STOPPED for police.stop_duration_s ("Führerschein, bitte!") -> released, the car
##    starts from standstill. Effective loss about 15–20 s
##  * while another system holds the car (set_blocked(true), e.g. refuelling or towing) the stop does not
##    progress: STOPPING waits, STOPPED does not count down – a capture during refuelling is served
##    after the refuel, so the stop always adds its full time
##  * during the chase traffic is reduced by 80 % (traffic_factor())
##  * a chase can continue into the City Limits; no radar zones there (StagePlan guarantees that). The
##    time limit police.catch_timeout_s (60 s, not in the design) is long enough for a chase that started in
##    the last radar zone before the City Limits (zone end >= 30 km before them) to run into them at
##    200–219 km/h
##  * visuals (police_car_offset_m()): during the chase the police car stays behind the camera; on pull_over
##    it overtakes from police.overtake_from_m behind to police.pull_over_offset_m in front within
##    police.overtake_s (the race module draws it one lane beside the player while passing)

enum State { IDLE, CHASE, STOPPING, STOPPED }

signal radar_warning(radar: Dictionary)
signal radar_zone(radar: Dictionary, entered: bool)
signal flashed(radar: Dictionary, speed_kmh: float)
signal chase_started
signal escaped
signal caught
signal released
## Addition: the police car has caught up and the stop begins (state STOPPING). `caught` follows when the
## car stands still (state STOPPED, "Führerschein, bitte!").
signal pull_over

var cfg: Dictionary = {}
var plan: StagePlan
var state: int = State.IDLE
var chase_time := 0.0
var gap_m := 0.0                 ## distance of the police car behind the player (visual m)
var escape_progress := 0.0       ## 0..1 (HUD)
var avg_speed := 0.0             ## rolling average over the escape window (km/h)
var police_kmh := 0.0            ## speed of the police car this frame (km/h): police_speed_kmh, slower in curves
var escape_kmh := 0.0            ## escape threshold (km/h): rolling average of min(escape_speed_kmh, police profile)
var stop_time_left := 0.0
var active_radar: Dictionary = {}  ## radar warned about or being driven through ({} if none)
# --- additions ---
var chase_radar: Dictionary = {} ## radar that started the current/last chase
var flashes := 0                 ## radar flashes in this stage
var chases := 0
var escapes := 0
var stops := 0
## While true another system controls the car (refuelling, towing): the police stop does not progress
## (STOPPING does not turn into STOPPED, STOPPED does not count down). See set_blocked().
var blocked := false
var overtake_time := 0.0         ## seconds since pull_over (overtaking animation of police_car_offset_m)

var _warned: Dictionary = {}
var _in_zone: Dictionary = {}
var _triggered: Dictionary = {}
var _samples_dt := PackedFloat64Array()
var _samples_v := PackedFloat64Array()
var _samples_e := PackedFloat64Array()
var _head := 0
var _sum_t := 0.0
var _sum_vt := 0.0
var _sum_et := 0.0
var _road_kmh := 0.0             ## police speed profile at the player's position (km/h, curve limit + acceleration)
var _cap_kmh := INF              ## road_cap_kmh of the current update()
# cached configuration
var _tolerance := 0.15
var _warn_window := 1.5
var _escape_speed := 220.0
var _window := 12.0
var _police_speed := 220.0
var _start_gap := 320.0
var _max_gap := 600.0
var _gap_rate := 1.0
var _catch_timeout := 60.0
var _stop_duration := 10.0
var _stop_decel := 40.0
var _pull_over := 12.0
var _bar_range := 60.0
var _chase_factor := 0.2
var _overtake_s := 2.2
var _overtake_from := 16.0
var _lat_grip := 5.6             ## lateral grip of the police car (m/s², agility rating police.agility)
var _radius_at_1 := 120.0
var _curve_grip_exp := 1.0       ## driving.grip_effects.curve_exp (same tyres and weather as the player)
var _curve_accel := 1.5
var _curve_brake := 8.0
var curve_lookahead_m := 300.0   ## police.curve_lookahead_m: how far ahead the curve limit is checked
var curve_step_m := 10.0         ## police.curve_step_m: sample spacing of that look-ahead
var curve_brake_mps2 := 8.0      ## police.curve_brake_mps2 (read-only copy for the race session)


func setup(config: Dictionary, stage_plan: StagePlan) -> void:
	cfg = config
	plan = stage_plan
	_read_config()
	state = State.IDLE
	chase_time = 0.0
	gap_m = 0.0
	escape_progress = 0.0
	avg_speed = 0.0
	stop_time_left = 0.0
	active_radar = {}
	chase_radar = {}
	flashes = 0
	chases = 0
	escapes = 0
	stops = 0
	blocked = false
	overtake_time = 0.0
	police_kmh = 0.0
	escape_kmh = 0.0
	_road_kmh = 0.0
	_cap_kmh = INF
	_warned.clear()
	_in_zone.clear()
	_triggered.clear()
	_clear_samples()


func _f(path: String, default: float) -> float:
	return float(ConfigLoader.lookup(cfg, path, default))


func _read_config() -> void:
	_tolerance = _f("radar.tolerance", 0.15)
	_warn_window = _f("radar.warning_window_km", 1.5)
	_escape_speed = _f("police.escape_speed_kmh", 220.0)
	_window = maxf(0.1, _f("police.escape_window_s", 12.0))
	_police_speed = _f("police.police_speed_kmh", _escape_speed)
	_start_gap = _f("police.start_gap_m", 320.0)
	_max_gap = _f("police.max_gap_m", 600.0)
	_gap_rate = _f("police.gap_rate_factor", 1.0)
	_catch_timeout = _f("police.catch_timeout_s", 60.0)
	_stop_duration = _f("police.stop_duration_s", 10.0)
	_stop_decel = _f("police.stop_decel_kmh_s", 40.0)
	_pull_over = _f("police.pull_over_offset_m", 12.0)
	_bar_range = maxf(1.0, _f("police.escape_bar_range_kmh", 60.0))
	_chase_factor = _f("traffic.chase_density_factor", 0.2)
	_overtake_s = maxf(0.05, _f("police.overtake_s", 2.2))
	_overtake_from = maxf(0.0, _f("police.overtake_from_m", 16.0))
	var agility := clampi(int(_f("police.agility", 1.0)), 1, 5)
	_lat_grip = maxf(0.1, _f("police.lat_grip", _f("vehicles.agility_ratings.%d.lat_grip" % agility, 5.6)))
	_radius_at_1 = maxf(1.0, _f("road.curve_radius_at_1_m", 120.0))
	_curve_grip_exp = maxf(0.0, _f("driving.grip_effects.curve_exp", 1.0))
	_curve_accel = maxf(0.0, _f("police.curve_accel_mps2", 1.5))
	_curve_brake = maxf(0.1, _f("police.curve_brake_mps2", 8.0))
	curve_brake_mps2 = _curve_brake
	curve_lookahead_m = maxf(0.0, _f("police.curve_lookahead_m", 300.0))
	curve_step_m = maxf(1.0, _f("police.curve_step_m", 10.0))


## Speed (km/h) from which a radar with this limit flashes: limit * (1 + radar.tolerance), 120 -> 138.
func trigger_speed(limit_kmh: float) -> float:
	return roundf(limit_kmh * (1.0 + _tolerance) * 100.0) / 100.0


## One step. road_cap_kmh: the curve limit of the police car at the player's position (race session:
## SessionRules.police_curve_cap_kmh – its curve speed here and braking for the curves ahead); INF = straight
## road / unknown (then the police drives police_speed_kmh and the escape needs escape_speed_kmh, as designed).
func update(dt: float, pos_km: float, speed_kmh: float, road_cap_kmh: float = INF) -> void:
	_cap_kmh = road_cap_kmh if not is_nan(road_cap_kmh) else INF
	var prev := state
	_update_radars(pos_km, speed_kmh)
	if prev != state:
		return  # a chase started this frame; it runs from the next frame on
	match state:
		State.CHASE:
			_update_chase(dt, speed_kmh)
		State.STOPPING:
			overtake_time += maxf(dt, 0.0)
			# blocked (e.g. refuelling): the stop starts only when the car is free again
			if speed_kmh <= 0.5 and not blocked:
				state = State.STOPPED
				stop_time_left = _stop_duration
				stops += 1
				caught.emit()
		State.STOPPED:
			overtake_time += maxf(dt, 0.0)
			if blocked:
				return  # the stop time is served after the other system releases the car
			stop_time_left -= dt
			if stop_time_left <= 0.0:
				stop_time_left = 0.0
				state = State.IDLE
				gap_m = 0.0
				escape_progress = 0.0
				released.emit()


func _radar_key(r: Dictionary) -> String:
	return "%.3f" % float(r.get("km", 0.0))


func _update_radars(pos_km: float, speed_kmh: float) -> void:
	active_radar = {}
	if plan == null:
		return
	for r in plan.radars:
		var key := _radar_key(r)
		var km0 := float(r.get("km", 0.0))
		var km1 := float(r.get("end_km", km0))
		var warn_at := float(r.get("warn_km", km0))
		var inside := pos_km >= km0 and pos_km < km1
		if inside != bool(_in_zone.get(key, false)):
			_in_zone[key] = inside
			radar_zone.emit(r, inside)
		if pos_km >= km1:
			continue
		if pos_km >= warn_at:
			if active_radar.is_empty():
				active_radar = r
			if not _warned.has(key):
				_warned[key] = true
				# a warning that would name a wrong distance (start right before the zone) is skipped
				if pos_km < warn_at + _warn_window:
					radar_warning.emit(r)
		if inside and state == State.IDLE and not _triggered.has(key) and speed_kmh >= trigger_speed(float(r.get("limit", 120))):
			_triggered[key] = true
			flashes += 1
			chase_radar = r
			flashed.emit(r, speed_kmh)
			_start_chase(speed_kmh)


func _start_chase(speed_kmh: float) -> void:
	state = State.CHASE
	chase_time = 0.0
	gap_m = _start_gap
	escape_progress = 0.0
	avg_speed = speed_kmh
	chases += 1
	_clear_samples()
	# the police car is at its top speed or at the curve limit of the road here
	_road_kmh = minf(_top_kmh(), _cap_kmh)
	police_kmh = minf(_police_speed, _road_kmh)
	escape_kmh = minf(_escape_speed, _road_kmh)
	chase_started.emit()


## Top speed of the police speed profile (km/h): the larger of police and escape speed, so that each keeps its
## own value on a straight.
func _top_kmh() -> float:
	return maxf(_police_speed, _escape_speed)


## Police speed profile at the player's position: limited by the road (curve speed, braking for curves ahead,
## road_cap_kmh) and, after a curve, rising with police.curve_accel_mps2 over the distance the player drove –
## a function of the road position, like an ideal police driver's speed along the road.
func _advance_police(dt: float, speed_kmh: float) -> void:
	if _road_kmh < _top_kmh():
		var v := _road_kmh / 3.6
		var dz := maxf(speed_kmh, 0.0) / 3.6 * dt
		_road_kmh = minf(sqrt(v * v + 2.0 * _curve_accel * dz) * 3.6, _top_kmh())
	_road_kmh = minf(_road_kmh, _cap_kmh)
	police_kmh = minf(_police_speed, _road_kmh)


## Speed (m/s) at which the police car takes a curve of this strength (-1..1) with this tyre grip (weather; 1 in a
## tunnel): sqrt(lat_grip of police.agility · curve grip · road.curve_radius_at_1_m / |curve|), curve grip =
## grip^driving.grip_effects.curve_exp like the player's car (VehicleModel.curve_grip). INF on a straight.
func curve_speed_mps(curve: float, grip: float = 1.0) -> float:
	var c := absf(curve)
	if c < 0.0001:
		return INF
	return sqrt(maxf(0.0, _lat_grip * pow(clampf(grip, 0.0001, 1.0), _curve_grip_exp) * _radius_at_1 / c))


func _update_chase(dt: float, speed_kmh: float) -> void:
	if dt <= 0.0:
		return
	chase_time += dt
	_advance_police(dt, speed_kmh)
	_push_sample(dt, speed_kmh, minf(_escape_speed, _road_kmh))
	gap_m = clampf(gap_m + (speed_kmh - police_kmh) / 3.6 * dt * _gap_rate, 0.0, _max_gap)
	var level := clampf((avg_speed - (escape_kmh - _bar_range)) / _bar_range, 0.0, 1.0)
	escape_progress = minf(chase_time / _window, 1.0) * level
	if chase_time >= _window - 0.000001 and avg_speed >= escape_kmh - 0.000001:
		state = State.IDLE
		escape_progress = 1.0
		gap_m = 0.0
		escapes += 1
		escaped.emit()
	elif gap_m <= 0.0 or chase_time >= _catch_timeout:
		gap_m = 0.0
		state = State.STOPPING
		overtake_time = 0.0
		pull_over.emit()


func _clear_samples() -> void:
	_samples_dt = PackedFloat64Array()
	_samples_v = PackedFloat64Array()
	_samples_e = PackedFloat64Array()
	_head = 0
	_sum_t = 0.0
	_sum_vt = 0.0
	_sum_et = 0.0


## Time-weighted rolling averages over the last escape window (exact window edge): the player's speed v
## (avg_speed) and the escape threshold e (escape_kmh) with the same weights.
func _push_sample(dt: float, v: float, e: float) -> void:
	_samples_dt.append(dt)
	_samples_v.append(v)
	_samples_e.append(e)
	_sum_t += dt
	_sum_vt += v * dt
	_sum_et += e * dt
	while _head < _samples_dt.size() - 1 and _sum_t - _samples_dt[_head] >= _window:
		_sum_t -= _samples_dt[_head]
		_sum_vt -= _samples_dt[_head] * _samples_v[_head]
		_sum_et -= _samples_dt[_head] * _samples_e[_head]
		_head += 1
	var excess := _sum_t - _window
	if excess > 0.0:
		avg_speed = (_sum_vt - excess * _samples_v[_head]) / _window
		escape_kmh = (_sum_et - excess * _samples_e[_head]) / _window
	else:
		avg_speed = _sum_vt / maxf(_sum_t, 0.000001)
		escape_kmh = _sum_et / maxf(_sum_t, 0.000001)
	if _head > 4096:
		_samples_dt = _samples_dt.slice(_head)
		_samples_v = _samples_v.slice(_head)
		_samples_e = _samples_e.slice(_head)
		_head = 0


## While blocked (another system – refuelling or towing, FuelSystem.holds_car() – controls the car) the
## police stop does not progress: STOPPING waits for the car to be free before it turns into STOPPED
## (`caught` = "Führerschein, bitte!"), and STOPPED does not count down. A capture during refuelling is
## therefore served after the refuel and the stop always adds its full police.stop_duration_s. The chase
## itself (gap, escape, catch) keeps running. Call it every frame before update().
func set_blocked(is_blocked: bool) -> void:
	blocked = is_blocked


func chase_active() -> bool:
	return state == State.CHASE or state == State.STOPPING


## Traffic density multiplier (traffic.chase_density_factor = 0.2 during a chase, i.e. -80 %).
func traffic_factor() -> float:
	return _chase_factor if chase_active() else 1.0


## Scripted control wanted by the police: {} or {"target_kmh": 0.0, "rate_kmh_s": float}.
func control_request() -> Dictionary:
	if state == State.STOPPING or state == State.STOPPED:
		return {"target_kmh": 0.0, "rate_kmh_s": _stop_decel}
	return {}


## Position of the police car (centre) relative to the player's centre in visual metres (negative = behind).
## NAN when no police car is around. Chase: -gap_m, but never closer than police.overtake_from_m (it stays
## behind the camera, render.camera_distance_m = 9 m). Pull-over: in police.overtake_s it overtakes from
## police.overtake_from_m behind to police.pull_over_offset_m in front (smoothstep: gentle start, fastest
## while passing, gentle stop) and stays there while stopping/stopped – no pop-up in front of the player.
## The drawing side places it one lane beside the player while it overlaps him (race module).
func police_car_offset_m() -> float:
	match state:
		State.CHASE:
			return -maxf(gap_m, _overtake_from)
		State.STOPPING, State.STOPPED:
			return lerpf(-_overtake_from, _pull_over, smoothstep(0.0, 1.0, overtake_time / _overtake_s))
	return NAN


## Addition: true while the police car is still overtaking (pull-over animation running).
func overtaking() -> bool:
	return (state == State.STOPPING or state == State.STOPPED) and overtake_time < _overtake_s


## Addition: 0..1 closeness of the police car for the siren volume (1 = right behind / stopping).
func siren_level() -> float:
	match state:
		State.CHASE:
			return clampf(1.0 - gap_m / maxf(_start_gap * 1.5, 1.0), 0.15, 1.0)
		State.STOPPING, State.STOPPED:
			return 1.0
	return 0.0
