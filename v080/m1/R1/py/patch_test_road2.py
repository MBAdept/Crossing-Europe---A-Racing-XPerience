p = 'tests/unit/race3d/test_road_builder.gd'
s = open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:70])
    s = s.replace(old, new)


rep('''	assert_eq(marked.size(), 1, "eine Ziellinie")
	if marked.size() == 1:
		assert_true(absf(float(marked[0]) * t.seg_len + t.seg_len * 0.5 - t.length_z) <= t.seg_len * 0.5, "… auf dem Segment mit length_z")
''', '''	# Arcade's rule: every segment whose middle is at most half a segment from the line – two when the line lies
	# exactly on a boundary, as on this synthetic track
	assert_true(is_equal_approx(fposmod(t.length_z, t.seg_len), 0.0), "die Ziellinie dieser Teststrecke liegt auf einer Segmentgrenze")
	assert_eq(marked.size(), 2, "Ziellinie auf einer Segmentgrenze: die beiden Segmente an ihr (wie in Arcade)")
	for m: int in marked:
		assert_true(absf(float(m) * t.seg_len + t.seg_len * 0.5 - t.length_z) <= t.seg_len * 0.5, "… Segment %d liegt an length_z" % m)
''')
rep('''			assert_near(float(segs[s]["x_max"]), ctx.rows_edge[s].y + t.shoulder_w, 1.0e-4, "das Band folgt der Tankspur")
''', '''			assert_near(float(segs[s]["x_max"]), maxf(ctx.rows_edge[s].y, eb.y) + t.shoulder_w, 1.0e-4, "das Band folgt der Tankspur")
''')
open(p, 'w', encoding='utf-8').write(s)
print("ok")
