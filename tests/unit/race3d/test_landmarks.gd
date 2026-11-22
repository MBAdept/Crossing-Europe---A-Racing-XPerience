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
		Landmarks.PICTURE, "Elbphilharmonie: Arcades Bild (noch kein Modell)")
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
		assert_true(aabb.end.z <= 0.7 and aabb.end.z > -1.0, "%s: Vorderseite am Anker, der Körper reicht nach -Z (%.2f)" % [what, aabb.end.z])
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
