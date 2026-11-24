extends TestCase
## RoadPath3D (kernel of the mode "Modern"): integration against the closed form, coordinates, floating origin,
## trimming, valley floor and clearance on synthetic tracks, forced generation of a real track.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const R1 := 120.0


func _track(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array(), opts: Dictionary = {}) -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, heights, opts)
	return t


func _path(t: Track, start: int = 0) -> RoadPath3D:
	var p := RoadPath3D.new()
	p.setup(t, start, R1)
	return p


## Acceptance: arcs match the closed form (<= 1 cm over 900 m at R = 134 m).
func test_arc_matches_closed_form() -> void:
	for sign_: float in [1.0, -1.0]:
		var radius := 134.0
		var t := _track(SynTrack.arc(304, radius * sign_))
		var p := _path(t)
		p.ensure(300)
		assert_eq(p.last(), 300, "300 Segmente integriert")
		var a := p.arrays(0, 300)
		var xs: PackedFloat64Array = a["x"]
		var zs: PackedFloat64Array = a["z"]
		var hd: PackedFloat64Array = a["heading"]
		var worst := 0.0
		var worst_heading := 0.0
		for k in 301:
			var th := float(k) * 3.0 / radius
			var ex := sign_ * radius * (1.0 - cos(th))
			var ez := -radius * sin(th)
			worst = maxf(worst, Vector2(xs[k] - ex, zs[k] - ez).length())
			worst_heading = maxf(worst_heading, absf(hd[k] - sign_ * th))
		assert_true(worst <= 0.01, "Kreisbogen R = 134 m über 900 m: größte Abweichung %.4f m (<= 0,01 m)" % worst)
		assert_true(worst > 0.0005, "die Mittelpunktsregel weicht messbar ab (%.4f m) – sonst prüft der Test nichts" % worst)
		assert_true(worst_heading < 1.0e-6, "Richtung = Bogenlänge / Radius (Fehler %.9f rad)" % worst_heading)
		# inside a segment the centre lies on the chord: at most the sagitta 3² / (8 · 134) = 8.4 mm from the arc
		var mid_worst := 0.0
		for k in range(0, 300, 7):
			var th := (float(k) + 0.5) * 3.0 / radius
			var c := p.centre_at((float(k) + 0.5) * 3.0)
			mid_worst = maxf(mid_worst, Vector2(c.x - sign_ * radius * (1.0 - cos(th)), c.z + radius * sin(th)).length())
		assert_true(mid_worst <= 0.016, "Segmentmitte höchstens Pfeilhöhe + Randfehler vom Bogen entfernt (%.4f m)" % mid_worst)


func test_coordinates() -> void:
	var heights := SynTrack.grades(64, [[0, 0.0], [10, 0.05]])
	var t := _track(SynTrack.straight(64), heights)
	var p := _path(t)
	assert_eq(RoadPath3D.fwd_of(0.0), Vector3(0, 0, -1), "Richtung 0 blickt entlang -Z")
	assert_eq(RoadPath3D.right_of(0.0), Vector3(1, 0, 0), "rechts = +X")
	assert_true(RoadPath3D.fwd_of(0.3).x > 0.0, "positive Richtung dreht nach rechts")
	var q := p.point(20)
	assert_near(q.x, 0.0, 1.0e-6, "Gerade: x")
	assert_near(q.z, -60.0, 1.0e-5, "Gerade: z = -Weg")
	assert_near(q.y, heights[20], 1.0e-5, "Höhe des Segments")
	var w := p.world(31.5, 4.0, 1.25)
	assert_near(w.x, 4.0, 1.0e-5, "x seitlich nach rechts")
	assert_near(w.z, -31.5, 1.0e-5, "z längs")
	assert_near(w.y, lerpf(heights[10], heights[11], 0.5) + 1.25, 1.0e-5, "Höhe über der Fahrbahn, linear im Segment")
	assert_near(p.height_at(31.5), lerpf(heights[10], heights[11], 0.5), 1.0e-6, "height_at")
	var f := p.frame_at(31.5, 4.0, 1.25)
	assert_true(f.origin.distance_to(w) < 1.0e-6, "frame_at steht auf world()")
	assert_true((f.basis.x - Vector3(1, 0, 0)).length() < 1.0e-6 and (f.basis.y - Vector3.UP).length() < 1.0e-6
		and (-f.basis.z - Vector3(0, 0, -1)).length() < 1.0e-6, "Rahmen: +X rechts, +Y oben, -Z voraus")
	# a right bend moves the road towards +X
	var tr := _track(SynTrack.arc(64, 300.0))
	var pr := _path(tr)
	assert_true(pr.point(60).x > 1.0 and pr.heading(60) > 0.0, "positive Kurve = Rechtskurve")
	var fr := pr.frame_at(150.0)
	assert_true(absf(fr.basis.determinant() - 1.0) < 1.0e-5 and absf(fr.basis.y.y - 1.0) < 1.0e-6, "nur Gieren, keine Neigung")
	assert_true((-fr.basis.z - RoadPath3D.fwd_of(pr.heading_at(150.0))).length() < 1.0e-6, "-Z = Straßenrichtung")


