import sys
w = sys.argv[1]
p = w + '/scripts/race3d/builders/border.gd'
s = open(p).read()
a = s.index('## Main thread: true when the road point (z, x) lies inside the sight corridor of a bend on its inside')
b = s.index('## The pillars of a roof from r0 (start of its front segment)')
s = s[:a] + s[b:]
old = 'corr.append(ctx.terrain != null and bend_corridor_at(tr, ctx.terrain, zp, px))'
assert old in s
s = s.replace(old, 'corr.append(ctx.terrain != null and Station.bend_corridor_at(tr, ctx.terrain, zp, px))')
s = s.replace('every pillar is decided here for the whole roof (bend_corridor_at(), any row)',
              'every pillar is decided here for the whole roof (Station.bend_corridor_at(), any row)')
open(p, 'w').write(s)
t = w + '/tests/unit/race3d/test_structures.gd'
s = open(t).read()
old = 'if BorderB.bend_corridor_at(t, ctx.terrain, float(p[0]), px) != ctx.in_bend_corridor(float(p[0]), px):'
assert old in s
s = s.replace(old, 'if StationB.bend_corridor_at(t, ctx.terrain, float(p[0]), px) != ctx.in_bend_corridor(float(p[0]), px):')
open(t, 'w').write(s)
print('ok')
