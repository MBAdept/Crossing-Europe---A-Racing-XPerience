"""RINT-M2 note 8: unit test of StationB.warm_step(). usage: edit_warm_test.py <test_structures.gd> (in place)"""
import sys

p = sys.argv[1]
t = open(p, encoding="utf-8").read()
anchor = """	assert_true(found, "das Dach bei km 148,08 gefunden")


# --- border"""
assert t.count(anchor) == 1
new = """	assert_true(found, "das Dach bei km 148,08 gefunden")


## RINT-M2 (A-18, note 8): warm_step() does the cold work of a canopy job in pieces (one at least per call, here with a
## deadline already past: one per call) and leaves in the builder's cache exactly what the two halves compute
## themselves – the job decided after warming equals the job decided cold, on a second track of the same stage.
func test_station_warm_step_prepares_what_the_halves_read() -> void:
	var t := _real("prag_leipzig")
	var t2 := _real("prag_leipzig")
	assert_true(t != null and t2 != null, "Etappe Prag – Leipzig")
	if t == null or t2 == null:
		return
	var zn: Dictionary = {}
	for z: Dictionary in t.zones:
		if str(z["kind"]) == "fuel_canopy":
			zn = z
			break
	assert_false(zn.is_empty(), "ein Tankstellendach")
	if zn.is_empty():
		return
	var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
	var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
	var ctx := _context(t, _chunk_of(t, r0))
	var warm: Dictionary = {}
	var calls := 1
	while not StationB.warm_step(ctx, r0, r1, warm, Time.get_ticks_usec()) and calls < 100000:
		calls += 1
	assert_true(calls > 10 and calls < 100000, "in Stücken vorbereitet (%d Aufrufe)" % calls)
	assert_true(StationB.warm_step(ctx, r0, r1, warm, Time.get_ticks_usec()), "danach fertig")
	assert_false((warm.get("_signs", {}) as Dictionary).is_empty(), "Schilder im Cache")
	assert_false((warm.get("_lanes", {}) as Dictionary).is_empty(), "Kameras im Cache")
	var a := StationB.canopy_job_begin(ctx, r0, r1, warm)
	StationB.canopy_job_rest(ctx, a, warm)
	var ctx2 := _context(t2, _chunk_of(t2, r0))
	var b := StationB.canopy_job_begin(ctx2, r0, r1, {})
	StationB.canopy_job_rest(ctx2, b, {})
	assert_eq(a.signs, b.signs, "Schilder")
	assert_eq(a.boards, b.boards, "Tafeln")
	assert_eq(a.plan, b.plan, "Stützenplan")
	assert_eq(a.lanes, b.lanes, "Kameras")
	a.run()
	a.finish(t, ctx.terrain)
	b.run()
	b.finish(t2, ctx2.terrain)
	assert_eq(a.result, b.result, "Entscheid")


# --- border"""
t = t.replace(anchor, new)
open(p, "w", encoding="utf-8").write(t)
print("ok")
