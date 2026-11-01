extends RefCounted
## Numeric simulations of the gameplay rules (design document numbers). Used by
## tests/unit/gameplay/test_design_numbers.gd (asserts) and tests/sim/run_sims.gd (prints all tables):
##   godot --headless --path . -s res://tests/sim/run_sims.gd
## Everything runs at 60 Hz with the real gameplay classes. Owner: gameplay module (tests only).

const Fx := preload("res://tests/sim/fixtures.gd")
const FakeTrack := preload("res://tests/sim/fake_track.gd")
const DT := 1.0 / 60.0


# --- (h) acceleration, (f) top speed in rain at night ----------------------------------------

## Full throttle from standstill on a flat road. Returns measured times (s, -1 = not reached) and the
## top speed after 90 s.
static func accel_run(cfg: Dictionary, id: String, vmax_factor: float = 1.0) -> Dictionary:
	var v := Fx.vehicle(cfg, id)
	var road := Fx.flat_road()
	var t := 0.0
	var marks := {100.0: -1.0, 200.0: -1.0, 220.0: -1.0}
	var t_top := -1.0
	while t < 90.0:
		v.update(DT, {"throttle": 1.0}, road, {"vmax_factor": vmax_factor})
		t += DT
		for m: float in marks.keys():
			if float(marks[m]) < 0.0 and v.speed >= m:
				marks[m] = t
		if t_top < 0.0 and v.speed >= v.vmax_effective - 0.001:
			t_top = t
	return {"id": id, "vmax": float(v.spec["vmax_kmh"]), "vmax_eff": v.vmax_effective, "top": v.speed,
		"t100": marks[100.0], "t200": marks[200.0], "t220": marks[220.0], "t_top": t_top,
		"t100_target": float(v.spec["t100_s"]), "t200_target": float(v.spec["t200_s"]),
		"a0": v.accel_a0, "q": v.accel_q}


# --- (a) collision at 200 km/h ---------------------------------------------------------------

## Collision at v0 (hit from the left, pushed right), then full throttle back to v0. lost_s = time lost
## against driving on at v0 (distance deficit / v0).
static func collision_cost(cfg: Dictionary, id: String, v0: float = 200.0) -> Dictionary:
	var v := Fx.vehicle(cfg, id)
	var road := Fx.flat_road()
	v.x = 0.0
	v.speed = v0
	v.start_crash(-1.0, 2.0, 2.0)
	var target := float(ConfigLoader.lookup(cfg, "collision.target_speed_kmh", 10.0))
	var t := 0.0
	var d := 0.0
	var t_slow := -1.0
	var t_end := -1.0
	var x_end := 0.0
	while t < 120.0:
		v.update(DT, {"throttle": 1.0}, road, {"vmax_factor": 1.0})
		t += DT
		d += v.speed / 3.6 * DT
		if t_slow < 0.0 and v.speed <= target + 0.001:
			t_slow = t
		if t_end < 0.0 and v.state != VehicleModel.State.CRASH:
			t_end = t
			x_end = v.x
		if v.state == VehicleModel.State.DRIVING and v.speed >= v0:
			break
	return {"id": id, "v0": v0, "lost_s": t - d / (v0 / 3.6), "slow_s": t_slow, "end_s": t_end,
		"back_s": t, "push_m": x_end}


# --- (b) caught by the police ----------------------------------------------------------------

## Flashed while cruising at `cruise` through a 120 zone, no escape attempt: caught when the police car
## has closed the gap, stopped, released, back to `cruise`. lost_s counts from the capture (the chase
## itself costs nothing) and compares with driving on at `cruise`.
static func police_caught_cost(cfg: Dictionary, id: String, cruise: float = 160.0) -> Dictionary:
	var plan := Fx.make_plan(cfg, 300.0, [], [{"km": 20.0, "limit": 120}])
	var police := PoliceSystem.new()
	police.setup(cfg, plan)
	var v := Fx.vehicle(cfg, id)
	v.speed = cruise
	var road := Fx.flat_road()
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var km := 19.0
	var t := 0.0
	var t_flash := -1.0
	var t_catch := -1.0
	var t_stand := -1.0
	var t_release := -1.0
	var d_since := 0.0
	var catch_km := -1.0
	while t < 300.0:
		var req := police.control_request()
		if req.is_empty():
			v.release_auto()
		else:
			v.auto_control(float(req["target_kmh"]), float(req["rate_kmh_s"]))
		v.update(DT, {"throttle": 1.0 if v.speed < cruise else 0.0}, road, {"vmax_factor": 1.0})
		if v.state == VehicleModel.State.DRIVING and v.speed > cruise:
			v.speed = cruise
		var dz := v.speed / 3.6 * DT
		km += Units.visual_m_to_km(dz, ts)
		police.update(DT, km, v.speed)
		t += DT
		if t_flash < 0.0 and police.state == PoliceSystem.State.CHASE:
			t_flash = t
		if t_catch < 0.0 and police.state == PoliceSystem.State.STOPPING:
			t_catch = t
			catch_km = km
		if t_catch >= 0.0:
			d_since += dz
		if t_stand < 0.0 and police.state == PoliceSystem.State.STOPPED:
			t_stand = t
		if t_release < 0.0 and t_stand >= 0.0 and police.state == PoliceSystem.State.IDLE:
			t_release = t
		if t_release >= 0.0 and v.speed >= cruise:
			break
	var lost := (t - t_catch) - d_since / (cruise / 3.6) if t_catch >= 0.0 else 0.0
	return {"id": id, "cruise": cruise, "chase_s": t_catch - t_flash, "brake_s": t_stand - t_catch,
		"stand_s": t_release - t_stand, "lost_s": lost, "catch_km": catch_km}


# --- (e) escape ------------------------------------------------------------------------------

## Flashed at hold_kmh (entering a 120 zone at that speed), then holding hold_kmh (or the car's maximum).
## Result: escaped / caught, after how many seconds. grade: constant climb (rise/run) of the whole run.
static func escape_run(cfg: Dictionary, id: String, hold_kmh: float, vmax_factor: float = 1.0, start_kmh: float = -1.0, grade: float = 0.0) -> Dictionary:
	var plan := Fx.make_plan(cfg, 300.0, [], [{"km": 20.0, "limit": 120}])
	var police := PoliceSystem.new()
	police.setup(cfg, plan)
	var v := Fx.vehicle(cfg, id)
	v.speed = hold_kmh if start_kmh < 0.0 else start_kmh
	var road := Fx.flat_road()
	road["grade"] = grade
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var km := 19.95
	var t := 0.0
	var result := "none"
	var min_gap := INF
	var chase_t := 0.0
	while t < 120.0:
		v.update(DT, {"throttle": 1.0 if v.speed < hold_kmh else 0.0}, road, {"vmax_factor": vmax_factor})
		if v.speed > hold_kmh:
			v.speed = hold_kmh
		km += Units.visual_m_to_km(v.speed / 3.6 * DT, ts)
		var was := police.state
		police.update(DT, km, v.speed)
		t += DT
		if police.state == PoliceSystem.State.CHASE:
			min_gap = minf(min_gap, police.gap_m)
			chase_t = police.chase_time
		if was == PoliceSystem.State.CHASE and police.state == PoliceSystem.State.IDLE:
			result = "escaped"
			chase_t = police.chase_time
			break
		if police.state == PoliceSystem.State.STOPPING:
			result = "caught"
			chase_t = police.chase_time
			break
	return {"id": id, "hold": hold_kmh, "result": result, "chase_s": chase_t, "min_gap_m": min_gap,
		"avg": police.avg_speed, "vmax_eff": v.vmax_effective}


