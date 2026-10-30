class_name TrafficSystem
extends RefCounted
## Traffic in driving direction only, on fixed lanes – pure logic (no nodes, no autoloads).
## Owner: gameplay module. Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
## Rules, decisions and tuning numbers: docs/gameplay.md.
##
## Rules (design document "Verkehr", "Kollisionen"):
##  * base speed per road type (traffic.speeds_kmh); trucks slower (traffic.truck_speeds_kmh), right lanes
##  * density (cars per visible km) = traffic.base_density_per_km[road] * daily curve traffic.hourly_density
##    (peaks 7–9 and 16–19, minimum 1–5) * section factor * City Limits factor * chase factor
##  * night 23–4: 15 % faster (traffic.night.speed_factor), fewer cars (daily curve)
##  * during a police chase traffic is reduced by 80 % (ctx.chase -> traffic.chase_density_factor)
##  * much more traffic in the City Limits (city_limits.density_factor)
##  * occasionally a car uses the fuel lane (traffic.fuel_lane_use_chance): slows down, drives through, merges
##  * cars overtaking from behind only collide once at least 1/3 of them is on screen
## Driving: Intelligent Driver Model (car following without rear-ending, brake lights) + MOBIL lane changes
## (overtaking, keeping right, merging where a lane ends, evading the player). Cars appear beyond the view
## ahead or behind the camera (only cars faster than the player) and vanish only where nobody can see them.
## The track object must provide (duck typing): length_z, lane_count_at(z), lane_center_x(z, lane),
## road_type_at(z), is_city_at(z), traffic_factor_at(z), fuel_lane_at(z), fuel_lane_x(z) (optional: lane_w).
## Its answers are sampled every TQ_BUCKET metres and cached: the track geometry must not change during a stage.


class Car:
	var id := 0
	var z := 0.0              ## visual metres along the track (car centre)
	var x := 0.0              ## lateral metres (car centre)
	var lane := 0             ## current target lane (0 = leftmost); FUEL_LANE when using the fuel lane
	var speed := 120.0        ## km/h
	var cruise_speed := 120.0 ## desired speed
	var set_id := ""          ## sprite set id, e.g. "traffic/sedan_blue"
	var length := 4.5
	var width := 1.8
	var height := 1.5
	var heavy := false        ## truck/bus
	var braking := false      ## brake lights
	var in_fuel_lane := false
	# --- additions ---
	var speed_frac := 0.5     ## position inside the speed range of the road type (fixed per car)
	var accel := 0.0          ## acceleration of the last frame (m/s²)
	var fuel_state := 0       ## 0 = none, 1 = heading for / using the fuel lane, 2 = done
	var fuel_decided_z := -1.0e9
	var lane_timer := 0.0     ## time until the next lane-change evaluation
	var lane_cooldown := 0.0  ## no new lane change before this ran out
	var from_behind := false  ## spawned behind the player (an overtaker)
	var age := 0.0            ## seconds since spawning
	var occ_lo := 0           ## lanes the body reaches into (updated once per frame)
	var occ_hi := -1
	var occ_fuel := false
	var end_lane := -1000     ## cache of the distance to the end of the own lane
	var end_abs := INF
	var end_check_z := -INF


const FUEL_LANE := 99
const TQ_BUCKET := 4.0
## Look-ahead probe distances (m) for lane ends / fuel lanes.
const PROBES := [6.0, 12.0, 20.0, 30.0, 42.0, 56.0, 72.0, 90.0, 115.0, 145.0, 180.0, 220.0, 270.0, 330.0, 400.0, 480.0]

var cfg: Dictionary = {}
var track: Object = null
var cars: Array[Car] = []
var car_sets: Array[String] = []
var heavy_sets: Array[String] = []
var rng := RandomNumberGenerator.new()
# --- additions ---
var target_count := 0.0          ## wanted number of cars in the managed window (last update)
var spawned_total := 0
var despawned_total := 0
var player_obstacle := Car.new() ## the player as seen by the traffic (id -1)

var _next_id := 1
var _initialized := false
var _dims: Dictionary = {}
var _hour := 12.0
var _all: Array[Car] = []
var _lane_w := 3.75
var _count_jitter := 0.5
var _jitter_t := 0.0
var _jitter_period := 8.0
var _was_chase := false
var _flash_cull_m := 250.0
var _tq_cache: Dictionary = {}
var _tq_pruned := -1000000000
var _tgt_z := -1.0e9
var _tgt_hour := -100.0
var _tgt_chase := false
var _spawn_wait := 0.0
var _last_dt := 0.0
# cached configuration
var _speeds: Dictionary = {}
var _truck_speeds: Dictionary = {}
var _base_density: Dictionary = {}
var _hourly: Array = []
var _night_start := 23.0
var _night_end := 4.0
var _night_density := 1.0
var _night_speed := 1.15
var _chase_factor := 0.2
var _city_factor := 2.5
var _truck_share: Dictionary = {}
var _lane_weights: Dictionary = {}
var _keep_right: Dictionary = {}
var _fuel_chance := 0.12
var _fuel_speed := 50.0
var _spawn_ahead := 950.0
var _spawn_behind := 120.0
var _despawn_behind := 220.0
var _despawn_ahead := 250.0
var _min_gap := 14.0
var _follow_time := 1.2
var _lane_change_mps := 2.5
var _acc_car := 1.6
var _acc_truck := 0.7
var _comfort := 2.5
var _max_decel := 8.0
var _lc_safe := 3.0
var _lc_threshold := 0.2
var _lc_threshold_truck := 0.6
var _politeness := 0.3
var _lc_cooldown := 2.5
var _lc_interval := 0.3
var _lc_min_gap := 6.0
var _merge_look_s := 6.0
var _fuel_look_m := 420.0
var _cull_frac := 0.7
var _spawn_min_gap := 30.0
var _brake_light := 1.0
var _cam_distance := 6.6
var _draw_distance := 900.0
var _rear_visible := 0.3333
var _hitbox := 0.95


