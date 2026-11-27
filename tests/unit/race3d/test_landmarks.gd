extends TestCase
## builders/landmarks.gd (mode "Modern", package R7b): Arcade's landmark law (range, alpha, haze, illumination,
## floodlight), what every landmark of data/cities.json is drawn with (model, Arcade's picture, the procedural shape
## of Arcade's kind, a fallback), where it stands (Arcade's anchor arithmetic), the procedural shapes (size of the
## real landmark, a slim tower stays slim, faces wound outwards, aviation lights) and the material rules (no instance
## uniform: amendment A-19). The scene-level checks (reach on the road, screen position at 600 m, no landmark twice)
## are tests/race3d/check_landmarks.gd.

const Fair := preload("res://tests/race3d/fairness.gd")
const Landmarks := preload("res://scripts/race3d/builders/landmarks.gd")
const LAW := Vector2(2.0, 1900.0)


func _cleanup() -> void:
	ModelDB.release_all()
	ModernMaterials.drop_shared()


## RoadRenderer.landmark_fade (frozen Arcade) for alpha and haze, and _draw_landmark for the illumination – at 20
## distances and three sights (day, night, fog).
func test_fade_is_arcades_landmark_law() -> void:
	for vis: float in [900.0, 420.0, 180.0]:
		var fog_start := vis * 0.45
		for i in 20:
			var d := 30.0 + float(i) * 110.0
			var a := RoadRenderer.landmark_fade(d, vis, fog_start, LAW.x, LAW.y)
			for night: float in [0.0, 1.0]:
				var f: Vector4 = Landmarks.fade(d, vis, fog_start, night, LAW, false)
				assert_near(f.x, a.x, 1.0e-5, "Deckung bei %.0f m, Sicht %.0f" % [d, vis])
				assert_near(f.y, a.y, 1.0e-5, "Dunst bei %.0f m, Sicht %.0f" % [d, vis])
				var lights := night * (1.0 - smoothstep(LAW.y * 0.8, LAW.y, d)) if night > 0.05 else 0.0
				assert_near(f.z, lights, 1.0e-5, "Beleuchtung bei %.0f m" % d)
				assert_near(f.w, 0.0, 1.0e-6, "ein Wahrzeichen-Sprite wird nicht angestrahlt")
				var fl: Vector4 = Landmarks.fade(d, vis, fog_start, night, LAW, true)
				assert_near(fl.w, RoadRenderer.LANDMARK_FLOOD_K * lights, 1.0e-5, "eine Requisite als Wahrzeichen wird nachts angestrahlt")


## Reach: Arcade's landmark range, at night at least render.landmark_far_m (RoadRenderer._draw_far_landmarks).
func test_reach_is_arcades() -> void:
	for vis: float in [900.0, 600.0, 300.0, 150.0, 2500.0]:
		var l := clampf(vis * LAW.x, minf(vis, 600.0), maxf(LAW.y, vis))
		assert_near(Landmarks.landmark_range(vis, LAW), l, 1.0e-4, "Reichweite bei Sicht %.0f" % vis)
		assert_near(Landmarks.reach(vis, 0.0, LAW), l, 1.0e-4, "bei Tag")
		assert_near(Landmarks.reach(vis, 1.0, LAW), maxf(l, LAW.y), 1.0e-4, "nachts bis landmark_far_m")
	assert_near(Landmarks.landmark_range(900.0, LAW), 1800.0, 0.01, "klare Sicht: 1.800 m")


