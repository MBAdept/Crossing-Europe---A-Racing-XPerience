extends RefCounted
## Sight check of the curves (driving model): is braking from the moment a curve becomes visible always enough?
## Used by tests/sim/curve_sight.gd (all stages) and tests/unit/race/test_track.gd.
## For a stage (real StagePlan/Track) every stretch whose safe curve speed is below the approach speed is
## checked (weather grip; dry inside tunnels, Track.grip_at). Approach speed: full throttle out of the previous curve up to the top speed in that weather (opts
## top_speed: always the top speed, as if every curve came out of a long straight). The curve "becomes
## visible" when its first such point is within the visibility (render.draw_distance_m * weather/night factor,
## tunnels) and not hidden behind a crest (line of sight from the camera, render.camera_height_m above the road
## at the car, render.camera_distance_m behind it, over the visual road heights) – or when a curve warning sign
## of the stretch (Track, road.curve_warning_*; its board 2.8 m above the road sticks out over crests) is seen
## earlier. From there the driver needs a reaction time plus full braking (of the weather, VehicleModel.brake_decel_mps2) to be at
## most `tolerance` (5 %: manageable with counter-steer, docs/gameplay.md (i2)) above the safe speed at every
## point of the stretch. margin = distance left over (m), negative = not enough.
## Owner: gameplay module (tests only, no autoloads).

const SIGN_H := 2.8


## opts: {vehicle (gran_turismo), weather (normal), night (false), reaction (1.0 s), top_speed (false),
## signs (true), tolerance (0.05)}. Returns {summary: {stage, from, vehicle, weather, night, top_kmh, stretches, min_margin_m
## (null without stretches)}, cases: [{km, seen_m, sign, vis_m, approach_kmh, min_safe_kmh, margin_m}, ...]
## (worst first)}.
static func check(cfg: Dictionary, plan: StagePlan, opts: Dictionary = {}) -> Dictionary:
	var weather := str(opts.get("weather", "normal"))
	var night := bool(opts.get("night", false))
	var reaction := float(opts.get("reaction", 1.0))
	var tol := 1.0 + float(opts.get("tolerance", 0.05))
	var hour := 2.0 if night else 12.0
	var track := Track.new()
	track.setup(plan, cfg, {})
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var v := VehicleModel.new()
	v.setup(cfg, str(opts.get("vehicle", "gran_turismo")))
	var grip := env.grip(weather)
	var vtop := v.max_speed(0.0, env.vmax_factor(hour, weather))
	# full braking of this weather (v0.5.0: limited by the grip – snow about half, VehicleModel.brake_decel_mps2)
	var brake := v.brake_decel_mps2(grip)
	var draw := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	var cam_h := float(ConfigLoader.lookup(cfg, "render.camera_height_m", 3.4))
	var cam_d := float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 9.0))
	var n := track.segment_count
	var seg := track.seg_len
	# the whole road: curve and height per segment (sequential generation keeps every segment)
	var curve := PackedFloat32Array()
	var height := PackedFloat32Array()
	var gk := PackedFloat32Array()   # grip per segment: weather grip, dry (1.0) inside tunnels (Track.grip_at)
	curve.resize(n)
	height.resize(n)
	gk.resize(n)
	for i in n:
		var s := track.get_segment(i)
		curve[i] = s.curve
		height[i] = s.y
		gk[i] = 1.0 if s.tunnel else grip
	var warn_z: Array[float] = []
	if bool(opts.get("signs", true)):
		for i in n:
			for sp: Dictionary in track.get_segment(i).sprites:
				if str(sp.get("sign", "")) == "curve":
					warn_z.append(float(sp["z"]))
	warn_z.sort()
	var always_top := bool(opts.get("top_speed", false))
	var v_fwd := PackedFloat32Array()
	v_fwd.resize(n)
	var vf := 0.0                     # standstill at the start line
	for k in n:
		vf = minf(v.safe_curve_speed(curve[k], gk[k]), v.accelerate(vf, vtop, seg / maxf(vf / 3.6, 1.0)))
		v_fwd[k] = vtop if always_top else vf
	var cases: Array = []
	var min_margin := INF
	var stretches := 0
	var i := 1
	while i < n:
		var z := float(i) * seg
		if z > track.length_z:
			break
		var v_app := vtop / 3.6
		if not always_top:
			v_app = minf(vtop, v.accelerate(v_fwd[i - 1], vtop, seg / maxf(v_fwd[i - 1] / 3.6, 1.0))) / 3.6
		if v.safe_curve_speed(curve[i], gk[i]) / 3.6 >= v_app - 0.3:
			i += 1
			continue
		# stretch [i, j) where the safe speed is below the approach speed
		var j := i
		var min_safe := INF
		while j < n and v.safe_curve_speed(curve[j], gk[j]) / 3.6 < v_app:
			min_safe = minf(min_safe, v.safe_curve_speed(curve[j], gk[j]))
			j += 1
		if min_safe / 3.6 * tol >= v_app:
			i = j
			continue   # within the tolerance everywhere: counter-steering holds the line
		stretches += 1
		var vis := draw * env.visibility_factor(hour, weather, track.is_tunnel_at(z))
		var z_see := z - _seen_from(height, seg, z, vis, cam_h, cam_d, 0.0)
		var by_sign := false
		for zs in warn_z:
			if zs > z:
				break
			if zs < z - 450.0:
				continue
			var zs_see := zs - _seen_from(height, seg, zs, vis, cam_h, cam_d, SIGN_H)
			if zs_see < z_see:
				z_see = zs_see
				by_sign = true
		var margin := INF
		for k in range(i, j):
			var vk := v.safe_curve_speed(curve[k], gk[k]) / 3.6 * tol
			if vk < v_app:
				var need := v_app * reaction + (v_app * v_app - vk * vk) / (2.0 * brake)
				margin = minf(margin, float(k) * seg - z_see - need)
		min_margin = minf(min_margin, margin)
		cases.append({"stage": plan.stage_id, "from": plan.from_id, "km": snappedf(track.z_to_km(z), 0.01),
			"seen_m": snappedf(z - z_see, 1.0), "sign": by_sign, "vis_m": snappedf(vis, 1.0),
			"approach_kmh": snappedf(v_app * 3.6, 0.1), "min_safe_kmh": snappedf(min_safe, 0.1), "margin_m": snappedf(margin, 0.1)})
		i = j
	cases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["margin_m"]) < float(b["margin_m"]))
	return {"summary": {"stage": plan.stage_id, "from": plan.from_id, "vehicle": v.type_id, "weather": weather, "night": night,
		"top_kmh": snappedf(vtop, 0.1), "stretches": stretches, "min_margin_m": snappedf(min_margin, 0.1) if stretches > 0 else null},
		"cases": cases}


