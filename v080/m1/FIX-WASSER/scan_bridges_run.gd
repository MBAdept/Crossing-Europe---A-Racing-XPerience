extends SceneTree
## FIX-WASSER scratch: every bridge of every stage direction – depth, deck height, the far-ground plane of the old
## rule (lowest road of the loaded window - 4 m) with the camera before / on the bridge, and the water surface the
## terrain draws there (road height + water_level of the water rows). "covered" = the old plane lies above the
## lowest water surface of the window (the opaque plane hides the water).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Fair: Variant = load("res://tests/race3d/fairness.gd")
	var FarGround: Variant = load("res://scripts/race3d/layers/far_ground.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.load_network()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var drop := float(ConfigLoader.lookup(cfg, "graphics.modern.terrain.far_ground_drop_m", 4.0))
	var fg: Node = FarGround.new()
	print("dir | bridge | type | depth | km0 | km1 | len_z | slope | deck_y_mid | road_lo_win | old_plane | water_lo | old_plane-water (cam: -300/z0/mid/z1-30) | covered")
	for dir: Dictionary in Fair.directions(net):
		var plan: Variant = StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		if t.bridges.is_empty():
			continue
		var p := RoadPath3D.new()
		p.setup(t, 0, r1)
		for br: Dictionary in t.bridges:
			var z0 := float(br["z0"])
			var z1 := float(br["z1"])
			var kend := mini(int((z1 + 1300.0) / t.seg_len), t.segment_count - 1)
			p.ensure(kend)
			var diffs := []
			var worst := -INF
			var info := []
			for cam_z: float in [z0 - 300.0, z0, (z0 + z1) * 0.5, z1 - 30.0]:
				cam_z = maxf(cam_z, 0.0)
				var lo: float = fg.lowest_road(p, cam_z, 900.0)
				var plane := lo - drop
				# lowest water surface of the same window (every row)
				var ahead := minf(1500.0, 900.0 + 192.0)
				var k0 := maxi(p.first, int(floor((cam_z - 150.0 - 96.0) / t.seg_len)))
				var k1 := mini(p.last(), int(ceil((cam_z + ahead) / t.seg_len)))
				var wlo := INF
				for k in range(k0, k1 + 1):
					var s := t.get_segment(k)
					if s.water:
						wlo = minf(wlo, p.height(k) + minf(s.water_level, 0.0))
				var d := plane - wlo
				diffs.append("%.2f" % d)
				worst = maxf(worst, d)
				if cam_z == (z0 + z1) * 0.5:
					var km := int(((z0 + z1) * 0.5) / t.seg_len)
					info = [p.height(km), lo, plane, wlo]
			print("%s | %s | %s | %.1f | %.2f | %.2f | %.0f | %.1f | %.2f | %.2f | %.2f | %.2f | %s | %s" % [
				str(dir["name"]), str(br["name"]), str(br["type"]), float(br["depth"]), float(br["km0"]), float(br["km1"]),
				z1 - z0, float(br["slope"]), info[0], info[1], info[2], info[3], "/".join(diffs), "JA" if worst > 0.0 else "nein"])
	fg.free()
	quit(0)
