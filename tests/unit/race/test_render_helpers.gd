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


func test_backdrop_wrap() -> void:
	assert_near(RaceBackdrop.wrap_angle(0.0), 0.0, 0.0001, "0")
	assert_near(RaceBackdrop.wrap_angle(TAU + 0.5), 0.5, 0.0001, "volle Drehung")
	assert_near(RaceBackdrop.wrap_angle(-TAU - 0.5), -0.5, 0.0001, "negativ")
	assert_true(RaceBackdrop.wrap_angle(3.5) < 0.0, "über PI wird negativ")
