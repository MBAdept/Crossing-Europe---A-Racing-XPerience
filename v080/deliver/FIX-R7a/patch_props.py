#!/usr/bin/env python3
"""FIX-R7a: the change QR7a-01 needs in builders/props.gd (R7c's file) and in the oracle of tests/unit/race3d/
test_props.gd – applied ONLY to a scratch copy (or by the lead at the merge). Usage: patch_props.py <tree> A|B
  A: drop_reason() tests the footprint (reach = crown radius / near edge, half_len = half the width) against the
     exact envelope of the sight lines (ChunkContext.in_sight_envelope()) instead of the foot against the terrain's
     corridor.
  B: A, and before that push_out(): a prop whose foot is outside the envelope but whose footprint reaches in moves
     away from the road by the depth + PUSH_MARGIN_M (at most PUSH_MAX_M) instead of being left out.
"""
import sys

tree, variant = sys.argv[1], sys.argv[2]
assert variant in ("A", "B")
p = tree + "/scripts/race3d/builders/props.gd"
s = open(p).read()


def rep(old, new, cnt=1):
    global s
    assert s.count(old) == cnt, (old[:90], s.count(old))
    s = s.replace(old, new)


rep("""const RIBBON_MARGIN_M := 1.0       ## a prop needs this much ribbon beyond its foot
""", """const RIBBON_MARGIN_M := 1.0       ## a prop needs this much ribbon beyond its foot
const PUSH_MARGIN_M := 0.3         ## a prop pushed out of the sight lines of a bend stands this far clear of them (push_out())
const PUSH_MAX_M := 12.0           ## … and moves at most this far; deeper it is left out (FIX-R7a measured: 6 m lost 180 city houses of the base)
""")
place_old = """	if it.has("align") and side != 0:
		x = edge_anchor_x(x, side, flipped, float(e["extent_l"]), float(e["extent_r"]), sc)
	var reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)
"""
place_new = """	if it.has("align") and side != 0:
		x = edge_anchor_x(x, side, flipped, float(e["extent_l"]), float(e["extent_r"]), sc)
	# the footprint (FIX-R7a, QR7a-01): half the width along the road; towards the road the crown's radius, or for an
	# edge-aligned building the distance from its anchor to its near edge
	var half_w := float(e["width"]) * sc * 0.5
	var reach := half_w
	if it.has("align") and side != 0:
		reach = (float(e["extent_l"]) if (side > 0 or flipped) else float(e["extent_r"])) * sc
"""
if variant == "B":
    place_new += """	if not is_cover:
		x = push_out(ctx, it, e, z, x, side, reach, half_w, cover)
"""
place_new += """	var reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover, reach, half_w)
"""
rep(place_old, place_new)
rep("""## Why a prop is left out ("" = it is drawn): see the header. e = its PropLibrary entry, (z, x) its foot.
static func drop_reason(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, seg_index: int, item: int,
		density: float, cover: Array) -> String:""", """## Why a prop is left out ("" = it is drawn): see the header. e = its PropLibrary entry, (z, x) its foot; reach and
## half_len its footprint (ChunkContext.in_sight_envelope(): how far it extends from the foot towards the road, half
## its length along the road) – FIX-R7a (QR7a-01): A-17 to the letter, no part of it in the sight lines of a bend.
static func drop_reason(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, seg_index: int, item: int,
		density: float, cover: Array, reach: float = 0.0, half_len: float = 0.0) -> String:""")
rep("""	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) and ctx.in_bend_corridor(z, x) \\
			and not cover.has(str(e["set"])):
		return "corridor"
""", """	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) and ctx.in_sight_envelope(z, x, reach, half_len) \\
			and not cover.has(str(e["set"])):
		return "corridor"
""")
if variant == "B":
    rep("""## True for the small decoration "Details" may thin out:""", """## FIX-R7a (QR7a-01, contract A-17: nothing taller than 0.5 m inside the envelope of the sight lines of a bend): a
## prop whose foot stands outside the envelope but whose footprint (reach, half_len as for drop_reason()) reaches into
## it moves away from the road by that depth + PUSH_MARGIN_M – at most PUSH_MAX_M – and keeps its place in the
## picture instead of being left out; drop_reason() leaves out what still reaches in or then lies beyond the ribbon.
## Never props the builder does not drop (landmarks, items of a stage event, ground cover).
static func push_out(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, reach: float, half_len: float,
		cover: Array) -> float:
	if side == 0 or bool(it.get("landmark", false)) or cover.has(str(e["set"])):
		return x
	if it.has("offset") and not bool(e["veg"]):
		return x
	if ctx.bend_intrusion(z, x) >= 0.0:
		return x       # the foot itself stands in the sight lines: left out
	var depth := ctx.bend_intrusion(z, x, reach, half_len)
	if depth < 0.0 or depth > PUSH_MAX_M:
		return x
	return x + float(side) * (depth + PUSH_MARGIN_M)


## True for the small decoration "Details" may thin out:""")
open(p, "w").write(s)