## car_sets / heavy_sets: sprite set ids to choose from (SpriteDB tags "traffic" / "heavy").
func setup(config: Dictionary, track_api: Object, cars_ids: Array[String], heavy_ids: Array[String], seed: int) -> void:
	cfg = config
	track = track_api
	car_sets = cars_ids.duplicate()
	heavy_sets = heavy_ids.duplicate()
	rng.seed = seed
	cars.clear()
	_all.clear()
	_next_id = 1
	_initialized = false
	spawned_total = 0
	despawned_total = 0
	target_count = 0.0
	player_obstacle = Car.new()
	player_obstacle.id = -1
	player_obstacle.length = 4.6
	player_obstacle.width = 1.85
	_count_jitter = 0.5
	_jitter_t = 0.0
	_was_chase = false
	_tq_cache.clear()
	_tq_pruned = -1000000000
	_tgt_z = -1.0e9
	_tgt_hour = -100.0
	_tgt_chase = false
	_spawn_wait = 0.0
	_last_dt = 0.0
	_read_config()
	_lane_w = float(ConfigLoader.lookup(cfg, "road.lane_width_m", 3.75))
	if track != null and "lane_w" in track:
		_lane_w = float(track.get("lane_w"))


## Optional: real vehicle sizes per sprite set, e.g. from the sprite manifest:
## {set_id: {length_m, width_m, height_m}} or {set_id: <manifest set with "object": {...}>}.
## Without it sizes are guessed from the set id (truck, bus, van, car).
func set_dimensions(dims: Dictionary) -> void:
	_dims = dims


func _f(path: String, default: float) -> float:
	return float(ConfigLoader.lookup(cfg, path, default))


func _read_config() -> void:
	_speeds = ConfigLoader.lookup(cfg, "traffic.speeds_kmh", {})
	_truck_speeds = ConfigLoader.lookup(cfg, "traffic.truck_speeds_kmh", {})
	_base_density = ConfigLoader.lookup(cfg, "traffic.base_density_per_km", {})
	_hourly = ConfigLoader.lookup(cfg, "traffic.hourly_density", [1.0])
	if _hourly.is_empty():
		_hourly = [1.0]
	_night_start = _f("traffic.night.start_hour", 23.0)
	_night_end = _f("traffic.night.end_hour", 4.0)
	_night_density = _f("traffic.night.density_factor", 1.0)
	_night_speed = _f("traffic.night.speed_factor", 1.15)
	_chase_factor = _f("traffic.chase_density_factor", 0.2)
	_city_factor = _f("city_limits.density_factor", 2.5)
	_truck_share = ConfigLoader.lookup(cfg, "traffic.truck_share", {})
	_lane_weights = ConfigLoader.lookup(cfg, "traffic.lane_weights", {})
	_keep_right = ConfigLoader.lookup(cfg, "traffic.keep_right_bias_mps2", {"autobahn": 0.3, "landstrasse": 0.3})
	_fuel_chance = _f("traffic.fuel_lane_use_chance", 0.12)
	_fuel_speed = _f("traffic.fuel_lane_speed_kmh", 50.0)
	_spawn_ahead = _f("traffic.spawn_ahead_m", 950.0)
	_spawn_behind = _f("traffic.spawn_behind_m", 120.0)
	_despawn_behind = _f("traffic.despawn_behind_m", 220.0)
	_despawn_ahead = _f("traffic.despawn_ahead_margin_m", 250.0)
	_min_gap = _f("traffic.min_gap_m", 14.0)
	_follow_time = _f("traffic.follow_time_s", 1.2)
	_lane_change_mps = _f("traffic.lane_change_mps", 2.5)
	_acc_car = _f("traffic.accel_mps2", 1.6)
	_acc_truck = _f("traffic.truck_accel_mps2", 0.7)
	_comfort = maxf(0.1, _f("traffic.comfort_decel_mps2", 2.5))
	_max_decel = _f("traffic.max_decel_mps2", 8.0)
	_lc_safe = _f("traffic.lane_change_safe_decel_mps2", 3.0)
	_lc_threshold = _f("traffic.lane_change_threshold_mps2", 0.2)
	_lc_threshold_truck = _f("traffic.truck_lane_change_threshold_mps2", 0.6)
	_politeness = _f("traffic.politeness", 0.3)
	_lc_cooldown = _f("traffic.lane_change_cooldown_s", 2.5)
	_lc_interval = maxf(0.02, _f("traffic.lane_change_interval_s", 0.3))
	_lc_min_gap = _f("traffic.lane_change_min_gap_m", 6.0)
	_merge_look_s = _f("traffic.merge_lookahead_s", 6.0)
	_fuel_look_m = _f("traffic.fuel_lane_lookahead_m", 420.0)
	_cull_frac = _f("traffic.cull_visible_fraction", 0.85)
	_flash_cull_m = _f("traffic.chase_flash_cull_m", 250.0)
	_spawn_min_gap = _f("traffic.spawn_min_gap_m", 30.0)
	_jitter_period = maxf(0.5, _f("traffic.count_jitter_s", 8.0))
	_brake_light = _f("traffic.brake_light_decel_mps2", 1.0)
	_cam_distance = _f("render.camera_distance_m", 6.6)
	_draw_distance = _f("render.draw_distance_m", 900.0)
	_rear_visible = _f("collision.rear_min_visible_fraction", 0.3333)
	_hitbox = _f("collision.hitbox_scale", 0.95)


