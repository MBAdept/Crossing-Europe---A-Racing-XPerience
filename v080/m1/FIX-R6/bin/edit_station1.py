import sys
p = sys.argv[1] + '/scripts/race3d/builders/station.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''const OUT_GAP := 0.25              ## an outer column's inner face this far beyond the outer edge of the boards''',
'''const OUT_GAP := 0.25              ## an outer column's inner face this far beyond the outer edge of the boards
## The rule above holds on a straight road only: in a bend the column at the end of a canopy (Arcade has none there) can
## cover part of a board several hundred metres behind it (finding B-02 of QA-R6). So the end column is checked against
## the real lines of sight (end_column_hides()): from the lane centres LOS_NEAR..LOS_FAR before every board on the right
## up to LOS_FAR behind the column, every LOS_STEP metres. If it would cover one, it stands as "end_out"; if that would
## cover one too, the canopy has no end column (Arcade has none anyway).
const LOS_NEAR := 55.0
const LOS_FAR := 400.0
const LOS_STEP := 10.0
const LOS_MARGIN := 0.05           ## the column's half width plus this''')

rep('''		tr.get_segment(tr.segment_index_at(r1 + SIGN_SCAN_M + tr.generation_lead_m()) + 2)
		var signs: Array = []
		for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + SIGN_SCAN_M) + 1):
			var s := tr.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) > 0:
					var zs := float(it.get("z", s.z))
					var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
					signs.append([zs, float(it.get("x", 0.0)) + hw - tr.road_edges_at(zs).y])
		for c: Array in column_plan(r0, r1, signs):
			if float(c[0]) >= za and float(c[0]) < zb:
				out.append(c)
	return out''',
'''		tr.get_segment(tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2)
		var signs: Array = []
		var boards: Array = []         ## [z, x of the centre, half width] of the boards on the right up to LOS_FAR behind
		for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + LOS_FAR) + 1):
			var s := tr.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) > 0:
					var zs := float(it.get("z", s.z))
					var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
					if zs <= r1 + SIGN_SCAN_M:
						signs.append([zs, float(it.get("x", 0.0)) + hw - tr.road_edges_at(zs).y])
					if not s.tunnel:
						boards.append([zs, float(it.get("x", 0.0)), hw])
		for c: Array in column_plan(r0, r1, signs):
			var zc := float(c[0])
			if zc < za or zc >= zb:
				continue
			if str(c[1]).begins_with("end") and ctx.path != null:
				var e := paved_edge_at(tr, zc)
				if str(c[1]) == "end" and end_column_hides(tr, ctx.path, zc, e + PILLAR_X, boards):
					c = [zc, "end_out", outer_place(signs, r0 - 1.0, r1 + SIGN_SCAN_M)]
				if str(c[1]) == "end_out" and end_column_hides(tr, ctx.path, zc, e + float(c[2]), boards):
					continue
			out.append(c)
	return out


## The paved right edge incl. the fuel lane where build() puts a column at z: the mean of the two rows of its segment
## (ChunkContext.rows_edge).
static func paved_edge_at(tr: Track, z: float) -> float:
	var k := maxi(int(floor(z / tr.seg_len)), 0)
	var a := tr.get_segment(k)
	var b := tr.get_segment(k + 1)
	return (a.lanes * tr.lane_w * 0.5 + a.fuel_lane * tr.lane_w + b.lanes * tr.lane_w * 0.5 + b.fuel_lane * tr.lane_w) * 0.5


## Main thread: true when a column at road position (z, x) would cover part of one of `boards` ([z, x, half width])
## from a lane centre (and the fuel lane where it is open) LOS_NEAR..LOS_FAR before the board – world-space lines of
## sight on the RoadPath3D, bends included, against the column's footprint (it spans every board height). Cameras every
## LOS_STEP metres; positions the path does not hold are skipped.
static func end_column_hides(tr: Track, p: RoadPath3D, z: float, x: float, boards: Array) -> bool:
	if not p.has(tr.segment_index_at(z) + 1):
		return false
	var cw := p.world(z, x, 0.0)
	var col := Vector2(cw.x, cw.z)
	var r := PILLAR_W * 0.5 + LOS_MARGIN
	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if p.has(tr.segment_index_at(zc)):
			var half := tr.lanes_at(zc) * tr.lane_w * 0.5
			var nl := int(round(tr.lanes_at(zc)))
			var xs: Array[float] = []
			for li in nl:
				xs.append(-half + tr.lane_w * (float(li) + 0.5))
			if tr.fuel_lane_factor(zc) > 0.5:
				xs.append(half + tr.lane_w * 0.5)
			for lx: float in xs:
				var w := p.world(zc, lx, 0.0)
				cams.append([zc, Vector2(w.x, w.z)])
		zc -= LOS_STEP
	for bd: Array in boards:
		var zs := float(bd[0])
		if zs <= z + 0.3 or zs > z + LOS_FAR or not p.has(tr.segment_index_at(zs) + 1):
			continue
		var w0 := p.world(zs, float(bd[1]) - float(bd[2]), 0.0)
		var w1 := p.world(zs, float(bd[1]) + float(bd[2]), 0.0)
		var b0 := Vector2(w0.x, w0.z)
		var b1 := Vector2(w1.x, w1.z)
		for cm: Array in cams:
			var d := zs - float(cm[0])
			if d < LOS_NEAR or d > LOS_FAR:
				continue
			var c: Vector2 = cm[1]
			var to_col := col - c
			var dc := to_col.length()
			if dc < r:
				continue
			# the column covers the angles within asin(r / dc) of its direction; the board spans its two ends' angles
			var half_a := asin(minf(1.0, r / dc))
			var a0 := to_col.angle_to(b0 - c)
			var a1 := to_col.angle_to(b1 - c)
			if maxf(a0, a1) >= -half_a and minf(a0, a1) <= half_a and (b0 - c).length() > dc:
				return true
	return false''')

rep('''## build() leaves out an outer column inside a bend's sight corridor (F7; the island lies in the shoulder band, where
## no corridor reaches). Pure.''',
'''## build() leaves out an outer column inside a bend's sight corridor (F7; the island lies in the shoulder band, where
## no corridor reaches); columns_in_chunk() checks the end column against the real lines of sight (end_column_hides()).
## Pure.''')
open(p, 'w').write(s)
print('ok')
