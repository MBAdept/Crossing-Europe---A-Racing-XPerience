extends TestCase
## TerrainProfile (kernel of the mode "Modern"): ring distances and their cuts (inside of bends, medial axis), verge
## and ditch, relief, valley floor, water, the sight corridor (fairness rule F7) and its check.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
const EDGE_3 := 3.0 * 3.75 * 0.5 + 2.5      ## shoulder edge of a three-lane road from its centre


## [track, path, terrain] of a synthetic road.
func _make(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array(), opts: Dictionary = {}, terrain_cfg: Dictionary = {}) -> Array:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, heights, opts)
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, terrain_cfg, {})
	return [t, p, tp]


func _near_array(a: PackedFloat32Array, b: Array, eps: float, msg: String) -> void:
	assert_eq(a.size(), b.size(), msg + ": Anzahl")
	for i in mini(a.size(), b.size()):
		assert_near(a[i], float(b[i]), eps, "%s [%d]" % [msg, i])


func test_straight_profile() -> void:
	var m := _make(SynTrack.straight(700), PackedFloat32Array(), {}, {"relief_m": 0.0})
	var tp: TerrainProfile = m[2]
	assert_eq(tp.ring_count(), 7, "sieben Ringe")
	for side: int in [-1, 1]:
		assert_near(tp.edge(300, side), EDGE_3, 1.0e-4, "Bankettkante: halbe Fahrbahn + Bankett")
		_near_array(tp.ring_offsets(300, side), [0.0, 5.0, 15.0, 40.0, 100.0, 220.0, 480.0], 1.0e-3, "Ringabstände der Geraden")
		_near_array(tp.ring_heights(300, side), [0.0, -0.35, -0.6, -1.1, -2.6, -4.0, -4.5], 1.0e-3, "Bankett, Graben, Talsohle")
		assert_near(tp.limit(300, side), 480.0, 1.0e-3, "Bandbreite = äußerer Ring")
		assert_near(tp.corridor_width(300, side), 8.0 - 2.5, 1.0e-3, "Sichtkorridor der Geraden: 8 m ab Fahrbahnrand")
		assert_near(tp.height(300, side, 10.0), -0.475, 1.0e-3, "zwischen zwei Ringen linear")
		assert_near(tp.height(300, side, -3.0), 0.0, 1.0e-6, "auf dem Bankett: Fahrbahnniveau")
		assert_near(tp.height(300, side, 2000.0), -4.5, 1.0e-3, "jenseits des Bandes: Talsohle")
	assert_near(TerrainProfile.interp(PackedFloat32Array([0.0, 10.0, 30.0]), 0, PackedFloat32Array([0.0, -1.0, 3.0]), 0, 3, 20.0), 1.0, 1.0e-6, "interp()")
	# a fuel lane widens the road to the right only
	var f := _make(SynTrack.straight(200), PackedFloat32Array(), {"fuel_lane": [50, 150]}, {"relief_m": 0.0})
	assert_near((f[2] as TerrainProfile).edge(100, 1), EDGE_3 + 3.75, 1.0e-4, "Tankspur verbreitert rechts")
	assert_near((f[2] as TerrainProfile).edge(100, -1), EDGE_3, 1.0e-4, "links unverändert")


