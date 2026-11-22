extends TestCase
## ChaseCamera3D (kernel of the mode "Modern"): Arcade's projection at every aspect ratio, the engine's frustum,
## the look-into-the-curve yaw, shake – and the Arcade model of the fairness checks against the real renderer.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
const SIZES: Array[Vector2] = [Vector2(1280, 720), Vector2(1280, 800), Vector2(1680, 720)]


func _track(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array(), opts: Dictionary = {}) -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, heights, opts)
	return t


func _path(t: Track) -> RoadPath3D:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	return p


func _base_proj() -> RoadProjection:
	return Fair.make_projection(cfg())


## Arcade's formula for a viewport of `size` logical pixels with the constant focal length of the simulation.
func _arcade_proj(size: Vector2) -> RoadProjection:
	var p := RoadProjection.new()
	p.setup(ConfigLoader.lookup(cfg(), "render", {}), size)
	p.focal = _base_proj().focal
	return p


func _camera(overrides: Dictionary = {}) -> ChaseCamera3D:
	return Fair.make_camera(cfg(), _base_proj(), overrides)


## Acceptance: camera maths <= 0.5 px against RoadProjection on a straight up to 600 m at 1280x720, 1280x800, 1680x720.
func test_straight_matches_arcade_projection() -> void:
	# a straight road over hills: 5 % up, 6 % down, flat
	var heights := SynTrack.grades(400, [[0, 0.05], [90, -0.06], [200, 0.0]])
	var t := _track(SynTrack.straight(400), heights)
	var path := _path(t)
	var cam := _camera()
	assert_near(cam.focal, 640.0 / tan(deg_to_rad(42.0)), 0.01, "Brennweite 711 px wie in Arcade")
	for size: Vector2 in SIZES:
		var proj := _arcade_proj(size)
		var fr := cam.frustum(size)
		var worst := 0.0
		for cam_z: float in [12.0, 190.5, 301.0]:
			for cam_x: float in [-3.75, 0.0, 2.2]:
				var cam_y := t.height_at(cam_z + 9.0) + 3.4
				var xf := cam.transform({"camera_z": cam_z, "camera_x": cam_x, "camera_y": cam_y}, path)
				var d := 10.0
				while d <= 600.0:
					for x: float in [-9.0, -3.75, 0.0, 5.6, 9.0]:
						for h: float in [0.0, 1.5, 4.2]:
							var z := cam_z + d
							var p3 := ChaseCamera3D.project(xf, fr, size, path.world(z, x, h))
							var pa := proj.project(x - cam_x, t.height_at(z) + h - cam_y, d)
							worst = maxf(worst, Vector2(p3.x - pa.x, p3.y - pa.y).length())
							assert_near(p3.z, d, 0.01, "Tiefe = Entfernung auf der Geraden")
					d += 14.75
		assert_true(worst <= 0.5, "%dx%d: größte Abweichung von Arcades Projektion %.4f px (<= 0,5 px)" % [int(size.x), int(size.y), worst])
		assert_true(worst <= 0.05, "%dx%d: tatsächlich unter 0,05 px (%.4f px)" % [int(size.x), int(size.y), worst])


## The frustum values are what the engine's camera needs: ChaseCamera3D.project() equals the engine's own frustum
## projection (Projection.create_frustum_aspect with keep_aspect = KEEP_HEIGHT – what Camera3D.set_frustum() uses).
func test_frustum_matches_engine_projection() -> void:
	var t := _track(SynTrack.arc(300, 400.0), SynTrack.grades(300, [[0, 0.03]]))
	var path := _path(t)
	var cam := _camera()
	for size: Vector2 in SIZES:
		for shake: Vector2 in [Vector2.ZERO, Vector2(3.5, -2.25)]:
			var fr := cam.frustum(size, shake)
			assert_near(float(fr["size"]), cam.near * size.y / cam.focal, 1.0e-9, "size = near · H / Brennweite")
			if shake == Vector2.ZERO:
				assert_near((fr["offset"] as Vector2).y, -0.05 * float(fr["size"]), 1.0e-9, "Horizont auf 45 % der Bildhöhe")
				assert_near((fr["offset"] as Vector2).x, 0.0, 1.0e-12, "kein seitlicher Versatz")
			var xf := cam.transform({"camera_z": 150.0, "camera_x": 1.5, "camera_y": t.height_at(159.0) + 3.4}, path)
			var pm := Projection.create_frustum_aspect(float(fr["size"]), size.x / size.y, fr["offset"], float(fr["near"]), float(fr["far"]), false)
			var worst := 0.0
			for d: float in [8.0, 40.0, 130.0, 420.0]:
				for x: float in [-7.0, 0.0, 9.5]:
					var w := path.world(150.0 + d, x, 0.8)
					var p3 := ChaseCamera3D.project(xf, fr, size, w)
					var v := xf.affine_inverse() * w
					var clip := pm * Vector4(v.x, v.y, v.z, 1.0)
					var e := Vector2((clip.x / clip.w + 1.0) * 0.5 * size.x, (1.0 - clip.y / clip.w) * 0.5 * size.y)
					worst = maxf(worst, Vector2(p3.x, p3.y).distance_to(e))
			assert_true(worst <= 0.01, "%dx%d: project() = Frustum der Engine (%.5f px)" % [int(size.x), int(size.y), worst])


