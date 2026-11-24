extends SceneTree
## Objective difficulty of the traffic (docs/gameplay.md "Schwierigkeit"): real StagePlan/Track, TrafficSystem,
## VehicleModel and EnvironmentModel, no police and no fuel stops (the tank is topped up), one stage direction per
## run. Drivers:
##   naive      full throttle, brakes only for curves (Autopilot.curve_speed_ahead), steers around traffic: it
##              changes to the neighbour lane with the most room when its lane closes within ~2.2 s, but never
##              brakes for a car – every time all lanes are shut it collides
##   autopilot  the real Autopilot (target 300 = always vmax, radar ignored, never refuels) – brakes and follows
##   late       the naive driver who also brakes – like on a dry road (70 km/h/s, 0.3 s), at the last moment that would
##              be enough there – when it cannot weave: what rain and snow do to a player who does not adapt
##   dryhabit   the same Autopilot with weather_aware = false: brakes for traffic, picks its gaps and steers as on a
##              dry road (curves with the real grip) – what the weather asks of a driver who does not adapt
## Measured (naive bot, per run and in total):
##   closing   speed difference to every car it passes (km/h: median, p10, p90)
##   blocked   share of the time in which every lane has a car within the stopping distance of a car at top speed
##             ((v - v_car)² / 2a + (v - v_car) · 1 s + 10 m, a = full braking of the car in this weather):
##             there is no way past without braking; plus such events per 100 km
##   lc/km     lane changes per km (odometer) the bot needs to keep its speed
##   coll      collisions per 100 km (odometer) – naive and autopilot; autopilot also its average speed,
##             seconds off the road and the most understeer
##   godot --headless --path . -s res://tests/sim/difficulty_sim.gd -- [--stages=kassel_wuerzburg,saragossa_pau]
##       [--weathers=normal,rain,snow] [--hours=7.5,0.5] [--vehicle=limousine] [--drivers=naive,late,autopilot,dryhabit]
##       [--seed=0] [--json=<file>] [--km=<limit per stage>]
## Owner: gameplay module (diagnostics only).

const DT := 1.0 / 60.0
const SAMPLE_EVERY := 6          ## metrics every 0.1 s

## Duck-typed race session for the Autopilot (it reads these fields).
class SimSession extends Node:
	var track: Track
	var vehicle: VehicleModel
	var traffic: TrafficSystem
	var fuel: FuelSystem
	var plan: StagePlan
	var env: EnvironmentModel
	var weather := "normal"
	var pos_z := 0.0
	var pos_km := 0.0


var cfg: Dictionary
var net: Dictionary
var countries: Dictionary
var cities := {}
var dims := {}
var car_sets: Array[String] = []
var heavy_sets: Array[String] = []