## Every landmark a city of data/cities.json places is drawn in Modern: a model where the manifest has one, else
## Arcade's own picture, else the 3D shape of Arcade's procedural kind (the six landmarks without a sprite: Hannover,
## Dortmund, Leipzig, Madrid, Belgrad, Calais), never nothing; plain props standing as landmarks are floodlit.
func test_every_city_landmark_has_a_representation() -> void:
	var net := Fair.load_network()
	var db: Dictionary = net["city_db"]
	var lib := PropLibrary.new()
	var want: Array = []
	var items: Array = []
	for cid: String in (db.get("cities", {}) as Dictionary):
		for lm_v: Variant in ((db["cities"] as Dictionary)[cid] as Dictionary).get("landmarks", []):
			var lm: Dictionary = lm_v
			var it := CityData.landmark_entry(db, str(lm.get("set", "")), lm)
			it["side"] = int(lm.get("side", 1))
			it["x"] = 10.0
			it["z"] = 1000.0
			it["scale"] = float(lm.get("scale", 1.0))
			it["align"] = "edge"
			it["landmark"] = true
			if it.has("proc"):
				it.erase("fallback")          # as Track._build_landmark
			items.append([cid, it, str(CityData.landmark_entry(db, str(lm.get("set", "")), lm).get("fallback", ""))])
			for s: String in [str(it["set"]), str(it.get("fallback", ""))]:
				if s != "" and not want.has(s):
					want.append(s)
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 30000:
		OS.delay_msec(1)
		guard += 1
	var procs := {}
	for row: Array in items:
		var cid := str(row[0])
		var it: Dictionary = row[1]
		var p: Dictionary = Landmarks.resolve_item(it, lib.sets, {})
		var set_id := str(it["set"])
		assert_true(int(p["rep"]) != Landmarks.NONE, "%s (%s) wird gezeichnet" % [set_id, cid])
		var e: Dictionary = lib.sets.get(set_id, {})
		var kind := int(e.get("kind", PropLibrary.NONE))
		if kind == PropLibrary.MODEL:
			assert_eq(int(p["rep"]), Landmarks.MODEL, "%s (%s): ein Modell im Manifest wird gezeigt" % [set_id, cid])
		elif kind == PropLibrary.SPRITE:
			assert_eq(int(p["rep"]), Landmarks.PICTURE, "%s (%s): sonst Arcades Bild" % [set_id, cid])
		else:
			assert_eq(int(p["rep"]), Landmarks.PROC, "%s (%s): sonst Arcades prozedurale Form in 3D" % [set_id, cid])
			assert_eq(str(p["kind"]), str(it["proc"]), "%s: dieselbe Art wie Arcade" % set_id)
			procs[set_id] = cid
		assert_eq(bool(p["flood"]), int(p["rep"]) != Landmarks.PROC and not str(p["set"]).begins_with("landmarks/"),
			"%s (%s): nachts angestrahlt genau dann, wenn eine gewöhnliche Requisite als Wahrzeichen steht" % [set_id, cid])
	for city: String in ["hannover", "dortmund", "leipzig", "madrid", "belgrad", "calais"]:
		assert_true(procs.values().has(city), "%s: prozedurales Wahrzeichen in 3D (%s)" % [city, str(procs)])
	assert_eq(int(Landmarks.resolve_item({"set": "landmarks/michel", "side": 1, "x": 70.0, "z": 0.0, "align": "edge"}, lib.sets, {})["rep"]),
		Landmarks.MODEL, "Michel: das Modell")
	assert_eq(int(Landmarks.resolve_item({"set": "landmarks/elbphilharmonie", "side": -1, "x": -55.0, "z": 0.0, "align": "edge"}, lib.sets, {})["rep"]),
		Landmarks.MODEL, "Elbphilharmonie: das Modell (AS6)")
	# since AS6 every landmark sprite has a model: Arcade's picture for a set without one (a sprite-only set)
	var only_sprite := {"landmarks/only_sprite": {"kind": PropLibrary.SPRITE, "extent_l": 10.0, "extent_r": 10.0, "variants": []}}
	assert_eq(int(Landmarks.resolve_item({"set": "landmarks/only_sprite", "side": 1, "x": 30.0, "z": 0.0, "align": "edge"}, only_sprite, {})["rep"]),
		Landmarks.PICTURE, "ein Set nur mit Sprite: Arcades Bild")
	lib.clear(self)
	_cleanup()


