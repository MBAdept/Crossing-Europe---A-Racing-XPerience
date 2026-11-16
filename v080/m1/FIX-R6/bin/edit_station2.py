import sys
p = sys.argv[1] + '/scripts/race3d/builders/station.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''## The rule above holds on a straight road only: in a bend the column at the end of a canopy (Arcade has none there) can
## cover part of a board several hundred metres behind it (finding B-02 of QA-R6). So the end column is checked against
## the real lines of sight (end_column_hides()): from the lane centres LOS_NEAR..LOS_FAR before every board on the right
## up to LOS_FAR behind the column, every LOS_STEP metres. If it would cover one, it stands as "end_out"; if that would
## cover one too, the canopy has no end column (Arcade has none anyway).
const LOS_NEAR := 55.0
const LOS_FAR := 400.0
const LOS_STEP := 10.0''',
'''## The rule above holds on a straight road only: in a bend the column at the end of a canopy (Arcade has none there) can
## cover part of a board several hundred metres behind it, on either side of the road (finding B-02 of QA-R6). So the
## end column is checked against the real lines of sight (end_column_hides()): from the lane centres LOS_NEAR..LOS_FAR
## before every board up to LOS_FAR behind the column, every LOS_STEP metres. If it would cover one, it stands as
## "end_out"; if that would cover one too, the canopy has no end column (Arcade has none anyway) – unless the canopy
## would then stand on no column at all (canopy_columns()).
const LOS_NEAR := 55.0
const LOS_FAR := 600.0
const LOS_STEP := 10.0''')

rep('''var _cast := false
var _prepared := false
''', '''var _cast := false
var _prepared := false
var _plans: Dictionary = {}        ## main thread (collect): canopy_columns() per canopy of the stage, by its start z
''')

rep('''func prepare(_ctx: Dictionary) -> void:
	_atlas.prepare(panel_specs(), _renderer)
	_prepared = true''', '''func prepare(_ctx: Dictionary) -> void:
	_atlas.prepare(panel_specs(), _renderer)
	_plans.clear()
	_prepared = true''')

rep('''	return {"uv": _atlas.entries.duplicate(), "prev_fz": prev_fz, "columns": columns_in_chunk(ctx)}''',
    '''	return {"uv": _atlas.entries.duplicate(), "prev_fz": prev_fz, "columns": columns_in_chunk(ctx, _plans)}''')

a = s.index('## Main thread: the columns (column_plan()) of every canopy that reaches into the chunk, those standing in it.')
b = s.index('## The paved right edge incl. the fuel lane where build() puts a column at z:')
s = s[:a] + '''## Main thread: the columns of every canopy that reaches into the chunk (canopy_columns()), those standing in it.
## cache: a Dictionary kept by the builder for the stage – a canopy's columns are decided once (the lines of sight cost
## a few milliseconds), whichever chunk asks first.
static func columns_in_chunk(ctx: ChunkContext, cache: Variant = null) -> Array:
	var out: Array = []
	var tr := ctx.track
	if tr == null:
		return out
	var len_s := ctx.seg_len
	var za := float(ctx.seg_a) * len_s
	var zb := float(ctx.seg_b) * len_s
	for zn: Dictionary in tr.zones:
		if str(zn.get("kind", "")) != "fuel_canopy":
			continue
		var r0 := floorf(float(zn["z0"]) / len_s) * len_s
		var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
		if r0 > zb:
			break
		if r1 < za:
			continue
		var key := "%.3f" % r0
		var plan: Array
		if cache is Dictionary and (cache as Dictionary).has(key):
			plan = (cache as Dictionary)[key]
		else:
			plan = canopy_columns(ctx, r0, r1)
			if cache is Dictionary:
				(cache as Dictionary)[key] = plan
		for c: Array in plan:
			if float(c[0]) >= za and float(c[0]) < zb:
				out.append(c)
	return out


## Main thread: the columns that stand under the canopy from r0 to r1 – [[z, kind, x]] of column_plan() (the signs on
## the right read from the track up to SIGN_SCAN_M beyond it, generated far enough ahead that the curve and crest
## warnings Track inserts later are in place), then:
##  * an outer column ("front_out", "end_out") inside a bend's sight corridor stands not (F7; the island lies in the
##    shoulder band, where no corridor reaches);
##  * the end column (Arcade has none) stands where it covers no board from the road (end_column_hides(), B-02 of
##    QA-R6): on the island, else beyond the boards, else not at all;
##  * a canopy left without any column keeps its end column on the island (rather than float; 3 of 1923 canopies of the
##    network, measured with the tools of FIX-R6 – they cover a part of a far board in a bend, as before).
static func canopy_columns(ctx: ChunkContext, r0: float, r1: float) -> Array:
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
	var out: Array = []
	var fallback: Array = []
	for c: Array in column_plan(r0, r1, signs):
		var zc := float(c[0])
		var kind := str(c[1])
		var e := paved_edge_at(tr, zc)
		if kind.begins_with("end"):
			fallback = [zc, "end", PILLAR_X]
			if ctx.path != null:
				var cands: Array = [[zc, "end", PILLAR_X], [zc, "end_out", outer_place(signs, r0 - 1.0, r1 + SIGN_SCAN_M)]] \\
					if kind == "end" else [c]
				var xs: Array[float] = []
				for q: Array in cands:
					xs.append(e + float(q[2]))
				var hides := end_column_hides(tr, ctx.path, zc, xs, boards)
				var chosen: Array = []
				for k in cands.size():
					if not bool(hides[k]):
						chosen = cands[k]
						break
				if chosen.is_empty():
					continue
				c = chosen
				kind = str(c[1])
		if kind != "front" and kind != "end" and ctx.terrain != null and bend_corridor_at(tr, ctx.terrain, zc, e + float(c[2])):
			continue
		out.append(c)
	if out.is_empty() and not fallback.is_empty():
		out.append(fallback)
	return out