# --- Public queries -------------------------------------------------------------------------

## Daily density multiplier for an hour of the day (0..24): interpolated traffic.hourly_density,
## times traffic.night.density_factor during the night hours.
func density_factor(hour: float) -> float:
	var n := _hourly.size()
	var hh := fposmod(hour, 24.0)
	var h := int(floorf(hh)) % n
	var h2 := (h + 1) % n
	var d := lerpf(float(_hourly[h]), float(_hourly[h2]), hh - floorf(hh))
	if is_night_hour(hour):
		d *= _night_density
	return d


## Speed multiplier (night 23–4: traffic.night.speed_factor, +15 %).
func speed_factor(hour: float) -> float:
	return _night_speed if is_night_hour(hour) else 1.0


## True inside the traffic night window (traffic.night.start_hour .. end_hour, wrapping midnight).
func is_night_hour(hour: float) -> bool:
	var hh := fposmod(hour, 24.0)
	if _night_start > _night_end:
		return hh >= _night_start or hh < _night_end
	return hh >= _night_start and hh < _night_end


## Cars per visible km at z (all lanes): base density of the road type * daily curve * section factor
## * City Limits factor * chase factor.
func density_per_km_at(z: float, hour: float, chase: bool) -> float:
	if track == null or z < 0.0 or z > float(track.length_z):
		return 0.0
	var b := _tq(z)
	var road := str(b[4])
	var d := float(_base_density.get(road, 6.0)) * density_factor(hour) * float(b[6])
	if bool(b[5]):
		d *= _city_factor
	if chase:
		d *= _chase_factor
	return d


# --- Per-frame update -----------------------------------------------------------------------

## player: {z, x, speed (, length, width)}; ctx: {hour: float, chase: bool, camera_z: float (, visibility_m)}
## dt = 0 is allowed (spawns the initial traffic without moving anything).
func update(dt: float, player: Dictionary, ctx: Dictionary) -> void:
	if track == null:
		return
	var p := player_obstacle
	p.z = float(player.get("z", 0.0))
	p.x = float(player.get("x", 0.0))
	p.speed = maxf(0.0, float(player.get("speed", 0.0)))
	p.cruise_speed = maxf(p.speed, 1.0)
	p.length = float(player.get("length", p.length))
	p.width = float(player.get("width", p.width))
	_update_occ(p)
	_hour = float(ctx.get("hour", 12.0))
	var chase := bool(ctx.get("chase", false))
	var cam_z := float(ctx.get("camera_z", p.z - _cam_distance))
	var vis := float(ctx.get("visibility_m", _draw_distance))
	_last_dt = dt
	if not _initialized or chase != _tgt_chase or absf(p.z - _tgt_z) > 10.0 or absf(_hour - _tgt_hour) > 0.02:
		target_count = _window_target(p.z, _hour, chase)
		_tgt_z = p.z
		_tgt_hour = _hour
		_tgt_chase = chase
	_jitter_t -= dt
	if _jitter_t <= 0.0:
		_jitter_t = _jitter_period
		_count_jitter = rng.randf()
	if not _initialized:
		_initialized = true
		_initial_fill()
	if chase and not _was_chase:
		_flash_cull(cam_z)
	_was_chase = chase
	if dt > 0.0:
		_sort_cars()
		_update_occupancy()
		_drive(dt)
		_sort_cars()
		_resolve_overlaps()
	_despawn(cam_z, vis)
	_update_occupancy()
	_spawn(cam_z, vis)
	_cull(cam_z, vis)
	_tq_prune(p.z)


## Number of cars to keep in the window right now: floor(target + jitter) with a jitter in [0, 1) that is
## re-drawn every traffic.count_jitter_s – on average exactly target_count, also for small targets.
func wanted_count() -> int:
	return int(floorf(target_count + _count_jitter))


func _window_target(pz: float, hour: float, chase: bool) -> float:
	var z0 := pz - _despawn_behind
	var z1 := pz + _spawn_ahead
	var step := 50.0
	var n := 0.0
	var z := z0 + step * 0.5
	while z < z1:
		n += density_per_km_at(z, hour, chase) * step / 1000.0
		z += step
	return n


## Sorts by z (ties by id). Insertion sort: the order hardly changes from frame to frame.
func _sort_cars() -> void:
	for i in range(1, cars.size()):
		var c := cars[i]
		var j := i - 1
		while j >= 0 and (cars[j].z > c.z or (cars[j].z == c.z and cars[j].id > c.id)):
			cars[j + 1] = cars[j]
			j -= 1
		cars[j + 1] = c
	_all = cars.duplicate()
	_all.append(player_obstacle)


# --- Driving --------------------------------------------------------------------------------

func _drive(dt: float) -> void:
	var acc := PackedFloat32Array()
	acc.resize(cars.size())
	for i in cars.size():
		var c := cars[i]
		_think(c, dt)
		acc[i] = _accel_for(c)
	for i in cars.size():
		var c := cars[i]
		var a := acc[i]
		var v := maxf(0.0, c.speed / 3.6 + a * dt)
		c.speed = v * 3.6
		c.accel = a
		c.z += v * dt
		c.x = move_toward(c.x, _lane_x(c.z, c.lane), _lane_change_mps * dt)
		c.in_fuel_lane = c.lane == FUEL_LANE or _right_of_main(c)
		c.braking = a < -_brake_light or c.speed < 2.0
		c.age += dt