## Traffic case (v0.5.0 review „Schnee in der Nacht“): can the player stop for the slowest traffic of the weather
## from the moment it becomes visible? At every point z of the road (every opts.step_m) a vehicle of the slowest
## class there (TrafficSystem.slowest_speed_kmh – cars, trucks and buses at the careful end of their range, speed
## limit, City Limits, weather – times opts.queue_factor: a queue runs a little below it) stands in the player's lane,
## every other lane blocked; cars and heavy vehicles are checked separately (the margin is the smaller one). It is
## seen when its rear is within the fog distance at which the renderer draws a car body at half opacity
## (RoadRenderer._item_alpha: fog_start + √0.5 · (vis − fog_start) from the camera; vis of the camera position,
## tunnels included) and a point half its height above the road there (opts.target_h 0.75 m for cars,
## opts.target_h_heavy 1.9 m for trucks and buses) is not hidden behind a crest (line of sight from the camera). The player arrives with the top speed of the weather
## (opts.top_speed) or the speed profile (full throttle out of the previous curve up to the top speed, curves at most
## opts.curve_tolerance over their limit), reacts after opts.reaction s and brakes with the full braking of the
## weather (dry only when car and player are both in a tunnel): margin = gap at first sight − (v_rel · reaction +
## v_rel² / (2 · a) + opts.margin_m), v_rel = approach speed − speed of the slow vehicle.
## crests = false: only the fog counts (the weather part). With crests a car can stay hidden until 55–100 m before
## it on some hilly stretches – too late from full speed in every weather, also dry by day and in v0.4.0
## (docs/gameplay.md (i6)); those cases are reported with by = "crest".
## opts: {vehicle (gran_turismo), weather (normal), night (false) or hour, reaction (1.0), top_speed (false),
## curve_tolerance (0.05), target_h (0.75), target_h_heavy (1.9), queue_factor (0.9), margin_m (2.0), step_m (15.0),
## crests (true)}.
## Returns {summary: {stage, from, vehicle, weather, hour, top_kmh, vis_m, points, short (points with a negative
## margin), short_crest (… limited by a crest), min_margin_m}, cases: [{km,
## seen_m, by (fog|crest), slow_kmh, approach_kmh, need_m, margin_m}, ...] (worst first, at most 1 per 200 m)}.
static func check_traffic(cfg: Dictionary, plan: StagePlan, opts: Dictionary = {}) -> Dictionary:
	var weather := str(opts.get("weather", "normal"))
	var hour := float(opts.get("hour", 2.0 if bool(opts.get("night", false)) else 12.0))
	var reaction := float(opts.get("reaction", 1.0))
	var tol := 1.0 + float(opts.get("curve_tolerance", 0.05))
	var target_h := float(opts.get("target_h", 0.75))
	var target_h_heavy := float(opts.get("target_h_heavy", 1.9))
	var queue := float(opts.get("queue_factor", 0.9))
	var margin_m := float(opts.get("margin_m", 2.0))
	var step := maxf(3.0, float(opts.get("step_m", 15.0)))
	var crests := bool(opts.get("crests", true))
	var track := Track.new()
	track.setup(plan, cfg, {})
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var v := VehicleModel.new()
	v.setup(cfg, str(opts.get("vehicle", "gran_turismo")))
	var traffic := TrafficSystem.new()
	var none: Array[String] = []
	traffic.setup(cfg, null, none, none, 1)
	traffic.set_weather(weather)
	var grip := env.grip(weather)
	var vtop := v.max_speed(0.0, env.vmax_factor(hour, weather))
	var draw := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	var cam_h := float(ConfigLoader.lookup(cfg, "render.camera_height_m", 3.4))
	var cam_d := float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 9.0))
	var fog_frac := float(ConfigLoader.lookup(cfg, "render.fog_start_frac", 0.45))
	var seen_frac := fog_frac + sqrt(0.5) * (1.0 - fog_frac)
	var half_len := v.length_m * 0.5
	var n := track.segment_count
	var seg := track.seg_len
	var height := PackedFloat32Array()
	var tunnel := PackedByteArray()
	var vapp := PackedFloat32Array()   # approach speed (m/s) of a player at the start of segment k
	var slow := PackedFloat32Array()   # speed (m/s) of the slowest car at the start of segment k
	var slow_h := PackedFloat32Array() # … of the slowest truck or bus
	height.resize(n)
	tunnel.resize(n)
	vapp.resize(n)
	slow.resize(n)
	slow_h.resize(n)
	var always_top := bool(opts.get("top_speed", false))
	var vf := 0.0
	var slow_cache := {}
	for k in n:
		var s := track.get_segment(k)
		height[k] = s.y
		tunnel[k] = 1 if s.tunnel else 0
		var gk := 1.0 if s.tunnel else grip
		vf = minf(v.safe_curve_speed(s.curve, gk) * tol, v.accelerate(vf, vtop, seg / maxf(vf / 3.6, 1.0)))
		vapp[k] = (vtop if always_top else minf(vf, vtop)) / 3.6
		var zk := float(k) * seg
		var road := "city" if track.is_city_at(zk) else track.road_type_at(zk)
		var limit := track.speed_limit_at(zk)
		var key := "%s:%d" % [road, limit]
		if not slow_cache.has(key):
			slow_cache[key] = Vector2(traffic.slowest_speed_kmh(road, limit, 0), traffic.slowest_speed_kmh(road, limit, 1)) * queue / 3.6
		slow[k] = (slow_cache[key] as Vector2).x
		slow_h[k] = (slow_cache[key] as Vector2).y
	var a_wet := v.brake_decel_mps2(grip)
	var a_dry := v.brake_decel_mps2(1.0)
	var vis_open := draw * env.visibility_factor(hour, weather, false)
	var vis_tun := draw * env.visibility_factor(hour, weather, true)
	var cases: Array = []
	var min_margin := INF
	var points := 0
	var short := 0          # points with a negative margin
	var short_crest := 0    # … of them limited by a crest
	var d_lim := seen_frac * maxf(vis_open, vis_tun)
	var z := maxf(200.0, d_lim + 2.0 * seg)   # from where the whole fog distance lies behind the start line
	var z_end := float(track.length_z) - 30.0
	while z < z_end:
		var kt := mini(int(floor(z / seg)), n - 1)
		var worst_case := {}
		var any_seen := false
		for heavy in [false, true]:
			var y_t := _h(height, seg, z) + (target_h_heavy if heavy else target_h)
			# camera positions zc = z - d, d = seg, 2 seg, … : the target is seen from the farthest d within the fog
			# distance of that camera with a free line of sight (running maximum of the terrain slope seen from it)
			var max_slope := -INF
			var best_d := -1.0
			var d := seg
			while d <= d_lim:
				var zc := z - d
				var kc := clampi(int(floor((zc + 5.0) / seg)), 0, n - 1)
				var vis := vis_tun if tunnel[kc] == 1 else vis_open
				var y_c := _h(height, seg, zc + cam_d) + cam_h
				if d <= seen_frac * vis and (not crests or (y_c - y_t) / d >= max_slope):
					best_d = d
				# terrain at zc hides the target from cameras farther back (5 cm tolerance like line_of_sight)
				max_slope = maxf(max_slope, (_h(height, seg, zc) - 0.05 - y_t) / d)
				d += seg
			if best_d < 0.0:
				continue
			any_seen = true
			var zp := z - best_d + cam_d   # player's centre at first sight
			var kp := clampi(int(floor(zp / seg)), 0, n - 1)
			var gap := z - zp - half_len
			var v_slow := slow_h[kt] if heavy else slow[kt]
			var rel := maxf(0.0, vapp[kp] - v_slow)
			var a := a_dry if tunnel[kp] == 1 and tunnel[kt] == 1 else a_wet
			var need := rel * reaction + rel * rel / (2.0 * a) + margin_m
			var margin := gap - need
			var kc2 := clampi(int(floor((z - best_d + 5.0) / seg)), 0, n - 1)
			var by := "crest" if best_d + seg <= seen_frac * (vis_tun if tunnel[kc2] == 1 else vis_open) else "fog"
			if worst_case.is_empty() or margin < float(worst_case["margin_m"]):
				worst_case = {"stage": plan.stage_id, "from": plan.from_id, "km": snappedf(track.z_to_km(z), 0.01),
					"seen_m": snappedf(gap, 1.0), "by": by, "heavy": heavy, "slow_kmh": snappedf(v_slow * 3.6, 0.1),
					"approach_kmh": snappedf(vapp[kp] * 3.6, 0.1), "need_m": snappedf(need, 1.0), "margin_m": snappedf(margin, 0.1)}
		if not any_seen:
			z += step
			continue
		points += 1
		var margin_w := float(worst_case["margin_m"])
		min_margin = minf(min_margin, margin_w)
		if margin_w < 0.0:
			short += 1
			if str(worst_case["by"]) == "crest":
				short_crest += 1
		if margin_w < 60.0:
			cases.append(worst_case)
		z += step
	cases.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["margin_m"]) < float(q["margin_m"]))
	# one case per 200 m of road (neighbouring points describe the same spot)
	var worst: Array = []
	for c: Dictionary in cases:
		var dup := false
		for w: Dictionary in worst:
			if absf(float(w["km"]) - float(c["km"])) < 200.0 * float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0)) / 1000.0:
				dup = true
				break
		if not dup:
			worst.append(c)
	return {"summary": {"stage": plan.stage_id, "from": plan.from_id, "vehicle": v.type_id, "weather": weather, "hour": hour,
		"top_kmh": snappedf(vtop, 0.1), "vis_m": snappedf(vis_open, 1.0), "points": points,
		"short": short, "short_crest": short_crest,
		"min_margin_m": snappedf(min_margin, 0.1) if points > 0 else null}, "cases": worst}


