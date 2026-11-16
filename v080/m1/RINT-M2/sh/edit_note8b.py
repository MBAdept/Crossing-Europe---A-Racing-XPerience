W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
p = W + "scripts/race3d/builders/station.gd"
t = open(p, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:70], t.count(old))
    t = t.replace(old, new)


# ---- the job class (after the Kit class: put it before "var _renderer")
sub('''var _renderer: Node                ## untyped: packages talk to each other through the facade only
''', '''var _renderer: Node                ## untyped: packages talk to each other through the facade only


## RINT-M2 (contract §11.3 A-18, NACH-R6 N-01/N-02): the columns of one canopy decided as a job. The main thread only
## gathers what the decision reads from the Track and the TerrainProfile (gather(): the signs and boards behind the
## canopy, the curvature of the segments the lines of sight cross, the lanes at every camera place, the paved edges and
## the sight-corridor flags of every candidate place – well below a millisecond); the lines of sight themselves (run())
## need nothing of the running game and go to a worker thread, started when collect() looks one canopy ahead
## (WARM_AHEAD_M). They are computed on a path of their own, integrated from the first segment the job needs with
## heading 0 – congruent to the streamer's path, so the decision is the same wherever the race started (the streamer's
## path begins 150 m before the start: before, canopies near a start decided on fewer cameras, NACH-R6 N-01).
class CanopyJob extends RefCounted:
	var r0 := 0.0
	var r1 := 0.0
	var plan: Array = []                ## column_plan()
	var signs: Array = []
	var boards: Array = []
	var seg_len := 3.0
	var inv_r1 := 1.0 / 120.0
	var k0 := 0                         ## first segment of the job's own path
	var curve := PackedFloat32Array()   ## curvature value of segments k0, k0 + 1, …
	var lanes: Dictionary = {}          ## camera grid index (z / LOS_STEP) -> PackedFloat32Array of lane centres x
	var edges: Dictionary = {}          ## column z (snapped) -> paved edge there
	var left_from: Dictionary = {}      ## column z (snapped) -> first place of a left mast (m left of the centre)
	var corridor: Dictionary = {}       ## place key -> true when it lies in a bend's sight corridor
	var result: Array = []
	var task := -1
	var _px := PackedFloat64Array()
	var _pz := PackedFloat64Array()
	var _th := PackedFloat64Array()

	static func zkey(z: float) -> int:
		return int(round(z * 100.0))

	static func pkey(z: float, x: float) -> String:
		return "%d|%d" % [int(round(z * 100.0)), int(round(x * 100.0))]

	func has_seg(k: int) -> bool:
		return k >= k0 and k <= k0 + curve.size()

	func _integrate() -> void:
		_px.resize(curve.size() + 1)
		_pz.resize(curve.size() + 1)
		_th.resize(curve.size() + 1)
		var x := 0.0
		var z := 0.0
		var a := 0.0
		_px[0] = 0.0
		_pz[0] = 0.0
		_th[0] = 0.0
		for i in curve.size():
			var da := float(curve[i]) * inv_r1 * seg_len
			var mid := a + da * 0.5
			x += sin(mid) * seg_len
			z -= cos(mid) * seg_len
			a += da
			_px[i + 1] = x
			_pz[i + 1] = z
			_th[i + 1] = a

	## Plan position of road coordinates (z, x) on the job's path – RoadPath3D.world() without height.
	func world2(z: float, x: float) -> Vector2:
		var f := z / seg_len - float(k0)
		var n := _px.size()
		var i := clampi(int(floor(f)), 0, maxi(0, n - 2))
		var j := mini(i + 1, n - 1)
		var u := clampf(f - float(i), 0.0, 1.0)
		var rx := lerpf(cos(_th[i]), cos(_th[j]), u)
		var rz := lerpf(sin(_th[i]), sin(_th[j]), u)
		return Vector2(lerpf(_px[i], _px[j], u) + rx * x, lerpf(_pz[i], _pz[j], u) + rz * x)

	## end_column_hides() on the job's data (same lines of sight, cameras and boards).
	func hides(z: float, xs: Array[float], width: float) -> Array:
		var out: Array = []
		out.resize(xs.size())
		out.fill(false)
		if not has_seg(int(floor(z / seg_len)) + 1):
			return out
		var cols: Array[Vector2] = []
		for x: float in xs:
			cols.append(world2(z, x))
		var r := width * 0.5 + LOS_MARGIN
		var rel: Array = []
		var lo := INF
		var hi := -INF
		for bd: Array in boards:
			var zs := float(bd[0])
			if zs <= z + 0.3 or zs > z + LOS_FAR or not has_seg(int(floor(zs / seg_len)) + 1):
				continue
			rel.append(bd)
			lo = minf(lo, zs - LOS_FAR)
			hi = maxf(hi, zs - LOS_NEAR)
		if rel.is_empty():
			return out
		var cams: Array = []
		var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
		while zc >= z - LOS_FAR:
			if zc >= lo and zc <= hi and has_seg(int(floor(zc / seg_len))):
				var lx: Variant = lanes.get(int(round(zc / LOS_STEP)))
				if lx is PackedFloat32Array:
					for x: float in lx:
						cams.append([zc, world2(zc, x)])
			zc -= LOS_STEP
		for bd: Array in rel:
			var zs := float(bd[0])
			var b0 := world2(zs, float(bd[1]) - float(bd[2]))
			var b1 := world2(zs, float(bd[1]) + float(bd[2]))
			for cm: Array in cams:
				var d := zs - float(cm[0])
				if d < LOS_NEAR or d > LOS_FAR:
					continue
				var c: Vector2 = cm[1]
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
					var s0 := _sine(to_col, w0, dc, db)
					var s1 := _sine(to_col, w1, dc, db1)
					var lim := minf(1.0, r / dc)
					if maxf(s0, s1) >= -lim and minf(s0, s1) <= lim:
						out[k] = true
		return out

	## The decision of canopy_columns() (WORKER THREAD or inline).
	func run() -> void:
		_integrate()
		var out: Array = []
		var fallback: Array = []
		for c0: Array in plan:
			var c: Array = c0
			var zc := float(c[0])
			var kind := str(c[1])
			var e := float(edges.get(zkey(zc), 0.0))
			if kind.begins_with("end"):
				fallback = [zc, "end", PILLAR_X]
				var cands: Array = [[zc, "end", PILLAR_X], [zc, "end_out", outer_place(signs, r0 - 1.0, r1 + SIGN_SCAN_M)]] \\
					if kind == "end" else [c]
				var xs: Array[float] = []
				for q: Array in cands:
					xs.append(e + float(q[2]))
				var hid := hides(zc, xs, PILLAR_W)
				var chosen: Array = []
				for k in cands.size():
					if not bool(hid[k]):
						chosen = cands[k]
						break
				if chosen.is_empty():
					continue
				c = chosen
				kind = str(c[1])
			if kind != "front" and kind != "end" and bool(corridor.get(pkey(zc, e + float(c[2])), false)):
				continue
			out.append(c)
		if out.is_empty() and not fallback.is_empty():
			var mast := _mast(float(fallback[0]))
			if mast.is_empty():
				mast = _mast(r0 + COLUMN_IN)
			out.append(mast if not mast.is_empty() else fallback)
		result = out

	## The mast of a canopy left without any column (MAST_TOP): right of the road beyond the boards, else beyond the
	## left shoulder – the first place that covers no board and stands outside the sight corridor; [] when none.
	func _mast(zc: float) -> Array:
		var e := float(edges.get(zkey(zc), 0.0))
		var xs := mast_right(zc, e, signs, r0, r1)
		var hid := hides(zc, xs, MAST_W)
		for k in xs.size():
			if not bool(hid[k]) and not bool(corridor.get(pkey(zc, xs[k]), false)):
				return [zc, "mast", xs[k] - e]
		var xl := mast_left(float(left_from.get(zkey(zc), 9.0)))
		var hl := hides(zc, xl, MAST_W)
		for k in xl.size():
			if not bool(hl[k]) and not bool(corridor.get(pkey(zc, xl[k]), false)):
				return [zc, "mast_l", xl[k]]
		return []


## The candidate places of a mast right of the road at zc (x from the road centre; e = the paved edge there).
static func mast_right(zc: float, e: float, signs: Array, r0: float, r1: float) -> Array[float]:
	var xs: Array[float] = []
	var off := maxf(outer_place(signs, r0 - 1.0, r1 + SIGN_SCAN_M), CANOPY_OUT + MAST_W) + MAST_STEP
	while off <= CANOPY_OUT + MAST_MAX_OUT:
		xs.append(e + off)
		off += MAST_STEP
	return xs


## … and left of it, from `left` (m left of the centre: the left shoulder + MAST_LEFT_GAP) outwards.
static func mast_left(left: float) -> Array[float]:
	var xs: Array[float] = []
	var o := left
	while o <= left + MAST_MAX_OUT:
		xs.append(-o)
		o += MAST_STEP
	return xs


## Main thread: everything the decision of the canopy from r0 to r1 reads from the Track and the TerrainProfile, as a
## CanopyJob (run() it inline or on a worker).
static func canopy_job(ctx: ChunkContext, r0: float, r1: float) -> CanopyJob:
	var tr := ctx.track
	var job := CanopyJob.new()
	job.r0 = r0
	job.r1 = r1
	var sb := signs_behind(tr, r0, r1)
	job.signs = sb["signs"]
	job.boards = sb["boards"]
	job.plan = column_plan(r0, r1, job.signs)
	job.seg_len = tr.seg_len
	if ctx.path != null:
		job.inv_r1 = ctx.path.inv_r1
	var kb := tr.segment_index_at(r1 + LOS_FAR) + 3
	var ka := maxi(0, tr.segment_index_at(r0 - LOS_FAR - 3.0 * LOS_STEP))
	while ka < kb and tr.get_segment(ka).index != ka:
		ka += 1
	job.k0 = ka
	for k in range(ka, kb + 1):
		var s := tr.get_segment(k)
		if s.index != k:
			break
		job.curve.append(s.curve)
	if job.curve.size() < 2:
		job.curve.clear()          # no path: the decision keeps every column (as without ctx.path)
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	while zc <= r1 + LOS_STEP:
		var half := tr.lanes_at(zc) * tr.lane_w * 0.5
		var nl := int(round(tr.lanes_at(zc)))
		var lx := PackedFloat32Array()
		for li in nl:
			lx.append(-half + tr.lane_w * (float(li) + 0.5))
		if tr.fuel_lane_factor(zc) > 0.5:
			lx.append(half + tr.lane_w * 0.5)
		job.lanes[int(round(zc / LOS_STEP))] = lx
		zc += LOS_STEP
	# column places: paved edges, outer and mast candidates and their corridor flags
	var far := outer_place(job.signs, r0 - 1.0, r1 + SIGN_SCAN_M)
	for c: Array in job.plan:
		var z := float(c[0])
		var e := paved_edge_at(tr, z)
		job.edges[CanopyJob.zkey(z)] = e
		var left := tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + MAST_LEFT_GAP
		job.left_from[CanopyJob.zkey(z)] = left
		var places: Array[float] = [e + far, e + float(c[2])]
		places.append_array(mast_right(z, e, job.signs, r0, r1))
		places.append_array(mast_left(left))
		for x: float in places:
			job.corridor[CanopyJob.pkey(z, x)] = ctx.terrain != null and bend_corridor_at(tr, ctx.terrain, z, x)
	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	return job
''')

