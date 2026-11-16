extends SceneTree
## R3E scratch: cost of the pieces of the sprite stand-in path (µs per call, 20000 calls each).

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")


func _t(label: String, n: int, c: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	c.call(n)
	print("%-28s %.2f µs" % [label, float(Time.get_ticks_usec() - t0) / float(n)])


func _initialize() -> void:
	var cfgd := ConfigLoader.load_merged()
	var t: Track = SynTrack.new()
	t.fill(cfgd, SynTrack.arc(600, 400.0))
	var path := RoadPath3D.new()
	path.setup(t, 0, 120.0)
	path.ensure(598)
	var cam := Transform3D(Basis.IDENTITY, path.world(300.0, 0.0, 3.4))
	var inv := cam.affine_inverse()
	var yaws := PackedFloat32Array([-24.0, -21.0, -18.0, -15.0, -12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0])
	var rear := path.world(340.0, 3.75, 0.0)
	var front := path.world(344.7, 3.75, 0.0)
	var st := PackedFloat32Array([0.0, 0.0, -1.0])
	var shade := VehicleStandIn.ArcadeShade.new()
	shade.setup({}, 3.0)
	var pal := Palette.compute(12.0, "normal", {}, false)
	shade.prepare({"palette": pal, "visibility_m": 900.0, "camera_z": 300.0, "cars": []}, false, t)
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var b := VehicleStandIn.SheetBatch.new("x/y", {}, ShaderMaterial.new(), root3, null, null)
	var n := 20000
	_t("path.world", n, func(k: int) -> void:
		for i in k:
			path.world(340.0 + float(i % 7), 3.75, 0.0))
	_t("view_inputs", n, func(k: int) -> void:
		for i in k:
			VehicleStandIn.view_inputs(inv, rear, rear, front))
	_t("traffic_cell", n, func(k: int) -> void:
		for i in k:
			VehicleStandIn.traffic_cell(st, yaws, Vector3(40.0, 3.75, 0.01), 0.0, 4.7, 30.0, 1.0 / 60.0, 0.12, 0.3))
	_t("modulate", n, func(k: int) -> void:
		for i in k:
			shade.modulate(340.0, false, 0.0, 1.0))
	_t("chord_pose", n, func(k: int) -> void:
		for i in k:
			VehiclePose3D.chord_pose(rear, front, 0.01, 0.0))
	_t("fade+lamps", n, func(k: int) -> void:
		var c := {"tail": 0.0, "brake": 1.0, "blink": 0, "blink_t": 0.1, "beacon": ""}
		for i in k:
			VehiclePose3D.fade(40.0, 900.0, 0.45, false, 260.0)
			VehiclePose3D.lamp_a(c, false)
			VehiclePose3D.lamp_b(c, false))
	_t("is_tunnel_at x2", n, func(k: int) -> void:
		for i in k:
			t.is_tunnel_at(340.0)
			t.is_tunnel_at(342.0))
	_t("batch.add (8 cars/commit)", n, func(k: int) -> void:
		var tr := Transform3D(Basis.IDENTITY, rear)
		for i in k:
			if i % 8 == 0:
				b.begin()
			b.add(tr, Color(1, 1, 1, 1), Vector4(1, 0, 0, 0)))
	_t("batch.commit (8 inst)", 2000, func(k: int) -> void:
		var tr := Transform3D(Basis.IDENTITY, rear)
		for i in k:
			b.begin()
			for j in 8:
				b.add(tr, Color(1, 1, 1, 1), Vector4(1, 0, 0, 0))
			b.commit())
	quit(0)
