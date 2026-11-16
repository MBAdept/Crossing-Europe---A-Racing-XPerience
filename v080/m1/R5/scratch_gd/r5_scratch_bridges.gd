extends SceneTree
## R5 scratch (not committed): builds every bridge chunk of the network with builders/bridge.gd (no renderer) and
## prints the debug counts per bridge.

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var Bridge: GDScript = load("res://scripts/race3d/builders/bridge.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var dirs: Array = Fair.call("directions", net, [])
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var n := 0
	var bad := 0
	for dir: Dictionary in dirs:
		if only != "" and not str(dir["name"]).contains(only):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.bridges.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
		p.set_clear_reach(1842.0)
		var b: Object = Bridge.new()
		for br: Dictionary in t.bridges:
			var c0 := int(floor(float(br["z0"]) / t.seg_len / 32.0))
			var c1 := int(floor(float(br["z1"]) / t.seg_len / 32.0))
			var sums := {}
			for ci in range(c0, c1 + 1):
				p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = net["scenery"]
				ctx.levels = {"shadow_casters": 2, "details": 1}
				ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
				var inp: Variant = b.call("collect", ctx)
				var part: Dictionary = b.call("build", ctx, inp)
				var dbg: Dictionary = b.call("debug", part)
				for k: String in dbg:
					sums[k] = int(sums.get(k, 0)) + int(dbg[k])
			n += 1
			var ok := int(sums.get("water_quads", 0)) > 0 and int(sums.get("walls", 0)) + int(sums.get("bank_quads", 0)) > 0
			if not ok:
				bad += 1
			print("%s %-28s %-12s %s %s" % ["OK " if ok else "BAD", br["name"], br["type"], dir["name"], JSON.stringify(sums)])
	print("bridges %d bad %d in %.1f s" % [n, bad, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
