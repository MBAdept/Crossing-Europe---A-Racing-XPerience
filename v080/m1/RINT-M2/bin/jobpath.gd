extends SceneTree
## RINT-M2 probe (note 8): the canopy decision through columns_in_chunk() in streaming order (warm-ahead jobs, worker
## threads, shared lane/curvature caches, finish()) must equal canopy_columns() inline, for every canopy of the network.
## Also reports how many canopies the streaming order had to decide inline (not warmed in time) and the main-thread
## time of each columns_in_chunk() call.   godot --headless --path . -s <this> [-- --only=<stage,…>]

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const N := 32


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, only)
	var canopies := 0
	var diffs := 0
	var tmax := 0.0
	var over2 := 0
	var calls := 0
	for dir: Dictionary in dirs:
		var name := str(dir["name"])
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var has := false
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) == "fuel_canopy":
				has = true
				break
		if not has:
			continue
		var r1c := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
		var p := RoadPath3D.new()
		p.setup(t, 0, r1c)
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		var cache := {}
		var nchunks := int(ceil(float(t.segment_count) / float(N)))
		for ci in nchunks - 1:
			p.ensure(mini((ci + 40) * N, t.segment_count - 1))
			var ctx := ChunkContext.new()
			ctx.cfg = cfg
			ctx.scenery_db = t.scenery_db
			ctx.capture(ci, ci * N, ci * N + N, p, tp, t)
			var t0 := Time.get_ticks_usec()
			StationB.columns_in_chunk(ctx, cache)
			var dt := float(Time.get_ticks_usec() - t0) / 1000.0
			calls += 1
			tmax = maxf(tmax, dt)
			over2 += 1 if dt > 2.0 else 0
			if dt > 2.0:
				var inl := 0
				for zn: Dictionary in t.zones:
					if str(zn["kind"]) == "fuel_canopy":
						var r0x := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
						if r0x >= float(ci * N) * t.seg_len and r0x < float(ci * N + N) * t.seg_len:
							inl += 1
				print("JOBPATH-SLOW %s chunk %d km %.2f %.3f ms (canopies starting in it %d)" % [name, ci, t.z_to_km(float(ci * N) * t.seg_len), dt, inl])
		# compare every canopy with the inline decision
		var full := RoadPath3D.new()
		full.setup(t, 0, r1c)
		var tpf := TerrainProfile.new()
		tpf.setup(full, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
			var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
			var key := "%.3f" % r0
			var got: Variant = cache.get(key)
			if not (got is Array):
				continue
			var ci := int(floor(r0 / (float(N) * t.seg_len)))
			full.ensure(t.segment_index_at(r1 + 1300.0))
			var ctx2 := ChunkContext.new()
			ctx2.cfg = cfg
			ctx2.scenery_db = t.scenery_db
			ctx2.capture(ci, ci * N, ci * N + N, full, tpf, t)
			var ref := StationB.canopy_columns(ctx2, r0, r1)
			canopies += 1
			if str(ref) != str(got):
				diffs += 1
				print("JOBPATH %s km %.2f inline %s / streamed %s" % [name, t.z_to_km(r0), str(ref), str(got)])
	print("JOBPATH-SUMMARY canopies=%d differing=%d; columns_in_chunk calls %d, max %.3f ms, over 2 ms %d" % [canopies, diffs, calls, tmax, over2])
	quit(0)
