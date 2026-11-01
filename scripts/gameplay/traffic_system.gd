class_name TrafficSystem
extends RefCounted
## Traffic in driving direction only, on fixed lanes – pure logic (no nodes, no autoloads).
## Owner: gameplay module. Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
## Rules, decisions and tuning numbers: docs/gameplay.md.
##
## Rules (design document "Verkehr", "Kollisionen"; v0.5.0 playtest "man kann zu leicht an anderen Autos
## vorbeifahren" – traffic is a real obstacle now, docs/gameplay.md "Verkehr als Hindernis"):
##  * desired speed per car: the design range of the road type (traffic.speeds_kmh) for cars, realistic ranges for
##    trucks (traffic.truck_speeds_kmh, autobahn 80–90) and buses (traffic.bus_speeds_kmh, ~95–100); capped by the
##    speed limit of the section (cars limit * traffic.limit_tolerance, by temperament; heavy vehicles the limit)
##    and slowed by the weather (traffic.weather.<w>: rain about -15 %, snow about -35 % with longer gaps).
##    Fast cars appear in the left lanes, slow ones on the right (traffic.lane_speed_spread)
##  * density (cars per visible km) = traffic.base_density_per_km[road] * daily curve traffic.hourly_density
##    (peaks 7–9 and 16–19, minimum 1–5) * section factor * City Limits factor * chase factor; new traffic
##    often comes in clusters (traffic.cluster: platoons behind a slow vehicle, trucks overtaking trucks)
##  * night 23–4: fewer cars (daily curve); traffic.night.speed_factor (1.0: no night bonus any more)
##  * during a police chase traffic is reduced by 80 % (ctx.chase -> traffic.chase_density_factor)
##  * much more traffic in the City Limits (city_limits.density_factor)
##  * occasionally a car uses the fuel lane (traffic.fuel_lane_use_chance): slows down, drives through, merges
##  * cars overtaking from behind only collide once at least 1/3 of them is on screen
##  * every lane change is announced by the indicator (traffic.blink: 1–1.5 s before the car moves; Car.signal_*),
##    except an emergency swerve away from the player
##  * traffic does not clear the way for the player: drivers misjudge a fast car coming up behind them and pull
##    out in front of it (traffic.cut_in) – but never closer than the player can still brake for (fairness floor
##    with ctx.brake_mps2, the player's full braking in this weather)
##  * trucks overtake slower heavy vehicles on roads with 3+ lanes ("Elefantenrennen", two lanes blocked at
##    ~85 km/h) and give up after traffic.elephant.max_s
## Driving: Intelligent Driver Model (car following without rear-ending, brake lights) + MOBIL lane changes
## (overtaking, keeping right, merging where a lane ends, evading the player). Cars appear beyond the view
## ahead or behind the camera (only cars faster than the player) and vanish only where nobody can see them.
## The track object must provide (duck typing): length_z, lane_count_at(z), lane_center_x(z, lane),
## road_type_at(z), is_city_at(z), traffic_factor_at(z), fuel_lane_at(z), fuel_lane_x(z) (optional: lane_w,
## speed_limit_at(z) – 0 = no limit).
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
	## Rolling-roadblock rule (TrafficSystem._side_plan), < 0 = inactive. yield_kmh: the car cannot pass an
	## about equally fast car on its right decisively – it drops back to this speed and keeps right behind
	## it. pass_kmh: it passes such cars decisively at this desired speed (at most the top of its range).
	var yield_kmh := -1.0
	var pass_kmh := -1.0
	# --- v0.5.0 ---
	var bus := false          ## heavy vehicle that is a bus (own speed range)
	## Indicator: -1 left, +1 right, 0 off. It starts signal_lead seconds before the car moves (signal_t counts
	## down), stays on while it waits for a safe gap and while it moves, and goes off in the new lane.
	var signal_dir := 0
	var signal_lane := -1     ## lane the car signals into (FUEL_LANE possible)
	var signal_t := 0.0       ## seconds until it moves (<= 0: moves as soon as it is safe)
	var signal_age := 0.0     ## seconds since the indicator came on (blink phase for the renderer)
	var signal_wait := 0.0    ## seconds it has been waiting for a gap after signal_t ran out
	var signal_mandatory := false
	## The car must leave its lane (it ends, or the fuel lane after refuelling): it signals at once and waits for a gap,
	## the traffic in the target lane lets it in (zipper, TrafficSystem._leader).
	var signal_merge := false
	## Truck overtaking a slower heavy vehicle (Elefantenrennen): seconds in the overtaking lane, -1 = no.
	var elephant_t := -1.0
	## Seconds until a heavy vehicle that gave up an Elefantenrennen tries again (traffic.elephant.retry_s).
	var elephant_cool := 0.0


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
# --- v0.5.0 ---
var weather := "normal"          ## ctx.weather of the last update (speeds and gaps of the traffic)
var player_brake_mps2 := 19.44   ## ctx.brake_mps2: the player's full braking in this weather (cut-in floor)
var cut_ins := 0                 ## lane changes into the player's lane in front of a faster player (statistics)
var last_cut_in := {}            ## {id, gap_m, rel_kmh, floor_m} of the last one (tests, debug)

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
var _pending := 0                 ## size of the next group spawned ahead (0 = not drawn yet)
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
var _eff_comfort := 2.5      ## comfortable braking in the current weather (traffic.weather.<w>.decel_factor)
var _eff_max_decel := 8.0    ## strongest braking in the current weather (behind the player: always _max_decel)
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
var _yield_margin := 6.0
var _yield_slow := 15.0
var _side_behind := 70.0
var _side_ahead := 40.0
var _yield_bonus := 1.0
var _pass_boost := 10.0
var _yield_hold := 40.0
var _w_margin := 1.0              ## side-rule speed margins × the weather speed factor (snow: 6 -> 3.9 km/h)
var _cam_distance := 6.6
var _draw_distance := 900.0
var _rear_visible := 0.3333
var _hitbox := 0.95
# v0.5.0: classes, limits, weather, indicators, cut-ins, elephant races, clusters
var _bus_speeds: Dictionary = {}
var _bus_share := 0.25
var _limit_tol := Vector2(0.92, 1.12)
var _lane_spread := 1.4
var _weather_cfg: Dictionary = {}
var _w_speed := 1.0               ## weather factors of the current weather (ctx.weather)
var _w_heavy := 1.0
var _w_follow := 1.0
var _w_gap := 1.0
var _eff_gap := 14.0              ## min_gap_m * weather factor
var _eff_follow := 1.2            ## follow_time_s * weather factor
var _eff_lc_mps := 2.5            ## lane_change_mps * weather factor (careful lane changes on snow)
var _blink_lead := Vector2(1.0, 1.5)
var _blink_heavy := 1.3
var _blink_mandatory := 1.0
var _blink_max_wait := 3.0
var _zipper_m := 60.0             ## traffic.blink.zipper_m: a mandatory merger this close ahead counts as the leader
var _cut_react := 0.3
var _cut_intrude := 0.5
var _cut_brake_frac := 0.7
var _cut_margin := 8.0
var _cut_perceive := 20.0         ## m/s: closing speeds above this look like this in the mirror
var _cut_judge := Vector2(2.5, 5.0)
var _cut_judge_add := 20.0
var _el_min_lanes := 3
var _el_min_kmh := 3.0
var _el_look := 60.0
var _el_bonus := 1.0
var _el_max_s := 40.0
var _el_retry := 60.0
var _cluster_chance: Dictionary = {}
var _cluster_followers := Vector2i(1, 3)
var _cluster_elephant := 0.3
var _cluster_gap := Vector2(1.0, 1.5)
var _cluster_patience := Vector2(4.0, 20.0)
var _bus_sets: Array[String] = []
var _truck_sets: Array[String] = []


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
	_pending = 0
	_last_dt = 0.0
	cut_ins = 0
	last_cut_in = {}
	_bus_sets.clear()
	_truck_sets.clear()
	for id in heavy_sets:
		if id.to_lower().contains("bus"):
			_bus_sets.append(id)
		else:
			_truck_sets.append(id)
	_read_config()
	_apply_weather("normal")
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
	_yield_margin = _f("traffic.yield_speed_margin_kmh", 6.0)
	_yield_slow = maxf(0.0, _f("traffic.yield_slowdown_kmh", 15.0))
	_side_behind = _f("traffic.side_window_behind_m", 70.0)
	_side_ahead = _f("traffic.side_window_ahead_m", 40.0)
	_yield_bonus = _f("traffic.yield_keep_right_bonus_mps2", 1.0)
	_pass_boost = maxf(0.0, _f("traffic.pass_boost_kmh", 10.0))
	_yield_hold = maxf(0.0, _f("traffic.side_yield_hold_m", 40.0))
	_cam_distance = _f("render.camera_distance_m", 6.6)
	_draw_distance = _f("render.draw_distance_m", 900.0)
	_rear_visible = _f("collision.rear_min_visible_fraction", 0.3333)
	_hitbox = _f("collision.hitbox_scale", 0.95)
	_bus_speeds = ConfigLoader.lookup(cfg, "traffic.bus_speeds_kmh", {})
	_bus_share = clampf(_f("traffic.bus_share", 0.25), 0.0, 1.0)
	_limit_tol = _vec2("traffic.limit_tolerance", Vector2(0.92, 1.12))
	_lane_spread = maxf(0.0, _f("traffic.lane_speed_spread", 1.4))
	_weather_cfg = ConfigLoader.lookup(cfg, "traffic.weather", {})
	_blink_lead = _vec2("traffic.blink.lead_s", Vector2(1.0, 1.5))
	_blink_heavy = maxf(0.0, _f("traffic.blink.heavy_factor", 1.3))
	_blink_mandatory = maxf(0.0, _f("traffic.blink.mandatory_lead_s", 1.0))
	_blink_max_wait = maxf(0.0, _f("traffic.blink.max_wait_s", 3.0))
	_zipper_m = maxf(0.0, _f("traffic.blink.zipper_m", 60.0))
	_cut_react = maxf(0.0, _f("traffic.cut_in.margin_s", 0.3))
	_cut_intrude = maxf(0.0, _f("traffic.cut_in.intrude_s", 0.5))
	_cut_brake_frac = clampf(_f("traffic.cut_in.brake_fraction", 0.7), 0.05, 1.0)
	_cut_margin = maxf(0.0, _f("traffic.cut_in.margin_m", 8.0))
	_cut_perceive = maxf(0.1, _f("traffic.cut_in.perceived_max_kmh", 72.0) / 3.6)
	_cut_judge = _vec2("traffic.cut_in.judge_s", Vector2(2.5, 5.0))
	_cut_judge_add = maxf(0.0, _f("traffic.cut_in.judge_add_m", 20.0))
	_el_min_lanes = int(_f("traffic.elephant.min_lanes", 3.0))
	_el_min_kmh = maxf(0.0, _f("traffic.elephant.min_diff_kmh", 3.0))
	_el_look = maxf(0.0, _f("traffic.elephant.look_m", 60.0))
	_el_bonus = _f("traffic.elephant.bonus_mps2", 1.0)
	_el_max_s = maxf(0.0, _f("traffic.elephant.max_s", 40.0))
	_el_retry = maxf(0.0, _f("traffic.elephant.retry_s", 60.0))
	_cluster_chance = ConfigLoader.lookup(cfg, "traffic.cluster.chance", {})
	var fol := _vec2("traffic.cluster.followers", Vector2(1.0, 3.0))
	_cluster_followers = Vector2i(maxi(0, int(fol.x)), maxi(0, int(fol.y)))
	_cluster_elephant = clampf(_f("traffic.cluster.elephant_share", 0.3), 0.0, 1.0)
	_cluster_gap = _vec2("traffic.cluster.gap_factor", Vector2(1.0, 1.5))
	_cluster_patience = _vec2("traffic.cluster.patience_s", Vector2(4.0, 20.0))
	player_brake_mps2 = _f("driving.brake_decel_kmh_s", 70.0) / 3.6


