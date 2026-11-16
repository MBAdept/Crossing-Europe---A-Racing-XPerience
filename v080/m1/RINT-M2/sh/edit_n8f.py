import sys

ROOT = sys.argv[1].rstrip("/") + "/"
P = ROOT + "scripts/race3d/builders/station.gd"
t = open(P, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:80], t.count(old))
    t = t.replace(old, new)


sub("""## The decision costs 2–6 ms per canopy (measured, llvmpipe VM under load): collect() gathers one half of the job of
## the next canopy that starts up to WARM_AHEAD_M beyond its chunk (CanopyJob), so that the canopies of a station are
## spread over the chunks before it and decided on a worker instead of all landing in one frame. RINT-M2: 2000 m – a
## station of six canopies needs twelve collect() calls (one chunk = 96 m); with 600 m the last three canopies were
## not ready and were decided inline (6 ms each, measured on the test stage, "Steam Deck").
const WARM_AHEAD_M := 2000.0""", """## The decision costs 2–6 ms per canopy (measured, llvmpipe VM under load): collect() gathers the jobs (CanopyJob) of the
## canopies that start up to WARM_AHEAD_M beyond its chunk, at most WARM_BUDGET_MS of them per call, so that the
## canopies of a station are spread over the chunks before it and decided on a worker instead of all landing in one
## frame. The canopies of a station share their cameras and segments: the lanes and the curvature are kept for the
## next canopy (cache "_lanes", "_curve"), so a station of six canopies is gathered in about four calls. RINT-M2,
## measured on the test stage ("Steam Deck"): further ahead than 600 m the gather makes the Track generate its segments
## early (18 ms in one frame at 2000 m); one half per call left the last three of six canopies to be decided inline.
const WARM_AHEAD_M := 600.0
const WARM_BUDGET_MS := 1.0""")
# begin: curve cache
sub("""## Main thread, first half of canopy_job(): the signs, the column plan and the curvature of the job's segments.
static func canopy_job_begin(ctx: ChunkContext, r0: float, r1: float) -> CanopyJob:""", """## Main thread, first half of canopy_job(): the signs, the column plan and the curvature of the job's segments.
## shared: the builder's cache (Dictionary) – the curvature of the segments is kept there for the next canopy.
static func canopy_job_begin(ctx: ChunkContext, r0: float, r1: float, shared: Variant = null) -> CanopyJob:""")
sub("""	job.k0 = ka
	for k in range(ka, kb + 1):
		var s := tr.get_segment(k)
		if s.index != k:
			break
		job.curve.append(s.curve)
	if job.curve.size() < 2:""", """	job.k0 = ka
	var cc: Dictionary = _shared_part(shared, "_curve", ka)
	for k in range(ka, kb + 1):
		var cv: Variant = cc.get(k)
		if cv == null:
			var s := tr.get_segment(k)
			if s.index != k:
				break
			cv = s.curve
			cc[k] = cv
		job.curve.append(float(cv))
	if job.curve.size() < 2:""")
# rest: lanes cache
sub("""## Main thread, second half of canopy_job(): the cameras (lane centres) and the paved edges at the column places.
static func canopy_job_rest(ctx: ChunkContext, job: CanopyJob) -> void:
	var tr := ctx.track
	var r0 := job.r0
	var r1 := job.r1
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	while zc <= r1 + LOS_STEP:
		var lanes := tr.lanes_at(zc)""", """## Main thread, second half of canopy_job(): the cameras (lane centres) and the paved edges at the column places.
## shared: the builder's cache – the cameras are kept there for the next canopy (its grid overlaps).
static func canopy_job_rest(ctx: ChunkContext, job: CanopyJob, shared: Variant = null) -> void:
	var tr := ctx.track
	var r0 := job.r0
	var r1 := job.r1
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	var lc: Dictionary = _shared_part(shared, "_lanes", int(round(zc / LOS_STEP)))
	while zc <= r1 + LOS_STEP:
		var gi := int(round(zc / LOS_STEP))
		var hit: Variant = lc.get(gi)
		if hit != null:
			job.lanes[gi] = hit
			zc += LOS_STEP
			continue
		var lanes := tr.lanes_at(zc)""")
sub("""		if tr.fuel_lane_factor(zc) > 0.5:
			lx.append(half + tr.lane_w * 0.5)
		job.lanes[int(round(zc / LOS_STEP))] = lx
		zc += LOS_STEP""", """		if tr.fuel_lane_factor(zc) > 0.5:
			lx.append(half + tr.lane_w * 0.5)
		job.lanes[gi] = lx
		lc[gi] = lx
		zc += LOS_STEP""")
sub("""	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	job.gathered = true""", """	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	job.gathered = true


## The part `name` of the builder's cache (shared) for the gather of the next canopy: a Dictionary index -> value,
## emptied when the new canopy starts beyond everything kept (index `from` past the largest key – another station).
## Without a cache a fresh one.
static func _shared_part(shared: Variant, name: String, from: int) -> Dictionary:
	if not (shared is Dictionary):
		return {}
	var d: Dictionary = (shared as Dictionary).get(name, {})
	if not d.is_empty() and from > int(d.keys().max()):
		d.clear()
	(shared as Dictionary)[name] = d
	return d""")
# consumers
sub("""			if not job.gathered:
				canopy_job_rest(ctx, job)""", """			if not job.gathered:
				canopy_job_rest(ctx, job, cache)""")
sub("""	# one canopy ahead decided in advance (WARM_AHEAD_M)
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
			var ahead: Variant = (cache as Dictionary).get(key)
			if ahead == null:
				# RINT-M2 (A-18): gathered here (main thread, one half per collect()), decided on a worker thread
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				(cache as Dictionary)[key] = canopy_job_begin(ctx, r0, r1)
				break
			if ahead is CanopyJob and not (ahead as CanopyJob).gathered:
				var job: CanopyJob = ahead
				canopy_job_rest(ctx, job)
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
				break
	return out""", """	# the canopies ahead decided in advance (WARM_AHEAD_M), gathered here (main thread, WARM_BUDGET_MS per collect())
	# and decided on a worker thread – RINT-M2 (A-18)
	if cache is Dictionary and ctx.path != null:
		var t0 := Time.get_ticks_usec()
		var budget_us := int(WARM_BUDGET_MS * 1000.0)
		for zn: Dictionary in tr.zones:
			if str(zn.get("kind", "")) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / len_s) * len_s
			if r0 <= zb:
				continue
			if r0 > zb + WARM_AHEAD_M:
				break
			var key := "%.3f" % r0
			var ahead: Variant = (cache as Dictionary).get(key)
			if ahead == null:
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				ahead = canopy_job_begin(ctx, r0, r1, cache)
				(cache as Dictionary)[key] = ahead
				if Time.get_ticks_usec() - t0 > budget_us:
					break
			if ahead is CanopyJob and not (ahead as CanopyJob).gathered:
				var job: CanopyJob = ahead
				canopy_job_rest(ctx, job, cache)
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
				if Time.get_ticks_usec() - t0 > budget_us:
					break
	return out""")
open(P, "w", encoding="utf-8").write(t)
print("ok")
