import sys
p = sys.argv[1] + '/scripts/race3d/builders/border.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''##  * pillars (pillar_plan()): Arcade's two at the front 0.6 m outside the shoulder edges and two more at the end of the
##    roof – moved out beyond the sign boards where they could cover a sign (F1), with a beam to the roof edge; none
##    but Arcade's front ones inside a bend's sight corridor (F7).''',
'''##  * pillars (pillar_plan()): Arcade's two at the front 0.6 m outside the shoulder edges and two more at the end of the
##    roof – moved out beyond the sign boards where they could cover a sign (F1), with a beam to the roof edge; none
##    but Arcade's front ones inside a bend's sight corridor (F7);
##  * a side of the roof left without any pillar that way (a sign under the roof on the inside of a bend: 5 of 48 roofs
##    of the network) is hung from masts (support_plan()): the pillars of the other side rise to MAST_TOP and carry it
##    with stays over the slab to a steel edge beam on the free side – all of it above the slab, nothing new in the
##    corridor (FIX-R6, finding B-01 of QA-R6).''')

rep('''const BEAM_H := 0.45
const BEAM_D := 0.4''',
'''const BEAM_H := 0.45
const BEAM_D := 0.4
## Masts that hang the free side of a roof (support_plan()): the pillars of the carried side rise to MAST_TOP; from the
## mast head two stays per mast run over the slab to STAY_T of the way to the free edge, the outer one to a steel edge
## beam on the slab along the free side. Everything above SLAB_TOP: the camera at 3.4 m looks at no car or sign through
## it (the slab below covers every line of sight that could reach it from under the roof).
const MAST_TOP := 13.0
const MAST_W := 0.5
const STAY_R := 0.07
const STAY_T: Array[float] = [0.55, 1.0]
const EDGE_BEAM := Vector2(0.4, 0.45)   ## free-edge beam on the slab: width, height
const EDGE_IN := 0.25              ## … its outer face this far inside the free edge of the slab''')

rep('''	return {"uv": _atlas.entries.duplicate(), "pillars": pillars_in_chunk(ctx)}''',
'''	var sup := supports_in_chunk(ctx)
	return {"uv": _atlas.entries.duplicate(), "pillars": sup["pillars"], "free": sup["free"]}''')

