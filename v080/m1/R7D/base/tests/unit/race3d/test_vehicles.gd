extends TestCase
## Vehicles of the mode "Modern" (contract §6 R3), the pure parts (VehiclePose3D, ModelFactory box stand-in):
## footprint against the collision box at 20 poses incl. the tightest bend, pose conventions (yaw, pitch, roll), the
## articulated semitrailer, the level of detail with hysteresis, the lamp levels of the view flags, the flare points
## and glow sizes against Arcade's constants, wheel spin, the box stand-in.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const R1 := 120.0


func _path(curves: PackedFloat32Array, heights: PackedFloat32Array = PackedFloat32Array()) -> RoadPath3D:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, heights)
	var p := RoadPath3D.new()
	p.setup(t, 0, R1)
	p.ensure(curves.size() - 2)
	return p


## Acceptance: the footprint corners of a placed vehicle lie within 0.3 m of the corners of its collision box (road
## coordinates: rear z .. z + length, x ± width / 2) – 20 poses on a straight, a bend of R = 400 m, the tightest bend
## of the network (R ≈ 136 m, T4) and a tighter one (R = 120 m), in both directions, on a grade, for cars and the
## 16.5 m semitrailer (rigid at the far levels, articulated at lod0).
func test_footprint_matches_collision_box() -> void:
	var cases: Array = []   # [curves, heights, label]
	cases.append([SynTrack.straight(260), PackedFloat32Array(), "gerade"])
	cases.append([SynTrack.arc(260, 400.0), PackedFloat32Array(), "R 400 m"])
	cases.append([SynTrack.arc(260, 136.0), PackedFloat32Array(), "R 136 m (T4)"])
	cases.append([SynTrack.arc(260, -120.0), PackedFloat32Array(), "R 120 m links"])
	cases.append([SynTrack.straight(260), SynTrack.grades(261, [[0, 0.0], [60, 0.07], [130, -0.07]]), "Kuppe und Senke"])
	var vehicles := [[1.82, 4.7, -1.875], [2.55, 16.5, 1.875], [1.86, 4.85, 5.625], [2.02, 5.4, -5.625]]
	var poses := 0
	var worst := 0.0
	var worst_label := ""
	for c: Array in cases:
		var path := _path(c[0], c[1])
		for v: Array in vehicles:
			var w := float(v[0])
			var l := float(v[1])
			var x := float(v[2])
			var z := 300.0 + float(poses % 7) * 23.0
			var pose := VehiclePose3D.chord_pose(path.world(z, x, 0.0), path.world(z + l, x, 0.0))
			var fp := VehiclePose3D.footprint(pose, w, l)
			var want := [path.world(z, x - w * 0.5, 0.0), path.world(z, x + w * 0.5, 0.0), path.world(z + l, x + w * 0.5, 0.0),
				path.world(z + l, x - w * 0.5, 0.0)]
			for i in 4:
				var d := fp[i].distance_to(want[i])
				if d > worst:
					worst = d
					worst_label = "%s, %.1f m langes Fahrzeug" % [str(c[2]), l]
			poses += 1
	assert_eq(poses, 20, "20 Posen")
	assert_true(worst <= 0.3, "Ecken der Grundfläche = Kollisionsquader ± 0,3 m (größte Abweichung %.3f m: %s)" % [worst, worst_label])


