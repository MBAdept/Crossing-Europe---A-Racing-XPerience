W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
P = "scripts/race3d/builders/station.gd"
sub(P, """const BEAM_H := 0.4                ## the beam under the canopy edge that carries it over to an outer column
const BEAM_D := 0.3
""", """const BEAM_H := 0.4                ## the beam under the canopy edge that carries it over to an outer column
const BEAM_D := 0.3
## RINT-M2 (contract §11.3 A-18): a canopy whose columns all fell out – the outer ones in a bend's sight corridor (F7),
## the end column on the island and outside covering a gameplay board – does not stand on an emergency column Arcade
## does not draw (it covered a "curve" warning by 89 % from 210 m at prag_leipzig km 148.2, NACH-R6 N-04). It hangs like
## the border roofs: from a mast farther out (the first place MAST_STEP by MAST_STEP beyond the boards, up to MAST_MAX_OUT,
## that covers no board from the lanes and stands outside the sight corridor), with a beam under the canopy edge over to
## it and stays from the mast head to the canopy's road edge – everything new above the canopy or beyond the boards.
const MAST_TOP := 10.5
const MAST_W := 0.4
const MAST_STEP := 1.0
const MAST_MAX_OUT := 24.0
const STAY_R := 0.06
const STAY_T: Array[float] = [1.0, 0.55]   ## stays to the road edge and to the middle of the canopy
const CANOPY_TOP := 6.45                   ## top of the fascia (FASCIA_BANDS)
""")
sub(P, """	if out.is_empty() and not fallback.is_empty():
		out.append(fallback)
	return out
""", """	if out.is_empty() and not fallback.is_empty():
		var mast := hang_mast(ctx, float(fallback[0]), signs, boards, r0, r1, cache)
		out.append(mast if not mast.is_empty() else fallback)
	return out


## Main thread: the mast that hangs a canopy left without any column (see MAST_TOP) at road position zc – [zc, "mast",
## x beyond the paved edge] at the first candidate place that covers no board (end_column_hides() with the mast's width)
## and stands outside the bend's sight corridor; [] when there is none (the canopy keeps its emergency column).
static func hang_mast(ctx: ChunkContext, zc: float, signs: Array, boards: Array, r0: float, r1: float, cache: Variant = null) -> Array:
	if ctx.path == null or ctx.track == null:
		return []
	var tr := ctx.track
	var e := paved_edge_at(tr, zc)
	var off := maxf(outer_place(signs, r0 - 1.0, r1 + SIGN_SCAN_M), CANOPY_OUT + MAST_W) + MAST_STEP
	var xs: Array[float] = []
	while off <= CANOPY_OUT + MAST_MAX_OUT:
		xs.append(e + off)
		off += MAST_STEP
	var hides := end_column_hides(tr, ctx.path, zc, xs, boards, cache, MAST_W)
	for k in xs.size():
		if bool(hides[k]):
			continue
		if ctx.terrain != null and bend_corridor_at(tr, ctx.terrain, zc, xs[k]):
			continue
		return [zc, "mast", xs[k] - e]
	return []
""")
sub(P, """static func end_column_hides(tr: Track, p: RoadPath3D, z: float, xs: Array[float], boards: Array, cache: Variant = null) -> Array:""",
"""static func end_column_hides(tr: Track, p: RoadPath3D, z: float, xs: Array[float], boards: Array, cache: Variant = null,
		width: float = PILLAR_W) -> Array:""")
sub(P, """	var r := PILLAR_W * 0.5 + LOS_MARGIN
	# only the boards behind the column, and only the cameras some of them need""", """	var r := width * 0.5 + LOS_MARGIN
	# only the boards behind the column, and only the cameras some of them need""")
# build: mast drawing
sub(P, """				var kind := str(c[1])
				var off := float(c[2])
				var cx := e + off
				var base := ISLAND_H""", """				var kind := str(c[1])
				var off := float(c[2])
				var cx := e + off
				if kind == "mast":
					_mast(ctx, kit, zp, e, cx)
					pillars += 1
					column_at.append([zp, cx, kind])
					continue
				var base := ISLAND_H""")
sub(P, """## Main thread: the signs behind a canopy from r0 to r1""", """## WORKER THREAD. The mast of a canopy without column (hang_mast()): at (zp, cx) from the ground to MAST_TOP with a head
## plate, a beam under the canopy edge over to it, and its stays from the mast head to the road edge and the middle of
## the canopy's top (e = the paved edge there).
static func _mast(ctx: ChunkContext, kit: Kit, zp: float, e: float, cx: float) -> void:
	var g := ctx.ground(zp, cx)
	var f := ctx.frame(zp, cx, g)
	kit.box(f, Vector3(0.0, PLINTH_H * 0.5, 0.0), Vector3(PLINTH_W + 0.1, PLINTH_H, PLINTH_W + 0.1) * 0.5, PLINTH, ROUGH_CONCRETE, 1 | 2 | 4 | 8 | 16)
	kit.box(f, Vector3(0.0, (MAST_TOP - g) * 0.5, 0.0), Vector3(MAST_W, MAST_TOP - g, MAST_W) * 0.5, PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8)
	kit.box(f, Vector3(0.0, MAST_TOP - g + 0.08, 0.0), Vector3(MAST_W + 0.2, 0.16, MAST_W + 0.2) * 0.5, PILLAR.darkened(0.15),
		ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	# the beam under the canopy edge over to the mast (the canopy's outer edge is e + CANOPY_OUT)
	var bx0 := e + CANOPY_OUT - 0.3
	var bx1 := cx + MAST_W * 0.5
	var fb := ctx.frame(zp, (bx0 + bx1) * 0.5, CANOPY_H - BEAM_H * 0.5)
	kit.box(fb, Vector3.ZERO, Vector3((bx1 - bx0) * 0.5, BEAM_H * 0.5, BEAM_D * 0.5), PILLAR, ROUGH_METAL, 1 | 2 | 4 | 8 | 16 | 32)
	for j in STAY_T.size():
		var xt := lerpf(e + CANOPY_OUT, e + CANOPY_IN + 0.3, STAY_T[j])
		var a := ctx.local(zp, cx - MAST_W * 0.5, MAST_TOP - 0.4 - 0.6 * float(j))
		var b := ctx.local(zp, xt, CANOPY_TOP)
		_stay(kit, a, b)


## A round stay (six faces) from a to b.
static func _stay(kit: Kit, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var h := d.length()
	if h < 1.0e-3:
		return
	var y := d / h
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	kit.column(Transform3D(Basis(x, y, z), a), Vector3.ZERO, STAY_R, h, 6, PILLAR, ROUGH_METAL, false)


## Main thread: the signs behind a canopy from r0 to r1""")
print("ok")