a = s.index('## Main thread: the pillars (pillar_plan()) of every roof that reaches into the chunk, those standing in it.')
b = s.index('## The pillars of a roof from r0 (start of its front segment)')
s = s[:a] + '''## Main thread: the pillars of every roof that reaches into the chunk that stand in it (supports_in_chunk()).
static func pillars_in_chunk(ctx: ChunkContext) -> Array:
	return supports_in_chunk(ctx)["pillars"]


## Main thread: the supports of every roof that reaches into the chunk – {"pillars": [[z, side, kind, out, mast]] of
## pillar_plan() that support_plan() keeps and that stand in the chunk (mast: the pillar rises to a mast that carries
## the free side), "free": [[r0, r1, side]] of the roofs whose `side` stands on no pillar and hangs from those masts}.
## The signs behind a roof are read from the track up to SIGN_SCAN_M beyond it – generated far enough ahead that the
## curve and crest warnings Track inserts later into segments already made are in place. The sight corridor (F7) of
## every pillar is decided here for the whole roof (bend_corridor_at(), any row), so that a roof that spans two chunks
## gets one decision.
static func supports_in_chunk(ctx: ChunkContext) -> Dictionary:
	var out: Array = []
	var free: Array = []
	var tr := ctx.track
	if tr == null:
		return {"pillars": out, "free": free}
	var len_s := ctx.seg_len
	var za := float(ctx.seg_a) * len_s
	var zb := float(ctx.seg_b) * len_s
	for zn: Dictionary in tr.zones:
		if str(zn.get("kind", "")) != "border":
			continue
		var r0 := floorf(float(zn["z0"]) / len_s) * len_s
		var r1 := ceilf(float(zn["z1"]) / len_s) * len_s
		if r0 > zb:
			break
		if r1 < za:
			continue
		tr.get_segment(tr.segment_index_at(r1 + SIGN_SCAN_M + tr.generation_lead_m()) + 2)
		var signs: Array = []
		for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + SIGN_SCAN_M) + 1):
			var s := tr.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) != 0:
					var zs := float(it.get("z", s.z))
					var side := int(it.get("side", 1))
					var ed := edges_at(tr, zs)
					var edge := ed.y if side > 0 else -ed.x
					var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
					signs.append([zs, side, absf(float(it.get("x", 0.0))) + hw - edge])
		var plan := pillar_plan(r0, r1, signs)
		var corr: Array = []
		for p: Array in plan:
			var zp := float(p[0])
			var sd := int(p[1])
			var ed2 := edges_at(tr, zp)
			var px := float(sd) * ((ed2.y if sd > 0 else -ed2.x) + float(p[3]))
			corr.append(ctx.terrain != null and bend_corridor_at(tr, ctx.terrain, zp, px))
		var sup := support_plan(plan, corr)
		for p: Array in sup["pillars"]:
			if float(p[0]) >= za and float(p[0]) < zb:
				out.append(p)
		if int(sup["free"]) != 0 and r1 > za and r0 < zb:
			free.append([r0, r1, int(sup["free"])])
	return {"pillars": out, "free": free}


## Which pillars of a plan stand and how the roof is carried. plan: pillar_plan(); corridor: per entry, true when the
## pillar would stand in a bend's sight corridor (F7). Rules:
##  * Arcade's "front" pillars always stand (Arcade draws them there, its painter's order covers the same);
##  * every other pillar stands only outside a corridor;
##  * a side left without any pillar is hung from masts: the standing pillars of the other side rise to masts
##    ([…, mast = true]) and "free" names that side. If both sides were left without one (never in the network,
##    measured with the probe of FIX-R6), the moved-out front pillars stand after all.
## Returns {"pillars": [[z, side, kind, out, mast]], "free": 0 | -1 | 1}. Pure.
static func support_plan(plan: Array, corridor: Array) -> Dictionary:
	var keep: Array = []
	var stands := {-1: 0, 1: 0}
	for i in plan.size():
		var p: Array = plan[i]
		var k := str(p[2]) == "front" or not (i < corridor.size() and bool(corridor[i]))
		keep.append(k)
		if k:
			stands[int(p[1])] += 1
	var free := 0
	if int(stands[-1]) == 0 and int(stands[1]) == 0:
		for i in plan.size():
			if str((plan[i] as Array)[2]) == "front_out":
				keep[i] = true
	elif int(stands[1]) == 0:
		free = 1
	elif int(stands[-1]) == 0:
		free = -1
	var out: Array = []
	for i in plan.size():
		if keep[i]:
			var p: Array = plan[i]
			out.append([p[0], p[1], p[2], p[3], free != 0 and int(p[1]) == -free])
	return {"pillars": out, "free": free}


## Main thread: true when the road point (z, x) lies inside the sight corridor of a bend on its inside – the test of
## ChunkContext.in_bend_corridor(), for a row of any chunk (Track segments and the TerrainProfile instead of a snapshot).
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

rep('''## No pillar can so cover a sign. build() leaves out every pillar but Arcade's "front" that stands in a bend's sight
## corridor (F7) – a roof in a bend may then stand on one side only. signs:''',
'''## No pillar can so cover a sign. support_plan() leaves out every pillar but Arcade's "front" that stands in a bend's
## sight corridor (F7) and hangs a side left without one from masts. signs:''')

