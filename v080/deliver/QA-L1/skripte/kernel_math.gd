extends SceneTree
## QA lens 1: independent checks of the race3d kernel maths (headless).

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
const R1 := 120.0

var cfg: Dictionary
var fails := 0

func _ok(name: String, cond: bool, msg: String) -> void:
	print("QA-MATH %-28s %s  %s" % [name, "OK    " if cond else "FEHLER", msg])
	if not cond:
		fails += 1

func _track(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array(), opts: Dictionary = {}) -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg, curves, heights, opts)
	return t

func _initialize() -> void:
	cfg = ConfigLoader.load_merged()
	_arcs()
	_rebase()
	_camera()
	_floor()
	_clearance()
	_terrain_rows()
	print("QA-MATH ERGEBNIS %d fehlgeschlagen" % fails)
	quit(0 if fails == 0 else 1)

# 1 ---------------------------------------------------------------------------------------------------------
func _arcs() -> void:
	for radius: float in [134.0, -134.0, 400.0, -266.7]:
		var n := 300
		var t := _track(SynTrack.arc(n + 4, radius))
		var p := RoadPath3D.new()
		p.setup(t, 0, R1)
		var worst := 0.0
		var worst_world := 0.0
		var r := absf(radius)
		var sg := signf(radius)
		for k in n + 1:
			var th := float(k) * 3.0 / r
			var e := Vector2(sg * r * (1.0 - cos(th)), -r * sin(th))
			var q := p.point(k)
			worst = maxf(worst, Vector2(q.x, q.z).distance_to(e))
			# a point 5 m right of the centre lies on the circle of radius r -/+ 5
			var w := p.world(float(k) * 3.0, 5.0, 0.0)
			var rr := r - sg * 5.0
			var ew := Vector2(sg * r - sg * rr * cos(th), -rr * sin(th))
			worst_world = maxf(worst_world, Vector2(w.x, w.z).distance_to(ew))
		_ok("arc R=%.1f over 900 m" % radius, worst <= 0.01 and worst_world <= 0.011, "largest deviation from the true circle %.2f mm (centre), %.2f mm (5 m right) – limit 10 mm" % [worst * 1000.0, worst_world * 1000.0])
	# full circle closes: 2*pi*134 = 841.9 m -> after one turn back near the start
	var t2 := _track(SynTrack.arc(600, 134.0))
	var p2 := RoadPath3D.new()
	p2.setup(t2, 0, R1)
	var turn := TAU * 134.0 / 3.0
	var a := p2.point(int(floor(turn)))
	var b := p2.point(int(floor(turn)) + 1)
	var back := a.lerp(b, turn - floor(turn))
	_ok("full circle closes", Vector2(back.x, back.z).length() < 0.02, "after one full turn of R = 134 m the path is %.1f mm from its start" % (Vector2(back.x, back.z).length() * 1000.0))

# 2 ---------------------------------------------------------------------------------------------------------
func _rebase() -> void:
	var n := 14000
	var curves := PackedFloat32Array()
	curves.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var c := 0.0
	for i in n:
		if i % 60 == 0:
			c = rng.randf_range(-0.9, 0.9) if rng.randf() < 0.6 else 0.0
		curves[i] = c
	var t := _track(curves)
	var p := RoadPath3D.new()
	p.setup(t, 0, R1)
	# independent reference in doubles (python-like)
	var rx := PackedFloat64Array(); var rz := PackedFloat64Array()
	rx.resize(n); rz.resize(n)
	var x := 0.0; var z := 0.0; var ang := 0.0
	for i in n:
		rx[i] = x; rz[i] = z
		var da := float(curves[i]) / R1 * 3.0
		x += sin(ang + da * 0.5) * 3.0
		z -= cos(ang + da * 0.5) * 3.0
		ang += da
	var worst := 0.0
	var worst_shift := 0.0
	var max_origin := 0.0
	var far := 0.0
	var rebases := 0
	var cam := 0
	var origin := 0
	while cam < n - 1300:
		p.ensure(cam + 1200)
		if p.origin_distance(cam) > 2000.0:
			var before := p.point(cam + 500)
			var shift := p.rebase(cam)
			var after := p.point(cam + 500)
			worst_shift = maxf(worst_shift, (before + shift).distance_to(after))
			origin = cam
			rebases += 1
		max_origin = maxf(max_origin, p.origin_distance(cam))
		for k: int in [cam, cam + 100, cam + 500, cam + 1146]:
			var q := p.point(k)
			var e := Vector2(rx[k] - rx[origin], rz[k] - rz[origin])
			worst = maxf(worst, Vector2(q.x, q.z).distance_to(e))
			far = maxf(far, e.length())
		cam += 37
	_ok("rebase keeps positions", worst <= 0.001 and worst_shift <= 0.001 and rebases >= 5,
		"42 km road, %d rebases at > 2 km: largest error against a double reference %.3f mm (points up to %.0f m from the origin), old + shift vs new %.3f mm – limit 1 mm" % [rebases, worst * 1000.0, far, worst_shift * 1000.0])
	_ok("largest path coordinate", absf(rx[n - 1]) + absf(rz[n - 1]) > 1000.0, "reference end at (%.0f, %.0f) m" % [rx[n - 1], rz[n - 1]])