## A chase into the City Limits, driven continuously with the real VehicleModel on a flat road: the player
## approaches `radar` (default: the last radar of the plan) at hold_kmh, is flashed at the zone start and
## keeps trying to flee at hold_kmh (below 220 = no escape). flee_kmh > 0: from the City Limits on the
## player speeds up to flee_kmh (escape inside the City Limits). Ends when the chase ends.
## Returns flash_km, end ("caught" | "escaped" | "none"), end_km, chase_s and city_chase_km (odometer km
## driven inside the City Limits while the chase was running).
static func chase_into_city_run(cfg: Dictionary, plan: StagePlan, id: String, hold_kmh: float, flee_kmh: float = -1.0, radar: Dictionary = {}) -> Dictionary:
	var r := radar
	if r.is_empty() and not plan.radars.is_empty():
		r = plan.radars[plan.radars.size() - 1]
	var police := PoliceSystem.new()
	police.setup(cfg, plan)
	var v := Fx.vehicle(cfg, id)
	v.speed = hold_kmh
	var road := Fx.flat_road()
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var km := maxf(0.0, float(r.get("km", 0.0)) - 2.0)
	var t := 0.0
	var end := "none"
	var end_km := -1.0
	var city_km := 0.0
	var st := {"km": km, "flash_km": -1.0}   # lambdas capture locals by value: share state via a Dictionary
	police.flashed.connect(func(_rr: Dictionary, _s: float) -> void: st["flash_km"] = st["km"])
	while t < 600.0 and km < plan.length_km:
		var target := hold_kmh
		if flee_kmh > 0.0 and plan.is_city(km):
			target = flee_kmh
		var req := police.control_request()
		if req.is_empty():
			v.release_auto()
		else:
			v.auto_control(float(req["target_kmh"]), float(req["rate_kmh_s"]))
		v.update(DT, {"throttle": 1.0 if v.speed < target else 0.0}, road, {"vmax_factor": 1.0})
		if v.state == VehicleModel.State.DRIVING and v.speed > target:
			v.speed = target
		var dkm := Units.odometer_km_delta(v.speed, DT, ts)
		km += dkm
		st["km"] = km
		var was := police.state
		police.update(DT, km, v.speed)
		t += DT
		if police.state == PoliceSystem.State.CHASE and plan.is_city(km):
			city_km += dkm
		if was == PoliceSystem.State.CHASE and police.state != PoliceSystem.State.CHASE:
			end = "escaped" if police.state == PoliceSystem.State.IDLE else "caught"
			end_km = km
			break
	return {"flash_km": float(st["flash_km"]), "end": end, "end_km": end_km, "chase_s": police.chase_time,
		"city_chase_km": city_km, "city_limits_km": plan.city_limits_km}


## The radar zone closest to the City Limits in the real network (data/network.json, all non-dev stages in
## both directions): {plan, radar, distance_km (zone start -> City Limits)} or {} without data.
static func closest_radar_to_city(cfg: Dictionary) -> Dictionary:
	var net: Variant = ConfigLoader.load_json("res://data/network.json")
	var ctry: Variant = ConfigLoader.load_json("res://data/countries.json")
	if not net is Dictionary or not ctry is Dictionary:
		return {}
	var countries: Dictionary = (ctry as Dictionary).get("countries", {})
	var cities := {}
	for c: Dictionary in (net as Dictionary).get("cities", []):
		cities[str(c["id"])] = c
	var best := {}
	for st: Dictionary in (net as Dictionary).get("stages", []):
		if bool(st.get("dev", false)):
			continue
		for from: String in [str(st["from"]), str(st["to"])]:
			var plan := StagePlan.build(st, from, cities, countries, cfg)
			for r: Dictionary in plan.radars:
				var d := plan.city_limits_km - float(r["km"])
				if best.is_empty() or d < float(best["distance_km"]) - 0.0001:
					best = {"plan": plan, "radar": r, "distance_km": d}
	return best


## POL-1: police stop and refuelling must add up. Real FuelSystem + PoliceSystem + VehicleModel with the race
## session's control priority (fuel before police) and PoliceSystem.set_blocked(fuel.holds_car()).
## mode "refuel_first": flashed at 180 km/h, the player brakes into the fuel lane and refuels, the police catch
##   the standing car during the refuel;
## mode "caught_first": caught right before the fuel lane, the police stop brakes the car below 60 km/h inside
##   the lane, so the refuel starts during the police stop;
## mode "refuel_only": the same refuel without a chase (reference).
## Returns standstill_s (first standstill until moving again), refuel_s (duration of the refuel), stop_s,
## liters and events [[t, name], ...].
static func police_refuel_run(cfg: Dictionary, mode: String, id: String = "limousine", fuel_l: float = 20.0) -> Dictionary:
	var cruise := 180.0 if mode != "caught_first" else 160.0
	var radar_km := 30.0
	var station := 40.0
	var lane_len := 1.5
	if mode == "caught_first":
		# where does the police catch a car cruising at 160 through the zone (same set-up as
		# police_caught_cost)? The lane starts just before that point and the car stops inside it.
		radar_km = 20.0
		lane_len = 1.8
		station = float(police_caught_cost(cfg, id, cruise).get("catch_km", 30.0)) + 1.6
	var plan := Fx.make_plan(cfg, 300.0, [station], [] if mode == "refuel_only" else [{"km": radar_km, "limit": 120}], lane_len)
	var police := PoliceSystem.new()
	police.setup(cfg, plan)
	var spec := VehicleModel.resolve_spec(cfg, id)
	var fuel := FuelSystem.new()
	fuel.setup(cfg, spec, plan)
	fuel.fuel_l = fuel_l
	var v := Fx.vehicle(cfg, id)
	v.speed = cruise
	var road := Fx.flat_road()
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var km := radar_km - 1.0
	var t := 0.0
	var events: Array = []
	var clock := {"t": 0.0}   # lambdas capture locals by value: share the time via a Dictionary
	police.pull_over.connect(func() -> void: events.append([clock["t"], "pull_over"]))
	police.caught.connect(func() -> void: events.append([clock["t"], "caught"]))
	police.released.connect(func() -> void: events.append([clock["t"], "released"]))
	fuel.refuel_started.connect(func() -> void: events.append([clock["t"], "refuel_started"]))
	fuel.refuel_finished.connect(func(_l: float, _a: bool) -> void: events.append([clock["t"], "refuel_finished"]))
	var lane_start := station - lane_len
	var t_stand := -1.0
	var t_go := -1.0
	var refuel_s := 0.0
	while t < 200.0:
		# player: cruise, brake into the fuel lane (refuel modes), hands off while the car is held
		var throttle := 1.0 if v.speed < cruise else 0.0
		var brake := 0.0
		if mode != "caught_first" and km > lane_start - 0.6 and km < station and fuel.liters_added <= 0.0:
			throttle = 0.0
			brake = 1.0 if v.speed > 45.0 else 0.0
		if fuel.state != FuelSystem.State.NORMAL or not police.control_request().is_empty():
			throttle = 0.0
			brake = 0.0
		var req := fuel.control_request()
		if req.is_empty():
			req = police.control_request()
		if req.is_empty():
			v.release_auto()
		else:
			v.auto_control(float(req["target_kmh"]), float(req["rate_kmh_s"]))
		v.update(DT, {"throttle": throttle, "brake": brake}, road, {"vmax_factor": 1.0})
		var dkm := Units.odometer_km_delta(v.speed, DT, ts)
		km += dkm
		var in_lane := not plan.fuel_lane_at(km).is_empty()
		t += DT
		clock["t"] = t
		fuel.update(DT, km, dkm, v.speed, in_lane, throttle)
		police.set_blocked(fuel.holds_car())
		police.update(DT, km, v.speed)
		if fuel.state == FuelSystem.State.REFUELING:
			refuel_s = fuel.refuel_duration
		if t_stand < 0.0 and v.speed <= 0.5:
			t_stand = t
		if t_stand >= 0.0 and t_go < 0.0 and v.speed > 0.5:
			t_go = t
			break
	# the car stops inside the fixed part of the refuel: the refuel itself keeps it standing until it ends
	var t_refuel_end := -1.0
	for e: Array in events:
		if str(e[1]) == "refuel_finished":
			t_refuel_end = float(e[0])
	var standstill := (t_go - t_stand) if t_go >= 0.0 else -1.0
	var refuel_stand := maxf(0.0, t_refuel_end - t_stand) if t_refuel_end >= 0.0 else 0.0
	return {"mode": mode, "standstill_s": standstill, "refuel_s": refuel_s, "refuel_stand_s": refuel_stand,
		"police_extra_s": standstill - refuel_stand,
		"stop_s": float(ConfigLoader.lookup(cfg, "police.stop_duration_s", 10.0)), "liters": fuel.liters_added,
		"events": events, "stops": police.stops}


