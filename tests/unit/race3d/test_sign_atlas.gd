extends TestCase
## Signs of the mode "Modern" (contract §6 R3): the sign atlas (catalogue, keys, geometry measured from Arcade's own
## SignPainter) and the meshes of the sign builder – every sign kind Track can emit (the kinds of
## SignPainter.HALF_WIDTH_M) gets a board of Arcade's width at Arcade's height and the posts Arcade draws.

const SIGNS_BUILDER := "res://scripts/race3d/builders/signs.gd"
const Fix := preload("res://tests/sim/fixtures.gd")


func _painter() -> Array:
	var batch := GeoBatch.new()
	var painter := SignPainter.new()
	painter.setup(null, batch)
	return [painter, batch]


func _item(kind: String) -> Dictionary:
	var it := {"kind": "sign", "sign": kind, "value": 100, "text": "Hamburg", "country": "DE", "road": "autobahn", "side": 1}
	match kind:
		"curve", "chevron":
			it["value"] = 1
		"distance":
			it["value"] = 25
		"town_ahead":
			it["value"] = 4
			it["limit"] = 50
		"radar", "fuel":
			it["text"] = "2 km"
		"tunnel":
			it["text"] = "Elbtunnel"
			it["value"] = 3300
	return it


## Acceptance: every sign kind Track can emit is drawn – the kinds of SignPainter.HALF_WIDTH_M.
func test_every_kind_has_board_and_posts() -> void:
	var pb := _painter()
	var kinds: Array = SignPainter.HALF_WIDTH_M.keys()
	assert_true(kinds.size() >= 15, "alle Schildarten von SignPainter (%d)" % kinds.size())
	for kind: String in kinds:
		var m := SignAtlas.measure(_item(kind), pb[0], pb[1])
		var b: Rect2 = m["bounds"]
		var hw := SignPainter.board_half_width(kind)
		assert_true(b.size.x > 0.5 and b.size.y > 0.3, "%s: Tafel gezeichnet (%s m)" % [kind, str(b.size)])
		assert_true(absf(b.size.x - 2.0 * hw) <= 0.3 * hw + 0.12, "%s: Breite %.2f m ≈ 2 × HALF_WIDTH_M (%.2f m)" % [kind, b.size.x, 2.0 * hw])
		assert_true(b.position.y >= 0.9 and b.end.y <= 5.0, "%s: Tafel %.2f … %.2f m über dem Boden (wie Arcade)" % [kind, b.position.y, b.end.y])
		var posts: Array = m["posts"]
		assert_true(posts.size() >= 1 and posts.size() <= 2, "%s: Pfosten wie Arcade (%d)" % [kind, posts.size()])
		for p: Vector3 in posts:
			assert_true(p.y > 0.05 and p.y < 0.2 and p.z >= b.position.y - 0.05 and p.z <= b.end.y + 0.05, "%s: Pfosten %s m bis an die Tafel" % [kind, str(p)])
		var wall := _item(kind)
		wall["wall"] = true
		assert_eq((SignAtlas.measure(wall, pb[0], pb[1])["posts"] as Array).size(), 0, "%s: an der Tunnelwand ohne Pfosten" % kind)


func test_keys() -> void:
	var a := _item("limit")
	var b := a.duplicate()
	b["country"] = "FR"
	b["road"] = "landstrasse"
	b["side"] = -1
	b["z"] = 999.0
	assert_eq(SignAtlas.key_of(a), SignAtlas.key_of(b), "Tempolimit: Land, Straße, Seite und Ort ändern das Bild nicht")
	var c := a.duplicate()
	c["value"] = 80
	assert_true(SignAtlas.key_of(a) != SignAtlas.key_of(c), "… der Wert schon")
	var d := _item("distance")
	var e := d.duplicate()
	e["road"] = "landstrasse"
	assert_true(SignAtlas.key_of(d) != SignAtlas.key_of(e), "Entfernungstafel: Autobahn- und Landstraßenfarben verschieden")
	var f := d.duplicate()
	f["country"] = "CH"
	assert_true(SignAtlas.key_of(d) != SignAtlas.key_of(f), "… und je Land")
	var g := _item("curve")
	var h := g.duplicate()
	h["value"] = -1
	assert_true(SignAtlas.key_of(g) != SignAtlas.key_of(h), "Kurve links und rechts verschieden")
	h["value"] = 1
	h["country"] = "IT"
	assert_eq(SignAtlas.key_of(g), SignAtlas.key_of(h), "Warnzeichen sehen in jedem Land gleich aus")


