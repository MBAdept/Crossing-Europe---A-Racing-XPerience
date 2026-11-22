WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1"
p = WT + '/tests/unit/race3d/test_structures.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:90]
    s = s.replace(old, new, 1)


rep('''		for p: Array in part.get("pillar_at", []):
			if str(p[2]) != "front":
				assert_false(ctx.in_bend_corridor(float(p[0]), float(p[1])), "Pfeiler %s nicht in der Sichtschneise einer Kurve (F7)" % str(p))
			else:
				fronts_here.append(p)''', '''		for p: Array in part.get("pillar_at", []):
			if str(p[2]) != "front":
				assert_false(_in_sight(ctx, float(p[0]), float(p[1]) - signf(float(p[1])) * BorderB.PILLAR_W * 0.5),
					"Pfeiler %s nicht in den Sichtlinien einer Kurve (F7, A-17)" % str(p))
			else:
				fronts_here.append(p)''')
rep('''		# corridor nothing below the soffit but Arcade's front pillars (F7: masts, stays and beams stay above the slab)''',
    '''		# corridor nothing below the soffit but Arcade's front pillars (F7: masts, stays and beams stay above the slab; the
		# envelope of the real sight lines, A-17 – BorderB.pillar_in_sight())''')
rep('''			if rc.z < ARCADE_ROOF_H - 0.05 and ctx.in_bend_corridor(rc.x, rc.y):''',
    '''			if rc.z > 0.5 and rc.z < ARCADE_ROOF_H - 0.05 and _in_sight(ctx, rc.x, rc.y * 0.995):''')
rep('''# --- border --------------------------------------------------------------------------------------------------------
''', '''# --- border --------------------------------------------------------------------------------------------------------

## True when road point (z, x) lies beyond the shoulder inside the envelope of the real sight lines of a bend
## (TerrainProfile.sight, contract A-17), the rows around z – BorderB.pillar_in_sight() for a point.
func _in_sight(ctx: ChunkContext, z: float, x: float) -> bool:
	var side := -1 if x < 0.0 else 1
	var k := int(floor(z / ctx.seg_len))
	var env := maxf(ctx.terrain.sight.width_near(k, side), ctx.terrain.sight.width_near(k + 1, side))
	var row := clampi(k - ctx.seg_a, 0, ctx.row_count() - 1)
	var m := absf(x) - ctx.shoulder_edge(row, side)
	return env > 0.0 and m > 0.0 and m <= env

''')
open(p, 'w').write(s)
print('ok')
