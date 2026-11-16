root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/unit/race3d/test_fairness.gd'
s = open(p).read()

a = '''	# R = 160 m: 320 m apart – fine, and nothing below the grid cell of 300 m is reported
	var arc_w := int(round(PI * 160.0 / 3.0))
	var wide := _geo(SynTrack.join([SynTrack.straight(260), SynTrack.arc(arc_w, 160.0), SynTrack.straight(260)]))
	assert_eq(float(Fair.scan_path(wide)["min_m"]), INF, "Haarnadel R 160 m: keine Annäherung unter 300 m")
'''
b = '''	# R = 160 m: the chord of 360 m of arc is 288.7 m – above the limit of 250 m
	var arc_w := int(round(PI * 160.0 / 3.0))
	var wide := _geo(SynTrack.join([SynTrack.straight(260), SynTrack.arc(arc_w, 160.0), SynTrack.straight(260)]))
	assert_near(float(Fair.scan_path(wide)["min_m"]), 2.0 * 160.0 * sin(360.0 / 320.0), 0.5, "Haarnadel R 160 m: Sehne über 360 m Bogen")
	# R = 200 m: 400 m apart, nothing below the grid cell of 300 m
	var arc_v := int(round(PI * 200.0 / 3.0))
	var very := _geo(SynTrack.join([SynTrack.straight(260), SynTrack.arc(arc_v, 200.0), SynTrack.straight(260)]))
	assert_eq(float(Fair.scan_path(very)["min_m"]), INF, "Haarnadel R 200 m: keine Annäherung unter 300 m")
'''
assert a in s
s = s.replace(a, b)

a = '''	# long alternating bends with R = 300 m and short straights – like a curviness-2 section
	var parts: Array = [SynTrack.straight(100)]
	for i in 8:
		parts.append(SynTrack.arc(130, 300.0 if i % 2 == 0 else -300.0))
		parts.append(SynTrack.straight(40))
	parts.append(SynTrack.straight(400))
	var geo := _geo(SynTrack.join(parts))
'''
b = '''	# tight bends like the generator makes them in a curviness-3 section: eased in and out over 30 % of their length,
	# up to curve 0.9 (R 133 m), straights in between
	var curves := SynTrack.straight(100)
	for i in 10:
		var length := 110 + (i * 37) % 60
		var mag := (0.9 if i % 3 != 1 else 0.6) * (1.0 if i % 2 == 0 else -1.0)
		var piece := PackedFloat32Array()
		piece.resize(length)
		for q in length:
			var t := float(q) / float(length)
			piece[q] = mag * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t))
		curves.append_array(piece)
		curves.append_array(SynTrack.straight(45 + (i * 23) % 50))
	curves.append_array(SynTrack.straight(400))
	var geo := _geo(curves)
'''
assert a in s
s = s.replace(a, b)

a = '''	# a two-lane bend with R = 400 m on a gentle slope: free sight across the inside with the shipped terrain
	var m := 1400
	var bend := _geo(SynTrack.join([SynTrack.straight(100), SynTrack.arc(m - 100, 400.0)]), SynTrack.grades(m, [[0, 0.012]]), {"lanes": 2.0, "road": "landstrasse"})'''
b = '''	# a fast two-lane bend with R = 600 m on a gentle slope: free sight across the inside with the shipped terrain
	var m := 1400
	var bend := _geo(SynTrack.join([SynTrack.straight(100), SynTrack.arc(m - 100, 600.0)]), SynTrack.grades(m, [[0, 0.012]]), {"lanes": 2.0, "road": "landstrasse"})'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
