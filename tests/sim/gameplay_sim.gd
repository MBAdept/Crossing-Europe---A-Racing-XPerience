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
		"stand_s": t_release - t_stand, "lost_s": lost}


# --- (e) escape ------------------------------------------------------------------------------

## Flashed at hold_kmh (entering a 120 zone at that speed), then holding hold_kmh (or the car's maximum).
## Result: escaped / caught, after how many seconds.
static func escape_run(cfg: Dictionary, id: String, hold_kmh: float, vmax_factor: float = 1.0, start_kmh: float = -1.0) -> Dictionary:
	var plan := Fx.make_plan(cfg, 300.0, [], [{"km": 20.0, "limit": 120}])
	var police := PoliceSystem.new()
	police.setup(cfg, plan)
	var v := Fx.vehicle(cfg, id)
	v.speed = hold_kmh if start_kmh < 0.0 else start_kmh
	var road := Fx.flat_road()
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
		"avg": police.avg_speed}


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
	while t < warmup + seconds:
		var since := t - warmup
		var chase := chase_all or (chase_at >= 0.0 and since >= chase_at)
		ts.update(DT, {"z": pz, "x": px, "speed": player_kmh}, {"hour": hour, "chase": chase, "camera_z": pz - cam_dist})
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
		sum_all += ts.cars.size()
		for c in ts.cars:
			if c.z + c.length * 0.5 > cam and c.z - c.length * 0.5 < cam + vis:
				if after:
					sum_vis_after += 1.0
				elif chase_at < 0.0 or since < chase_at:
					sum_vis += 1.0
			if not seen.has(c.id):
				seen[c.id] = true
				sum_cruise_unique += c.cruise_speed
				var r: Array = ConfigLoader.lookup(cfg, ("traffic.truck_speeds_kmh." if c.heavy else "traffic.speeds_kmh.") + str(track.road_type_at(c.z)), [100, 130])
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
	var n_before := n - n_after if chase_at >= 0.0 else n
	if chase_at >= 0.0:
		n_before = int(minf(float(n), chase_at / DT))
	return {"avg_visible": sum_vis / maxf(1.0, n_before), "avg_visible_after": sum_vis_after / maxf(1.0, n_after),
		"avg_cars": sum_all / maxf(1.0, n),
		"avg_speed": sum_speed / maxf(1.0, speed_n), "avg_cruise": sum_cruise / maxf(1.0, speed_n),
		"unique_cars": seen.size(), "avg_cruise_unique": sum_cruise_unique / maxf(1.0, seen.size()),
		"speed_factor_unique": sum_factor_unique / maxf(1.0, seen.size()),
		"overlaps": overlaps, "player_hits": player_hits, "min_gap": min_gap, "lane_changes": lane_changes,
		"fuel_users": fuel_users.size(), "target": ts.target_count, "spawned": ts.spawned_total,
		"pops_in": pops_in, "pops_out": pops_out, "hidden_culls": hidden_culls, "heavy_seen": heavy_ids.size(), "heavy_lane0_frames": heavy_lane0,
		"heavy_right_share": float(heavy_right) / maxf(1.0, heavy_frames), "braking_frames": braking_seen, "system": ts}


## Cars per visible km (all lanes) for the given hour: TrafficSystem.density_per_km_at on a plain autobahn.
static func density_at(cfg: Dictionary, hour: float, chase: bool = false, road: String = "autobahn", city: bool = false) -> float:
	var track := FakeTrack.new(5000.0, road, 3 if road == "autobahn" else 2)
	if city:
		track.city_z = 0.0
	var ts := TrafficSystem.new()
	var empty: Array[String] = []
	ts.setup(cfg, track, empty, empty, 1)
	return ts.density_per_km_at(1000.0, hour, chase)


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
	return out


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
	return Fx.table("(b) Von der Polizei erwischt – Zeitverlust ab dem Zugriff (Ziel 15–20 s, Referenz 160–180 km/h)",
		["Fahrzeug", "bei 140", "bei 160", "bei 180", "bei 200", "Verfolgung s (160)", "Bremsen + Stehen s"], rows)


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
	return Fx.table("(e) Flucht: Tempo halten nach dem Blitzer (Limousine; Flucht ab Ø 220 km/h über 12 s)",
		["Tempo", "Ergebnis", "nach s", "min. Abstand m", "Ø km/h"], rows)


static func table_rain_night(cfg: Dictionary) -> String:
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var rows: Array = []
	for id: String in Fx.VEHICLES:
		var rn := accel_run(cfg, id, env.vmax_factor(2.0, "rain"))
		var sn := accel_run(cfg, id, env.vmax_factor(2.0, "snow"))
		var sd := accel_run(cfg, id, env.vmax_factor(12.0, "snow"))
		rows.append([id, "%d" % int(rn["vmax"]), "%.1f" % float(rn["top"]), "%.1f" % float(rn["t220"]),
			"%.1f" % float(sd["top"]), "%.1f" % float(sn["top"])])
	return Fx.table("(f) Höchstgeschwindigkeit bei Regen in der Nacht (Ziel >= 220 km/h) und Schnee",
		["Fahrzeug", "vmax", "Regen+Nacht km/h", "0-220 s", "Schnee Tag", "Schnee+Nacht"], rows)


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
	return Fx.table("(g) Verkehr: Tageskurve, Nacht +15 %, Verfolgung -80 %, City Limits x2,5",
		["Größe", "Wert", "Bemerkung"], rows)
