extends TestCase
## SightCorridor (kernel of the mode "Modern", contract A-17): the sight corridor of bends as the envelope of the real
## sight lines – checked against an exhaustive reference (every camera row, every lane centre, every target row and
## lane centre, every crossing of every sight line with every cross-section) on the five shapes of A-17: a long arc,
## a short arc, a straight before a bend, an S-bend and a mountain hairpin; the F2 need against
## tests/race3d/fairness.gd speed_profile(); order independence; the corridor TerrainProfile builds from it.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
## The kernel may stand this much wider than the exact envelope (beyond a quarter turn both outermost lines count on both
## sides – conservative in hairpins).
const TIGHT_M := 2.6


## [track, path, terrain, sight] of a synthetic road.
func _make(curves: PackedFloat32Array, opts: Dictionary = {}, terrain_cfg: Dictionary = {}) -> Array:
	var t: Track = SynTrack.new()
	var o := {"lanes": 2.0, "road": "landstrasse"}
	o.merge(opts, true)
	t.fill(cfg(), curves, PackedFloat32Array(), o)
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, terrain_cfg, {})
	return [t, p, tp, tp.sight]


## Lane centres of row k (signed lateral offsets), fuel lane included (Track.fuel_lane_x(): also in its taper).
static func _lanes(t: Track, k: int) -> PackedFloat32Array:
	var s := t.get_segment(maxi(k, 0))
	var half := s.lanes * t.lane_w * 0.5
	var out := PackedFloat32Array()
	for i in int(ceil(s.lanes - 1.0e-4)):
		out.append(minf(-half + t.lane_w * (float(i) + 0.5), half - t.lane_w * 0.5))
	if s.fuel_lane > 0.0:
		out.append(half + t.lane_w * 0.5)
	return out


## Exhaustive reference of the rows j0..j1: [left, right] metres beyond the shoulder edge (NONE where no sight line
## leaves the road). Cameras a0..a1 (every row), every lane centre; targets every row up to L(a) and the exact end;
## every crossing of the segment camera–target (parameter 0..1) with the cross-section of every row in between;
## the same limits as the kernel (MAX_TURN, medial axis).
static func _brute(t: Track, p: RoadPath3D, sc: SightCorridor, a0: int, a1: int, j0: int, j1: int) -> Array:
	var cnt := j1 - j0 + 1
	var wl := PackedFloat32Array()
	var wr := PackedFloat32Array()
	wl.resize(cnt)
	wr.resize(cnt)
	wl.fill(SightCorridor.NONE)
	wr.fill(SightCorridor.NONE)
	var seg := t.seg_len
	for a in range(a0, a1 + 1):
		var L := sc.chord_at(a)
		var n := L / seg
		var th_a := p.heading(a)
		var pa := p.point(a)
		var ra := RoadPath3D.right_of(th_a)
		var cams := _lanes(t, a)
		# targets: every row up to floor(n) and the exact end
		var tg: Array = []
		for d in range(1, int(floor(n)) + 1):
			tg.append([a + d, 0.0])
		if n - floor(n) > 1.0e-4:
			tg.append([a + int(floor(n)), n - floor(n)])
		for e: Array in tg:
			var b := int(e[0])
			var f := float(e[1])
			var th_b := lerpf(p.heading(b), p.heading(b + 1), f)
			if absf(th_b - th_a) > SightCorridor.MAX_TURN:
				continue
			var pb := p.point(b).lerp(p.point(b + 1), f)
			var rb := RoadPath3D.right_of(th_b)
			var tls := _lanes(t, b)
			for cl in cams:
				var c := pa + ra * cl
				for tl in tls:
					var tp := pb + rb * tl
					var u := tp - c
					for j in range(maxi(a + 1, j0), mini(b + (1 if f > 0.0 else 0), j1 + 1)):
						var pj := p.point(j)
						var rj := RoadPath3D.right_of(p.heading(j))
						# c + s u = pj + x rj
						var den := u.x * rj.z - u.z * rj.x
						if absf(den) < 1.0e-9:
							continue
						var dx := pj.x - c.x
						var dz := pj.z - c.z
						var s := (dx * rj.z - dz * rj.x) / den
						if s < 0.0 or s > 1.0:
							continue
						var x := (dx * u.z - dz * u.x) / den
						var sj := t.get_segment(j)
						var half := sj.lanes * t.lane_w * 0.5
						var q := j - j0
						if x > 0.0:
							var w := minf(x, p.clearance(j, 1)) - (half + sj.fuel_lane * t.lane_w + t.shoulder_w)
							wr[q] = maxf(wr[q], w)
						else:
							var w2 := minf(-x, p.clearance(j, -1)) - (half + t.shoulder_w)
							wl[q] = maxf(wl[q], w2)
	return [wl, wr]