# 3 ---------------------------------------------------------------------------------------------------------
func _camera() -> void:
	var proj := RoadProjection.new()
	proj.setup(ConfigLoader.lookup(cfg, "render", {}), Vector2(1280, 720))
	var cam := ChaseCamera3D.new()
	cam.setup(proj, ConfigLoader.lookup(cfg, "graphics.modern.camera", {}))
	var heights := PackedFloat32Array()
	heights.resize(400)
	for i in 400:
		heights[i] = 6.0 * sin(float(i) * 0.03)
	var t := _track(SynTrack.straight(400), heights)
	var p := RoadPath3D.new()
	p.setup(t, 0, R1)
	p.ensure(399)
	for size: Vector2 in [Vector2(1280, 720), Vector2(1280, 800), Vector2(1680, 720), Vector2(1280, 960), Vector2(2560, 1080) / 1.5]:
		var worst := 0.0
		var samples := 0
		var off := Vector2((size.x - proj.screen.x) * 0.5, proj.horizon_y / proj.screen.y * size.y - proj.horizon_y)
		for cam_z: float in [30.0, 211.7, 404.3]:
			for cam_x: float in [-5.5, 0.0, 3.75]:
				var cam_y := t.height_at(cam_z + proj.cam_distance) + proj.cam_height
				var view := {"camera_z": cam_z, "camera_x": cam_x, "camera_y": cam_y}
				var xf := cam.transform(view, p)
				var fr := cam.frustum(size)
				for d: float in [1.5, 4.0, 9.0, 20.0, 47.3, 100.0, 150.0, 270.0, 444.4, 600.0]:
					for x: float in [-12.0, -3.75, 0.0, 1.0, 9.4]:
						for h: float in [0.0, 0.75, 2.8]:
							var zt := cam_z + d
							var y_road := t.height_at(zt)
							var pm := ChaseCamera3D.project(xf, fr, size, p.world(zt, x, h))
							var pa := proj.project(x - cam_x, y_road + h - cam_y, d)
							worst = maxf(worst, Vector2(pm.x - pa.x - off.x, pm.y - pa.y - off.y).length())
							samples += 1
							if absf(pm.z - d) > 0.001:
								worst = 99.0
		_ok("camera vs Arcade %dx%d" % [int(size.x), int(size.y)], worst <= 0.5, "straight with hills, depth 1.5 … 600 m, %d samples: largest difference %.4f px (picture offset %.1f / %.1f px) – limit 0.5 px" % [samples, worst, off.x, off.y])
	# the frustum against the engine's own projection matrix at the three sizes
	for size: Vector2 in [Vector2(1280, 720), Vector2(1280, 800), Vector2(1680, 720)]:
		var fr := cam.frustum(size, Vector2(3.0, -2.0))
		var m := Projection.create_frustum_aspect(float(fr["size"]), size.x / size.y, fr["offset"], float(fr["near"]), float(fr["far"]), false)
		var worst := 0.0
		for v: Vector3 in [Vector3(1, -3.4, -10), Vector3(-30, 2, -200), Vector3(4, -3, -600), Vector3(0, 0, -5)]:
			var clip := m * Vector4(v.x, v.y, v.z, 1.0)
			var ndc := Vector2(clip.x, clip.y) / clip.w
			var e := Vector2((ndc.x * 0.5 + 0.5) * size.x, (0.5 - ndc.y * 0.5) * size.y)
			var g := ChaseCamera3D.project(Transform3D.IDENTITY, fr, size, v)
			worst = maxf(worst, Vector2(g.x, g.y).distance_to(e))
		_ok("frustum vs engine %dx%d" % [int(size.x), int(size.y)], worst < 0.01, "project() against Projection.create_frustum_aspect (KEEP_HEIGHT) with shake: %.5f px" % worst)
	# focal length in pixels at each size
	for size: Vector2 in [Vector2(1280, 720), Vector2(1280, 800), Vector2(1680, 720)]:
		var fr := cam.frustum(size)
		var f_px := float(fr["near"]) / float(fr["size"]) * size.y
		_ok("focal %dx%d" % [int(size.x), int(size.y)], absf(f_px - proj.focal) < 1.0e-6 and absf(float((fr["offset"] as Vector2).y) + (0.5 - proj.horizon_y / proj.screen.y) * float(fr["size"])) < 1.0e-9,
			"focal %.3f px (Arcade %.3f), size %.5f, offset y %.5f" % [f_px, proj.focal, float(fr["size"]), float((fr["offset"] as Vector2).y)])