func test_articulated_semitrailer_follows_the_bend() -> void:
	var path := _path(SynTrack.arc(260, 136.0))
	var l := 16.5
	var w := 2.55
	var z := 330.0
	var x := 1.875
	var tractor_pivot := Vector3(0.0, 0.0, -3.1)
	var trailer_pivot := Vector3(0.0, 1.19, -3.7)
	var half := l * 0.5
	var lead := VehiclePose3D.lead_unit(path.world(z + half - tractor_pivot.z, x, 0.0), path.world(z + l, x, 0.0), tractor_pivot)
	var trailer := VehiclePose3D.follow_unit(lead, tractor_pivot, trailer_pivot, path.world(z, x, 0.0))
	# the coupling is shared: the kingpin seen from both units is the same point
	var kp_lead := lead * (trailer_pivot - tractor_pivot)
	assert_true(kp_lead.distance_to(trailer.origin) < 1.0e-4, "Königszapfen: beide Einheiten am selben Punkt")
	# the trailer's rear corners and the tractor's front corners on the collision box (± 0.3 m)
	var rear_l := trailer * (Vector3(-w * 0.5, 0.0, half) - trailer_pivot + Vector3(0.0, 0.0, 0.0))
	var rear_r := trailer * (Vector3(w * 0.5, 0.0, half) - trailer_pivot)
	var front_l := lead * (Vector3(-w * 0.5, 0.0, -half) - tractor_pivot)
	var front_r := lead * (Vector3(w * 0.5, 0.0, -half) - tractor_pivot)
	var worst := maxf(maxf(rear_l.distance_to(path.world(z, x - w * 0.5, 0.0)), rear_r.distance_to(path.world(z, x + w * 0.5, 0.0))),
		maxf(front_l.distance_to(path.world(z + l, x - w * 0.5, 0.0)), front_r.distance_to(path.world(z + l, x + w * 0.5, 0.0))))
	assert_true(worst <= 0.3, "Sattelzug in R = 136 m: Ecken auf dem Kollisionsquader (± 0,3 m, %.3f m)" % worst)
	# the units really bend: their headings differ by about the arc between their axles
	var a_lead := atan2(-lead.basis.z.x, -lead.basis.z.z)
	var a_trailer := atan2(-trailer.basis.z.x, -trailer.basis.z.z)
	assert_true(absf(a_lead - a_trailer) > deg_to_rad(2.0), "Zugmaschine und Auflieger knicken (%.1f°)" % rad_to_deg(absf(a_lead - a_trailer)))


func test_pose_conventions() -> void:
	var b := VehiclePose3D.chord_basis(Vector3.ZERO, Vector3(0.0, 0.0, -5.0))
	assert_true(b.is_equal_approx(Basis.IDENTITY), "gerade voraus: Einheitsbasis (−Z = vorn)")
	var right := VehiclePose3D.chord_basis(Vector3.ZERO, Vector3(0.0, 0.0, -5.0), deg_to_rad(10.0))
	assert_true((-right.z).x > 0.15, "Gierwinkel + = Nase nach rechts")
	var up := VehiclePose3D.chord_basis(Vector3.ZERO, Vector3(0.0, 0.5, -5.0))
	assert_true((-up.z).y > 0.09 and up.y.y < 1.0 and up.y.z > 0.0, "Steigung: Nase hebt sich, Dach kippt nach hinten (+Z)")
	assert_near(up.x.length(), 1.0, 1.0e-5, "orthonormal")
	assert_near(up.x.dot(up.y), 0.0, 1.0e-5, "orthonormal")
	var roll := VehiclePose3D.chord_basis(Vector3.ZERO, Vector3(0.0, 0.0, -5.0), 0.0, 2.0)
	assert_true(roll.y.x > 0.03, "Wanken + (Arcade: im Uhrzeigersinn von hinten) = Dach nach rechts")
	var pose := VehiclePose3D.chord_pose(Vector3(1.0, 2.0, 3.0), Vector3(1.0, 2.0, -1.0))
	assert_true(pose.origin.is_equal_approx(Vector3(1.0, 2.0, 1.0)), "Ursprung = Mitte des Kollisionsquaders am Boden")


func test_player_terms() -> void:
	var k := {"steer_deg": 3.0, "lateral_gain": 1.0, "understeer_deg": 6.0, "max_deg": 20.0}
	assert_near(rad_to_deg(VehiclePose3D.player_yaw(1.0, 0.0, 40.0, 0.0, 0.0, k)), 3.0, 1.0e-4, "Lenken × 3°")
	assert_near(rad_to_deg(VehiclePose3D.player_yaw(0.0, 0.0, 40.0, 1.0, 0.5, k)), 6.0, 1.0e-4, "Untersteuern × 6°, Nase in die Kurve")
	assert_near(rad_to_deg(VehiclePose3D.player_yaw(0.0, 0.0, 40.0, 1.0, -0.5, k)), -6.0, 1.0e-4, "… in einer Linkskurve nach links")
	assert_near(VehiclePose3D.player_yaw(0.0, 4.0, 40.0, 0.0, 0.0, k), atan(0.1), 1.0e-5, "Spurwechsel: eigene Richtung aus der Quergeschwindigkeit")
	var roll := VehiclePose.roll_target_deg(VehiclePose3D.lateral_accel(45.0, 1.0, 120.0, 0.0), 0.22, 2.5)
	assert_near(roll, -2.5, 1.0e-4, "Wanken höchstens 2,5°, aus der Kurve hinaus")