# --- the oracle of test_props.gd ----------------------------------------------------------------------------------
q = tree + "/tests/unit/race3d/test_props.gd"
t = open(q).read()


def rept(old, new):
    global t
    assert t.count(old) == 1, (old[:90], t.count(old))
    t = t.replace(old, new)


rept("""func _expected(t: Track, tp: TerrainProfile, lib: PropLibrary, k: int, dropped: Dictionary) -> Array:""",
     """## FIX-R7a (QR7a-01): how deep the footprint of a prop reaches into the exact envelope of the sight lines (the rows
## lo .. hi the chunk's snapshot holds; ChunkContext.bend_intrusion() computed from the TerrainProfile).
func _bend_depth(t: Track, tp: TerrainProfile, z: float, x: float, side: int, reach: float, half_len: float, lo: int, hi: int) -> float:
	var n := 0 if half_len <= 0.0 else int(ceil(half_len * 2.0 / t.seg_len))
	var depth := -INF
	for q in n + 1:
		var zq := z if n == 0 else z - half_len + half_len * 2.0 * float(q) / float(n)
		var fq := zq / t.seg_len
		var kq := clampi(int(floor(fq)), lo, hi - 1)
		var u := clampf(fq - float(kq), 0.0, 1.0)
		var m := absf(x) - lerpf(tp.edge(kq, side), tp.edge(kq + 1, side), u)
		if m <= 0.0:
			continue
		var cw := maxf(tp.envelope_width(kq, side), tp.envelope_width(kq + 1, side))
		if cw > 0.0:
			depth = maxf(depth, cw - (m - maxf(reach, 0.0)))
	return depth if depth > -INF else -1.0


func _expected(t: Track, tp: TerrainProfile, lib: PropLibrary, k: int, dropped: Dictionary, lo: int = -1000000, hi: int = 1000000) -> Array:""")
oracle_old = """			var m := absf(x) - lerpf(tp.edge(k, side), tp.edge(k + 1, side), f)
			var corr := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), f)
			var in_bend := corr > tp.corridor_min_m - t.shoulder_w + 0.5 and m > 0.0 and m <= corr
			if in_bend and (not it.has("offset") or bool(e["veg"])) and not bool(it.get("landmark", false)):
				dropped["corridor"] += 1
				continue
"""
oracle_new = """			var half_w := float(e["width"]) * sc * 0.5
			var reach := half_w
			if it.has("align"):
				reach = (float(e["extent_l"]) if (side > 0 or flipped) else float(e["extent_r"])) * sc
			var droppable := (not it.has("offset") or bool(e["veg"])) and not bool(it.get("landmark", false))
"""
if variant == "B":
    oracle_new += """			if droppable and _bend_depth(t, tp, z, x, side, 0.0, 0.0, lo, hi) < 0.0:
				var d := _bend_depth(t, tp, z, x, side, reach, half_w, lo, hi)
				if d >= 0.0 and d <= Props.PUSH_MAX_M:
					x += float(side) * (d + Props.PUSH_MARGIN_M)     # push_out()
					if absf(x) - tp.edge(k, side) > lerpf(tp.limit(k, side), tp.limit(k + 1, side), f) - Props.RIBBON_MARGIN_M:
						dropped["ribbon"] += 1
						continue
"""
oracle_new += """			if droppable and _bend_depth(t, tp, z, x, side, reach, half_w, lo, hi) >= 0.0:
				dropped["corridor"] += 1
				continue
"""
rept(oracle_old, oracle_new)
rept("""				for e: Array in _expected(t, tp, b.library, k, dropped):""",
     """				for e: Array in _expected(t, tp, b.library, k, dropped, int(ch["seg_a"]) - ChunkContext.ENV_MARGIN, int(ch["seg_b"]) + ChunkContext.ENV_MARGIN):""")
open(q, "w").write(t)
print("patched", variant)