func test_inside_of_a_bend_is_cut() -> void:
	var m := _make(SynTrack.arc(400, 150.0), PackedFloat32Array(), {}, {"relief_m": 0.0})
	var tp: TerrainProfile = m[2]
	var k := 200
	assert_near(tp.limit(k, 1), 0.8 * 150.0 - EDGE_3, 0.05, "Kurveninnenseite: 0,8 × Radius ab Straßenmitte")
	assert_near(tp.limit(k, -1), 480.0, 1.0e-3, "Kurvenaußenseite ungekürzt")
	var x := tp.ring_offsets(k, 1)
	var h := tp.ring_heights(k, 1)
	assert_near(x[1], 5.0, 1.0e-3, "innere Ringe bleiben, wo sie passen (5 m)")
	assert_near(x[2], 15.0, 1.0e-3, "(15 m)")
	assert_near(x[6], tp.limit(k, 1), 1.0e-4, "letzter Ring am Bandende")
	for i in range(1, 7):
		assert_true(x[i] > x[i - 1] + 0.5, "Ringe streng aufsteigend (%d: %.2f > %.2f)" % [i, x[i], x[i - 1]])
		assert_true(x[i] <= tp.rings[i] + 1.0e-4, "nie weiter außen als ungekürzt")
	assert_true(x[5] <= 0.76 * x[6], "der letzte Ring behält Platz zum Abfallen (%.1f von %.1f m)" % [x[5], x[6]])
	assert_near(h[6], -4.5, 1.0e-3, "Bandende auf der Talsohle")
	# a tighter factor from the configuration
	var m2 := _make(SynTrack.arc(400, 150.0), PackedFloat32Array(), {}, {"relief_m": 0.0, "inside_bend_factor": 0.5})
	assert_near((m2[2] as TerrainProfile).limit(200, 1), 0.5 * 150.0 - EDGE_3, 0.05, "inside_bend_factor aus der Konfiguration")


## Two legs of a U-turn 300 m apart: each ribbon ends before the middle between them.
func test_medial_axis_cut() -> void:
	var arc_n := int(round(PI * 150.0 / 3.0))
	var m := _make(SynTrack.join([SynTrack.straight(200), SynTrack.arc(arc_n, 150.0), SynTrack.straight(260)]), PackedFloat32Array(), {}, {"relief_m": 0.0})
	var p: RoadPath3D = m[1]
	var tp: TerrainProfile = m[2]
	assert_near(tp.limit(96, 1), 150.0 - tp.clear_margin_m - EDGE_3, 1.6, "Innenseite: Mittelachse - Sicherheitsabstand - Straßenrand")
	assert_near(tp.limit(96, -1), 480.0, 1.0e-3, "Außenseite ungekürzt")
	var k2 := ((200 + arc_n + 96) / 8) * 8
	assert_true(tp.limit(96, 1) + EDGE_3 + tp.limit(k2, 1) + EDGE_3 < 300.0 - 2.0 * tp.clear_margin_m + 3.5,
		"die Bänder der beiden Schenkel überlappen sich nicht (%.1f + %.1f m bei 300 m Abstand)" % [tp.limit(96, 1) + EDGE_3, tp.limit(k2, 1) + EDGE_3])
	assert_true(p.clearance(96, 1) < 152.0, "clearance() ist die Mittelachse")
	# "Details: Hoch": the outer ring goes to 1,000 m where nothing is near
	var s := _make(SynTrack.straight(900), PackedFloat32Array(), {}, {"relief_m": 0.0})
	(s[2] as TerrainProfile).set_outer_ring(1000.0)
	assert_near((s[2] as TerrainProfile).limit(304, 1), 1000.0, 1.0e-3, "äußerer Ring 1.000 m auf freier Strecke")
	assert_near((s[2] as TerrainProfile).ring_offsets(304, -1)[6], 1000.0, 1.0e-3, "(links)")
	assert_near((s[2] as TerrainProfile).ring_offsets(304, -1)[5], 220.0, 1.0e-3, "die inneren Ringe bleiben")


