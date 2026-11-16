extends SceneTree
## R6 helper: the pillars the border builder really builds at every border of every stage direction (pillar_plan plus
## the bend corridor of build()), counted per side.
##   godot --headless --path . -s <this> [-- --only=<stage>]

const Fair := preload("res://tests/race3d/fairness.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")
const N := 32


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = [a.substr(7)]
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var stats := {"roofs": 0, "four": 0, "three": 0, "two_sides": 0, "one_side": 0, "none": 0, "front_moved": 0}
	for dir: Dictionary in Fair.directions(net, only):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.borders.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "border":
				continue
			var bz := float(zn["z0"])
			var b: ChunkBuilder = BorderB.new()
			var kinds: Array = []
			var c0 := int(floor((bz - 4.0) / (float(N) * t.seg_len)))
			var c1 := int(floor((bz + 22.0) / (float(N) * t.seg_len)))
			for c in range(c0, c1 + 1):
				p.ensure((c + 1) * N + 700)
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = t.scenery_db
				ctx.capture(c, c * N, c * N + N, p, tp, t)
				var part: Dictionary = b.build(ctx, b.collect(ctx))
				for q: Array in part.get("pillar_at", []):
					kinds.append("%s%s" % ["R" if float(q[1]) > 0.0 else "L", str(q[2])])
			stats["roofs"] += 1
			var left := 0
			var right := 0
			for k: String in kinds:
				if k.begins_with("L"):
					left += 1
				else:
					right += 1
				if k.ends_with("moved"):
					stats["front_moved"] += 1
			if kinds.size() >= 4:
				stats["four"] += 1
			elif kinds.size() == 3:
				stats["three"] += 1
			if left > 0 and right > 0:
				stats["two_sides"] += 1
			elif left + right > 0:
				stats["one_side"] += 1
			else:
				stats["none"] += 1
			print("%s border km %.2f: %s" % [str(dir["name"]), t.z_to_km(bz), str(kinds)])
	print("PILLARS ", JSON.stringify(stats))
	quit(0)
