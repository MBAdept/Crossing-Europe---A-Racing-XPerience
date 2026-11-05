extends TestCase
## Glow occlusion (v0.5.1, docs/renn-modul.md §2): lights of hidden sources must not shine through nearer road,
## vehicles or tunnel walls. Pure helpers of RoadRenderer and GeoBatch; the rendering itself is checked under Xvfb
## by tests/race/check_glow_occlusion.gd.


## Source visibility at the crest line: 1 above, 0.5 on the line, 0 below, linear over the bright core (0.25 r, at
## least 0.75 px) – a light sinking behind a crest fades out with its lamp, no halo cap is left above the crest.
func test_glow_visibility_at_the_crest_line() -> void:
	assert_near(RoadRenderer.glow_visibility(280.0, 300.0, 8.0), 1.0, 0.0001, "weit über der Kuppenlinie sichtbar")
	assert_near(RoadRenderer.glow_visibility(300.0, 300.0, 8.0), 0.5, 0.0001, "auf der Linie halb")
	assert_near(RoadRenderer.glow_visibility(320.0, 300.0, 8.0), 0.0, 0.0001, "darunter verdeckt")
	# r = 8: core 2 px -> visible from 2 px above the line, hidden from 2 px below
	assert_near(RoadRenderer.glow_visibility(298.0, 300.0, 8.0), 1.0, 0.0001, "Kern ganz über der Linie")
	assert_near(RoadRenderer.glow_visibility(302.0, 300.0, 8.0), 0.0, 0.0001, "Kern ganz unter der Linie")
	assert_near(RoadRenderer.glow_visibility(301.0, 300.0, 8.0), 0.25, 0.0001, "linear dazwischen")
	# small glows: the core never gets thinner than 0.75 px (no flicker from sub-pixel steps)
	assert_near(RoadRenderer.glow_visibility(300.375, 300.0, 1.0), 0.25, 0.0001, "kleiner Kern mindestens 0,75 px")
	assert_near(RoadRenderer.glow_visibility(10.0, 1.0e9, 4.0), 1.0, 0.0001, "ohne Boden davor (Linie 1e9) sichtbar")
	var last := 2.0
	for i in 41:
		var v := RoadRenderer.glow_visibility(290.0 + float(i) * 0.5, 300.0, 12.0)
		assert_true(v <= last + 1.0e-6, "monoton fallend beim Absinken (y %.1f)" % (290.0 + float(i) * 0.5))
		last = v


## Part of a glow below the ground line in front of its slice: assigned to the nearer rows whose ground covers it
## (running minimum row_clip): contiguous bands from the line to the bottom of the glow, top to bottom.
func test_glow_bands_follow_the_nearer_ground() -> void:
	# flat road: row 0 at the camera (no ground), then rows rising towards the horizon
	var flat := PackedFloat32Array([1.0e9, 700.0, 600.0, 500.0, 450.0, 420.0, 400.0])
	var b := RoadRenderer.glow_bands(405.0, 440.0, 420.0, flat, 5)
	assert_eq(b.size(), 3, "ein Band")
	assert_near(b[0], 420.0, 0.001, "beginnt an der Bodenlinie")
	assert_near(b[1], 440.0, 0.001, "endet am Rand des Leuchtens")
	assert_eq(int(b[2]), 4, "auf dem Boden der Zeilen 4..5")
	b = RoadRenderer.glow_bands(405.0, 520.0, 420.0, flat, 5)
	assert_eq(b.size(), 9, "drei Bänder")
	var expect := [[420.0, 450.0, 4], [450.0, 500.0, 3], [500.0, 520.0, 2]]
	for i in 3:
		assert_near(b[i * 3], float(expect[i][0]), 0.001, "Band %d oben" % i)
		assert_near(b[i * 3 + 1], float(expect[i][1]), 0.001, "Band %d unten" % i)
		assert_eq(int(b[i * 3 + 2]), int(expect[i][2]), "Band %d Zeile" % i)
	# crest: rows 3..5 lie behind the crest of row 3 (running minimum stays 300); the part below the crest line
	# belongs to the crest slice (rows 2..3), not to the hidden rows in between
	var crest := PackedFloat32Array([1.0e9, 700.0, 500.0, 300.0, 300.0, 300.0])
	b = RoadRenderer.glow_bands(280.0, 330.0, 300.0, crest, 5)
	assert_eq(b.size(), 3, "Kuppe: ein Band")
	assert_near(b[0], 300.0, 0.001, "Kuppe: ab der Kuppenlinie")
	assert_eq(int(b[2]), 2, "Kuppe: auf dem Boden der Kuppe")
	# the rest below the nearest row with ground goes to the slice at the camera
	b = RoadRenderer.glow_bands(650.0, 760.0, 700.0, flat, 1)
	assert_eq(b.size(), 3, "an der Kamera: ein Band")
	assert_eq(int(b[2]), 0, "an der Kamera: Zeile 0")
	assert_near(b[1], 760.0, 0.001, "bis zum Rand")
	# a glow entirely above the line has no bands
	assert_eq(RoadRenderer.glow_bands(380.0, 410.0, 420.0, flat, 5).size(), 0, "über der Linie: keine Bänder")


