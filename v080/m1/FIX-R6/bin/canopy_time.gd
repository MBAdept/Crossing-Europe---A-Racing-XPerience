extends SceneTree
## FIX-R6: main-thread cost of StationB.canopy_columns() per canopy (DEV, KH, PN), with the path ensured like in the
## game (36 chunks ahead).   godot --headless --path . -s <this>

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const N := 32


func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, ["dev_testetappe", "kiel_hamburg", "prag_nuernberg"]):
		if str(dir["from"]) != str(dir["stage"]["from"]):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
		var tot := 0.0
		var mx := 0.0
		var n := 0
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
			var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
			var c := int(floor(r0 / (float(N) * t.seg_len)))
			p.ensure((c + 36) * N)
			var ctx := ChunkContext.new()
			ctx.cfg = cfg
			ctx.scenery_db = t.scenery_db
			ctx.capture(c, c * N, c * N + N, p, tp, t)
			t.get_segment(t.segment_index_at(r1 + 700.0))
			var ta := Time.get_ticks_usec()
			var sb := StationB.signs_behind(t, r0, r1)
			var tb := Time.get_ticks_usec()
			var xs: Array[float] = [StationB.paved_edge_at(t, r1 - 0.45) + 1.3, StationB.paved_edge_at(t, r1 - 0.45) + 6.3]
			StationB.end_column_hides(t, p, r1 - 0.45, xs, sb["boards"])
			var tc := Time.get_ticks_usec()
			var ex := {}
			StationB.end_column_hides(t, p, r1 - 0.45, xs, sb["boards"], ex)
			StationB.end_column_hides(t, p, r1 - 0.45, xs, sb["boards"], ex)
			var td := Time.get_ticks_usec()
			print("PART signs_behind %.2f ms, hides %.2f ms, hides cached cams %.2f ms, boards %d" % [float(tb - ta) / 1000.0, float(tc - tb) / 1000.0, float(td - tc) / 2000.0, (sb["boards"] as Array).size()])
			var t0 := Time.get_ticks_usec()
			var cols := StationB.canopy_columns(ctx, r0, r1)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0
			tot += ms
			mx = maxf(mx, ms)
			n += 1
			print("CANOPY %s km %.2f %.2f ms %s" % [dir["name"], t.z_to_km(r0), ms, str(cols)])
		print("CANOPY-SUM %s %d canopies, mean %.2f ms, max %.2f ms" % [dir["name"], n, tot / maxf(1.0, float(n)), mx])
	quit(0)
