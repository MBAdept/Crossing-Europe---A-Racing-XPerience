extends TestCase
## The fairness and world checks themselves (tests/race3d/fairness.gd, used by tests/sim/modern_sight.gd and
## modern_path_check.gd) on synthetic roads: each check passes where it should and – more important – fails where it
## must: a road that comes too close to itself, a camera that does not look into the bend, ground that is raised on
## the inside of a fast bend.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")


func _geo(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array(), opts: Dictionary = {}) -> Dictionary:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, heights, opts)
	return Fair.geo_of_track(cfg(), t, "test")


func test_envelopes_and_speed_profile() -> void:
	var envs := Fair.envelopes(cfg())
	var dry: Dictionary = envs["normal"]
	assert_near(float(dry["vtop"]) * 3.6, 270.0, 0.01, "schnellstes Auto 270 km/h")
	assert_near(float(dry["safe1"]), sqrt(8.0 * 120.0), 0.01, "beste Querhaftung 8 m/s² bei Kurvenwert 1 (R 120 m)")
	assert_near(float(dry["brake"]), 70.0 / 3.6, 0.001, "Vollbremsung 70 km/h/s")
	assert_near(float(dry["seen_m"]), 0.839 * 900.0, 0.5, "gesehen ab 0,839 × Sichtweite")
	assert_near(float(envs["rain"]["seen_m"]), 0.839 * 585.0, 0.5, "Regen: 65 % Sicht")
	assert_near(float(envs["snow"]["seen_m"]), 0.839 * 450.0, 0.5, "Schnee: 50 % Sicht")
	assert_true(float(envs["snow"]["brake"]) < float(envs["rain"]["brake"]) and float(envs["rain"]["brake"]) < float(dry["brake"]), "Bremsung sinkt mit der Haftung")
	# a straight, then a bend with R = 400 m, then a straight
	var geo := _geo(SynTrack.join([SynTrack.straight(400), SynTrack.arc(200, 400.0), SynTrack.straight(400)]))
	var p := Fair.speed_profile(geo, dry)
	var v: PackedFloat64Array = p["v"]
	var need: PackedFloat64Array = p["need"]
	assert_near(v[50], 75.0, 1.0e-6, "Gerade: Höchstgeschwindigkeit")
	assert_near(need[50], 75.0 + 75.0 * 75.0 / (2.0 * 70.0 / 3.6), 0.01, "Anhalteweg bei 270 km/h: 219,6 m (1 s Reaktion + Vollbremsung)")
	var v_curve := 1.05 * sqrt(8.0 * 400.0)
	assert_near(v[500], v_curve, 0.01, "Kurve R 400 m: 5 % über der Kurvengrenze")
	assert_true(v[399] < 75.0 and v[399] >= v_curve and v[380] > v[399], "davor die Bremshüllkurve rückwärts")
	assert_near(v[900], 75.0, 1.0e-6, "dahinter wieder frei")


func test_path_scan() -> void:
	# a hairpin with R = 110 m: the legs run 220 m apart – too close
	var arc_n := int(round(PI * 110.0 / 3.0))
	var tight := _geo(SynTrack.join([SynTrack.straight(260), SynTrack.arc(arc_n, 110.0), SynTrack.straight(260)]))
	var r := Fair.scan_path(tight)
	assert_between(float(r["min_m"]), 215.0, 222.0, "Haarnadel R 110 m: Schenkel 220 m auseinander (%.1f m)" % float(r["min_m"]))
	assert_true(float(r["min_sep_m"]) >= 360.0 and float(r["min_sep_m"]) <= 1900.0, "bei 360 … 1900 m Weg")
	assert_true(float(r["near_m"][250.0]) > 100.0, "Straßenlänge mit Annäherung unter 250 m gezählt")
	# R = 160 m: the chord of 360 m of arc is 288.7 m – above the limit of 250 m
	var arc_w := int(round(PI * 160.0 / 3.0))
	var wide := _geo(SynTrack.join([SynTrack.straight(260), SynTrack.arc(arc_w, 160.0), SynTrack.straight(260)]))
	assert_near(float(Fair.scan_path(wide)["min_m"]), 2.0 * 160.0 * sin(360.0 / 320.0), 0.5, "Haarnadel R 160 m: Sehne über 360 m Bogen")
	# R = 200 m: 400 m apart, nothing below the grid cell of 300 m
	var arc_v := int(round(PI * 200.0 / 3.0))
	var very := _geo(SynTrack.join([SynTrack.straight(260), SynTrack.arc(arc_v, 200.0), SynTrack.straight(260)]))
	assert_eq(float(Fair.scan_path(very)["min_m"]), INF, "Haarnadel R 200 m: keine Annäherung unter 300 m")
	# a loop that closes after about 2.9 km of path: a crossing far apart is a loop, not a clearance problem
	var loop_n := int(round(TAU * 420.0 / 3.0))
	var loop := _geo(SynTrack.join([SynTrack.straight(40), SynTrack.arc(loop_n + 60, 420.0)]))
	var lr := Fair.scan_path(loop)
	assert_eq(float(lr["min_m"]), INF, "Schleife: innerhalb von 1900 m Weg kein Problem")
	assert_true(float(lr["loop_min_m"]) < 30.0, "die Straße kreuzt sich (%.1f m)" % float(lr["loop_min_m"]))
	assert_between(float(lr["loop_sep_m"]), 2300.0, 2700.0, "erste Annäherung unter 250 m nach %.0f m Weg" % float(lr["loop_sep_m"]))
	# the curvature bound that lets the path check skip gentle stages
	assert_true(Fair.proven_clear(400.0, 250.0, 360.0, 2000.0), "R >= 400 m: keine Annäherung unter 250 m zwischen 360 und 2000 m Weg möglich")
	assert_false(Fair.proven_clear(120.0 / 0.45, 250.0, 360.0, 2000.0), "R 267 m: nicht beweisbar, muss gerechnet werden")
	assert_false(Fair.proven_clear(110.0, 250.0, 360.0, 2000.0), "R 110 m: nicht beweisbar")
	assert_near(Fair.max_curve_of_stage(cfg(), {"sections": [{"curviness": 0}, {"curviness": 2}, {"curviness": 1}]}), 0.45, 1.0e-6, "größter Kurvenwert einer Etappe")