## world() is bilinear between two boundaries – the surface a mesh built from the rows has.
func test_world_is_bilinear_between_rows() -> void:
	var t := _track(SynTrack.arc(64, 150.0), SynTrack.grades(64, [[0, 0.06]]))
	var p := _path(t)
	p.ensure(40)
	for k: int in [3, 17, 30]:
		for x: float in [-9.0, 0.0, 6.5]:
			var a := p.point(k) + RoadPath3D.right_of(p.heading(k)) * x
			var b := p.point(k + 1) + RoadPath3D.right_of(p.heading(k + 1)) * x
			for tt: float in [0.0, 0.25, 0.8]:
				var w := p.world((float(k) + tt) * 3.0, x, 0.0)
				assert_true(w.distance_to(a.lerp(b, tt)) < 1.0e-4, "world() liegt auf der Kante zwischen den Reihen (k %d, x %.1f)" % [k, x])


## Acceptance: rebase keeps positions within 1 mm (floating origin, re-based every 2 km on a 42-km road).
func test_rebase_keeps_positions() -> void:
	var n := 14000
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = 0.35 * sin(float(i) * 0.011) + 0.2 * sin(float(i) * 0.0037)
	var t := _track(curves)
	var p := _path(t)
	# independent reference in doubles
	var rx := PackedFloat64Array()
	var rz := PackedFloat64Array()
	var rt := PackedFloat64Array()
	rx.resize(n)
	rz.resize(n)
	rt.resize(n)
	var x := 0.0
	var z := 0.0
	var a := 0.0
	for i in n:
		rx[i] = x
		rz[i] = z
		rt[i] = a
		var da := float(curves[i]) / R1 * 3.0
		x += sin(a + da * 0.5) * 3.0
		z -= cos(a + da * 0.5) * 3.0
		a += da
	var far := 0.0
	for i in n:
		far = maxf(far, Vector2(rx[i], rz[i]).length())
	assert_true(far > 8000.0, "die Teststrecke entfernt sich weit vom Start (%.0f m)" % far)
	var ox := 0.0
	var oz := 0.0
	var worst := 0.0
	var worst_shift := 0.0
	var rebases := 0
	var cam := 0
	while cam < n - 700:
		p.ensure(cam + 640)
		if p.origin_distance(cam) > 2000.0:
			var probe := cam + 300
			var before := p.point(probe)
			var shift := p.rebase(cam)
			worst_shift = maxf(worst_shift, (p.point(probe) - (before + shift)).length())
			ox = rx[cam]
			oz = rz[cam]
			rebases += 1
			assert_eq(p.origin_index, cam, "Ursprung liegt an der Kamera")
		for k: int in [cam, cam + 150, cam + 633]:
			var q := p.point(k)
			worst = maxf(worst, Vector2(q.x - (rx[k] - ox), q.z - (rz[k] - oz)).length())
			var w := p.world(float(k) * 3.0 + 1.2, 7.5, 0.0)
			var ex := lerpf(rx[k], rx[k + 1], 0.4) - ox + lerpf(cos(rt[k]), cos(rt[k + 1]), 0.4) * 7.5
			var ez := lerpf(rz[k], rz[k + 1], 0.4) - oz + lerpf(sin(rt[k]), sin(rt[k + 1]), 0.4) * 7.5
			worst = maxf(worst, Vector2(w.x - ex, w.z - ez).length())
		cam += 32
	assert_true(rebases >= 5, "mehrfach verlegt (%d)" % rebases)
	assert_true(worst <= 0.001, "mit schwimmendem Ursprung höchstens 1 mm neben der Rechnung in doppelter Genauigkeit (%.5f m)" % worst)
	assert_true(worst_shift <= 0.001, "rebase(): neu = alt + Verschiebung auf 1 mm (%.5f m)" % worst_shift)
	# without re-basing the 32-bit positions are coarser than that far away from the start
	var p2 := _path(t)
	p2.ensure(n - 1)
	var coarse := 0.0
	for k in range(0, n, 97):
		var q := p2.point(k)
		coarse = maxf(coarse, Vector2(q.x - rx[k], q.z - rz[k]).length())
	assert_true(coarse > worst, "ohne Verlegen ist der Fehler größer (%.5f m gegen %.5f m)" % [coarse, worst])