## Kernel against the reference on rows j0..j1: never narrower (coverage), at most TIGHT_M wider where a sight line
## leaves the road. Returns {max_short, max_over, rows_bend}.
func _compare(m: Array, j0: int, j1: int, label: String) -> Dictionary:
	var t: Track = m[0]
	var p: RoadPath3D = m[1]
	var sc: SightCorridor = m[3]
	var nb := int(ceil(sc.chord_max_m / t.seg_len)) + 2
	var ref := _brute(t, p, sc, maxi(j0 - nb, 0), j1, j0, j1)
	var short := 0.0
	var over := 0.0
	var bend := 0
	var bad := 0
	for si in 2:
		var side := -1 if si == 0 else 1
		var r: PackedFloat32Array = ref[si]
		for j in range(j0, j1 + 1):
			var want := r[j - j0]
			var got := sc.width(j, side)
			if want > 0.0:
				bend += 1
				short = maxf(short, want - got)
				over = maxf(over, got - want)
				if got < want - 1.0e-3 and bad < 4:
					bad += 1
					fail("%s: Reihe %d Seite %d – Korridor %.2f m schmaler als die Sichtlinien (%.2f m)" % [label, j, side, got, want])
			elif got > TIGHT_M and want < -1.0:
				over = maxf(over, got - maxf(want, 0.0))
	assert_true(bend > 0, "%s: es gibt Sichtlinien jenseits des Banketts" % label)
	assert_true(short <= 1.0e-3, "%s: der Korridor deckt jede Sichtlinie (größter Fehlbetrag %.3f m)" % [label, short])
	assert_true(over <= TIGHT_M, "%s: höchstens %.1f m breiter als nötig (%.2f m)" % [label, TIGHT_M, over])
	return {"short": short, "over": over, "bend": bend}


## Sagitta beyond the shoulder of a chord between the inner lane centres of an arc (path length L along the centre).
static func _arc_width(radius: float, chord_m: float, inner_lane: float, edge_from_lane: float) -> float:
	var r_in := radius - inner_lane
	return r_in * (1.0 - cos(chord_m / radius * 0.5)) - edge_from_lane


func test_long_arc() -> void:
	var m := _make(SynTrack.join([SynTrack.straight(150), SynTrack.arc(400, 250.0), SynTrack.straight(150)]))
	var sc: SightCorridor = m[3]
	var tp: TerrainProfile = m[2]
	_compare(m, 230, 470, "langer Bogen")
	# in the middle: the sagitta of the chord L between the inner lane centres
	var L := sc.chord_at(350 - 20)
	assert_between(L, 100.0, 300.0, "L aus dem F2-Bedarf (%.0f m)" % L)
	var want := _arc_width(250.0, L, 1.875, 1.875 + 2.5)
	assert_near(sc.width(350, 1), want + SightCorridor.MARGIN_M, 0.45, "Mitte des Bogens: Pfeilhöhe der Sehne %.0f m (%.1f m)" % [L, want])
	assert_true(sc.width(350, -1) <= 0.0, "außen keine Sichtlinie jenseits des Banketts")
	assert_near(tp.corridor_width(350, 1), maxf(sc.width(350, 1), 5.5 + TerrainProfile.BEND_FLOOR_M), 1.0e-4, "TerrainProfile übernimmt die Hülle")
	assert_near(tp.corridor_width(350, -1), 5.5, 1.0e-4, "außen der schlichte Streifen (8 m ab Fahrbahnrand)")
	# the band runs out after the bend: a straight more than L behind the bend's end is free
	assert_true(sc.width(550 + int(ceil(L / 3.0)) + 4, 1) <= 0.0, "hinter dem Bogen läuft das Band aus")
	assert_near(tp.corridor_width(550 + int(ceil(L / 3.0)) + 4, 1), 5.5, 1.0e-4, "dort wieder der schlichte Streifen")


