extends SceneTree
const Fair := preload("res://tests/race3d/fairness.gd")
func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, ["kiel_hamburg"]):
		if str(dir["from"]) != str(dir["stage"]["from"]):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		p.ensure(32 + 900)
		var ctx := ChunkContext.new()
		ctx.cfg = cfg
		ctx.scenery_db = t.scenery_db
		ctx.capture(0, 0, 32, p, tp, t)
		var g: ChunkBuilder = load("res://scripts/race3d/builders/gantry.gd").new()
		var d: Dictionary = g.debug(g.build(ctx, g.collect(ctx)))
		print("GANTRY ", d)
	quit(0)
