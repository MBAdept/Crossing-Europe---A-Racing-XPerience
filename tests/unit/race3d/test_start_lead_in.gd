extends TestCase
## The start of a stage in the mode "Modern" (FIX-ZS1, finding QA1-B1 of the first test build): the car stands at
## z = 0, the camera 9 m behind it. RoadPath3D continues the road before boundary 0 straight along its tangent (the
## lead-in), the streamer builds chunk -1 there, the vehicle layer draws a car whose rear lies before the first
## boundary. Nothing changes for z >= 0 or once the path no longer starts at the track start.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Vehicles := preload("res://scripts/race3d/layers/vehicles.gd")
const R1 := 120.0
const SEG := 3.0


## Records the rows of every chunk; builds no geometry.
class RowProbe extends ChunkBuilder:
	func id() -> String:
		return "rows"

	func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
		var idx: Array = []
		var sprites := 0
		for s: Dictionary in ctx.segs:
			idx.append(int(s["index"]))
			sprites += (s["sprites"] as Array).size()
		return {"rows": ctx.row_count(), "seg_a": ctx.seg_a, "index": idx, "sprites": sprites, "o": ctx.rows_o, "origin": ctx.origin,
			"lanes": float(ctx.segs[0]["lanes"]), "z0": float(ctx.segs[0]["z"])}


func _track(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array()) -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, heights)
	return t


func _path(t: Track, start: int = 0) -> RoadPath3D:
	var p := RoadPath3D.new()
	p.setup(t, start, R1)
	p.ensure(400)
	return p


## A bend from the first segment on (curve 0.8 = R 150 m) and a grade from the first boundary: the lead-in must still be
## the straight, level tangent of boundary 0 – not the chord of segment 0, not the bend, not the grade.
func _bent_track() -> Track:
	var curves := SynTrack.join([SynTrack.arc(200, 150.0), SynTrack.straight(300)])
	return _track(curves, SynTrack.grades(501, [[0, 0.04]]))


func test_lead_in_is_the_tangent_of_boundary_0() -> void:
	for t: Track in [_track(SynTrack.straight(500)), _bent_track()]:
		var p := _path(t)
		assert_true(p.has_lead_in() and p.z_min() == -INF, "der Pfad beginnt am Streckenanfang: Vorlauf, z_min() = -INF")
		var p0 := p.point(0)
		var a0 := p.heading(0)
		var f0 := RoadPath3D.fwd_of(a0)
		var r0 := RoadPath3D.right_of(a0)
		var worst := 0.0
		for k in range(-40, 0):
			var want := p0 + f0 * float(k) * SEG
			worst = maxf(worst, p.point(k).distance_to(want))
		assert_true(worst < 1.0e-4, "Grenzen vor 0 auf der Tangente der Grenze 0 (%.6f m)" % worst)
		worst = 0.0
		var worst_h := 0.0
		for i in 61:
			var z := -0.25 * float(i) - 0.001
			worst = maxf(worst, p.centre_at(z).distance_to(p0 + f0 * z))
			worst = maxf(worst, p.world(z, 3.75, 0.66).distance_to(p0 + f0 * z + r0 * 3.75 + Vector3(0.0, 0.66, 0.0)))
			var fr := p.frame_at(z, -2.0, 1.0)
			worst = maxf(worst, fr.origin.distance_to(p0 + f0 * z - r0 * 2.0 + Vector3(0.0, 1.0, 0.0)))
			worst_h = maxf(worst_h, absf(p.heading_at(z) - a0) + absf(p.height_at(z) - p0.y))
			worst_h = maxf(worst_h, (fr.basis.z + f0).length())
		assert_true(worst < 1.0e-4, "centre_at / world / frame_at vor der Startlinie auf der Tangente (%.6f m)" % worst)
		assert_true(worst_h < 1.0e-6, "Richtung und Höhe vor der Startlinie die der Grenze 0 (%.8f)" % worst_h)
		# the camera of the countdown: 9 m behind the car at z = 0, exactly
		assert_true(absf(p.centre_at(-9.0).distance_to(p0) - 9.0) < 1.0e-4, "die Kamera des Countdowns steht 9 m hinter z = 0")
		# no jump at the start line
		var jump := p.world(-0.0005, 1.5, 0.0).distance_to(p.world(0.0, 1.5, 0.0))
		assert_true(jump < 0.001, "kein Sprung an der Startlinie (%.6f m auf 0,5 mm)" % jump)