## [lo, hi] config array as Vector2 (default when missing or malformed).
func _vec2(path: String, default: Vector2) -> Vector2:
	var v: Variant = ConfigLoader.lookup(cfg, path, null)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return default


## Weather factors of the traffic (traffic.weather.<w>: speed_factor for cars, heavy_speed_factor for trucks/buses,
## follow_time_factor and min_gap_factor for the following distance, lane_change_factor, decel_factor for the
## comfortable and the strongest braking – like the player's braking, about grip^0.87). Unknown weather = normal.
func _apply_weather(w: String) -> void:
	weather = w
	var e: Variant = _weather_cfg.get(w, {})
	var d: Dictionary = e if e is Dictionary else {}
	_w_speed = maxf(0.05, float(d.get("speed_factor", 1.0)))
	_w_heavy = maxf(0.05, float(d.get("heavy_speed_factor", _w_speed)))
	_w_follow = maxf(0.1, float(d.get("follow_time_factor", 1.0)))
	_w_gap = maxf(0.1, float(d.get("min_gap_factor", 1.0)))
	_eff_gap = _min_gap * _w_gap
	_eff_follow = _follow_time * _w_follow
	_eff_lc_mps = _lane_change_mps * maxf(0.1, float(d.get("lane_change_factor", 1.0)))
	_w_margin = _w_speed
	# braking (review v0.5.0: in snow the traffic stopped with up to 8 m/s², close to the player's whole snow braking)
	var dec := clampf(float(d.get("decel_factor", 1.0)), 0.1, 1.0)
	_eff_comfort = _comfort * dec
	_eff_max_decel = _max_decel * dec


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