## The anchor: a picture or model edge-aligned like Arcade's props (RoadRenderer.edge_anchor_x with the sprite's
## extents; landmarks never mirrored), a procedural shape centred like Arcade's procedural drawing (x + side ×
## width_m / 2 × scale).
func test_anchor_is_arcades() -> void:
	var sets := {"landmarks/a": {"kind": PropLibrary.SPRITE, "extent_l": 20.0, "extent_r": 30.0, "variants": []}}
	for side: int in [1, -1]:
		var it := {"set": "landmarks/a", "side": side, "x": 50.0 * float(side), "z": 0.0, "scale": 1.5, "align": "edge"}
		var p: Dictionary = Landmarks.resolve_item(it, sets, {})
		var ext := Vector2(20.0, 30.0)
		assert_near(float(p["x"]), RoadRenderer.edge_anchor_x(50.0 * float(side), side, false, ext, 1.5), 1.0e-4, "Anker wie Arcade, Seite %d" % side)
		var pi := {"set": "landmarks/none", "side": side, "x": 40.0 * float(side), "z": 0.0, "scale": 0.5, "proc": "tv_tower",
			"width_m": 30.0, "height_m": 200.0, "align": "edge"}
		var pp: Dictionary = Landmarks.resolve_item(pi, sets, {})
		assert_eq(int(pp["rep"]), Landmarks.PROC, "prozedural")
		assert_near(float(pp["x"]), 40.0 * float(side) + float(side) * 30.0 * 0.5 * 0.5, 1.0e-4, "Mitte wie Arcades Zeichnung, Seite %d" % side)


## FIX-R7b (B-04), network-wide: every landmark of every stage direction stands at Arcade's anchor (RoadRenderer
## _prep_prop of the same item – edge rule with the extent of the side Arcade shows, a procedural kind centred) and is
## mirrored exactly where Arcade mirrors its picture (prop_flipped: props/church on the left side). R7b never mirrored
## and measured the edge with the unmirrored extent: the Magdeburger Dom stood 37.8 m nearer the road (44.7 px at 600 m).
func test_anchor_and_mirror_like_arcade_network_wide() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var items: Array = []
	var want: Array = []
	for dir: Dictionary in Fair.directions(net):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var pfb := Landmarks.plan_fallbacks(t)
		for it: Dictionary in t.landmarks:
			items.append([str(dir["name"]), it.duplicate(true), pfb])
		for s: String in Landmarks.wanted_sets(t):
			if not want.has(s):
				want.append(s)
	var lib := PropLibrary.new()
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 60000:
		OS.delay_msec(1)
		guard += 1
	var rr := RoadRenderer.new()
	rr.proj = Fair.make_projection(cfg)
	var worst := 0.0
	var mirrored := 0
	for row: Array in items:
		var it: Dictionary = row[1]
		var pc: Array = rr._prep_prop(it.duplicate())
		var p: Dictionary = Landmarks.resolve_item(it, lib.sets, row[2])
		var what := "%s %s" % [str(row[0]), str(it["set"])]
		if int(p["rep"]) == Landmarks.NONE:
			continue
		worst = maxf(worst, absf(float(p["x"]) - float(pc[3])))
		# a model's extents may differ from its sprite's by the validator's tolerance (A-4: max(2 %, half a sprite pixel
		# + 5 mm)) – measured at most 0.34 m since AS6 (landmarks/catedrala_mantuirii: the sprite measures its extents
		# in whole pixels of 0.23 m, the model on its geometry; 1.5 sprite pixels), 0.4 px at 600 m
		assert_near(float(p["x"]), float(pc[3]), 0.4, "%s: Anker wie Arcade" % what)
		var info: Array = pc[1]
		var flip := not info.is_empty() and RoadRenderer.prop_flipped(int(it.get("side", 1)), bool(it.get("mirror", false)),
			bool(info[RoadRenderer.SI_MIRROR]))
		assert_eq(bool(p.get("mirror", false)), flip, "%s: gespiegelt genau wie Arcades Bild" % what)
		if flip:
			mirrored += 1
	rr.free()
	assert_true(items.size() >= 100, "Wahrzeichen des Netzes geprüft (%d)" % items.size())
	assert_true(mirrored >= 10, "Requisiten mit mirror_left stehen links gespiegelt wie in Arcade (%d)" % mirrored)
	print("    Anker wie Arcade bei %d Wahrzeichen (größter Unterschied %.3f m), %d gespiegelt" % [items.size(), worst, mirrored])
	lib.clear(self)
	_cleanup()


