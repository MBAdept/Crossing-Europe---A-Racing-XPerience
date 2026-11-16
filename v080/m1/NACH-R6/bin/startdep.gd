extends SceneTree
## NACH-R6 probe: does the column decision of a fuel-station canopy (Station.canopy_columns(), FIX-R6) depend on where
## the race started? In the game the streamer sets the path up at (start - keep_behind_m) (ChunkStreamer._restart);
## end_column_hides() skips cameras the path does not hold. Compares, per canopy, the decision with the path from the
## stage start (as in a race from km 0) with the decision when the race starts `lead` metres before the canopy.
##   godot --headless --path . -s <this> [-- --only=<stage,…>]

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const N := 32
const KEEP_BEHIND := 150.0
const LEADS: Array[float] = [100.0, 300.0, 500.0]

var cfg: Dictionary


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	cfg = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, only)
	var canopies := 0
	var diffs := 0
	var lines: Array = []
	for dir: Dictionary in dirs:
		var name := str(dir["name"])
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var r1c := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
		var full := RoadPath3D.new()
		full.setup(t, 0, r1c)
		var tpf := TerrainProfile.new()
		tpf.setup(full, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
			var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
			var ci := int(floor(r0 / (float(N) * t.seg_len)))
			full.ensure(t.segment_index_at(r1 + 1300.0))
			var ctx := ChunkContext.new()
			ctx.cfg = cfg
			ctx.scenery_db = t.scenery_db
			ctx.capture(ci, ci * N, ci * N + N, full, tpf, t)
			var ref := StationB.canopy_columns(ctx, r0, r1)
			canopies += 1
			for lead: float in LEADS:
				var start := r0 - lead
				if start - KEEP_BEHIND < 0.0:
					continue
				var c_lo := int(floor((start - KEEP_BEHIND) / (float(N) * t.seg_len)))
				var p := RoadPath3D.new()
				p.setup(t, c_lo * N, r1c)
				var tp := TerrainProfile.new()
				tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
				p.ensure(t.segment_index_at(r1 + 1300.0))
				var c2 := ChunkContext.new()
				c2.cfg = cfg
				c2.scenery_db = t.scenery_db
				c2.capture(ci, ci * N, ci * N + N, p, tp, t)
				var got := StationB.canopy_columns(c2, r0, r1)
				if str(got) != str(ref):
					diffs += 1
					lines.append("%s km %.2f start %d m before: from km 0 %s  /  late start %s" % [name, t.z_to_km(r0), int(lead), str(ref), str(got)])
	for l: String in lines:
		print("STARTDEP ", l)
	print("STARTDEP-SUMMARY canopies=%d differing_decisions=%d (of %d late starts each)" % [canopies, diffs, LEADS.size()])
	quit(0)