## Atlas of the painter's-order glows: 72 × 64, gradient in x 0–63 (radially symmetric, transparent corners, bright
## centre, falling outwards), x 64–67 copies of column 63, x 68–71 white. Byte-exact equality with the
## GradientTexture2D of the layer needs a real renderer (tests/race/check_glow_occlusion.gd).
func test_glow_atlas() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	var img := RoadRenderer.glow_atlas_image(g)
	assert_eq(img.get_width(), 72, "Breite")
	assert_eq(img.get_height(), 64, "Höhe")
	assert_eq(img.get_format(), Image.FORMAT_RGBA8, "RGBA8")
	assert_false(img.has_mipmaps(), "ohne Mipmaps")
	var d := img.get_data()
	var px := func(x: int, y: int) -> PackedByteArray: return d.slice((y * 72 + x) * 4, (y * 72 + x) * 4 + 4)
	assert_eq(px.call(0, 0)[3], 0, "Ecke durchsichtig")
	assert_true(px.call(32, 32)[3] > 240, "Mitte hell")
	for y in 64:
		for x in range(64, 68):
			assert_eq(px.call(x, y), px.call(63, y), "Rand = Spalte 63 (Zeile %d)" % y)
		for x in range(68, 72):
			assert_eq(px.call(x, y), PackedByteArray([255, 255, 255, 255]), "weißer Block")
	for y in [5, 20, 31, 40]:
		for x in 64:
			assert_eq(px.call(x, y), px.call(63 - x, y), "symmetrisch in x")
			assert_eq(px.call(y, x), px.call(y, 63 - x), "symmetrisch in y")
	var last := 256
	for x in range(32, 64):
		var a: int = px.call(x, 32)[3]
		assert_true(a <= last, "fällt nach außen (x %d)" % x)
		last = a
	# the white block is sampled by GeoBatch.WHITE_UV, the gradient ends at GLOW_U1
	assert_near(GeoBatch.WHITE_UV.x * 72.0, 70.0, 0.0001, "WHITE_UV in der Mitte des weißen Blocks")
	assert_near(GeoBatch.GLOW_U1 * 72.0, 64.0, 0.0001, "Verlauf endet bei x 64")