func test_lod_with_hysteresis() -> void:
	var model := {"lods": [{"name": "lod0", "max_dist_m": 40}, {"name": "lod1", "max_dist_m": 120}, {"name": "lod2", "max_dist_m": 100000},
		{"name": "show", "max_dist_m": 0}]}
	assert_eq(VehiclePose3D.lod_for(model, 10.0, 1.0, 1.0), "lod0", "nah: lod0")
	assert_eq(VehiclePose3D.lod_for(model, 41.0, 1.0, 1.0), "lod1", "41 m: lod1")
	assert_eq(VehiclePose3D.lod_for(model, 41.0, 1.0, 1.0, "lod0"), "lod0", "Hysterese: lod0 bleibt bis 42 m")
	assert_eq(VehiclePose3D.lod_for(model, 39.0, 1.0, 1.0, "lod1"), "lod1", "Hysterese: zurück erst unter 38 m")
	assert_eq(VehiclePose3D.lod_for(model, 37.0, 1.0, 1.0, "lod1"), "lod0", "unter 38 m wieder lod0")
	assert_eq(VehiclePose3D.lod_for(model, 500.0, 1.0, 1.0), "lod2", "fern: lod2 (show nie nach Entfernung)")
	# quality levels: Details "Niedrig" 25 m / 90 m, "Hoch" 60 m / 160 m
	assert_eq(VehiclePose3D.lod_for(model, 30.0, 25.0 / 40.0, 90.0 / 120.0), "lod1", "Details Niedrig: lod0 bis 25 m")
	assert_eq(VehiclePose3D.lod_for(model, 150.0, 60.0 / 40.0, 160.0 / 120.0), "lod1", "Details Hoch: lod1 bis 160 m")
	var trees := {"lods": [{"name": "lod0", "max_dist_m": 60}, {"name": "lod1", "max_dist_m": 200}], "impostor": {}}
	assert_eq(VehiclePose3D.lod_for(trees, 300.0, 1.0, 1.0), ModelDB.IMPOSTOR, "jenseits der letzten Stufe: Fernbild, wenn es eines gibt")


## Acceptance: the lamps in the snapshot follow the view flags.
func test_lamps_follow_view_flags() -> void:
	var day := {"tail": 0.0, "brake": 0.0}
	assert_eq(VehiclePose3D.lamp_a(day, false), Vector4.ZERO, "Tag, ungebremst: alles aus")
	assert_eq(VehiclePose3D.lamp_a(day, true).x, 1.0, "im Tunnel: Rücklicht an")
	assert_eq(VehiclePose3D.lamp_b(day, true).x, 1.0, "im Tunnel: Scheinwerfer an")
	assert_eq(VehiclePose3D.lamp_a({"tail": 0.6, "brake": 1.0}, false), Vector4(0.6, 1.0, 0.0, 0.0), "Dämmerung: Rücklicht mit den Lichtern der Palette, Bremse")
	var period := RoadRenderer.INDICATOR_PERIOD_S
	var left_on := VehiclePose3D.lamp_a({"blink": -1, "blink_t": 0.1}, false)
	var left_off := VehiclePose3D.lamp_a({"blink": -1, "blink_t": period * 0.5 + 0.05}, false)
	var right_on := VehiclePose3D.lamp_a({"blink": 1, "blink_t": period + 0.1}, false)
	assert_true(left_on.z == 1.0 and left_on.w == 0.0, "Blinker links in der ersten Hälfte der Periode an, rechts aus")
	assert_true(left_off.z == 0.0, "… in der zweiten Hälfte aus")
	assert_true(right_on.w == 1.0 and right_on.z == 0.0, "Blinker rechts, Periode %.2f s" % period)
	for t: float in [0.0, 0.2, 0.37, 0.71, 1.0, 1.5, 3.3]:
		assert_eq(VehiclePose3D.lamp_a({"blink": 1, "blink_t": t}, false).w == 1.0, RoadRenderer.indicator_lit(t), "Blinktakt = Arcade bei %.2f s" % t)
	assert_eq(VehiclePose3D.lamp_b({"beacon": "a"}, false), Vector4(0.0, 0.0, 1.0, 0.0), "Blaulicht A")
	assert_eq(VehiclePose3D.lamp_b({"beacon": "b"}, false), Vector4(0.0, 0.0, 0.0, 1.0), "Blaulicht B")