## Shake = the picture moves by `shake` logical pixels (+x right, +y down) like Arcade's draw transform.
func test_shake_moves_the_picture() -> void:
	var t := _track(SynTrack.straight(200))
	var path := _path(t)
	var cam := _camera()
	var size := Vector2(1280, 720)
	var xf := cam.transform({"camera_z": 30.0, "camera_x": 0.0, "camera_y": 3.4}, path)
	var shake := Vector2(4.0, -3.0)
	for d: float in [10.0, 80.0, 500.0]:
		var w := path.world(30.0 + d, 3.0, 1.0)
		var a := ChaseCamera3D.project(xf, cam.frustum(size), size, w)
		var b := ChaseCamera3D.project(xf, cam.frustum(size, shake), size, w)
		assert_near(b.x - a.x, shake.x, 1.0e-3, "Wackeln x bei %.0f m" % d)
		assert_near(b.y - a.y, shake.y, 1.0e-3, "Wackeln y bei %.0f m" % d)
	assert_true(ChaseCamera3D.on_screen(ChaseCamera3D.project(xf, cam.frustum(size), size, path.world(100.0, 0.0, 0.0)), cam.frustum(size), size), "Straße voraus im Bild")
	assert_false(ChaseCamera3D.on_screen(ChaseCamera3D.project(xf, cam.frustum(size), size, path.world(10.0, 0.0, 0.0)), cam.frustum(size), size), "hinter der Kamera nicht im Bild")
	assert_true(ChaseCamera3D.project(xf, cam.frustum(size), size, path.world(10.0, 0.0, 0.0)).z < 0.0, "Tiefe hinter der Kamera negativ")


func test_look_yaw() -> void:
	var cam := _camera()
	assert_near(cam.look_gain, 0.6, 1.0e-6, "look_gain aus der Konfiguration bzw. Standard 0,6")
	assert_near(cam.look_m, 100.0, 1.0e-6, "look_m 100 m")
	assert_near(cam.near, 1.0, 1.0e-6, "nahe Ebene 1 m")
	assert_near(cam.far, 2600.0, 1.0e-6, "ferne Ebene 2600 m")
	# straight: no yaw
	var ps := _path(_track(SynTrack.straight(200)))
	assert_near(cam.look_yaw(ps, 60.0), 0.0, 1.0e-9, "Gerade: kein Blickwinkel")
	# constant bend: the bearing of a point 100 m along an arc is half its turning
	for radius: float in [400.0, -400.0, 200.0]:
		var p := _path(_track(SynTrack.arc(200, radius)))
		var want := 0.6 * (100.0 / absf(radius)) * 0.5 * signf(radius)
		assert_near(cam.look_yaw(p, 90.0), want, 2.0e-4, "Kreisbogen R %.0f m: 0,6 × halber Drehwinkel über 100 m" % radius)
		assert_near(cam.look_yaw(p, 91.3), want, 2.0e-4, "auch zwischen zwei Segmentgrenzen")
		var xf := cam.transform({"camera_z": 90.0, "camera_x": 0.0, "camera_y": 3.4}, p)
		var fwd := -xf.basis.z
		assert_true((fwd - RoadPath3D.fwd_of(p.heading_at(90.0) + want)).length() < 1.0e-3, "die Kamera blickt in die Kurve")
		assert_near(xf.basis.y.y, 1.0, 1.0e-6, "keine Neigung")
		assert_near(fwd.y, 0.0, 1.0e-6, "kein Nicken")
	# the tightest bend of the game stays below the limit; a smaller limit clamps
	var pt := _path(_track(SynTrack.arc(200, 134.0)))
	var tight := cam.look_yaw(pt, 90.0)
	assert_between(rad_to_deg(tight), 12.0, 13.5, "R 134 m: etwa 12,8°")
	assert_true(tight < cam.yaw_max, "unter der Grenze von 14°")
	assert_near(_camera({"yaw_max_deg": 5.0}).look_yaw(pt, 90.0), deg_to_rad(5.0), 1.0e-6, "yaw_max_deg begrenzt")
	assert_near(_camera({"look_gain": 0.0}).look_yaw(pt, 90.0), 0.0, 1.0e-12, "look_gain 0: Tangentenkamera")
	# position only: the same place gives the same yaw whatever else the view says
	var a := cam.transform({"camera_z": 120.0, "camera_x": 0.0, "camera_y": 3.4, "speed": 10.0, "time": 1.0}, pt)
	var b := cam.transform({"camera_z": 120.0, "camera_x": 0.0, "camera_y": 3.4, "speed": 250.0, "time": 77.0, "shake": Vector2(3, 3)}, pt)
	assert_true(a.is_equal_approx(b), "Blickwinkel hängt nur vom Ort ab")
	# the camera position: on the path, camera_x to the right of the road direction, camera_y as given
	var c := cam.transform({"camera_z": 120.0, "camera_x": 2.5, "camera_y": 9.9}, pt)
	var want_pos := pt.centre_at(120.0) + RoadPath3D.right_of(pt.heading_at(120.0)) * 2.5
	assert_true(Vector2(c.origin.x - want_pos.x, c.origin.z - want_pos.z).length() < 1.0e-4, "Kamera seitlich entlang der Straßenquerrichtung versetzt")
	assert_near(c.origin.y, 9.9, 1.0e-5, "Kamerahöhe aus der Ansicht")
	# near the end of the road the look point is the last boundary – no error, no jump to zero
	var pe := _path(_track(SynTrack.arc(60, 300.0)))
	assert_true(absf(cam.look_yaw(pe, 170.0)) < cam.yaw_max + 1.0e-9, "am Streckenende begrenzt")


