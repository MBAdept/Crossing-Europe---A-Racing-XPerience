W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
p = W + "tests/unit/race3d/test_structures.gd"
t = open(p, encoding="utf-8").read()
anchor = "# --- border --------------------------------------------------------------------------------------------------------"
assert t.count(anchor) == 1
new = '''## RINT-M2 (A-18, NACH-R6 N-04): a canopy whose columns all fell out (outer ones in the sight corridor, the end column
## covering a board) hangs from a mast instead of standing on an emergency column Arcade does not draw – at
## prag_leipzig km 148.08 every place right of the road covers a board farther on in the bend, so the mast stands beyond
## the left shoulder (stays high over the road); it covers no board from the lanes and stands outside the corridor.
func test_station_canopy_without_column_hangs_from_a_mast() -> void:
	var t := _real("prag_leipzig")
	assert_true(t != null, "Etappe Prag – Leipzig")
	if t == null:
		return
	var found := false
	for zn: Dictionary in t.zones:
		if str(zn["kind"]) != "fuel_canopy":
			continue
		var km := t.z_to_km(float(zn["z0"]))
		if absf(km - 148.08) > 0.3:
			continue
		var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
		var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
		var ctx := _context(t, _chunk_of(t, r0))
		var plan := StationB.canopy_columns(ctx, r0, r1)
		assert_eq(plan.size(), 1, "eine Stütze: der Mast (%s)" % str(plan))
		if plan.size() != 1:
			return
		var c: Array = plan[0]
		found = true
		assert_true(str(c[1]).begins_with("mast"), "Mast statt Notstütze (%s)" % str(c))
		var sb := StationB.signs_behind(t, r0, r1)
		var x := float(c[2]) if str(c[1]) == "mast_l" else StationB.paved_edge_at(t, float(c[0])) + float(c[2])
		var xs: Array[float] = [x]
		assert_false(bool(StationB.end_column_hides(t, ctx.path, float(c[0]), xs, sb["boards"], null, StationB.MAST_W)[0]),
			"der Mast verdeckt keine Tafel aus den Spuren")
		assert_false(StationB.bend_corridor_at(t, ctx.terrain, float(c[0]), x), "der Mast steht außerhalb des Sichtkorridors")
	assert_true(found, "das Dach bei km 148,08 gefunden")


''' + anchor
t = t.replace(anchor, new)
open(p, "w", encoding="utf-8").write(t)
print("ok")