# --- (c) refuel, (d) consumption -------------------------------------------------------------

## Drives into a fuel lane at 55 km/h with `missing_l` litres missing (tank tank_l) and lets the refuel
## run to the end. Returns the refuel duration (refuel_started -> refuel_finished) and the litres.
static func refuel_run(cfg: Dictionary, tank_l: float, missing_l: float, factor: float = 1.0) -> Dictionary:
	var plan := Fx.make_plan(cfg, 200.0, [60.0], [], 1.5)
	var fuel := FuelSystem.new()
	fuel.setup(cfg, {"tank_l": tank_l, "consumption_factor": factor}, plan)
	fuel.fuel_l = tank_l - missing_l
	var v := Fx.vehicle(cfg, "limousine")
	v.speed = 55.0
	var road := Fx.flat_road()
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var km := 58.6
	var t := 0.0
	var t_start := -1.0
	var t_end := -1.0
	var liters := 0.0
	var stopped_at := -1.0
	var res := {"started": false}
	fuel.refuel_started.connect(func() -> void: res["started"] = true)
	fuel.refuel_finished.connect(func(l: float, _a: bool) -> void: res["liters"] = l)
	while t < 120.0:
		var req := fuel.control_request()
		if req.is_empty():
			v.release_auto()
		else:
			v.auto_control(float(req["target_kmh"]), float(req["rate_kmh_s"]))
		v.update(DT, {"throttle": 0.0}, road, {"vmax_factor": 1.0})
		var dkm := Units.visual_m_to_km(v.speed / 3.6 * DT, ts)
		km += dkm
		var in_lane := not plan.fuel_lane_at(km).is_empty()
		var before := fuel.state
		fuel.update(DT, km, dkm, v.speed, in_lane, 0.0)
		t += DT
		if before != FuelSystem.State.REFUELING and fuel.state == FuelSystem.State.REFUELING:
			t_start = t
		if stopped_at < 0.0 and t_start >= 0.0 and v.speed <= 0.01:
			stopped_at = t - t_start
		if before == FuelSystem.State.REFUELING and fuel.state != FuelSystem.State.REFUELING:
			t_end = t
			liters = float(res.get("liters", 0.0))
			break
	return {"tank": tank_l, "missing": missing_l, "duration_s": t_end - t_start, "liters": liters,
		"stop_s": stopped_at, "formula_s": fuel.refuel_duration_for(missing_l)}


## Litres used for distance_km at constant speed (integrated through FuelSystem.update at 60 Hz).
static func consumption_run(cfg: Dictionary, speed: float, distance_km: float = 100.0, tank_l: float = 500.0, factor: float = 1.0) -> float:
	var plan := Fx.make_plan(cfg, 2000.0)
	var fuel := FuelSystem.new()
	fuel.setup(cfg, {"tank_l": tank_l, "consumption_factor": factor}, plan)
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var km := 0.0
	var start := fuel.fuel_l
	var dkm := Units.odometer_km_delta(speed, DT, ts)
	while km < distance_km - 0.0000001:
		var step := minf(dkm, distance_km - km)
		km += step
		fuel.update(DT, km, step, speed, false, 1.0)
	return start - fuel.fuel_l


# --- (g) traffic -----------------------------------------------------------------------------

