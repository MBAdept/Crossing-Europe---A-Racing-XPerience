import sys

ROOT = sys.argv[1].rstrip("/") + "/"
P = ROOT + "scripts/race3d/builders/station.gd"
t = open(P, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:80], t.count(old))
    t = t.replace(old, new)


# 1. class doc
sub("""## gathers what the decision reads from the Track and the TerrainProfile (gather(): the signs and boards behind the
## canopy, the curvature of the segments the lines of sight cross, the lanes at every camera place, the paved edges and
## the sight-corridor flags of every candidate place – well below a millisecond); the lines of sight themselves (run())
## need nothing of the running game and go to a worker thread, started when collect() looks one canopy ahead
## (WARM_AHEAD_M).""", """## gathers what the decision reads from the Track (canopy_job(): the signs and boards behind the canopy, the curvature
## of the segments the lines of sight cross, the lanes at every camera place, the paved edges – about 2 ms, measured);
## the lines of sight themselves (run()) need nothing of the running game and go to a worker thread, started when
## collect() looks one canopy ahead (WARM_AHEAD_M). The sight-corridor flags of the places (TerrainProfile) are read
## only when the canopy's columns are taken (finish(), main thread): read 600 m ahead they made the TerrainProfile
## compute its rows there, up to 17 ms in one frame (RINT-M2, measured); when the canopy's chunk is captured those rows
## exist anyway.""")
# 2. fields
sub("""	var corridor: Dictionary = {}       ## place key -> true when it lies in a bend's sight corridor
	var result: Array = []""", """	var checks: Array = []              ## run(): [index into out, z, x] of the columns finish() drops in a sight corridor
	var masts: Array = []               ## run(): [[z, e, right xs free of boards, left xs free of boards]] in order
	var out: Array = []                 ## run(): the columns before the corridor test
	var fallback: Array = []
	var result: Array = []""")
# 3. run(): corridor deferred
sub("""	## The decision of canopy_columns() (WORKER THREAD or inline).
	func run() -> void:
		_integrate()
		var out: Array = []
		var fallback: Array = []
		for c0: Array in plan:""", """	## The lines of sight of canopy_columns() (WORKER THREAD or inline); finish() completes the decision.
	func run() -> void:
		_integrate()
		out = []
		fallback = []
		checks = []
		masts = []
		for c0: Array in plan:""")
