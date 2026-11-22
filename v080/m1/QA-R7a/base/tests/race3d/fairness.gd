extends RefCounted
## Fairness and world checks of the mode "Modern" on whole stage directions (docs/renderer-modern.md "Fairness").
## Pure static functions on the shipped kernel classes (RoadPath3D, ChaseCamera3D, TerrainProfile) with the shipped
## parameters; used by tests/sim/modern_sight.gd, tests/sim/modern_path_check.gd and the race3d unit tests.
##
##  * scan_path():     the true path never comes close to itself within what is loaded together; loops only far apart
##  * scan_frustum():  F1 – what Arcade has on screen up to f1_limit_m is inside the Modern frustum;
##                     F2 – beyond it the stopping sight distance at the fastest drivable speed stays below
##                     f2_ratio x the distance of the target Modern does not show yet (dry, rain, snow)
##  * scan_crests():   F3 – no vehicle (0.75 m) or sign (2.8 m) is seen later than in Arcade and then inside the
##                     stopping sight distance; sight lines over the shipped terrain
##  * scan_corridor(): F7 – the terrain never rises above the road inside the sight corridor
## Arcade model: the renderer's own row accumulation (RoadRenderer._project: x += dx, dx += curve * seg² / R1) and
## RoadProjection; the sight over crests as in tests/sim/sight_check.gd (profile over the road distance).
## "Fastest drivable speed": the best lateral grip and the highest top speed of all cars at once, curves 5 % above
## their limit, braking envelope backwards; stopping sight distance = 1 s reaction + full braking to a standstill.
## Owner: race3d kernel (tests only, no autoloads).

const CAR_H := 0.75                 ## half a car: the target point of a vehicle
const SIGN_H := 2.8                 ## a sign board
const WEATHERS: Array[String] = ["normal", "rain", "snow"]
const NO_GROUND := -1.0e6
const LOS_TOLERANCE_M := 0.05
## Largest distance (logical px) between the vertical pixel of the shipped camera and the pixel of the eye the sight
## scans assume (_reference_sample: eye_px).
const EYE_TOLERANCE_PX := 0.5
## The stage directions of the sampled run: the ten with the tightest bends (closest approach of the true path to
## itself) and the two with the largest loss of sight over crests in true 3D.
const HARDEST: Array[String] = ["bukarest_sibiu__sibiu", "saragossa_pau__saragossa", "bukarest_sibiu__bukarest",
	"saragossa_pau__pau", "erfurt_kassel__kassel", "belgrad_sofia__sofia", "san_sebastian_burgos__san_sebastian",
	"erfurt_kassel__erfurt", "belgrad_sofia__belgrad", "san_sebastian_burgos__burgos", "koeln_bruessel__koeln",
	"frankfurt_koeln__koeln"]


# --- data ---------------------------------------------------------------------------------------------------------

## The game data the checks need, loaded without autoloads: {stages, cities, countries, city_db, scenery}.
static func load_network() -> Dictionary:
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var cdb: Variant = ConfigLoader.load_json("res://data/cities.json") if FileAccess.file_exists("res://data/cities.json") else null
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	return {"stages": net.get("stages", []), "cities": cities, "countries": countries,
		"city_db": cdb if cdb is Dictionary else {}, "scenery": (sc as Dictionary).get("scenery", {}) if sc is Dictionary else {}}


## Stage directions {name: "<stage>__<from>", stage, from}. only: names or stage ids ([] = all); dev stages are left
## out unless they are named.
static func directions(net: Dictionary, only: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in net.get("stages", []):
		for from_id: String in [str(s["from"]), str(s["to"])]:
			var name := "%s__%s" % [str(s["id"]), from_id]
			if only.is_empty():
				if bool(s.get("dev", false)):
					continue
			elif not (only.has(name) or only.has(str(s["id"]))):
				continue
			out.append({"name": name, "stage": s, "from": from_id})
	return out


## The whole road of one stage direction as arrays (boundary k = start of segment k), integrated by RoadPath3D:
## {name, n, nz (segments up to the finish), seg, track, path, plan, curve, x, z, y, th (doubles, relative to the
## start), rx, rz (right vector), u (Arcade's lateral accumulation), km_per_m}. The track keeps every segment.
static func build_geo(cfg: Dictionary, net: Dictionary, dir: Dictionary, scenery: Dictionary = {}) -> Dictionary:
	var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net.get("city_db", {}))
	var track := Track.new()
	track.setup(plan, cfg, scenery)
	return geo_of_track(cfg, track, str(dir["name"]))