## Runs traffic around a player driving at player_kmh on `track` for `seconds` (after opts.warmup seconds).
## opts: chase (bool, whole run), chase_at (s after warmup when a chase starts, -1 = never), settle (s after
## chase_at before "after" stats count), warmup (20), seed (99), start_z (200), player_x (rightmost lane).
## Returns averages (visible cars, speeds), safety counters (car/car overlaps, cars overlapping the player)
## and pop counters (cars appearing/vanishing inside the visible area – must stay 0).
static func traffic_run(cfg: Dictionary, track: Object, hour: float, player_kmh: float, seconds: float, opts: Dictionary = {}) -> Dictionary:
	var ts := TrafficSystem.new()
	var sets: Array[String] = ["traffic/sedan_blue", "traffic/sedan_red", "traffic/hatch_green", "traffic/van_white"]
	var heavy: Array[String] = ["traffic/truck_white"]
	ts.setup(cfg, track, sets, heavy, int(opts.get("seed", 99)))
	var warmup := float(opts.get("warmup", 20.0))
	var chase_all := bool(opts.get("chase", false))
	var chase_at := float(opts.get("chase_at", -1.0))
	var settle := float(opts.get("settle", 15.0))
	var pz := float(opts.get("start_z", 200.0))
	var lanes := int(track.lane_count_at(pz))
	var px := float(opts.get("player_x", track.lane_center_x(pz, lanes - 1)))
	var cam_dist := float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 6.6))
	var vis := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	var t := 0.0
	var n := 0
	var n_after := 0
	var sum_vis := 0.0
	var sum_vis_after := 0.0
	var sum_all := 0.0
	var sum_speed := 0.0
	var speed_n := 0
	var sum_cruise := 0.0
	var overlaps := 0
	var player_hits := 0
	var min_gap := INF
	var lane_changes := 0
	var fuel_users := {}
	var last_lane := {}
	var seen := {}
	var sum_cruise_unique := 0.0
	var sum_factor_unique := 0.0
	var prev := {}
	var pops_in := 0
	var pops_out := 0
	var hidden_culls := 0
	var heavy_ids := {}
	var heavy_frames := 0
	var heavy_lane0 := 0
	var heavy_right := 0
	var was_chase := false
	var cull_frac := float(ConfigLoader.lookup(cfg, "traffic.cull_visible_fraction", 0.85))
	var flash_m := float(ConfigLoader.lookup(cfg, "traffic.chase_flash_cull_m", 250.0))
	var braking_seen := 0
	var min_cruise := INF
	var max_cruise := -INF
	var min_cruise_heavy := INF
	var max_cruise_heavy := -INF
	var min_cruise_car := INF
	var side_t := {}
	var max_side := 0.0
	var weather := str(opts.get("weather", "normal"))
	var signals := 0
	var signal_moves := 0
	var min_lead := INF
	var signal_seen := {}
	var cv_sum := 0.0
	var cv_n := 0
	while t < warmup + seconds:
		var since := t - warmup
		var chase := chase_all or (chase_at >= 0.0 and since >= chase_at)
		var lane_before := {}
		for c in ts.cars:
			lane_before[c.id] = c.lane
		ts.update(DT, {"z": pz, "x": px, "speed": player_kmh}, {"hour": hour, "chase": chase, "camera_z": pz - cam_dist, "weather": weather})
		# indicators: every lane change (except an emergency swerve) is signalled before the car moves
		for c in ts.cars:
			if c.signal_dir != 0 and not signal_seen.has(c.id):
				signal_seen[c.id] = true
				signals += 1
			elif c.signal_dir == 0:
				signal_seen.erase(c.id)
			if lane_before.has(c.id) and int(lane_before[c.id]) != c.lane and c.signal_dir != 0:
				signal_moves += 1
				min_lead = minf(min_lead, c.signal_age)
		pz += player_kmh / 3.6 * DT
		t += DT
		since = t - warmup
		var cam := pz - cam_dist
		# pops: cars that appear or vanish while inside the visible area
		var now := {}
		for c in ts.cars:
			now[c.id] = Vector2(c.z, c.length * 0.5)
			if since > 0.0 and not prev.has(c.id) and c.z + c.length * 0.5 > cam and c.z - c.length * 0.5 < cam + vis:
				pops_in += 1
		if since > 0.0:
			for id in prev:
				if not now.has(id):
					var pv: Vector2 = prev[id]
					if pv.x + pv.y > cam and pv.x - pv.y < cam + vis:
						# deliberate, hidden removals: deep in the fog, or far ahead under the radar flash
						var flash_frame := chase and not was_chase
						if pv.x - pv.y > cam + vis * cull_frac or (flash_frame and pv.x - pv.y > cam + flash_m):
							hidden_culls += 1
						else:
							pops_out += 1
		prev = now
		was_chase = chase
		if since < 0.0:
			continue
		n += 1
		var after := chase_at >= 0.0 and since >= chase_at + settle
		if after:
			n_after += 1
		if n % 60 == 0:
			# spacing along the road (all lanes, view ahead): coefficient of variation of the gaps (clusters > 1)
			var zs: Array[float] = []
			for c in ts.cars:
				if c.z > pz and c.z < pz + vis:
					zs.append(c.z)
			zs.sort()
			if zs.size() >= 4:
				var gsum := 0.0
				var gsq := 0.0
				for i in range(1, zs.size()):
					var g := zs[i] - zs[i - 1]
					gsum += g
					gsq += g * g
				var k := float(zs.size() - 1)
				var mean := gsum / k
				cv_sum += sqrt(maxf(0.0, gsq / k - mean * mean)) / maxf(mean, 0.001)
				cv_n += 1
		sum_all += ts.cars.size()
		for c in ts.cars:
			if c.z + c.length * 0.5 > cam and c.z - c.length * 0.5 < cam + vis:
				if after:
					sum_vis_after += 1.0
				elif chase_at < 0.0 or since < chase_at:
					sum_vis += 1.0
			if not seen.has(c.id):
				seen[c.id] = true
				min_cruise = minf(min_cruise, c.cruise_speed)
				max_cruise = maxf(max_cruise, c.cruise_speed)
				if c.heavy:
					min_cruise_heavy = minf(min_cruise_heavy, c.cruise_speed)
					max_cruise_heavy = maxf(max_cruise_heavy, c.cruise_speed)
				else:
					min_cruise_car = minf(min_cruise_car, c.cruise_speed)
				sum_cruise_unique += c.cruise_speed
				# desired speed relative to the class range at its temperament (night/weather factor)
				var key := "traffic.speeds_kmh."
				if c.heavy:
					key = "traffic.bus_speeds_kmh." if c.bus else "traffic.truck_speeds_kmh."
				var r: Array = ConfigLoader.lookup(cfg, key + str(track.road_type_at(c.z)), [100, 130])
				sum_factor_unique += c.cruise_speed / lerpf(float(r[0]), float(r[1]), c.speed_frac)
			sum_speed += c.speed
			sum_cruise += c.cruise_speed
			speed_n += 1
			if c.braking:
				braking_seen += 1
			if c.heavy:
				heavy_ids[c.id] = true
				heavy_frames += 1
				if c.lane == 0 and int(track.lane_count_at(c.z)) >= 3:
					heavy_lane0 += 1
				if c.lane == int(track.lane_count_at(c.z)) - 1:
					heavy_right += 1
			if c.in_fuel_lane:
				fuel_users[c.id] = true
			if last_lane.has(c.id) and int(last_lane[c.id]) != c.lane:
				lane_changes += 1
			last_lane[c.id] = c.lane
			if absf(c.z - pz) < (c.length + 4.6) * 0.5 and absf(c.x - px) < (c.width + 1.85) * 0.5:
				player_hits += 1
		var cs := ts.cars
		var side_now := {}
		for i in cs.size():
			for j in range(i + 1, cs.size()):
				var a := cs[i]
				var b := cs[j]
				if absf(a.x - b.x) < (a.width + b.width) * 0.5 - 0.1:
					var gap := absf(a.z - b.z) - (a.length + b.length) * 0.5
					if gap < 0.0:
						overlaps += 1
					if absf(a.x - b.x) < 0.5:
						min_gap = minf(min_gap, gap)
				# rolling roadblock: two cars side by side in neighbouring lanes at (almost) the same speed
				if a.lane != TrafficSystem.FUEL_LANE and b.lane != TrafficSystem.FUEL_LANE and absi(a.lane - b.lane) == 1 \
						and absf(a.z - b.z) < (a.length + b.length) * 0.5 + 6.0 and absf(a.speed - b.speed) < 5.0:
					var key := "%d:%d" % [mini(a.id, b.id), maxi(a.id, b.id)]
					var st := float(side_t.get(key, 0.0)) + DT
					side_now[key] = st
					max_side = maxf(max_side, st)
		side_t = side_now
	var n_before := n - n_after if chase_at >= 0.0 else n
	if chase_at >= 0.0:
		n_before = int(minf(float(n), chase_at / DT))
	return {"avg_visible": sum_vis / maxf(1.0, n_before), "avg_visible_after": sum_vis_after / maxf(1.0, n_after),
		"avg_cars": sum_all / maxf(1.0, n),
		"avg_speed": sum_speed / maxf(1.0, speed_n), "avg_cruise": sum_cruise / maxf(1.0, speed_n),
		"unique_cars": seen.size(), "avg_cruise_unique": sum_cruise_unique / maxf(1.0, seen.size()),
		"speed_factor_unique": sum_factor_unique / maxf(1.0, seen.size()),
		"max_cruise_heavy": max_cruise_heavy, "min_cruise_car": min_cruise_car, "spacing_cv": cv_sum / maxf(1.0, float(cv_n)),
		"signals": signals, "signal_moves": signal_moves, "min_signal_lead_s": min_lead,
		"overlaps": overlaps, "player_hits": player_hits, "min_gap": min_gap, "lane_changes": lane_changes,
		"fuel_users": fuel_users.size(), "target": ts.target_count, "spawned": ts.spawned_total,
		"pops_in": pops_in, "pops_out": pops_out, "hidden_culls": hidden_culls, "heavy_seen": heavy_ids.size(), "heavy_lane0_frames": heavy_lane0,
		"heavy_right_share": float(heavy_right) / maxf(1.0, heavy_frames), "braking_frames": braking_seen,
		"min_cruise": min_cruise, "max_cruise": max_cruise, "min_cruise_heavy": min_cruise_heavy,
		"max_side_by_side_s": max_side, "system": ts}