## Speed multiplier of the night window 23–4 (traffic.night.speed_factor; 1.0 since v0.5.0 – faster traffic
## at night made overtaking even easier).
func speed_factor(hour: float) -> float:
	return _night_speed if is_night_hour(hour) else 1.0


## Desired speed (km/h) of a vehicle class (0 car, 1 truck, 2 bus) with temperament frac (0..1) on road type
## `road` with the speed limit `limit` (0 = none) in the current weather and hour: the class range
## (traffic.speeds_kmh / truck_speeds_kmh / bus_speeds_kmh) at frac, capped by the limit (cars: limit *
## traffic.limit_tolerance at frac – careful drivers below it, fast ones a little above; heavy vehicles: the
## limit), times the weather factor of the class and speed_factor(hour).
func cruise_speed_for(road: String, cls: int, frac: float, limit: int = 0) -> float:
	var table := _speeds
	if cls == 1:
		table = _truck_speeds
	elif cls == 2:
		table = _bus_speeds if not _bus_speeds.is_empty() else _truck_speeds
	var r: Variant = table.get(road, null)
	var lo := 100.0
	var hi := 130.0
	if r is Array and (r as Array).size() >= 2:
		lo = float(r[0])
		hi = float(r[1])
	var v := lerpf(lo, hi, frac)
	if limit > 0:
		v = minf(v, float(limit) * (lerpf(_limit_tol.x, _limit_tol.y, frac) if cls == 0 else 1.0))
	return v * (_w_speed if cls == 0 else _w_heavy) * speed_factor(_hour)


## Desired speed (km/h) of the slowest vehicle on road type `road` with the speed limit `limit` (0 = none) in the
## current weather and hour: cars, trucks and buses at the careful end of their range (cruise_speed_for with
## frac 0); heavy = 0 only cars, 1 only trucks and buses, -1 all. The sight check of the traffic
## (tests/sim/sight_check.gd) brakes for it.
func slowest_speed_kmh(road: String, limit: int = 0, heavy: int = -1) -> float:
	var v := INF
	for cls in 3:
		if heavy < 0 or (heavy == 0) == (cls == 0):
			v = minf(v, cruise_speed_for(road, cls, 0.0, limit))
	return v


## Sets the weather of the traffic (speeds, gaps, braking) without an update – sight checks and tests.
func set_weather(w: String) -> void:
	_apply_weather(w)


## Vehicle class of a car: 0 car, 1 truck, 2 bus.
static func vehicle_class(c: Car) -> int:
	if not c.heavy:
		return 0
	return 2 if c.bus else 1


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

## player: {z, x, speed (, length, width)}; ctx: {hour: float, chase: bool, camera_z: float (, visibility_m,
## weather: "normal"|"rain"|"snow" – speeds and gaps of the traffic, brake_mps2: the player's full braking in this
## weather – the floor of the cut-ins, see _cut_in_ok)}.
## dt = 0 is allowed (spawns the initial traffic without moving anything).
func update(dt: float, player: Dictionary, ctx: Dictionary) -> void:
	if track == null:
		return
	var w := str(ctx.get("weather", weather))
	if w != weather:
		_apply_weather(w)
	player_brake_mps2 = maxf(0.5, float(ctx.get("brake_mps2", player_brake_mps2)))
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
		c.x = move_toward(c.x, _lane_x(c.z, c.lane), _eff_lc_mps * dt)
		c.in_fuel_lane = c.lane == FUEL_LANE or _right_of_main(c)
		c.braking = a < -_brake_light or c.speed < 2.0
		c.age += dt


## Cruise speed, lane validity, fuel-lane plan and lane-change decisions of one car.
func _think(c: Car, dt: float) -> void:
	var lanes := maxi(1, _t_lanes(c.z))
	var road := _t_road(c.z)
	c.cruise_speed = cruise_speed_for(road, vehicle_class(c), c.speed_frac, _t_limit(c.z))
	if c.lane != FUEL_LANE and c.lane >= lanes:
		c.lane = lanes - 1
	if c.lane == FUEL_LANE and not _fuel_lane_open_at(c.z) and not _t_fuel(c.z + 8.0):
		c.lane = lanes - 1
		c.fuel_state = 2
	c.lane_cooldown = maxf(0.0, c.lane_cooldown - dt)
	_update_elephant(c, lanes, dt)
	if c.signal_dir != 0:
		c.signal_age += dt
		if c.signal_lane == c.lane:
			# moving into the new lane: the indicator goes off once the car is (almost) there
			if absf(c.x - _lane_x(c.z, c.lane)) < 0.4:
				_clear_signal(c)
		else:
			_signal_step(c, lanes, road, dt)
			return
	c.lane_timer -= dt
	var urgent := _player_threat(c)
	if c.lane_timer > 0.0 and not urgent:
		return
	c.lane_timer = _lc_interval * (0.75 + 0.5 * fposmod(float(c.id) * 0.618034, 1.0))
	_update_fuel_plan(c, lanes)
	_side_plan(c, lanes, road)
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
	return gap < _eff_gap or (closing > 0.5 and gap / closing < 3.0)


## Picks the best lane (MOBIL). A wanted change starts the indicator (traffic.blink, _signal_step moves the car
## later); an emergency swerve away from the player (urgent) happens at once.
func _consider_lane_change(c: Car, lanes: int, road: String, urgent: bool) -> void:
	var cur := c.lane
	var cands: Array[int] = []
	var mandatory := -999
	var merge := false
	if cur == FUEL_LANE:
		cands.append(lanes - 1)
		if c.fuel_state != 1 or _lane_end_distance(c, FUEL_LANE, _blink_mandatory + 0.5) < INF:
			mandatory = lanes - 1
			merge = true
	else:
		if c.fuel_state == 1:
			if cur == lanes - 1 and _fuel_lane_open_at(c.z):
				cands.append(FUEL_LANE)
				mandatory = FUEL_LANE
			elif cur < lanes - 1:
				mandatory = cur + 1
		# a yielding car wants to get back to the right – it does not dodge to the left (unless evading the player)
		if cur > 0 and not (c.heavy and lanes >= 3 and cur - 1 == 0) and (c.yield_kmh < 0.0 or urgent):
			cands.append(cur - 1)
		if cur < lanes - 1:
			cands.append(cur + 1)
			# a truck that gave up its Elefantenrennen must get back to the right: it signals at once and the traffic
			# there lets it in (zipper) – otherwise it hovers in the middle lane at its yield speed
			if c.heavy and c.elephant_t >= _el_max_s and c.fuel_state != 1:
				mandatory = cur + 1
				merge = true
		if cur > 0 and _lane_end_distance(c, cur, _blink_mandatory) < INF:
			mandatory = cur - 1
			merge = true
	if cands.is_empty():
		return
	var a_cur := _idm(c, _desired_speed(c, cur), _leader(c, cur))
	var best_lane := cur
	var best_margin := 0.0
	var lead_s := 0.0 if urgent else _signal_lead(c, false)
	for lane in cands:
		var margin := _lane_margin(c, lane, a_cur, road, lanes, lane == mandatory, urgent,
			0.0 if urgent else (_blink_mandatory if lane == mandatory else lead_s))
		if margin > best_margin:
			best_margin = margin
			best_lane = lane
	if best_lane == cur:
		# its lane ends and there is no gap yet: it signals at once and waits (_signal_step) – the traffic there opens
		# the gap (zipper, _leader) instead of the car stopping at the end of its lane unannounced
		if merge and not urgent and cands.has(mandatory):
			_start_signal(c, mandatory, true, true)
		return
	_start_signal(c, best_lane, best_lane == mandatory, merge and best_lane == mandatory)
	if urgent:
		_execute_lane_change(c, lanes, road)


