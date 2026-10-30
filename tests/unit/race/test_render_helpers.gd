extends TestCase
## Small pure helpers of the race module: GeoBatch (quad batching), Autopilot speed planning,
## backdrop angle wrapping.


func test_geo_batch() -> void:
	var rid := RenderingServer.canvas_item_create()
	var b := GeoBatch.new()
	b.begin(rid)
	assert_true(b.is_empty(), "leer nach begin")
	b.quad(Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.RED)
	b.tri(Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Color.BLUE)
	b.rect(Rect2(0, 0, 10, 10), Color.GREEN)
	assert_eq(b.verts.size(), 12, "vier Ecken je Primitiv")
	assert_eq(b.cols.size(), b.verts.size(), "eine Farbe je Ecke")
	b.flush()
	assert_true(b.is_empty(), "leer nach flush")
	assert_eq(b.triangles, 6, "zwei Dreiecke je Primitiv")
	assert_eq(b.commands, 1, "ein Zeichenbefehl")
	b.ellipse(Vector2(5, 5), Vector2(3, 2), Color.WHITE, Color.WHITE, 12)
	assert_eq(b.verts.size(), 6 * 4, "Ellipse: zwei Fächerdreiecke je Viereck")
	b.flush()
	b.flush()
	assert_eq(b.commands, 2, "leeres flush zeichnet nichts")
	RenderingServer.free_rid(rid)


func test_autopilot_braking_curve() -> void:
	var ap := Autopilot.new()
	assert_near(ap._speed_for(100.0, 0.0), 100.0, 0.001, "am Ziel genau die Zielgeschwindigkeit")
	var v := ap._speed_for(100.0, 100.0)
	var vt := 100.0 / 3.6
	assert_near(v, sqrt(vt * vt + 2.0 * ap.brake_decel_mps2 * 100.0) * 3.6, 0.001, "Bremsweg-Formel")
	assert_true(ap._speed_for(100.0, 200.0) > v, "mehr Abstand, mehr Tempo")
	assert_true(ap._follow_speed(100.0, 200.0, 150.0) > 100.0, "großer Abstand: aufschließen")
	assert_true(ap._follow_speed(100.0, 10.0, 150.0) < 100.0, "zu nah: zurückfallen")


## Mirrored sprites (left roadside): the image covers exactly the unmirrored destination rect
## (Godot keeps the position of a negative-width rect, see tests/race/check_sprite_flip.gd).
func test_sprite_flip_in_place() -> void:
	var anchor := Vector2(0.59, 0.9)
	var dest := RoadRenderer.sprite_dest(Vector2(500.0, 600.0), 200.0, 100.0, anchor, false)
	assert_near(dest.position.x, 500.0 - 0.59 * 200.0, 0.0001, "Anker an der Bodenposition")
	assert_near(dest.position.y, 600.0 - 0.9 * 100.0, 0.0001, "Anker unten")
	var fdest := RoadRenderer.sprite_dest(Vector2(500.0, 600.0), 200.0, 100.0, anchor, true)
	assert_near(fdest.position.x, 500.0 - 0.41 * 200.0, 0.0001, "gespiegelt: Ankerspalte 1 - x")
	var r := RoadRenderer.flipped_draw_rect(fdest)
	assert_near(r.position.x, fdest.position.x, 0.0001, "an Ort und Stelle gespiegelt (keine Verschiebung um die Breite)")
	assert_near(r.size.x, -fdest.size.x, 0.0001, "negative Breite = gespiegelt")
	assert_near(r.size.y, fdest.size.y, 0.0001, "Höhe unverändert")
	assert_true(RoadRenderer.prop_flipped(-1, false, true), "Tag mirror_left links gespiegelt")
	assert_true(RoadRenderer.prop_flipped(-1, true, false), "Regel mirror links gespiegelt")
	assert_false(RoadRenderer.prop_flipped(1, true, true), "rechts nie gespiegelt")


