class_name FuelSystem
extends RefCounted
## Fuel, fuel stations, fuel lane and towing – pure logic. Owner: gameplay module.
## Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
## Rules, decisions and tuning numbers: docs/gameplay.md.
##
## Rules (design document "Tanken"):
##  * consumption (L/100 km) = base + quad_coeff * v² (14 + 0.00034 v²), times the vehicle factor;
##    consumption counts odometer km
##  * stations from the StagePlan; announcements 30 / 15 / 5 km before, once per station (signal announced)
##  * fuel lane on the right = the last 1–2 km before the station (StagePlan.fuel_lanes).
##    In the lane and below fuel.lane_trigger_speed_kmh (60) the refuelling runs automatically: the car
##    stops (control_request), duration = refuel_fixed_s + refuel_s_per_5l per 5 litres needed (empty
##    50 L tank: 5 + 20 = 25 s); the litres flow after the fixed part. HUD: "Volltanken?" /
##    "Gas = Weiterfahren" while state == REFUELING. A FRESH throttle press (not a held pedal) aborts and
##    keeps the litres pumped so far. Faster than 60 the car simply drives through the lane.
##  * empty tank: the car rolls to a stop (control_request; it can still roll into a fuel lane and refuel),
##    then the tow service: TOWING for fuel.tow_overlay_s seconds, time penalty fuel.tow_penalty_s
##    (take_penalty()), tank refilled to fuel.tow_refill_fraction

enum State { NORMAL, REFUELING, TOWING }

signal announced(km_before: int, station_km: float)
signal refuel_started
signal refuel_finished(liters: float, aborted: bool)
signal ran_dry
signal tow_finished(penalty_s: float)
## Addition: fuel dropped below fuel.reserve_warning_l (once until refuelled).
signal reserve_reached

var cfg: Dictionary = {}
var plan: StagePlan
var tank_l := 50.0
var fuel_l := 50.0
var consumption_factor := 1.0
var state: int = State.NORMAL
var refuel_progress := 0.0       ## 0..1 of the running refuel
var refuel_time_left := 0.0      ## seconds
var liters_added := 0.0          ## litres of the running/last refuel
# --- additions ---
var refuel_duration := 0.0       ## total duration of the running/last refuel (s)
var refuel_elapsed := 0.0        ## seconds since the running refuel started
var liters_needed := 0.0         ## litres missing when the running refuel started
var pumping := false             ## litres are flowing (after the fixed part)
var rolling_out := false         ## tank empty, the car rolls to a stop before the tow service comes
var tow_time_left := 0.0         ## seconds of the tow overlay left
var odometer_km := 0.0           ## odometer km driven since setup (consumption basis)
var liters_used := 0.0           ## litres consumed since setup
var low_fuel := false            ## below fuel.reserve_warning_l

var _penalty := 0.0
var _announced: Dictionary = {}
var _throttle_prev := 0.0
var _abort_armed := false
var _lane_lock := false
var _fuel_at_start := 0.0
var _station_km := -1.0
# cached configuration
var _base := 14.0
var _quad := 0.00034
var _announce: Array[int] = []
var _trigger := 60.0
var _fixed_s := 5.0
var _per5_s := 2.0
var _stop_decel := 50.0
var _dry_decel := 18.0
var _min_refuel := 1.0
var _reserve := 8.0
var _tow_penalty := 90.0
var _tow_refill := 0.5
var _tow_overlay := 4.0
var _press := 0.5
var _release := 0.15
var _announce_window := 1.5


func setup(config: Dictionary, vehicle_spec: Dictionary, stage_plan: StagePlan) -> void:
	cfg = config
	plan = stage_plan
	_read_config()
	tank_l = float(vehicle_spec.get("tank_l", ConfigLoader.lookup(config, "vehicles.base_tank_l", 50.0)))
	consumption_factor = float(vehicle_spec.get("consumption_factor", 1.0))
	var fill := float(ConfigLoader.lookup(config, "fuel.start_fill_fraction", 1.0))
	if stage_plan != null and stage_plan.start_fuel_fraction >= 0.0:
		fill = stage_plan.start_fuel_fraction   # e.g. the tutorial starts with a partly filled tank
	fuel_l = tank_l * fill
	state = State.NORMAL
	refuel_progress = 0.0
	refuel_time_left = 0.0
	refuel_duration = 0.0
	refuel_elapsed = 0.0
	liters_added = 0.0
	liters_needed = 0.0
	pumping = false
	rolling_out = false
	tow_time_left = 0.0
	odometer_km = 0.0
	liters_used = 0.0
	low_fuel = false
	_penalty = 0.0
	_announced.clear()
	_throttle_prev = 0.0
	_abort_armed = false
	_lane_lock = false
	_station_km = -1.0