func test_rows_of_the_lead_in() -> void:
	var p := _path(_bent_track())
	var rl := p.rows_local(-32, 0)
	var o: PackedVector3Array = rl["o"]
	var r: PackedVector3Array = rl["r"]
	var hd: PackedFloat64Array = rl["heading"]
	assert_eq(o.size(), 33, "33 Reihen von -32 bis 0")
	var origin: Vector3 = rl["origin"]
	assert_true(origin.distance_to(p.point(-32)) < 1.0e-4, "Ursprung = Grenze -32 auf dem Vorlauf")
	var worst := 0.0
	for q in 33:
		worst = maxf(worst, (origin + o[q]).distance_to(p.point(-32 + q)))
		worst = maxf(worst, r[q].distance_to(RoadPath3D.right_of(p.heading(0))) + absf(hd[q] - p.heading(0)))
	assert_true(worst < 1.0e-4, "Reihen des Vorlaufs = point(k), Richtung der Grenze 0 (%.6f)" % worst)
	assert_true(o[32].distance_to(p.point(0) - origin) < 1.0e-4, "die letzte Reihe ist Grenze 0 (die erste des Stücks 0)")


## z >= 0 is untouched: every lookup equals the plain interpolation of the integrated boundaries (arrays()), and a
## path that no longer starts at the track start clamps below its first boundary as before.
func test_nothing_changes_from_the_start_line_on() -> void:
	var p := _path(_bent_track())
	var a := p.arrays(0, 300)
	var xs: PackedFloat64Array = a["x"]
	var zs: PackedFloat64Array = a["z"]
	var ys: PackedFloat64Array = a["y"]
	var th: PackedFloat64Array = a["heading"]
	var worst := 0.0
	for i in 400:
		var z := float(i) * 2.17
		var k := int(floor(z / SEG))
		var t := z / SEG - float(k)
		var want := Vector3(lerpf(xs[k], xs[k + 1], t), lerpf(ys[k], ys[k + 1], t), lerpf(zs[k], zs[k + 1], t))
		worst = maxf(worst, p.centre_at(z).distance_to(want))
		var rx := lerpf(cos(th[k]), cos(th[k + 1]), t)
		var rz := lerpf(sin(th[k]), sin(th[k + 1]), t)
		var want_w := Vector3(lerpf(xs[k], xs[k + 1], t) + rx * 2.0, lerpf(ys[k], ys[k + 1], t) + 0.5, lerpf(zs[k], zs[k + 1], t) + rz * 2.0)
		worst = maxf(worst, p.world(z, 2.0, 0.5).distance_to(want_w))
		worst = maxf(worst, absf(p.heading_at(z) - lerpf(th[k], th[k + 1], t)))
	assert_eq(worst, 0.0, "ab der Startlinie bitgleich dieselben Werte wie ohne Vorlauf (%.8f)" % worst)
	assert_eq(p.centre_at(37.3), Vector3(lerpf(xs[12], xs[13], 37.3 / SEG - 12.0), lerpf(ys[12], ys[13], 37.3 / SEG - 12.0),
		lerpf(zs[12], zs[13], 37.3 / SEG - 12.0)), "centre_at() bitgleich mit der Interpolation der Grenzen")
	var rl := p.rows_local(32, 64)
	var o: PackedVector3Array = rl["o"]
	var wo := 0.0
	for q in 33:
		wo = maxf(wo, o[q].distance_to(Vector3(xs[32 + q] - xs[32], ys[32 + q] - ys[32], zs[32 + q] - zs[32])))
	assert_eq(wo, 0.0, "rows_local() ab Grenze 0 unverändert")
	# a path that starts later (or was trimmed): no lead-in, clamped below its first boundary as before
	var late := _path(_bent_track(), 64)
	assert_false(late.has_lead_in(), "Pfad ab Grenze 64: kein Vorlauf")
	assert_eq(late.z_min(), 64.0 * SEG, "z_min() = erste Grenze")
	assert_eq(late.point(10), late.point(64), "point() unter der ersten Grenze geklemmt")
	assert_eq(late.centre_at(-9.0), late.centre_at(64.0 * SEG), "centre_at() unter der ersten Grenze geklemmt")
	var trimmed := _path(_bent_track())
	trimmed.ensure(300)
	trimmed.trim(100)
	assert_false(trimmed.has_lead_in(), "nach trim(): kein Vorlauf mehr")
	assert_eq(trimmed.world(-9.0, 1.0, 0.0), trimmed.world(float(trimmed.first) * SEG, 1.0, 0.0), "nach trim(): geklemmt wie vorher")