## Cruise speed, lane validity, fuel-lane plan and lane-change decisions of one car.
func _think(c: Car, dt: float) -> void:
	var lanes := maxi(1, _t_lanes(c.z))
	var road := _t_road(c.z)
	c.cruise_speed = _cruise_value(road, c.heavy, c.speed_frac)
	if c.lane != FUEL_LANE and c.lane >= lanes:
		c.lane = lanes - 1
	if c.lane == FUEL_LANE and not _fuel_lane_open_at(c.z) and not _t_fuel(c.z + 8.0):
		c.lane = lanes - 1
		c.fuel_state = 2
	c.lane_cooldown = maxf(0.0, c.lane_cooldown - dt)
	c.lane_timer -= dt
	var urgent := _player_threat(c)
	if c.lane_timer > 0.0 and not urgent:
		return
	c.lane_timer = _lc_interval * (0.75 + 0.5 * fposmod(float(c.id) * 0.618034, 1.0))
	_update_fuel_plan(c, lanes)
	if c.lane_cooldown > 0.0 and not urgent:
		return
	if absf(c.x - _lane_x(c.z, c.lane)) > 0.35:
		return
	_consider_lane_change(c, lanes, road, urgent)


## True when the player is right ahead in the car's path and the car is closing in fast.
func _player_threat(c: Car) -> bool:
	var p := player_obstacle
	if p.z <= c.z or not _in_path(c, p, c.lane):
		return false
	var gap := _gap(c, p)
	if gap > 150.0:
		return false
	var closing := (c.speed - p.speed) / 3.6
	return gap < _min_gap or (closing > 0.5 and gap / closing < 3.0)


func _consider_lane_change(c: Car, lanes: int, road: String, urgent: bool) -> void:
	var cur := c.lane
	var cands: Array[int] = []
	var mandatory := -999
	if cur == FUEL_LANE:
		cands.append(lanes - 1)
		if c.fuel_state != 1 or _lane_end_distance(c, FUEL_LANE) < INF:
			mandatory = lanes - 1
	else:
		if c.fuel_state == 1:
			if cur == lanes - 1 and _fuel_lane_open_at(c.z):
				cands.append(FUEL_LANE)
				mandatory = FUEL_LANE
			elif cur < lanes - 1:
				mandatory = cur + 1
		if cur > 0 and not (c.heavy and lanes >= 3 and cur - 1 == 0):
			cands.append(cur - 1)
		if cur < lanes - 1:
			cands.append(cur + 1)
		if cur > 0 and _lane_end_distance(c, cur) < INF:
			mandatory = cur - 1
	if cands.is_empty():
		return
	var a_cur := _idm(c, _desired_speed(c, cur), _leader(c, cur))
	var best_lane := cur
	var best_margin := 0.0
	for lane in cands:
		# trucks are reluctant to pull out to the left, but return to the right like everybody else
		var threshold := _lc_threshold_truck if c.heavy and lane < cur else _lc_threshold
		if urgent:
			threshold = 0.05
		var margin := _lane_gain(c, lane, a_cur, road, lane == mandatory, urgent) - threshold
		if margin > best_margin:
			best_margin = margin
			best_lane = lane
	if best_lane != cur:
		if cur == FUEL_LANE:
			c.fuel_state = 2
		c.lane = best_lane
		c.lane_cooldown = _lc_cooldown


## MOBIL: advantage (m/s²) of moving to `lane`, -INF when unsafe or not allowed.
func _lane_gain(c: Car, lane: int, a_cur: float, road: String, mandatory: bool, urgent: bool) -> float:
	if not _lane_usable(c, lane):
		return -INF
	var lead := _lane_leader(c, lane)
	var foll := _follower(c, lane)
	if lead != null and _gap(c, lead) < _lc_min_gap:
		return -INF
	if foll != null and _gap(foll, c) < _lc_min_gap:
		return -INF
	var a_new := _idm(c, _desired_speed(c, lane), lead)
	if a_new < -_lc_safe and not mandatory and not urgent:
		return -INF
	var f_loss := 0.0
	if foll != null:
		var a_f_new := _idm(foll, _desired_speed(foll, foll.lane), c)
		if a_f_new < -_lc_safe:
			return -INF
		if foll != player_obstacle:
			var a_f_old := _idm(foll, _desired_speed(foll, foll.lane), _leader(foll, foll.lane))
			f_loss = maxf(0.0, a_f_old - a_f_new)
	var gain := a_new - a_cur - _politeness * f_loss
	if lane != FUEL_LANE and c.lane != FUEL_LANE:
		var kr := float(_keep_right.get(road, 0.0))
		gain += kr if lane > c.lane else -kr
	if mandatory:
		gain += 10.0
	return gain


func _lane_usable(c: Car, lane: int) -> bool:
	if lane == FUEL_LANE:
		return _fuel_lane_open_at(c.z) and _t_fuel(c.z + 25.0)
	if lane < 0 or lane >= _t_lanes(c.z):
		return false
	return _lane_end_distance(c, lane) == INF