## A-25 (RINT-M3, NACH-R7b N-1): the NODE that is drawn – the model or shape turned to its approach and moved away from
## the road by near_shift() (Landmarks.place_model(), the function _place() draws with) – stays within
## MAX_NODE_SHIFT_M (12 m) of Arcade's anchor, horizontally, network-wide; the resolved anchor alone (the test above)
## says nothing about it. The path starts 800 m before each landmark (the turn reads the road 600 m before it; relative
## geometry is the same as from the stage start).
func test_drawn_node_stays_near_arcades_anchor_network_wide() -> void:
	var cfg := ConfigLoader.load_merged()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var net := Fair.load_network()
	var rows: Array = []
	var want: Array = []
	for dir: Dictionary in Fair.directions(net):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		rows.append([str(dir["name"]), plan])
		for s: String in Landmarks.wanted_sets(t):
			if not want.has(s):
				want.append(s)
	var lib := PropLibrary.new()
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 60000:
		OS.delay_msec(1)
		guard += 1
	var boxes := {}
	var n := 0
	var worst := 0.0
	var worst_what := ""
	for row: Array in rows:
		var t := Track.new()
		t.setup(row[1], cfg, net["scenery"])
		var pfb := Landmarks.plan_fallbacks(t)
		for it: Dictionary in t.landmarks:
			var p: Dictionary = Landmarks.resolve_item(it, lib.sets, pfb)
			var rep := int(p["rep"])
			if rep != Landmarks.MODEL and rep != Landmarks.PROC:
				continue
			var box := AABB()
			if rep == Landmarks.PROC:
				box = ((Landmarks.proc_mesh(p["item"]) as Dictionary)["mesh"] as Mesh).get_aabb()
			else:
				var mid := str(p["model"])
				if not boxes.has(mid):
					var reps: Array = (lib.models.get(mid, {}) as Dictionary).get("reps", [])
					boxes[mid] = Landmarks.parts_box(lib.mesh_parts(mid, str(reps[0]))) if not reps.is_empty() else AABB()
				box = boxes[mid]
			var z := float(p["z"])
			var path := RoadPath3D.new()
			path.setup(t, maxi(0, int(floor((z - 800.0) / t.seg_len))), r1)
			path.ensure(int(ceil(z / t.seg_len)) + 2)
			var origin := path.world(z, float(p["x"]), 0.0)
			var pm := Landmarks.place_model(path, z, origin, int(p["side"]), float(p["scale"]), bool(p.get("mirror", false)), box)
			var o: Vector3 = (pm["transform"] as Transform3D).origin
			var d := Vector2(o.x - origin.x, o.z - origin.z).length()
			var what := "%s km %.1f %s" % [str(row[0]), z / 1000.0, str(p["set"])]
			n += 1
			if d > worst:
				worst = d
				worst_what = "%s (gedreht %.1f°)" % [what, rad_to_deg(float(pm["turn"]))]
			assert_true(d <= Landmarks.MAX_NODE_SHIFT_M, "%s: gezeichneter Knoten %.2f m von Arcades Anker (höchstens %.0f m)" % [what, d, Landmarks.MAX_NODE_SHIFT_M])
	assert_true(n >= 40, "Modelle und Formen des Netzes geprüft (%d)" % n)
	print("    gezeichneter Knoten: %d Modelle/Formen, größte Verschiebung %.2f m – %s" % [n, worst, worst_what])
	lib.clear(self)
	_cleanup()


