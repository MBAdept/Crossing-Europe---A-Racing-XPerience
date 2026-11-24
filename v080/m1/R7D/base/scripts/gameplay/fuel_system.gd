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
##    keeps the litres pumped so far – but only once the tank holds fuel.abort_min_fuel_l (can_abort_refuel()):
##    with a (nearly) empty tank driving on is impossible, so gas is ignored until that much is in.
##    Faster than 60 the car simply drives through the lane.
##  * empty tank: the car rolls to a stop (control_request; it can still roll into a fuel lane and refuel –
##    an empty car standing in a fuel lane always refuels, it is never towed there), then the tow service:
##    TOWING for fuel.tow_overlay_s seconds, time penalty fuel.tow_penalty_s (take_penalty()), tank refilled
##    to fuel.tow_refill_fraction. ran_dry fires once per empty tank, tow_started when the tow really comes
##  * start filling (v0.7.0): in a race the tank of the last stage goes on (setup start_fuel_l), otherwise
##    StagePlan.start_fuel_fraction (the tutorial's 35 %), else fuel.start_fill_fraction. The first station lies
##    5–20 km after the start (fuel.first_station_min_km/max_km), closer than the 30-km announcement: it is
##    announced once at the start with its real distance (announce_start). start_check() tells whether a carried
##    tank reaches the first station – at full speed, only gently (max_kmh) or not even the open fuel lane at the lane
##    trigger speed (then the race session calls the tow service before the start, at the price of one on the road)

enum State { NORMAL, REFUELING, TOWING }

## km_before: the threshold (30 / 15 / 5), or at the start the real distance to the first station rounded to 0.1 km
## (12.0, 8.5 – the texts show it with UiFormat.number(km, 1), like the stage screen and the HUD).
signal announced(km_before: float, station_km: float)
signal refuel_started
signal refuel_finished(liters: float, aborted: bool)
signal ran_dry
signal tow_finished(penalty_s: float)
## Addition: fuel dropped below fuel.reserve_warning_l (once until refuelled).
signal reserve_reached
## Addition: the empty car has come to a stop outside a fuel lane and the tow service comes (state TOWING).
## Unlike ran_dry (tank empty, the car may still roll into a fuel lane) this is a real tow; tow_finished
## follows after fuel.tow_overlay_s.
signal tow_started

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
## v0.7.0: announce a first station closer than the first threshold once at the start with its real distance
## (_announce_first). Off when the race session already names it in the countdown (a carried tank).
var announce_start := true

var _penalty := 0.0
var _announced: Dictionary = {}
var _throttle_prev := 0.0
var _abort_armed := false
var _lane_lock := false
var _dry_reported := false
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
var _abort_min := 1.0
var _start_checked := false


## start_fuel_l >= 0: litres carried over from the last stage of a race (v0.7.0) – they replace the stage's own
## start filling (StagePlan.start_fuel_fraction, else fuel.start_fill_fraction), clamped to the tank.
func setup(config: Dictionary, vehicle_spec: Dictionary, stage_plan: StagePlan, start_fuel_l: float = -1.0) -> void:
	cfg = config
	plan = stage_plan
	_read_config()
	tank_l = float(vehicle_spec.get("tank_l", ConfigLoader.lookup(config, "vehicles.base_tank_l", 50.0)))
	consumption_factor = float(vehicle_spec.get("consumption_factor", 1.0))
	fuel_l = tank_l * start_fill_fraction(config, stage_plan)
	if start_fuel_l >= 0.0:
		fuel_l = clampf(start_fuel_l, 0.0, tank_l)
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
	_dry_reported = false
	_station_km = -1.0
	_start_checked = false


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
	_abort_min = maxf(0.0, _f("fuel.abort_min_fuel_l", 1.0))


static func base_consumption(config: Dictionary, speed_kmh: float) -> float:
	return float(ConfigLoader.lookup(config, "fuel.base_l_per_100km", 14.0)) + float(ConfigLoader.lookup(config, "fuel.quad_coeff", 0.00034)) * speed_kmh * speed_kmh


## Litres per 100 odometer km at speed, for this vehicle.
func consumption_per_100km(speed_kmh: float) -> float:
	return (_base + _quad * speed_kmh * speed_kmh) * consumption_factor


