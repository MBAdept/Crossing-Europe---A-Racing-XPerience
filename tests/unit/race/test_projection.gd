extends TestCase
## RoadProjection: camera maths, player position on screen, 1/3-visibility rule.


func _proj() -> RoadProjection:
	var p := RoadProjection.new()
	p.setup(ConfigLoader.lookup(cfg(), "render", {}), Vector2(1280, 720))
	return p


func test_project_basics() -> void:
	var p := _proj()
	var v := p.project(0.0, 0.0, 10.0)
	assert_near(v.x, 640.0, 0.001, "Mitte")
	assert_near(v.y, p.horizon_y, 0.001, "Augenhöhe = Horizont")
	assert_near(v.z, p.focal / 10.0, 0.0001, "Maßstab = focal / dz")
	assert_true(p.project(1.0, 0.0, 10.0).x > 640.0, "+x rechts")
	assert_true(p.project(0.0, 1.0, 10.0).y < p.horizon_y, "+y oben")
	assert_near(p.project(0.0, 0.0, 0.0).z, p.focal / p.near, 0.001, "nahe Ebene begrenzt")
	var fov := float(ConfigLoader.lookup(cfg(), "render.fov_deg", 84.0))
	assert_near(p.focal, 640.0 / tan(deg_to_rad(fov) * 0.5), 0.01, "Brennweite aus fov")


func test_ground_rows() -> void:
	var p := _proj()
	var prev := INF
	for dz: float in [2.0, 5.0, 10.0, 50.0, 200.0, 900.0]:
		var y := p.ground_row(dz)
		assert_true(y < prev and y > p.horizon_y, "Boden steigt zum Horizont an (dz %.0f)" % dz)
		assert_near(p.depth_at_row(y), dz, 0.001, "depth_at_row ist die Umkehrung")
		prev = y
	assert_eq(p.depth_at_row(p.horizon_y - 5.0), INF, "über dem Horizont kein Boden")


func test_player_car_on_screen() -> void:
	var p := _proj()
	# rear bottom edge of a 4.85 m car: low in the picture but completely visible
	var y := p.ground_row(p.cam_distance - 4.85 * 0.5)
	assert_between(y, 620.0, 700.0, "Wagenheck unten in der Bildmitte")
	var width_px := 1.86 * p.scale_at(p.cam_distance - 4.85 * 0.5)
	assert_between(width_px, 150.0, 300.0, "Wagenbreite im Bild")
	assert_between(p.horizon_y / p.screen.y, 0.38, 0.5, "Horizont im oberen Bilddrittel/-hälfte")


func test_visible_fraction_rule() -> void:
	var p := _proj()
	assert_eq(p.visible_fraction(0.1, 1.5), 0.0, "hinter der Kamera unsichtbar")
	var prev := 0.0
	var dz := 0.5
	while dz < 30.0:
		var f := p.visible_fraction(dz, 1.5)
		assert_true(f >= prev - 0.0001, "monoton bei dz %.1f" % dz)
		prev = f
		dz += 0.25
	assert_near(p.visible_fraction(60.0, 1.5), 1.0, 0.0001, "weit vorn ganz sichtbar")
	# the threshold lies between the camera and the player's rear bumper
	var thr := 0.5
	while p.visible_fraction(thr, 1.5) < 1.0 / 3.0:
		thr += 0.05
	assert_true(thr > 1.0 and thr < p.cam_distance, "1/3 sichtbar bei dz %.2f" % thr)
	assert_true(p.visible_fraction(2.0, 4.0) < p.visible_fraction(2.0, 1.5) + 0.5, "hohe Lkw brauchen länger")


func test_view_angle() -> void:
	var p := _proj()
	assert_near(p.view_angle(0.0, 10.0), 0.0, 0.0001, "geradeaus")
	assert_near(p.view_angle(10.0, 10.0), PI / 4.0, 0.0001, "45 Grad")
