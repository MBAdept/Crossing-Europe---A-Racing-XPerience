extends TestCase
## Vehicle display v2 (docs/fahrzeug-darstellung.md §2/§3): display yaw of rear-pivot ortho sprites with the
## vehicle length, critically damped smoothing, cell hysteresis, visible yaw and roll of the player car.
## Road model for the perspective checks: the camera looks along the road tangent at its own position; a road
## of constant curvature k has the lateral offset k * d² / 2 at depth d (the renderer's curve accumulation).

const YAWS17: Array[float] = [-24.0, -21.0, -18.0, -15.0, -12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0]
const YAWS5: Array[float] = [-25.0, -12.0, 0.0, 12.0, 25.0]


func _proj() -> RoadProjection:
	var p := RoadProjection.new()
	p.setup(ConfigLoader.lookup(cfg(), "render", {}), Vector2(1280, 720))
	return p


func _yaws(a: Array[float]) -> PackedFloat32Array:
	return PackedFloat32Array(a)


func _road_x(k: float, d: float) -> float:
	return k * d * d * 0.5


## The old renderer: point formula with hard thresholds (6.5° / 18.5°) on the 5 legacy cells.
func _old_cell_deg(yaw_deg: float) -> float:
	if yaw_deg > 18.5:
		return 25.0
	if yaw_deg > 6.5:
		return 12.0
	if yaw_deg < -18.5:
		return -25.0
	if yaw_deg < -6.5:
		return -12.0
	return 0.0


## Playtest: a 16.5 m truck in the neighbour lane 30 m ahead (straight road) must be turned only slightly.
func test_truck_in_neighbour_lane_gets_a_small_yaw() -> void:
	var lane_w := float(ConfigLoader.lookup(cfg(), "road.lane_width_m", 3.75))
	var psi := rad_to_deg(VehiclePose.ortho_yaw(30.0, lane_w, 0.0, 0.0, 16.5))
	assert_between(absf(psi), 4.0, 5.0, "Lkw 30 m voraus in der Nachbarspur: Darstellungswinkel")
	assert_true(psi < 0.0, "rechts der Kamera: linke Flanke sichtbar (negativer Winkel)")
	var old := rad_to_deg(VehiclePose.point_yaw(30.0, lane_w, 0.0))
	assert_near(absf(_old_cell_deg(old)), 12.0, 0.001, "die alte Punktformel wählte die 12°-Zelle")
	assert_near(absf(old), 7.1, 0.1, "alte Punktformel")
	# the 17-angle sheet shows it within half a step, the old 5-angle sheet straight (0° is nearest)
	var c17 := VehiclePose.pick_cell(_yaws(YAWS17), psi, -1)
	assert_true(absf(YAWS17[c17] - psi) <= 1.5 + 0.0001, "17 Winkel: nächste Zelle %.0f°" % YAWS17[c17])
	assert_eq(VehiclePose.pick_cell(_yaws(YAWS5), psi, -1), 2, "5 Winkel: c")


## The front centre of the sprite (rotated about its rear, drawn at the scale of the rear) lands where the true
## perspective shows the front of the vehicle – for cars and trucks, in curves and beside the camera axis.
func test_front_centre_matches_true_perspective() -> void:
	var p := _proj()
	var lane_w := 3.75
	var worst := 0.0
	var worst_old := 0.0
	var n := 0
	for k: float in [0.0, 0.9 / 120.0, -0.9 / 120.0, 0.35 / 120.0, -0.35 / 120.0]:
		for d_r: float in [8.0, 15.0, 30.0, 60.0, 120.0]:
			for x: float in [-lane_w, 0.0, lane_w, 2.0 * lane_w]:
				for length: float in [4.5, 12.8, 16.5]:
					var xr_road := _road_x(k, d_r)
					var xf_road := _road_x(k, d_r + length)
					var h := VehiclePose.chord_heading(xr_road, xf_road, length)
					var psi := VehiclePose.ortho_yaw(d_r, xr_road + x, h, 0.0, length)
					if absf(rad_to_deg(psi)) >= 29.9:
						continue   # limited (not reached on screen with these numbers)
					var s_r := p.scale_at(d_r)
					var sx_r := p.screen.x * 0.5 + (xr_road + x) * s_r
					var drawn := VehiclePose.ortho_front_x(sx_r, s_r, length, psi)
					var truth := p.project(xf_road + x, 0.0, d_r + length).x
					worst = maxf(worst, absf(drawn - truth))
					var old := VehiclePose.point_yaw(d_r, xr_road + x, atan(k * d_r))
					worst_old = maxf(worst_old, absf(VehiclePose.ortho_front_x(sx_r, s_r, length, old) - truth))
					n += 1
	assert_true(n > 250, "Fälle geprüft (%d)" % n)
	assert_true(worst < 0.5, "Front an der wahren Position (größte Abweichung %.3f px)" % worst)
	assert_true(worst_old > 40.0, "zum Vergleich die alte Punktformel (bis %.0f px daneben)" % worst_old)


