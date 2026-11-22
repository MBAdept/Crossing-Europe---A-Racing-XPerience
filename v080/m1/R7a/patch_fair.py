import sys
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1"
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a"
p = WT + '/tests/race3d/fairness.gd'
s = open(p).read()
env = open(S + '/fair_env.gd').read()
marker = '''# --- F7 -----------------------------------------------------------------------------------------------------------

'''
assert marker in s
s = s.replace(marker, marker + env, 1)
old = '''## Terrain against the sight corridor on every row and side: the ring polyline must not be above the road before the
## corridor ends. Returns {rows, sides, violations, worst_m, cut (sides whose ribbon is narrower than the outer
## ring), min_limit_m, max_corridor_m, max_height_m (highest ground above the road anywhere), raised (sides with
## ground above the road somewhere)}.
static func scan_corridor(geo: Dictionary, terr: Dictionary) -> Dictionary:'''
new = '''## Terrain against the sight corridor on every row and side: the ring polyline must not be above the road before the
## corridor ends. With `envelope` (sight_envelope()): the corridor must reach every sampled sight line that leaves the
## road (contract A-17; never beyond the medial axis to another part of the road, RoadPath3D.clearance(), as in the
## kernel) and count there as a bend's (more than the plain strip + 0.5 m: ChunkContext.in_bend_corridor(), so that
## nothing taller than 0.5 m stands in it). Returns {rows, sides, violations, worst_m, cut (sides whose ribbon is
## narrower than the outer ring), min_limit_m, max_corridor_m, max_height_m (highest ground above the road anywhere),
## raised (sides with ground above the road somewhere), env_sides (sides a sampled sight line leaves the road on),
## env_short (of them with a narrower corridor), env_short_m (largest shortfall), env_flag (of them not counted as a
## bend's corridor), env_over_m (mean of corridor - envelope there)}.
static func scan_corridor(geo: Dictionary, terr: Dictionary, envelope: Dictionary = {}) -> Dictionary:'''
assert old in s
s = s.replace(old, new, 1)
old2 = '''	return {"name": geo["name"], "rows": count, "sides": count * 2, "violations": violations, "worst_m": worst, "cut": cut,
		"min_limit_m": min_limit, "max_corridor_m": max_corr, "max_height_m": max_h, "raised": raised}'''
new2 = '''	var env_sides := 0
	var env_short := 0
	var env_short_m := 0.0
	var env_flag := 0
	var env_over := 0.0
	if not envelope.is_empty():
		var path: RoadPath3D = geo["path"]
		var track: Track = geo["track"]
		var strip := maxf(0.0, terrain.corridor_min_m - track.shoulder_w)
		var edges: PackedVector2Array = rows["edge"]
		for si in 2:
			var e: PackedFloat64Array = envelope["l"] if si == 0 else envelope["r"]
			for r in mini(count, e.size()):
				var w := e[r]
				if w <= 0.0:
					continue
				var edge := edges[r].x if si == 0 else edges[r].y
				w = minf(w, path.clearance(r, -1 if si == 0 else 1) - edge)
				if w <= 0.0:
					continue
				env_sides += 1
				var cw := corr[r].x if si == 0 else corr[r].y
				env_over += cw - w
				if cw < w - 0.02:
					env_short += 1
					env_short_m = maxf(env_short_m, w - cw)
				if cw <= strip + 0.5:
					env_flag += 1
	return {"name": geo["name"], "rows": count, "sides": count * 2, "violations": violations, "worst_m": worst, "cut": cut,
		"min_limit_m": min_limit, "max_corridor_m": max_corr, "max_height_m": max_h, "raised": raised,
		"env_sides": env_sides, "env_short": env_short, "env_short_m": env_short_m, "env_flag": env_flag,
		"env_over_m": env_over / maxf(1.0, float(env_sides))}'''
assert old2 in s
s = s.replace(old2, new2, 1)
old3 = '''##  * scan_corridor(): F7 – the terrain never rises above the road inside the sight corridor'''
assert old3 in s
s = s.replace(old3, '''##  * scan_corridor(): F7 – the terrain never rises above the road inside the sight corridor, and the corridor covers
##                     every sight line of sight_envelope() (contract A-17: the envelope of the real sight lines)''', 1)
open(p, 'w').write(s)
print("patched")
