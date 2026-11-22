"""RINT-M2 note 8: warm the station caches piece by piece (warm_step) so that no half of a canopy job exceeds the budget.
usage: edit_warm.py <station.gd in> <station.gd out>"""
import sys

src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:90], t.count(old))
    t = t.replace(old, new)


# 1. constants
sub("""## measured on the test stage ("Steam Deck"): further ahead than 600 m the gather makes the Track generate its segments
## early (18 ms in one frame at 2000 m); one half per call left the last three of six canopies to be decided inline.
const WARM_AHEAD_M := 600.0
const WARM_BUDGET_MS := 0.5      ## a further half of a job starts only while the call has used less than this
""", """## measured on the test stage ("Steam Deck"): further ahead than 600 m the gather makes the Track generate its segments
## early (18 ms in one frame at 2000 m); one half per call left the last three of six canopies to be decided inline.
## Before the first half, warm_step() generates the track and fills the caches in small pieces up to WARM_BUDGET_MS
## (the first canopy of a station cost 1.2–1.5 ms per half with cold caches – 2.4 ms in one collect() on the Deck).
const WARM_AHEAD_M := 600.0
const WARM_BUDGET_MS := 1.0      ## warm_step() and a further half of a job run only while the call has used less than this
const WARM_GEN_SEGS := 6         ## warm_step(): segments the track is generated ahead per piece (~0.25 ms on the Deck)
""")

# 2. rest: lane xs through a helper
sub("""		var lanes := tr.lanes_at(zc)
		var half := lanes * tr.lane_w * 0.5
		var nl := int(round(lanes))
		var lx := PackedFloat32Array()
		for li in nl:
			lx.append(-half + tr.lane_w * (float(li) + 0.5))
		if tr.fuel_lane_factor(zc) > 0.5:
			lx.append(half + tr.lane_w * 0.5)
		job.lanes[gi] = lx
		lc[gi] = lx
		zc += LOS_STEP
""", """		var lx := _lane_xs(tr, zc)
		job.lanes[gi] = lx
		lc[gi] = lx
		zc += LOS_STEP
""")

# 3. helpers + warm_step after _shared_part()
sub("""	if not d.is_empty() and from > int(d.keys().max()):
		d.clear()
	(shared as Dictionary)[name] = d
	return d
""", """	if not d.is_empty() and from > int(d.keys().max()):
		d.clear()
	(shared as Dictionary)[name] = d
	return d


## The cameras of canopy_job_rest() at z: the lane centres and, where the fuel lane is open, its centre.
static func _lane_xs(tr: Track, z: float) -> PackedFloat32Array:
	var lanes := tr.lanes_at(z)
	var half := lanes * tr.lane_w * 0.5
	var lx := PackedFloat32Array()
	for li in int(round(lanes)):
		lx.append(-half + tr.lane_w * (float(li) + 0.5))
	if tr.fuel_lane_factor(z) > 0.5:
		lx.append(half + tr.lane_w * 0.5)
	return lx


## The entries signs_behind() keeps for segment i: [z, x, half width, right side, paved edge there, in a tunnel] of
## each sign on a side of the road.
static func _segment_signs(tr: Track, i: int) -> Array:
	var list: Array = []
	var s := tr.get_segment(i)
	for sp: Variant in s.sprites:
		var it: Dictionary = sp
		if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
			continue
		var zs := float(it.get("z", s.z))
		var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
		var right := int(it.get("side", 1)) > 0
		list.append([zs, float(it.get("x", 0.0)), hw, right, tr.road_edges_at(zs).y if right else 0.0, s.tunnel])
	return list


## Main thread, before canopy_job_begin() of a canopy ahead (RINT-M2, A-18): generates the track as far as
## signs_behind() needs it (WARM_GEN_SEGS segments per piece), then fills the builder's caches of the job's signs and
## cameras – piece by piece until the clock passes deadline_us (at least one piece per call), so that a call of
## collect() never pays a whole cold half. True when all is in place; called again by the next collect() otherwise.
## The values are those the halves would compute (the signs only once the track is generated that far, as in
## signs_behind()).
static func warm_step(ctx: ChunkContext, r0: float, r1: float, shared: Dictionary, deadline_us: int) -> bool:
	var tr := ctx.track
	var target := tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2
	# how far an earlier call generated this track ("_gen": [track id, segment]) – each call goes on from there
	var gen: Array = shared.get("_gen", [0, 0])
	var k := tr.segment_index_at(r0)
	if int(gen[0]) == tr.get_instance_id():
		k = maxi(k, int(gen[1]))
	while k < target:
		k = mini(k + WARM_GEN_SEGS, target)
		tr.get_segment(k)
		shared["_gen"] = [tr.get_instance_id(), k]
		if k < target and Time.get_ticks_usec() > deadline_us:
			return false
	var ia := tr.segment_index_at(r0)
	var sc: Dictionary = _shared_part(shared, "_signs", ia)
	for i in range(ia, tr.segment_index_at(r1 + LOS_FAR) + 1):
		if sc.has(i):
			continue
		sc[i] = _segment_signs(tr, i)
		if Time.get_ticks_usec() > deadline_us:
			return false
	var zc := floorf((r0 - 1.0 - LOS_FAR - LOS_STEP) / LOS_STEP) * LOS_STEP
	var lc: Dictionary = _shared_part(shared, "_lanes", int(round(zc / LOS_STEP)))
	while zc <= r1 + LOS_STEP:
		var gi := int(round(zc / LOS_STEP))
		if not lc.has(gi):
			lc[gi] = _lane_xs(tr, zc)
			if Time.get_ticks_usec() > deadline_us:
				return false
		zc += LOS_STEP
	return true
""")

# 4. signs_behind through the helper
sub("""		var got: Variant = sc.get(i)
		if got == null:
			# [z, x, half width, right side, paved edge there, in a tunnel] of the signs of segment i
			var list: Array = []
			var s := tr.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
					continue
				var zs := float(it.get("z", s.z))
				var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
				var right := int(it.get("side", 1)) > 0
				list.append([zs, float(it.get("x", 0.0)), hw, right, tr.road_edges_at(zs).y if right else 0.0, s.tunnel])
			got = list
			sc[i] = list
""", """		var got: Variant = sc.get(i)
		if got == null:
			got = _segment_signs(tr, i)
			sc[i] = got
""")

# 5. the warm loop: warm_step before the first half
sub("""			if ahead == null:
				if Time.get_ticks_usec() - t0 > budget_us:
					break
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				ahead = canopy_job_begin(ctx, r0, r1, cache)
				(cache as Dictionary)[key] = ahead
""", """			if ahead == null:
				var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
				if not warm_step(ctx, r0, r1, cache, t0 + budget_us):
					break
				if Time.get_ticks_usec() - t0 > budget_us:
					break
				ahead = canopy_job_begin(ctx, r0, r1, cache)
				(cache as Dictionary)[key] = ahead
""")
open(dst, "w", encoding="utf-8").write(t)
print("ok")