func test_trim_and_window() -> void:
	var t := _track(SynTrack.arc(900, 400.0))
	var p := _path(t)
	p.ensure(800)
	var before := p.point(500)
	var h := p.heading(500)
	p.trim(300)
	assert_eq(p.first, 300, "vorn abgeschnitten")
	assert_eq(p.last(), 800, "Ende bleibt")
	assert_true(p.point(500).distance_to(before) < 1.0e-6, "Positionen bleiben")
	assert_near(p.heading(500), h, 1.0e-9, "Richtung bleibt")
	assert_true(p.point(10).distance_to(p.point(300)) < 1.0e-6, "abgeschnittene Indizes werden auf den ersten geklemmt")
	p.trim(100000)
	assert_true(p.last() - p.first >= 1, "mindestens zwei Grenzen bleiben")
	# a path that starts behind the track window starts at the oldest segment the track still has
	var t2 := _track(SynTrack.straight(900))
	t2.update_window(1500.0, 300.0)
	var oldest := t2.get_segment(0).index
	assert_true(oldest > 300, "das Fenster der Strecke ist hinten abgeschnitten (ältestes Segment %d)" % oldest)
	var p3 := _path(t2, 10)
	assert_eq(p3.first, oldest, "Pfad beginnt am ältesten vorhandenen Segment")
	p3.ensure(oldest + 50)
	assert_eq(p3.last(), oldest + 50, "und lässt sich von dort integrieren")
	assert_near(p3.point(oldest + 50).z, -150.0, 1.0e-4, "relativ zu seinem Anfang")


## Acceptance: floor_y on synthetic tracks.
func test_floor_y() -> void:
	# a valley: 400 segments down with 5 %, 400 up with 5 % (lowest point at boundary 400, y = -60)
	var n := 1200
	var heights := SynTrack.grades(n, [[0, -0.05], [400, 0.05], [800, 0.0]])
	var t := _track(SynTrack.straight(n), heights)
	var p := _path(t)
	assert_near(p.floor_y(400), -60.0 - 4.5, 1.0e-4, "Talsohle: tiefste Fahrbahn - 4,5 m")
	assert_near(p.floor_y(250), -60.0 - 4.5, 1.0e-4, "150 Segmente davor liegt die Sohle noch im Fenster (±900 m)")
	assert_near(p.floor_y(99), heights[399] - 4.5, 1.0e-4, "Fenster endet 300 Segmente weiter")
	assert_near(p.floor_y(0), heights[300] - 4.5, 1.0e-4, "am Anfang nur nach vorn")
	assert_near(p.floor_y(1000), heights[700] - 4.5, 1.0e-4, "dahinter: tiefster Punkt 900 m zurück")
	assert_near(p.floor_y(n - 1), 0.0 - 4.5, 1.0e-4, "auf der Ebene am Ende: eigene Höhe - 4,5 m")
	for k in range(0, n, 13):
		assert_true(p.floor_y(k) <= p.height(k) - 4.5 + 1.0e-6, "die Talsohle liegt nie über der Fahrbahn - 4,5 m (k %d)" % k)
	# other window and drop
	p.floor_window_m = 300.0
	p.floor_drop_m = 2.0
	assert_near(p.floor_y(250), heights[350] - 2.0, 1.0e-4, "Fenster ±300 m, 2 m tiefer")
	# floor_rows() = floor_y() per row, also across a trimmed start
	p.floor_window_m = 900.0
	p.floor_drop_m = 4.5
	for range_: Array in [[0, 64], [380, 420], [1100, 1199]]:
		var rows := p.floor_rows(range_[0], range_[1])
		for q in rows.size():
			assert_eq(rows[q], p.floor_y(int(range_[0]) + q), "floor_rows = floor_y (Reihe %d)" % (int(range_[0]) + q))
	p.trim(500)
	var rows2 := p.floor_rows(560, 600)
	for q in rows2.size():
		assert_eq(rows2[q], p.floor_y(560 + q), "nach trim() gleich (Reihe %d)" % (560 + q))
	assert_near(p.floor_y(560), heights[500] - 4.5, 1.0e-4, "hinter dem Schnitt zählt nur, was noch geladen ist")


