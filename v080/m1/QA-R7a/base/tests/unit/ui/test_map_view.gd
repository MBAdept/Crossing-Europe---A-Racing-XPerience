extends TestCase
## MapView auto-fit math and the latlon fallback projection.


func test_fit_keeps_points_inside_and_aspect() -> void:
	var pts: Array[Vector2] = [Vector2(100, 50), Vector2(300, 90), Vector2(180, 400)]
	var size := Vector2(640, 360)
	var xf := MapView.compute_fit(pts, size, 0.1, 10.0)
	for p in pts:
		var q := xf * p
		assert_true(q.x >= 0.0 and q.x <= size.x and q.y >= 0.0 and q.y <= size.y, "Punkt im Bild: %s" % q)
	assert_near(xf.get_scale().x, xf.get_scale().y, 0.0001, "gleichmäßige Skalierung")
	var c := xf * Vector2(200, 225)
	assert_near(c.x, size.x * 0.5, 0.5, "zentriert x")
	assert_near(c.y, size.y * 0.5, 0.5, "zentriert y")


func test_fit_min_span_for_single_stage() -> void:
	var pts: Array[Vector2] = [Vector2(400, 120), Vector2(405, 140)]
	var xf := MapView.compute_fit(pts, Vector2(600, 600), 0.0, 100.0)
	assert_near(xf.get_scale().x, 6.0, 0.001, "Mindestausschnitt 100 Karteneinheiten")


func test_fit_degenerate() -> void:
	var none: Array[Vector2] = []
	assert_eq(MapView.compute_fit(none, Vector2(100, 100), 0.1, 10.0), Transform2D.IDENTITY, "keine Punkte")


func test_latlon_projection_orientation() -> void:
	var kiel := MapView.project_latlon(54.32, 10.12)
	var munich := MapView.project_latlon(48.14, 11.58)
	var paris := MapView.project_latlon(48.86, 2.35)
	assert_true(kiel.y < munich.y, "Norden oben")
	assert_true(paris.x < munich.x, "Westen links")