func _f(path: String, default: float) -> float:
	return float(ConfigLoader.lookup(cfg, path, default))


func _read_config() -> void:
	_base = _f("fuel.base_l_per_100km", 14.0)
	_quad = _f("fuel.quad_coeff", 0.00034)
	_announce.clear()
	for k in ConfigLoader.lookup(cfg, "fuel.announce_km", [30, 15, 5]):
		_announce.append(int(k))
	_announce.sort()
	_announce.reverse()
	_trigger = _f("fuel.lane_trigger_speed_kmh", 60.0)
	_fixed_s = _f("fuel.refuel_fixed_s", 5.0)
	_per5_s = _f("fuel.refuel_s_per_5l", 2.0)
	_stop_decel = _f("fuel.stop_decel_kmh_s", 50.0)
	_dry_decel = _f("fuel.dry_coast_decel_kmh_s", 18.0)
	_min_refuel = _f("fuel.min_refuel_l", 1.0)
	_reserve = _f("fuel.reserve_warning_l", 8.0)
	_tow_penalty = _f("fuel.tow_penalty_s", 90.0)
	_tow_refill = _f("fuel.tow_refill_fraction", 0.5)
	_tow_overlay = _f("fuel.tow_overlay_s", 4.0)
	_press = _f("fuel.abort_press_threshold", 0.5)
	_release = _f("fuel.abort_release_threshold", 0.15)
	_announce_window = _f("fuel.announce_window_km", 1.5)


static func base_consumption(config: Dictionary, speed_kmh: float) -> float:
	return float(ConfigLoader.lookup(config, "fuel.base_l_per_100km", 14.0)) + float(ConfigLoader.lookup(config, "fuel.quad_coeff", 0.00034)) * speed_kmh * speed_kmh


## Litres per 100 odometer km at speed, for this vehicle.
func consumption_per_100km(speed_kmh: float) -> float:
	return (_base + _quad * speed_kmh * speed_kmh) * consumption_factor


## Remaining range (odometer km) at the given speed (at least 60 km/h is assumed).
func range_km(speed_kmh: float) -> float:
	return fuel_l / consumption_per_100km(maxf(speed_kmh, 60.0)) * 100.0


## Distance (km) to the next station ahead, -1 if none.
func distance_to_next_station(pos_km: float) -> float:
	var s := plan.next_station_km(pos_km) if plan else -1.0
	return s - pos_km if s >= 0.0 else -1.0


## Duration (s) of a refuel that fills `liters`: fixed part + refuel_s_per_5l per 5 litres.
func refuel_duration_for(liters: float) -> float:
	return _fixed_s + _per5_s * maxf(liters, 0.0) / 5.0


## Called every physics frame. delta_km = odometer km driven this frame; throttle = raw pedal 0..1.
func update(dt: float, pos_km: float, delta_km: float, speed_kmh: float, in_fuel_lane: bool, throttle: float) -> void:
	if not in_fuel_lane or speed_kmh > _trigger:
		_lane_lock = false
	match state:
		State.NORMAL:
			_consume(delta_km, speed_kmh)
			_announce_stations(pos_km)
			if fuel_l <= 0.0 and not rolling_out:
				rolling_out = true
				ran_dry.emit()
			if in_fuel_lane and speed_kmh < _trigger and not _lane_lock and tank_l - fuel_l >= _min_refuel and _lane_valid(pos_km):
				_start_refuel(pos_km, throttle)
			elif rolling_out and speed_kmh <= 0.5:
				rolling_out = false
				state = State.TOWING
				tow_time_left = _tow_overlay
		State.REFUELING:
			_update_refuel(dt, throttle)
		State.TOWING:
			tow_time_left -= dt
			if tow_time_left <= 0.0:
				tow_time_left = 0.0
				_penalty += _tow_penalty
				fuel_l = maxf(fuel_l, tank_l * _tow_refill)
				state = State.NORMAL
				_check_reserve()
				tow_finished.emit(_tow_penalty)
	_throttle_prev = throttle