## MOBIL advantage of `lane` minus the threshold of this move (> 0 = worth it), -INF when unsafe. Trucks are
## reluctant to pull out to the left (traffic.truck_lane_change_threshold_mps2) unless a clearly slower vehicle
## holds them up on a road with 3+ lanes (Elefantenrennen, traffic.elephant.bonus_mps2).
func _lane_margin(c: Car, lane: int, a_cur: float, road: String, lanes: int, mandatory: bool, urgent: bool,
		lead_s: float) -> float:
	var threshold := _lc_threshold_truck if c.heavy and lane < c.lane else _lc_threshold
	if urgent:
		threshold = 0.05
	var gain := _lane_gain(c, lane, a_cur, road, mandatory, urgent, lead_s)
	if gain == -INF:
		return -INF
	if c.heavy and lane < c.lane and lane != FUEL_LANE and c.lane != FUEL_LANE and _elephant_wanted(c, lanes, road):
		gain += _el_bonus
	return gain - threshold


## Seconds the indicator runs before the car moves: traffic.blink.lead_s (per car between the two values),
## mandatory changes (lane ends, fuel lane) traffic.blink.mandatory_lead_s, heavy vehicles × heavy_factor.
func _signal_lead(c: Car, mandatory: bool) -> float:
	var lead := _blink_mandatory
	if not mandatory:
		lead = lerpf(_blink_lead.x, _blink_lead.y, fposmod(float(c.id) * 0.7548777, 1.0))
	return lead * (_blink_heavy if c.heavy else 1.0)


func _start_signal(c: Car, target: int, mandatory: bool, merge: bool = false) -> void:
	c.signal_lane = target
	c.signal_dir = -1 if target < c.lane else 1
	c.signal_mandatory = mandatory
	c.signal_merge = merge
	c.signal_t = _signal_lead(c, mandatory)
	c.signal_age = 0.0
	c.signal_wait = 0.0


func _clear_signal(c: Car) -> void:
	c.signal_dir = 0
	c.signal_lane = -1
	c.signal_t = 0.0
	c.signal_age = 0.0
	c.signal_wait = 0.0
	c.signal_mandatory = false
	c.signal_merge = false


## A car with its indicator on: it moves once the indicator has run its time and the target lane is still safe
## (the cut-in floor counts the time left); while unsafe it waits (traffic.blink.max_wait_s, then gives up), and
## it cancels when the change is no longer worth it.
func _signal_step(c: Car, lanes: int, road: String, dt: float) -> void:
	c.signal_t -= dt
	if c.signal_t <= 0.0:
		c.signal_wait += dt
	var target := c.signal_lane
	var valid := target == FUEL_LANE or (target >= 0 and target < lanes and absi(target - c.lane) == 1) \
		or (c.lane == FUEL_LANE and target == lanes - 1)
	if target == FUEL_LANE and (c.lane != lanes - 1 or c.fuel_state != 1):
		valid = false
	if not valid:
		_clear_signal(c)
		return
	c.lane_timer -= dt
	if c.signal_t > 0.0 and c.lane_timer > 0.0:
		return
	c.lane_timer = _lc_interval * (0.75 + 0.5 * fposmod(float(c.id) * 0.618034, 1.0))
	_update_fuel_plan(c, lanes)
	var a_cur := _idm(c, _desired_speed(c, c.lane), _leader(c, c.lane))
	var margin := _lane_margin(c, target, a_cur, road, lanes, c.signal_mandatory, false, maxf(c.signal_t, 0.0))
	if margin == -INF:
		if c.signal_wait > _blink_max_wait * (2.0 if c.signal_mandatory else 1.0) and not c.signal_merge:
			_clear_signal(c)   # no gap: gives up (a mandatory change signals again at the next decision)
			c.lane_cooldown = maxf(c.lane_cooldown, _lc_interval)
		return
	if margin < -0.15 and not c.signal_mandatory:
		_clear_signal(c)   # no longer worth it
		return
	if c.signal_t <= 0.0:
		_execute_lane_change(c, lanes, road)


## Moves the car into its signalled lane (the indicator stays on until it is there). Counts a cut-in in front of
## a faster player (cut_ins, last_cut_in).
func _execute_lane_change(c: Car, lanes: int, road: String) -> void:
	var target := c.signal_lane
	var foll := _follower(c, target)
	var p := player_obstacle
	if foll == p and target != FUEL_LANE and p.speed > c.speed + 2.0:
		var rel := (p.speed - c.speed) / 3.6
		cut_ins += 1
		last_cut_in = {"id": c.id, "gap_m": _gap(p, c), "rel_kmh": rel * 3.6, "floor_m": cut_in_floor_m(rel, 0.0),
			"car_kmh": c.speed, "player_kmh": p.speed}
	if c.heavy and target < c.lane and target != FUEL_LANE and c.lane != FUEL_LANE and _elephant_wanted(c, lanes, road):
		c.elephant_t = 0.0
	if c.lane == FUEL_LANE:
		c.fuel_state = 2
	c.lane = target
	c.lane_cooldown = _lc_cooldown
	c.yield_kmh = -1.0
	c.pass_kmh = -1.0
	c.signal_t = 0.0
	c.signal_wait = 0.0


## Elefantenrennen bookkeeping: seconds a heavy vehicle spends overtaking in a left lane (elephant_t), reset
## once it is back in the right lane – after giving up (traffic.elephant.max_s) it waits traffic.elephant.retry_s
## before it tries again.
func _update_elephant(c: Car, lanes: int, dt: float) -> void:
	if not c.heavy:
		return
	c.elephant_cool = maxf(0.0, c.elephant_cool - dt)
	if c.lane == FUEL_LANE or c.lane >= lanes - 1:
		if c.elephant_t >= _el_max_s:
			c.elephant_cool = _el_retry
		c.elephant_t = -1.0
	elif c.elephant_t >= 0.0:
		c.elephant_t += dt