func test_sight_corridor() -> void:
	# two-lane road: 300 straight, 300 segments of a right bend with R = 134 m, straight
	var m := _make(SynTrack.join([SynTrack.straight(300), SynTrack.arc(300, 134.0), SynTrack.straight(300)]), PackedFloat32Array(),
		{"lanes": 2.0, "road": "landstrasse"}, {"relief_m": 0.0})
	var tp: TerrainProfile = m[2]
	var half := 3.75
	var want := 300.0 * 300.0 / 8.0 / (134.0 - half) - 2.5
	assert_near(tp.corridor_width(448, 1), want, 0.3, "Kurveninnenseite: Pfeilhöhe einer 300-m-Sehne am Innenrand (%.1f m ab Bankett)" % want)
	assert_near(tp.corridor_width(448, -1), 5.5, 1.0e-3, "Kurvenaußenseite: 8 m ab Fahrbahnrand")
	assert_near(tp.corridor_width(100, 1), 5.5, 1.0e-3, "weit vor der Kurve: 8 m ab Fahrbahnrand")
	assert_near(tp.corridor_width(272, 1), want, 0.3, "84 m vor der Kurve gilt schon ihr Korridor (halbe Sehne voraus)")
	assert_near(tp.corridor_width(632, 1), want, 0.3, "und 96 m dahinter noch")
	assert_near(tp.corridor_width(720, 1), 5.5, 1.0e-3, "360 m dahinter nicht mehr")
	# the corridor is narrower than the cut ribbon of the same bend, so ground exists beyond it
	assert_true(tp.corridor_width(448, 1) < tp.limit(448, 1), "Korridor %.1f m < Band %.1f m" % [tp.corridor_width(448, 1), tp.limit(448, 1)])
	# other chord and minimum from the configuration
	var m2 := _make(SynTrack.arc(400, 400.0), PackedFloat32Array(), {}, {"corridor_chord_m": 200.0, "corridor_min_m": 12.0})
	var tp2: TerrainProfile = m2[2]
	assert_near(tp2.corridor_width(200, 1), maxf(12.0, 200.0 * 200.0 / 8.0 / (400.0 - 5.625)) - 2.5, 0.1, "Sehne 200 m, mindestens 12 m")
	assert_near(tp2.corridor_width(200, -1), 12.0 - 2.5, 1.0e-3, "Mindestkorridor außen")


## Fairness rule F7: inside the sight corridor the ground is never above the road – also with a strong relief.
func test_never_above_the_road_inside_the_corridor() -> void:
	var n := 2400
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = clampf(0.75 * sin(float(i) * 0.013) + 0.3 * sin(float(i) * 0.0041 + 0.7), -0.9, 0.9)
	var heights := SynTrack.grades(n, [[0, 0.04], [300, -0.07], [700, 0.02], [1200, -0.03], [1800, 0.06]])
	var m := _make(curves, heights, {"hills": 3, "lanes": 2.0}, {"relief_m": 12.0})
	var tp: TerrainProfile = m[2]
	var highest := -INF
	var raised_rows := 0
	for k in range(30, n - 40, 3):
		for side: int in [-1, 1]:
			var corr := tp.corridor_width(k, side)
			var x := 0.0
			while x <= corr:
				var h := tp.height(k, side, x)
				if h > 1.0e-5:
					fail("Reihe %d Seite %d: Gelände %.3f m über der Fahrbahn bei %.1f m (Korridor %.1f m)" % [k, side, h, x, corr])
					return
				x += 0.5
			assert_true(tp.height(k, side, corr) <= 1.0e-5, "am Korridorrand nicht über der Fahrbahn")
			var hs := tp.ring_heights(k, side)
			var any := false
			for v in hs:
				highest = maxf(highest, v)
				any = any or v > 0.0
			if any:
				raised_rows += 1
			assert_true(hs[6] <= -4.5 + 1.0e-4, "Bandende auf der Talsohle (höchstens Fahrbahn - 4,5 m)")
	assert_true(highest > 3.0, "außerhalb des Korridors gibt es Relief über Fahrbahnniveau (bis %.1f m)" % highest)
	assert_true(raised_rows > 100, "an vielen Querschnitten (%d)" % raised_rows)
	# the network check finds nothing here …
	var geo := Fair.geo_of_track(cfg(), m[0], "test")
	var terr := {"terrain": tp, "rows": tp.rows(0, n - 1)}
	var res := Fair.scan_corridor(geo, terr)
	assert_eq(int(res["violations"]), 0, "scan_corridor: keine Verstöße")
	assert_eq(int(res["rows"]), n, "alle Reihen geprüft")
	assert_true(float(res["max_height_m"]) > 3.0, "scan_corridor sieht das Relief")
	# … and does find a ring that is raised inside the corridor
	var rows: Dictionary = terr["rows"]
	var hh: PackedFloat32Array = rows["h"]
	hh[(500 * 2 + 1) * 7 + 2] = 0.4
	rows["h"] = hh
	assert_true(int(Fair.scan_corridor(geo, terr)["violations"]) >= 1, "scan_corridor meldet erhöhtes Gelände im Korridor")