## Lane change: the own heading (lateral speed) turns the sprite so that its front leads in the new direction.
func test_own_heading_during_lane_change() -> void:
	var p := _proj()
	var psi_c := VehiclePose.own_heading(2.5, 120.0 / 3.6)
	assert_near(rad_to_deg(psi_c), 4.29, 0.02, "2,5 m/s quer bei 120 km/h")
	assert_eq(VehiclePose.own_heading(2.5, 0.2), 0.0, "im Stand keine Eigenrichtung")
	for d_r: float in [10.0, 25.0, 50.0]:
		for x: float in [-3.75, 0.0, 3.75]:
			var length := 4.6
			var psi := VehiclePose.ortho_yaw(d_r, x, 0.0, psi_c, length)
			var s_r := p.scale_at(d_r)
			var sx_r := p.screen.x * 0.5 + x * s_r
			# true front of a car turned by psi_c relative to the (straight) road
			var truth := p.project(x + length * sin(psi_c), 0.0, d_r + length * cos(psi_c)).x
			assert_near(VehiclePose.ortho_front_x(sx_r, s_r, length, psi), truth, 1.5, "Spurwechsel d %.0f x %.2f" % [d_r, x])
	assert_true(VehiclePose.ortho_yaw(20.0, 0.0, 0.0, psi_c, 4.6) > 0.0, "nach rechts unterwegs: nach rechts gedreht")


func test_yaw_is_limited() -> void:
	assert_near(rad_to_deg(VehiclePose.ortho_yaw(1.0, -40.0, 0.0, 0.0, 4.5)), 30.0, 0.0001, "auf +30° begrenzt")
	assert_near(rad_to_deg(VehiclePose.ortho_yaw(1.0, 40.0, 0.0, 0.0, 4.5)), -30.0, 0.0001, "auf -30° begrenzt")
	assert_near(rad_to_deg(VehiclePose.ortho_yaw(1.0, 40.0, 0.0, 0.0, 4.5, 12.0)), -12.0, 0.0001, "eigene Grenze")


## Critically damped follower: no overshoot, exact for any frame time, ~95 % after 4.75 time constants.
func test_critically_damped_smoothing() -> void:
	var tau := 0.12
	for dt: float in [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 0.1]:
		var v := Vector2.ZERO
		var t := 0.0
		var prev := 0.0
		while t < 4.75 * tau - 0.0001:
			v = VehiclePose.damp(v.x, v.y, 1.0, dt, tau)
			t += dt
			assert_true(v.x <= 1.0 + 1e-9, "kein Überschwingen (dt %.4f)" % dt)
			assert_true(v.x >= prev - 1e-9, "monoton (dt %.4f)" % dt)
			prev = v.x
		var expected := 1.0 - (1.0 + t / tau) * exp(-t / tau)
		assert_near(v.x, expected, 1e-6, "geschlossene Lösung nach %.3f s (dt %.4f)" % [t, dt])
	var a := VehiclePose.damp(0.0, 0.0, 1.0, 4.75 * tau, tau)
	assert_near(a.x, 0.95, 0.002, "95 % nach 4,75 Zeitkonstanten")
	assert_eq(VehiclePose.damp(0.3, 0.2, 1.0, 0.0, tau), Vector2(0.3, 0.2), "dt 0 (Pause): unverändert")
	assert_eq(VehiclePose.damp(0.3, 0.2, 1.0, 0.016, 0.0), Vector2(1.0, 0.0), "ohne Glättung: sofort")