func _initialize() -> void:
	cfg = ConfigLoader.load_merged()
	net = ConfigLoader.load_json("res://data/network.json")
	countries = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var man: Variant = ConfigLoader.load_json("res://assets/sprites/manifest.json")
	if man is Dictionary:
		var sets: Dictionary = (man as Dictionary).get("sets", {})
		for id: String in sets:
			var tags: Array = (sets[id] as Dictionary).get("tags", [])
			if tags.has("traffic"):
				dims[id] = sets[id]
				if tags.has("heavy"):
					heavy_sets.append(id)
				else:
					car_sets.append(id)
	var args := CliArgs.all()
	var stages := str(args.get("stages", "kassel_wuerzburg,saragossa_pau,hamburg_hannover")).split(",")
	var weathers := str(args.get("weathers", "normal,rain,snow")).split(",")
	var hours: Array[float] = []
	for h in str(args.get("hours", "7.5,0.5")).split(","):
		hours.append(float(h))
	var drivers := str(args.get("drivers", "naive,late,autopilot")).split(",")
	var vehicle_id := str(args.get("vehicle", "limousine"))
	var seed := int(args.get("seed", 0))
	var km_limit := float(args.get("km", 0.0))
	var runs: Array = []
	var t0 := Time.get_ticks_msec()
	for w in weathers:
		for h in hours:
			for d in drivers:
				var total := {"open": _new_stats(), "city": _new_stats()}
				for st in stages:
					var r := run(st, w, h, d, vehicle_id, seed, km_limit)
					for zone: String in total:
						_merge(total[zone], r[zone])
				for zone: String in total:
					var row := _summary(total[zone])
					row["weather"] = w
					row["hour"] = h
					row["driver"] = d
					row["zone"] = zone
					runs.append(row)
					print("RUN %-6s %5.1f h %-9s %-4s %s  (%.0f s)" % [w, h, d, zone, JSON.stringify(row), (Time.get_ticks_msec() - t0) / 1000.0])
	print(_table(runs))
	if args.has("json"):
		var f := FileAccess.open(str(args["json"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(runs, "  "))
	quit(0)


func _new_stats() -> Dictionary:
	return {"km": 0.0, "time_s": 0.0, "collisions": 0, "lane_changes": 0, "closing": [],
		"samples": 0, "blocked_samples": 0, "blocked_events": 0, "off_road_s": 0.0, "understeer_max": 0.0,
		"rail_hits": 0, "free_time_s": 0.0, "car_kmh": [], "heavy_kmh": [],
		"visible_sum": 0.0, "two_lane_heavy_s": 0.0, "cut_ins": 0}


func _merge(a: Dictionary, b: Dictionary) -> void:
	for k: String in ["km", "time_s", "collisions", "lane_changes", "samples", "blocked_samples", "blocked_events", "off_road_s",
			"rail_hits", "free_time_s", "visible_sum", "two_lane_heavy_s", "cut_ins"]:
		a[k] = a[k] + b[k]
	a["understeer_max"] = maxf(float(a["understeer_max"]), float(b["understeer_max"]))
	for k: String in ["closing", "car_kmh", "heavy_kmh"]:
		(a[k] as Array).append_array(b[k])


static func _pct(arr: Array, p: float) -> float:
	if arr.is_empty():
		return NAN
	var s := PackedFloat32Array(arr)
	s.sort()
	return s[clampi(int(floor(p * float(s.size() - 1) + 0.5)), 0, s.size() - 1)]


func _summary(s: Dictionary) -> Dictionary:
	var km := maxf(float(s["km"]), 0.001)
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	return {
		"km": snappedf(km, 0.1),
		"avg_kmh": snappedf(Units.avg_speed_kmh(km, float(s["time_s"]), ts), 0.1),
		"coll_per_100km": snappedf(float(s["collisions"]) * 100.0 / km, 0.01),
		"collisions": int(s["collisions"]),
		"lc_per_km": snappedf(float(s["lane_changes"]) / km, 0.001),
		"closing_p10": snappedf(_pct(s["closing"], 0.1), 0.1),
		"closing_p50": snappedf(_pct(s["closing"], 0.5), 0.1),
		"closing_p90": snappedf(_pct(s["closing"], 0.9), 0.1),
		"passes": (s["closing"] as Array).size(),
		"blocked_pct": snappedf(100.0 * float(s["blocked_samples"]) / maxf(1.0, float(s["samples"])), 0.01),
		"blocked_per_100km": snappedf(float(s["blocked_events"]) * 100.0 / km, 0.1),
		"off_road_s": snappedf(float(s["off_road_s"]), 0.01),
		"rail_hits": int(s["rail_hits"]),
		"understeer_max": snappedf(float(s["understeer_max"]), 0.001),
		"car_kmh_p50": snappedf(_pct(s["car_kmh"], 0.5), 0.1),
		"car_kmh_p10": snappedf(_pct(s["car_kmh"], 0.1), 0.1),
		"car_kmh_p90": snappedf(_pct(s["car_kmh"], 0.9), 0.1),
		"heavy_kmh_p50": snappedf(_pct(s["heavy_kmh"], 0.5), 0.1),
		"visible_avg": snappedf(float(s["visible_sum"]) / maxf(1.0, float(s["samples"])), 0.1),
		"two_heavy_side_s_per_100km": snappedf(float(s["two_lane_heavy_s"]) * 100.0 / km, 0.1),
		"cut_ins_per_100km": snappedf(float(s["cut_ins"]) * 100.0 / km, 0.1),
	}


func _table(rows: Array) -> String:
	var out := "\n== Schwierigkeit (Summe aller Etappen; open = Autobahn/Landstraße, city = City Limits) ==\n"
	out += "Wetter  Uhr    Fahrer    Zone    km     Ø km/h  Koll/100km  Spurw/km  Annäh p10/p50/p90  alle Spuren zu %  /100km  sichtbar  Pkw p50  Lkw p50\n"
	for r: Dictionary in rows:
		out += "%-7s %5.1f  %-9s %-4s %6.0f  %6.1f  %9.2f  %8.3f  %5.0f/%4.0f/%4.0f    %8.2f        %6.1f  %6.1f   %6.1f   %6.1f\n" % [
			r["weather"], float(r["hour"]), r["driver"], r["zone"], float(r["km"]), float(r["avg_kmh"]), float(r["coll_per_100km"]),
			float(r["lc_per_km"]), float(r["closing_p10"]), float(r["closing_p50"]), float(r["closing_p90"]), float(r["blocked_pct"]),
			float(r["blocked_per_100km"]), float(r["visible_avg"]), float(r["car_kmh_p50"]), float(r["heavy_kmh_p50"])]
	return out


func _stage(id: String) -> Dictionary:
	for s: Dictionary in net.get("stages", []):
		if str(s["id"]) == id:
			return s
	return {}


## Full braking of the car in this weather (m/s²): VehicleModel.brake_decel_mps2(grip) when the model has it.
func _brake_mps2(v: VehicleModel, grip: float) -> float:
	if v.has_method("brake_decel_mps2"):
		return float(v.call("brake_decel_mps2", grip))
	return float(ConfigLoader.lookup(cfg, "driving.brake_decel_kmh_s", 70.0)) / 3.6


func run(stage_id: String, weather: String, hour: float, driver: String, vehicle_id: String, seed: int, km_limit: float) -> Dictionary:
	var zones := {"open": _new_stats(), "city": _new_stats()}
	var stats: Dictionary = zones["open"]
	var stage := _stage(stage_id)
	if stage.is_empty():
		push_error("Etappe fehlt: " + stage_id)
		return zones
	var plan := StagePlan.build(stage, "", cities, countries, cfg)
	var track := Track.new()
	track.setup(plan, cfg, {})
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var clock := WorldClock.new()
	clock.setup(cfg, hour * 60.0)
	var v := VehicleModel.new()
	v.setup(cfg, vehicle_id)
	var traffic := TrafficSystem.new()
	traffic.setup(cfg, track, car_sets, heavy_sets, plan.seed + 17 + seed)
	traffic.set_dimensions(dims)
	var fuel := FuelSystem.new()
	fuel.setup(cfg, v.spec, plan)
	var proj := RoadProjection.new()
	proj.setup(ConfigLoader.lookup(cfg, "render", {}), Vector2(1280, 720))
	var sess := SimSession.new()
	sess.track = track
	sess.vehicle = v
	sess.traffic = traffic
	sess.fuel = fuel
	sess.plan = plan
	sess.env = env
	sess.weather = weather
	var ap := Autopilot.new()
	ap.target_kmh = 300.0
	ap.obey_radar = false
	ap.refuel_mode = "never"
	if "weather_aware" in ap:
		ap.set("weather_aware", driver != "dryhabit")
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var draw := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	var cam_d := proj.cam_distance
	var wgrip := env.grip(weather)
	var z := track.km_to_z(0.5)
	var km := track.z_to_km(z)
	var end_km := plan.length_km - 0.3 if km_limit <= 0.0 else minf(plan.length_km - 0.3, km_limit)
	track.update_window(z - cam_d, draw + 60.0)
	v.x = track.lane_center_x(z, track.lane_count_at(z) - 1)
	v.speed = 120.0
	var bot := {"lane": track.lane_count_at(z) - 1, "t_eval": 0.0}
	var t := 0.0
	var step := 0
	var ahead_ids := {}
	var was_blocked := false
	var lane_prev := int(bot["lane"])
	var crash_seen := false
	traffic.update(0.0, {"z": z, "x": v.x, "speed": v.speed}, {"hour": clock.hour(), "chase": false, "camera_z": z - cam_d,
		"weather": weather, "visibility_m": draw * env.visibility_factor(clock.hour(), weather, false)})
	var km_zone := km
	var cut_seen := 0
	while km < end_km and t < 3600.0:
		var zone_now: Dictionary = zones["city" if plan.is_city(km) else "open"]
		if not is_same(zone_now, stats):
			stats["km"] = float(stats["km"]) + km - km_zone
			km_zone = km
			stats = zone_now
		var hour_now := clock.hour()
		sess.pos_z = z
		sess.pos_km = km
		fuel.fuel_l = fuel.tank_l
		var input: Dictionary
		if driver == "autopilot" or driver == "dryhabit":
			input = ap.drive(sess)
		else:
			# the naive driver sees what the screen shows: cars up to the sight distance
			bot["vis_end"] = z - cam_d + draw * env.visibility_factor(hour_now, weather, track.is_tunnel_at(z - cam_d + 5.0))
			input = _naive(bot, track, traffic, v, ap, z, wgrip)
			if driver == "late":
				_late_brake(input, bot, track, traffic, v, z)
		v.update(DT, input, _road(track, z, wgrip), {"vmax_factor": env.vmax_factor(hour_now, weather)})
		var dz := v.speed / 3.6 * DT
		z += dz
		km = track.z_to_km(z)
		var cam_z := z - cam_d
		track.update_window(cam_z, draw + 60.0)
		var vis := draw * env.visibility_factor(hour_now, weather, track.is_tunnel_at(cam_z + 5.0))
		traffic.update(DT, {"z": z, "x": v.x, "speed": v.speed}, {"hour": hour_now, "chase": false, "camera_z": cam_z,
			"visibility_m": vis, "weather": weather, "brake_mps2": _brake_mps2(v, wgrip)})
		if not v.invulnerable:
			var hit := traffic.find_collision({"z": z, "x": v.x, "length": v.length_m, "width": v.width_m}, cam_z, proj.visible_fraction)
			if hit != null:
				var e := track.road_edges_at(z)
				var space := traffic.space_beside(z, v.x, v.length_m * 0.5, e.x - track.shoulder_w, e.y + track.shoulder_w, hit)
				v.start_crash(hit.x, space.x, space.y)
		if v.state == VehicleModel.State.CRASH and not crash_seen:
			stats["collisions"] = int(stats["collisions"]) + 1
		crash_seen = v.state == VehicleModel.State.CRASH
		if "cut_ins" in traffic:
			var ci := int(traffic.get("cut_ins"))
			stats["cut_ins"] = int(stats["cut_ins"]) + ci - cut_seen
			cut_seen = ci
		clock.advance(DT)
		t += DT
		stats["time_s"] = float(stats["time_s"]) + DT
		step += 1
		if v.off_road > 0:
			stats["off_road_s"] = float(stats["off_road_s"]) + DT
		if v.rail_hit:
			stats["rail_hits"] = int(stats["rail_hits"]) + 1
		stats["understeer_max"] = maxf(float(stats["understeer_max"]), v.understeer)
		if (driver == "naive" or driver == "late") and int(bot["lane"]) != lane_prev:
			stats["lane_changes"] = int(stats["lane_changes"]) + 1
			lane_prev = int(bot["lane"])
		# passes: a car that was ahead of the player's front is now behind it
		var now_ahead := {}
		for c in traffic.cars:
			if c.z > z:
				now_ahead[c.id] = c.speed
			elif ahead_ids.has(c.id) and absf(c.z - z) < 40.0:
				(stats["closing"] as Array).append(v.speed - c.speed)
		ahead_ids = now_ahead
		if step % SAMPLE_EVERY == 0:
			stats["samples"] = int(stats["samples"]) + 1
			var blocked := _all_lanes_blocked(track, traffic, z, v, _brake_mps2(v, track.grip_at(z, wgrip)))
			if blocked:
				stats["blocked_samples"] = int(stats["blocked_samples"]) + 1
				if not was_blocked:
					stats["blocked_events"] = int(stats["blocked_events"]) + 1
			was_blocked = blocked
			var visible := 0
			var heavy_side := false
			for c in traffic.cars:
				if c.z - c.length * 0.5 > cam_z and c.z < cam_z + vis:
					visible += 1
					if c.heavy:
						(stats["heavy_kmh"] as Array).append(c.speed)
					else:
						(stats["car_kmh"] as Array).append(c.speed)
					if c.heavy and not heavy_side:
						for o in traffic.cars:
							if o != c and o.heavy and absf(o.z - c.z) < (o.length + c.length) * 0.5 and absf(o.x - c.x) > 2.0 and absf(o.x - c.x) < 5.0:
								heavy_side = true
								break
			stats["visible_sum"] = float(stats["visible_sum"]) + float(visible)
			if heavy_side:
				stats["two_lane_heavy_s"] = float(stats["two_lane_heavy_s"]) + DT * SAMPLE_EVERY
	stats["km"] = float(stats["km"]) + km - km_zone
	sess.free()
	return zones


func _road(track: Track, z: float, wgrip: float) -> Dictionary:
	var e := track.road_edges_at(z)
	var seg := track.segment_at(z)
	return {"curve": track.curve_at(z), "grade": track.grade_at(z), "left_edge": e.x, "right_edge": e.y,
		"shoulder_m": track.shoulder_w, "guardrail": seg.guardrail or seg.tunnel, "grip": track.grip_at(z, wgrip)}


## Lanes whose corridor the car's body reaches into (half a lane + half the body - 0.25 m around its centre),
## plus the lane it signals into (when the traffic system has blinkers).
func _car_lanes(track: Track, c: TrafficSystem.Car) -> Vector2i:
	var lanes := track.lane_count_at(c.z)
	var x0 := track.lane_center_x(c.z, 0)
	var lw := track.lane_w
	var rel := (c.x - x0) / lw
	var r := (lw * 0.5 + c.width * 0.5 - 0.25) / lw
	var lo := int(floorf(rel - r)) + 1
	var hi := int(ceilf(rel + r)) - 1
	if "signal_dir" in c:
		var sd := int(c.get("signal_dir"))
		if sd < 0:
			lo = mini(lo, c.lane - 1)
		elif sd > 0:
			hi = maxi(hi, c.lane + 1)
	return Vector2i(clampi(lo, 0, lanes), clampi(hi, -1, lanes - 1))


## Every lane has a car ahead within the stopping distance of a car at top speed (vmax_effective).
func _all_lanes_blocked(track: Track, traffic: TrafficSystem, z: float, v: VehicleModel, a_brake: float) -> bool:
	var lanes := track.lane_count_at(z)
	var vp := v.vmax_effective / 3.6
	var blocked := []
	blocked.resize(lanes)
	blocked.fill(false)
	for c in traffic.cars:
		var gap := c.z - z - (c.length + v.length_m) * 0.5
		if gap < -2.0 or gap > 600.0:
			continue
		var rel := maxf(0.0, vp - c.speed / 3.6)
		var need := rel * rel / (2.0 * a_brake) + rel * 1.0 + 10.0
		if gap > need:
			continue
		var occ := _car_lanes(track, c)
		for l in range(maxi(0, occ.x), mini(lanes - 1, occ.y) + 1):
			blocked[l] = true
	for b: bool in blocked:
		if not b:
			return false
	return true


## The naive driver: full throttle except for curves, weaves around the traffic it can see (sight distance of the
## weather/night), never brakes for a car. It steers like a keyboard player: full lock towards the lane, letting go
## when the slide it knows from a dry road (lateral speed × 0.12 s) will carry it there – on a slippery road it
## slides past and swings back.
func _naive(bot: Dictionary, track: Track, traffic: TrafficSystem, v: VehicleModel, ap: Autopilot, z: float, wgrip: float) -> Dictionary:
	var lanes := mini(track.lane_count_at(z), track.lane_count_at(z + 90.0))
	var lane := clampi(int(bot["lane"]), 0, lanes - 1)
	var vis_end := float(bot.get("vis_end", z + 900.0))
	bot["t_eval"] = float(bot["t_eval"]) - DT
	if float(bot["t_eval"]) <= 0.0:
		bot["t_eval"] = 0.1
		var here := _lane_room(track, traffic, z, v, lane, vis_end)
		var vp := v.speed / 3.6
		if here < vp * 2.2 + 25.0:
			var best := lane
			var best_room := here + 15.0
			for cand: int in [lane - 1, lane + 1]:
				if cand < 0 or cand >= lanes or not _lane_enterable(track, traffic, z, v, cand):
					continue
				var room := _lane_room(track, traffic, z, v, cand, vis_end)
				if room > best_room:
					best = cand
					best_room = room
			lane = best
	bot["lane"] = lane
	var want := ap.curve_speed_ahead(track, v, z, wgrip)
	var out := Autopilot.pedals(v.speed, minf(want, 400.0))
	var err := track.lane_center_x(z + 12.0, lane) - v.x
	var steer := 0.0
	if absf(err) > absf(v.lat_speed) * 0.12 + 0.25 or (absf(err) > 0.25 and signf(err) != signf(v.lat_speed)):
		steer = signf(err)
	out["steer"] = steer
	return out


## The late braker: the naive driver who also brakes – like on a dry road (full 70 km/h/s braking, 0.3 s to react),
## at the last moment that would be enough there – when the car in its lane closes in and it cannot weave.
func _late_brake(input: Dictionary, bot: Dictionary, track: Track, traffic: TrafficSystem, v: VehicleModel, z: float) -> void:
	var lane := int(bot["lane"])
	var vis_end := float(bot.get("vis_end", z + 900.0))
	var dry := float(ConfigLoader.lookup(cfg, "driving.brake_decel_kmh_s", 70.0)) / 3.6
	var vp := v.speed / 3.6
	for c in traffic.cars:
		var gap := c.z - z - (c.length + v.length_m) * 0.5
		if gap < -1.0 or gap > 400.0 or c.z - c.length * 0.5 > vis_end:
			continue
		var occ := _car_lanes(track, c)
		if (lane < occ.x or lane > occ.y) and absf(c.x - v.x) > (c.width + v.width_m) * 0.5 + 0.3:
			continue
		var rel := vp - c.speed / 3.6
		if rel > 0.0 and gap < rel * rel / (2.0 * dry) + rel * 0.3 + 6.0:
			input["throttle"] = 0.0
			input["brake"] = 1.0
			return


## Free road ahead in a lane, in "metres at top speed": gap to the nearest car occupying it scaled by how much
## slower that car is (a car at the player's speed never closes in). Cars beyond vis_end are not seen.
func _lane_room(track: Track, traffic: TrafficSystem, z: float, v: VehicleModel, lane: int, vis_end: float = INF) -> float:
	var vp := maxf(v.speed / 3.6, 1.0)
	var best := 1000.0
	for c in traffic.cars:
		var gap := c.z - z - (c.length + v.length_m) * 0.5
		if gap < -1.0 or gap > 700.0 or c.z - c.length * 0.5 > vis_end:
			continue
		var occ := _car_lanes(track, c)
		if lane < occ.x or lane > occ.y:
			continue
		var rel := vp - c.speed / 3.6
		if rel <= 0.5:
			continue
		best = minf(best, maxf(gap, 0.0) * vp / rel)
	return best


## No car beside the player in that lane (it would be side-swiped).
func _lane_enterable(track: Track, traffic: TrafficSystem, z: float, v: VehicleModel, lane: int) -> bool:
	for c in traffic.cars:
		var occ := _car_lanes(track, c)
		if lane < occ.x or lane > occ.y:
			continue
		var dz := c.z - z
		var rel := v.speed / 3.6 - c.speed / 3.6
		var front := (c.length + v.length_m) * 0.5 + 4.0 + maxf(0.0, rel) * 0.7
		var back := (c.length + v.length_m) * 0.5 + 3.0 + maxf(0.0, -rel) * 0.7
		if dz < front and dz > -back:
			return false
	return true