func test_relief_rules() -> void:
	var n := 1500
	var flat := _make(SynTrack.straight(n), PackedFloat32Array(), {"hills": 0}, {})
	var hilly := _make(SynTrack.straight(n), PackedFloat32Array(), {"hills": 3}, {})
	var none := _make(SynTrack.straight(n), PackedFloat32Array(), {"hills": 3}, {"relief_m": 0.0})
	var sum_flat := 0.0
	var sum_hilly := 0.0
	var max_hilly := 0.0
	for k in range(100, n - 100, 5):
		for side: int in [-1, 1]:
			var b := (none[2] as TerrainProfile).ring_heights(k, side)
			var f := (flat[2] as TerrainProfile).ring_heights(k, side)
			var h := (hilly[2] as TerrainProfile).ring_heights(k, side)
			for i in 7:
				assert_true(f[i] >= b[i] - 1.0e-5 and h[i] >= b[i] - 1.0e-5, "Relief hebt nur an")
				sum_flat += f[i] - b[i]
				sum_hilly += h[i] - b[i]
				max_hilly = maxf(max_hilly, h[i] - b[i])
			for i in 3:
				assert_near(h[i], b[i], 1.0e-5, "Bankett und Graben (bis 15 m) ohne Relief")
			assert_near(h[6], b[6], 1.0e-5, "Bandende ohne Relief")
	assert_true(sum_hilly > 2.5 * sum_flat and sum_flat > 0.0, "Hügelstufe 3 hat deutlich mehr Relief als Stufe 0 (%.0f gegen %.0f)" % [sum_hilly, sum_flat])
	assert_between(max_hilly, 2.0, 3.0 * 1.5 + 0.001, "höchstens relief_m × Hügelfaktor (%.2f m)" % max_hilly)
	# smooth along the road: neighbouring rows differ by centimetres
	var tp: TerrainProfile = hilly[2]
	var step := 0.0
	for k in range(200, 900):
		step = maxf(step, absf(tp.ring_heights(k + 1, 1)[4] - tp.ring_heights(k, 1)[4]))
	assert_true(step < 0.2, "Relief ändert sich von Reihe zu Reihe um höchstens %.3f m" % step)
	# no relief in City Limits, in tunnels and on bridges; on a bridge the rings lie on the water
	var special := _make(SynTrack.straight(n), PackedFloat32Array(), {"hills": 3, "city_from_segment": 1100, "tunnel": [300, 400],
		"water": [700, 760, 9.0]}, {})
	var sp: TerrainProfile = special[2]
	var base := (none[2] as TerrainProfile).ring_heights(600, 1)
	for k: int in [320, 380, 1200, 1300]:
		_near_array(sp.ring_heights(k, 1), Array(base), 1.0e-4, "kein Relief bei Reihe %d (Tunnel / City Limits)" % k)
	var w := sp.ring_heights(730, -1)
	assert_near(w[0], 0.0, 1.0e-6, "Brücke: Bankettkante auf Fahrbahnniveau")
	for i in range(1, 7):
		assert_near(w[i], -9.0, 1.0e-4, "Brücke: Ringe auf dem Wasser (9 m unter der Fahrbahn)")
	var any_relief := false
	for k in range(450, 650, 7):
		if sp.ring_heights(k, 1)[4] > base[4] + 0.05:
			any_relief = true
	assert_true(any_relief, "dazwischen auf freier Strecke gibt es Relief")