func test_short_arc() -> void:
	var m := _make(SynTrack.join([SynTrack.straight(200), SynTrack.arc(20, 150.0), SynTrack.straight(200)]))
	var sc: SightCorridor = m[3]
	_compare(m, 120, 300, "kurzer Bogen")
	var L := sc.chord_at(170)
	var apex := sc.width(210, 1)
	var own := 60.0 * 60.0 / (8.0 * 150.0) - 4.375          # the sagitta of the arc itself (60 m) beyond the shoulder
	var old_band := L * L / (8.0 * (150.0 - 3.75)) - 2.5     # the constant band of the old rule with this L
	assert_true(apex > own, "die Sichtlinien von den Geraden schneiden die Ecke: %.1f m > eigene Pfeilhöhe %.1f m" % [apex, own])
	assert_true(apex < old_band * 0.5, "aber weit schmaler als das alte Band mit dieser Sehne (%.1f m < %.1f m)" % [apex, old_band])


func test_straight_before_a_bend() -> void:
	var m := _make(SynTrack.join([SynTrack.straight(300), SynTrack.arc(200, 200.0), SynTrack.straight(150)]))
	var sc: SightCorridor = m[3]
	_compare(m, 180, 420, "Gerade vor der Kurve")
	var L := sc.chord_at(250)
	var free_to := 300 - int(ceil(L / 3.0)) - 2
	for j in range(100, free_to, 6):
		if sc.width(j, 1) > 0.0:
			fail("Reihe %d, %.0f m vor der Kurve: Korridor %.2f m – mehr als eine Sehne vor der Kurve ist frei" % [j, float(300 - j) * 3.0, sc.width(j, 1)])
			break
	assert_true(sc.width(300, 1) > 5.0, "am Kurvenbeginn kreuzen die Sichtlinien in die Kurve (%.1f m)" % sc.width(300, 1))
	assert_true(sc.width(285, 1) < sc.width(300, 1), "davor schmaler (%.1f < %.1f m)" % [sc.width(285, 1), sc.width(300, 1)])


func test_s_bend() -> void:
	var m := _make(SynTrack.join([SynTrack.straight(150), SynTrack.arc(80, 200.0), SynTrack.arc(80, -200.0), SynTrack.straight(150)]))
	var sc: SightCorridor = m[3]
	_compare(m, 120, 360, "S-Kurve")
	assert_true(sc.width(190, 1) > 0.0 and sc.width(190, 1) > sc.width(190, -1), "erste Hälfte: innen rechts")
	assert_true(sc.width(270, -1) > 0.0 and sc.width(270, -1) > sc.width(270, 1), "zweite Hälfte: innen links")


## A hairpin between two bends of a climb (the approach is as slow as the bends): L is the short F2 need of a slow
## mountain bend and the corridor the sagitta of that chord, not of 300 m.
func test_mountain_hairpin() -> void:
	var arc_n := int(round(PI * 0.85 * 90.0 / 3.0))
	var m := _make(SynTrack.join([SynTrack.straight(40), SynTrack.arc(30, 90.0), SynTrack.straight(8), SynTrack.arc(arc_n, -90.0),
		SynTrack.straight(8), SynTrack.arc(30, 90.0), SynTrack.straight(80)]))
	var sc: SightCorridor = m[3]
	var h0 := 40 + 30 + 8
	var r := _compare(m, h0 - 20, h0 + arc_n + 20, "Kehre")
	var mid := h0 + arc_n / 2
	var L := sc.chord_at(mid - 15)
	assert_between(L, 80.0, 140.0, "langsame Bergkurve: kurze Sehne aus dem F2-Bedarf (%.0f m)" % L)
	var want := _arc_width(90.0, L, 1.875, 4.375)
	assert_near(sc.width(mid, -1), want + SightCorridor.MARGIN_M, 0.6, "Scheitel: Pfeilhöhe der Sehne %.0f m (%.1f m)" % [L, want])
	assert_true(sc.width(mid, -1) < 300.0 * 300.0 / (8.0 * 90.0) * 0.25, "weit schmaler als das alte 300-m-Band")
	assert_true(int(r["bend"]) > 0, "Kehre mit Sichtlinien jenseits des Banketts")


