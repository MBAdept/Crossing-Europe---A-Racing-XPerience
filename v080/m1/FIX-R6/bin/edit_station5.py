import sys
p = sys.argv[1] + '/scripts/race3d/builders/station.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''const LOS_MARGIN := 0.1            ## the column's half width plus this (cameras every LOS_STEP: a line can sweep past)''',
'''const LOS_MARGIN := 0.1            ## the column's half width plus this (cameras every LOS_STEP: a line can sweep past)
## The decision costs 2–4.5 ms per canopy on the main thread (measured, llvmpipe VM under load): collect() decides one
## more canopy that starts up to WARM_AHEAD_M beyond its chunk in advance, so that the canopies of a station are spread
## over the chunks before it instead of all landing in one frame; camera positions are kept per stage (cache).
const WARM_AHEAD_M := 600.0''')

rep('''		var key := "%.3f" % r0
		var plan: Array
		if cache is Dictionary and (cache as Dictionary).has(key):
			plan = (cache as Dictionary)[key]
		else:
			plan = canopy_columns(ctx, r0, r1)
			if cache is Dictionary:
				(cache as Dictionary)[key] = plan
		for c: Array in plan:
			if float(c[0]) >= za and float(c[0]) < zb:
				out.append(c)
	return out''',
'''		var key := "%.3f" % r0
		var plan: Array
		if cache is Dictionary and (cache as Dictionary).has(key):
			plan = (cache as Dictionary)[key]
		else:
			plan = canopy_columns(ctx, r0, r1, cache)
			if cache is Dictionary:
				(cache as Dictionary)[key] = plan
		for c: Array in plan:
			if float(c[0]) >= za and float(c[0]) < zb:
				out.append(c)
	# one canopy ahead decided in advance (WARM_AHEAD_M)
	if cache is Dictionary and ctx.path != null:
		for zn: Dictionary in tr.zones:
			if str(zn.get("kind", "")) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / len_s) * len_s
			if r0 <= zb:
				continue
			if r0 > zb + WARM_AHEAD_M:
				break
			var key := "%.3f" % r0
			if not (cache as Dictionary).has(key):
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				(cache as Dictionary)[key] = canopy_columns(ctx, r0, r1, cache)
				break
	return out''')

rep('''static func canopy_columns(ctx: ChunkContext, r0: float, r1: float) -> Array:''',
    '''static func canopy_columns(ctx: ChunkContext, r0: float, r1: float, cache: Variant = null) -> Array:''')
rep('''				var hides := end_column_hides(tr, ctx.path, zc, xs, boards)''',
    '''				var hides := end_column_hides(tr, ctx.path, zc, xs, boards, cache)''')

rep('''## column's footprint (it spans every board height). Cameras every LOS_STEP metres; positions the path does not hold
## are skipped.
static func end_column_hides(tr: Track, p: RoadPath3D, z: float, xs: Array[float], boards: Array) -> Array:''',
'''## column's footprint (it spans every board height). Cameras every LOS_STEP metres on a fixed grid; positions the path
## does not hold are skipped. cache (a Dictionary, optional): keeps the camera positions of the grid for the next
## canopies (valid while the floating origin of the path stays where it is).
static func end_column_hides(tr: Track, p: RoadPath3D, z: float, xs: Array[float], boards: Array, cache: Variant = null) -> Array:''')

rep('''	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if p.has(tr.segment_index_at(zc)):
			var half := tr.lanes_at(zc) * tr.lane_w * 0.5
			var nl := int(round(tr.lanes_at(zc)))
			var lxs: Array[float] = []
			for li in nl:
				lxs.append(-half + tr.lane_w * (float(li) + 0.5))
			if tr.fuel_lane_factor(zc) > 0.5:
				lxs.append(half + tr.lane_w * 0.5)
			for lx: float in lxs:
				var w := p.world(zc, lx, 0.0)
				cams.append([zc, Vector2(w.x, w.z)])
		zc -= LOS_STEP''',
'''	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var grid: Dictionary = {}
	if cache is Dictionary:
		var cd: Dictionary = cache
		if int(cd.get("cam_origin", -1)) != p.origin_index or not cd.has("cams"):
			cd["cam_origin"] = p.origin_index
			cd["cams"] = {}
		grid = cd["cams"]
	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if p.has(tr.segment_index_at(zc)):
			var at: Variant = grid.get(zc)
			if at == null:
				var half := tr.lanes_at(zc) * tr.lane_w * 0.5
				var nl := int(round(tr.lanes_at(zc)))
				var lxs: Array[float] = []
				for li in nl:
					lxs.append(-half + tr.lane_w * (float(li) + 0.5))
				if tr.fuel_lane_factor(zc) > 0.5:
					lxs.append(half + tr.lane_w * 0.5)
				var pts: Array[Vector2] = []
				for lx: float in lxs:
					var w := p.world(zc, lx, 0.0)
					pts.append(Vector2(w.x, w.z))
				at = pts
				grid[zc] = pts
			for v2: Vector2 in at:
				cams.append([zc, v2])
		zc -= LOS_STEP''')

rep('''			var c: Vector2 = cm[1]
			var db := (b0 - c).length()
			for k in cols.size():
				if bool(out[k]):
					continue
				var to_col := cols[k] - c
				var dc := to_col.length()
				if dc < r or db <= dc:
					continue
				# the column covers the angles within asin(r / dc) of its direction; the board spans its two ends' angles
				var half_a := asin(minf(1.0, r / dc))
				var a0 := to_col.angle_to(b0 - c)
				var a1 := to_col.angle_to(b1 - c)
				if maxf(a0, a1) >= -half_a and minf(a0, a1) <= half_a:
					out[k] = true''',
'''			var c: Vector2 = cm[1]
			var w0 := b0 - c
			var w1 := b1 - c
			var db := w0.length()
			var db1 := w1.length()
			for k in cols.size():
				if bool(out[k]):
					continue
				var to_col := cols[k] - c
				var dc := to_col.length()
				if dc < r or db <= dc:
					continue
				# the column covers the angles within asin(r / dc) of its direction; the board spans its two ends' angles.
				# Compared as sines (monotonic up to 90°; beyond it ±2): the same test as with the angles, without atan2
				var s0 := _sine(to_col, w0, dc, db)
				var s1 := _sine(to_col, w1, dc, db1)
				var lim := minf(1.0, r / dc)
				if maxf(s0, s1) >= -lim and minf(s0, s1) <= lim:
					out[k] = true''')

rep('''## The columns of a canopy from r0 (start of its front segment)''',
'''## Sine of the signed angle from v to w (lengths lv, lw), mapped to ±2 beyond 90° – a monotonic stand-in for the angle.
static func _sine(v: Vector2, w: Vector2, lv: float, lw: float) -> float:
	var s := v.cross(w) / maxf(lv * lw, 1.0e-9)
	if v.dot(w) < 0.0:
		return 2.0 if s >= 0.0 else -2.0
	return s


## The columns of a canopy from r0 (start of its front segment)''')
open(p, 'w').write(s)
print('ok')
