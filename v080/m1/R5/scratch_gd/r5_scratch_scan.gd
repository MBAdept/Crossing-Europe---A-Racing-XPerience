extends SceneTree
## R5 scratch (not committed): every bridge and tunnel of the network – type, lengths, depth, slope, curvature on the
## bridge, road height change, pylon items.

func _initialize() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var dirs: Array = Fair.call("directions", net, [])
	var n_br := 0
	var n_tun := 0
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.bridges.is_empty() and plan.tunnels.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for tu: Dictionary in plan.tunnels:
			n_tun += 1
			var z0 := t.km_to_z(float(tu["start_km"]))
			var z1 := t.km_to_z(float(tu["end_km"]))
			print("TUN %s %s km %.1f len %.0f m" % [dir["name"], tu["name"], float(tu["start_km"]), z1 - z0])
		if plan.bridges.is_empty():
			continue
		# generate up to the end of the last bridge
		var last := 0.0
		for b: Dictionary in plan.bridges:
			last = maxf(last, t.km_to_z(float(b["end_km"])))
		var k_end := mini(int(last / t.seg_len) + 4, t.segment_count - 1)
		var k := 0
		var rows := {}
		while k <= k_end:
			var s := t.get_segment(k)
			if s.water or s.bank:
				rows[k] = {"curve": s.curve, "y": s.y, "wl": s.water_level, "bank": s.bank, "city": s.city, "lanes": s.lanes,
					"pyl": s.sprites.filter(func(it): return str(it.get("proc", "")) == "pylon").size()}
			k += 1
		for bi in t.bridges.size():
			var br: Dictionary = t.bridges[bi]
			n_br += 1
			var a := int(float(br["z0"]) / t.seg_len)
			var b := int(float(br["z1"]) / t.seg_len)
			var cmax := 0.0
			var ymin := 1e9
			var ymax := -1e9
			var pyl := 0
			var city := true
			var lanes := 0.0
			for q in range(a, b + 1):
				if rows.has(q):
					var r: Dictionary = rows[q]
					cmax = maxf(cmax, absf(float(r["curve"])))
					ymin = minf(ymin, float(r["y"]))
					ymax = maxf(ymax, float(r["y"]))
					pyl += int(r["pyl"])
					city = city and bool(r["city"])
					lanes = maxf(lanes, float(r["lanes"]))
			print("BR %s %s type=%s len=%.0f depth=%.1f slope=%.1f curve_max=%.2f dy=%.1f pylons=%d city=%s lanes=%.0f bank=%s" % [
				dir["name"], br["name"], br["type"], float(br["z1"]) - float(br["z0"]), float(br["depth"]), float(br["slope"]),
				cmax, ymax - ymin, pyl, city, lanes, br["bank"]])
	print("bridges %d tunnels %d" % [n_br, n_tun])
	quit(0)