## Cars per visible km (all lanes) for the given hour: TrafficSystem.density_per_km_at on a plain autobahn.
static func density_at(cfg: Dictionary, hour: float, chase: bool = false, road: String = "autobahn", city: bool = false) -> float:
	var track := FakeTrack.new(5000.0, road, 3 if road == "autobahn" else 2)
	if city:
		track.city_z = 0.0
	var ts := TrafficSystem.new()
	var empty: Array[String] = []
	ts.setup(cfg, track, empty, empty, 1)
	return ts.density_per_km_at(1000.0, hour, chase)


# --- (i) curves and understeer ---------------------------------------------------------------

## Curve value (+ = right bend) whose safe speed for the vehicle is speed_kmh / (1 + over) at the grip.
static func curve_for_overspeed(v: VehicleModel, speed_kmh: float, over: float, grip: float = 1.0) -> float:
	var vs := speed_kmh / (1.0 + over) / 3.6
	var r1 := float(ConfigLoader.lookup(v.cfg, "road.curve_radius_at_1_m", 120.0))
	return v.grip_accel(grip) * r1 / (vs * vs)


## The user's case: the car arrives at top speed (full throttle, which holds vmax) in a constant right bend
## whose safe speed it exceeds by `over` (0.15 = 15 %), starting in the middle lane of a three-lane autobahn
## with guardrails. steer: +1 = full counter-steer (into the bend), 0 = none. brake_at >= 0: from that time
## on full braking instead of throttle, steering released once the car is back under the limit (recovery).
## Times are -1 when not reached; shoulder and guardrail count on the outside (left) only.
## Returns t_lane (one lane width outwards), t_shoulder (off_road >= 1), t_limit (guardrail), x_min (most
## outward position), x_end, v_end, push_peak (|drift| m/s), us_peak, t_below (back under the limit after
## braking), t_recovered (|drift| < 10 % of the peak after that), drift_after_m (outward metres after t_below).
static func understeer_run(cfg: Dictionary, id: String, over: float, steer: float, seconds: float, grip: float = 1.0, dt: float = DT, brake_at: float = -1.0) -> Dictionary:
	var v := Fx.vehicle(cfg, id)
	var vmax := v.max_speed(0.0, 1.0)
	var road := Fx.flat_road(3, true, curve_for_overspeed(v, vmax, over, grip), grip)
	var lane_w := 3.75
	v.speed = vmax
	v.x = 0.0
	var r := {"id": id, "over": over, "steer": steer, "t_lane": -1.0, "t_shoulder": -1.0, "t_limit": -1.0, "x_min": 0.0,
		"push_peak": 0.0, "us_peak": 0.0, "t_below": -1.0, "t_recovered": -1.0, "drift_after_m": 0.0, "curve": float(road["curve"]),
		"safe_kmh": v.safe_curve_speed(float(road["curve"]), grip), "v0": vmax}
	var t := 0.0
	var x_below := 0.0
	while t < seconds - 0.0001:
		var braking := brake_at >= 0.0 and t >= brake_at
		var st := 0.0 if braking and float(r["t_below"]) >= 0.0 else steer
		v.update(dt, {"steer": st, "throttle": 0.0 if braking else 1.0, "brake": 1.0 if braking else 0.0}, road, {"vmax_factor": 1.0})
		t += dt
		r["x_min"] = minf(float(r["x_min"]), v.x)
		r["push_peak"] = maxf(float(r["push_peak"]), absf(v.push_speed))
		r["us_peak"] = maxf(float(r["us_peak"]), v.understeer)
		if float(r["t_lane"]) < 0.0 and v.x <= -lane_w:
			r["t_lane"] = t
		if float(r["t_shoulder"]) < 0.0 and v.off_road >= 1 and v.x < 0.0:
			r["t_shoulder"] = t
		if float(r["t_limit"]) < 0.0 and v.off_road == 2 and v.x < 0.0:
			r["t_limit"] = t
		if braking and float(r["t_below"]) < 0.0 and v.lat_excess <= 0.0:
			r["t_below"] = t
			x_below = v.x
		if float(r["t_below"]) >= 0.0:
			r["drift_after_m"] = maxf(float(r["drift_after_m"]), x_below - v.x)
			if float(r["t_recovered"]) < 0.0 and absf(v.push_speed) < 0.1 * float(r["push_peak"]):
				r["t_recovered"] = t
	r["x_end"] = v.x
	r["v_end"] = v.speed
	return r


## A real curve piece as Track builds it: right bend of length_m with smoothstep ramp-in/-out over 30 % of the piece,
## its peak `over` too fast for the car at top speed. A lane-keeping driver (steer = clamp((lane_x − x) · gain), the
## proportional counter-steer of a player holding a lane) keeps full throttle (which holds vmax) from the lane at
## lane_x (0 = middle lane of a three-lane autobahn with guardrails) until 150 m after the piece.
## Returns dev_max (largest distance from the lane, m), out_max (outwards = left), shoulder / limit (outer shoulder
## or guardrail reached), rail_hits, us_s (seconds with understeer), v_min.
static func curve_piece_run(cfg: Dictionary, id: String, over: float, length_m: float, lane_x: float = 0.0, gain: float = 1.5, grip: float = 1.0, dt: float = DT) -> Dictionary:
	var v := Fx.vehicle(cfg, id)
	var vmax := v.max_speed(0.0, 1.0)
	v.speed = vmax
	v.x = lane_x
	var peak := curve_for_overspeed(v, vmax, over, grip)
	var road := Fx.flat_road(3, true, 0.0, grip)
	var out := {"dev_max": 0.0, "out_max": 0.0, "shoulder": false, "limit": false, "rail_hits": 0, "us_s": 0.0, "v_min": vmax, "peak": peak}
	var z := -30.0
	while z < length_m + 150.0:
		var tt := clampf(z / length_m, 0.0, 1.0)
		var ease := smoothstep(0.0, 0.3, tt) * (1.0 - smoothstep(0.7, 1.0, tt))
		road["curve"] = peak * ease if z >= 0.0 and z <= length_m else 0.0
		var steer := clampf((lane_x - v.x) * gain, -1.0, 1.0)
		v.update(dt, {"steer": steer, "throttle": 1.0}, road, {"vmax_factor": 1.0})
		z += v.speed / 3.6 * dt
		out["dev_max"] = maxf(float(out["dev_max"]), absf(v.x - lane_x))
		out["out_max"] = maxf(float(out["out_max"]), lane_x - v.x)
		out["v_min"] = minf(float(out["v_min"]), v.speed)
		if v.off_road >= 1 and v.x < lane_x:
			out["shoulder"] = true
		if v.off_road == 2 and v.x < lane_x:
			out["limit"] = true
		if v.rail_hit:
			out["rail_hits"] = int(out["rail_hits"]) + 1
		if v.understeer > 0.0:
			out["us_s"] = float(out["us_s"]) + dt
	return out


## Safe curve speed (km/h) of a vehicle at the sharpest and the median curve of a curviness level
## (road.curviness_max_curve; Track draws curve magnitudes uniformly from 35–100 % of the maximum).
static func curviness_speeds(cfg: Dictionary, id: String, level: int, grip: float = 1.0) -> Vector2:
	var v := Fx.vehicle(cfg, id)
	var maxes: Array = ConfigLoader.lookup(cfg, "road.curviness_max_curve", [0.0, 0.30, 0.45, 0.9])
	var c := float(maxes[clampi(level, 0, maxes.size() - 1)])
	return Vector2(v.safe_curve_speed(c, grip), v.safe_curve_speed(c * 0.675, grip))