## Glow quads in the batch: ordinary quads with flagged atlas UVs (u + 2), every other vertex samples the white
## block; one triangle-array command; without glow quads no UVs and no texture as before.
func test_geo_batch_glow_quads() -> void:
	var rid := RenderingServer.canvas_item_create()
	var b := GeoBatch.new()
	b.begin(rid)
	b.rect(Rect2(0, 0, 10, 10), Color.RED)
	b.glow_rect(20.0, 30.0, 60.0, 50.0, Color(1, 0.5, 0, 0.8), 0.25, 0.75)
	b.tri(Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Color.BLUE)
	assert_eq(b.pending_glows(), 1, "ein Leuchtviereck")
	assert_eq(b.verts.size(), 12, "drei Vierecke")
	assert_eq(b.verts[4], Vector2(20, 30), "Ecke oben links")
	assert_eq(b.verts[6], Vector2(60, 50), "Ecke unten rechts")
	var uv := b.glow_uvs()
	assert_eq(uv.size(), 12, "eine UV je Ecke")
	for i in [0, 1, 2, 3, 8, 9, 10, 11]:
		assert_eq(uv[i], GeoBatch.WHITE_UV, "normale Ecke %d: weißer Block" % i)
	assert_eq(uv[4], Vector2(2.0, 0.25), "Leuchten oben links: u + 2, v0")
	assert_eq(uv[5], Vector2(2.0 + GeoBatch.GLOW_U1, 0.25), "oben rechts")
	assert_eq(uv[6], Vector2(2.0 + GeoBatch.GLOW_U1, 0.75), "unten rechts: v1")
	assert_eq(uv[7], Vector2(2.0, 0.75), "unten links")
	for i in 12:
		assert_true((uv[i].x > 1.5) == (i >= 4 and i < 8), "nur das Leuchtviereck ist markiert (Ecke %d)" % i)
	b.flush()
	assert_eq(b.commands, 1, "ein Zeichenbefehl")
	assert_eq(b.glow_quads, 1, "Statistik")
	assert_eq(b.pending_glows(), 0, "nach flush leer")
	b.rect(Rect2(0, 0, 5, 5), Color.GREEN)
	b.flush()
	assert_eq(b.commands, 2, "ohne Leuchten wie bisher")
	b.begin(rid)
	assert_eq(b.glow_quads, 0, "begin setzt die Statistik zurück")
	RenderingServer.free_rid(rid)


## Tunnel window: running intersection of the tube cross-sections from the camera. Straight tube: a lamp on the
## haunch of a farther row lies inside (on the edge of its own row: still fully visible); in a bend the farther
## lamps on the outer side are behind the nearer wall; capped tube: nothing beyond; before the tunnel: unbounded.
func test_tunnel_window() -> void:
	var wall_h := 4.2
	var ceil_h := 6.2
	var haunch := 1.8
	var n := 12
	var tun := PackedByteArray()
	var sx := PackedFloat32Array()
	var sy := PackedFloat32Array()
	var ss := PackedFloat32Array()
	var xl := PackedFloat32Array()
	var xr := PackedFloat32Array()
	for k in n:
		var dz := 6.0 + float(k) * 6.0
		var s := 711.0 / dz
		tun.append(1 if k >= 2 else 0)        # rows 0, 1 outside, the tube from row 2
		ss.append(s)
		sx.append(640.0)
		sy.append(324.0 + 3.4 * s)
		xl.append(-7.0)
		xr.append(7.0)
	var w := RoadRenderer.tunnel_window(tun, sx, sy, ss, xl, xr, wall_h, ceil_h, haunch, n + 1)
	assert_eq(w.size(), n * RoadRenderer.TUNNEL_WINDOW_STRIDE, "fünf Werte je Zeile")
	var lamp := func(k: int, side: float) -> Vector2:
		# lamp on the haunch: (wall_h + ceil_h) / 2 high, haunch / 2 inside the wall
		var x := (xl[k] + haunch * 0.5) if side < 0.0 else (xr[k] - haunch * 0.5)
		return Vector2(sx[k] + x * ss[k], sy[k] - (wall_h + ceil_h) * 0.5 * ss[k])
	var o := 4 * RoadRenderer.TUNNEL_WINDOW_STRIDE
	assert_near(RoadRenderer.tunnel_window_visibility(lamp.call(8, 1.0), 6.0, w, o, wall_h, ceil_h, haunch), 1.0, 0.0001, "gerade: fernere Lampe sichtbar")
	assert_near(RoadRenderer.tunnel_window_visibility(lamp.call(4, -1.0), 6.0, w, o, wall_h, ceil_h, haunch), 1.0, 0.0001, "Lampe am Rand der eigenen Zeile sichtbar")
	assert_near(RoadRenderer.tunnel_window_visibility(Vector2(640.0 + 9.0 * ss[4], sy[4] - 2.0 * ss[4]), 6.0, w, o, wall_h, ceil_h, haunch), 0.0, 0.0001, "hinter der Wand verdeckt")
	assert_near(RoadRenderer.tunnel_window_visibility(Vector2(640.0, 10.0), 6.0, w, o, wall_h, ceil_h, haunch), 0.0, 0.0001, "über der Decke verdeckt")
	assert_near(RoadRenderer.tunnel_window_visibility(Vector2(5.0, 300.0), 6.0, w, 0, wall_h, ceil_h, haunch), 1.0, 0.0001, "vor dem Tunnel unbegrenzt")
	# right bend: from row 6 on the tube shifts to the right on screen -> the right-hand lamps of the far rows lie
	# beyond the right wall of the nearer rows
	var sx2 := sx.duplicate()
	for k in range(6, n):
		sx2[k] = 640.0 + float(k - 5) * 40.0
	var w2 := RoadRenderer.tunnel_window(tun, sx2, sy, ss, xl, xr, wall_h, ceil_h, haunch, n + 1)
	var far_right := Vector2(sx2[10] + (xr[10] - haunch * 0.5) * ss[10], sy[10] - (wall_h + ceil_h) * 0.5 * ss[10])
	var o9 := 9 * RoadRenderer.TUNNEL_WINDOW_STRIDE
	assert_near(RoadRenderer.tunnel_window_visibility(far_right, 4.0, w2, o9, wall_h, ceil_h, haunch), 0.0, 0.0001, "Kurve: Lampe hinter der inneren Wand verdeckt")
	var far_left := Vector2(sx2[10] + (xl[10] + haunch * 0.5) * ss[10], sy[10] - (wall_h + ceil_h) * 0.5 * ss[10])
	assert_true(RoadRenderer.tunnel_window_visibility(far_left, 4.0, w2, o9, wall_h, ceil_h, haunch) > 0.99, "Kurve: Lampe an der äußeren Wand sichtbar")
	# capped tube (seen from outside, render.tunnel.peek_m): nothing visible from the cap on
	var w3 := RoadRenderer.tunnel_window(tun, sx, sy, ss, xl, xr, wall_h, ceil_h, haunch, 6)
	assert_near(RoadRenderer.tunnel_window_visibility(lamp.call(8, 1.0), 6.0, w3, 7 * RoadRenderer.TUNNEL_WINDOW_STRIDE, wall_h, ceil_h, haunch), 0.0, 0.0001, "hinter dem Abschluss verdeckt")
	assert_near(RoadRenderer.tunnel_window_visibility(lamp.call(8, 1.0), 6.0, w3, o, wall_h, ceil_h, haunch), 1.0, 0.0001, "davor sichtbar")