## The catalogue of a real stage: the events of Track with their country and road, the signs Track places while it
## generates; the headless atlas (placeholder) has a cell for every one, nothing is missing.
func test_stage_catalogue() -> void:
	var c := cfg()
	var plan := Fix.make_plan(c, 60.0, [30.0], [{"km": 20.0, "limit": 100}])
	plan.to_name = "Hamburg"
	var track := Track.new()
	track.setup(plan, c, {})
	var items := SignAtlas.stage_signs(track, plan)
	var kinds := {}
	for it: Dictionary in items:
		kinds[str(it["sign"])] = true
		assert_true(it.has("country") and it.has("road"), "%s: Land und Straße der Stelle" % str(it["sign"]))
	for k: String in ["limit", "radar", "fuel", "town", "town_ahead", "distance", "curve", "crest", "chevron"]:
		assert_true(kinds.has(k), "Katalog enthält %s (%s)" % [k, str(kinds.keys())])
	var atlas := SignAtlas.new()
	atlas.prepare(items, null, {})
	assert_true(atlas.ready and atlas.placeholder, "ohne Szene: Platzhalter-Atlas, sofort fertig")
	assert_eq(atlas.pending(), 0, "nichts offen")
	for it: Dictionary in items:
		assert_false(atlas.entry(it).is_empty(), "Zelle für %s" % SignAtlas.key_of(it))
	assert_eq(atlas.missing, 0, "kein Schild ohne Zelle")
	# cells inside the atlas, not overlapping
	var rects: Array[Rect2] = []
	for k: Variant in atlas.entries:
		var uv: Rect2 = (atlas.entries[k] as Dictionary)["uv"]
		assert_true(uv.position.x >= 0.0 and uv.position.y >= 0.0 and uv.end.x <= 1.0 and uv.end.y <= 1.0, "Zelle im Atlas: %s" % str(k))
		for r: Rect2 in rects:
			assert_false(r.intersects(uv), "Zellen überlappen nicht: %s" % str(k))
		rects.append(uv)


## The builder's mesh: one board quad per sign at Arcade's height (scaled), its UVs = the atlas cell, the posts down
## to the ground; a wall sign has no posts.
func test_builder_mesh() -> void:
	var script: GDScript = load(SIGNS_BUILDER)
	var signs := [{"z": 100.0, "x": 8.0, "scale": 1.0, "wall": false, "tunnel": false, "bounds": Rect2(-0.85, 1.9, 1.7, 1.7),
		"uv": Rect2(0.1, 0.2, 0.05, 0.05), "posts": [Vector3(0.0, 0.11, 2.75)], "colour": Color.WHITE},
		{"z": 130.0, "x": 7.0, "scale": 0.6, "wall": true, "tunnel": true, "bounds": Rect2(-2.4, 2.65, 4.8, 1.35),
		"uv": Rect2(0.3, 0.2, 0.2, 0.05), "posts": [], "colour": Color.WHITE}]
	var d: Dictionary = script.call(&"_sign_arrays", signs, null)
	var v: PackedVector3Array = d["v"]
	var uv: PackedVector2Array = d["uv"]
	var uv2: PackedVector2Array = d["uv2"]
	var c: PackedColorArray = d["c"]
	# first sign: 4 board vertices + 5 post faces x 4
	assert_eq(v.size(), 4 + 20 + 4, "zwei Tafeln, ein Pfosten (fünf Flächen)")
	assert_true(v[0].is_equal_approx(Vector3(-0.85, 1.9, 0.0)) and v[2].is_equal_approx(Vector3(0.85, 3.6, 0.0)), "Tafel in Arcades Höhe")
	assert_true(uv[1].is_equal_approx(Vector2(0.1, 0.2)) and uv[3].is_equal_approx(Vector2(0.15, 0.25)), "UVs = Atlaszelle (oben links = oben links)")
	assert_eq(c[0].a, 1.0, "Tafel: Alpha 1")
	assert_eq(c[4].a, 0.0, "Pfosten: Alpha 0")
	var low := INF
	for i in range(4, 24):
		low = minf(low, v[i].y)
	assert_true(low < -0.2, "Pfosten reicht in den Boden (%.2f m)" % low)
	assert_true(v[24].is_equal_approx(Vector3(-2.4 * 0.6, 2.65 * 0.6, 0.0)), "Wandschild skaliert, ohne Pfosten")
	assert_eq(uv2[0], Vector2(100.0, 0.0), "UV2 = (z des Schildes, Tunnel)")
	assert_eq(uv2[24], Vector2(130.0, 1.0), "UV2 im Tunnel")
	var idx: PackedInt32Array = d["idx"]
	var a := v[idx[0]]
	var b := v[idx[1]]
	var e := v[idx[2]]
	assert_true((b - a).cross(e - a).z < 0.0, "Tafel im Uhrzeigersinn von vorn (Godots Vorderseite zeigt zum Verkehr)")
