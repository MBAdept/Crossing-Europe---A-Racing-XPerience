extends SceneTree
## FIX-WASSER scratch: where the lowered far-ground plane can show near the camera – along the stretch in which the
## plane lies lower than before because of deep water (old target - new target > 0.05 m), the rows whose ribbon is
## cut (medial axis or inside of a bend: limit < outer ring) and how much deeper the plane lies there.
##   -- --stage=kiel_hamburg --from=kiel

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Fair: Variant = load("res://tests/race3d/fairness.gd")
	var FarGround: Variant = load("res://scripts/race3d/layers/far_ground.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.load_network()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var drop := float(ConfigLoader.lookup(cfg, "graphics.modern.terrain.far_ground_drop_m", 4.0))
	var cases := [["kiel_hamburg", "kiel"], ["kiel_hamburg", "hamburg"], ["rostock_kiel", "rostock"], ["frankfurt_koeln", "frankfurt"],
		["budapest_wien", "wien"], ["lyon_bern", "lyon"], ["slavonski_brod_belgrad", "slavonski_brod"], ["kaunas_riga", "kaunas"]]
	var fg: Node = FarGround.new()
	for c: Array in cases:
		for dir: Dictionary in Fair.directions(net, [c[0]]):
			if str(dir["from"]) != str(c[1]):
				continue
			var plan: Variant = StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg, net["scenery"])
			var p := RoadPath3D.new()
			p.setup(t, 0, r1)
			var tp := TerrainProfile.new()
			tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
			var last := t.segment_count - 1
			p.set_clear_reach(1842.0)
			p.ensure(last)
			var outer := tp.rings[tp.ring_count() - 1]
			var lowered_from := -1.0
			var lowered_to := -1.0
			var max_low := 0.0
			var cut := 0
			var cut_min := INF
			var cut_rows := 0
			var deeper_at_cut := 0.0
			var z := 0.0
			while z < t.length_z - 10.0:
				var old: float = float(fg.lowest_road(p, z, 900.0)) - drop
				var nw: float = float(fg.target_height(p, t, z, 900.0))
				var low := old - nw
				if low > 0.05:
					if lowered_from < 0.0:
						lowered_from = z
					lowered_to = z
					max_low = maxf(max_low, low)
					# rows within 300 m ahead of the camera with a cut ribbon (a gap the plane shows through)
					var k := int(z / t.seg_len)
					for d in range(0, 100, 4):
						var kk := mini(k + d, last)
						for side: int in [-1, 1]:
							var lim := tp.limit(kk, side)
							cut_rows += 1
							if lim < outer - 1.0:
								cut += 1
								cut_min = minf(cut_min, lim)
								deeper_at_cut = maxf(deeper_at_cut, low)
				z += 30.0
			print("%s: Scheibe tiefer von km %.2f bis km %.2f (höchstens %.2f m); gekürzte Bandseiten in 300 m voraus: %d von %d (schmalste %.0f m, äußerer Ring %.0f m)" % [
				str(dir["name"]), t.z_to_km(maxf(lowered_from, 0.0)), t.z_to_km(maxf(lowered_to, 0.0)), max_low, cut, cut_rows,
				cut_min if cut_min < INF else -1.0, outer])
	fg.free()
	quit(0)
