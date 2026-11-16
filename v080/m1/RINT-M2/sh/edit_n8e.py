import sys

ROOT = sys.argv[1].rstrip("/") + "/"
P = ROOT + "scripts/race3d/builders/station.gd"
t = open(P, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:80], t.count(old))
    t = t.replace(old, new)


sub("""## gathers what the decision reads from the Track (canopy_job(): the signs and boards behind the canopy, the curvature
## of the segments the lines of sight cross, the lanes at every camera place, the paved edges – about 2 ms, measured);
## the lines of sight themselves (run()) need nothing of the running game and go to a worker thread, started when
## collect() looks one canopy ahead (WARM_AHEAD_M).""", """## gathers what the decision reads from the Track, in two collect() calls of about 1 ms each (canopy_job_begin(): the
## signs and boards behind the canopy and the curvature of the segments the lines of sight cross; canopy_job_rest():
## the lanes at every camera place and the paved edges – measured); the lines of sight themselves (run()) need nothing
## of the running game and go to a worker thread, started when collect() looks one canopy ahead (WARM_AHEAD_M).""")
sub("""	var result: Array = []
	var task := -1""", """	var result: Array = []
	var gathered := false               ## canopy_job_rest() done
	var done := false                   ## run() done
	var task := -1""")
sub("""		if not fallback.is_empty() and checks.size() == out.size():
			for zm: float in [float(fallback[0]), r0 + COLUMN_IN]:
				masts.append(_mast_places(zm))
""", """		if not fallback.is_empty() and checks.size() == out.size():
			for zm: float in [float(fallback[0]), r0 + COLUMN_IN]:
				masts.append(_mast_places(zm))
		done = true
""")
sub("""## Main thread: everything the decision of the canopy from r0 to r1 reads from the Track and the TerrainProfile, as a
## CanopyJob (run() it inline or on a worker).
static func canopy_job(ctx: ChunkContext, r0: float, r1: float) -> CanopyJob:
	var tr := ctx.track
	var job := CanopyJob.new()""", """## Main thread: everything the decision of the canopy from r0 to r1 reads from the Track, as a CanopyJob (run() it
## inline or on a worker, then finish()).
static func canopy_job(ctx: ChunkContext, r0: float, r1: float) -> CanopyJob:
	var job := canopy_job_begin(ctx, r0, r1)
	canopy_job_rest(ctx, job)
	return job


## Main thread, first half of canopy_job(): the signs, the column plan and the curvature of the job's segments.
static func canopy_job_begin(ctx: ChunkContext, r0: float, r1: float) -> CanopyJob:
	var tr := ctx.track
	var job := CanopyJob.new()""")
sub("""	if job.curve.size() < 2:
		job.curve.clear()          # no path: the decision keeps every column (as without ctx.path)
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	while zc <= r1 + LOS_STEP:
		var half := tr.lanes_at(zc) * tr.lane_w * 0.5
		var nl := int(round(tr.lanes_at(zc)))
		var lx := PackedFloat32Array()""", """	if job.curve.size() < 2:
		job.curve.clear()          # no path: the decision keeps every column (as without ctx.path)
	return job


## Main thread, second half of canopy_job(): the cameras (lane centres) and the paved edges at the column places.
static func canopy_job_rest(ctx: ChunkContext, job: CanopyJob) -> void:
	var tr := ctx.track
	var r0 := job.r0
	var r1 := job.r1
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	while zc <= r1 + LOS_STEP:
		var lanes := tr.lanes_at(zc)
		var half := lanes * tr.lane_w * 0.5
		var nl := int(round(lanes))
		var lx := PackedFloat32Array()""")
sub("""		job.left_from[CanopyJob.zkey(z)] = tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + MAST_LEFT_GAP
	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	return job""", """		job.left_from[CanopyJob.zkey(z)] = tr.lanes_at(z) * tr.lane_w * 0.5 + tr.shoulder_w + MAST_LEFT_GAP
	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	job.gathered = true""")
# consumer: the canopy needed now
sub("""		if got is CanopyJob:
			# decided on a worker since the chunk 600 m before; wait for it (normally long done)
			var job: CanopyJob = got
			if job.task >= 0:
				WorkerThreadPool.wait_for_task_completion(job.task)
				job.task = -1
			job.finish(tr, ctx.terrain)
			plan = job.result""", """		if got is CanopyJob:
			# decided on a worker since the chunk 600 m before; wait for it (normally long done) – or, when the race
			# started closer than that, gathered and decided here
			var job: CanopyJob = got
			if not job.gathered:
				canopy_job_rest(ctx, job)
			if job.task >= 0:
				WorkerThreadPool.wait_for_task_completion(job.task)
				job.task = -1
			if not job.done:
				job.run()
			job.finish(tr, ctx.terrain)
			plan = job.result""")
# warm-ahead: one half per collect()
sub("""			var key := "%.3f" % r0
			if not (cache as Dictionary).has(key):
				# RINT-M2 (A-18): gathered here (main thread), decided on a worker thread
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				var job := canopy_job(ctx, r0, r1)
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
				(cache as Dictionary)[key] = job
				break""", """			var key := "%.3f" % r0
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
				break""")
open(P, "w", encoding="utf-8").write(t)
print("ok")