## A heavy vehicle on a road with traffic.elephant.min_lanes+ lanes (not in the City Limits) is held up by a vehicle
## at least traffic.elephant.min_diff_kmh slower than it wants to go, within traffic.elephant.look_m: it overtakes.
func _elephant_wanted(c: Car, lanes: int, road: String) -> bool:
	if not c.heavy or road == "city" or lanes < _el_min_lanes or c.lane <= 0 or c.lane == FUEL_LANE \
			or c.elephant_cool > 0.0:
		return false
	var lead := _leader(c, c.lane)
	if lead == null or lead == player_obstacle:
		return false
	return _gap(c, lead) < _el_look and lead.speed <= c.cruise_speed - _el_min_kmh


## No rolling roadblocks (two cars of about the same speed side by side, or one just ahead of the other in
## neighbouring lanes, block a road for minutes). A car in a left lane looks at the traffic cars in the lane to
## its right between traffic.side_window_behind_m behind and traffic.side_window_ahead_m ahead that it is not
## already clearly faster than (margin m = traffic.yield_speed_margin_kmh):
##  * PASS decisively when they are at most m faster than it wants to go and it can be clearly (m) faster
##    within its speed range: desired speed min(max(own cruise, their speed) + traffic.pass_boost_kmh, top of
##    its range) (pass_kmh) – it overtakes them and keeps right once it is clear
##  * otherwise (a clearly faster car comes up on the right, or it cannot be clearly faster) YIELD: drop back
##    to their speed - traffic.yield_slowdown_kmh (never above its own cruise), let them pass and keep right
##    behind them (MOBIL keep-right bias + traffic.yield_keep_right_bonus_mps2, no dodging to the left) – until
##    they are traffic.side_yield_hold_m beyond the window (hysteresis: no hovering at the window's edge)
## The speed margins are dry values and shrink with the weather speed factor (snow × 0.65).
## A faster car that is only held back by a slow car ahead in its own lane passes as soon as that one is
## gone. The player never counts: he controls his own speed, and a car matching it would stay beside him and
## block his overtaking lane. Exception (v0.5.0): a truck overtaking a slower heavy vehicle (Elefantenrennen)
## keeps its own pace for traffic.elephant.max_s – two lanes blocked at truck speed – and then gives up (drops
## back behind it).
func _side_plan(c: Car, lanes: int, road: String) -> void:
	var was_yielding := c.yield_kmh >= 0.0
	c.yield_kmh = -1.0
	c.pass_kmh = -1.0
	if c.lane == FUEL_LANE or c.lane >= lanes - 1 or c.fuel_state == 1 or not _lane_usable(c, c.lane + 1):
		return
	var gave_up := false
	if c.heavy and c.elephant_t >= 0.0:
		if c.elephant_t < _el_max_s:
			return
		gave_up = true
	var plan := _side_decision(c.z, c.lane, c.cruise_speed, vehicle_class(c), road, c, not gave_up,
		_yield_hold if was_yielding else 0.0)
	if plan.x > 0.0:
		c.pass_kmh = plan.y
	elif plan.x < 0.0:
		c.yield_kmh = plan.y


## Side decision for a car (cruise speed, class) at (z, lane) – see _side_plan: Vector2(1, desired speed) =
## pass, Vector2(-1, speed to drop back to) = yield, Vector2.ZERO = nothing to do. `self_car` is skipped;
## may_pass = false (a truck that gave up its Elefantenrennen): only yielding is possible, and every heavy vehicle
## beside it counts, however much slower; extra_ahead_m widens the window ahead (a car that yields keeps
## dropping back until it is traffic.side_yield_hold_m further behind – otherwise it would hover at the edge of
## the window, e.g. beside a player who follows the slower vehicle). The speed margins scale with the weather
## (traffic.weather.<w>.speed_factor): in snow every speed is about a third lower, so are the differences.
func _side_decision(z: float, lane: int, cruise: float, cls: int, road: String, self_car: Car = null,
		may_pass: bool = true, extra_ahead_m: float = 0.0) -> Vector2:
	var margin := _yield_margin * _w_margin
	var v_max := -1.0
	var v_min := INF
	for o in cars:
		if o == self_car:
			continue
		var dz := o.z - z
		if dz < -_side_behind or dz > _side_ahead + extra_ahead_m:
			continue
		if not _occupies(o, lane + 1):
			continue
		if o.speed + margin <= cruise and (may_pass or not o.heavy):
			continue   # clearly slower than this car wants to go: an ordinary overtake – unless a truck gave up its
			# Elefantenrennen: then the heavy vehicle beside it counts (in snow the margin shrinks to 3.9 km/h, a race
			# at 5 km/h difference took over 2 minutes)
		v_max = maxf(v_max, o.speed)
		v_min = minf(v_min, o.speed)
	if v_max < 0.0:
		return Vector2.ZERO
	var top := maxf(cruise, cruise_speed_for(road, cls, 1.0, _t_limit(z)))
	if may_pass and _pass_boost > 0.0 and v_max <= cruise + margin and top >= v_max + margin:
		return Vector2(1.0, minf(maxf(cruise, v_max) + _pass_boost * _w_margin, top))
	if _yield_slow > 0.0:
		return Vector2(-1.0, maxf(0.0, v_min - _yield_slow * _w_margin))   # below all of them, then keep right
	return Vector2.ZERO


## MOBIL: advantage (m/s²) of moving to `lane`, -INF when unsafe or not allowed. lead_s = seconds until the car
## really moves (indicator time left): a cut-in in front of the player is judged with it (_cut_in_ok).
func _lane_gain(c: Car, lane: int, a_cur: float, road: String, mandatory: bool, urgent: bool,
		lead_s: float = 0.0) -> float:
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
	if foll == player_obstacle:
		if not _cut_in_ok(c, lead_s):
			return -INF
	elif foll != null:
		var a_f_new := _idm(foll, _desired_speed(foll, foll.lane), c)
		if a_f_new < -_lc_safe:
			return -INF
		var a_f_old := _idm(foll, _desired_speed(foll, foll.lane), _leader(foll, foll.lane))
		f_loss = maxf(0.0, a_f_old - a_f_new)
		if lane > c.lane and a_f_new > -1.0:
			f_loss = 0.0   # keeping right well ahead of the traffic there: no politeness (no slow car lingers left)
	var gain := a_new - a_cur - _politeness * f_loss
	if lane != FUEL_LANE and c.lane != FUEL_LANE:
		var kr := float(_keep_right.get(road, 0.0))
		gain += kr if lane > c.lane else -kr
		if lane > c.lane and c.yield_kmh >= 0.0:
			gain += _yield_bonus   # yielding: back to the right as soon as it is safe
	if mandatory:
		gain += 10.0
	return gain


