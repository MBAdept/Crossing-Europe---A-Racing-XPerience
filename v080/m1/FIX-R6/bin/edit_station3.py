import sys
w = sys.argv[1]
p = w + '/scripts/race3d/builders/station.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''static func canopy_columns(ctx: ChunkContext, r0: float, r1: float) -> Array:
	var tr := ctx.track
	tr.get_segment(tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2)
	var signs: Array = []
	var boards: Array = []             ## [z, x of the centre, half width] of the boards up to LOS_FAR behind the canopy
	for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + LOS_FAR) + 1):
		var s := tr.get_segment(i)
		for sp: Variant in s.sprites:
			var it: Dictionary = sp
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
				continue
			var zs := float(it.get("z", s.z))
			var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
			if int(it.get("side", 1)) > 0 and zs <= r1 + SIGN_SCAN_M:
				signs.append([zs, float(it.get("x", 0.0)) + hw - tr.road_edges_at(zs).y])
			if not s.tunnel:
				boards.append([zs, float(it.get("x", 0.0)), hw])
	var out: Array = []''', '''static func canopy_columns(ctx: ChunkContext, r0: float, r1: float) -> Array:
	var tr := ctx.track
	var sb := signs_behind(tr, r0, r1)
	var signs: Array = sb["signs"]
	var boards: Array = sb["boards"]
	var out: Array = []''')

rep('''## Main thread: true when the road point (z, x) lies inside the sight corridor of a bend on its inside – the test of
## ChunkContext.in_bend_corridor(), for a row of any chunk''', '''## Main thread: the signs behind a canopy from r0 to r1 – {"signs": [[z, outer edge of the board beyond the paved edge]]
## of the signs on the right up to SIGN_SCAN_M beyond it (column_plan()), "boards": [[z, x of the centre, half width]]
## of every board on either side up to LOS_FAR beyond it, outside tunnels (end_column_hides())}. Generates the track far
## enough ahead that the curve and crest warnings Track inserts later are in place.
static func signs_behind(tr: Track, r0: float, r1: float) -> Dictionary:
	tr.get_segment(tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2)
	var signs: Array = []
	var boards: Array = []
	for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + LOS_FAR) + 1):
		var s := tr.get_segment(i)
		for sp: Variant in s.sprites:
			var it: Dictionary = sp
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
				continue
			var zs := float(it.get("z", s.z))
			var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
			if int(it.get("side", 1)) > 0 and zs <= r1 + SIGN_SCAN_M:
				signs.append([zs, float(it.get("x", 0.0)) + hw - tr.road_edges_at(zs).y])
			if not s.tunnel:
				boards.append([zs, float(it.get("x", 0.0)), hw])
	return {"signs": signs, "boards": boards}


## Main thread: true when the road point (z, x) lies inside the sight corridor of a bend on its inside – the test of
## ChunkContext.in_bend_corridor(), for a row of any chunk''')
open(p, 'w').write(s)

t = w + '/tests/unit/race3d/test_structures.gd'
s = open(t).read()
anchor = '''# --- border --------------------------------------------------------------------------------------------------------
'''
assert anchor in s
s = s.replace(anchor, '''func test_station_end_column_lines_of_sight() -> void:
	# B-02 of QA-R6: on a straight road a column on the island cannot cover a board whose outer edge stays inside its
	# inner face; in a right bend the lines of sight from the lanes bulge to the right and it can
	var boards: Array = []
	for d in range(30, 601, 30):
		boards.append([270.0 + float(d), 4.45, 0.3])     # boards from 4.15 to 4.75 m right of the centre
	var found := {}
	for kind: String in ["straight", "right", "left"]:
		var curves := SynTrack.straight(500)
		if kind == "right":
			curves = SynTrack.join([SynTrack.straight(92), SynTrack.arc(408, 400.0)])
		elif kind == "left":
			curves = SynTrack.join([SynTrack.straight(92), SynTrack.arc(408, -400.0)])
		var t: Track = SynTrack.new()
		t.fill(cfg(), curves, PackedFloat32Array(), {"lanes": 2.0})
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
		p.ensure(400)
		var e := StationB.paved_edge_at(t, 270.0)
		var xs: Array[float] = [e + StationB.PILLAR_X]
		found[kind] = bool(StationB.end_column_hides(t, p, 270.0, xs, boards)[0])
	assert_false(found["straight"], "gerade Strecke: die Stütze auf der Insel verdeckt keine Tafel innerhalb ihrer Innenkante")
	assert_true(found["right"], "Rechtskurve: die Sichtlinien laufen durch die Stütze – sie würde eine Tafel verdecken")
	assert_false(found["left"], "Linkskurve: die Sichtlinien laufen links an ihr vorbei")
	# the real stations: every canopy stands on a column, and no end column covers a board from the lanes
	var hiding: Array = []
	var bare: Array = []
	var ends := 0
	for sid: String in ["kiel_hamburg", "dev_testetappe"]:
		var t := _real(sid)
		if t == null:
			continue
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
			var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
			var ctx := _context(t, _chunk_of(t, r0))
			var plan := StationB.canopy_columns(ctx, r0, r1)
			if plan.is_empty():
				bare.append("%s km %.2f" % [sid, t.z_to_km(r0)])
			var sb := StationB.signs_behind(t, r0, r1)
			for c: Array in plan:
				if not str(c[1]).begins_with("end"):
					continue
				ends += 1
				var xs: Array[float] = [StationB.paved_edge_at(t, float(c[0])) + float(c[2])]
				if bool(StationB.end_column_hides(t, ctx.path, float(c[0]), xs, sb["boards"])[0]) and plan.size() > 1:
					hiding.append("%s km %.2f %s" % [sid, t.z_to_km(r0), str(c)])
	assert_true(ends > 4, "Endstützen geprüft (%d)" % ends)
	assert_eq(bare, [], "kein Dach ohne Stütze")
	assert_eq(hiding, [], "keine Endstütze verdeckt eine Tafel (Sichtlinien aus den Spuren, Kurven eingeschlossen)")


''' + anchor)
open(t, 'w').write(s)
print('ok')