## A car on a constant curve (yaw near a cell boundary, frame jitter and noise) keeps its cell.
func test_no_cell_flicker_on_a_constant_curve() -> void:
	var yaws := _yaws(YAWS17)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for target: float in [4.5, 4.4, -10.6, 13.5]:
		var cell := -1
		var changes := -1
		var changes_plain := -1
		var plain := -1
		var v := Vector2(target, 0.0)
		for i in 900:
			var dt := rng.randf_range(1.0 / 75.0, 1.0 / 40.0)
			var noisy := target + rng.randf_range(-0.4, 0.4)
			v = VehiclePose.damp(v.x, v.y, noisy, dt, 0.12)
			var c := VehiclePose.pick_cell(yaws, v.x, cell, 0.3)
			if c != cell:
				changes += 1
				cell = c
			var c0 := VehiclePose.pick_cell(yaws, noisy, plain, 0.0)
			if c0 != plain:
				changes_plain += 1
				plain = c0
		assert_eq(changes, 0, "Kurve mit konstantem Winkel %.1f°: Zellwechsel" % target)
		if absf(fposmod(target, 3.0) - 1.5) < 0.2:
			assert_true(changes_plain > 20, "ohne Glättung und Hysterese flackert es (%d Wechsel)" % changes_plain)


## Hysteresis: the cell switches only when the new one is more than 0.3 steps closer; a slow sweep switches
## once per boundary in each direction.
func test_cell_hysteresis_band() -> void:
	var yaws := _yaws(YAWS17)
	var c0 := VehiclePose.pick_cell(yaws, 0.0, -1)
	assert_eq(YAWS17[c0], 0.0, "Start bei 0°")
	assert_eq(VehiclePose.pick_cell(yaws, 1.9, c0), c0, "1,9°: noch 0°")
	assert_eq(YAWS17[VehiclePose.pick_cell(yaws, 2.0, c0)], 3.0, "2,0°: 3° liegt um mehr als 0,3 Schritte näher")
	var c3 := VehiclePose.pick_cell(yaws, 2.0, c0)
	assert_eq(VehiclePose.pick_cell(yaws, 1.1, c3), c3, "zurück erst unter 1,05°")
	assert_eq(YAWS17[VehiclePose.pick_cell(yaws, 1.0, c3)], 0.0, "1,0°: zurück auf 0°")
	assert_eq(YAWS17[VehiclePose.pick_cell(yaws, 11.0, c0)], 12.0, "großer Sprung: sofort die nächste Zelle")
	var cell := -1
	var switches := 0
	var y := -24.0
	while y <= 24.0:
		var c := VehiclePose.pick_cell(yaws, y, cell)
		if c != cell and cell >= 0:
			switches += 1
			assert_eq(absi(c - cell), 1, "nur Nachbarzellen beim langsamen Schwenk")
		cell = c
		y += 0.05
	assert_eq(switches, 16, "ein Wechsel je Grenze")
	# legacy sheets: 12° / 13° steps
	var legacy := _yaws(YAWS5)
	assert_eq(VehiclePose.pick_cell(legacy, 7.7, 2), 2, "5 Winkel: bis 7,8° bleibt c")
	assert_eq(VehiclePose.pick_cell(legacy, 7.9, 2), 3, "5 Winkel: danach r1")