func test_indicator_constants_equal_arcade() -> void:
	# VehiclePose3D carries copies (it must compile in -s scripts, before RoadRenderer's autoloads exist)
	assert_eq(VehiclePose3D.INDICATOR_PERIOD_S, RoadRenderer.INDICATOR_PERIOD_S, "Blinkperiode = Arcade")
	assert_eq(VehiclePose3D.INDICATOR_MIN_PX, RoadRenderer.INDICATOR_MIN_PX, "kleinste Blinkerlampe = Arcade")
	assert_eq(VehiclePose3D.INDICATOR_MIN_GLOW_PX, RoadRenderer.INDICATOR_MIN_GLOW_PX, "kleinster Blinkerschein = Arcade")
	for i in 60:
		var t := float(i) * 0.037
		assert_eq(VehiclePose3D.indicator_lit(t), RoadRenderer.indicator_lit(t), "Blinktakt = Arcade bei %.3f s" % t)


func test_flares_keep_arcade_sizes() -> void:
	# indicator: core at least INDICATOR_MIN_PX, glow at least INDICATOR_MIN_GLOW_PX (+1 at night)
	var s300 := 711.0 / 300.0
	var core := VehiclePose3D.indicator_core_px(s300)
	assert_true(core.x >= RoadRenderer.INDICATOR_MIN_PX.x and core.y >= RoadRenderer.INDICATOR_MIN_PX.y, "Blinker bei 300 m: Kern %s ≥ %s px" % [str(core), str(RoadRenderer.INDICATOR_MIN_PX)])
	var a := Vector4(0.0, 0.0, 1.0, 0.0)
	for lights: float in [0.0, 1.0]:
		var fp := VehiclePose3D.flare_params("ind_l", a, Vector4.ZERO, lights)
		var r := VehiclePose3D.glow_px(fp.y, s300, fp.z)
		assert_near(r, RoadRenderer.indicator_glow_px(s300, lights), 1.0e-4, "Blinker-Schein = RoadRenderer.indicator_glow_px (Licht %.0f)" % lights)
		assert_near(fp.x, 0.75 + 0.2 * lights, 1.0e-6, "Blinker-Stärke wie Arcade")
		assert_eq(fp.w, VehiclePose3D.KIND_INDICATOR, "Blinker mit Lampenkern")
	# rear lamps: Arcade's glow strength and radius
	var night_brake := VehiclePose3D.flare_params("rear", Vector4(1.0, 1.0, 0.0, 0.0), Vector4.ZERO, 1.0)
	assert_near(night_brake.x, 1.0, 1.0e-6, "Rück + Bremslicht nachts: 0,9 + 0,75 → 1")
	assert_near(night_brake.y, 0.32 + 0.12 + 0.18, 1.0e-6, "Radius (0,32 + 0,12 Bremse + 0,18 Nacht) × s")
	var day_brake := VehiclePose3D.flare_params("rear", Vector4(0.0, 1.0, 0.0, 0.0), Vector4.ZERO, 0.0)
	assert_near(day_brake.x, 0.35, 1.0e-6, "Bremslicht bei Tag: 0,35")
	assert_eq(VehiclePose3D.flare_params("rear", Vector4.ZERO, Vector4.ZERO, 0.0).x, 0.0, "Tag, ungebremst: kein Schein")
	assert_near(VehiclePose3D.glow_px(0.32, 711.0 / 600.0, 2.0), 2.0, 1.0e-6, "Rücklicht-Schein mindestens 2 px")
	assert_near(VehiclePose3D.glow_px(0.32, 711.0 / 1.0, 2.0), 70.0, 1.0e-6, "… höchstens 70 px")