## Acceleration (m/s²) of a car: IDM towards its leader, plus a stop before the end of its lane.
func _accel_for(c: Car) -> float:
	var v0 := _desired_speed(c, c.lane)
	var a := _idm(c, v0, _leader(c, c.lane))
	var end_d := _cached_lane_end(c)
	if end_d < INF:
		var a_max := _acc_truck if c.heavy else _acc_car
		a = minf(a, _idm_free(c, v0, a_max) + _idm_interaction(c, a_max, 0.0, end_d - c.length * 0.5 - 3.0))
	return clampf(a, -_max_decel, _acc_truck if c.heavy else _acc_car)


func _desired_speed(c: Car, lane: int) -> float:
	if c == player_obstacle:
		return c.cruise_speed
	var v := c.cruise_speed
	if lane == FUEL_LANE or c.in_fuel_lane:
		v = minf(v, _fuel_speed)
	elif c.fuel_state == 1:
		# heading for the fuel lane: brake just in time to enter it at fuel_lane_speed_kmh
		var d := _fuel_lane_ahead(c.z)
		if d < INF:
			var vf := _fuel_speed / 3.6
			v = minf(v, sqrt(vf * vf + 2.0 * _comfort * 0.6 * maxf(0.0, d - 10.0)) * 3.6)
	return v


## Intelligent Driver Model acceleration (m/s²) of c with desired speed v0_kmh behind `lead` (or free road).
func _idm(c: Car, v0_kmh: float, lead: Car) -> float:
	var a_max := _acc_truck if c.heavy else _acc_car
	var a := _idm_free(c, v0_kmh, a_max)
	if lead != null:
		a += _idm_interaction(c, a_max, lead.speed / 3.6, _gap(c, lead))
	return a


func _idm_free(c: Car, v0_kmh: float, a_max: float) -> float:
	var v := c.speed / 3.6
	var vd := maxf(v0_kmh / 3.6, 0.5)
	if v <= vd:
		return a_max * (1.0 - pow(v / vd, 4.0))
	return -minf(_comfort, 0.4 * (v - vd) + 0.2)


func _idm_interaction(c: Car, a_max: float, v_lead: float, gap: float) -> float:
	var v := c.speed / 3.6
	var s_star := _min_gap + maxf(0.0, v * _follow_time + v * (v - v_lead) / (2.0 * sqrt(a_max * _comfort)))
	return -a_max * pow(s_star / maxf(gap, 0.5), 2.0)


# --- Neighbourhood --------------------------------------------------------------------------

## Lane centre (or fuel lane centre) at z from the geometry cache (linear between the cache buckets).
func _lane_x(z: float, lane: int) -> float:
	var f := z / TQ_BUCKET
	var b0 := floorf(f)
	var e0 := _tq_bucket(int(b0))
	var e1 := _tq_bucket(int(b0) + 1)
	var t := f - b0
	if lane == FUEL_LANE:
		return lerpf(float(e0[3]), float(e1[3]), t)
	return lerpf(float(e0[1]), float(e1[1]), t) + _lane_w * float(lane)


func _right_of_main(c: Car) -> bool:
	# right edge of the regular lanes = lanes * lane_w / 2 = lane_w / 2 - centre of lane 0
	return c.x > _lane_w * 0.5 - _lane_x(c.z, 0) + 0.3


# --- Track geometry cache -------------------------------------------------------------------
# The track is static, but its queries are not free. Everything the traffic needs is sampled every
# TQ_BUCKET metres once: [lane_count, centre of lane 0, fuel lane open, fuel lane centre, road type,
# City Limits, traffic factor]. Buckets far behind the player are dropped.

func _tq_bucket(b: int) -> Array:
	var e: Variant = _tq_cache.get(b, null)
	if e == null:
		var z := float(b) * TQ_BUCKET
		e = [int(track.lane_count_at(z)), float(track.lane_center_x(z, 0)), bool(track.fuel_lane_at(z)),
			float(track.fuel_lane_x(z)), str(track.road_type_at(z)), bool(track.is_city_at(z)), float(track.traffic_factor_at(z))]
		_tq_cache[b] = e
	return e


func _tq(z: float) -> Array:
	return _tq_bucket(int(floorf(z / TQ_BUCKET)))


func _t_lanes(z: float) -> int:
	return int(_tq(z)[0])


func _t_road(z: float) -> String:
	return str(_tq(z)[4])


## Fuel lane open at z (both ends of the cache bucket must be inside the lane).
func _t_fuel(z: float) -> bool:
	var b := int(floorf(z / TQ_BUCKET))
	return bool(_tq_bucket(b)[2]) and bool(_tq_bucket(b + 1)[2])


func _tq_prune(pz: float) -> void:
	var first := int(floorf((pz - _despawn_behind - 200.0) / TQ_BUCKET))
	if first - _tq_pruned < 200:
		return
	for k in _tq_cache.keys():
		if int(k) < first:
			_tq_cache.erase(k)
	_tq_pruned = first


func _gap(follower: Car, leader: Car) -> float:
	return leader.z - follower.z - (leader.length + follower.length) * 0.5


## o is in lane (its target lane, or its body reaches into the lane – see _update_occ).
func _occupies(o: Car, lane: int) -> bool:
	if o != player_obstacle and o.lane == lane:
		return true
	if lane == FUEL_LANE:
		return o.occ_fuel
	return lane >= o.occ_lo and lane <= o.occ_hi


## Lanes whose centre is closer than half a lane + half the body (- 0.25 m) to o.x.
func _update_occ(o: Car) -> void:
	var reach := _lane_w * 0.5 + o.width * 0.5 - 0.25
	var rel := (o.x - _lane_x(o.z, 0)) / _lane_w
	var r := reach / _lane_w
	o.occ_lo = int(floorf(rel - r)) + 1
	o.occ_hi = int(ceilf(rel + r)) - 1
	o.occ_fuel = absf(o.x - _lane_x(o.z, FUEL_LANE)) < reach


