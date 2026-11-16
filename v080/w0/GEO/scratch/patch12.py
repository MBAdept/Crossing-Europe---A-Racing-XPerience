root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'scripts/race3d/chunk_context.gd'
s = open(p).read()

a = '''var corridor := PackedVector2Array()    ## sight corridor beyond the shoulder per row (left, right), fairness rule F7
'''
b = '''var corridor := PackedVector2Array()    ## sight corridor beyond the shoulder per row (left, right), fairness rule F7
var corridor_min := 5.5                 ## its width away from bends (TerrainProfile.corridor_min_m - shoulder)
'''
assert a in s
s = s.replace(a, b)

a = '''	corridor = tp["corridor"]
'''
b = '''	corridor = tp["corridor"]
	corridor_min = maxf(0.0, t.corridor_min_m - shoulder_w)
'''
assert a in s
s = s.replace(a, b)

a = '''## True when road coordinates (z, x) lie inside the sight corridor (fairness rule F7: no ground above the road, no
## decorative vegetation on the inside of bends) or on the road itself.
func in_corridor(z: float, x: float) -> bool:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if x < 0.0 else 1
	var e := rows_edge[i].lerp(rows_edge[i + 1], t)
	var m := (-x + e.x if si == 0 else x - e.y) - shoulder_w
	var c := corridor[i].lerp(corridor[i + 1], t)
	return m <= (c.x if si == 0 else c.y)
'''
b = '''## True when road coordinates (z, x) lie inside the sight corridor (fairness rule F7: no ground above the road) or
## on the road itself.
func in_corridor(z: float, x: float) -> bool:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if x < 0.0 else 1
	var e := rows_edge[i].lerp(rows_edge[i + 1], t)
	var m := (-x + e.x if si == 0 else x - e.y) - shoulder_w
	var c := corridor[i].lerp(corridor[i + 1], t)
	return m <= (c.x if si == 0 else c.y)


## True when (z, x) lies inside the sight corridor of a bend, on its inside – where fairness rule F7 allows no
## decorative vegetation (the props builder leaves such props out). Away from bends the corridor is only the
## corridor_min strip beside the road, and that strip does not count here.
func in_bend_corridor(z: float, x: float) -> bool:
	var f := z / seg_len - float(seg_a)
	var i := clampi(int(floor(f)), 0, rows_o.size() - 2)
	var t := clampf(f - float(i), 0.0, 1.0)
	var si := 0 if x < 0.0 else 1
	var e := rows_edge[i].lerp(rows_edge[i + 1], t)
	var m := (-x + e.x if si == 0 else x - e.y) - shoulder_w
	var c := corridor[i].lerp(corridor[i + 1], t)
	var cw := c.x if si == 0 else c.y
	return cw > corridor_min + 0.5 and m > 0.0 and m <= cw
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

p = root + 'tests/unit/race3d/test_chunk_streamer.gd'
s = open(p).read()
a = '''	assert_false(ctx.in_corridor(210.0, e + tp.corridor_width(70, 1) + 3.0), "weiter außen nicht")
'''
b = '''	assert_false(ctx.in_corridor(210.0, e + tp.corridor_width(70, 1) + 3.0), "weiter außen nicht")
	assert_false(ctx.in_bend_corridor(210.0, e + 4.0), "auf gerader Strecke gibt es keinen Kurvenkorridor")
	assert_near(ctx.corridor_min, tp.corridor_min_m - t.shoulder_w, 1.0e-6, "corridor_min")
	# on the inside of a bend the corridor is wide: vegetation there is left out by the props builder
	var tb: Track = SynTrack.new()
	tb.fill(cfg(), SynTrack.arc(400, 200.0))
	var pb := RoadPath3D.new()
	pb.setup(tb, 0, 120.0)
	var tpb := TerrainProfile.new()
	tpb.setup(pb, tb, {}, {})
	var cb := ChunkContext.new()
	cb.capture(4, 128, 160, pb, tpb, tb)
	var eb := tpb.edge(140, 1)
	assert_true(cb.in_bend_corridor(420.0, eb + 20.0), "Kurveninnenseite: 20 m neben dem Bankett liegt im Kurvenkorridor")
	assert_false(cb.in_bend_corridor(420.0, -(eb + 20.0)), "Kurvenaußenseite nicht")
	assert_false(cb.in_bend_corridor(420.0, 0.0), "die Fahrbahn selbst zählt nicht")
	assert_false(cb.in_bend_corridor(420.0, eb + tpb.corridor_width(140, 1) + 5.0), "jenseits des Korridors nicht")
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