# 4 ---------------------------------------------------------------------------------------------------------
func _floor() -> void:
	var n := 2400
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var heights := PackedFloat32Array()
	heights.resize(n)
	var y := 0.0
	var g := 0.0
	for i in n:
		if i % 40 == 0:
			g = rng.randf_range(-0.07, 0.07)
		heights[i] = y
		y += g * 3.0
	var t := _track(SynTrack.straight(n), heights)
	var p := RoadPath3D.new()
	p.setup(t, 0, R1)
	p.floor_window_m = 900.0
	p.floor_drop_m = 4.5
	var worst := 0.0
	var above := 0
	for k in range(0, n - 1, 7):
		var lo := INF
		for j in range(maxi(0, k - 300), mini(n - 1, k + 300) + 1):
			lo = minf(lo, heights[j])
		var f := p.floor_y(k)
		worst = maxf(worst, absf(f - (lo - 4.5)))
		if f > heights[k] - 4.5 + 1.0e-6:
			above += 1
	var rows := p.floor_rows(100, 2000)
	var worst_rows := 0.0
	for k in range(100, 2001):
		worst_rows = maxf(worst_rows, absf(rows[k - 100] - p.floor_y(k)))
	_ok("floor_y vs brute force", worst < 1.0e-4 and above == 0 and worst_rows < 1.0e-9, "random profile: floor_y differs by %.6f m, floor_rows vs floor_y %.9f m, rows with the floor less than 4.5 m below the road: %d" % [worst, worst_rows, above])
	# after a trim the window behind is shorter: value of a row near the cut
	var before := p.floor_y(700)
	p.trim(650)
	var after := p.floor_y(700)
	_ok("floor_y after trim (info)", true, "row 700: %.3f with the whole road, %.3f after trim(650) – the value depends on what is kept behind (streamer keeps 2,280 m)" % [before, after])

# 5 ---------------------------------------------------------------------------------------------------------
var _arg_l := 0
var _arg_r := 0

func _brute_clear(xs: PackedFloat64Array, zs: PackedFloat64Array, th: PackedFloat64Array, k: int, reach: int, clear_max: float) -> Vector2:
	var left := clear_max
	var right := clear_max
	_arg_l = k
	_arg_r = k
	var ux := cos(th[k]); var uz := sin(th[k])
	for j in range(maxi(0, k - reach), mini(xs.size() - 1, k + reach) + 1):
		var vx := xs[j] - xs[k]; var vz := zs[j] - zs[k]
		var a := vx * ux + vz * uz
		var b2 := vx * vx + vz * vz
		if a > 1.0e-9:
			if b2 / (2.0 * a) < right:
				right = b2 / (2.0 * a)
				_arg_r = j
		elif a < -1.0e-9:
			if b2 / (-2.0 * a) < left:
				left = b2 / (-2.0 * a)
				_arg_l = j
	return Vector2(left, right)