func _consume(delta_km: float, speed_kmh: float) -> void:
	if delta_km <= 0.0:
		return
	odometer_km += delta_km
	var used := minf(fuel_l, consumption_per_100km(speed_kmh) * delta_km / 100.0)
	fuel_l -= used
	liters_used += used
	_check_reserve()


func _check_reserve() -> void:
	if fuel_l < _reserve and fuel_l > 0.0:
		if not low_fuel:
			low_fuel = true
			reserve_reached.emit()
	elif fuel_l >= _reserve:
		low_fuel = false


## Announcements 30 / 15 / 5 km before every station, each once. Several thresholds crossed in one
## frame give only the closest one; thresholds already passed by more than fuel.announce_window_km
## (start in the middle of a stage) are skipped silently, so a message never names a wrong distance.
func _announce_stations(pos_km: float) -> void:
	if plan == null:
		return
	for s in plan.fuel_stations_km:
		if pos_km >= s:
			continue
		var fire := -1
		for k in _announce:
			var key := "%d@%.3f" % [k, s]
			if _announced.has(key):
				continue
			var at := s - float(k)
			if pos_km >= at:
				_announced[key] = true
				if pos_km < at + _announce_window:
					fire = k
		if fire >= 0:
			announced.emit(fire, s)


func _lane_valid(pos_km: float) -> bool:
	return plan == null or not plan.fuel_lane_at(pos_km).is_empty()


func _start_refuel(pos_km: float, throttle: float) -> void:
	state = State.REFUELING
	rolling_out = false
	liters_needed = maxf(0.0, tank_l - fuel_l)
	refuel_duration = refuel_duration_for(liters_needed)
	refuel_elapsed = 0.0
	liters_added = 0.0
	refuel_progress = 0.0
	refuel_time_left = refuel_duration
	pumping = false
	_fuel_at_start = fuel_l
	_abort_armed = throttle <= _release
	var lane: Dictionary = plan.fuel_lane_at(pos_km) if plan != null else {}
	_station_km = float(lane.get("station_km", pos_km))
	refuel_started.emit()


func _update_refuel(dt: float, throttle: float) -> void:
	# abort only with a fresh press: the pedal must have been released since the refuel started
	if throttle <= _release:
		_abort_armed = true
	elif _abort_armed and throttle >= _press and _throttle_prev < _press:
		_finish_refuel(true)
		return
	refuel_elapsed += dt
	var pump_t := maxf(0.0, refuel_elapsed - _fixed_s)
	pumping = pump_t > 0.0 and liters_added < liters_needed
	liters_added = minf(liters_needed, pump_t * 5.0 / maxf(_per5_s, 0.001))
	fuel_l = minf(tank_l, _fuel_at_start + liters_added)
	refuel_progress = clampf(refuel_elapsed / maxf(refuel_duration, 0.001), 0.0, 1.0)
	refuel_time_left = maxf(0.0, refuel_duration - refuel_elapsed)
	if refuel_elapsed >= refuel_duration - 0.000001:
		liters_added = liters_needed
		fuel_l = minf(tank_l, _fuel_at_start + liters_added)
		_finish_refuel(false)


func _finish_refuel(aborted: bool) -> void:
	state = State.NORMAL
	pumping = false
	refuel_time_left = 0.0
	if not aborted:
		refuel_progress = 1.0
	_lane_lock = true
	_check_reserve()
	refuel_finished.emit(liters_added, aborted)


## Scripted control wanted by the fuel system: {} or {"target_kmh": float, "rate_kmh_s": float}.
## REFUELING: stop at fuel.stop_decel_kmh_s; empty tank (rolling out / TOWING): roll to a stop at
## fuel.dry_coast_decel_kmh_s.
func control_request() -> Dictionary:
	if state == State.REFUELING:
		return {"target_kmh": 0.0, "rate_kmh_s": _stop_decel}
	if state == State.TOWING or rolling_out:
		return {"target_kmh": 0.0, "rate_kmh_s": _dry_decel}
	return {}


## Returns and clears the accumulated time penalty (towing) in seconds.
func take_penalty() -> float:
	var p := _penalty
	_penalty = 0.0
	return p
