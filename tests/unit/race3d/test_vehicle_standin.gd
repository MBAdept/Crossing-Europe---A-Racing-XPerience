extends TestCase
## Stand-ins of vehicle sets without a model in the mode "Modern" (R3E, VehicleStandIn, layers/vehicles.gd): Arcade's
## own picture. Checked against the frozen Arcade code itself wherever it can run without a scene:
##  * the cell of a traffic car = RoadRenderer._vehicle_cell (ortho yaw formula, damping, hysteresis) over many
##    roads, lanes, lane changes and frames; the player's cell = RoadRenderer._update_player_pose + its cell pick
##    (21 angles);
##  * the inputs taken from the 3D camera = Arcade's on a straight road; the fold = Arcade's flank warp columns;
##    the fold rule = RoadRenderer._car_warp's; the modulate = RoadRenderer._modulate after _prepare/_project (time
##    of day, tunnel, fog, headlights, lamps);
##  * which picture a set gets: a sprite set without a model the sprite stand-in, a box set the textured box, a set
##    with a model its model (unchanged), a sheet that was not prepared the painted box – and no sheet is loaded
##    while driving;
##  * the textured box: faces with their pictures, the articulated units of a two-part set (AS1's coupling);
##  * the pulled perspective picture: the same pixels, its lowest row above the road.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const FIXTURES := "res://tests/fixtures/sprites/manifest.json"
const LAYER := "res://scripts/race3d/layers/vehicles.gd"
const YAWS17: Array = [-24.0, -21.0, -18.0, -15.0, -12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0]