func test_player_yaw_components() -> void:
	var k := {"curve_gain": 1.0, "steer_deg": 3.0, "lateral_gain": 1.0, "understeer_deg": 4.0, "view_gain": 1.0, "max_deg": 20.0}
	assert_near(VehiclePose.player_yaw_target(0.0, 0.0, 0.0, 40.0, 0.0, 0.0, 0.0, k), 0.0, 1e-9, "geradeaus")
	assert_true(VehiclePose.player_yaw_target(0.08, 0.0, 0.0, 40.0, 0.0, 1.0, 0.0, k) > 0.0, "Rechtskurve voraus: nach rechts")
	assert_true(VehiclePose.player_yaw_target(-0.08, 0.0, 0.0, 40.0, 0.0, -1.0, 0.0, k) < 0.0, "Linkskurve voraus: nach links")
	assert_near(rad_to_deg(VehiclePose.player_yaw_target(0.0, 1.0, 0.0, 40.0, 0.0, 0.0, 0.0, k)), 3.0, 1e-6, "Lenkeinschlag")
	assert_near(VehiclePose.player_yaw_target(0.0, 0.0, 4.0, 40.0, 0.0, 0.0, 0.0, k), atan(0.1), 1e-6, "Querbewegung")
	assert_near(rad_to_deg(VehiclePose.player_yaw_target(0.0, 0.0, 0.0, 40.0, 1.0, 1.0, 0.0, k)), 4.0, 1e-6, "Untersteuern rechts: Nase nach innen")
	assert_near(rad_to_deg(VehiclePose.player_yaw_target(0.0, 0.0, 0.0, 40.0, 1.0, -1.0, 0.0, k)), -4.0, 1e-6, "Untersteuern links")
	assert_near(VehiclePose.player_yaw_target(0.0, 0.0, 0.0, 40.0, 0.0, 0.0, 0.1, k), -0.1, 1e-6, "rechts der Kameraachse: von links gesehen")
	assert_near(rad_to_deg(VehiclePose.player_yaw_target(1.0, 1.0, 30.0, 10.0, 0.0, 0.0, 0.0, k)), 20.0, 1e-6, "begrenzt auf player_yaw_max_deg")


## The rendered view of a car beside the camera axis equals a centred view turned by the view angle: with the
## view-angle term the perspective sprite's rear and front stay where the true perspective shows them.
func test_player_view_angle_keeps_rear_and_front_in_place() -> void:
	var p := _proj()
	var d := p.cam_distance
	var half_l := 4.85 * 0.5
	for dx: float in [-1.1, -0.5, 0.5, 1.1]:
		var view := atan2(dx, d)
		var psi := VehiclePose.player_yaw_target(0.0, 0.0, 0.0, 40.0, 0.0, 0.0, view, {"view_gain": 1.0})
		# centred render of a car turned by psi, translated by the anchor (scale of the centre)
		for end: float in [-1.0, 1.0]:
			var x_in_render := end * half_l * sin(psi)
			var z_in_render := d + end * half_l * cos(psi)
			var drawn := p.screen.x * 0.5 + dx * p.scale_at(d) + p.focal * x_in_render / z_in_render
			var truth := p.project(dx, 0.0, d + end * half_l).x
			assert_near(drawn, truth, 1.5, "Spieler %.1f m neben der Achse, %s" % [dx, "Front" if end > 0.0 else "Heck"])


func test_roll_and_perspective_scale() -> void:
	assert_near(VehiclePose.roll_target_deg(9.0, 0.22, 2.5), -1.98, 1e-6, "Rechtskurve: Aufbau neigt nach links (gegen den Uhrzeigersinn)")
	assert_near(VehiclePose.roll_target_deg(-9.0, 0.22, 2.5), 1.98, 1e-6, "Linkskurve")
	assert_near(VehiclePose.roll_target_deg(40.0, 0.22, 2.5), -2.5, 1e-6, "höchstens 2,5°")
	assert_near(VehiclePose.perspective_scale(9.0, 9.0, 1.25), 0.8, 1e-6, "Standardkamera: 1 / supersample")
	assert_near(VehiclePose.perspective_scale(9.0, 18.0, 2.0), 0.25, 1e-6, "doppelte Tiefe: halbe Größe")