## Share of the curves of a curviness level (magnitudes uniform in 35–100 % of the maximum) whose safe speed
## is below the vehicle's top speed, i.e. that need a lift or braking at full speed.
static func lift_share(cfg: Dictionary, id: String, level: int, grip: float = 1.0) -> float:
	var v := Fx.vehicle(cfg, id)
	var maxes: Array = ConfigLoader.lookup(cfg, "road.curviness_max_curve", [0.0, 0.30, 0.45, 0.9])
	var cmax := float(maxes[clampi(level, 0, maxes.size() - 1)])
	if cmax <= 0.0:
		return 0.0
	var vm := v.max_speed(0.0, 1.0) / 3.6
	var c_crit := v.grip_accel(grip) * float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)) / (vm * vm)
	return clampf((cmax - c_crit) / (cmax * 0.65), 0.0, 1.0)


# --- tables ----------------------------------------------------------------------------------

static func all_tables(cfg: Dictionary) -> String:
	var out := ""
	out += table_accel(cfg)
	out += table_collision(cfg)
	out += table_police(cfg)
	out += table_refuel(cfg)
	out += table_consumption(cfg)
	out += table_escape(cfg)
	out += table_rain_night(cfg)
	out += table_traffic(cfg)
	out += table_understeer(cfg)
	return out


static func table_understeer(cfg: Dictionary) -> String:
	var rows: Array = []
	for id: String in Fx.VEHICLES:
		var v := Fx.vehicle(cfg, id)
		var row := [id, "%d" % int(v.spec["agility"]), "%.1f" % v.grip_accel(1.0), "%d" % int(v.spec["vmax_kmh"])]
		for level in [1, 2, 3]:
			var s := curviness_speeds(cfg, id, level)
			row.append("%d / %d" % [roundi(s.x), roundi(s.y)])
			row.append("%d %%" % roundi(lift_share(cfg, id, level) * 100.0))
		rows.append(row)
	var out := Fx.table("(i) Sichere Kurvengeschwindigkeit km/h (schärfste / mittlere Kurve) und Anteil der Kurven, die bei vmax Gas wegnehmen oder Bremsen verlangen",
		["Fahrzeug", "Agilität", "Haftung m/s²", "vmax", "Kurvigkeit 1", "Anteil", "Kurvigkeit 2", "Anteil", "Kurvigkeit 3", "Anteil"], rows)
	var rows2: Array = []
	for id: String in ["kompakt", "limousine", "gran_turismo"]:
		for over: float in [0.05, 0.10, 0.15, 0.20, 0.30]:
			var free := understeer_run(cfg, id, over, 0.0, 3.0)
			var cs := understeer_run(cfg, id, over, 1.0, 3.0)
			rows2.append([id, "%d %%" % roundi(over * 100.0), "%.0f" % float(cs["safe_kmh"]), _t(free["t_lane"]), _t(free["t_shoulder"]),
				_t(cs["t_lane"]), _t(cs["t_shoulder"]), _t(cs["t_limit"]), "%.1f" % float(cs["x_min"])])
	out += Fx.table("(i2) Mit Vollgas (vmax) in eine Rechtskurve, die X % zu schnell ist, mittlere Spur einer dreispurigen Autobahn: Zeit (s) bis eine Spur nach außen / Bankett / Leitplanke außen, ohne Lenken (frei) und mit vollem Gegenlenken (gegen); x min = weitester Punkt außen in 3 s",
		["Fahrzeug", "zu schnell", "sicher km/h", "Spur frei", "Bankett frei", "Spur gegen", "Bankett gegen", "Leitplanke gegen", "x min m"], rows2)
	var rows3: Array = []
	for over: float in [0.10, 0.15, 0.30]:
		var r := understeer_run(cfg, "limousine", over, 1.0, 3.0, 1.0, DT, 0.6)
		rows3.append(["%d %%" % roundi(over * 100.0), "%.1f" % float(r["push_peak"]), _t(r["t_below"]), _t(float(r["t_recovered"]) - float(r["t_below"]) if float(r["t_recovered"]) >= 0.0 else -1.0),
			"%.2f" % float(r["drift_after_m"]), "%.1f" % float(r["x_min"])])
	out += Fx.table("(i3) Erholung: Limousine, 0,6 s zu schnell mit Gegenlenken, dann Vollbremsung (Lenkung los, sobald unter der Grenze)",
		["zu schnell", "Drift max m/s", "unter Grenze nach s", "Drift < 10 % nach s", "danach weiter nach außen m", "x min m"], rows3)
	var rows4: Array = []
	for id: String in ["kompakt", "limousine", "gran_turismo"]:
		for over: float in [0.03, 0.05, 0.08, 0.10, 0.15]:
			var row := [id, "%d %%" % roundi(over * 100.0)]
			for length_m: float in [150.0, 300.0, 520.0]:
				var r := curve_piece_run(cfg, id, over, length_m)
				row.append("%.2f%s" % [float(r["out_max"]), " L" if bool(r["limit"]) else (" B" if bool(r["shoulder"]) else "")])
			rows4.append(row)
	out += Fx.table("(i2b) Spurhalten (Gegenlenken proportional zur Abweichung, Verstärkung 1,5/m) mit Vollgas durch ein echtes Kurvenstück (Einlauf/Auslauf je 30 %), Spitze X % zu schnell: größte Abweichung nach außen (m), B = Bankett, L = Leitplanke",
		["Fahrzeug", "zu schnell", "150 m", "300 m", "520 m"], rows4)
	return out


static func _t(v: Variant) -> String:
	return "–" if float(v) < 0.0 else "%.2f" % float(v)


static func table_accel(cfg: Dictionary) -> String:
	var rows: Array = []
	for id: String in Fx.VEHICLES:
		var r := accel_run(cfg, id)
		rows.append([id, "%d" % int(r["vmax"]), "%.2f" % float(r["t100"]), "%.2f" % float(r["t100_target"]),
			"%+.1f %%" % ((float(r["t100"]) / float(r["t100_target"]) - 1.0) * 100.0),
			"%.2f" % float(r["t200"]), "%.2f" % float(r["t200_target"]),
			"%+.1f %%" % ((float(r["t200"]) / float(r["t200_target"]) - 1.0) * 100.0),
			"%.1f" % float(r["t_top"]), "%.1f" % float(r["a0"]), "%.3f" % float(r["q"])])
	return Fx.table("(h) Beschleunigung 0–100 / 0–200 km/h (Ziel ±10 %)",
		["Fahrzeug", "vmax", "0-100 s", "Ziel", "Abw.", "0-200 s", "Ziel", "Abw.", "0-vmax s", "a0 km/h/s", "q"], rows)


static func table_collision(cfg: Dictionary) -> String:
	var rows: Array = []
	for id: String in Fx.VEHICLES:
		var r := collision_cost(cfg, id, 200.0)
		var acc := int(ConfigLoader.lookup(cfg, "vehicles.types.%s.accel" % id, 0))
		rows.append([id, "%d" % acc, "%.2f" % float(r["slow_s"]), "%.2f" % float(r["end_s"]), "%.2f" % float(r["push_m"]),
			"%.1f" % float(r["back_s"]), "%.2f" % float(r["lost_s"])])
	return Fx.table("(a) Kollision bei 200 km/h – Zeitverlust (Ziel 7–10 s, Pflicht für Beschleunigung 3)",
		["Fahrzeug", "Beschl.", "auf 10 km/h s", "Endpunkt s", "Schub m", "wieder 200 s", "Verlust s"], rows)