## RENDER-1/RENDER-2 regression: every edge-aligned scenery prop (buildings …) keeps its visible near
## edge exactly at the rule's x on both roadsides – computed through the renderer's own placement
## (edge_anchor_x), destination rect (sprite_dest) and mirroring (flipped_draw_rect) with the real
## sprite manifest. Buildings therefore never reach over sidewalk or road.
func test_edge_aligned_props_keep_their_near_edge() -> void:
	var man: Variant = ConfigLoader.load_json("res://assets/sprites/manifest.json")
	var sets: Dictionary = (man as Dictionary).get("sets", {}) if man is Dictionary else {}
	var sc_data: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var scenery: Dictionary = (sc_data as Dictionary).get("scenery", {}) if sc_data is Dictionary else {}
	var checked := 0
	var mirrored := 0
	for sid: String in scenery:
		for rule: Dictionary in (scenery[sid] as Dictionary).get("props", []):
			if str(rule.get("align", "")) != "edge":
				continue
			var set_id := str(rule["set"])
			if not sets.has(set_id):
				set_id = str(rule.get("fallback", ""))
			if not sets.has(set_id):
				continue
			var info: Dictionary = sets[set_id]
			var cell := Vector2(float(info["cell"][0]), float(info["cell"][1]))
			var ppm := cell.x / float(info["image_width_m"])
			var anchor := Vector2(float(info["anchor"][0]), float(info["anchor"][1]))
			var half := float((info.get("object", {}) as Dictionary).get("width_m", cell.x / ppm * 0.8)) * 0.5
			var ext_a: Array = info.get("extent_m", [half, half])
			var ext := Vector2(float(ext_a[0]), float(ext_a[1]))
			var tag_mirror := (info.get("tags", []) as Array).has("mirror_left")
			var sides: Array[int] = [1, -1]
			if str(rule.get("side", "both")) == "left":
				sides = [-1]
			elif str(rule.get("side", "both")) == "right":
				sides = [1]
			for side in sides:
				for sc: float in [0.8, 1.0, 1.25]:
					var near_x := float(side) * 8.0   # wanted near edge (behind road + sidewalk)
					var flip := RoadRenderer.prop_flipped(side, bool(rule.get("mirror", false)), tag_mirror)
					var ax := RoadRenderer.edge_anchor_x(near_x, side, flip, ext, sc)
					# world metres as "screen": cell width w at this scale
					var w := cell.x / ppm * sc
					var dest := RoadRenderer.sprite_dest(Vector2(ax, 0.0), w, w * cell.y / cell.x, anchor, flip)
					var drawn := RoadRenderer.flipped_draw_rect(dest) if flip else dest
					# object columns in the unmirrored cell, metres from its left border
					var u0 := anchor.x * w - ext.x * sc
					var u1 := anchor.x * w + ext.y * sc
					var left := 0.0
					var right := 0.0
					if drawn.size.x < 0.0:
						# mirrored in place: cell column u lands at position + (|w| - u)
						left = drawn.position.x + (w - u1)
						right = drawn.position.x + (w - u0)
						mirrored += 1
					else:
						left = drawn.position.x + u0
						right = drawn.position.x + u1
					var near := left if side > 0 else right
					assert_near(near, near_x, 0.001, "%s (%s) Seite %d Maßstab %.2f: Vorderkante an der Regelposition" % [set_id, sid, side, sc])
					assert_true((left >= near_x - 0.001) if side > 0 else (right <= near_x + 0.001), "%s ragt nicht zur Straße" % set_id)
					checked += 1
	assert_true(checked > 30, "kantenbündige Requisiten geprüft (%d)" % checked)
	assert_true(mirrored > 0, "gespiegelte Gebäude links geprüft (%d)" % mirrored)


func test_backdrop_wrap() -> void:
	assert_near(RaceBackdrop.wrap_angle(0.0), 0.0, 0.0001, "0")
	assert_near(RaceBackdrop.wrap_angle(TAU + 0.5), 0.5, 0.0001, "volle Drehung")
	assert_near(RaceBackdrop.wrap_angle(-TAU - 0.5), -0.5, 0.0001, "negativ")
	assert_true(RaceBackdrop.wrap_angle(3.5) < 0.0, "über PI wird negativ")