## FIX-M2 (QA-M2-BILD B-03/B-04): a model's brake lights and beacons glow stronger than Arcade's law (the sprite's light
## layer is missing); a tail light alone, indicators and head lamps keep Arcade's strength.
func test_model_glow_gain() -> void:
	var braking := Vector4(0.0, 1.0, 0.0, 0.0)
	var tail := Vector4(1.0, 0.0, 0.0, 0.0)
	assert_near(VehiclePose3D.model_glow_gain("rear", braking), VehiclePose3D.MODEL_BRAKE_GAIN, 1.0e-6, "Bremse voll: MODEL_BRAKE_GAIN")
	assert_near(VehiclePose3D.model_glow_gain("brake", Vector4(0.0, 0.5, 0.0, 0.0)), 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * 0.5,
		1.0e-6, "halbe Bremse: halber Zuschlag")
	assert_near(VehiclePose3D.model_glow_gain("rear", tail), 1.0, 1.0e-6, "nur Rücklicht: Arcades Stärke")
	assert_near(VehiclePose3D.model_glow_gain("beacon_a", Vector4.ZERO), VehiclePose3D.MODEL_BEACON_GAIN, 1.0e-6, "Blaulicht A")
	assert_near(VehiclePose3D.model_glow_gain("beacon_b", Vector4.ZERO), VehiclePose3D.MODEL_BEACON_GAIN, 1.0e-6, "Blaulicht B")
	for role: String in ["ind_l", "ind_r", "head", "marker", "tail"]:
		assert_near(VehiclePose3D.model_glow_gain(role, braking), 1.0, 1.0e-6, "%s: Arcades Stärke" % role)
	assert_true(VehiclePose3D.MODEL_BRAKE_GAIN > 1.0 and VehiclePose3D.MODEL_BEACON_GAIN > 1.0, "Zuschläge > 1")
	# RINT-M2 (A-20): the brake gain is for daylight – at night it fades to MODEL_BRAKE_NIGHT_SHARE of the extra gain,
	# steadily with the palette's lights; the beacon keeps its gain
	var g_night := VehiclePose3D.model_glow_gain("rear", braking, 1.0, 100.0)
	assert_near(g_night, 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * VehiclePose3D.MODEL_BRAKE_NIGHT_FAR, 1.0e-6, "Bremse nachts, fern")
	var g_near := VehiclePose3D.model_glow_gain("rear", braking, 1.0, 10.0)
	assert_near(g_near, 1.0 + (VehiclePose3D.MODEL_BRAKE_GAIN - 1.0) * VehiclePose3D.MODEL_BRAKE_NIGHT_NEAR, 1.0e-6, "Bremse nachts, nah")
	assert_true(g_night > 1.0 and g_near > g_night and g_near < VehiclePose3D.MODEL_BRAKE_GAIN, "nachts zwischen Arcade und Tag, nah mehr als fern (%.2f / %.2f)" % [g_near, g_night])
	assert_near(VehiclePose3D.model_glow_gain("rear", braking, 0.0, 100.0), VehiclePose3D.MODEL_BRAKE_GAIN, 1.0e-6, "bei Tag der volle Zuschlag in jeder Entfernung")
	assert_true(VehiclePose3D.model_glow_gain("rear", braking, 0.5, 60.0) < VehiclePose3D.model_glow_gain("rear", braking, 0.0, 60.0)
		and VehiclePose3D.model_glow_gain("rear", braking, 0.5, 60.0) > VehiclePose3D.model_glow_gain("rear", braking, 1.0, 60.0), "stetig mit den Lichtern")
	assert_near(VehiclePose3D.model_glow_gain("rear", tail, 1.0), 1.0, 1.0e-6, "nachts nur Rücklicht: Arcades Stärke")
	assert_near(VehiclePose3D.model_glow_gain("beacon_a", Vector4.ZERO, 1.0), VehiclePose3D.MODEL_BEACON_GAIN, 1.0e-6, "Blaulicht nachts")
	# the strongest glow stays inside what the flare shader can show (colour × 0.5 × strength ≤ the lamp colour)
	var day := VehiclePose3D.flare_params("rear", braking, Vector4.ZERO, 0.0).x * VehiclePose3D.model_glow_gain("rear", braking)
	var night := VehiclePose3D.flare_params("rear", Vector4(1.0, 1.0, 0.0, 0.0), Vector4.ZERO, 1.0).x \
		* VehiclePose3D.model_glow_gain("rear", braking, 1.0, 20.0)
	var beacon := VehiclePose3D.flare_params("beacon_a", Vector4.ZERO, Vector4(0.0, 0.0, 1.0, 0.0), 1.0).x \
		* VehiclePose3D.model_glow_gain("beacon_a", Vector4.ZERO)
	assert_true(day > 0.35 and day < night and night <= 2.5 and beacon <= 2.0,
		"Stärken Tag %.2f, Nacht %.2f, Blaulicht %.2f" % [day, night, beacon])