## A lane change with the player as the new follower (he comes up behind in the target lane). Traffic does not
## clear the way any more: a driver judges a car in the mirror by the gap and a closing speed of at most
## traffic.cut_in.perceived_max_kmh, wanting traffic.cut_in.judge_s of it (bold = fast drivers the shorter
## value) plus judge_add_m – a fast player gets cut off. Never closer than the fairness floor
## (cut_in_floor_m): reacting to the indicator, the player can still brake in time. A player who is not faster
## than the car: the ordinary MOBIL safety (no braking harder than traffic.lane_change_safe_decel_mps2).
func _cut_in_ok(c: Car, lead_s: float) -> bool:
	var p := player_obstacle
	var gap := _gap(p, c)
	var rel := (p.speed - c.speed) / 3.6
	if rel <= 0.5:
		return _idm(p, p.cruise_speed, c) >= -_lc_safe
	if gap < cut_in_floor_m(rel, lead_s):
		return false
	var judge := lerpf(_cut_judge.y, _cut_judge.x, c.speed_frac)
	return gap >= minf(rel, _cut_perceive) * judge + _cut_judge_add


## Smallest gap (m, player front to car rear) at which a car may start a lane change in front of a player closing
## in at rel_mps, lead_s seconds before it moves: the car blocks his lane after lead_s + traffic.cut_in.intrude_s;
## with traffic.cut_in.margin_s more to react, the player then brakes with traffic.cut_in.brake_fraction of his
## full braking (ctx.brake_mps2 – weather!) and stops closing in traffic.cut_in.margin_m behind it.
func cut_in_floor_m(rel_mps: float, lead_s: float = 0.0) -> float:
	if rel_mps <= 0.0:
		return _cut_margin
	var a := maxf(0.5, player_brake_mps2 * _cut_brake_frac)
	return rel_mps * (maxf(lead_s, 0.0) + _cut_intrude + _cut_react) + rel_mps * rel_mps / (2.0 * a) + _cut_margin


func _lane_usable(c: Car, lane: int) -> bool:
	if lane == FUEL_LANE:
		return _fuel_lane_open_at(c.z) and _t_fuel(c.z + 25.0)
	if lane < 0 or lane >= _t_lanes(c.z):
		return false
	return _lane_end_distance(c, lane) == INF


## Acceleration (m/s²) of a car: IDM towards its leader, plus a stop before the end of its lane. Braking is limited
## by the weather (traffic.weather.<w>.decel_factor) – except behind the player: he may brake with his full
## braking or cut in, and traffic must never run into him (the dry limit, as before).
func _accel_for(c: Car) -> float:
	var v0 := _desired_speed(c, c.lane)
	var lead := _leader(c, c.lane)
	var a := _idm(c, v0, lead)
	var end_d := _cached_lane_end(c)
	if end_d < INF:
		var a_max := _acc_truck if c.heavy else _acc_car
		a = minf(a, _idm_free(c, v0, a_max) + _idm_interaction(c, a_max, 0.0, end_d - c.length * 0.5 - 3.0))
	var limit := _max_decel if lead == player_obstacle else _eff_max_decel
	return clampf(a, -limit, _acc_truck if c.heavy else _acc_car)


func _desired_speed(c: Car, lane: int) -> float:
	if c == player_obstacle:
		return c.cruise_speed
	var v := c.cruise_speed
	if lane == c.lane and c.yield_kmh >= 0.0:
		v = minf(v, c.yield_kmh)   # not overtaking the car beside it: drop back, then keep right
	elif c.pass_kmh >= 0.0 and (lane == c.lane or lane == c.lane + 1):
		v = maxf(v, c.pass_kmh)    # passing decisively (also when judging the merge back to the right)
	if lane == FUEL_LANE or c.in_fuel_lane:
		v = minf(v, _fuel_speed)
	elif c.fuel_state == 1:
		# heading for the fuel lane: brake just in time to enter it at fuel_lane_speed_kmh
		var d := _fuel_lane_ahead(c.z)
		if d < INF:
			var vf := _fuel_speed / 3.6
			v = minf(v, sqrt(vf * vf + 2.0 * _eff_comfort * 0.6 * maxf(0.0, d - 10.0)) * 3.6)
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
	return -minf(_eff_comfort, 0.4 * (v - vd) + 0.2)


## IDM interaction term. Minimum gap and time gap of the current weather (traffic.weather.<w>: longer in rain
## and snow).
func _idm_interaction(c: Car, a_max: float, v_lead: float, gap: float) -> float:
	var v := c.speed / 3.6
	var s_star := _eff_gap + maxf(0.0, v * _eff_follow + v * (v - v_lead) / (2.0 * sqrt(a_max * _eff_comfort)))
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
# City Limits, traffic factor, speed limit (0 = none)]. Buckets far behind the player are dropped.

func _tq_bucket(b: int) -> Array:
	var e: Variant = _tq_cache.get(b, null)
	if e == null:
		var z := float(b) * TQ_BUCKET
		var limit := int(track.speed_limit_at(z)) if track.has_method("speed_limit_at") else 0
		e = [int(track.lane_count_at(z)), float(track.lane_center_x(z, 0)), bool(track.fuel_lane_at(z)),
			float(track.fuel_lane_x(z)), str(track.road_type_at(z)), bool(track.is_city_at(z)),
			float(track.traffic_factor_at(z)), limit]
		_tq_cache[b] = e
	return e


## Speed limit at z (km/h, 0 = none) from the geometry cache.
func _t_limit(z: float) -> int:
	return int(_tq(z)[7])


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
## Zipper (Reißverschluss): a car that must leave its lane (lane end, fuel lane exit – signal_merge) and signals into
## `lane` counts as soon as it is within traffic.blink.zipper_m ahead, so the traffic there opens the gap instead of
## letting it stop at the end of its lane (QA v0.5.0: merge queues standing on the autobahn before the City Limits).
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
				or (o.occ_fuel if fuel else (lane >= o.occ_lo and lane <= o.occ_hi)) \
				or (o.signal_merge and o.signal_lane == lane and oz - cz < _zipper_m \
					and oz - cz - (o.length + c.length) * 0.5 >= _lc_min_gap):
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
## extra_s: look that many seconds further (the decision to leave signals first, traffic.blink.mandatory_lead_s).
func _lane_end_distance(c: Car, lane: int, extra_s: float = 0.0) -> float:
	var look: float
	if lane == FUEL_LANE:
		look = 25.0 + c.speed / 3.6 * (1.5 + extra_s)
	else:
		look = 60.0 + c.speed / 3.6 * (_merge_look_s + extra_s)
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

func _is_heavy(road: String, roll: float) -> bool:
	if heavy_sets.is_empty():
		return false
	if car_sets.is_empty():
		return true
	return roll < float(_truck_share.get(road, 0.1))