func _update_occupancy() -> void:
	for c in cars:
		_update_occ(c)
	_update_occ(player_obstacle)


## o is in the way of c driving in `lane` (lane occupied or overlapping c's current corridor).
func _in_path(c: Car, o: Car, lane: int) -> bool:
	if absf(o.x - c.x) < (o.width + c.width) * 0.5 + 0.2:
		return true
	return _occupies(o, lane)


## Nearest object ahead of c in its way (same checks as _in_path, inlined: this runs for every car each frame).
func _leader(c: Car, lane: int) -> Car:
	var best: Car = null
	var best_z := INF
	var cz := c.z
	var cx := c.x
	var half := c.width * 0.5 + 0.2
	var fuel := lane == FUEL_LANE
	for o in _all:
		var oz := o.z
		if oz <= cz or oz >= best_z or o == c:
			continue
		if absf(o.x - cx) < o.width * 0.5 + half \
				or (o != player_obstacle and o.lane == lane) \
				or (o.occ_fuel if fuel else (lane >= o.occ_lo and lane <= o.occ_hi)):
			best = o
			best_z = oz
	return best


## Nearest object ahead of c that occupies `lane` (lane-change evaluation: c's current corridor is ignored).
func _lane_leader(c: Car, lane: int) -> Car:
	var best: Car = null
	for o in _all:
		if o == c or o.z <= c.z:
			continue
		if best != null and o.z >= best.z:
			continue
		if _occupies(o, lane):
			best = o
	return best


func _follower(c: Car, lane: int) -> Car:
	var best: Car = null
	for o in _all:
		if o == c or o.z > c.z:
			continue
		if best != null and o.z <= best.z:
			continue
		if _occupies(o, lane):
			best = o
	return best


## Distance (m) to where `lane` ends ahead of c (lane drop or end of the fuel lane), INF if not in sight.
func _lane_end_distance(c: Car, lane: int) -> float:
	var look: float
	if lane == FUEL_LANE:
		look = 25.0 + c.speed / 3.6 * 1.5
	else:
		look = 60.0 + c.speed / 3.6 * _merge_look_s
	var last_ok := 0.0
	for d: float in PROBES:
		if d > look:
			break
		if not _lane_exists(c.z + d, lane):
			# refine between the last probe where the lane existed and this one
			var lo := last_ok
			var hi := d
			for k in 4:
				var mid := (lo + hi) * 0.5
				if _lane_exists(c.z + mid, lane):
					lo = mid
				else:
					hi = mid
			return hi
		last_ok = d
	return INF


## _lane_end_distance of the car's own lane, re-probed every few metres (the end itself does not move).
func _cached_lane_end(c: Car) -> float:
	if c.end_lane != c.lane or c.z >= c.end_check_z:
		var d := _lane_end_distance(c, c.lane)
		c.end_lane = c.lane
		c.end_abs = c.z + d if d < INF else INF
		c.end_check_z = c.z + (3.0 if c.lane == FUEL_LANE else 8.0)
	return c.end_abs - c.z if c.end_abs < INF else INF


func _lane_exists(z: float, lane: int) -> bool:
	if lane == FUEL_LANE:
		return _t_fuel(z)
	return _t_lanes(z) > lane


func _fuel_lane_open_at(z: float) -> bool:
	return _t_fuel(z) and _t_fuel(z + 15.0)


## Distance to the next fuel lane ahead within traffic.fuel_lane_lookahead_m, INF if none.
func _fuel_lane_ahead(z: float) -> float:
	if _t_fuel(z):
		return 0.0
	var last := 0.0
	for d: float in PROBES:
		if d > _fuel_look_m:
			break
		if _t_fuel(z + d):
			var lo := last
			var hi := d
			for k in 5:
				var mid := (lo + hi) * 0.5
				if _t_fuel(z + mid):
					hi = mid
				else:
					lo = mid
			return hi
		last = d
	return INF


func _update_fuel_plan(c: Car, lanes: int) -> void:
	if c.fuel_state == 2 and c.z - c.fuel_decided_z > 2500.0:
		c.fuel_state = 0
	if c.fuel_state == 0:
		if c.heavy or _fuel_chance <= 0.0 or c.z - c.fuel_decided_z < 2500.0:
			return
		var ahead := _fuel_lane_ahead(c.z)
		if ahead < INF and ahead > 25.0:
			c.fuel_decided_z = c.z
			if rng.randf() < _fuel_chance:
				c.fuel_state = 1
	elif c.fuel_state == 1 and c.lane != FUEL_LANE:
		# could not get in (blocked) -> give up once the lane is behind
		if _fuel_lane_ahead(c.z) == INF:
			c.fuel_state = 2
	if c.fuel_state == 1 and lanes <= 0:
		c.fuel_state = 2


## Pushes cars back that overlap the car ahead of them (safety net, normally never needed).
func _resolve_overlaps() -> void:
	var n := cars.size()
	for i in range(n - 2, -1, -1):
		var c := cars[i]
		for j in range(i + 1, n):
			var o := cars[j]
			if o.z - c.z > (c.length + 17.0) * 0.5 + 0.5:
				break
			var need := (o.length + c.length) * 0.5 + 0.5
			if o.z - c.z < need and absf(o.x - c.x) < (o.width + c.width) * 0.5 - 0.05:
				c.z = o.z - need
				c.speed = minf(c.speed, o.speed)