## Remaining range (odometer km) at the given speed (at least 60 km/h is assumed).
func range_km(speed_kmh: float) -> float:
	return fuel_l / consumption_per_100km(maxf(speed_kmh, 60.0)) * 100.0


## Litres needed to drive `km` odometer km at a steady speed_kmh (this vehicle).
func litres_for(km: float, speed_kmh: float) -> float:
	return maxf(km, 0.0) * consumption_per_100km(speed_kmh) / 100.0


## Tank filling (0..1) a stage starts with when nothing is carried over: StagePlan.start_fuel_fraction (the
## tutorial's 35 % in its driving direction), else fuel.start_fill_fraction.
static func start_fill_fraction(config: Dictionary, stage_plan: StagePlan) -> float:
	if stage_plan != null and stage_plan.start_fuel_fraction >= 0.0:
		return stage_plan.start_fuel_fraction
	return clampf(float(ConfigLoader.lookup(config, "fuel.start_fill_fraction", 1.0)), 0.0, 1.0)


## Litres per 100 km at speed_kmh for a vehicle spec (VehicleModel.resolve_spec: consumption_factor) – the same
## formula as consumption_per_100km(), without a FuelSystem (stage screen).
static func consumption_for(config: Dictionary, vehicle_spec: Dictionary, speed_kmh: float) -> float:
	return base_consumption(config, speed_kmh) * float(vehicle_spec.get("consumption_factor", 1.0))


## What is a tank of `litres` good for on the way to the first station of the stage (v0.7.0, the tank carried over in
## a race)? The verdict is planned to the station itself (first_km) – the distance the countdown, the stage screen and
## the HUD's "Nächste Tankstelle" name, and the HUD's range turns red below it (QA v0.7.0: planned to the open lane,
## "höchstens X km/h" left 0.05–0.11 L and a red range all the way). The fuel lane before the station (1–2 km) is the
## margin. Only the tow before the start counts to the open lane (its start plus the taper road.fuel_lane_taper_m,
## visual metres): a car that reaches it at the lane trigger speed refuels there. Returns
##   first_km    first station (km after the start; -1 = no station, then the finish is the target)
##   lane_km     odometer km to the open fuel lane (or to the finish)
##   need_l      litres to the open lane at fuel.lane_trigger_speed_kmh (below it the lane refuels) – less: "tow"
##   need_full_l litres to the station (or the finish) at the car's vmax_kmh – at least: "ok"
##   max_kmh     fastest steady speed that still reaches the station, rounded down to 5 km/h (vmax when the tank is
##               enough; at least the lane trigger speed, which reaches the open lane)
##   state       "ok" (even at full speed), "tight" (only up to max_kmh – drive gently or risk the tow) or "tow"
##               (not even at the lane trigger speed: the race session calls the tow service before the start –
##               fuel.tow_penalty_s, then fuel.tow_refill_fraction, the price of a tow on the road)
static func start_check(config: Dictionary, vehicle_spec: Dictionary, stage_plan: StagePlan, litres: float) -> Dictionary:
	var vmax := float(vehicle_spec.get("vmax_kmh", 245.0))
	var trigger := float(ConfigLoader.lookup(config, "fuel.lane_trigger_speed_kmh", 60.0))
	var first := -1.0
	var lane := 0.0
	var target := 0.0
	if stage_plan != null:
		lane = stage_plan.length_km
		target = stage_plan.length_km
		if not stage_plan.fuel_lanes.is_empty():
			var l: Dictionary = stage_plan.fuel_lanes[0]
			first = float(l["station_km"])
			target = first
			var taper := Units.visual_m_to_km(float(ConfigLoader.lookup(config, "road.fuel_lane_taper_m", 40.0)),
				float(ConfigLoader.lookup(config, "time.time_scale", 12.0)))
			lane = minf(float(l["start_km"]) + taper, first)
	var need := lane * consumption_for(config, vehicle_spec, trigger) / 100.0
	var need_full := target * consumption_for(config, vehicle_spec, vmax) / 100.0
	var out := {"first_km": first, "lane_km": lane, "need_l": need, "need_full_l": need_full, "max_kmh": vmax, "state": "ok"}
	if litres >= need_full:
		return out
	if litres < need:
		out["state"] = "tow"
		out["max_kmh"] = 0.0
		return out
	# fastest steady speed: litres / target km per km = consumption(v) / 100 – solved for v (consumption is
	# base + quad · v², times the vehicle factor), rounded down to 5 km/h as a margin; a tank that reaches the open lane
	# only below the trigger speed is told the trigger speed (it reaches the lane, the station lies beyond)
	var base := float(ConfigLoader.lookup(config, "fuel.base_l_per_100km", 14.0))
	var quad := float(ConfigLoader.lookup(config, "fuel.quad_coeff", 0.00034))
	var factor := maxf(float(vehicle_spec.get("consumption_factor", 1.0)), 0.001)
	var per100 := litres / maxf(target, 0.001) * 100.0 / factor
	var v := sqrt(maxf(per100 - base, 0.0) / maxf(quad, 0.0000001))
	out["state"] = "tight"
	out["max_kmh"] = clampf(floorf(v / 5.0) * 5.0, trigger, vmax)
	return out


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
			if fuel_l <= 0.0:
				rolling_out = true
				if not _dry_reported:
					_dry_reported = true
					ran_dry.emit()
			# an empty car in the lane always refuels (the lane lock after a refuel only stops a car with
			# fuel from being caught again while it pulls away) – it is never towed away from the pumps
			var locked := _lane_lock and fuel_l > 0.0
			if in_fuel_lane and speed_kmh < _trigger and not locked and tank_l - fuel_l >= _min_refuel and _lane_valid(pos_km):
				_start_refuel(pos_km, throttle)
			elif rolling_out and speed_kmh <= 0.5:
				rolling_out = false
				state = State.TOWING
				tow_time_left = _tow_overlay
				tow_started.emit()
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
	if fuel_l > 0.0:
		_dry_reported = false   # the next empty tank is reported again
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
## (start in the middle of a stage) are skipped silently, so a message never names a wrong distance. A first
## station closer than the first threshold is announced at the start with its real distance (_announce_first).
func _announce_stations(pos_km: float) -> void:
	if plan == null:
		return
	if not _start_checked:
		_start_checked = true
		_announce_first(pos_km)
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
			announced.emit(float(fire), s)


