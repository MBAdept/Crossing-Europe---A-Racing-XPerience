extends SceneTree
## FIX-WASSER scratch: every bridge of every stage direction – depth, and with the camera before / on the bridge the
## far-ground plane of the old rule (lowest road of the loaded window - 4 m), of the new rule (layers/far_ground.gd
## target_height) and the lowest water surface of THIS bridge inside the window (road height + water_level of its
## water rows – what the terrain draws). "verdeckt" = the old plane lay above this bridge's water at some camera
## position; "neu ok" = the new plane lies below it at every position.

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
	var t0 := Time.get_ticks_msec()
	print("richtung | bruecke | typ | tiefe_m | km0 | km1 | laenge_z | alt-wasser (kamera z0-300/z0/mitte/z1-30) | neu-wasser | verdeckt | neu ok")
	var affected := {}
	for dir: Dictionary in Fair.directions(net):
		var plan: Variant = StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		if t.bridges.is_empty():
			continue
		var p := RoadPath3D.new()
		p.setup(t, 0, r1)
		for bi in t.bridges.size():
			var br: Dictionary = t.bridges[bi]
			var z0 := float(br["z0"])
			var z1 := float(br["z1"])
			p.ensure(mini(int((z1 + 1300.0) / t.seg_len), t.segment_count - 1))
			var olds := []
			var news := []
			var worst_old := -INF
			var worst_new := -INF
			for cam_z: float in [z0 - 300.0, z0, (z0 + z1) * 0.5, z1 - 30.0]:
				cam_z = maxf(cam_z, 0.0)
				var old: float = float(fg.lowest_road(p, cam_z, 900.0)) - drop
				var nw: float = float(fg.target_height(p, t, cam_z, 900.0))
				var w: Vector2i = fg.window_rows(p, cam_z, 900.0)
				var wlo := INF
				for k in range(maxi(w.x, int(z0 / t.seg_len) - 1), mini(w.y, int(z1 / t.seg_len) + 1) + 1):
					var s := t.get_segment(k)
					if s.index == k and s.water and s.bridge_i == bi:
						wlo = minf(wlo, p.height(k) + minf(s.water_level, 0.0))
				if wlo == INF:
					olds.append("-")
					news.append("-")
					continue
				olds.append("%.2f" % (old - wlo))
				news.append("%.2f" % (nw - wlo))
				worst_old = maxf(worst_old, old - wlo)
				worst_new = maxf(worst_new, nw - wlo)
			var hidden := worst_old > 0.0
			if hidden:
				affected["%s (%s, %.1f m)" % [str(br["name"]), str(br["type"]), float(br["depth"])]] = true
			print("%s | %s | %s | %.1f | %.2f | %.2f | %.0f | %s | %s | %s | %s" % [str(dir["name"]), str(br["name"]), str(br["type"]),
				float(br["depth"]), float(br["km0"]), float(br["km1"]), z1 - z0, "/".join(olds), "/".join(news),
				"JA" if hidden else "nein", "ja" if worst_new <= -0.29 else "NEIN"])
	print("--- betroffen (alte Scheibe über dem Wasser der Brücke):")
	for k: String in affected.keys():
		print("  ", k)
	print("--- %d ms" % (Time.get_ticks_msec() - t0))
	fg.free()
	quit(0)
