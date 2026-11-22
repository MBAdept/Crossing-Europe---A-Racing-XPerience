import sys
p = sys.argv[1]
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep('''	var gathered := false               ## canopy_job_rest() done
''', '''	var gathered := false               ## canopy_job_rest() done
	var rest_zc := INF                  ## FIX-RINT (B-03): the next camera place of an interrupted canopy_job_rest()
''')
rep('''## Main thread, second half of canopy_job(): the cameras (lane centres) and the paved edges at the column places.
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
		var lx := _lane_xs(tr, zc)
		job.lanes[gi] = lx
		lc[gi] = lx
		zc += LOS_STEP
''', '''## Main thread, second half of canopy_job(): the cameras (lane centres) and the paved edges at the column places.
## shared: the builder's cache – the cameras are kept there for the next canopy (its grid overlaps).
## FIX-RINT (QA-RINT-SYSTEM B-03): with deadline_us > 0 it stops once the clock passes it (after at least one camera
## place) and goes on from there in the next call – true when the job is gathered. collect() of the station stayed
## at 3.6–4.9 ms at most under load (A-18: 2 ms on the Deck): a cold rest of a canopy ahead ran whole in one call.
static func canopy_job_rest(ctx: ChunkContext, job: CanopyJob, shared: Variant = null, deadline_us: int = 0) -> bool:
	var tr := ctx.track
	var r0 := job.r0
	var r1 := job.r1
	# cameras: the lane centres (and the open fuel lane) on the LOS_STEP grid before the canopy
	var z_first := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	var zc := z_first if not is_finite(job.rest_zc) else job.rest_zc
	var lc: Dictionary = _shared_part(shared, "_lanes", int(round(z_first / LOS_STEP)))
	var fresh := 0
	while zc <= r1 + LOS_STEP:
		var gi := int(round(zc / LOS_STEP))
		var hit: Variant = lc.get(gi)
		if hit != null:
			job.lanes[gi] = hit
			zc += LOS_STEP
			continue
		if deadline_us > 0 and fresh > 0 and Time.get_ticks_usec() > deadline_us:
			job.rest_zc = zc
			return false
		var lx := _lane_xs(tr, zc)
		job.lanes[gi] = lx
		lc[gi] = lx
		fresh += 1
		zc += LOS_STEP
	job.rest_zc = INF
''')
rep('''	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	job.gathered = true
''', '''	# the mast may also stand at the front (r0 + COLUMN_IN) – the first entry of the plan is there
	job.gathered = true
	return true
''')
rep('''			if ahead is CanopyJob and not (ahead as CanopyJob).gathered:
				if Time.get_ticks_usec() - t0 > budget_us:
					break
				var job: CanopyJob = ahead
				canopy_job_rest(ctx, job, cache)
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
''', '''			if ahead is CanopyJob and not (ahead as CanopyJob).gathered:
				if Time.get_ticks_usec() - t0 > budget_us:
					break
				var job: CanopyJob = ahead
				# (B-03: in pieces under the budget – the next collect() goes on)
				if not canopy_job_rest(ctx, job, cache, t0 + budget_us):
					break
				job.task = WorkerThreadPool.add_task(job.run, false, "Modern canopy %.0f" % r0)
''')
open(p, 'w').write(s)
print("ok")
