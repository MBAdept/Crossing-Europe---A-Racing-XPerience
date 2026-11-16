extends SceneTree
## RINT-M2 probe (note 8): main-thread cost of the canopy decision – canopy_job() (gather on the main thread),
## job.run()
##   godot --headless --path . -s <this> [-- --only=<stage,…>]

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const N := 32


func _initialize() -> void:
	var only: Array = ["dev_testetappe", "kiel_hamburg"]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, only)
	var gmax := 0.0
	var rmax := 0.0
	var imax := 0.0
	var n := 0
	var gsum := 0.0
	var bmax := 0.0
	var cmax := 0.0
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
			var t0 := Time.get_ticks_usec()
			var job: Variant = StationB.canopy_job_begin(ctx, r0, r1)
			var tb := Time.get_ticks_usec()
			StationB.canopy_job_rest(ctx, job)
			var tc := Time.get_ticks_usec()
			bmax = maxf(bmax, float(tb - t0) / 1000.0)
			cmax = maxf(cmax, float(tc - tb) / 1000.0)
			var t1 := Time.get_ticks_usec()
			job.run()
			job.finish(t, tpf)
			var t2 := Time.get_ticks_usec()
			StationB.canopy_columns(ctx, r0, r1)
			var t3 := Time.get_ticks_usec()
			var g := float(t1 - t0) / 1000.0
			var r := float(t2 - t1) / 1000.0
			var i := float(t3 - t2) / 1000.0
			gmax = maxf(gmax, g)
			rmax = maxf(rmax, r)
			imax = maxf(imax, i)
			gsum += g
			n += 1
			print("CANOPY %s km %.2f gather %.3f ms  run %.3f ms  inline %.3f ms" % [name, t.z_to_km(r0), g, r, i])
	print("CANOPY-HALVES begin max %.3f ms, rest max %.3f ms" % [bmax, cmax])
	print("CANOPY-SUMMARY n=%d gather max %.3f avg %.3f ms; run max %.3f ms; inline max %.3f ms" % [n, gmax, gsum / maxf(n, 1), rmax, imax])
	quit(0)