## The vehicle layer's range rule: the player's rear lies 2.4 m before the start line during the countdown; it is drawn
## while the path has its lead-in and hidden where the path cannot place it (a trimmed path, as before).
func test_car_with_its_rear_before_the_first_boundary() -> void:
	var p := _path(_track(SynTrack.straight(500)))
	var z_hi := float(p.last()) * SEG
	var length := 4.8
	var rear := -length * 0.5
	assert_true(Vehicles.in_range(rear, length, -9.0, 900.0, p.z_min(), z_hi), "Spielerauto im Countdown (Heck bei -2,4 m) wird gezeigt")
	assert_false(Vehicles.in_range(rear, length, -9.0, 900.0, 0.0, z_hi), "mit der alten Grenze z_lo = 0 fehlte es (Befund QA1-B1)")
	assert_true(Vehicles.in_range(-27.0, 4.6, -9.0, 900.0, p.z_min(), z_hi), "ein Auto 27 m vor der Startlinie (Front 13,4 m hinter der Kamera) ja")
	assert_false(Vehicles.in_range(-40.0, 4.6, -9.0, 900.0, p.z_min(), z_hi), "eines, dessen Front mehr als 14 m hinter der Kamera liegt, nein")
	assert_false(Vehicles.in_range(950.0, 4.6, -9.0, 900.0, p.z_min(), z_hi), "jenseits der Sicht + 30 m nein")
	var late := _path(_track(SynTrack.straight(500)), 64)
	assert_false(Vehicles.in_range(190.0, 4.6, 200.0, 900.0, late.z_min(), z_hi), "Heck unter der ersten Grenze eines späteren Pfads: nicht gezeigt")
	assert_true(Vehicles.in_range(193.0, 4.6, 200.0, 900.0, late.z_min(), z_hi), "Heck auf der ersten Grenze: gezeigt")