static func table_police(cfg: Dictionary) -> String:
	var rows: Array = []
	for id: String in Fx.VEHICLES:
		var row: Array = [id]
		for cruise: float in [140.0, 160.0, 180.0, 200.0]:
			var r := police_caught_cost(cfg, id, cruise)
			row.append("%.1f" % float(r["lost_s"]))
		var r160 := police_caught_cost(cfg, id, 160.0)
		row.append("%.1f" % float(r160["chase_s"]))
		row.append("%.1f + %.1f" % [float(r160["brake_s"]), float(r160["stand_s"])])
		rows.append(row)
	var out := Fx.table("(b) Von der Polizei erwischt – Zeitverlust ab dem Zugriff (Ziel 15–20 s, Referenz 160–180 km/h)",
		["Fahrzeug", "bei 140", "bei 160", "bei 180", "bei 200", "Verfolgung s (160)", "Bremsen + Stehen s"], rows)
	var rows2: Array = []
	for mode: String in ["refuel_only", "refuel_first", "caught_first"]:
		var r := police_refuel_run(cfg, mode)
		var names: Array = []
		for e: Array in r["events"]:
			names.append(str(e[1]))
		rows2.append([mode, "%.1f" % float(r["standstill_s"]), "%.1f" % float(r["refuel_stand_s"]), "%.1f" % float(r["police_extra_s"]),
			" > ".join(names)])
	out += Fx.table("(b2) Erwischt an der Tankstelle (Limousine, ~42 L): Polizeistopp kommt zum Tanken hinzu",
		["Fall", "Stand s", "davon Tanken s", "Polizei s", "Ablauf"], rows2)
	return out


static func table_refuel(cfg: Dictionary) -> String:
	var rows: Array = []
	var r50 := refuel_run(cfg, 50.0, 50.0)
	rows.append(["leerer 50-L-Tank", "50", "%.1f" % float(r50["liters"]), "%.2f" % float(r50["duration_s"]), "%.2f" % float(r50["formula_s"])])
	for id: String in Fx.VEHICLES:
		var spec := VehicleModel.resolve_spec(cfg, id)
		var tank := float(spec["tank_l"])
		var r := refuel_run(cfg, tank, tank)
		rows.append([id + " (leer)", "%d" % int(tank), "%.1f" % float(r["liters"]), "%.2f" % float(r["duration_s"]), "%.2f" % float(r["formula_s"])])
	var half := refuel_run(cfg, 50.0, 25.0)
	rows.append(["halber 50-L-Tank", "50", "%.1f" % float(half["liters"]), "%.2f" % float(half["duration_s"]), "%.2f" % float(half["formula_s"])])
	return Fx.table("(c) Tankdauer = 5 s fest + 2 s je 5 L (leerer 50-L-Tank: 25 s)",
		["Fall", "Tank L", "getankt L", "Dauer s", "Formel s"], rows)


static func table_consumption(cfg: Dictionary) -> String:
	var rows: Array = []
	for v: float in [100.0, 130.0, 180.0, 250.0]:
		var per100 := FuelSystem.base_consumption(cfg, v)
		var sim := consumption_run(cfg, v, 100.0)
		rows.append(["%d" % int(v), "%.2f" % per100, "%.2f" % sim, "%.0f" % (50.0 / per100 * 100.0)])
	var out := Fx.table("(d) Verbrauch (L/100 km) = 14 + 0,00034 v² und Reichweite mit 50 L",
		["km/h", "L/100 km", "simuliert L/100 km", "Reichweite km"], rows)
	var rows2: Array = []
	for id: String in Fx.VEHICLES:
		var spec := VehicleModel.resolve_spec(cfg, id)
		var f := float(spec["consumption_factor"])
		var tank := float(spec["tank_l"])
		var row: Array = [id, "%d" % int(tank), "%.2f" % f]
		for v: float in [130.0, 180.0, 250.0]:
			row.append("%.0f" % (tank / (FuelSystem.base_consumption(cfg, v) * f) * 100.0))
		row.append("%.0f" % (tank / (FuelSystem.base_consumption(cfg, float(spec["vmax_kmh"])) * f) * 100.0))
		rows2.append(row)
	out += Fx.table("(d) Reichweite je Fahrzeug (voller Tank, km)",
		["Fahrzeug", "Tank L", "Faktor", "bei 130", "bei 180", "bei 250", "bei vmax"], rows2)
	return out


static func table_escape(cfg: Dictionary) -> String:
	var rows: Array = []
	for hold: float in [200.0, 210.0, 219.0, 222.0, 230.0]:
		var r := escape_run(cfg, "limousine", hold)
		rows.append(["%d" % int(hold), str(r["result"]), "%.1f" % float(r["chase_s"]), "%.0f" % float(r["min_gap_m"]), "%.1f" % float(r["avg"])])
	var env := EnvironmentModel.new()
	env.setup(cfg)
	for id: String in Fx.VEHICLES:
		var r := escape_run(cfg, id, 400.0, env.vmax_factor(2.0, "rain"), 140.0)
		rows.append(["%s Vollgas ab 140, Regen+Nacht" % id, str(r["result"]), "%.1f" % float(r["chase_s"]), "%.0f" % float(r["min_gap_m"]), "%.1f" % float(r["avg"])])
	var hills2 := float((ConfigLoader.lookup(cfg, "road.hills_max_grade", [0.0, 0.025, 0.045, 0.07]) as Array)[2])
	for id: String in Fx.VEHICLES:
		var r := escape_run(cfg, id, 400.0, env.vmax_factor(2.0, "rain"), 140.0, hills2)
		rows.append(["%s dito, %.1f %% bergauf" % [id, hills2 * 100.0], str(r["result"]), "%.1f" % float(r["chase_s"]), "%.0f" % float(r["min_gap_m"]), "%.1f" % float(r["avg"])])
	var out := Fx.table("(e) Flucht: Tempo halten nach dem Blitzer (Limousine; Flucht ab Ø 220 km/h über 12 s)",
		["Tempo", "Ergebnis", "nach s", "min. Abstand m", "Ø km/h"], rows)
	var best := closest_radar_to_city(cfg)
	if not best.is_empty():
		var plan: StagePlan = best["plan"]
		var rows2: Array = []
		for hold: float in [190.0, 200.0, 210.0, 219.0]:
			var r := chase_into_city_run(cfg, plan, "kompakt", hold, -1.0, best["radar"])
			rows2.append(["%d" % int(hold), "%.1f" % float(r["flash_km"]), str(r["end"]), "%.1f" % float(r["end_km"]), "%.1f" % float(r["chase_s"]),
				"%.1f" % float(r["city_chase_km"])])
		out += Fx.table("(e2) Verfolgung in die City Limits: %s, Radar km %.0f–%.0f, City Limits ab km %.0f (Kompakt hält das Tempo)" % [
			plan.display_name, float(best["radar"]["km"]), float(best["radar"]["end_km"]), plan.city_limits_km],
			["Tempo", "geblitzt km", "Ende", "bei km", "Verfolgung s", "km in den City Limits"], rows2)
	return out