## FIX-R7b (B-05): a model or shape faces its approach – the bearing from the road point before it, at most MAX_TURN
## from the road's heading – and the turn never brings a corner of its footprint nearer the road than standing along
## the road would.
func test_facing_the_approach() -> void:
	var a := 0.3
	var origin := Vector3(100.0, 0.0, -600.0)
	# straight ahead of the approach point: the bearing itself
	var from := origin - RoadPath3D.fwd_of(a + 0.2) * 600.0
	assert_near(Landmarks.face_heading(a, from, origin), a + 0.2, 1.0e-4, "Front zur Anfahrt")
	var far := origin - RoadPath3D.fwd_of(a + 1.2) * 600.0
	assert_near(Landmarks.face_heading(a, far, origin), a + Landmarks.MAX_TURN, 1.0e-4, "höchstens MAX_TURN von der Straße")
	assert_near(Landmarks.face_heading(a, origin + Vector3(1.0, 0.0, 1.0), origin), a, 1.0e-6, "Punkte fallen zusammen: Straßenrichtung")
	# a long footprint (a church 20 m wide, 70 m deep) on the left side, turned 25° each way
	var box := AABB(Vector3(-4.0, 0.0, -60.0), Vector3(20.0, 30.0, 70.0))
	for side: int in [1, -1]:
		for turn: float in [0.44, -0.44]:
			for mirror: float in [1.0, -1.0]:
				var s := Vector3(2.6 * mirror, 2.6, 2.6)
				var along := Landmarks.heading_basis(a, s)
				var turned := Landmarks.heading_basis(a + turn, s)
				var shift := Landmarks.near_shift(along, turned, box, a, side)
				assert_true(shift >= 0.0, "nie zur Straße hin verschoben")
				var r := RoadPath3D.right_of(a)
				var near_a := INF
				var near_t := INF
				for cx: float in [box.position.x, box.end.x]:
					for cz: float in [box.position.z, box.end.z]:
						var c := Vector3(cx, 0.0, cz)
						near_a = minf(near_a, float(side) * (along * c).dot(r))
						near_t = minf(near_t, float(side) * ((turned * c) + r * float(side) * shift).dot(r))
				assert_true(near_t >= near_a - 1.0e-3, "Seite %d, Drehung %.2f, Spiegel %.0f: keine Ecke näher an der Straße (%.2f gegen %.2f)" % [side, turn, mirror, near_t, near_a])
	assert_near(Landmarks.near_shift(Landmarks.heading_basis(a, Vector3.ONE), Landmarks.heading_basis(a, Vector3.ONE), box, a, 1), 0.0, 1.0e-4, "ungedreht: keine Verschiebung")
	assert_true(Landmarks.heading_basis(a, Vector3(-1.0, 1.0, 1.0)).determinant() < 0.0, "gespiegelt: negative Determinante (ein MeshInstance3D zeichnet richtig, D24)")


## Welle 6 (AS6): a long footprint – the Milan cathedral is 158 m deep – turned to its approach swings its far end
## towards the road, and near_shift() would move the node 26.7 m from Arcade's anchor. capped_turn() turns it only as
## far as the node may move (MAX_NODE_SHIFT_M); a short footprint keeps its whole turn.
func test_long_footprint_turns_only_as_far_as_the_node_may_move() -> void:
	var a := 0.4
	var long_box := AABB(Vector3(-30.0, 0.0, -160.0), Vector3(60.0, 100.0, 160.0))
	var cut := 0
	for side: int in [1, -1]:
		for turn: float in [0.17, -0.17, 0.6, -0.6]:
			for mirror: float in [1.0, -1.0]:
				var s := Vector3(mirror, 1.0, 1.0)
				var t := Landmarks.capped_turn(a, a + turn, long_box, side, s)
				var shift := Landmarks.near_shift(Landmarks.heading_basis(a, s), Landmarks.heading_basis(t, s), long_box, a, side)
				assert_true(shift <= Landmarks.MAX_NODE_SHIFT_M + 1.0e-3, "Seite %d, Drehung %.2f: Verschiebung %.2f m (höchstens %.0f m)" % [side, turn, shift, Landmarks.MAX_NODE_SHIFT_M])
				assert_true((t - a) * turn >= 0.0 and absf(t - a) <= absf(turn) + 1.0e-6, "Seite %d, Drehung %.2f: in dieselbe Richtung, höchstens so weit (%.3f)" % [side, turn, t - a])
				if absf(t - a) < absf(turn) - 1.0e-3:
					cut += 1
					var full := Landmarks.near_shift(Landmarks.heading_basis(a, s), Landmarks.heading_basis(a + turn, s), long_box, a, side)
					assert_true(full > Landmarks.MAX_NODE_SHIFT_M, "gekürzt nur, wo die ganze Drehung zu weit schöbe (%.2f m)" % full)
	assert_true(cut > 0, "die lange Kirche wird in manchen Fällen weniger gedreht (%d)" % cut)
	var short_box := AABB(Vector3(-10.0, 0.0, -20.0), Vector3(20.0, 30.0, 20.0))
	for turn: float in [0.5, -0.5]:
		assert_near(Landmarks.capped_turn(a, a + turn, short_box, 1, Vector3.ONE), a + turn, 1.0e-6, "kurzer Grundriss: ganze Drehung %.1f" % turn)