## Three lanes and a fuel lane: the camera and the targets in every lane are covered by the outermost lane centres.
func test_every_lane() -> void:
	var m := _make(SynTrack.join([SynTrack.straight(150), SynTrack.arc(120, 300.0), SynTrack.straight(100)]),
		{"lanes": 3.0, "road": "autobahn", "fuel_lane": [150, 200]})
	_compare(m, 150, 260, "drei Spuren und Tankspur")


## The F2 need is the one of fairness.speed_profile() (the largest of dry, rain and snow) at every row.
func test_need_is_the_f2_need() -> void:
	var curves := PackedFloat32Array()
	curves.resize(1400)
	for i in curves.size():
		curves[i] = clampf(0.9 * sin(float(i) * 0.011) + 0.4 * sin(float(i) * 0.037), -1.2, 1.2)
	var m := _make(curves)
	var t: Track = m[0]
	var sc: SightCorridor = m[3]
	var geo := Fair.geo_of_track(cfg(), t)
	var envs := Fair.envelopes(cfg())
	var worst := 0.0
	var profiles: Array = []
	for w: String in Fair.WEATHERS:
		profiles.append(Fair.speed_profile(geo, envs[w]))
	for k in range(0, int(geo["n"])):
		var want := 0.0
		for pr: Dictionary in profiles:
			want = maxf(want, float((pr["need"] as PackedFloat64Array)[k]))
		worst = maxf(worst, absf(sc.need_at(k) - want))
	assert_true(worst < 0.05, "Anhalteweg wie fairness.speed_profile() (größte Abweichung %.4f m)" % worst)
	assert_near(sc.chord_at(500), minf(300.0, sc.need_at(503) / 0.6 + 9.0), 1.0e-4, "L = min(300 m, Bedarf am Wagen / 0,6 + Kamera)")


## A pure function of the road: asked backwards, in pieces, after a trim – the same numbers.
func test_order_independent() -> void:
	var curves := SynTrack.join([SynTrack.straight(100), SynTrack.arc(90, 160.0), SynTrack.straight(60), SynTrack.arc(70, -110.0), SynTrack.straight(200)])
	var a := _make(curves)
	var b := _make(curves)
	var sa: SightCorridor = a[3]
	var sb: SightCorridor = b[3]
	var fwd: Array[float] = []
	for j in range(0, 480):
		fwd.append(sa.width(j, 1))
		fwd.append(sa.width(j, -1))
	var diff := 0
	for j in range(479, -1, -1):
		if absf(sb.width(j, 1) - fwd[j * 2]) > 1.0e-6 or absf(sb.width(j, -1) - fwd[j * 2 + 1]) > 1.0e-6:
			diff += 1
	assert_eq(diff, 0, "rückwärts gefragt: dieselben Werte")
	sb.trim(200)
	var diff2 := 0
	for j in range(200, 480):
		if absf(sb.width(j, 1) - fwd[j * 2]) > 1.0e-6:
			diff2 += 1
	assert_eq(diff2, 0, "nach trim(): dieselben Werte")
	sb.trim(1 << 40)
	assert_near(sb.width(300, 1), fwd[600], 1.0e-6, "nach dem Zurücksetzen: neu gerechnet, dieselben Werte")
	assert_true(sa.cameras > 0 and sa.usec >= 0, "Messwerte")