sub("""			if kind != "front" and kind != "end" and bool(corridor.get(pkey(zc, e + float(c[2])), false)):
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
""", """			if kind != "front" and kind != "end":
				checks.append([out.size(), zc, e + float(c[2])])
			out.append(c)
		# a canopy may lose every column (finish() drops the outer ones in a sight corridor): the mast places free of
		# boards, for finish() to take the first outside the corridor – only then needed, so only then looked at
		if not fallback.is_empty() and checks.size() == out.size():
			for zm: float in [float(fallback[0]), r0 + COLUMN_IN]:
				masts.append(_mast_places(zm))

	## The places of a mast at zc that cover no board: [zc, e, right xs (beyond the boards), left xs (beyond the left
	## shoulder)], each in the order of preference.
	func _mast_places(zc: float) -> Array:
		var e := float(edges.get(zkey(zc), 0.0))
		var xs := mast_right(zc, e, signs, r0, r1)
		var hid := hides(zc, xs, MAST_W)
		var right: Array[float] = []
		for k in xs.size():
			if not bool(hid[k]):
				right.append(xs[k])
		var xl := mast_left(float(left_from.get(zkey(zc), 9.0)))
		var hl := hides(zc, xl, MAST_W)
		var left: Array[float] = []
		for k in xl.size():
			if not bool(hl[k]):
				left.append(xl[k])
		return [zc, e, right, left]

	## MAIN THREAD, after run(): the columns of the canopy – the outer ones outside a bend's sight corridor; a canopy
	## left without any column hangs from a mast (MAST_TOP: right of the road beyond the boards, else beyond the left
	## shoulder – the first place free of boards and outside the corridor), else keeps its end column on the island.
	## tr / tp: the Track and the TerrainProfile (tp null: no corridor test).
	func finish(tr: Track, tp: TerrainProfile) -> void:
		var drop := {}
		for ck: Array in checks:
			if tp != null and bend_corridor_at(tr, tp, float(ck[1]), float(ck[2])):
				drop[int(ck[0])] = true
		var cols: Array = []
		for i in out.size():
			if not drop.has(i):
				cols.append(out[i])
		if cols.is_empty() and not fallback.is_empty():
			var mast: Array = []
			for m: Array in masts:
				var zc := float(m[0])
				for x: float in m[2]:
					if tp == null or not bend_corridor_at(tr, tp, zc, x):
						mast = [zc, "mast", x - float(m[1])]
						break
				if mast.is_empty():
					for x: float in m[3]:
						if tp == null or not bend_corridor_at(tr, tp, zc, x):
							mast = [zc, "mast_l", x]
							break
				if not mast.is_empty():
					break
			cols.append(mast if not mast.is_empty() else fallback)
		result = cols

	## bend_corridor_at() of the builder (an inner class cannot call the outer script's static functions).
	static func bend_corridor_at(tr: Track, tp: TerrainProfile, z: float, x: float) -> bool:
		var f := z / tr.seg_len
		var k := maxi(int(floor(f)), 0)
		var u := clampf(f - float(k), 0.0, 1.0)
		var side := -1 if x < 0.0 else 1
		var e := lerpf(paved_edge(tr, k, side), paved_edge(tr, k + 1, side), u)
		var m := absf(x) - e - tr.shoulder_w
		var cw := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), u)
		var cmin := maxf(0.0, tp.corridor_min_m - tr.shoulder_w)
		return cw > cmin + 0.5 and m > 0.0 and m <= cw

	## _paved_edge() of the builder.
	static func paved_edge(tr: Track, k: int, side: int) -> float:
		var s := tr.get_segment(k)
		var half := s.lanes * tr.lane_w * 0.5
		return half if side < 0 else half + s.fuel_lane * tr.lane_w
""")
# 4. gather: no corridor flags
sub("""	# column places: paved edges, outer and mast candidates and their corridor flags
	var far := outer_place(job.signs, r0 - 1.0, r1 + SIGN_SCAN_M)
	for c: Array in job.plan:
		var z := float(c[0])
		var e := paved_edge_at(tr, z)
		job.edges[CanopyJob.zkey(z)] = e
		var left := tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + MAST_LEFT_GAP
		job.left_from[CanopyJob.zkey(z)] = left
		var places: Array[float] = [e + far, e + float(c[2])]
		places.append_array(CanopyJob.mast_right(z, e, job.signs, r0, r1))
		places.append_array(CanopyJob.mast_left(left))
		for x: float in places:
			job.corridor[CanopyJob.pkey(z, x)] = ctx.terrain != null and bend_corridor_at(tr, ctx.terrain, z, x)
	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	return job""", """	# column places: paved edges and the first place of a left mast (the corridor flags: finish())
	for c: Array in job.plan:
		var z := float(c[0])
		job.edges[CanopyJob.zkey(z)] = paved_edge_at(tr, z)
		job.left_from[CanopyJob.zkey(z)] = tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + MAST_LEFT_GAP
	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	return job""")
# 5. consumers
sub("""				WorkerThreadPool.wait_for_task_completion(job.task)
				job.task = -1
			plan = job.result""", """				WorkerThreadPool.wait_for_task_completion(job.task)
				job.task = -1
			job.finish(tr, ctx.terrain)
			plan = job.result""")
sub("""	var job := canopy_job(ctx, r0, r1)
	job.run()
	return job.result""", """	var job := canopy_job(ctx, r0, r1)
	job.run()
	job.finish(ctx.track, ctx.terrain)
	return job.result""")
open(P, "w", encoding="utf-8").write(t)
print("ok")