static func geo_of_track(cfg: Dictionary, track: Track, name: String = "") -> Dictionary:
	var n := track.segment_count
	var seg := track.seg_len
	var curve := PackedFloat32Array()
	curve.resize(n)
	for i in n:
		curve[i] = track.get_segment(i).curve
	var path := RoadPath3D.new()
	path.setup(track, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	path.ensure(n - 1)
	var a := path.arrays(0, n - 1)
	var th: PackedFloat64Array = a["heading"]
	var rx := PackedFloat64Array()
	var rz := PackedFloat64Array()
	var u := PackedFloat64Array()
	rx.resize(n)
	rz.resize(n)
	u.resize(n)
	var acc := 0.0
	for i in n:
		rx[i] = cos(th[i])
		rz[i] = sin(th[i])
		u[i] = acc
		acc += th[i] * seg
	return {"name": name, "n": n, "nz": int(track.length_z / seg), "seg": seg, "track": track, "path": path, "plan": track.plan,
		"curve": curve, "x": a["x"], "z": a["z"], "y": a["y"], "th": th, "rx": rx, "rz": rz, "u": u,
		"km_per_m": track.z_to_km(1.0)}


## Lateral offset (m) of the road centre at boundary c + k as Arcade draws it for a camera at boundary c
## (RoadRenderer._project with the camera on a boundary): the forward sum of the headings relative to the camera's.
static func arcade_x(geo: Dictionary, c: int, k: int) -> float:
	var u: PackedFloat64Array = geo["u"]
	var th: PackedFloat64Array = geo["th"]
	return u[c + k] - u[c] - float(k) * float(geo["seg"]) * th[c]


## The shipped camera of the mode "Modern".
static func make_camera(cfg: Dictionary, proj: RoadProjection, overrides: Dictionary = {}) -> ChaseCamera3D:
	var cam := ChaseCamera3D.new()
	var cc: Dictionary = (ConfigLoader.lookup(cfg, "graphics.modern.camera", {}) as Dictionary).duplicate()
	cc.merge(overrides, true)
	cam.setup(proj, cc)
	return cam


static func make_projection(cfg: Dictionary) -> RoadProjection:
	var p := RoadProjection.new()
	p.setup(ConfigLoader.lookup(cfg, "render", {}), Vector2(1280, 720))
	return p


## The shipped terrain of a stage direction: {terrain, rows (TerrainProfile.rows() of every boundary)}.
static func build_terrain(cfg: Dictionary, geo: Dictionary, scenery: Dictionary = {}, overrides: Dictionary = {}) -> Dictionary:
	var tc: Dictionary = (ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}) as Dictionary).duplicate()
	tc.merge(overrides, true)
	var terrain := TerrainProfile.new()
	var path: RoadPath3D = geo["path"]
	var chunk_m := float(int(ConfigLoader.lookup(cfg, "graphics.modern.chunk_segments", 32))) * float(geo["seg"])
	path.set_clear_reach(float(ConfigLoader.lookup(cfg, "graphics.modern.load_path_m", 1500.0))
		+ float(ConfigLoader.lookup(cfg, "graphics.modern.keep_behind_m", 150.0)) + 2.0 * chunk_m)
	terrain.setup(path, geo["track"], tc, scenery)
	return {"terrain": terrain, "rows": terrain.rows(0, int(geo["n"]) - 1)}


# --- speeds -------------------------------------------------------------------------------------------------------

## Per weather the envelope of all cars: {safe1: curve speed at curve value 1 (m/s), vtop (m/s), brake (m/s²),
## seen_m: distance at which a vehicle is "seen" by day (0.839 x visibility)}.
static func envelopes(cfg: Dictionary) -> Dictionary:
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var draw := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	var fog := float(ConfigLoader.lookup(cfg, "render.fog_start_frac", 0.45))
	var seen := fog + sqrt(0.5) * (1.0 - fog)
	var out := {}
	for w: String in WEATHERS:
		var grip := env.grip(w)
		var safe1 := 0.0
		var vtop := 0.0
		var brake := 0.0
		for id: Variant in ConfigLoader.lookup(cfg, "vehicles.order", ["limousine"]):
			var v := VehicleModel.new()
			v.setup(cfg, str(id))
			safe1 = maxf(safe1, v.safe_curve_speed(1.0, grip) / 3.6)
			vtop = maxf(vtop, v.max_speed(0.0, env.vmax_factor(12.0, w)) / 3.6)
			brake = maxf(brake, v.brake_decel_mps2(grip))
		out[w] = {"safe1": safe1, "vtop": vtop, "brake": brake, "seen_m": seen * draw * env.visibility_factor(12.0, w, false)}
	return out