## Acceptance: clearance on synthetic tracks. A U-turn: 600 m straight, half a circle with R = 150 m to the right,
## 600 m straight back – the two legs run 300 m apart.
func test_clearance_u_turn() -> void:
	var arc_n := int(round(PI * 150.0 / 3.0))
	var t := _track(SynTrack.join([SynTrack.straight(200), SynTrack.arc(arc_n, 150.0), SynTrack.straight(260)]))
	var p := _path(t)
	p.clear_reach_m = 1900.0
	# leg 1, 300 m before the bend: the other leg lies 300 m to the right -> medial axis half way
	assert_near(p.clearance(96, 1), 150.0, 1.5, "Innenseite des ersten Schenkels: halber Abstand zum zweiten")
	assert_eq(p.clearance(96, -1), p.clear_max_m, "Außenseite frei")
	# in the bend: the cross-sections meet in the centre
	var mid := 200 + arc_n / 2
	mid = (mid / 8) * 8
	assert_near(p.clearance(mid, 1), 150.0, 1.5, "Kurveninnenseite: Radius")
	assert_eq(p.clearance(mid, -1), p.clear_max_m, "Kurvenaußenseite frei")
	# leg 2 sees leg 1
	var k2 := ((200 + arc_n + 96) / 8) * 8
	assert_near(p.clearance(k2, 1), 150.0, 1.5, "zweiter Schenkel: halber Abstand zum ersten")
	# rows between the coarse rows are interpolated
	var c0 := p.clearance(96, 1)
	var c1 := p.clearance(104, 1)
	assert_near(p.clearance(99, 1), lerpf(c0, c1, 3.0 / 8.0), 1.0e-6, "zwischen den Stützreihen linear")
	# what is farther than clear_reach_m of path does not count
	var p2 := _path(t)
	p2.clear_reach_m = 300.0
	assert_eq(p2.clearance(96, 1), p2.clear_max_m, "außerhalb der Reichweite (300 m Weg) zählt der andere Schenkel nicht")
	# a pure function of the road: the same value from a path that started elsewhere and was extended differently
	var p3 := _path(t, 40)
	p3.clear_reach_m = 1900.0
	p3.ensure(120)
	assert_near(p3.clearance(k2, 1), p.clearance(k2, 1), 1.0e-6, "gleiche Reihe, gleicher Wert (anderer Pfadanfang im Fenster)")
	# straight road: nothing near
	var ts := _track(SynTrack.straight(900))
	var ps := _path(ts)
	assert_eq(ps.clearance(304, 1), ps.clear_max_m, "Gerade: frei rechts")
	assert_eq(ps.clearance(304, -1), ps.clear_max_m, "Gerade: frei links")


## A tightening bend: before the tight part the free width is what the tight part leaves, not the local radius.
func test_clearance_before_a_tight_bend() -> void:
	var t := _track(SynTrack.join([SynTrack.arc(120, 2000.0), SynTrack.arc(60, 134.0), SynTrack.straight(300)]))
	var p := _path(t)
	var c := p.clearance(88, 1)
	assert_between(c, 200.0, 340.0, "vor der engen Kurve begrenzen ihr Bogen und die Gerade dahinter die Innenseite (%.0f m), nicht 0,8 × 2000 m" % c)
	var inside := p.clearance(152, 1)
	assert_between(inside, 125.0, 150.0, "in der engen Kurve etwa ihr Radius")
	assert_eq(p.clearance(152, -1), p.clear_max_m, "ihre Außenseite ist frei")


## ensure() forces the generation of the real track ahead (contract D3) – the generated road is the same as when it
## is generated step by step like in Arcade.
func test_forced_generation_keeps_the_track() -> void:
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var scenery: Dictionary = (ConfigLoader.load_json("res://data/scenery.json") as Dictionary).get("scenery", {})
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var stage := {}
	for s: Dictionary in net.get("stages", []):
		if str(s["id"]) == "saragossa_pau":
			stage = s
	assert_false(stage.is_empty(), "Etappe saragossa_pau vorhanden")
	if stage.is_empty():
		return
	var plan := StagePlan.build(stage, str(stage["from"]), cities, countries, cfg())
	var a := Track.new()
	a.setup(plan, cfg(), scenery)
	var b := Track.new()
	b.setup(plan, cfg(), scenery)
	var p := _path(a)
	p.ensure(1400)                       # 4.2 km at once, far ahead of any camera
	assert_true(a.window_size() >= 1400, "die Strecke wurde bis dorthin erzeugt")
	var cam := 0.0
	while cam < 2400.0:                  # Arcade: window of 960 m ahead of the camera, cut behind it
		b.update_window(cam, 960.0)
		cam += 45.0
	var checked := 0
	for i in range(b.segment_index_at(cam - 45.0) - 60, b.segment_index_at(cam - 45.0 + 900.0)):
		var sa := a.get_segment(i)
		var sb := b.get_segment(i)
		assert_eq(sb.index, i, "Segment %d im Arcade-Fenster" % i)
		if sa.curve != sb.curve or sa.y != sb.y or JSON.stringify(sa.sprites) != JSON.stringify(sb.sprites) or sa.lanes != sb.lanes:
			fail("Segment %d unterscheidet sich zwischen vorausgezwungener und schrittweiser Erzeugung" % i)
		checked += 1
	assert_true(checked > 300, "%d Segmente verglichen" % checked)