## Main thread: true when the road point (z, x) lies inside the sight corridor of a bend on its inside – the test of
## ChunkContext.in_bend_corridor(), for a row of any chunk (Track segments and the TerrainProfile instead of a snapshot;
## used by the station and the border builder).
static func bend_corridor_at(tr: Track, tp: TerrainProfile, z: float, x: float) -> bool:
	var f := z / tr.seg_len
	var k := maxi(int(floor(f)), 0)
	var t := clampf(f - float(k), 0.0, 1.0)
	var side := -1 if x < 0.0 else 1
	var e := lerpf(_paved_edge(tr, k, side), _paved_edge(tr, k + 1, side), t)
	var m := absf(x) - e - tr.shoulder_w
	var cw := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), t)
	var cmin := maxf(0.0, tp.corridor_min_m - tr.shoulder_w)
	return cw > cmin + 0.5 and m > 0.0 and m <= cw


## Paved edge of segment k on `side` (m from the centre, positive): ChunkContext.rows_edge of that row.
static func _paved_edge(tr: Track, k: int, side: int) -> float:
	var s := tr.get_segment(k)
	var half := s.lanes * tr.lane_w * 0.5
	return half if side < 0 else half + s.fuel_lane * tr.lane_w


''' + s[b:]

# end_column_hides: several candidate x at once, sharing cameras and boards
a = s.index('## Main thread: true when a column at road position (z, x) would cover part of one of `boards`')
b = s.index('## The columns of a canopy from r0 (start of its front segment)')
s = s[:a] + '''## Main thread: for each candidate place x of `xs` (m from the road centre) at road position z, true when a column
## there would cover part of one of `boards` ([z, x, half width]) from a lane centre (and the fuel lane where it is
## open) LOS_NEAR..LOS_FAR before the board – world-space lines of sight on the RoadPath3D, bends included, against the
## column's footprint (it spans every board height). Cameras every LOS_STEP metres; positions the path does not hold
## are skipped.
static func end_column_hides(tr: Track, p: RoadPath3D, z: float, xs: Array[float], boards: Array) -> Array:
	var out: Array = []
	out.resize(xs.size())
	out.fill(false)
	if not p.has(tr.segment_index_at(z) + 1):
		return out
	var cols: Array[Vector2] = []
	for x: float in xs:
		var cw := p.world(z, x, 0.0)
		cols.append(Vector2(cw.x, cw.z))
	var r := PILLAR_W * 0.5 + LOS_MARGIN
	var cams: Array = []               ## [z, Vector2] on a fixed grid before the column
	var zc := floorf((z - 1.0) / LOS_STEP) * LOS_STEP
	while zc >= z - LOS_FAR:
		if p.has(tr.segment_index_at(zc)):
			var half := tr.lanes_at(zc) * tr.lane_w * 0.5
			var nl := int(round(tr.lanes_at(zc)))
			var lxs: Array[float] = []
			for li in nl:
				lxs.append(-half + tr.lane_w * (float(li) + 0.5))
			if tr.fuel_lane_factor(zc) > 0.5:
				lxs.append(half + tr.lane_w * 0.5)
			for lx: float in lxs:
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
			var db := (b0 - c).length()
			for k in cols.size():
				if bool(out[k]):
					continue
				var to_col := cols[k] - c
				var dc := to_col.length()
				if dc < r or db <= dc:
					continue
				# the column covers the angles within asin(r / dc) of its direction; the board spans its two ends' angles
				var half_a := asin(minf(1.0, r / dc))
				var a0 := to_col.angle_to(b0 - c)
				var a1 := to_col.angle_to(b1 - c)
				if maxf(a0, a1) >= -half_a and minf(a0, a1) <= half_a:
					out[k] = true
	return out


''' + s[b:]

rep('''## build() leaves out an outer column inside a bend's sight corridor (F7; the island lies in the shoulder band, where
## no corridor reaches); columns_in_chunk() checks the end column against the real lines of sight (end_column_hides()).
## Pure.''', '''## canopy_columns() decides which of them stand (sight corridor F7, lines of sight of the end column). Pure.''')

rep('''				var kind := str(c[1])
				var off := float(c[2])
				var cx := e + off
				if kind != "front" and kind != "end" and ctx.in_bend_corridor(zp, cx):
					continue''', '''				var kind := str(c[1])
				var off := float(c[2])
				var cx := e + off''')
open(p, 'w').write(s)
print('ok')