## Sprite set and class [set_id, cls] (0 car, 1 truck, 2 bus) of a new vehicle: heavy vehicles are buses with
## traffic.bus_share (when there are bus sets), the rest of the roll picks the colour.
func _pick_set(heavy: bool, set_roll: float) -> Array:
	if not heavy:
		if car_sets.is_empty():
			return ["", 0]
		return [car_sets[mini(int(set_roll * car_sets.size()), car_sets.size() - 1)], 0]
	var bus := not _bus_sets.is_empty() and (_truck_sets.is_empty() or set_roll < _bus_share)
	var r := set_roll
	if not _bus_sets.is_empty() and not _truck_sets.is_empty():
		r = set_roll / maxf(_bus_share, 0.0001) if bus else (set_roll - _bus_share) / maxf(0.0001, 1.0 - _bus_share)
	var sets := _bus_sets if bus else _truck_sets
	if sets.is_empty():
		return ["", 1]
	return [sets[mini(int(clampf(r, 0.0, 0.9999) * sets.size()), sets.size() - 1)], 2 if bus else 1]


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


## Lanes to try for a new vehicle, preferred first. Heavy vehicles: the right lane (on 3+ lanes some are just
## overtaking in the second lane from the right: trucks 15 %, buses 30 %). Cars by speed – fast ones left, slow
## ones right: (1 - frac) * (lanes - 1) ± traffic.lane_speed_spread / 2 (roll), then the others, nearest first.
func _lane_order(lanes: int, cls: int, roll: float, frac: float) -> Array[int]:
	var order: Array[int] = []
	if cls != 0:
		order.append(lanes - 2 if lanes >= 3 and roll < (0.3 if cls == 2 else 0.15) else lanes - 1)
		return order
	var pick := lanes - 1
	if lanes > 1:
		pick = clampi(int(roundf((1.0 - frac) * float(lanes - 1) + (roll - 0.5) * _lane_spread)), 0, lanes - 1)
	order.append(pick)
	for d in range(1, lanes):
		for l: int in [pick + d, pick - d]:
			if l >= 0 and l < lanes:
				order.append(l)
	return order


## Traffic at the start (during the countdown): the managed window ahead, singles and clusters.
func _initial_fill() -> void:
	var p := player_obstacle
	var z0 := p.z + 60.0
	var z1 := minf(p.z + _spawn_ahead, float(track.length_z) - 30.0)
	if z1 <= z0:
		return
	var share := (z1 - z0) / maxf(1.0, _spawn_ahead + _despawn_behind)
	var n := int(roundf(target_count * share))
	var made := 0
	for i in n:
		if made >= n:
			break
		var z := z0 + (z1 - z0) * (float(i) + rng.randf()) / float(n)
		var road := _t_road(z)
		if z + 260.0 < z1 and n - made >= 2 and rng.randf() < float(_cluster_chance.get(road, 0.0)):
			var followers := rng.randi_range(_cluster_followers.x, maxi(_cluster_followers.x, _cluster_followers.y))
			var size := mini(n - made, 1 + followers)
			var k := _spawn_cluster(z, road, size)
			if k > 0:
				made += k
				continue
		if _try_spawn(z, rng.randf(), rng.randf(), rng.randf(), rng.randf(), false) != null:
			made += 1


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
		var cls_b := int(_pick_set(_is_heavy(road_b, heavy_roll), set_roll)[1])
		if cruise_speed_for(road_b, cls_b, frac, _t_limit(z_behind)) > p.speed + 8.0:
			_try_spawn(z_behind, frac, heavy_roll, lane_roll, set_roll, true)
			return
	if z_ahead < float(track.length_z) - 30.0:
		var road := _t_road(z_ahead)
		if _pending == 0:
			# the next group: a single vehicle, or with traffic.cluster.chance a cluster of 1 + followers
			_pending = 1
			if rng.randf() < float(_cluster_chance.get(road, 0.0)):
				_pending = 1 + rng.randi_range(_cluster_followers.x, maxi(_cluster_followers.x, _cluster_followers.y))
		# a cluster waits until the window misses that many vehicles: an empty stretch, then the group – the
		# average density stays the same
		var n := mini(_pending, maxi(1, wanted_count()))
		if wanted_count() - cars.size() < n:
			return
		_pending = 0
		if n >= 2 and _spawn_cluster(z_ahead, road, n) > 0:
			return
		_try_spawn(z_ahead, frac, heavy_roll, lane_roll, set_roll, false)


## One new vehicle at z (lane by class and speed, see _lane_order) or null when there is no room.
func _try_spawn(z: float, frac: float, heavy_roll: float, lane_roll: float, set_roll: float, behind: bool) -> Car:
	var road := _t_road(z)
	var pick := _pick_set(_is_heavy(road, heavy_roll), set_roll)
	var set_id := str(pick[0])
	if set_id == "":
		return null
	var cls := int(pick[1])
	var lanes := maxi(1, _t_lanes(z))
	var cruise := cruise_speed_for(road, cls, frac, _t_limit(z))
	for lane in _lane_order(lanes, cls, lane_roll, frac):
		if behind and _occupies(player_obstacle, lane):
			continue
		var speed := cruise
		if not behind:
			# do not appear faster than a slow car right ahead in the same lane
			for o in cars:
				if o.z > z and o.z - z < 220.0 and _occupies(o, lane):
					speed = minf(speed, o.speed)
		if lane < lanes - 1 and cls == 0 and _side_decision(z, lane, cruise, cls, road).x < 0.0:
			continue   # would have to yield to an about equally fast car on its right at once
		var c := _place(z, lane, frac, set_id, cls, speed, behind)
		if c != null:
			return c
	return null


## Creates a vehicle at (z, lane) when the lane has room there (_space_free); null otherwise. A heavy vehicle left
## of the right lane is overtaking (elephant_t = 0).
func _place(z: float, lane: int, frac: float, set_id: String, cls: int, speed: float, behind: bool) -> Car:
	var dims := _dims_for(set_id, cls != 0)
	if not _space_free(z, lane, dims.x, speed):
		return null
	var c := Car.new()
	c.id = _next_id
	_next_id += 1
	c.z = z
	c.lane = lane
	c.x = _lane_x(z, lane)
	c.speed_frac = frac
	c.cruise_speed = cruise_speed_for(_t_road(z), cls, frac, _t_limit(z))
	c.speed = speed
	c.set_id = set_id
	c.length = dims.x
	c.width = dims.y
	c.height = dims.z
	c.heavy = cls != 0
	c.bus = cls == 2
	c.from_behind = behind
	c.lane_timer = _lc_interval
	if c.heavy and lane < maxi(1, _t_lanes(z)) - 1:
		c.elephant_t = 0.0
	_update_occ(c)
	cars.append(c)
	spawned_total += 1
	return c