func _clearance() -> void:
	# straight 600 m, right U-turn R = 150 (pi * 150 = 471 m = 157 segments), straight 900 m, left bend R = 300 by 90°, straight
	var curves := SynTrack.join([SynTrack.straight(200), SynTrack.arc(157, 150.0), SynTrack.straight(300), SynTrack.arc(157, -300.0), SynTrack.straight(300)])
	var t := _track(curves)
	var p := RoadPath3D.new()
	p.setup(t, 0, R1)
	p.set_clear_reach(1842.0)
	var n := curves.size()
	p.ensure(n - 1)
	var a := p.arrays(0, n - 1)
	var xs: PackedFloat64Array = a["x"]
	var zs: PackedFloat64Array = a["z"]
	var th: PackedFloat64Array = a["heading"]
	var worst := 0.0
	var worst_k := 0
	var k := 0
	while k < n - 1:
		var want := _brute_clear(xs, zs, th, k, int(1842.0 / 3.0), p.clear_max_m)
		for side: int in [-1, 1]:
			var got := p.clearance(k, side)
			var w := want.x if side < 0 else want.y
			# the kernel scans every 8th boundary and interpolates between every 8th row: allow 2 % + 1.5 m
			var d := absf(got - w)
			var arg := _arg_l if side < 0 else _arg_r
			if absi(arg - k) > int(1842.0 / 3.0) - 20:
				continue      # the nearest part lies at the reach limit: the cut-off, not the geometry, decides
			if d > worst and w < p.clear_max_m - 1.0:
				worst = d
				worst_k = k
		k += 5
	var mid_turn := 200 + 78
	_ok("clearance vs brute force", worst < 3.0, "U-turn + bends: largest difference to the exact medial axis over every boundary %.2f m (row %d); inside of the U-turn R = 150: %.1f m, outside %.1f m; straight before it: right %.1f m" % [
		worst, worst_k, p.clearance(mid_turn, 1), p.clearance(mid_turn, -1), p.clearance(100, 1)])
	# the two straights of the U-turn are 300 m apart: half of it on the facing sides
	_ok("clearance parallel roads", absf(p.clearance(150, 1) - 150.0) < 3.0 and absf(p.clearance(200 + 157 + 50, 1) - 150.0) < 3.0, "first leg right %.1f m, second leg right %.1f m (300 m apart -> 150 m)" % [p.clearance(150, 1), p.clearance(200 + 157 + 50, 1)])
	# purity: the same row asked on a path that was extended step by step
	var p2 := RoadPath3D.new()
	p2.setup(t, 0, R1)
	p2.set_clear_reach(1842.0)
	var diff := 0.0
	for kk in range(0, n - 1, 3):
		diff = maxf(diff, absf(p2.clearance(kk, 1) - p.clearance(kk, 1)))
		diff = maxf(diff, absf(p2.clearance(kk, -1) - p.clearance(kk, -1)))
	_ok("clearance is a pure function", diff < 1.0e-9, "asked in another order on a second path: largest difference %.9f m" % diff)

# 6 ---------------------------------------------------------------------------------------------------------
func _terrain_rows() -> void:
	var net := Fair.load_network()
	var dirs := Fair.directions(net, ["saragossa_pau__pau"])
	var geo := Fair.build_geo(cfg, net, dirs[0], net["scenery"])
	var terr := Fair.build_terrain(cfg, geo, net["scenery"])
	var tp: TerrainProfile = terr["terrain"]
	var rows: Dictionary = terr["rows"]
	var n := int(rows["rings"])
	var x: PackedFloat32Array = rows["x"]
	var h: PackedFloat32Array = rows["h"]
	var worst := 0.0
	var above_in_corridor := 0
	var floor_above := 0
	var count := 0
	var path: RoadPath3D = geo["path"]
	for k in range(0, int(geo["n"]) - 1, 11):
		for side: int in [-1, 1]:
			var ro := tp.ring_offsets(k, side)
			var rh := tp.ring_heights(k, side)
			var o := (k * 2 + (0 if side < 0 else 1)) * n
			for i in n:
				worst = maxf(worst, absf(ro[i] - x[o + i]) + absf(rh[i] - h[o + i]))
			var cw := tp.corridor_width(k, side)
			# sample the corridor densely through height()
			var m := 0.0
			while m <= cw:
				if tp.height(k, side, m) > 1.0e-4:
					above_in_corridor += 1
				m += 0.5
			# the last ring lies on the valley floor: never above the road
			if rh[n - 1] > 1.0e-6 or absf((path.height(k) + rh[n - 1]) - path.floor_y(k)) > 0.02 and not (geo["track"] as Track).get_segment(k).water:
				floor_above += 1
			count += 1
	_ok("terrain rows() vs single rows", worst < 1.0e-5, "saragossa_pau__pau, %d row sides: rows() and ring_offsets()/ring_heights() differ by %.7f" % [count, worst])
	_ok("terrain F7 by dense sampling", above_in_corridor == 0, "height() sampled every 0.5 m inside corridor_width(): %d samples above the road" % above_in_corridor)
	_ok("last ring on the valley floor", floor_above == 0, "%d row sides whose last ring is not on floor_y()" % floor_above)