# build(): pillars from the plan as decided in collect(), masts with stays, edge beam on the free side
rep('''	# pillars (pillar_plan(): none that could cover a sign, F1), all but Arcade's front ones never inside a bend's sight
	# corridor (F7); an outer pillar beyond the roof's edge carries it on a beam under the soffit
	var pillar_at: Array = []
	var plan: Array = (input as Dictionary).get("pillars", []) if input is Dictionary else []
	for p: Array in plan:
		var zp := float(p[0])
		var row := clampi(int(floor(zp / seg_len)) - ctx.seg_a, 0, rows - 2)
		var sr: Dictionary = ctx.segs[row]
		if str(sr["cover"]) == "" or bool(sr["tunnel"]):
			continue
		var sd := 1.0 if int(p[1]) > 0 else -1.0
		var edge := ctx.shoulder_edge(row, int(sd))
		var out := float(p[3])
		var px := sd * (edge + out)
		if str(p[2]) != "front" and ctx.in_bend_corridor(zp, px):
			continue
		var g := minf(ctx.ground(zp, px), 0.0) - 0.3
		var top := ROOF_H
		var beam := out + PILLAR_W * 0.5 > FASCIA_OUT''',
'''	# pillars (supports_in_chunk(): none that could cover a sign, F1; all but Arcade's front ones never inside a bend's
	# sight corridor, F7 – decided for the whole roof on the main thread); an outer pillar beyond the roof's edge carries
	# it on a beam under the soffit; a mast carries the free side of a roof with stays over the slab
	var pillar_at: Array = []
	var masts := 0
	var plan: Array = (input as Dictionary).get("pillars", []) if input is Dictionary else []
	for p: Array in plan:
		var zp := float(p[0])
		var row := clampi(int(floor(zp / seg_len)) - ctx.seg_a, 0, rows - 2)
		var sr: Dictionary = ctx.segs[row]
		if str(sr["cover"]) == "" or bool(sr["tunnel"]):
			continue
		var sd := 1.0 if int(p[1]) > 0 else -1.0
		var edge := ctx.shoulder_edge(row, int(sd))
		var out := float(p[3])
		var px := sd * (edge + out)
		var mast := p.size() > 4 and bool(p[4])
		var g := minf(ctx.ground(zp, px), 0.0) - 0.3
		var top := ROOF_H
		var beam := out + PILLAR_W * 0.5 > FASCIA_OUT''')

rep('''		var f := ctx.frame(zp, px, 0.0)
		kit.box(f, Vector3(0.0, (g + top) * 0.5, 0.0), Vector3(PILLAR_W, top - g, PILLAR_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
		kit.box(f, Vector3(0.0, (g + 0.35) * 0.5, 0.0), Vector3(PLINTH_HALF, (0.35 - g) * 0.5, PLINTH_HALF), PILLAR.darkened(0.2),
			ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
		pillars += 1
		pillar_at.append([zp, px, str(p[2])])''',
'''		var f := ctx.frame(zp, px, 0.0)
		kit.box(f, Vector3(0.0, (g + top) * 0.5, 0.0), Vector3(PILLAR_W, top - g, PILLAR_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
		kit.box(f, Vector3(0.0, (g + 0.35) * 0.5, 0.0), Vector3(PLINTH_HALF, (0.35 - g) * 0.5, PLINTH_HALF), PILLAR.darkened(0.2),
			ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
		if mast:
			var xf := -sd * (ctx.shoulder_edge(row, -int(sd)) + FASCIA_OUT - EDGE_IN - EDGE_BEAM.x * 0.5)
			_mast(ctx, kit, zp, px, top if beam else SLAB_TOP, xf)
			masts += 1
		pillars += 1
		pillar_at.append([zp, px, str(p[2]) + ("+mast" if mast else "")])
	# the steel edge beam on the slab along a free side (the stays end on it)
	var free: Array = (input as Dictionary).get("free", []) if input is Dictionary else []
	for fr: Array in free:
		var fs := int(fr[2])
		for i in rows - 1:
			var sa2: Dictionary = ctx.segs[i]
			if str(sa2["cover"]) == "" or bool(sa2["tunnel"]):
				continue
			var z0b := float(ctx.seg_a + i) * seg_len
			var z1b := z0b + seg_len
			if z0b < float(fr[0]) - 0.01 or z1b > float(fr[1]) + 0.01:
				continue
			var xo := float(fs) * (ctx.shoulder_edge(i, fs) + FASCIA_OUT - EDGE_IN)
			var xi := xo - float(fs) * EDGE_BEAM.x
			var ends := (1 if z0b <= float(fr[0]) + 0.01 else 0) | (2 if z1b >= float(fr[1]) - 0.01 else 0)
			kit.road_box(ctx, z0b, z1b, minf(xi, xo), maxf(xi, xo), SLAB_TOP, SLAB_TOP + EDGE_BEAM.y, PILLAR, ROUGH_METAL,
				4 | 8 | 16 | ends)''')