## The procedural shapes: the size of the real landmark (height_m × scale up to its tip; skyscrapers with their
## masts as Arcade draws them), a TV tower and a lighthouse slim (N2: no wide block), every face wound outwards (front
## faces clockwise for Godot), the aviation lights.
func test_procedural_shapes() -> void:
	var cases := [
		{"proc": "tv_tower", "height_m": 209.0, "scale": 1.0, "glows": 3, "slim": true},
		{"proc": "lighthouse", "height_m": 51.0, "scale": 1.0, "glows": 1, "slim": true},
		{"proc": "domed_church", "height_m": 98.0 * 0.65, "scale": 1.0, "wall": "#e4dccc", "dome": "#6f9c86", "cross": false, "glows": 1, "slim": false},
		{"proc": "domed_church", "height_m": 82.0, "scale": 1.0, "wall": "#f0ece2", "dome": "#6f9c86", "glows": 1, "slim": false},
		{"proc": "skyscrapers", "height_m": 250.0, "scale": 1.0, "glows": 5, "slim": false}]
	for c: Dictionary in cases:
		var out: Dictionary = Landmarks.proc_mesh(c)
		var mesh: ArrayMesh = out["mesh"]
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var aabb := mesh.get_aabb()
		var hgt := float(c["height_m"])
		var top := aabb.end.y
		var what := str(c["proc"])
		if what == "skyscrapers":
			assert_between(top, hgt, hgt * 1.1, "%s: Höhe mit Mast (%.1f m)" % [what, top])
		else:
			assert_near(top, hgt, hgt * 0.02, "%s: Höhe des Wahrzeichens (%.1f m)" % [what, top])
		assert_near(aabb.position.y, 0.0, 0.01, "%s: steht auf dem Boden" % what)
		# FIX-R7b (B-05): the main axis (dome, tower, tallest high-rise) on the anchor, as Arcade draws it there – the
		# body reaches to both sides of it in depth (R7b: the front face at the anchor, the dome 25 m behind it)
		var axis := _axis_z(v, aabb)
		assert_near(axis, 0.0, maxf(0.5, aabb.size.z * 0.02), "%s: Hauptachse am Anker (z %.2f)" % [what, axis])
		assert_true(aabb.position.z < -1.0 and aabb.end.z > 1.0, "%s: der Körper reicht vor und hinter den Anker (%.1f .. %.1f)" % [what, aabb.position.z, aabb.end.z])
		var ratio := aabb.size.x / maxf(top, 0.01)
		if bool(c["slim"]):
			assert_true(ratio < 0.4, "%s: schlank (Breite/Höhe %.2f) – kein breiter Block" % [what, ratio])
		else:
			assert_true(ratio > 0.4, "%s: breit wie Arcades Zeichnung (%.2f)" % [what, ratio])
		var bad := 0
		var tri := idx.size() / 3
		for t in tri:
			var a := v[idx[t * 3]]
			var b := v[idx[t * 3 + 1]]
			var cc := v[idx[t * 3 + 2]]
			var g := (b - a).cross(cc - a)
			if g.length() < 1.0e-6:
				continue
			# Godot: front faces are clockwise, so the geometric normal of the winding points away from the viewer
			var nm := n[idx[t * 3]] + n[idx[t * 3 + 1]] + n[idx[t * 3 + 2]]
			if g.dot(nm) > 0.0:
				bad += 1
		assert_eq(bad, 0, "%s: jede Fläche nach außen gewunden (%d von %d falsch)" % [what, bad, tri])
		assert_true(tri >= 50 and tri <= 25000, "%s: Dreiecke im Budget eines Wahrzeichens (%d)" % [what, tri])
		assert_eq(int(out["glows"]), int(c["glows"]), "%s: Flugwarn- und Leuchtfeuer" % what)
		assert_eq(out["glow_mesh"] != null, int(c["glows"]) > 0, "%s: Leuchtpunkte als eigenes Netz" % what)


## Depth of a shape's main axis: the mean z of its topmost vertices (spike, antenna, mast – they stand on the axis).
static func _axis_z(v: PackedVector3Array, aabb: AABB) -> float:
	var s := 0.0
	var n := 0
	for p: Vector3 in v:
		if p.y >= aabb.end.y - aabb.size.y * 0.03:
			s += p.z
			n += 1
	return s / float(maxi(1, n))