## Fastest drivable speed (m/s) and stopping sight distance (m) at every segment for one envelope.
static func speed_profile(geo: Dictionary, e: Dictionary, tolerance: float = 1.05, reaction_s: float = 1.0) -> Dictionary:
	var n: int = geo["n"]
	var seg: float = geo["seg"]
	var curve: PackedFloat32Array = geo["curve"]
	var safe1: float = e["safe1"]
	var vtop: float = e["vtop"]
	var a: float = e["brake"]
	var v := PackedFloat64Array()
	var need := PackedFloat64Array()
	v.resize(n)
	need.resize(n)
	for i in n:
		v[i] = minf(vtop, tolerance * safe1 / sqrt(maxf(absf(curve[i]), 1.0e-4)))
	for i in range(n - 2, -1, -1):
		v[i] = minf(v[i], sqrt(v[i + 1] * v[i + 1] + 2.0 * a * seg))
	for i in n:
		need[i] = v[i] * reaction_s + v[i] * v[i] / (2.0 * a)
	return {"v": v, "need": need}


# --- path ---------------------------------------------------------------------------------------------------------

## Closest approaches of the true path to itself. Points every `step` segments (12 m); pairs at least sep_min_m of
## path apart and closer than cell_m by air are found with a grid. Returns
## {max_abs_m (largest |x| or |z| of the path relative to its start),
## min_m, min_km, min_sep_m (closest approach within sep_min_m..sep_max_m of path), near_m: {limit: metres of road
## with such an approach below limit}, loop_sep_m (smallest path separation beyond sep_max_m of an approach below
## loop_m; INF = none), loop_min_m, loop_min_sep_m, loop_min_km (closest approach sep_loop_min_m..sep_loop_max_m apart
## on the 24-m points)}.
static func scan_path(geo: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var seg: float = geo["seg"]
	var n: int = geo["n"]
	var xs: PackedFloat64Array = geo["x"]
	var zs: PackedFloat64Array = geo["z"]
	var step := int(opts.get("step", 4))
	var sep_min := float(opts.get("sep_min_m", 360.0))
	var sep_max := float(opts.get("sep_max_m", 1900.0))
	var cell := float(opts.get("cell_m", 300.0))
	var loop_m := float(opts.get("loop_m", 250.0))
	var loop_lo := float(opts.get("sep_loop_min_m", 1100.0))
	var loop_hi := float(opts.get("sep_loop_max_m", 8000.0))
	var limits: Array = opts.get("limits_m", [100.0, 150.0, 200.0, 250.0, 300.0])
	var m := (n + step - 1) / step
	var d_pt := seg * float(step)
	var k_min := int(sep_min / d_pt)
	var k_max := int(sep_max / d_pt)
	var grid := {}
	var cx := PackedInt32Array()
	var cz := PackedInt32Array()
	cx.resize(m)
	cz.resize(m)
	for i in m:
		var gx := int(floor(xs[i * step] / cell))
		var gz := int(floor(zs[i * step] / cell))
		cx[i] = gx
		cz[i] = gz
		var key := gx * 1048576 + gz
		if grid.has(key):
			var cell_pts: PackedInt32Array = grid[key]
			cell_pts.append(i)
			grid[key] = cell_pts
		else:
			grid[key] = PackedInt32Array([i])
	var max_abs := 0.0
	for i in m:
		max_abs = maxf(max_abs, maxf(absf(xs[i * step]), absf(zs[i * step])))
	var mind := PackedFloat64Array()
	mind.resize(m)
	mind.fill(INF)
	var best := INF
	var best_i := 0
	var best_k := 0
	var loop_sep := INF
	var loop_min := INF
	var loop_min_i := 0
	var loop_min_k := 0
	var cell2 := cell * cell
	var loop2 := loop_m * loop_m
	for i in m:
		var px := xs[i * step]
		var pz := zs[i * step]
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				var key := (cx[i] + ox) * 1048576 + cz[i] + oz
				if not grid.has(key):
					continue
				var cell_pts: PackedInt32Array = grid[key]
				for j: int in cell_pts:
					var k := j - i
					if k < k_min:
						continue
					var dx := xs[j * step] - px
					var dz := zs[j * step] - pz
					var d2 := dx * dx + dz * dz
					if d2 >= cell2:
						continue
					if k <= k_max:
						if d2 < mind[i] * mind[i]:
							mind[i] = sqrt(d2)
							if mind[i] < best:
								best = mind[i]
								best_i = i
								best_k = k
					elif d2 < loop2 and float(k) * d_pt < loop_sep:
						loop_sep = float(k) * d_pt
					# loops on the 24-m points like the design study
					if i % 2 == 0 and j % 2 == 0 and float(k) * d_pt >= loop_lo and float(k) * d_pt <= loop_hi and d2 < loop_min * loop_min:
						loop_min = sqrt(d2)
						loop_min_i = i
						loop_min_k = k
	var near := {}
	for lim: float in limits:
		var cnt := 0
		for i in m:
			if mind[i] < lim:
				cnt += 1
		near[lim] = float(cnt) * d_pt
	var kpm: float = geo["km_per_m"]
	return {"name": geo["name"], "length_m": float(n) * seg, "max_abs_m": max_abs, "min_m": best, "min_km": float(best_i) * d_pt * kpm,
		"min_sep_m": float(best_k) * d_pt, "near_m": near, "loop_sep_m": loop_sep, "loop_min_m": loop_min,
		"loop_min_sep_m": float(loop_min_k) * d_pt, "loop_min_km": float(loop_min_i) * d_pt * kpm}


## Largest |curve| the generator can produce on a stage: the limit of the curviest section
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


## Free width of the ribbon (RoadPath3D.clearance on every 8th boundary, both sides) and the chunk load of the
## streamer rule along the stage: {sides, free: {width: sides with at least that much}, min_clear_m,
## chunks_max (wanted chunks without the cap), cap_hits (camera positions that want more than max_chunks),
## cap_nearest_m (nearest distance by air of a chunk the streamer leaves out because of the cap; INF = none)}.
static func scan_ribbon(cfg: Dictionary, geo: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var path: RoadPath3D = geo["path"]
	var seg: float = geo["seg"]
	var n: int = geo["n"]
	var gm: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern", {})
	var chunk_n := int(gm.get("chunk_segments", 32))
	var chunk_m := float(chunk_n) * seg
	var load_m := float(gm.get("load_path_m", 1500.0))
	var keep_m := float(gm.get("keep_behind_m", 150.0))
	var max_chunks := int(gm.get("max_chunks", 18))
	var vis := float(opts.get("visibility_m", ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0)))
	path.set_clear_reach(load_m + keep_m + 2.0 * chunk_m)
	var widths: Array = opts.get("widths_m", [40.0, 80.0, 120.0, 160.0, 240.0, 320.0, 480.0])
	var free := {}
	for w: float in widths:
		free[w] = 0
	var sides := 0
	var min_clear := INF
	var k := 0
	while k < n:
		for side: int in [-1, 1]:
			var c := path.clearance(k, side)
			sides += 1
			min_clear = minf(min_clear, c)
			for w: float in widths:
				if c >= w:
					free[w] = int(free[w]) + 1
		k += RoadPath3D.CLEAR_ROW_STEP
	# chunks the streamer's load rule wants along the stage (camera every chunk length): without the cap, and what
	# the cap of max_chunks leaves out
	var st := ChunkStreamer.new()
	st.setup(path, null, geo["track"], cfg, {}, true)
	var chunks_max := 0
	var cap_hits := 0
	var cap_nearest := INF
	var positions := 0
	var cam := 0
	while cam < n - 2:
		positions += 1
		var cam_z := float(cam) * seg
		st.max_chunks = 1000
		var wanted := st.wanted_for(cam_z, vis)
		chunks_max = maxi(chunks_max, wanted.size())
		if wanted.size() > max_chunks:
			cap_hits += 1
			st.max_chunks = max_chunks
			var kept := st.wanted_for(cam_z, vis)
			var cp := path.centre_at(cam_z)
			for ci: int in wanted:
				if kept.has(ci):
					continue
				var a := ci * chunk_n
				var b := mini(a + chunk_n, n - 1)
				for row: int in [a, (a + b) / 2, b]:
					var p := path.point(row)
					cap_nearest = minf(cap_nearest, Vector2(p.x - cp.x, p.z - cp.z).length())
		cam += chunk_n
	st.free()
	return {"name": geo["name"], "sides": sides, "free": free, "min_clear_m": min_clear, "chunks_max": chunks_max,
		"cap_hits": cap_hits, "cap_nearest_m": cap_nearest, "positions": positions}


# --- F1 / F2 ------------------------------------------------------------------------------------------------------

## Frustum check. For every camera position (every cam_step-th boundary) and every target distance d (path
## distance, d_from..d_to in d_step, with near_from > 0 also the near field near_from..d_from in near_step) a target
## on the road at the lateral positions `lats` (default: the centre and ± one lane) seen from a camera at the lateral
## positions `cam_lats` (default: the centreline): a "case" is a target Arcade has on screen that lies outside the
## Modern frustum. Returns {samples, cams, cases: {d: count}, f1_cases (d <= f1_limit_m), f1_nearest_m,
## max_need: {d: [dry, rain, snow]}, worst: {weather: {ratio, d, km, need_m, v_kmh, curve}}, max_yaw_deg,
## check_samples, check_mismatch, check_vertical, check_eye, check_eye_max_px} – "check_*": the same samples through
## ChaseCamera3D.transform() / project() and RoadProjection.project() (_reference_sample; check_eye = samples whose
## vertical pixel is more than EYE_TOLERANCE_PX away from where the eye F3 and F7 assume puts it).
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
	var check_eye := 0
	var check_eye_max := 0.0
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
						var eye_px: float = ref["eye_px"]
						if eye_px > EYE_TOLERANCE_PX:
							check_eye += 1
						if eye_px > check_eye_max:
							check_eye_max = eye_px
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
		"check_mismatch": check_bad, "check_vertical": check_vert, "check_eye": check_eye, "check_eye_max_px": check_eye_max}