static func table_rain_night(cfg: Dictionary) -> String:
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var rows: Array = []
	var maxes: Array = ConfigLoader.lookup(cfg, "road.hills_max_grade", [0.0, 0.025, 0.045, 0.07])
	for id: String in Fx.VEHICLES:
		var rn := accel_run(cfg, id, env.vmax_factor(2.0, "rain"))
		var sn := accel_run(cfg, id, env.vmax_factor(2.0, "snow"))
		var sd := accel_run(cfg, id, env.vmax_factor(12.0, "snow"))
		var v := Fx.vehicle(cfg, id)
		rows.append([id, "%d" % int(rn["vmax"]), "%.1f" % float(rn["top"]), "%.1f" % float(rn["t220"]),
			"%.1f" % v.max_speed(float(maxes[2]), env.vmax_factor(2.0, "rain")), "%.1f" % v.max_speed(float(maxes[3]), 1.0),
			"%.1f" % v.max_speed(float(maxes[3]), env.vmax_factor(2.0, "rain")), "%.1f" % float(sd["top"]), "%.1f" % float(sn["top"])])
	return Fx.table("(f) Höchstgeschwindigkeit bei Regen in der Nacht (Ziel >= 220 km/h, auch an Steigungen bis Hügelstufe 2 = %.1f %%), Hügelstufe 3 (%.0f %%) und Schnee" % [
		float(maxes[2]) * 100.0, float(maxes[3]) * 100.0],
		["Fahrzeug", "vmax", "Regen+Nacht km/h", "0-220 s", "R+N 4,5 %", "trocken 7 %", "R+N 7 %", "Schnee Tag", "Schnee+Nacht"], rows)


static func table_traffic(cfg: Dictionary) -> String:
	var rows: Array = []
	var d8 := density_at(cfg, 8.0)
	var d3 := density_at(cfg, 3.0)
	var d12 := density_at(cfg, 12.0)
	var d17 := density_at(cfg, 17.5)
	var d23 := density_at(cfg, 23.5)
	rows.append(["Dichte 08:00 (Autobahn, Fz/km)", "%.2f" % d8, ""])
	rows.append(["Dichte 03:00", "%.2f" % d3, "x%.2f von 08:00" % (d3 / d8)])
	rows.append(["Dichte 12:00 / 17:30 / 23:30", "%.2f / %.2f / %.2f" % [d12, d17, d23], ""])
	var dc := density_at(cfg, 12.0, true)
	rows.append(["Verfolgung (12:00)", "%.2f" % dc, "x%.2f (-%.0f %%)" % [dc / d12, (1.0 - dc / d12) * 100.0]])
	var dcity := density_at(cfg, 12.0, false, "city", true)
	var dcity_road := density_at(cfg, 12.0, false, "city", false)
	rows.append(["City Limits (12:00)", "%.2f" % dcity, "x%.2f vs. Stadtstraße ohne City Limits, x%.2f vs. Autobahn" % [dcity / dcity_road, dcity / d12]])
	# simulated: visible cars and speeds
	var day := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 12.0, 160.0, 60.0)
	var night := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 0.5, 160.0, 60.0)
	var rush := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 8.0, 160.0, 60.0)
	var early := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 3.0, 160.0, 60.0)
	var chased := traffic_run(cfg, FakeTrack.new(80000.0, "autobahn", 3), 12.0, 225.0, 75.0, {"chase_at": 30.0, "settle": 15.0})
	var city_track := FakeTrack.new(60000.0, "autobahn", 3)
	city_track.city_z = 0.0
	var city := traffic_run(cfg, city_track, 12.0, 80.0, 60.0)
	var stopped := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 17.5, 0.0, 60.0, {"player_x": 0.0, "start_z": 3000.0})
	rows.append(["sim: sichtbare Autos 08:00 / 03:00", "%.1f / %.1f" % [float(rush["avg_visible"]), float(early["avg_visible"])], "Spieler 160 km/h"])
	rows.append(["sim: Ø Wunschtempo neuer Autos 12:00 / 00:30", "%.1f / %.1f km/h" % [float(day["avg_cruise_unique"]), float(night["avg_cruise_unique"])],
		"Faktor je Auto %.3f / %.3f" % [float(day["speed_factor_unique"]), float(night["speed_factor_unique"])]])
	rows.append(["sim: sichtbare Autos vor / in Verfolgung", "%.1f / %.1f" % [float(chased["avg_visible"]), float(chased["avg_visible_after"])],
		"x%.2f (Spieler 225 km/h, 15 s nach Beginn)" % (float(chased["avg_visible_after"]) / maxf(0.01, float(chased["avg_visible"])))])
	rows.append(["sim: sichtbare Autos City Limits", "%.1f" % float(city["avg_visible"]), "Spieler 80 km/h"])
	var runs: Array = [day, night, rush, early, chased, city, stopped]
	var overlaps := 0
	var pops := 0
	for r: Dictionary in runs:
		overlaps += int(r["overlaps"])
		pops += int(r["pops_in"]) + int(r["pops_out"])
	rows.append(["sim: Überlappungen Auto/Auto (alle Läufe)", "%d" % overlaps, "muss 0 sein"])
	rows.append(["sim: Auftauchen/Verschwinden im Bild", "%d" % pops, "muss 0 sein"])
	rows.append(["sim: Spieler steht auf der Fahrbahn (17:30)", "%d Treffer" % int(stopped["player_hits"]), "%d Autos ausgewichen/gebremst" % int(stopped["unique_cars"])])
	rows.append(["sim: Spurwechsel in 60 s (12:00)", "%d" % int(day["lane_changes"]), ""])
	var lkw := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 12.0, 160.0, 60.0)
	var r_trucks: Array = ConfigLoader.lookup(cfg, "traffic.truck_speeds_kmh.autobahn", [80, 90])
	var r_bus: Array = ConfigLoader.lookup(cfg, "traffic.bus_speeds_kmh.autobahn", [95, 100])
	rows.append(["sim: Wunschtempo Autobahn 12:00 min Pkw (schwere min–max)", "%.1f (%.1f–%.1f) km/h" % [float(lkw["min_cruise_car"]),
		float(lkw["min_cruise_heavy"]), float(lkw["max_cruise_heavy"])], "Lkw %d–%d, Busse %d–%d km/h" % [int(r_trucks[0]), int(r_trucks[1]), int(r_bus[0]), int(r_bus[1])]])
	var snow := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 12.0, 160.0, 60.0, {"weather": "snow"})
	var rain := traffic_run(cfg, FakeTrack.new(60000.0, "autobahn", 3), 12.0, 160.0, 60.0, {"weather": "rain"})
	rows.append(["sim: Ø Wunschtempo neuer Autos 12:00 trocken / Regen / Schnee", "%.1f / %.1f / %.1f km/h" % [float(lkw["avg_cruise_unique"]),
		float(rain["avg_cruise_unique"]), float(snow["avg_cruise_unique"])], "traffic.weather"])
	var land := traffic_run(cfg, FakeTrack.new(60000.0, "landstrasse", 2), 17.0, 90.0, 120.0, {"seed": 7})
	var no_yield := ConfigLoader.deep_merge(cfg, {"traffic": {"yield_slowdown_kmh": 0.0, "pass_boost_kmh": 0.0}})
	var land0 := traffic_run(no_yield, FakeTrack.new(60000.0, "landstrasse", 2), 17.0, 90.0, 120.0, {"seed": 7})
	rows.append(["sim: Landstraße 17:00, Spieler 90 km/h, 120 s", "%.1f s (ohne Regel %.1f s)" % [float(land["max_side_by_side_s"]), float(land0["max_side_by_side_s"])],
		"längstes Nebeneinander zweier gleich schneller Autos (rollende Sperre)"])
	return Fx.table("(g) Verkehr: Tageskurve, Nacht x%.2f, Verfolgung -80 %%, City Limits x2,5" % float(ConfigLoader.lookup(cfg, "traffic.night.speed_factor", 1.0)),
		["Größe", "Wert", "Bemerkung"], rows)
