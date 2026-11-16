extends SceneTree
## QA-R6: main-thread cost of the R6 builders' collect() along a stage, with the track generated progressively like in
## the game (path kept ~3.4 km = 36 chunks ahead of the chunk being collected). Prints max/avg per builder and the worst
## chunks.   godot --headless --path . -s <this> -- --only=dev_testetappe

const Fair := preload("res://tests/race3d/fairness.gd")
const N := 32
const IDS := ["station", "border", "city", "gantry", "radar"]


func _initialize() -> void:
	var only: Array = ["dev_testetappe"]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, only):
		if str(dir["from"]) != str(dir["stage"]["from"]):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		var builders := {}
		for id: String in IDS:
			builders[id] = load("res://scripts/race3d/builders/%s.gd" % id).new()
		var stats := {}
		for id: String in IDS:
			stats[id] = {"max": 0.0, "sum": 0.0, "n": 0, "where": -1}
		var nch := int(t.segment_index_at(t.length_z) / N)
		for c in nch:
			p.ensure((c + 36) * N)
			var ctx := ChunkContext.new()
			ctx.cfg = cfg
			ctx.scenery_db = t.scenery_db
			ctx.capture(c, c * N, c * N + N, p, tp, t)
			for id: String in IDS:
				var b: ChunkBuilder = builders[id]
				var t0 := Time.get_ticks_usec()
				b.collect(ctx)
				var ms := float(Time.get_ticks_usec() - t0) / 1000.0
				var st: Dictionary = stats[id]
				st["sum"] = float(st["sum"]) + ms
				st["n"] = int(st["n"]) + 1
				if ms > float(st["max"]):
					st["max"] = ms
					st["where"] = c
		for id: String in IDS:
			var st: Dictionary = stats[id]
			print("COLLECT %s %s max %.2f ms (chunk %d, km %.2f) avg %.3f ms over %d chunks" % [dir["name"], id, float(st["max"]), int(st["where"]),
				t.z_to_km(float(int(st["where"]) * N) * t.seg_len), float(st["sum"]) / maxf(1.0, float(st["n"])), int(st["n"])])
	quit(0)