## One sample of scan_frustum() through the shipped functions: {on_a, on_3 (horizontally on screen, in front of the
## near plane), borderline (within 0.05 px of a picture edge), vertical (on screen horizontally but not vertically),
## eye_px}.
## eye_px ties the eye of the shipped camera class to the one the sight scans compute with: scan_crests() (F3) and
## the session put the eye cam_height above the road at the car (view.camera_y), without pitch or roll. Then,
## whatever the yaw, a point at the view depth d and the height y lies focal * (y - camera_y) / d pixels above the
## horizon row. eye_px = how far the pixel of ChaseCamera3D.transform() / project() is from that (0 for a point
## behind the near plane). A camera class that stood higher or lower, or pitched, would pass F1–F3 unnoticed
## without it: 0.5 px is 1 cm of eye height for a target 15 m ahead, 19 cm at 270 m, or a pitch of 0.04°.
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
	var eye_px := 0.0
	if p3.z > cam.near:
		var target_y := path.world(float(c + k) * seg, xt, 0.0).y
		eye_px = absf(p3.y - (proj.horizon_y - proj.focal * (target_y - cam_y) / p3.z))
	return {"on_a": on_a, "on_3": on_3, "borderline": edge < 0.05, "vertical": vertical, "eye_px": eye_px, "modern": p3, "arcade": pa}