# --- Spawning and despawning ----------------------------------------------------------------

func _cruise_value(road: String, heavy: bool, frac: float) -> float:
	var r: Variant = (_truck_speeds if heavy else _speeds).get(road, null)
	var lo := 100.0
	var hi := 130.0
	if r is Array and (r as Array).size() >= 2:
		lo = float(r[0])
		hi = float(r[1])
	return lerpf(lo, hi, frac) * speed_factor(_hour)


func _is_heavy(road: String, roll: float) -> bool:
	if heavy_sets.is_empty():
		return false
	if car_sets.is_empty():
		return true
	return roll < float(_truck_share.get(road, 0.1))


func _dims_for(set_id: String, heavy: bool) -> Vector3:
	var raw: Variant = _dims.get(set_id, null)
	if raw is Dictionary:
		var d: Dictionary = raw
		if d.get("object", null) is Dictionary:
			d = d["object"]
		if d.has("length_m"):
			return Vector3(float(d["length_m"]), float(d.get("width_m", 1.8)), float(d.get("height_m", 1.5)))
	var s := set_id.to_lower()
	if s.contains("truck"):
		return Vector3(16.5, 2.5, 3.9)
	if s.contains("bus"):
		return Vector3(12.0, 2.55, 3.2)
	if s.contains("van"):
		return Vector3(4.6, 1.85, 2.0)
	if heavy:
		return Vector3(12.0, 2.5, 3.5)
	return Vector3(4.5, 1.8, 1.5)


## Lanes to try for a new car, preferred first (trucks: right lanes only).
func _lane_order(road: String, lanes: int, heavy: bool, roll: float) -> Array[int]:
	var order: Array[int] = []
	if heavy:
		# trucks: rightmost lane; on wider roads some are just overtaking in the second lane from the right
		order.append(lanes - 2 if lanes >= 3 and roll < 0.15 else lanes - 1)
		return order
	var w: Variant = _lane_weights.get(road, [])
	var weights: Array[float] = []
	var total := 0.0
	for i in lanes:
		var wi := 1.0
		if w is Array and not (w as Array).is_empty():
			wi = maxf(0.0, float(w[mini(i, (w as Array).size() - 1)]))
		weights.append(wi)
		total += wi
	var pick := lanes - 1
	var r := roll * total
	var acc := 0.0
	for i in lanes:
		acc += weights[i]
		if r < acc:
			pick = i
			break
	order.append(pick)
	for i in range(lanes - 1, -1, -1):
		if i != pick:
			order.append(i)
	return order


func _initial_fill() -> void:
	var p := player_obstacle
	var z0 := p.z + 60.0
	var z1 := minf(p.z + _spawn_ahead, float(track.length_z) - 30.0)
	if z1 <= z0:
		return
	var share := (z1 - z0) / maxf(1.0, _spawn_ahead + _despawn_behind)
	var n := int(roundf(target_count * share))
	for i in n:
		var z := z0 + (z1 - z0) * (float(i) + rng.randf()) / float(n)
		_try_spawn(z, rng.randf(), rng.randf(), rng.randf(), rng.randf(), false)


func _spawn(cam_z: float, vis: float) -> void:
	if car_sets.is_empty() and heavy_sets.is_empty():
		return
	if cars.size() >= wanted_count():
		return
	if _spawn_wait > 0.0:
		_spawn_wait -= _last_dt
		return
	_spawn_wait = 0.1
	var p := player_obstacle
	var frac := rng.randf()
	var heavy_roll := rng.randf()
	var lane_roll := rng.randf()
	var set_roll := rng.randf()
	var z_ahead := maxf(p.z + _spawn_ahead, cam_z + maxf(vis, _draw_distance) + 20.0) + rng.randf_range(0.0, 40.0)
	var z_behind := minf(p.z - _spawn_behind, cam_z - 30.0) - rng.randf_range(0.0, 30.0)
	# a car that would overtake the player comes from behind (out of sight), all others appear ahead
	if z_behind > 0.0:
		var road_b := _t_road(z_behind)
		if _cruise_value(road_b, _is_heavy(road_b, heavy_roll), frac) > p.speed + 8.0:
			_try_spawn(z_behind, frac, heavy_roll, lane_roll, set_roll, true)
			return
	if z_ahead < float(track.length_z) - 30.0:
		_try_spawn(z_ahead, frac, heavy_roll, lane_roll, set_roll, false)


func _try_spawn(z: float, frac: float, heavy_roll: float, lane_roll: float, set_roll: float, behind: bool) -> bool:
	var road := _t_road(z)
	var heavy := _is_heavy(road, heavy_roll)
	var sets := heavy_sets if heavy else car_sets
	if sets.is_empty():
		return false
	var set_id := sets[mini(int(set_roll * sets.size()), sets.size() - 1)]
	var dims := _dims_for(set_id, heavy)
	var lanes := maxi(1, _t_lanes(z))
	var cruise := _cruise_value(road, heavy, frac)
	for lane in _lane_order(road, lanes, heavy, lane_roll):
		if behind and _occupies(player_obstacle, lane):
			continue
		var speed := cruise
		if not _space_free(z, lane, dims.x, speed):
			continue
		if not behind:
			# do not appear faster than a slow car right ahead in the same lane
			for o in cars:
				if o.z > z and o.z - z < 220.0 and _occupies(o, lane):
					speed = minf(speed, o.speed)
		var c := Car.new()
		c.id = _next_id
		_next_id += 1
		c.z = z
		c.lane = lane
		c.x = _lane_x(z, lane)
		c.speed_frac = frac
		c.cruise_speed = cruise
		c.speed = speed
		c.set_id = set_id
		c.length = dims.x
		c.width = dims.y
		c.height = dims.z
		c.heavy = heavy
		c.from_behind = behind
		c.lane_timer = _lc_interval
		_update_occ(c)
		cars.append(c)
		spawned_total += 1
		return true
	return false


