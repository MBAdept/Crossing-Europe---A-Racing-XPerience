root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/unit/race3d/test_fairness.gd'
s = open(p).read()

i0 = s.index("## F1/F2: the shipped camera passes on an S-bend that a tangent camera fails.")
i1 = s.index("## F3: a crest hides alike in both modes;")
new = '''## Bends like the generator makes them in a curviness-3 section: eased in and out over 30 % of their length, peak
## curve value `peak` (two of three pieces, the third 2/3 of it), alternating direction, straights in between.
func _mountain_road(peak: float) -> PackedFloat32Array:
	var curves := SynTrack.straight(100)
	for i in 10:
		var length := 110 + (i * 37) % 60
		var mag := (peak if i % 3 != 1 else peak * 0.67) * (1.0 if i % 2 == 0 else -1.0)
		var piece := PackedFloat32Array()
		piece.resize(length)
		for q in length:
			var t := float(q) / float(length)
			piece[q] = mag * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t))
		curves.append_array(piece)
		curves.append_array(SynTrack.straight(45 + (i * 23) % 50))
	curves.append_array(SynTrack.straight(400))
	return curves


## F1/F2: the shipped camera passes on tight bends that a tangent camera fails.
func test_frustum_scan_needs_the_look_into_the_bend() -> void:
	var geo := _geo(_mountain_road(0.85))        # R 141 m; the tightest bend of the network has 0.892
	var proj := Fair.make_projection(cfg())
	var envs := Fair.envelopes(cfg())
	var profiles := {}
	for w: String in Fair.WEATHERS:
		profiles[w] = Fair.speed_profile(geo, envs[w])
	var good := Fair.scan_frustum(geo, Fair.make_camera(cfg(), proj), proj, profiles, envs, {"near_from": 15, "check_every": 97})
	assert_eq(int(good["f1_cases"]), 0, "ausgelieferte Kamera: kein Fall bis 270 m")
	assert_true(int(good["samples"]) > 100000, "%d Stichproben" % int(good["samples"]))
	assert_eq(int(good["check_mismatch"]), 0, "schnelle Schleife = ChaseCamera3D/RoadProjection (%d Stichproben nachgerechnet)" % int(good["check_samples"]))
	assert_eq(int(good["check_vertical"]), 0, "nichts senkrecht außerhalb des Bildes")
	assert_true(int(good["check_samples"]) > 500, "genug nachgerechnet")
	for w: String in Fair.WEATHERS:
		assert_true(float(good["worst"][w]["ratio"]) <= 0.6, "F2 %s: %.3f" % [w, float(good["worst"][w]["ratio"])])
	var tangent := Fair.scan_frustum(geo, Fair.make_camera(cfg(), proj, {"look_gain": 0.0}), proj, profiles, envs, {"near_from": 15, "check_every": 97})
	assert_true(int(tangent["f1_cases"]) > 100, "Tangentenkamera (look_gain 0): Fälle bis 270 m (%d, nächster bei %.0f m)" % [int(tangent["f1_cases"]), float(tangent["f1_nearest_m"])])
	assert_true(float(tangent["f1_nearest_m"]) <= 230.0, "schon ab etwa 210 m")
	assert_eq(int(tangent["check_mismatch"]), 0, "auch dort stimmt die schnelle Schleife")
	# the limit of what the generator can produce (every bend at the cap 0.9 of curviness 3): the first case moves to
	# 270 m – such a stage would fail F1 and get another seed – while F2 still holds
	var cap := _geo(_mountain_road(0.9))
	var pc := {}
	for w: String in Fair.WEATHERS:
		pc[w] = Fair.speed_profile(cap, envs[w])
	var edge := Fair.scan_frustum(cap, Fair.make_camera(cfg(), proj), proj, pc, envs, {"near_from": 15})
	assert_true(int(edge["f1_cases"]) > 0 and float(edge["f1_nearest_m"]) >= 270.0, "Kurvenwert 0,9 überall: erster Fall bei %.0f m" % float(edge["f1_nearest_m"]))
	assert_true(float(edge["worst"]["normal"]["ratio"]) <= 0.6, "F2 hält auch dort (%.3f)" % float(edge["worst"]["normal"]["ratio"]))
	# a straight road never has a case
	var straight := _geo(SynTrack.straight(900))
	var ps := {}
	for w: String in Fair.WEATHERS:
		ps[w] = Fair.speed_profile(straight, envs[w])
	var rs := Fair.scan_frustum(straight, Fair.make_camera(cfg(), proj), proj, ps, envs, {"near_from": 15})
	assert_true((rs["cases"] as Dictionary).is_empty(), "Gerade: nie ein Fall")


'''
s = s[:i0] + new + s[i1:]
open(p, 'w').write(s)
print('patched')