func _yaws(list: Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	for v: float in list:
		y.append(v)
	return y


func _yaws21() -> PackedFloat32Array:
	var y := PackedFloat32Array()
	for i in 21:
		y.append(-20.0 + 2.0 * float(i))
	return y


## A RoadRenderer (never in the tree) with the projected rows _project() would give for a camera at z = 0 on a road
## whose centre lies at lateral x(d) = x0 + c d² in front of it (c = 1 / (2 R): a bend; the camera axis along the
## road at the camera) – the members _vehicle_cell, road_at and _update_player_pose read.
func _arcade(x0: float, c: float, rows: int = 140) -> RoadRenderer:
	var rr := RoadRenderer.new()
	var dz := PackedFloat32Array()
	var zw := PackedFloat32Array()
	var xw := PackedFloat32Array()
	var yw := PackedFloat32Array()
	for k in rows + 1:
		var d := float(k) * 3.0
		dz.append(d)
		zw.append(d)
		xw.append(x0 + c * d * d)
		yw.append(0.0)
	rr.set("_seg_len", 3.0)
	rr.set("_base", 0)
	rr.set("_n", rows)
	rr.set("_dz", dz)
	rr.set("_zw", zw)
	rr.set("_xw", xw)
	rr.set("_yw", yw)
	rr.set("_cam_y", 0.0)
	return rr


## Arcade's sprite info array with the entries _vehicle_cell reads (yaws, object size, angle names).
func _info(yaws: PackedFloat32Array, obj: Vector3) -> Array:
	var info: Array = []
	info.resize(22)
	info[RoadRenderer.SI_YAWS] = yaws
	info[RoadRenderer.SI_OBJ] = obj
	info[RoadRenderer.SI_COLS] = {"c": int(yaws.size() / 2)}
	return info


## Acceptance (R3E): the cell of every traffic stand-in is the one Arcade shows – RoadRenderer._vehicle_cell itself
## against VehicleStandIn.traffic_cell with the same inputs, frame by frame (damping and hysteresis included), on a
## straight road and in bends of R = 400 / 136 m both ways, in every lane, near and far, holding the lane and
## changing it.
func test_traffic_cell_equals_arcade() -> void:
	var yaws := _yaws(YAWS17)
	var compared := 0
	var cells := {}
	var worst_yaw := 0.0
	var mismatch := ""
	var cases := [[0.0, 0.0], [-1.875, 0.0], [0.0, 1.0 / 800.0], [1.875, -1.0 / 800.0], [0.0, 1.0 / 272.0], [-3.75, -1.0 / 272.0]]
	var id := 1
	for cs: Array in cases:
		var rr := _arcade(float(cs[0]), float(cs[1]))
		var info := _info(yaws, Vector3(1.82, 4.7, 1.48))
		for dist: float in [6.0, 11.0, 20.0, 35.0, 60.0, 110.0, 200.0, 320.0]:
			for lane: float in [-7.5, -3.75, 0.0, 3.75]:
				for change: float in [0.0, 2.2, -1.6]:
					var st := PackedFloat32Array([0.0, 0.0, -1.0])
					var x := lane
					var z := dist
					var t := 0.0
					for f in 40:
						rr.set("view", {"time": t})
						rr.call("_pose_tick")
						var k := int(floor(z / 3.0))
						var fr := (z - float(k) * 3.0) / 3.0
						var it := {"z": z, "x": x, "speed": 110.0, "id": id, "length": 4.7}
						var a_cell := int(rr.call("_vehicle_cell", k, fr, it, info))
						var poses: Dictionary = rr.get("_poses")
						var pst: PackedFloat64Array = poses[id]
						# the same inputs from the rows (what VehicleStandIn.view_inputs gives on Arcade's road)
						var d_r := lerpf(float((rr.get("_dz") as PackedFloat32Array)[k]), float((rr.get("_dz") as PackedFloat32Array)[k + 1]), fr)
						var xr := lerpf(float((rr.get("_xw") as PackedFloat32Array)[k]), float((rr.get("_xw") as PackedFloat32Array)[k + 1]), fr)
						var h := VehiclePose.chord_heading(xr, (rr.call("road_at", z + 4.7) as Vector3).x, 4.7)
						var psi_c := VehiclePose.own_heading(pst[5], 110.0 / 3.6)
						var m_cell := VehicleStandIn.traffic_cell(st, yaws, Vector3(d_r, xr + x, h), psi_c, 4.7, float(rr.get("_veh_max_deg")),
							float(rr.get("_pose_dt")), float(rr.get("_veh_tau")), float(rr.get("_veh_hyst")))
						compared += 1
						cells[a_cell] = true
						worst_yaw = maxf(worst_yaw, absf(pst[0] - st[0]))
						if a_cell != m_cell and mismatch == "":
							mismatch = "R-Fall %s, %.0f m, Spur %.2f, Wechsel %.1f, Bild %d: Arcade %d, Modern %d" % [str(cs), dist, lane, change, f, a_cell, m_cell]
						t += 1.0 / 60.0
						x += change / 60.0
						z += 1.0 / 60.0 * 8.0
					id += 1
		rr.free()
	assert_eq(mismatch, "", "Zelle = RoadRenderer._vehicle_cell")
	assert_true(compared >= 20000, "viele Fälle verglichen (%d)" % compared)
	assert_true(cells.size() >= 12, "viele verschiedene Zellen getroffen (%d von 17)" % cells.size())
	assert_true(worst_yaw < 1.0e-5, "Darstellungswinkel gleich (größte Abweichung %.8f rad)" % worst_yaw)


## Acceptance (R3E): the cell of the player's stand-in (21 angles) is the one Arcade shows –
## RoadRenderer._update_player_pose and the cell pick of _draw_player against VehicleStandIn.player_cell: steering,
## lane change, understeer in a bend, the car beside the camera axis, frame by frame.
func test_player_cell_equals_arcade() -> void:
	var yaws := _yaws21()
	var k := {"curve_gain": 1.0, "steer_deg": 3.0, "lateral_gain": 1.0, "understeer_deg": 6.0, "view_gain": 1.0, "max_deg": 20.0}
	var compared := 0
	var cells := {}
	var mismatch := ""
	for cs: Array in [[0.0, 0.0, 0.0], [0.0, 1.0 / 272.0, 120.0 / 136.0], [0.8, -1.0 / 800.0, -120.0 / 400.0]]:
		var rr := _arcade(float(cs[0]), float(cs[1]))
		var track: Track = SynTrack.new()
		track.fill(cfg(), SynTrack.arc(200, 120.0 / float(cs[2])) if float(cs[2]) != 0.0 else SynTrack.straight(200))
		rr.set("track", track)
		rr.set("_pl_k", k)
		var st := PackedFloat32Array([0.0, 0.0, -1.0, 0.0])
		var t := 0.0
		for f in 300:
			rr.set("view", {"time": t})
			rr.call("_pose_tick")
			var steer := sin(float(f) * 0.05) * 0.9
			var lat := 2.5 * sin(float(f) * 0.021)
			var under := clampf(sin(float(f) * 0.013), 0.0, 1.0)
			var it := {"steer": steer, "lat_speed": lat, "understeer": under}
			var zc := 11.4 + float(f) * 0.03
			var xc := (rr.call("road_at", zc) as Vector3).x + sin(float(f) * 0.017) * 1.2
			var dc := maxf((rr.call("road_at", zc) as Vector3).z, 0.3)
			var speed := 36.0
			rr.call("_update_player_pose", it, zc, xc, dc, speed)
			var a_cell := VehiclePose.pick_cell(yaws, rad_to_deg(float(rr.get("_pl_yaw"))), int(rr.get("_pl_cell")), float(rr.get("_veh_hyst")))
			rr.set("_pl_cell", a_cell)
			var heading := float(rr.call("road_heading_at", zc + float(rr.get("_pl_lookahead"))))
			var m_cell := VehicleStandIn.player_cell(st, yaws, heading, steer, lat, speed, under, track.curve_at(zc), atan2(xc, dc), k,
				float(rr.get("_pose_dt")), float(rr.get("_pl_tau")), float(rr.get("_veh_hyst")))
			compared += 1
			cells[a_cell] = true
			if (a_cell != m_cell or absf(float(rr.get("_pl_yaw")) - st[0]) > 1.0e-6) and mismatch == "":
				mismatch = "Fall %s, Bild %d: Arcade %d (%.4f), Modern %d (%.4f)" % [str(cs), f, a_cell, float(rr.get("_pl_yaw")), m_cell, st[0]]
			t += 1.0 / 60.0
		rr.free()
	assert_eq(mismatch, "", "Zelle des Spielers = RoadRenderer._update_player_pose + Zellwahl")
	assert_true(compared == 900, "900 Bilder verglichen (%d)" % compared)
	assert_true(cells.size() >= 6, "verschiedene der 21 Zellen getroffen (%d)" % cells.size())


## The inputs taken from the 3D camera are Arcade's on a straight road (depth of the rear, its lateral offset from
## the camera axis, road heading 0) – with the camera beside the lane; turning the camera keeps the relative yaw.
func test_view_inputs_match_arcade_on_a_straight() -> void:
	var t: Track = SynTrack.new()
	t.fill(cfg(), SynTrack.straight(400))
	var path := RoadPath3D.new()
	path.setup(t, 0, 120.0)
	path.ensure(398)
	var cam_z := 300.0
	var cam_x := 1.875
	var cam := Transform3D(Basis.IDENTITY, path.world(cam_z, cam_x, 3.4))
	var worst := 0.0
	for dist: float in [5.0, 20.0, 60.0, 150.0]:
		for x: float in [-3.75, 0.0, 3.75]:
			var z := cam_z + dist
			var v := VehicleStandIn.view_inputs(cam, path.world(z, x, 0.0), path.world(z, 0.0, 0.0), path.world(z + 4.7, 0.0, 0.0))
			worst = maxf(worst, absf(v.x - dist) + absf(v.y - (x - cam_x)) + absf(v.z))
	assert_true(worst < 1.0e-3, "Tiefe, Seitenversatz, Straßenrichtung wie Arcade (größte Abweichung %.6f)" % worst)
	# a turned camera: the road heading and the view ray turn alike, the car's yaw against the ray stays
	var yaw := deg_to_rad(8.0)
	var cam2 := Transform3D(Basis(Vector3.UP, -yaw), cam.origin)
	var z2 := cam_z + 40.0
	var a := VehicleStandIn.view_inputs(cam, path.world(z2, 3.75, 0.0), path.world(z2, 0.0, 0.0), path.world(z2 + 4.7, 0.0, 0.0))
	var b := VehicleStandIn.view_inputs(cam2, path.world(z2, 3.75, 0.0), path.world(z2, 0.0, 0.0), path.world(z2 + 4.7, 0.0, 0.0))
	assert_near(b.z, a.z - yaw, 1.0e-4, "Straßenrichtung relativ zur gedrehten Kamera")
	assert_near(b.z - atan2(b.y, b.x), a.z - atan2(a.y, a.x), 1.0e-3, "Gier gegen den Sehstrahl bleibt")
	assert_near(VehicleStandIn.camera_heading(cam2), yaw, 1.0e-6, "Kamerarichtung (+ = rechts)")


## The fold puts the cell's columns where Arcade's flank warp puts them: every column of VehiclePose.warp_columns
## lies on the four columns of VehicleStandIn.fold_columns (same car point for the same sprite x).
func test_fold_columns_equal_arcade_warp() -> void:
	var worst := 0.0
	var n := 0
	var smeared := 0
	for spec: Array in [[6.2308, 0.5, 1.82, 4.7], [5.3846, 0.5, 1.95, 4.45], [6.2308, 0.5, 2.02, 5.4]]:
		var w := float(spec[0])
		var xl := -float(spec[1]) * w
		var xr := (1.0 - float(spec[1])) * w
		for deg: float in [-24.0, -15.0, -6.0, -3.0, -1.0, 1.0, 3.0, 9.0, 18.0, 24.0]:
			var psi := deg_to_rad(deg)
			var ours := VehicleStandIn.fold_columns(psi, float(spec[2]), float(spec[3]), xl, xr)
			var arc := VehiclePose.warp_columns(psi, float(spec[2]), float(spec[3]), xl, xr, 9)
			assert_eq(ours.size(), 12, "vier Spalten")
			for i in range(0, arc.size(), 3):
				var x := arc[i]
				# Arcade's flank columns that run past the cell edge collapse onto it (their texture column smeared
				# over the rest of the flank); the fold ends the flank there instead – not compared
				if (x <= xl + 1.0e-5 or x >= xr - 1.0e-5) and absf(absf(arc[i + 1]) - float(spec[2]) * 0.5) < 1.0e-6 and arc[i + 2] > 1.0e-6:
					smeared += 1
					continue
				var j := 0
				while j < 2 and x > ours[(j + 1) * 3] + 1.0e-5:
					j += 1
				var x0 := ours[j * 3]
				var x1 := ours[(j + 1) * 3]
				var u := 0.0 if x1 - x0 < 1.0e-6 else clampf((x - x0) / (x1 - x0), 0.0, 1.0)
				var s := lerpf(ours[j * 3 + 1], ours[(j + 1) * 3 + 1], u)
				var t := lerpf(ours[j * 3 + 2], ours[(j + 1) * 3 + 2], u)
				if x1 - x0 < 1.0e-6:
					s = ours[(j + 1) * 3 + 1]
					t = ours[(j + 1) * 3 + 2]
				worst = maxf(worst, absf(s - arc[i + 1]) + absf(t - arc[i + 2]))
				n += 1
	assert_true(n > 300, "Spalten verglichen (%d, %d am Zellrand verschmiert)" % [n, smeared])
	assert_true(worst < 1.0e-3, "gleicher Punkt des Autos je Bildspalte (größte Abweichung %.6f m)" % worst)


## The fold follows RoadRenderer._car_warp: warp on, explicit rear pivot, cell turned >= 1°, length / rear depth >=
## render.vehicle_warp_min_ratio; a rear at the camera always folds.
func test_fold_rule_is_arcades() -> void:
	assert_true(VehicleStandIn.folds(true, true, 3.0, 4.7, 20.0, 0.06), "nah, gedreht: gefaltet")
	assert_false(VehicleStandIn.folds(true, true, 0.0, 4.7, 20.0, 0.06), "nicht gedreht: flach")
	assert_false(VehicleStandIn.folds(true, true, 0.5, 4.7, 20.0, 0.06), "unter 1°: flach")
	assert_false(VehicleStandIn.folds(true, true, 6.0, 4.7, 100.0, 0.06), "fern (4,7 / 100 < 0,06): flach")
	assert_true(VehicleStandIn.folds(true, true, 6.0, 4.7, 78.0, 0.06), "4,7 / 78 >= 0,06: gefaltet")
	assert_false(VehicleStandIn.folds(false, true, 6.0, 4.7, 20.0, 0.06), "render.vehicle_warp aus")
	assert_false(VehicleStandIn.folds(true, false, 6.0, 4.7, 20.0, 0.06), "ohne ausdrückliches Heck-Pivot (Spieler, alte Sets)")
	assert_true(VehicleStandIn.folds(true, true, -24.0, 4.7, 0.0, 0.06), "Heck an der Kamera: die Flanke bleibt sichtbar")


## The light of the stand-ins is Arcade's: VehicleStandIn.ArcadeShade against RoadRenderer._prepare + _project +
## _ctx + _light + _modulate (noon, dusk, night with the player's headlights and traffic ahead, a city with street
## lights, a tunnel seen from outside and from inside) at many rows and lateral positions.
func test_modulate_equals_arcade() -> void:
	var rcfg: Dictionary = ConfigLoader.lookup(cfg(), "render", {})
	var dcfg: Variant = ConfigLoader.lookup(cfg(), "daytime", {})
	var worst := 0.0
	var where := ""
	var n := 0
	for scene: Array in [[12.0, false, -1], [19.5, false, -1], [22.0, false, -1], [22.0, false, 30], [22.0, true, -1], [3.0, false, -1]]:
		var hour := float(scene[0])
		var t: Track = SynTrack.new()
		var opts := {"tunnel": [120, 180]} if bool(scene[1]) else {}
		if int(scene[2]) >= 0:
			opts["city_from_segment"] = int(scene[2])
		t.fill(cfg(), SynTrack.straight(400), PackedFloat32Array(), opts)
		for cam_z: float in [300.0, 390.0]:
			var pal := Palette.compute(hour, "normal", dcfg if dcfg is Dictionary else {}, false)
			var cam_in := t.is_tunnel_at(cam_z)
			var view := {"palette": pal, "visibility_m": 900.0, "camera_z": cam_z, "camera_x": 0.0, "camera_y": 3.4,
				"time": 1.0, "camera_in_tunnel": cam_in, "player": {"z": cam_z + 6.6, "x": 0.0, "length": 4.8},
				"cars": [{"z": cam_z + 30.0, "x": -3.75, "length": 4.5}, {"z": cam_z + 70.0, "x": 0.0, "length": 4.5}]}
			var rr := RoadRenderer.new()
			rr.set("track", t)
			rr.set("proj", RoadProjection.new())
			rr.set("cfg", cfg())
			rr.set("_seg_len", 3.0)
			rr.set("_k_curve", 9.0 / 120.0)
			rr.set("_hl_range", float(rcfg.get("headlight_range_m", 80.0)))
			rr.set("_hl_int", float(rr.get("_hl_int")) if not rcfg.has("headlight_intensity") else float(rcfg["headlight_intensity"]))
			rr.set("_lw", t.lane_w)
			rr.set("view", view)
			rr.call("_prepare")
			rr.call("_project")
			var shade := VehicleStandIn.ArcadeShade.new()
			shade.setup(rcfg, 3.0, 9.0, float(ConfigLoader.lookup(cfg(), "road.streetlight_every_m", 33.0)))
			shade.hl_int = float(rr.get("_hl_int"))
			shade.prepare(view, cam_in, t)
			for i in 40:
				var z := cam_z + 4.0 + float(i) * 13.7
				var k := int(floor(z / 3.0)) - int(rr.get("_base"))
				var segs: Array = rr.get("_segs")
				var tun := (segs[k] as TrackSegment).tunnel
				for x: float in [-3.75, 0.0, 2.5]:
					rr.call("_ctx", tun)
					var dz := z - cam_z
					var l_a := float(rr.call("_light", z, x)) if bool(rr.get("_lit")) and dz < float(rr.get("_hl_range")) + 40.0 else 0.0
					var a: Color = rr.call("_modulate", k, l_a, 0.8, 0.55)
					var m := shade.modulate(z, tun, shade.light_at(z, x, dz), 0.8)
					var d := absf(a.r - m.r) + absf(a.g - m.g) + absf(a.b - m.b) + absf(a.a - m.a)
					if d > worst:
						worst = d
						where = "%.1f Uhr, Tunnel %s, Kamera %.0f, z %.1f, x %.2f: %s gegen %s" % [hour, str(tun), cam_z, z, x, str(a), str(m)]
					n += 1
			rr.free()
	assert_true(n >= 1400, "Stellen verglichen (%d)" % n)
	assert_true(worst < 1.0e-4, "Modulation = RoadRenderer._modulate (größte Abweichung %.7f: %s)" % [worst, where])


## Which picture a set gets (layer "vehicles"): a sprite set without a model Arcade's sprite, a box set Arcade's box,
## a set with a model its model (the stand-in leaves it alone), a set whose sheet was not loaded in prepare() the
## painted box – and asking for it while driving loads nothing. Fixture sheets (tests/fixtures/sprites) stand for
## sets without a model; the set with a model is taken from the shipped manifest.
func test_each_set_gets_its_picture() -> void:
	var db: Node = (load("res://scripts/core/sprite_db.gd") as GDScript).new()
	assert_true(db.call("load_manifest", FIXTURES), "Testdaten-Manifest")
	var real: Node = (load("res://scripts/core/sprite_db.gd") as GDScript).new()
	var model_set := ""
	for sid: String in real.get("sets"):
		if (sid.begins_with("traffic/") or sid.begins_with("player/")) and ModelDB.has_model(sid):
			model_set = sid
			break
	real.free()
	var layer: Node = (load(LAYER) as GDScript).new()
	layer.set("sprite_db", db)
	var sets: Array[String] = ["fixture/car17", "fixture/player21", "fixture/truck_box"]
	if model_set != "":
		sets.append(model_set)
	layer.set("_sets", sets)
	layer.call("_load_standins")
	var loads := int(db.get("loads"))
	var car: Dictionary = layer.call("_set_info", "fixture/car17")
	var pl: Dictionary = layer.call("_set_info", "fixture/player21")
	var tr: Dictionary = layer.call("_set_info", "fixture/truck_box")
	var late: Dictionary = layer.call("_set_info", "fixture/police17")
	assert_eq(str(car.get("standin", "")), VehicleStandIn.KIND_SPRITE, "Pkw ohne Modell: Arcades Sprite")
	assert_true(bool((car["sheet"] as Dictionary)["rear"]), "Verkehr: Heck-Pivot (Arcade faltet ihn)")
	assert_eq(str(pl.get("standin", "")), VehicleStandIn.KIND_SPRITE, "Spielerauto ohne Modell: Arcades Sprite")
	assert_true(bool((pl["sheet"] as Dictionary)["persp"]), "Spielerauto: perspektivische Zellen")
	assert_eq(str(tr.get("standin", "")), VehicleStandIn.KIND_BOX, "Lkw ohne Modell: Arcades Kasten")
	assert_eq(str(late.get("standin", "")), "", "Bild nicht vorbereitet: der gemalte Kasten")
	assert_true(bool(late.get("box", false)), "… als Ersatz")
	assert_eq(int(db.get("loads")), loads, "während der Fahrt wird kein Bild geladen")
	if model_set != "":
		var m: Dictionary = layer.call("_set_info", model_set)
		assert_eq(str(m.get("standin", "")), "", "Set mit Modell (%s): kein Ersatz" % model_set)
		assert_true(str(m.get("model_id", "")) != "" and not bool(m.get("box", true)), "… sein Modell wie bisher")
		assert_false((layer.get("_standin_tex") as Dictionary).has(model_set), "… und sein Blatt wird nicht geladen")
	else:
		fail("kein Fahrzeug-Set mit Modell im ausgelieferten Manifest")
	assert_eq((layer.get("_standin_tex") as Dictionary).size(), 3, "drei Blätter in prepare() geladen")
	layer.free()
	db.free()


## The textured box: one mesh per part with Arcade's face pictures (UVs inside the face rectangles), the front shows
## the rear picture; two parts are two units – the leading one turning about the axle behind the kingpin, the trailer
## coupled at its kingpin (AS1's semitrailer: tractor pivot 3.1 m, kingpin 3.7 m ahead of the centre, 1.19 m high).
func test_box_faces_and_units() -> void:
	var db: Node = (load("res://scripts/core/sprite_db.gd") as GDScript).new()
	db.call("load_manifest", FIXTURES)
	var info := VehicleStandIn.sheet_info("fixture/truck_box", db)
	var parts: Array = info["parts"]
	var units := VehicleStandIn.box_units(parts)
	assert_eq(units.size(), parts.size(), "eine Einheit je Teil")
	if parts.size() >= 2:
		var lead: Dictionary = units[0]
		var trail: Dictionary = units[1]
		var front_trailer := float((parts[int((trail["parts"] as Array)[0])] as Dictionary)["z1"])
		assert_near((trail["pivot"] as Vector3).z, -(front_trailer - VehicleStandIn.KINGPIN_BEHIND_FRONT_M), 1.0e-5, "Königszapfen hinter der Front des Aufliegers")
		assert_near((trail["pivot"] as Vector3).y, VehicleStandIn.KINGPIN_HEIGHT_M, 1.0e-5, "Königszapfen 1,19 m hoch")
		assert_near((lead["pivot"] as Vector3).z, (trail["pivot"] as Vector3).z + VehicleStandIn.LEAD_PIVOT_BEHIND_KINGPIN_M, 1.0e-5, "Zugmaschine dreht um die Achse hinter dem Zapfen")
	var tex_size := Vector2(2048.0, 2048.0)
	for pi in parts.size():
		var p: Dictionary = parts[pi]
		var mesh := VehicleStandIn.box_part_mesh(p, pi, info["lights"], tex_size)
		var arr := mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var faces: Dictionary = p["faces"]
		assert_eq(uv.size(), 4 * (faces.size() + (1 if faces.has("rear") else 0)), "%s: vier Ecken je Fläche (und die Front)" % str(p["name"]))
		var inside := 0
		for f: String in faces:
			var r: Rect2 = (faces[f] as Rect2)
			var rn := Rect2(r.position / tex_size, r.size / tex_size).grow(0.5 / 2048.0)
			for q: Vector2 in uv:
				if rn.has_point(q):
					inside += 1
		assert_true(inside >= uv.size(), "%s: jede Ecke im Bild einer Fläche" % str(p["name"]))
	var node := VehicleStandIn.build_box_node("fixture/truck_box", info, ShaderMaterial.new(), tex_size, StandardMaterial3D.new())
	assert_true(node != null, "Knoten gebaut")
	var groups: Array = node.get_meta("groups", [])
	assert_eq(groups.size(), units.size() if parts.size() >= 2 else 0, "gelenkig: eine Gruppe je Einheit wie bei einem Modell")
	var casters := 0
	for gi: GeometryInstance3D in ModelFactory.geometry_of(node):
		if gi.name == "shadow":
			casters += 1
			assert_eq(gi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "verborgener Werfer")
		else:
			assert_eq(gi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "die Bildflächen werfen nicht")
	assert_eq(casters, units.size(), "ein Kastenwerfer je Einheit")
	assert_true(not (node.get_meta("lights", []) as Array).is_empty(), "Lampenanker für die Lichtpunkte")
	node.free()
	db.free()


## The player's perspective picture pulled towards the eye keeps its pixels and its lowest row stands on the road:
## scaling about the eye leaves the projection unchanged.
func test_pulled_picture_keeps_its_pixels() -> void:
	var ay := -3.4                 # the anchor 3.4 m below the eye (the road under the car centre)
	var h := 2.95                  # picture height (kombi: 4.39 m x 384 / 572)
	var vb := (0.552 - 1.0) * h    # lowest row below the anchor
	var k := VehicleStandIn.persp_pull(ay, vb)
	assert_between(k, 0.6, 0.75, "Bild zum Auge gezogen (Faktor %.3f)" % k)
	var d := 9.0
	var low := Vector3(0.0, ay + vb, -d) * k
	assert_true(low.y >= ay - 1.0e-4, "unterste Zeile über der Straße (%.3f m gegen %.3f m)" % [low.y, ay])
	var p0 := Vector2(1.3 / d, (ay + vb) / d)
	var p1 := Vector2(1.3 * k / (d * k), low.y / (d * k))
	assert_near(p0.distance_to(p1), 0.0, 1.0e-6, "gleiche Bildposition")
	assert_eq(VehicleStandIn.persp_pull(0.5, vb), 1.0, "über Augenhöhe: nicht gezogen")
	assert_eq(VehicleStandIn.layer_strength(0.04, 1.0, 1.0), 0.0, "Ebene unter 0,05: aus (Arcade)")
	assert_near(VehicleStandIn.layer_strength(1.0, 0.5, 0.8), 1.0, 1.0e-6, "nachts überdauern die Lichter den Wagen (höchstens 1)")
	assert_near(VehicleStandIn.layer_strength(0.6, 1.0, 1.0), 0.6, 1.0e-6, "Tag: Stärke der Ebene")
