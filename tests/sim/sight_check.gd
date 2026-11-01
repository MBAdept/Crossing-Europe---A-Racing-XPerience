extends RefCounted
## Sight check of the curves (driving model): is braking from the moment a curve becomes visible always enough?
## Used by tests/sim/curve_sight.gd (all stages) and tests/unit/race/test_track.gd.
## For a stage (real StagePlan/Track) every stretch whose safe curve speed is below the approach speed is
## checked. Approach speed: full throttle out of the previous curve up to the top speed in that weather (opts
## top_speed: always the top speed, as if every curve came out of a long straight). The curve "becomes
## visible" when its first such point is within the visibility (render.draw_distance_m * weather/night factor,
## tunnels) and not hidden behind a crest (line of sight from the camera, render.camera_height_m above the road
## at the car, render.camera_distance_m behind it, over the visual road heights) – or when a curve warning sign
## of the stretch (Track, road.curve_warning_*; its board 2.8 m above the road sticks out over crests) is seen
## earlier. From there the driver needs a reaction time plus full braking (driving.brake_decel_kmh_s) to be at
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
	var brake := float(ConfigLoader.lookup(cfg, "driving.brake_decel_kmh_s", 70.0)) / 3.6
	var draw := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	var cam_h := float(ConfigLoader.lookup(cfg, "render.camera_height_m", 3.4))
	var cam_d := float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 9.0))
	var n := track.segment_count
	var seg := track.seg_len
	# the whole road: curve and height per segment (sequential generation keeps every segment)
	var curve := PackedFloat32Array()
	var height := PackedFloat32Array()
	curve.resize(n)
	height.resize(n)
	for i in n:
		var s := track.get_segment(i)
		curve[i] = s.curve
		height[i] = s.y
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
		vf = minf(v.safe_curve_speed(curve[k], grip), v.accelerate(vf, vtop, seg / maxf(vf / 3.6, 1.0)))
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
		if v.safe_curve_speed(curve[i], grip) / 3.6 >= v_app - 0.3:
			i += 1
			continue
		# stretch [i, j) where the safe speed is below the approach speed
		var j := i
		var min_safe := INF
		while j < n and v.safe_curve_speed(curve[j], grip) / 3.6 < v_app:
			min_safe = minf(min_safe, v.safe_curve_speed(curve[j], grip))
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
			var vk := v.safe_curve_speed(curve[k], grip) / 3.6 * tol
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