# ---- columns_in_chunk: use the jobs
sub('''		var key := "%.3f" % r0
		var plan: Array
		if cache is Dictionary and (cache as Dictionary).has(key):
			plan = (cache as Dictionary)[key]
		else:
			plan = canopy_columns(ctx, r0, r1, cache)
			if cache is Dictionary:
				(cache as Dictionary)[key] = plan''', '''		var key := "%.3f" % r0
		var plan: Array
		var got: Variant = (cache as Dictionary).get(key) if cache is Dictionary else null
		if got is CanopyJob:
			# decided on a worker since the chunk 600 m before; wait for it (normally long done)
			var job: CanopyJob = got
			if job.task >= 0:
				WorkerThreadPool.wait_for_task_completion(job.task)
				job.task = -1
			plan = job.result
			(cache as Dictionary)[key] = plan
		elif got is Array:
			plan = got
		else:
			plan = canopy_columns(ctx, r0, r1, cache)
			if cache is Dictionary:
				(cache as Dictionary)[key] = plan''')
sub('''			var key := "%.3f" % r0
			if not (cache as Dictionary).has(key):
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				(cache as Dictionary)[key] = canopy_columns(ctx, r0, r1, cache)
				break''', '''			var key := "%.3f" % r0
			if not (cache as Dictionary).has(key):
				# RINT-M2 (A-18): gathered here (main thread), decided on a worker thread
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				var job := canopy_job(ctx, r0, r1)
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
				(cache as Dictionary)[key] = job
				break''')

# ---- canopy_columns: the job inline
a = t.index("static func canopy_columns(ctx: ChunkContext, r0: float, r1: float, cache: Variant = null) -> Array:")
b = t.index("## Main thread: the signs behind a canopy from r0 to r1")
t = t[:a] + '''static func canopy_columns(ctx: ChunkContext, r0: float, r1: float, _cache: Variant = null) -> Array:
	var job := canopy_job(ctx, r0, r1)
	job.run()
	return job.result


## WORKER THREAD. The mast of a canopy without column (CanopyJob._mast()): at (zp, cx) from the ground to MAST_TOP with a head
''' + t[t.index("## plate, a beam under the canopy edge over to it, and its stays from the mast head to the road edge and the middle of", a):]
open(p, "w", encoding="utf-8").write(t)
print("ok")