# --- F3 -----------------------------------------------------------------------------------------------------------

## Sight over crests. Targets every target_step_m where the road before them is not flat; for both target heights
## the farthest camera position (every 2nd boundary up to the seen distance, eye cam_height above the road at the
## car) with a free line of sight – in Arcade over the road profile (depth = road distance), in Modern as a straight
## line through the world over the road and the shipped terrain ribbon (terr = build_terrain()). With
## opts.study_ribbon_m > 0 the ground of the design study is used instead (road height up to that distance from the
## centreline, on the inside of a bend up to 0.8 x radius, nothing beyond) – to compare the method with its numbers.
## Returns
## {targets, per tag ("car", "sign"): {later (Modern more than later_m later), later30, earlier, short_a, short_3,
## fail (later and then inside the stopping sight distance), da, d3 (seen-from distances), worst: [...]}}.
static func scan_crests(geo: Dictionary, terr: Dictionary, proj: RoadProjection, profile_dry: Dictionary, seen_m: float,
		opts: Dictionary = {}) -> Dictionary:
	var seg: float = geo["seg"]
	var n: int = geo["n"]
	var nz: int = geo["nz"]
	var ys: PackedFloat64Array = geo["y"]
	var curve: PackedFloat32Array = geo["curve"]
	var need: PackedFloat64Array = profile_dry["need"]
	var cam_h := proj.cam_height
	var car_off := int(round(proj.cam_distance / seg))
	var kmax := int(seen_m / seg)
	var step_t := maxi(1, int(float(opts.get("target_step_m", 300.0)) / seg))
	var later_m := float(opts.get("later_m", 6.5))
	var flat_m := float(opts.get("flat_m", 1.5))
	var curved_min := float(opts.get("curved_min", 0.08))
	var heights := [CAR_H, SIGN_H]
	var tags := ["car", "sign"]
	var res := {"name": geo["name"], "targets": 0}
	for tg: String in tags:
		res[tg] = {"later": 0, "later30": 0, "earlier": 0, "short_a": 0, "short_3": 0, "fail": 0, "limited": 0,
			"da": PackedFloat32Array(), "d3": PackedFloat32Array(), "worst": []}
	var da_list: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var d3_list: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	var ray := RayGround.new()
	ray.setup(geo, terr)
	ray.study_ribbon_m = float(opts.get("study_ribbon_m", 0.0))
	var kt := kmax + 8
	while kt < nz - 4:
		var k0 := kt - kmax - 4
		var lo := INF
		var hi := -INF
		var cmax := 0.0
		for k in range(k0, kt + 1):
			var y := ys[k]
			if y < lo:
				lo = y
			if y > hi:
				hi = y
			var ca := absf(curve[k])
			if ca > cmax:
				cmax = ca
		if hi - lo < flat_m:
			kt += step_t
			continue
		res["targets"] = int(res["targets"]) + 1
		var curved := cmax > curved_min
		# Arcade: running maximum of the slope from the target back to the road rows in between
		var best_a := [0.0, 0.0]
		var slope := [-INF, -INF]
		var kc := kt - 2
		var kc_far := kt - 2
		while kc > k0 + 3:
			var d := float(kt - kc)
			var yc := ys[mini(kc + car_off, n - 1)] + cam_h
			for hi_ in 2:
				var yt: float = ys[kt] + float(heights[hi_])
				# rows kc + 1 .. kt - 1; the two rows this step adds are kc + 2 and kc + 1 (kc + 1 only from the 2nd step on)
				var s: float = slope[hi_]
				for row: int in [kc + 2, kc + 1]:
					if row < kt and row > kc:
						var v := (ys[row] - LOS_TOLERANCE_M - yt) / float(kt - row)
						if v > s:
							s = v
				slope[hi_] = s
				if (yc - yt) / d >= s:
					best_a[hi_] = d * seg
			kc_far = kc
			kc -= 2
		# Modern: rays from the farthest camera position towards the nearest until the car is seen
		var best_3 := [best_a[0], best_a[1]]
		if curved:
			best_3 = [0.0, 0.0]
			var found := [false, false]
			kc = kc_far
			while kc <= kt - 2:
				var yc := ys[mini(kc + car_off, n - 1)] + cam_h
				var m3 := ray.max_slope(kc, kt, yc, ys[kt] + SIGN_H - yc)
				for hi_ in 2:
					if not bool(found[hi_]) and m3 <= ys[kt] + float(heights[hi_]) - yc:
						found[hi_] = true
						best_3[hi_] = float(kt - kc) * seg
				if bool(found[0]):
					break
				kc += 2
		for hi_ in 2:
			var r: Dictionary = res[tags[hi_]]
			var da: float = best_a[hi_]
			var d3: float = best_3[hi_]
			var da_arr := da_list[hi_]
			da_arr.append(da)
			da_list[hi_] = da_arr
			var d3_arr := d3_list[hi_]
			d3_arr.append(d3)
			d3_list[hi_] = d3_arr
			var need3: float = need[clampi(kt - int(d3 / seg) + car_off, 0, n - 1)]
			var needa: float = need[clampi(kt - int(da / seg) + car_off, 0, n - 1)]
			if da < seen_m - 7.0:
				r["limited"] = int(r["limited"]) + 1
			if da < needa:
				r["short_a"] = int(r["short_a"]) + 1
			if d3 < need3:
				r["short_3"] = int(r["short_3"]) + 1
			if d3 - da > later_m:
				r["earlier"] = int(r["earlier"]) + 1
			if d3 - da < -later_m:
				r["later"] = int(r["later"]) + 1
				if d3 - da < -30.0:
					r["later30"] = int(r["later30"]) + 1
				var item := {"name": geo["name"], "z": float(kt) * seg, "km": float(kt) * seg * float(geo["km_per_m"]), "arcade_m": da,
					"modern_m": d3, "need_m": need3, "fail": d3 < need3}
				(r["worst"] as Array).append(item)
				if d3 < need3:
					r["fail"] = int(r["fail"]) + 1
		kt += step_t
	for hi_ in 2:
		res[tags[hi_]]["da"] = da_list[hi_]
		res[tags[hi_]]["d3"] = d3_list[hi_]
	return res