## Farthest distance (m, up to vis) before z_p from which the point target_h above the road at z_p is seen.
static func _seen_from(height: PackedFloat32Array, seg: float, z_p: float, vis: float, cam_h: float, cam_d: float, target_h: float) -> float:
	var d := minf(vis, z_p)
	while d > 0.0:
		if line_of_sight(height, seg, z_p - d, z_p, cam_h, cam_d, target_h):
			return d
		d -= seg
	return 0.0


## True when the point target_h metres above the road at z_p is visible from the camera of a car at z_car
## (no crest in between).
static func line_of_sight(height: PackedFloat32Array, seg: float, z_car: float, z_p: float, cam_h: float, cam_d: float, target_h: float = 0.0) -> bool:
	var zc := z_car - cam_d
	var yc := _h(height, seg, z_car) + cam_h
	var yp := _h(height, seg, z_p) + target_h
	var z := zc + seg
	while z < z_p - 0.5:
		var t := (z - zc) / (z_p - zc)
		if _h(height, seg, z) > yc + (yp - yc) * t + 0.05:
			return false
		z += seg
	return true


static func _h(height: PackedFloat32Array, seg: float, z: float) -> float:
	var i := clampi(int(floor(z / seg)), 0, height.size() - 1)
	var j := mini(i + 1, height.size() - 1)
	return lerpf(height[i], height[j], clampf((z - float(i) * seg) / seg, 0.0, 1.0))