func test_point_in_quad() -> void:
	var a := Vector2(0, 0)
	var b := Vector2(10, 0)
	var c := Vector2(12, 8)
	var d := Vector2(-2, 8)
	assert_true(RoadRenderer.point_in_quad(Vector2(5, 4), a, b, c, d), "innen")
	assert_true(RoadRenderer.point_in_quad(Vector2(5, 4), d, c, b, a), "andere Umlaufrichtung")
	assert_true(RoadRenderer.point_in_quad(Vector2(5, 0), a, b, c, d), "Kante gehört dazu")
	assert_false(RoadRenderer.point_in_quad(Vector2(11, 1), a, b, c, d), "außen neben der schrägen Kante")
	assert_false(RoadRenderer.point_in_quad(Vector2(5, 9), a, b, c, d), "außen unten")
	assert_false(RoadRenderer.point_in_quad(Vector2(0, 0), a, a, a, a), "entartet: enthält nichts")
	assert_false(RoadRenderer.point_in_quad(Vector2(5, 0), a, b, b, a), "Fläche null: enthält nichts")


## Rows -> scene slices (the deferred glow bands are drawn after the ground of the slice that holds their rows).
func test_slice_of_row() -> void:
	var r := RoadRenderer.new()
	r._sl_a = PackedInt32Array([1, 2, 3, 6, 30])
	r._sl_b = PackedInt32Array([2, 3, 6, 30, 31])
	assert_eq(r._slice_of_row(0), -1, "vor der ersten Scheibe")
	assert_eq(r._slice_of_row(1), 0, "erste Scheibe")
	assert_eq(r._slice_of_row(4), 2, "in einer zusammengefassten Scheibe")
	assert_eq(r._slice_of_row(6), 3, "Anfang einer Scheibe")
	assert_eq(r._slice_of_row(29), 3, "Ende einer Scheibe")
	assert_eq(r._slice_of_row(30), 4, "letzte Scheibe")
	assert_eq(r._slice_of_row(31), -1, "hinter der letzten Scheibe")
	assert_eq(r._slice_of_row(-1), -1, "negative Zeile")
	r.free()