## A cluster of n new vehicles beyond the view, its rear end at z (traffic.cluster): on roads with
## traffic.elephant.min_lanes+ lanes with traffic.cluster.elephant_share an Elefantenrennen (a truck overtaking a
## slower one, cars held up behind both), else a platoon (a slow leader – truck, bus or slow car – with the other
## cars held up behind it). Returns the number of vehicles placed.
func _spawn_cluster(z: float, road: String, n: int) -> int:
	var lanes := maxi(1, _t_lanes(z))
	if n >= 2 and not _truck_sets.is_empty() and road != "city" and lanes >= maxi(2, _el_min_lanes) \
			and rng.randf() < _cluster_elephant:
		var k := _spawn_elephant(z, road, lanes, n)
		if k > 0:
			return k
	return _spawn_platoon(z, road, n)


## Gap (m, bumper to bumper) of a follower in a cluster at speed v_kmh: traffic.cluster.gap_factor × the IDM
## equilibrium gap of the weather.
func _cluster_gap_m(v_kmh: float) -> float:
	return (_eff_gap + v_kmh / 3.6 * _eff_follow) * rng.randf_range(_cluster_gap.x, maxf(_cluster_gap.x, _cluster_gap.y))


## Cars queued behind `lead` in its lane (n of them, each wanting to go faster, all at its speed). They stay in the
## queue for traffic.cluster.patience_s before they try to overtake – so the player meets the platoon.
func _queue_behind(lead: Car, n: int, road: String) -> int:
	var made := 0
	var prev := lead
	for i in n:
		var pick := _pick_set(false, rng.randf())
		if str(pick[0]) == "":
			break
		var frac := rng.randf_range(0.35, 1.0)
		var dims := _dims_for(str(pick[0]), false)
		var zf := prev.z - (prev.length + dims.x) * 0.5 - _cluster_gap_m(lead.speed)
		var v := minf(lead.speed, cruise_speed_for(road, 0, frac, _t_limit(zf)))
		var c := _place(zf, lead.lane, frac, str(pick[0]), 0, v, false)
		if c == null:
			break
		c.lane_cooldown = rng.randf_range(_cluster_patience.x, maxf(_cluster_patience.x, _cluster_patience.y))
		made += 1
		prev = c
	return made


## Platoon of n: a slow leader (heavy with 2.5 × the truck share of the road, else a slow car) and n - 1 cars
## behind it.
func _spawn_platoon(z: float, road: String, n: int) -> int:
	var heavy_chance := minf(0.85, float(_truck_share.get(road, 0.1)) * 2.5)
	var heavy := not heavy_sets.is_empty() and (car_sets.is_empty() or rng.randf() < heavy_chance)
	var frac := rng.randf() * (1.0 if heavy else 0.45)
	var v := cruise_speed_for(road, 1 if heavy else 0, frac, _t_limit(z))
	var length := 17.0
	for i in n - 1:
		length += (_eff_gap + v / 3.6 * _eff_follow) * maxf(_cluster_gap.x, _cluster_gap.y) + 5.5
	var leader := _try_spawn(z + length, frac, 0.0 if heavy else 0.9999, rng.randf(), rng.randf(), false)
	if leader == null:
		return 0
	return 1 + _queue_behind(leader, n - 1, road)


## Elefantenrennen of n vehicles: a slow truck in the right lane, a faster one overtaking it in the lane to its left
## (already some seconds into it), the other n - 2 cars queued behind them.
func _spawn_elephant(z: float, road: String, lanes: int, n: int) -> int:
	var right := lanes - 1
	var left := lanes - 2
	var limit := _t_limit(z)
	var fa := rng.randf_range(0.0, 0.45)
	var fb := minf(1.0, fa + rng.randf_range(0.35, 0.6))
	var va := cruise_speed_for(road, 1, fa, limit)
	var vb := cruise_speed_for(road, 1, fb, limit)
	if vb - va < _el_min_kmh * _w_heavy:
		return 0   # a speed limit flattened the truck range
	var n_left := rng.randi_range(0, maxi(0, n - 2))
	var n_right := maxi(0, n - 2 - n_left)
	var off := rng.randf_range(0.0, 12.0)   # centre of the overtaking truck behind the centre of the other one
	var room := (_eff_gap + va / 3.6 * _eff_follow) * maxf(_cluster_gap.x, _cluster_gap.y) + 5.5
	var za := z + 9.0 + off + room * float(maxi(n_left, n_right))
	var sa := _pick_set(true, _bus_share + rng.randf() * (1.0 - _bus_share))
	var sb := _pick_set(true, _bus_share + rng.randf() * (1.0 - _bus_share))
	var a := _place(za, right, fa, str(sa[0]), int(sa[1]), va, false)
	if a == null:
		return 0
	var b := _place(za - off, left, fb, str(sb[0]), int(sb[1]), vb, false)
	if b == null:
		return 1
	b.elephant_t = rng.randf_range(0.0, _el_max_s * 0.4)
	return 2 + _queue_behind(b, n_left, road) + _queue_behind(a, n_right, road)


## True when (z, lane) has room for a new vehicle of this length and speed: the IDM gap of the weather (at least
## traffic.spawn_min_gap_m) plus 4 s of any speed difference to the vehicles ahead and behind in that lane.
func _space_free(z: float, lane: int, length: float, speed: float) -> bool:
	for i in cars.size() + 1:
		var o := cars[i] if i < cars.size() else player_obstacle
		if not _occupies(o, lane):
			continue
		var dz := o.z - z
		var need := (o.length + length) * 0.5 + maxf(_spawn_min_gap, _eff_gap + maxf(speed, o.speed) / 3.6 * _eff_follow)
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


## Free lateral metres left/right of a car of half length half_len at (z, x), limited by the road edges
## (pass the edges including the shoulder). Only cars BESIDE count: `exclude` (the car just hit) and every
## car whose body covers x (in line, i.e. ahead of or behind the player, like the hit car of a centre hit)
## are skipped – otherwise the hit car would block the side its centre happens to be on by a few cm, and the
## centre-hit rule "side with more space, equal space -> left" could never apply.
func space_beside(z: float, x: float, half_len: float, left_edge: float, right_edge: float, exclude: Object = null) -> Vector2:
	var left := x - left_edge
	var right := right_edge - x
	for c in cars:
		if c == exclude:
			continue
		if absf(c.z - z) >= half_len + c.length * 0.5 + 1.0:
			continue
		if absf(c.x - x) < c.width * 0.5:
			continue   # in line (ahead/behind): blocks neither side
		if c.x < x:
			left = minf(left, x - c.x - c.width * 0.5)
		else:
			right = minf(right, c.x - x - c.width * 0.5)
	return Vector2(maxf(left, 0.0), maxf(right, 0.0))
