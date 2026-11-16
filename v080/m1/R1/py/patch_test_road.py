p = 'tests/unit/race3d/test_road_builder.gd'
s = open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:70])
    s = s.replace(old, new)


rep('''		assert_true((flags & (RoadBuilder.F_RAIL_L | RoadBuilder.F_RAIL_R)) != 0 or true, "")
''', '')
rep('''	var rv: PackedVector3Array = part["arrays"][Mesh.ARRAY_VERTEX]
	var lo := INF
	var hi := -INF
	for i in rv.size():
		var seg := clampi(i / (rv.size() / N), 0, N - 1)
		var road_y := ctx.rows_o[seg].y
		lo = minf(lo, rv[i].y - maxf(road_y, ctx.rows_o[seg + 1].y))
		hi = maxf(hi, rv[i].y - minf(road_y, ctx.rows_o[seg + 1].y))
	assert_true(lo > -0.2 and hi < 0.8 + 0.2, "Planke und Pfosten zwischen Boden und 0,80 m (%.2f … %.2f)" % [lo, hi])
''', '''	# on a level road: beam between 0.48 m and 0.80 m, posts from the ground, everything within 9 cm of the edge line
	var level: Track = SynTrack.new()
	level.fill(cfg(), SynTrack.straight(400))
	var fctx := _context(level, 2)
	var rv: PackedVector3Array = side.build(fctx, null)["arrays"][Mesh.ARRAY_VERTEX]
	var lo := INF
	var hi := -INF
	var out := 0.0
	var edge := fctx.shoulder_edge(0, 1)
	for vert: Vector3 in rv:
		lo = minf(lo, vert.y)
		hi = maxf(hi, vert.y)
		out = maxf(out, absf(absf(vert.x) - edge))
	assert_true(absf(lo) < 1.0e-4 and absf(hi - 0.8) < 1.0e-4, "Pfosten ab dem Boden, Planke bis 0,80 m (%.3f … %.3f)" % [lo, hi])
	assert_true(out < 0.1, "alles höchstens 10 cm von der Bankettkante (%.3f m)" % out)
''')
open(p, 'w', encoding='utf-8').write(s)
print("ok")