## Ground under a straight sight line between two points of the centreline: the road and the terrain ribbon of the
## nearest cross-section (TerrainProfile.rows()), nothing beyond the ribbon.
class RayGround extends RefCounted:
	var seg := 3.0
	var n := 0
	var xs: PackedFloat64Array
	var zs: PackedFloat64Array
	var ys: PackedFloat64Array
	var rxs: PackedFloat64Array
	var rzs: PackedFloat64Array
	var ring_x: PackedFloat32Array
	var ring_h: PackedFloat32Array
	var edges: PackedVector2Array
	var rings := 0
	var sample_m := 6.0
	var study_ribbon_m := 0.0          ## > 0: the design study's ground instead of the TerrainProfile (see scan_crests)
	var curve: PackedFloat32Array
	var r1 := 120.0

	func setup(geo: Dictionary, terr: Dictionary) -> void:
		seg = geo["seg"]
		n = geo["n"]
		xs = geo["x"]
		zs = geo["z"]
		ys = geo["y"]
		rxs = geo["rx"]
		rzs = geo["rz"]
		var rows: Dictionary = terr["rows"]
		ring_x = rows["x"]
		ring_h = rows["h"]
		edges = rows["edge"]
		rings = int(rows["rings"])
		curve = geo["curve"]
		r1 = 1.0 / (geo["path"] as RoadPath3D).inv_r1

	## Ground height relative to the road of `row` at the signed lateral offset `lat` (NO_GROUND beyond the ribbon).
	func rel(row: int, lat: float) -> float:
		if study_ribbon_m > 0.0:
			return 0.0 if absf(lat) <= minf(study_ribbon_m, 0.8 * r1 / maxf(absf(curve[row]), 1.0e-4)) else NO_GROUND
		var e := edges[row]
		var si := 0 if lat < 0.0 else 1
		var m := (-lat - e.x) if si == 0 else (lat - e.y)
		if m <= 0.0:
			return 0.0
		var o := (row * 2 + si) * rings
		if m > ring_x[o + rings - 1] + 0.01:
			return NO_GROUND
		return TerrainProfile.interp(ring_x, o, ring_h, o, rings, m)

	## Absolute ground height under the plan position (qx, qz); j = boundary to start the search from (returned in
	## last_j). NO_GROUND when the position is beyond the ribbon of the nearest cross-section.
	var last_j := 0

	func ground_at(qx: float, qz: float, j: int, j_lo: int, j_hi: int) -> float:
		j = _nearest_local(qx, qz, j, j_lo, j_hi)
		var g := _ground_from(qx, qz, j)
		if g <= NO_GROUND * 0.5:
			# beyond the ribbon of the local cross-section: another part of the road may own this ground (the sight
			# line cuts across a bend) – look for the nearest boundary of the whole stretch
			var dx := qx - xs[j]
			var dz := qz - zs[j]
			var d2 := dx * dx + dz * dz
			var bj := j
			var q := j_lo
			while q <= j_hi:
				var ex := qx - xs[q]
				var ez := qz - zs[q]
				var e2 := ex * ex + ez * ez
				if e2 < d2:
					d2 = e2
					bj = q
				q += 4
			if bj != j:
				j = _nearest_local(qx, qz, bj, j_lo, j_hi)
				g = _ground_from(qx, qz, j)
		last_j = j
		return g

	## Boundary nearest to (qx, qz), searched downhill from j.
	func _nearest_local(qx: float, qz: float, j: int, j_lo: int, j_hi: int) -> int:
		var dx := qx - xs[j]
		var dz := qz - zs[j]
		var d2 := dx * dx + dz * dz
		var moved := false
		while j < j_hi:
			var ex := qx - xs[j + 1]
			var ez := qz - zs[j + 1]
			var e2 := ex * ex + ez * ez
			if e2 >= d2:
				break
			d2 = e2
			j += 1
			moved = true
		if not moved:
			while j > j_lo:
				var ex := qx - xs[j - 1]
				var ez := qz - zs[j - 1]
				var e2 := ex * ex + ez * ez
				if e2 >= d2:
					break
				d2 = e2
				j -= 1
		return j

	## Ground height at (qx, qz) from the cross-sections around boundary j.
	func _ground_from(qx: float, qz: float, j: int) -> float:
		var vx := qx - xs[j]
		var vz := qz - zs[j]
		var lat := vx * rxs[j] + vz * rzs[j]
		var along := vx * rzs[j] - vz * rxs[j]
		var ja := j
		var jb := j
		var t := 0.0
		if along >= 0.0 and j < n - 1:
			jb = j + 1
			t = minf(along / seg, 1.0)
		elif along < 0.0 and j > 0:
			ja = j - 1
			t = maxf(1.0 + along / seg, 0.0)
		var ga := rel(ja, lat)
		var gb := rel(jb, lat)
		if ga <= NO_GROUND * 0.5 and gb <= NO_GROUND * 0.5:
			return NO_GROUND
		if ga <= NO_GROUND * 0.5:
			ga = gb
		elif gb <= NO_GROUND * 0.5:
			gb = ga
		return lerpf(ys[ja], ys[jb], t) + lerpf(ga, gb, t)

	## Largest slope (rise per unit of the way from the eye to the target) the ground needs between an eye yc above
	## the centreline at boundary kc and a target above boundary kt: the target at height yt is seen when
	## yt - yc >= the returned value. Stops early once it exceeds give_up.
	func max_slope(kc: int, kt: int, yc: float, give_up: float) -> float:
		var d := float(kt - kc) * seg
		var m := maxi(2, int(d / sample_m))
		var cx := xs[kc]
		var cz := zs[kc]
		var ex := xs[kt] - cx
		var ez := zs[kt] - cz
		var j := kc
		var j_lo := maxi(0, kc - 100)
		var j_hi := mini(n - 1, kt + 100)
		var worst := -INF
		for i in range(1, m):
			var tt := float(i) / float(m)
			var g := ground_at(cx + ex * tt, cz + ez * tt, j, j_lo, j_hi)
			j = last_j
			if g <= NO_GROUND * 0.5:
				continue
			var s := (g - LOS_TOLERANCE_M - yc) / tt
			if s > worst:
				worst = s
				if worst > give_up:
					return worst
		return worst