## rows() gives what the single-row queries give; two chunks that share a row get the same numbers.
func test_rows_and_shared_rows() -> void:
	var n := 2600
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = clampf(0.8 * sin(float(i) * 0.012), -0.9, 0.9)
	var heights := SynTrack.grades(n, [[0, 0.05], [500, -0.06], [1300, 0.03]])
	var m := _make(curves, heights, {"hills": 2})
	var p: RoadPath3D = m[1]
	var tp: TerrainProfile = m[2]
	var a := tp.rows(1024, 1056)
	assert_eq(int(a["rings"]), 7, "Ringe je Seite")
	assert_eq((a["x"] as PackedFloat32Array).size(), 33 * 2 * 7, "33 Reihen × 2 Seiten × 7 Ringe")
	for q: int in [0, 13, 32]:
		var k := 1024 + q
		for si in 2:
			var side := -1 if si == 0 else 1
			var x := tp.ring_offsets(k, side)
			var h := tp.ring_heights(k, side)
			for i in 7:
				assert_eq((a["x"] as PackedFloat32Array)[(q * 2 + si) * 7 + i], x[i], "rows().x = ring_offsets() (Reihe %d)" % k)
				assert_eq((a["h"] as PackedFloat32Array)[(q * 2 + si) * 7 + i], h[i], "rows().h = ring_heights() (Reihe %d)" % k)
			var e: Vector2 = (a["edge"] as PackedVector2Array)[q]
			assert_near(e.x if si == 0 else e.y, tp.edge(k, side), 1.0e-6, "rows().edge")
			var l: Vector2 = (a["limit"] as PackedVector2Array)[q]
			assert_near(l.x if si == 0 else l.y, tp.limit(k, side), 1.0e-6, "rows().limit")
			var c: Vector2 = (a["corridor"] as PackedVector2Array)[q]
			assert_near(c.x if si == 0 else c.y, tp.corridor_width(k, side), 1.0e-6, "rows().corridor")
		assert_near((a["floor"] as PackedFloat64Array)[q], p.floor_y(k), 1.0e-9, "rows().floor = floor_y()")
		assert_near(tp.ring_heights(k, 1)[6], p.floor_y(k) - p.height(k), 1.0e-4, "letzter Ring = Talsohle relativ zur Fahrbahn")
	# the next chunk, taken later: the path was extended and trimmed like the streamer does in between
	p.ensure(2500)
	p.trim(1056 - 96 - int((150.0 + p.clear_reach_m) / 3.0) - 96)
	tp.trim(p.first)
	var b := tp.rows(1056, 1088)
	for i in 14:
		assert_eq((b["x"] as PackedFloat32Array)[i], (a["x"] as PackedFloat32Array)[32 * 14 + i], "gemeinsame Reihe: gleiche Ringabstände")
		assert_eq((b["h"] as PackedFloat32Array)[i], (a["h"] as PackedFloat32Array)[32 * 14 + i], "gemeinsame Reihe: gleiche Höhen")
	# and from a completely fresh path / profile that starts at another place of the same road
	var p2 := RoadPath3D.new()
	p2.setup(m[0], 256, 120.0)
	var tp2 := TerrainProfile.new()
	tp2.setup(p2, m[0], {}, {})
	p2.clear_reach_m = p.clear_reach_m
	var c2 := tp2.rows(1056, 1088)
	for i in (c2["x"] as PackedFloat32Array).size():
		assert_near((c2["x"] as PackedFloat32Array)[i], (b["x"] as PackedFloat32Array)[i], 1.0e-3, "reine Funktion der Straße: Ringabstände")
		assert_near((c2["h"] as PackedFloat32Array)[i], (b["h"] as PackedFloat32Array)[i], 1.0e-3, "reine Funktion der Straße: Höhen")