## The Arcade model of the fairness checks (Fairness.arcade_x) is the real renderer's row accumulation.
func test_arcade_model_matches_road_renderer() -> void:
	var n := 700
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = 0.6 * sin(float(i) * 0.021) + 0.25 * sin(float(i) * 0.0063 + 1.0)
	var t := _track(curves, SynTrack.grades(n, [[0, 0.02], [150, -0.03], [330, 0.01]]))
	var geo := Fair.geo_of_track(cfg(), t, "test")
	var proj := _base_proj()
	var r := RoadRenderer.new()
	r.setup(t, proj, cfg(), {})
	var worst_x := 0.0
	var worst_px := 0.0
	for c: int in [5, 120, 301]:
		var cam_y := t.height_at(float(c + 3) * 3.0) + proj.cam_height
		r.view = {"camera_z": float(c) * 3.0, "camera_x": 0.0, "camera_y": cam_y}
		r._vis = 900.0
		r._fog_start = 405.0
		r._project()
		for k in range(1, 250, 7):
			worst_x = maxf(worst_x, absf(r._xw[k] - Fair.arcade_x(geo, c, k)))
			var pa := proj.project(Fair.arcade_x(geo, c, k), t.get_segment(c + k).y - cam_y, float(k) * 3.0)
			worst_px = maxf(worst_px, Vector2(r._sx[k] - pa.x, r._sy[k] - pa.y).length())
	r.free()
	assert_true(worst_x <= 0.01, "seitlicher Versatz der Reihen wie RoadRenderer._project (%.5f m)" % worst_x)
	assert_true(worst_px <= 0.05, "Bildpunkte wie RoadRenderer._project (%.4f px)" % worst_px)


## In bends the true 3D picture differs from Arcade's sheared one by a few pixels near the car (tangent camera,
## look_gain 0). On a constant arc that starts at the camera – the worst case – the road points (centre and
## ± 5.6 m) differ by at most 8 px up to 150 m at R 400 m and 27 px up to 100 m at R 136 m (the design study measured
## <= 6 px and 11–22 px at real positions, where the bend does not have its full curvature all the way).
func test_curve_parity_bounds() -> void:
	var cam := _camera({"look_gain": 0.0})
	var proj := _base_proj()
	var size := Vector2(1280, 720)
	for case: Array in [[400.0, 150.0, 8.0], [136.0, 100.0, 27.0]]:
		var radius: float = case[0]
		var t := _track(SynTrack.arc(300, radius))
		var geo := Fair.geo_of_track(cfg(), t, "arc")
		var path: RoadPath3D = geo["path"]
		var c := 20
		var xf := cam.transform({"camera_z": float(c) * 3.0, "camera_x": 0.0, "camera_y": proj.cam_height}, path)
		var fr := cam.frustum(size)
		var worst := 0.0
		var k := 4
		while float(k) * 3.0 <= float(case[1]):
			for x: float in [-5.6, 0.0, 5.6]:
				var p3 := ChaseCamera3D.project(xf, fr, size, path.world(float(c + k) * 3.0, x, 0.0))
				var pa := proj.project(Fair.arcade_x(geo, c, k) + x, -proj.cam_height, float(k) * 3.0)
				worst = maxf(worst, absf(p3.x - pa.x))
			k += 1
		assert_true(worst <= float(case[2]), "R %.0f m bis %.0f m: Fahrbahnpunkte höchstens %.0f px neben Arcade (%.1f px)" % [radius, float(case[1]), float(case[2]), worst])
		assert_true(worst > 0.5, "in der Kurve ist das echte 3D-Bild nicht pixelgleich (%.1f px) – sonst prüft der Test nichts" % worst)
