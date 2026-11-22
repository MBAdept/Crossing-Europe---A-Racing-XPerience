WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1"
p = WT + '/scripts/race3d/builders/border.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:90]
    s = s.replace(old, new, 1)


rep('''		var plan := pillar_plan(r0, r1, signs)
		var corr: Array = []
		for p: Array in plan:
			var zp := float(p[0])
			var sd := int(p[1])
			var ed2 := edges_at(tr, zp)
			var px := float(sd) * ((ed2.y if sd > 0 else -ed2.x) + float(p[3]))
			corr.append(ctx.terrain != null and Station.bend_corridor_at(tr, ctx.terrain, zp, px))''',
    '''		var plan := pillar_plan(r0, r1, signs)
		var corr: Array = []
		for p: Array in plan:
			corr.append(ctx.terrain != null and pillar_in_sight(ctx.terrain, len_s, float(p[0]), int(p[1]), float(p[3])))''')
rep('''## every pillar is decided here for the whole roof (Station.bend_corridor_at(), any row), so that a roof that spans two chunks
## gets one decision.''', '''## every pillar is decided here for the whole roof (pillar_in_sight(), any row), so that a roof that spans two chunks
## gets one decision.''')
rep('''## Which pillars of a plan stand and how the roof is carried.''', '''## True when a pillar of `side` at road position z, its centre `out` metres beyond the shoulder edge, would stand in the
## sight lines of a bend (contracts A-17 and A-18): its face towards the road (PILLAR_W / 2 inside its centre – the
## plinth stays below 0.5 m) lies inside the envelope of the real sight lines (TerrainProfile.sight, any row; the rows
## the pillar stands on and their neighbours). The exact envelope, not ChunkContext.in_bend_corridor(): that counts a
## corridor as a bend's only beyond the plain strip + 0.5 m and so keeps a little more free than the sight lines need
## near the ends of a bend – there a pillar of Arcade's place stands again where no sight line passes (A-18). Main thread.
static func pillar_in_sight(tp: TerrainProfile, seg_len: float, z: float, side: int, out: float) -> bool:
	var k := int(floor(z / seg_len))
	var env := maxf(tp.sight.width_near(k, side), tp.sight.width_near(k + 1, side))
	return env > 0.0 and out - PILLAR_W * 0.5 <= env


## Which pillars of a plan stand and how the roof is carried.''')
rep('''##    roof – moved out beyond the sign boards where they could cover a sign (F1), with a beam to the roof edge; none
##    but Arcade's front ones inside a bend's sight corridor (F7);''', '''##    roof – moved out beyond the sign boards where they could cover a sign (F1), with a beam to the roof edge; none
##    but Arcade's front ones inside the sight lines of a bend (F7, the envelope of A-17: pillar_in_sight());''')
open(p, 'w').write(s)
print('ok')
