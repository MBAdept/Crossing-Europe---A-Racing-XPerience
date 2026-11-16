extends SceneTree
## QA-ZS1 scratch: props of the first 120 m of a stage start and whether Modern's props builder drops them as
## "corridor" (F7 sight corridor of a bend, ChunkContext.in_bend_corridor) – why the big oak left of the start of
## Kiel – Hamburg is missing in Modern.
##   godot --headless --path . -s <this> -- --stage=kiel_hamburg --from=kiel

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var stage := str(args.get("stage", "kiel_hamburg"))
	var from := str(args.get("from", "kiel"))
	var Fair: Variant = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.load_network()
	var dirs: Array = Fair.directions(net, ["%s__%s" % [stage, from]])
	if dirs.is_empty():
		print("no such stage direction %s__%s" % [stage, from])
		quit(1)
		return
	var d: Dictionary = dirs[0]
	var plan: Variant = StagePlan.build(d["stage"], str(d["from"]), net["cities"], net["countries"], cfg, net.get("city_db", {}))
	var t := Track.new()
	t.setup(plan, cfg, net["scenery"])
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var p := RoadPath3D.new()
	p.setup(t, 0, r1)
	p.ensure(600)
	var terr := TerrainProfile.new()
	terr.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
	var ctx := ChunkContext.new()
	ctx.cfg = cfg
	ctx.capture(0, 0, 32, p, terr, t)
	var ctx1 := ChunkContext.new()
	ctx1.cfg = cfg
	ctx1.capture(1, 32, 64, p, terr, t)
	print("stage %s from %s: first curves:" % [stage, from])
	for k in 80:
		var s := t.get_segment(k)
		if absf(s.curve) > 0.0:
			print("  first curve at seg %d z %.0f m curve %.3f" % [k, s.z, s.curve])
			break
	print("corridor width (m beyond shoulder) left/right at rows 0, 5, 10, 20, 30, 40, 50, 60:")
	for k: int in [0, 5, 10, 20, 30, 40, 50, 60]:
		print("  row %d (z %.0f m): left %.1f right %.1f" % [k, k * 3.0, terr.corridor_width(k, -1), terr.corridor_width(k, 1)])
	print("props with |x| < 40 m in the first 40 segments (z, x, set, decorative, in_bend_corridor):")
	for k in 64:
		var s := t.get_segment(k)
		for it: Dictionary in s.sprites:
			if str(it.get("kind", "prop")) != "prop":
				continue
			var x := float(it.get("x", 0.0))
			var z := float(it.get("z", s.z))
			if absf(x) > 40.0:
				continue
			var c: ChunkContext = ctx if k < 32 else ctx1
			print("  seg %d z %.1f x %.1f side %d set %s decorative %s corridor %s" % [k, z, x, int(it.get("side", 1)), str(it.get("set", "")),
				str(not it.has("offset")), str(c.in_bend_corridor(z, x))])
	quit(0)