## Amendment A-19: landmarks never use instance uniforms (each landmark has its own small set of materials).
func test_no_instance_uniforms() -> void:
	var code := FileAccess.get_file_as_string(Landmarks.SHADER_PATH)
	assert_true(code.length() > 1000, "Wahrzeichen-Shader gelesen")
	var re := RegEx.create_from_string("(?m)^\\s*instance\\s+uniform")
	assert_true(re.search(code) == null, "keine Instanz-Uniforms im Wahrzeichen-Shader")
	var src := FileAccess.get_file_as_string("res://scripts/race3d/builders/landmarks.gd")
	assert_false(src.contains("set_instance_shader_parameter"), "der Builder setzt keine Instanz-Uniforms")


## Every material variant compiles its code: the defines select one branch each (the Godot preprocessor), and the
## translucent variants exist for picture, atlas and vertex colours.
func test_variants() -> void:
	var b = Landmarks.new()
	for v: String in ["picture", "atlas", "atlas_cutout", "vcol", "glow"]:
		for blend: bool in [false, true]:
			var sh: Shader = b.shader(v, blend)
			assert_true(sh != null and sh.code.contains("#define"), "%s%s: eigener Shader" % [v, " (durchscheinend)" if blend else ""])
			assert_eq(sh.code.contains("#define CE_BLEND"), blend, "%s: CE_BLEND genau bei der durchscheinenden Variante" % v)
	_cleanup()


## Open point N1 of the reviews: the placement tint of a landmark (tint, × fallback_tint when the fallback set draws)
## reaches its materials – near and far, opaque and translucent – as Arcade multiplies the sprite (RoadRenderer
## _prep_prop: tint × fallback_tint); a procedural shape keeps its catalogue colours (Arcade draws it untinted).
func test_tint_reaches_every_landmark_material() -> void:
	var sets := {"props/church": {"kind": PropLibrary.SPRITE, "extent_l": 5.0, "extent_r": 5.0, "variants": []}}
	var it := {"set": "landmarks/none", "side": 1, "x": 30.0, "z": 0.0, "scale": 2.0, "align": "edge", "tint": "#c0a080",
		"fallback": "props/church", "fallback_scale": 1.5, "fallback_tint": "#80c0ff"}
	var p: Dictionary = Landmarks.resolve_item(it, sets, {})
	var want := Color("#c0a080") * Color("#80c0ff")
	assert_eq(str(p["set"]), "props/church", "das Ersatz-Set zeichnet")
	assert_near(float(p["scale"]), 3.0, 1.0e-5, "mit fallback_scale")
	assert_true((p["tint"] as Color).is_equal_approx(want), "Tönung × Ersatztönung (%s)" % str(p["tint"]))
	var b = Landmarks.new()
	var src := ShaderMaterial.new()
	var pair: Array = b.picture_materials(src, p["tint"])
	for m: ShaderMaterial in pair:
		var t: Variant = m.get_shader_parameter("tint")
		assert_true(t is Vector3 and (t as Vector3).is_equal_approx(Vector3(want.r, want.g, want.b)), "Bild: Tönung im Material (%s)" % str(t))
	for cls: String in ["baked", "baked_cutout", "vpbr"]:
		for m: ShaderMaterial in b.model_materials(cls, ShaderMaterial.new(), p["tint"], {}):
			var t: Variant = m.get_shader_parameter("tint")
			assert_true(t is Vector3 and (t as Vector3).is_equal_approx(Vector3(want.r, want.g, want.b)), "Modell (%s): Tönung im Material" % cls)
	assert_true(b.model_materials("glass", ShaderMaterial.new(), p["tint"], {}).is_empty(), "Glas behält sein Klassenmaterial")
	var pp: Dictionary = Landmarks.resolve_item({"set": "landmarks/none", "side": 1, "x": 30.0, "z": 0.0, "proc": "tv_tower",
		"tint": "#ff0000", "height_m": 100.0}, sets, {})
	assert_eq(int(pp["rep"]), Landmarks.PROC, "prozedural")
	_cleanup()
