root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/sim/modern_path_check.gd'
s = open(p).read()
a = '''## Normal run (about 30 s): stage directions whose bends are too wide for any approach (curviness <= 1: radius
## >= 400 m; Schwarz's arc theorem, Fairness.proven_clear) are not generated. --full generates every stage direction,
## confirms that bound and adds the free ribbon width (RoadPath3D.clearance) and the chunk load of the streamer rule
## (information for the terrain and the budgets, no check; about 70 s). Exit code 1 when a check fails.
'''
b = '''## Normal run (about 25 s): stage directions whose bends are too wide for any approach (curviness <= 1: radius
## >= 400 m; Schwarz's arc theorem, Fairness.proven_clear) are not generated. --full generates every stage direction,
## confirms that bound and adds the largest coordinate of a path, the free ribbon width (RoadPath3D.clearance) and
## the chunk load of the streamer rule (information for the terrain and the budgets, no check; about 55 s).
## Exit code 1 when a check fails.
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