## Chunk -1: loaded with the start view, rows -32 .. 0 on the lead-in with segment 0's data and no sprites; freed like
## every chunk once it lies more than keep_behind_m behind the camera; never loaded away from the start.
func test_streamer_builds_the_lead_in_chunk() -> void:
	var t := _track(SynTrack.straight(1200))
	(t.get_segment(0) as TrackSegment).sprites.append({"kind": "prop", "set": "props/test", "side": 1, "x": 12.0, "z": 1.0})
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), {})
	var st := ChunkStreamer.new()
	st.setup(p, tp, t, cfg(), {}, true)
	st.register(RowProbe.new())
	st.update(-9.0, 900.0)
	var lead: Dictionary = {}
	var zero: Dictionary = {}
	for c: Dictionary in st.snapshot()["chunks"]:
		if int(c["index"]) == -1:
			lead = c
		elif int(c["index"]) == 0:
			zero = c
	assert_false(lead.is_empty(), "Stück -1 (Vorlauf) mit der Startansicht geladen")
	assert_false(zero.is_empty(), "Stück 0 geladen")
	if lead.is_empty():
		st.free()
		return
	assert_eq(int(lead["seg_a"]), -32, "Vorlauf von Grenze -32 …")
	assert_eq(int(lead["seg_b"]), 0, "… bis zur Startlinie (Grenze 0)")
	var node := st.chunk_node(-1)
	assert_true(node != null and node.position.distance_to(p.point(-32)) < 1.0e-4, "Knoten auf Grenze -32 (96 m vor der Startlinie)")
	# what the builder saw (it ran on the snapshot)
	var probe := RowProbe.new()
	var ctx := ChunkContext.new()
	ctx.capture(-1, -32, 0, p, tp, t)
	var part := probe.build(ctx, null)
	assert_eq(int(part["rows"]), 33, "33 Reihen")
	var want_idx: Array = []
	for k in range(-32, 1):
		want_idx.append(k)
	assert_eq(part["index"], want_idx, "Reihen tragen ihren eigenen Index -32 … 0")
	assert_eq(int(part["sprites"]), 1, "nur Segment 0 selbst trägt Requisiten – keine doppelt im Vorlauf")
	assert_eq(float(part["z0"]), -96.0, "Straßenposition der ersten Reihe -96 m")
	assert_eq(float(part["lanes"]), float((t.get_segment(0) as TrackSegment).lanes), "Spuren wie Segment 0")
	var o: PackedVector3Array = part["o"]
	var origin: Vector3 = part["origin"]
	var worst := 0.0
	for q in 33:
		worst = maxf(worst, (origin + o[q]).distance_to(p.point(-32 + q)))
	assert_true(worst < 1.0e-4, "Reihen auf dem Vorlauf des Pfads (%.6f m)" % worst)
	assert_true(ctx.local(-9.0, 0.0, 0.0).distance_to(p.centre_at(-9.0) - origin) < 1.0e-4, "ChunkContext.local() unter der Kamera = Pfad")
	# driving off: freed once it lies keep_behind_m behind the camera
	st.update(140.0, 900.0)
	assert_true(st.chunk_node(-1) != null, "bei 140 m noch da (liegt 140 m hinter der Kamera)")
	st.update(160.0, 900.0)
	assert_true(st.chunk_node(-1) == null, "ab 150 m hinter der Kamera freigegeben")
	st.clear()
	# a start further down the stage: no lead-in chunk
	st.update(2400.0, 900.0)
	var lowest := 1 << 30
	for c: Dictionary in st.snapshot()["chunks"]:
		lowest = mini(lowest, int(c["index"]))
	assert_true(lowest >= 0 and st.chunk_node(-1) == null, "Start bei km > 0: kein Stück -1 (niedrigstes %d)" % lowest)
	st.free()


func test_lead_in_snapshot() -> void:
	var s := TrackSegment.new()
	s.index = 0
	s.lanes = 2.5
	s.guardrail = true
	s.city = true
	s.sprites.append({"kind": "sign", "sign": "start", "side": 0, "z": 14.0})
	var d := ChunkContext.lead_in_snapshot(s, -7, 3.0)
	assert_eq(int(d["index"]), -7, "Index der Reihe")
	assert_eq(float(d["z"]), -21.0, "Straßenposition der Reihe")
	assert_eq(float(d["km"]), 0.0, "Kilometer 0")
	assert_eq((d["sprites"] as Array).size(), 0, "ohne Requisiten und Schilder (kein zweites Starttor)")
	assert_true(float(d["lanes"]) == 2.5 and bool(d["guardrail"]) and bool(d["city"]), "sonst Segment 0: Spuren, Leitplanke, Stadt")
	assert_eq(s.sprites.size(), 1, "Segment 0 selbst unverändert")
	for f: String in ChunkContext.SEG_FIELDS:
		assert_true(d.has(f), "Feld %s vorhanden" % f)