# --- F7 -----------------------------------------------------------------------------------------------------------

## Terrain against the sight corridor on every row and side: the ring polyline must not be above the road before the
## corridor ends. Returns {rows, sides, violations, worst_m, cut (sides whose ribbon is narrower than the outer
## ring), min_limit_m, max_corridor_m, max_height_m (highest ground above the road anywhere), raised (sides with
## ground above the road somewhere)}.
static func scan_corridor(geo: Dictionary, terr: Dictionary) -> Dictionary:
	var rows: Dictionary = terr["rows"]
	var x: PackedFloat32Array = rows["x"]
	var h: PackedFloat32Array = rows["h"]
	var corr: PackedVector2Array = rows["corridor"]
	var limits: PackedVector2Array = rows["limit"]
	var rings := int(rows["rings"])
	var terrain: TerrainProfile = terr["terrain"]
	var outer: float = terrain.rings[rings - 1]
	var count := corr.size()
	var violations := 0
	var worst := 0.0
	var cut := 0
	var min_limit := INF
	var max_corr := 0.0
	var max_h := -INF
	var raised := 0
	for r in count:
		for si in 2:
			var o := (r * 2 + si) * rings
			var cw := corr[r].x if si == 0 else corr[r].y
			var lim := limits[r].x if si == 0 else limits[r].y
			if lim < outer - 0.5:
				cut += 1
			min_limit = minf(min_limit, lim)
			max_corr = maxf(max_corr, cw)
			var any_raised := false
			for i in range(1, rings):
				var hh := h[o + i]
				if hh > max_h:
					max_h = hh
				if hh > 0.0:
					any_raised = true
				# the straight line from ring i - 1 to ring i is above the road somewhere before the corridor ends
				if x[o + i - 1] < cw and hh > 1.0e-4:
					violations += 1
					worst = maxf(worst, hh)
				if x[o + i] <= x[o + i - 1]:
					violations += 1      # rings must be strictly increasing
			if absf(h[o]) > 1.0e-6:
				violations += 1          # the ribbon starts at road level
			if any_raised:
				raised += 1
	return {"name": geo["name"], "rows": count, "sides": count * 2, "violations": violations, "worst_m": worst, "cut": cut,
		"min_limit_m": min_limit, "max_corridor_m": max_corr, "max_height_m": max_h, "raised": raised}


# --- helpers ------------------------------------------------------------------------------------------------------

static func percentile(values: PackedFloat32Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	var f := clampf(p, 0.0, 100.0) / 100.0 * float(v.size() - 1)
	var i := int(floor(f))
	return lerpf(v[i], v[mini(i + 1, v.size() - 1)], f - float(i))