## Bends like the generator makes them in a curviness-3 section: eased in and out over 30 % of their length, peak
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


## F3: a crest hides alike in both modes; ground raised on the inside of a fast bend makes Modern see too late.
func test_crest_scan() -> void:
	var proj := Fair.make_projection(cfg())
	var envs := Fair.envelopes(cfg())
	var seen := float(envs["normal"]["seen_m"])
	# straight road: up with 4 %, down with 6 % behind a crest at boundary 500
	var n := 1500
	var crest := _geo(SynTrack.straight(n), SynTrack.grades(n, [[0, 0.04], [500, -0.06], [900, 0.01]]))
	var terr := Fair.build_terrain(cfg(), crest)
	var prof := Fair.speed_profile(crest, envs["normal"])
	var r := Fair.scan_crests(crest, terr, proj, prof, seen)
	assert_true(int(r["targets"]) >= 8, "%d Ziele" % int(r["targets"]))
	assert_true(int(r["car"]["limited"]) >= 1, "die Kuppe begrenzt die Sicht auf Fahrzeuge dahinter")
	assert_eq(int(r["car"]["later"]) + int(r["sign"]["later"]), 0, "gerade Straße: Modern sieht nichts später als Arcade")
	assert_eq(int(r["car"]["fail"]) + int(r["sign"]["fail"]), 0, "kein Verstoß")
	var da: PackedFloat32Array = r["car"]["da"]
	var ds: PackedFloat32Array = r["sign"]["da"]
	var behind := 0
	for i in da.size():
		assert_true(ds[i] >= da[i], "ein Schild (2,8 m) ist mindestens so früh zu sehen wie ein Fahrzeug (0,75 m)")
		if da[i] < 300.0:
			behind += 1
	assert_true(behind >= 1, "ein Ziel kurz hinter der Kuppe ist erst aus der Nähe zu sehen")
	# a fast two-lane bend with R = 600 m on a gentle slope: free sight across the inside with the shipped terrain
	var m := 1400
	var bend := _geo(SynTrack.join([SynTrack.straight(100), SynTrack.arc(m - 100, 600.0)]), SynTrack.grades(m, [[0, 0.012]]), {"lanes": 2.0, "road": "landstrasse"})
	var terr_b := Fair.build_terrain(cfg(), bend)
	var prof_b := Fair.speed_profile(bend, envs["normal"])
	var ok := Fair.scan_crests(bend, terr_b, proj, prof_b, seen)
	assert_true(int(ok["targets"]) >= 4, "Kurve: %d Ziele" % int(ok["targets"]))
	assert_eq(int(ok["car"]["fail"]) + int(ok["sign"]["fail"]), 0, "ausgeliefertes Gelände: kein Verstoß in der Kurve")
	# the same bend with careless ground: 8 m high from 5 m beyond the shoulder on the inside (right)
	var rows: Dictionary = (terr_b["rows"] as Dictionary).duplicate()
	var h: PackedFloat32Array = (rows["h"] as PackedFloat32Array).duplicate()
	var rings := int(rows["rings"])
	for row in m:
		for i in range(1, rings):
			h[(row * 2 + 1) * rings + i] = 8.0
	rows["h"] = h
	var bad_terr := {"terrain": terr_b["terrain"], "rows": rows}
	var bad := Fair.scan_crests(bend, bad_terr, proj, prof_b, seen)
	assert_true(int(bad["car"]["later"]) >= 3, "erhöhtes Gelände innen: Modern sieht Fahrzeuge später (%d Ziele)" % int(bad["car"]["later"]))
	assert_true(int(bad["car"]["fail"]) >= 1, "und zu spät für den Anhalteweg (%d Verstöße) – F3 schlägt an" % int(bad["car"]["fail"]))
	assert_true(int(Fair.scan_corridor(bend, bad_terr)["violations"]) > 0, "dasselbe Gelände verletzt auch F7")
	assert_eq(int(Fair.scan_corridor(bend, terr_b)["violations"]), 0, "das ausgelieferte nicht")
	# the design study's ground (road height up to 100 m, 0.8 R inside) is available for comparison
	var study := Fair.scan_crests(bend, terr_b, proj, prof_b, seen, {"study_ribbon_m": 100.0})
	assert_eq(int(study["car"]["fail"]), 0, "Gelände der Entwurfsstudie: kein Verstoß")