## FIX-M2 (QA-M2-BILD B-06): the player's paint in a race is moved towards its luminance by VEHICLE_PLAYER_DESAT; the
## luminance and the metal value stay, keys that are no colour stay as they are.
func test_player_paint_is_desaturated() -> void:
	var src := {"paint": "#1d4ea8", "paint2": "#cc1419", "metal": 0.55}
	var out := ModernMaterials.player_paint(src)
	assert_eq(src["paint"], "#1d4ea8", "die Vorlage bleibt unverändert")
	assert_near(float(out["metal"]), 0.55, 1.0e-6, "Metallwert bleibt")
	for k: String in ["paint", "paint2"]:
		var a := Color(str(src[k]))
		var b := Color(str(out[k]))
		var sat_a := a.s
		var sat_b := b.s
		assert_true(sat_b < sat_a - 0.05,
			"%s: weniger gesättigt (%.3f -> %.3f)" % [k, sat_a, sat_b])
		var la := 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
		var lb := 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
		assert_near(lb, la, 0.01, "%s: Helligkeit bleibt (%.3f / %.3f)" % [k, la, lb])
	assert_true(ModernMaterials.VEHICLE_PLAYER_DESAT > 0.0 and ModernMaterials.VEHICLE_PLAYER_DESAT < 0.5, "Anteil zwischen 0 und 0,5")
	# at night the share fades out (R4's night law holds the paint there)
	var night := ModernMaterials.player_paint(src, 1.0)
	assert_eq(str(night["paint"]).to_lower(), str(src["paint"]).to_lower(), "nachts unverändert")
	var dusk := Color(str(ModernMaterials.player_paint(src, 0.5)["paint"]))
	assert_true(dusk.s < Color(str(src["paint"])).s and dusk.s > Color(str(out["paint"])).s, "Dämmerung dazwischen")
	# FIX-RINT (QA-RINT-BILD F-06): the red sports car keeps a night share of its own – less saturated and darker at
	# night, unchanged by day against the others; a set without an entry as before
	var red := {"paint": "#cc1419"}
	var sw_day := Color(str(ModernMaterials.player_paint(red, 0.0, "player/sportwagen")["paint"]))
	var sw_night := Color(str(ModernMaterials.player_paint(red, 1.0, "player/sportwagen")["paint"]))
	assert_eq(sw_day.to_html(false), Color(str(ModernMaterials.player_paint(red, 0.0)["paint"])).to_html(false), "Sportwagen bei Tag wie alle")
	assert_true(sw_night.s < Color("#cc1419").s - 0.2 and sw_night.v < Color("#cc1419").v, "Sportwagen nachts weniger gesättigt und dunkler (%.2f / %.2f)" % [
		sw_night.s, sw_night.v])
	assert_eq(str(ModernMaterials.player_paint(red, 1.0, "player/limousine")["paint"]).to_lower(), "#cc1419", "ohne Eintrag nachts unverändert")
	assert_near(ModernMaterials.player_fill("player/sportwagen", 0.0), ModernMaterials.VEHICLE_PLAYER_FILL, 1.0e-6, "Füllung bei Tag wie alle")
	assert_true(ModernMaterials.player_fill("player/sportwagen", 1.0) < ModernMaterials.VEHICLE_PLAYER_FILL * 0.6, "Sportwagen nachts weniger Füllung")
	assert_near(ModernMaterials.player_fill("player/limousine", 1.0), ModernMaterials.VEHICLE_PLAYER_FILL, 1.0e-6, "ohne Eintrag unverändert")