## v0.7.0: the first station lies 5–20 km after the start, closer than the first announcement (30 km), and usually
## the 15-km one lies before the start line as well (no sign there either). At a real stage start (pos_km below
## fuel.announce_window_km) such a station is announced once with its real distance to 0.1 km ("Tankstelle in 12 km",
## "in 8,5 km" – the same figure as the countdown, the stage screen and the HUD) – unless
## a threshold fires right there or within announce_window_km anyway (a station 15–16.5 km ahead: the 15-km
## announcement does it) or announce_start is off (the race session names it in the countdown). The thresholds behind
## the start are marked as done. A start in the middle of a stage (debug) skips passed thresholds silently as before.
func _announce_first(pos_km: float) -> void:
	var first := plan.next_station_km(pos_km)
	if first < 0.0 or _announce.is_empty() or pos_km >= _announce_window or first - pos_km > float(_announce[0]):
		return
	for k in _announce:
		var at := first - float(k)
		if at > pos_km - _announce_window and at < pos_km + _announce_window:
			return   # this threshold is (about) here: it announces the station itself
	for k in _announce:
		if first - float(k) <= pos_km:
			_announced["%d@%.3f" % [k, first]] = true
	if announce_start:
		announced.emit(snappedf(first - pos_km, 0.1), first)


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
	# abort only with a fresh press: the pedal must have been released since the refuel started.
	# With (almost) nothing in the tank the press is ignored – "Weiterfahren" is impossible then.
	if throttle <= _release:
		_abort_armed = true
	elif _abort_armed and throttle >= _press and _throttle_prev < _press and can_abort_refuel():
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


## Addition: a fresh throttle press would abort the running refuel ("Gas = Weiterfahren"): false while the
## tank holds less than fuel.abort_min_fuel_l (HUD: show "Tank leer – bitte warten" instead) or when no
## refuel is running.
func can_abort_refuel() -> bool:
	return state == State.REFUELING and fuel_l >= _abort_min


## Addition: the fuel system holds the car at a standstill (refuelling or towing). The race session passes
## it to PoliceSystem.set_blocked() so that a police stop is served after the refuel/tow, not during it.
func holds_car() -> bool:
	return state == State.REFUELING or state == State.TOWING


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
