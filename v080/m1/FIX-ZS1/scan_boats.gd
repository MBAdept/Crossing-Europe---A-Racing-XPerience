extends SceneTree
## FIX-ZS1 scratch (CHECK 3): every houseboat / ferry item of a stage – where it stands and what the Modern ground
## under it is (water rows of the terrain, the ribbon width, the props builder's verdict).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Fair: Variant = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.load_network()
	var only := str(CliArgs.all().get("stage", "kiel_hamburg"))
	var from := str(CliArgs.all().get("from", "kiel"))
	for dir: Dictionary in Fair.directions(net, [only]):
		if str(dir["from"]) != from:
			continue
		var plan: Variant = StagePlan.build(dir["stage"], from, net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for i in t.bridges.size():
			var b: Dictionary = t.bridges[i]
			print("bridge %d: %s" % [i, JSON.stringify(b)])
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
		var k := 0
		while k < t.segment_count - 1:
			var s := t.get_segment(k)
			for j in s.sprites.size():
				var it: Dictionary = s.sprites[j]
				var set_id := str(it.get("set", ""))
				if set_id != "props/houseboat" and set_id != "props/ferry_ship":
					continue
				var z := float(it.get("z", s.z))
				var kz := int(floor(z / t.seg_len))
				var sz := t.get_segment(kz)
				var side := int(it.get("side", 1))
				var x := float(it.get("x", 0.0))
				var water_rows := 0
				for d in range(-3, 4):
					water_rows += 1 if t.get_segment(kz + d).water else 0
				var edge := tp.edge(kz, side)
				var lim := tp.limit(kz, side)
				var beyond := absf(x) - edge
				var hgt := tp.height(kz, side, beyond)
				print("%s km %.2f z %.1f seg %d side %d x %.1f h %.2f | seg water %s depth %.2f level %.2f bridge '%s' bank %s | water rows ±3: %d | ribbon %.0f m, beyond %.1f, ground %.2f" % [
					set_id, t.z_to_km(z), z, kz, side, x, float(it.get("h", 0.0)), str(sz.water), sz.water_depth, sz.water_level, sz.bridge,
					str(sz.bank), water_rows, lim, beyond, hgt])
			k += 1
	quit(0)