func test_flare_points_merge_rear_lamps() -> void:
	var lights := [
		{"role": "brake", "pos": [-0.75, 0.89, 2.29], "dir": [-0.48, 0.25, 0.84], "size": 0.237, "color": "#ff2010"},
		{"role": "brake", "pos": [0.0, 1.32, 1.0], "dir": [0.0, 0.84, 0.54], "size": 0.168, "color": "#ff2010"},
		{"role": "tail", "pos": [-0.75, 0.89, 2.29], "dir": [-0.48, 0.25, 0.84], "size": 0.237, "color": "#ff2010"},
		{"role": "ind_l", "pos": [-0.75, 0.83, 2.31], "dir": [-0.33, 0.04, 0.94], "size": 0.119, "color": "#ffa01a"},
		{"role": "lights", "pos": [0.0, 9.0, 0.0], "size": 0.6, "color": "#fff0cf"}]
	var pts := VehiclePose3D.flare_points(lights)
	var roles: Array[String] = []
	for p: Dictionary in pts:
		roles.append(str(p["role"]))
	assert_eq(roles, ["rear", "brake", "ind_l"] as Array[String], "Rück- und Bremslicht an einer Stelle = ein Schein; dritte Bremsleuchte bleibt; Requisitenlampe nicht")
	assert_true(((pts[0] as Dictionary)["dir"] as Vector3).is_normalized(), "Richtung normiert")
	# every model of the manifest: its rear has glows, its indicators have glows on both sides
	ModelDB.load_manifest()
	for mid: String in ModelDB.model_ids():
		var m := ModelDB.model(mid)
		if not ["vehicle", "heavy"].has(str(m.get("kind", ""))):
			continue
		var rr: Array[String] = []
		for p: Dictionary in VehiclePose3D.flare_points(m.get("lights", [])):
			rr.append(str(p["role"]))
		assert_true(rr.has("rear") or (rr.has("tail") and rr.has("brake")), mid + ": Schein an den Rückleuchten")
		assert_true(rr.has("ind_l") and rr.has("ind_r"), mid + ": Blinker beider Seiten")


func test_wheel_spin_and_steering() -> void:
	var r := 0.32
	var right := VehiclePose3D.wheel_spin(1.0, r, false)
	var left := VehiclePose3D.wheel_spin(1.0, r, true)
	assert_true(right < 0.0 and left > 0.0 and absf(absf(right) - 1.0 / r) < 1.0e-5, "1 m Fahrt = 1 / r rad; links (um 180° gedreht) umgekehrtes Vorzeichen")
	# a point on top of the right wheel moves forward (-Z) when it rolls forward
	var top := Basis(Vector3.RIGHT, VehiclePose3D.wheel_spin(0.05, r, false)) * Vector3(0.0, r, 0.0)
	assert_true(top.z < 0.0, "oben läuft das Rad nach vorn")
	var top_l := (Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, VehiclePose3D.wheel_spin(0.05, r, true))) * Vector3(0.0, r, 0.0)
	assert_true(top_l.z < 0.0, "… auch das linke (um 180° gedrehte) Rad")
	assert_near(VehiclePose3D.steer_angle(2.8, 0.0, 1.0, 7.0), deg_to_rad(7.0), 1.0e-6, "Lenkeinschlag des Spielers")
	assert_true(VehiclePose3D.steer_angle(2.8, 1.0 / 136.0, 0.0, 0.0) > 0.0, "Rechtskurve: Räder nach rechts")


func test_box_stand_in() -> void:
	ModelDB.load_manifest()
	for sid: String in ["traffic/sports_red", "traffic/van_white", "traffic/bus_blue", "police/de"]:
		var obj := ModelDB.object_size(sid)
		var kb := ModelFactory.box_kind(sid, obj)
		var mesh := ModelFactory.box_mesh(obj, str(kb[0]), bool(kb[1]))
		var aabb := mesh.get_aabb()
		var w := float(obj["width_m"])
		var l := float(obj["length_m"])
		var h := float(obj["height_m"])
		assert_true(absf(aabb.size.x - w) < 0.05 and absf(aabb.size.z - l) < 0.05, "%s: Grundfläche = Objektgröße (%s)" % [sid, str(aabb.size)])
		assert_true(aabb.position.y >= -0.001 and aabb.end.y <= h + (0.14 if bool(kb[1]) else 0.001) and aabb.end.y > h - 0.05, "%s: Höhe %.2f m" % [sid, aabb.end.y])
		var arrays := mesh.surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var channels := {}
		for u: Vector2 in uv2:
			if u.x >= 0.0:
				channels[int(floor(u.x))] = true
		assert_true(channels.has(2) and channels.has(3) and channels.has(4), "%s: Rück-/Bremslicht und Blinker als Lampenkanäle" % sid)
		if bool(kb[1]):
			assert_true(channels.has(10) and channels.has(11), "%s: Blaulicht A und B" % sid)
		assert_eq(mesh.surface_get_name(0), "vpbr", "%s: eine vpbr-Fläche" % sid)
		var pts := VehiclePose3D.flare_points(ModelFactory.box_lights(obj, str(kb[0]), bool(kb[1])))
		var roles := {}
		for p: Dictionary in pts:
			roles[str(p["role"])] = true
		assert_true(roles.has("rear") and roles.has("ind_l") and roles.has("ind_r"), "%s: Lichtpunkte des Kastens" % sid)
