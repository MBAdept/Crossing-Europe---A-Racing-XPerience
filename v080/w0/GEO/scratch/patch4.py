root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/race3d/fairness.gd'
s = open(p).read()

# --- scan_frustum: camera lateral positions and free target laterals --------------------------------------------
i0 = s.index("# --- F1 / F2 -----")
i1 = s.index("# --- F3 -----")
new_block = '''# --- F1 / F2 ------------------------------------------------------------------------------------------------------

## Frustum check. For every camera position (every cam_step-th boundary) and every target distance d (path
## distance, d_from..d_to in d_step, with near_from > 0 also the near field near_from..d_from in near_step) a target
## on the road at the lateral positions `lats` (default: the centre and ± one lane) seen from a camera at the lateral
## positions `cam_lats` (default: the centreline): a "case" is a target Arcade has on screen that lies outside the
## Modern frustum. Returns {samples, cams, cases: {d: count}, f1_cases (d <= f1_limit_m), f1_nearest_m,
## max_need: {d: [dry, rain, snow]}, worst: {weather: {ratio, d, km, need_m, v_kmh, curve}}, max_yaw_deg,
## check_samples, check_mismatch, check_vertical} – "check_*": the same samples through ChaseCamera3D.transform() /
## project() and RoadProjection.project().
## profiles: speed_profile() per weather, envs: envelopes().
static func scan_frustum(geo: Dictionary, cam: ChaseCamera3D, proj: RoadProjection, profiles: Dictionary, envs: Dictionary,
		opts: Dictionary = {}) -> Dictionary:
	var seg: float = geo["seg"]
	var n: int = geo["n"]
	var nz: int = geo["nz"]
	var xs: PackedFloat64Array = geo["x"]
	var zs: PackedFloat64Array = geo["z"]
	var th: PackedFloat64Array = geo["th"]
	var rxs: PackedFloat64Array = geo["rx"]
	var rzs: PackedFloat64Array = geo["rz"]
	var us: PackedFloat64Array = geo["u"]
	var path: RoadPath3D = geo["path"]
	var track: Track = geo["track"]
	var focal := cam.focal
	var half := proj.screen.x * 0.5
	var near := cam.near
	var lane := track.lane_w
	var cam_step := maxi(1, int(opts.get("cam_step", 2)))
	var car_off := int(round(proj.cam_distance / seg))
	var f1_limit := float(opts.get("f1_limit_m", 270.0))
	var d_from := int(opts.get("d_from", 150))
	var d_to := int(opts.get("d_to", 750))
	var d_step := int(opts.get("d_step", 10))
	var near_from := int(opts.get("near_from", 0))
	var near_step := int(opts.get("near_step", 15))
	var check_every := int(opts.get("check_every", 4099))
	var lats := PackedFloat64Array(opts.get("lats", [-lane, 0.0, lane]))
	var cam_lats := PackedFloat64Array(opts.get("cam_lats", [0.0]))
	var nl := lats.size()
	var lat_max := 0.0
	for v in lats:
		lat_max = maxf(lat_max, absf(v))
	var dists := PackedInt32Array()
	if near_from > 0:
		var dn := near_from
		while dn < d_from:
			dists.append(dn)
			dn += near_step
	var dd := d_from
	while dd <= d_to:
		dists.append(dd)
		dd += d_step
	var nd := dists.size()
	var ks := PackedInt32Array()
	ks.resize(nd)
	for i in nd:
		ks[i] = int(float(dists[i]) / seg)
	var seen_lim := PackedFloat32Array()
	var needs: Array[PackedFloat64Array] = []
	var speeds: Array[PackedFloat64Array] = []
	for w: String in WEATHERS:
		seen_lim.append(float((envs[w] as Dictionary)["seen_m"]) + seg)
		needs.append((profiles[w] as Dictionary)["need"])
		speeds.append((profiles[w] as Dictionary)["v"])
	var cases := PackedInt32Array()
	cases.resize(nd)
	var max_need := PackedFloat64Array()
	max_need.resize(nd * 3)
	var worst: Array[Dictionary] = [{"ratio": 0.0}, {"ratio": 0.0}, {"ratio": 0.0}]
	var samples := 0
	var cams := 0
	var f1 := 0
	var f1_nearest := INF
	var max_yaw := 0.0
	var check_n := 0
	var check_bad := 0
	var check_vert := 0
	var counter := 0
	var c_end := nz - int(float(d_to + d_step) / seg) - 2
	var kpm: float = geo["km_per_m"]
	var curve: PackedFloat32Array = geo["curve"]
	var c := 4
	while c < c_end:
		cams += 1
		var yaw_l := cam.look_yaw(path, float(c) * seg)
		if absf(yaw_l) > max_yaw:
			max_yaw = absf(yaw_l)
		var yaw := th[c] + yaw_l
		var cy := cos(yaw)
		var sy := sin(yaw)
		var uc := us[c]
		var tc := th[c]
		for cam_x: float in cam_lats:
			var cx := xs[c] + cam_x * rxs[c]
			var cz := zs[c] + cam_x * rzs[c]
			samples += nd * nl
			for di in nd:
				var k := ks[di]
				var j := c + k
				var dk := float(k) * seg
				var fa := focal / dk
				var sxa := (us[j] - uc - dk * tc - cam_x) * fa
				var lat_px := lat_max * fa
				counter += 1
				var check := counter % check_every == 0
				if not check:
					if sxa - lat_px > half or sxa + lat_px < -half:
						continue      # Arcade shows none of them
				var tx := xs[j] - cx
				var tz := zs[j] - cz
				var depth_c := tx * sy - tz * cy
				var vx_c := tx * cy + tz * sy
				if not check:
					if depth_c - lat_max > near and (absf(vx_c) + lat_max) * focal <= half * (depth_c - lat_max):
						continue      # Modern shows all of them
				for li in nl:
					var xt := lats[li]
					var on_a := absf(sxa + xt * fa) <= half
					var wx := tx + xt * rxs[j]
					var wz := tz + xt * rzs[j]
					var depth := wx * sy - wz * cy
					var vx := wx * cy + wz * sy
					var on_3 := depth > near and absf(vx) * focal <= half * depth
					var bad := on_a and not on_3
					if bad or check:
						# the same sample through the shipped camera functions
						var ref := _reference_sample(geo, cam, proj, c, k, xt, cam_x, car_off)
						check_n += 1
						if not bool(ref["borderline"]) and (bool(ref["on_a"]) != on_a or bool(ref["on_3"]) != on_3):
							check_bad += 1
						if bool(ref["vertical"]):
							check_vert += 1
					if not bad:
						continue
					cases[di] += 1
					var d := float(dists[di])
					if d <= f1_limit:
						f1 += 1
						f1_nearest = minf(f1_nearest, d)
					var car := mini(c + car_off, n - 1)
					for wi in 3:
						if d > seen_lim[wi]:
							continue
						var need: float = needs[wi][car]
						if need > max_need[di * 3 + wi]:
							max_need[di * 3 + wi] = need
						if need / d > float(worst[wi]["ratio"]):
							worst[wi] = {"ratio": need / d, "d": d, "name": geo["name"], "km": float(c) * seg * kpm, "need_m": need,
								"v_kmh": speeds[wi][car] * 3.6, "curve": absf(curve[car])}
		c += cam_step
	var cases_d := {}
	var need_d := {}
	for di in nd:
		if cases[di] > 0:
			cases_d[dists[di]] = cases[di]
			need_d[dists[di]] = [max_need[di * 3], max_need[di * 3 + 1], max_need[di * 3 + 2]]
	var worst_d := {}
	for wi in 3:
		worst_d[WEATHERS[wi]] = worst[wi]
	return {"name": geo["name"], "samples": samples, "cams": cams, "cases": cases_d, "f1_cases": f1, "f1_nearest_m": f1_nearest,
		"max_need": need_d, "worst": worst_d, "max_yaw_deg": rad_to_deg(max_yaw), "check_samples": check_n,
		"check_mismatch": check_bad, "check_vertical": check_vert}


## One sample of scan_frustum() through the shipped functions: {on_a, on_3 (horizontally on screen, in front of the
## near plane), borderline (within 0.05 px of a picture edge), vertical (on screen horizontally but not vertically)}.
static func _reference_sample(geo: Dictionary, cam: ChaseCamera3D, proj: RoadProjection, c: int, k: int, xt: float, cam_x: float,
		car_off: int) -> Dictionary:
	var seg: float = geo["seg"]
	var path: RoadPath3D = geo["path"]
	var ys: PackedFloat64Array = geo["y"]
	var n: int = geo["n"]
	var cam_y := ys[mini(c + car_off, n - 1)] + proj.cam_height
	var view := {"camera_z": float(c) * seg, "camera_x": cam_x, "camera_y": cam_y}
	var xf := cam.transform(view, path)
	var fr := cam.frustum(proj.screen)
	var p3 := ChaseCamera3D.project(xf, fr, proj.screen, path.world(float(c + k) * seg, xt, 0.0))
	var pa := proj.project(arcade_x(geo, c, k) + xt - cam_x, ys[c + k] - cam_y, float(k) * seg)
	var w := proj.screen.x
	var h := proj.screen.y
	var on_3 := p3.z > cam.near and p3.x >= 0.0 and p3.x <= w
	var on_a := pa.x >= 0.0 and pa.x <= w
	var edge := minf(minf(absf(p3.x), absf(p3.x - w)), minf(absf(pa.x), absf(pa.x - w)))
	var vertical := (on_3 and (p3.y < 0.0 or p3.y > h)) or (on_a and (pa.y < 0.0 or pa.y > h))
	return {"on_a": on_a, "on_3": on_3, "borderline": edge < 0.05, "vertical": vertical, "modern": p3, "arcade": pa}


'''
s = s[:i0] + new_block + s[i1:]

