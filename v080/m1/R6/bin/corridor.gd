extends SceneTree
## R6 helper: the bend sight corridor (ChunkContext.in_bend_corridor) at the pillar places of a border roof.
##   godot --headless --path . -s <this> -- --stage=dev_testetappe

const Fair := preload("res://tests/race3d/fairness.gd")
const N := 32


func _initialize() -> void:
	var stage := "dev_testetappe"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.substr(8)
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, [stage]):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "border":
				continue
			var bz := float(zn["z0"])
			var chunk := int(floor(bz / (float(N) * t.seg_len)))
			for c in [chunk, chunk + 1]:
				var p := RoadPath3D.new()
				p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
				var tp := TerrainProfile.new()
				tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
				p.ensure((c + 1) * N + 700)
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = t.scenery_db
				ctx.capture(c, c * N, c * N + N, p, tp, t)
				var line := "%s chunk %d (z %.0f-%.0f) bz %.0f:" % [str(dir["name"]), c, c * N * t.seg_len, (c + 1) * N * t.seg_len, bz]
				var z := bz - 4.0
				while z < bz + 24.0:
					if z >= c * N * t.seg_len and z < (c + 1) * N * t.seg_len:
						var row := int(floor(z / t.seg_len)) - ctx.seg_a
						var xr := ctx.shoulder_edge(row, 1) + 0.6
						var xl := -ctx.shoulder_edge(row, -1) - 0.6
						line += " %+.0f:%s%s" % [z - bz, "L" if ctx.in_bend_corridor(z, xl) else "-", "R" if ctx.in_bend_corridor(z, xr) else "-"]
					z += 1.0
				print(line)
				var cl := ""
				for zz: float in [bz - 2.0, bz + 9.0, bz + 18.0]:
					if zz >= c * N * t.seg_len and zz < (c + 1) * N * t.seg_len:
						var ri := int(floor(zz / t.seg_len)) - ctx.seg_a
						cl += " %+.0f: corridor %s min %.1f" % [zz - bz, str(ctx.corridor[ri]), ctx.corridor_min]
				print("   " + cl)
				print("   curve at bz: %.4f, at bz+30: %.4f, at bz+60: %.4f" % [t.segment_at(bz).curve, t.segment_at(bz + 30.0).curve, t.segment_at(bz + 60.0).curve])
	quit(0)
