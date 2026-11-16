#!/usr/bin/env python3
"""FIX-M2 B-01 preview (NOT committed): apply / revert a temporary variant of the props builder's corridor rule.
  preview_corridor.py apply <scope: strict|veg> <chord_m>   (300 = the shipped corridor)
  preview_corridor.py revert
scope veg = only vegetation is dropped in the bend corridor (D14 F7 literally); chord < 300 narrows the props corridor
to the sagitta of that chord (the terrain keeps its 300-m corridor)."""
import shutil
import sys

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5"
P = WT + "/scripts/race3d/builders/props.gd"
BAK = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/props.gd.preview_bak"

OLD = '''	if (decorative or bool(e["veg"])) and not bool(it.get("landmark", false)) and ctx.in_bend_corridor(z, x) \\
			and not cover.has(str(e["set"])):
		return "corridor"'''


def new(scope, chord):
    cond = 'bool(e["veg"])' if scope == "veg" else '(decorative or bool(e["veg"]))'
    return '''	if %s and not bool(it.get("landmark", false)) and _preview_corridor(ctx, z, x, %.1f) \\
			and not cover.has(str(e["set"])):
		return "corridor"''' % (cond, chord)


HELPER = '''

## FIX-M2 PREVIEW (not committed): the bend corridor of a chord c instead of the terrain's 300 m.
static func _preview_corridor(ctx: ChunkContext, z: float, x: float, chord: float) -> bool:
	var f := z / ctx.seg_len - float(ctx.seg_a)
	var i := clampi(int(floor(f)), 0, ctx.rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if x < 0.0 else 1
	var e := ctx.rows_edge[i].lerp(ctx.rows_edge[i + 1], t)
	var m := (-x + e.x if si == 0 else x - e.y) - ctx.shoulder_w
	var c := ctx.corridor[i].lerp(ctx.corridor[i + 1], t)
	var cw := c.x if si == 0 else c.y
	if not (cw > ctx.corridor_min + 0.5):
		return false
	var k := chord / 300.0
	var cp := maxf(ctx.corridor_min, (cw + ctx.shoulder_w) * k * k - ctx.shoulder_w)
	return m > 0.0 and m <= cp
'''

if sys.argv[1] == "apply":
    shutil.copy(P, BAK)
    s = open(P).read()
    assert OLD in s
    s = s.replace(OLD, new(sys.argv[2], float(sys.argv[3])), 1) + HELPER
    open(P, "w").write(s)
    print("applied", sys.argv[2], sys.argv[3])
else:
    shutil.copy(BAK, P)
    print("reverted")