# --- no threads ---------------------------------------------------------------------------------------------------
j0 = s.index("## Runs fn(job) for every job on `threads` threads (1 = here). Results in job order.")
j1 = s.index("static func percentile(values: PackedFloat32Array, p: float) -> float:")
s = s[:j0] + s[j1:]

# --- curvature bound of a stage direction -------------------------------------------------------------------------
a = '''## Free width of the ribbon (RoadPath3D.clearance on every 8th boundary, both sides) and the chunk load of the'''
b = '''## Largest |curve| the generator can produce on a stage: the limit of the curviest section
## (road.curviness_max_curve; tunnels and City Limits only lower it, fades start below it).
static func max_curve_of_stage(cfg: Dictionary, stage: Dictionary) -> float:
	var maxes: Array = ConfigLoader.lookup(cfg, "road.curviness_max_curve", [0.0, 0.30, 0.45, 0.9])
	var out := 0.0
	for sec: Dictionary in stage.get("sections", []):
		out = maxf(out, float(maxes[clampi(int(sec.get("curviness", 1)), 0, maxes.size() - 1)]))
	return out


## True when a road whose curvature never exceeds 1 / radius cannot come closer to itself than dist_m between
## sep_min_m and sep_max_m of path. Schwarz's arc theorem: an arc with curvature <= 1/R between two points d <= 2R
## apart is either at most as long as the short arc of the circle of radius R through them or at least as long as
## the long one – so no arc length in between is possible. A margin of 10 % / 5 % covers the 3-m polyline.
static func proven_clear(radius: float, dist_m: float, sep_min_m: float, sep_max_m: float) -> bool:
	if dist_m >= 2.0 * radius:
		return false
	var short_arc := 2.0 * radius * asin(dist_m / (2.0 * radius))
	var long_arc := TAU * radius - short_arc
	return short_arc <= 0.9 * sep_min_m and long_arc >= 1.05 * sep_max_m


## Free width of the ribbon (RoadPath3D.clearance on every 8th boundary, both sides) and the chunk load of the'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched fairness')
