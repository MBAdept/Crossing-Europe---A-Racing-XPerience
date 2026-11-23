extends TestCase
## NACH-R7b probe (temporary, NOT committed): network-wide placement of the landmark models and shapes after FIX-R7b
## (turn to the approach, near_shift, main axis on the anchor, mirror) against R7b (turned with the road, front face
## on the anchor, never mirrored): turn, shift, anchor change and the horizontal clearance of the footprint's corners
## to the road edge (searched along the real path ±200 m).

const Fair := preload("res://tests/race3d/fairness.gd")
const Landmarks := preload("res://scripts/race3d/builders/landmarks.gd")


func _cleanup() -> void:
	ModelDB.release_all()
	ModernMaterials.drop_shared()


func _road_clear(t: Track, path: RoadPath3D, c: Vector3, z0: float) -> float:
	# smallest horizontal distance of world point c to the road's edge band (negative: over the road)
	var best := INF
	var zz := z0 - 200.0
	while zz <= z0 + 200.0:
		var ctr := path.world(zz, 0.0, 0.0)
		var a := path.heading_at(zz)
		var r := RoadPath3D.right_of(a)
		var f := RoadPath3D.fwd_of(a)
		var d := Vector3(c.x - ctr.x, 0.0, c.z - ctr.z)
		if absf(d.dot(f)) <= 1.5:
			var lat := d.dot(r)
			var e := t.road_edges_at(zz)
			var out := (lat - e.y) if lat > 0.0 else (e.x - lat)
			best = minf(best, out)
		zz += 1.0
	return best


func test_probe_placement() -> void:
	var cfg := ConfigLoader.load_merged()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var net := Fair.load_network()
	var want: Array = []
	var rows: Array = []
	for dir: Dictionary in Fair.directions(net):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for s: String in Landmarks.wanted_sets(t):
			if not want.has(s):
				want.append(s)
		rows.append([str(dir["name"]), plan])
	var lib := PropLibrary.new()
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 60000:
		OS.delay_msec(1)
		guard += 1
	var boxes := {}
	var n := 0
	var worst_turn := 0.0
	var worst_shift := 0.0
	var worst_dx := 0.0
	var min_clear_now := INF
	var min_clear_old := INF
	var lines: Array[String] = []
	for row: Array in rows:
		var t := Track.new()
		t.setup(row[1], cfg, net["scenery"])
		var pfb := Landmarks.plan_fallbacks(t)
		var items: Array = t.landmarks.duplicate()
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("z", 0.0)) < float(b.get("z", 0.0)))
		var path := RoadPath3D.new()
		path.setup(t, 0, r1)
		for it: Dictionary in items:
			var p: Dictionary = Landmarks.resolve_item(it, lib.sets, pfb)
			var rep := int(p["rep"])
			if rep != Landmarks.MODEL and rep != Landmarks.PROC:
				continue
			var z := float(p["z"])
			path.ensure(int(z / t.seg_len) + 60)
			var side := int(p["side"])
			var sc := float(p["scale"])
			var box := AABB()
			var oz := 0.0
			if rep == Landmarks.PROC:
				var pm: Dictionary = Landmarks.proc_mesh(p["item"])
				box = (pm["mesh"] as Mesh).get_aabb()
				var kind := str(p["kind"])
				oz = float(Landmarks.PROC_AXIS_Z.get(kind, 0.0)) * float(it.get("height_m", 40.0)) / float(Landmarks.PROC_REF.get(kind, 1.0))
			else:
				var mid := str(p["model"])
				if not boxes.has(mid):
					var md: Dictionary = lib.models.get(mid, {})
					var reps: Array = md.get("reps", [])
					var bb := AABB()
					if not reps.is_empty():
						for pv: Variant in lib.mesh_parts(mid, str(reps[0])):
							var part: Dictionary = pv
							if bool(part.get("shadow", false)) or bool(part.get("billboard", false)):
								continue
							var mb: AABB = (part.get("transform", Transform3D.IDENTITY) as Transform3D) * (part["mesh"] as Mesh).get_aabb()
							bb = mb if bb.size == Vector3.ZERO else bb.merge(mb)
					boxes[mid] = bb
				box = boxes[mid]
			# R7b: anchor with the unmirrored edge, turned with the road, never mirrored; shapes with the front face on
			# the anchor (the body = today's mesh moved back by the main-axis offset)
			var x_now := float(p["x"])
			var x_old := x_now
			if it.has("align") and side != 0 and rep == Landmarks.MODEL:
				var e: Dictionary = lib.sets.get(str(p["set"]), {})
				x_old = Landmarks.PropsBuilderMath.edge_anchor_x(float(it.get("x", 0.0)), side, false, float(e.get("extent_l", 0.5)),
					float(e.get("extent_r", 0.5)), sc)
			var origin_now := path.world(z, x_now, 0.0)
			var origin_old := path.world(z, x_old, 0.0)
			var a := path.heading_at(z)
			var from := path.world(maxf(z - Landmarks.APPROACH_M, path.z_min()), 0.0, 0.0)
			var th := Landmarks.face_heading(a, from, origin_now)
			var mx := -sc if bool(p.get("mirror", false)) else sc
			var basis := Landmarks.heading_basis(th, Vector3(mx, sc, sc))
			var shift := Landmarks.near_shift(Landmarks.heading_basis(a, Vector3(mx, sc, sc)), basis, box, a, side)
			var o_now := origin_now + RoadPath3D.right_of(a) * float(side) * shift
			var b_old := Landmarks.heading_basis(a, Vector3(sc, sc, sc))
			var box_old := box
			box_old.position.z -= oz
			var cl_now := INF
			var cl_old := INF
			for cx: float in [box.position.x, box.end.x]:
				for cz: float in [box.position.z, box.end.z]:
					cl_now = minf(cl_now, _road_clear(t, path, o_now + basis * Vector3(cx, 0.0, cz), z))
			for cx: float in [box_old.position.x, box_old.end.x]:
				for cz: float in [box_old.position.z, box_old.end.z]:
					cl_old = minf(cl_old, _road_clear(t, path, origin_old + b_old * Vector3(cx, 0.0, cz), z))
			var turn := rad_to_deg(th - a)
			n += 1
			worst_turn = maxf(worst_turn, absf(turn))
			worst_shift = maxf(worst_shift, shift)
			worst_dx = maxf(worst_dx, absf(x_now - x_old))
			min_clear_now = minf(min_clear_now, cl_now)
			min_clear_old = minf(min_clear_old, cl_old)
			lines.append("PROBE %s km %.1f %s rep=%s side=%d mirror=%s turn=%.1f shift=%.2f dx=%.2f clear_now=%.1f clear_old=%.1f box=%s sc=%.2f" % [
				str(row[0]), z / 1000.0, str(p["set"]) if rep == Landmarks.MODEL else str(p["kind"]), Landmarks.REP_NAMES[rep], side,
				str(p.get("mirror", false)), turn, shift, x_now - x_old, cl_now, cl_old, str(box.size.snappedf(0.1)), sc])
	for l in lines:
		print(l)
	print("PROBE-SUMME %d Modelle/Formen: |Drehung| max %.1f°, Verschiebung max %.2f m, Ankeränderung max %.2f m, kleinster Abstand Ecke–Fahrbahnrand jetzt %.1f m (R7b %.1f m)" % [
		n, worst_turn, worst_shift, worst_dx, min_clear_now, min_clear_old])
	assert_true(n > 0, "probe ran")
	lib.clear(self)
	_cleanup()