func _space_free(z: float, lane: int, length: float, speed: float) -> bool:
	for i in cars.size() + 1:
		var o := cars[i] if i < cars.size() else player_obstacle
		if not _occupies(o, lane):
			continue
		var dz := o.z - z
		var need := (o.length + length) * 0.5 + maxf(_spawn_min_gap, _min_gap + maxf(speed, o.speed) / 3.6 * _follow_time)
		if dz > 0.0 and speed > o.speed:
			need += (speed - o.speed) / 3.6 * 4.0
		elif dz < 0.0 and o.speed > speed:
			need += (o.speed - speed) / 3.6 * 4.0
		if absf(dz) < need:
			return false
	return true


func _visible(c: Car, cam_z: float, vis: float) -> bool:
	return c.z + c.length * 0.5 > cam_z and c.z - c.length * 0.5 < cam_z + vis


func _despawn(cam_z: float, vis: float) -> void:
	var p := player_obstacle
	var view_end := cam_z + maxf(vis, _draw_distance)
	var keep: Array[Car] = []
	for c in cars:
		var far_behind := c.z < p.z - _despawn_behind and c.z + c.length * 0.5 < cam_z
		var far_ahead := c.z > p.z + _spawn_ahead + _despawn_ahead and c.z - c.length * 0.5 > view_end
		var past_end := c.z > float(track.length_z) + 30.0 and not _visible(c, cam_z, vis)
		if far_behind or far_ahead or past_end:
			despawned_total += 1
		else:
			keep.append(c)
	cars = keep


## The moment a chase starts the radar flash covers the screen (HUD radar_flash01): surplus cars further
## than traffic.chase_flash_cull_m ahead of the camera (and all behind it) are removed right then, so the
## -80 % is felt during the chase without cars vanishing in plain sight. 0 disables it.
func _flash_cull(cam_z: float) -> void:
	if _flash_cull_m <= 0.0:
		return
	var wanted := wanted_count()
	while cars.size() > wanted:
		var best: Car = null
		var best_score := -INF
		for c in cars:
			var score := -INF
			if c.z + c.length * 0.5 < cam_z - 2.0:
				score = 100000.0 + (cam_z - c.z)
			elif c.z - c.length * 0.5 > cam_z + _flash_cull_m:
				score = c.z - cam_z
			if score > best_score:
				best = c
				best_score = score
		if best == null:
			break
		cars.erase(best)
		despawned_total += 1


## Removes surplus cars (e.g. after the density dropped) – only where they cannot be seen:
## behind the camera or deep in the fog ahead (beyond traffic.cull_visible_fraction of the visibility).
func _cull(cam_z: float, vis: float) -> void:
	var limit := wanted_count() + maxi(1, int(ceilf(target_count * 0.25)))
	if cars.size() <= limit:
		return
	var fog_z := cam_z + vis * _cull_frac
	var best: Car = null
	var best_score := -INF
	for c in cars:
		var score := -INF
		if c.z + c.length * 0.5 < cam_z - 2.0:
			score = 100000.0 + (cam_z - c.z)
		elif c.z - c.length * 0.5 > fog_z:
			score = c.z - fog_z
		if score > best_score:
			best = c
			best_score = score
	if best != null and best_score > -INF:
		cars.erase(best)
		despawned_total += 1


# --- Collision queries ----------------------------------------------------------------------

## First car overlapping the player, or null. player: {z, x, length, width}.
## visible_fraction(dz_from_camera: float, height_m: float) -> float decides whether a car coming from
## behind is visible enough (collision.rear_min_visible_fraction) to collide.
func find_collision(player: Dictionary, camera_z: float, visible_fraction: Callable) -> Car:
	var pz := float(player.get("z", 0.0))
	var px := float(player.get("x", 0.0))
	var pl := float(player.get("length", 4.6))
	var pw := float(player.get("width", 1.85))
	var best: Car = null
	var best_d := INF
	for c in cars:
		var dz := c.z - pz
		var dx := c.x - px
		if absf(dz) >= (c.length + pl) * 0.5 * _hitbox or absf(dx) >= (c.width + pw) * 0.5 * _hitbox:
			continue
		if dz < 0.0 and visible_fraction.is_valid():
			var vf := float(visible_fraction.call(c.z - c.length * 0.5 - camera_z, c.height))
			if vf < _rear_min_visible():
				continue
		var d := absf(dz) + absf(dx)
		if d < best_d:
			best = c
			best_d = d
	return best


func _rear_min_visible() -> float:
	return _rear_visible


## Free lateral metres left/right of a car of half length half_len at (z, x), limited by the road edges.
func space_beside(z: float, x: float, half_len: float, left_edge: float, right_edge: float) -> Vector2:
	var left := x - left_edge
	var right := right_edge - x
	for c in cars:
		if absf(c.z - z) < half_len + c.length * 0.5 + 1.0:
			if c.x < x:
				left = minf(left, x - c.x - c.width * 0.5)
			else:
				right = minf(right, c.x - x - c.width * 0.5)
	return Vector2(maxf(left, 0.0), maxf(right, 0.0))