rep('''	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [], "lamps": lamps, "covers": covers,
		"fronts": fronts, "pillars": pillars, "pillar_at": pillar_at, "pools": pools, "letterings": letterings,
		"triangles": kit.triangles() + pan.count * 2}''',
'''	return {"arrays": kit.arrays(), "panels": pan.arrays() if not pan.is_empty() else [], "lamps": lamps, "covers": covers,
		"fronts": fronts, "pillars": pillars, "pillar_at": pillar_at, "masts": masts, "pools": pools, "letterings": letterings,
		"triangles": kit.triangles() + pan.count * 2}


## A mast on the pillar at (zp, px) from `from_h` up to MAST_TOP with a head plate, and its stays over the slab towards
## the free side (x_free: the centre of the edge beam there): STAY_T of the way, each from its own point of the mast head.
static func _mast(ctx: ChunkContext, kit: Station.Kit, zp: float, px: float, from_h: float, x_free: float) -> void:
	var f := ctx.frame(zp, px, 0.0)
	kit.box(f, Vector3(0.0, (from_h + MAST_TOP) * 0.5, 0.0), Vector3(MAST_W, MAST_TOP - from_h, MAST_W) * 0.5, PILLAR, ROUGH_METAL,
		1 | 2 | 4 | 8)
	kit.box(f, Vector3(0.0, MAST_TOP + 0.08, 0.0), Vector3(MAST_W + 0.2, 0.16, MAST_W + 0.2) * 0.5, PILLAR.darkened(0.15), ROUGH_METAL,
		1 | 2 | 4 | 8 | 16 | 32)
	for j in STAY_T.size():
		var t := STAY_T[j]
		var a := ctx.local(zp, px + (x_free - px) * 0.06, MAST_TOP - 0.45 - 0.7 * float(j))
		var b := ctx.local(zp, lerpf(px, x_free, t), SLAB_TOP + (EDGE_BEAM.y * 0.5 if t >= 1.0 else 0.0))
		_rod(kit, a, b, STAY_R, PILLAR)
		if t < 1.0:
			# the anchor plate on the slab
			var fa := ctx.frame(zp, lerpf(px, x_free, t), SLAB_TOP)
			kit.box(fa, Vector3(0.0, 0.08, 0.0), Vector3(0.5, 0.16, 0.4) * 0.5, PILLAR.darkened(0.15), ROUGH_METAL, 1 | 2 | 4 | 8 | 16)


## A round rod (six faces) from a to b.
static func _rod(kit: Station.Kit, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := b - a
	var h := d.length()
	if h < 1.0e-3:
		return
	var y := d / h
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	kit.column(Transform3D(Basis(x, y, z), a), Vector3.ZERO, r, h, 6, col, ROUGH_METAL, false)''')

rep('''	return {"covers": int(part.get("covers", 0)), "fronts": int(part.get("fronts", 0)), "pillars": int(part.get("pillars", 0)),
		"pillar_at": part.get("pillar_at", []),''',
'''	return {"covers": int(part.get("covers", 0)), "fronts": int(part.get("fronts", 0)), "pillars": int(part.get("pillars", 0)),
		"pillar_at": part.get("pillar_at", []), "masts": int(part.get("masts", 0)),''')

open(p, 'w').write(s)
print("ok")
