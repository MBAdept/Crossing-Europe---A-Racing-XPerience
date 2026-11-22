extends SceneTree
## R7a: cost of the sight corridor per stage direction (headless).  -- --stage=<id>[,<id>] [--cam=2] [--row=2]
const Fair := preload("res://tests/race3d/fairness.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var only: Array = []
	var cam := 2
	var row := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			only = Array(a.substr(8).split(",", false))
		if a.begins_with("--cam="):
			cam = int(a.substr(6))
		if a.begins_with("--row="):
			row = int(a.substr(6))
	var dirs := Fair.directions(net, only)
	var tot_rows := 0
	var tot_us := 0
	var tot_terr := 0
	for dir: Dictionary in dirs:
		var geo := Fair.build_geo(cfg, net, dir)
		var tc: Dictionary = (ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}) as Dictionary).duplicate()
		var terrain := TerrainProfile.new()
		var path: RoadPath3D = geo["path"]
		var chunk_m := 96.0
		path.set_clear_reach(float(ConfigLoader.lookup(cfg, "graphics.modern.load_path_m", 1500.0)) + 150.0 + 2.0 * chunk_m)
		terrain.setup(path, geo["track"], tc, {})
		terrain.sight.cam_step = cam
		terrain.sight.row_step = row
		var t0 := Time.get_ticks_usec()
		var rows := terrain.rows(0, int(geo["n"]) - 1)
		var us := Time.get_ticks_usec() - t0
		var corr: PackedVector2Array = rows["corridor"]
		var bend := 0
		for c in corr:
			if c.x > 6.0:
				bend += 1
			if c.y > 6.0:
				bend += 1
		print("COST %-40s rows %6d terrain %6.0f ms sight %6.0f ms (%.1f us/row) cameras %d skipped %d bend sides %d" % [dir["name"], int(geo["n"]),
			us / 1000.0, terrain.sight.usec / 1000.0, float(terrain.sight.usec) / float(geo["n"]), terrain.sight.cameras, terrain.sight.skipped, bend])
		tot_rows += int(geo["n"])
		tot_us += terrain.sight.usec
		tot_terr += us
		geo["path"] = null
	print("COST total rows %d terrain %.1f s sight %.1f s (%.1f us/row)" % [tot_rows, tot_terr / 1e6, tot_us / 1e6, float(tot_us) / float(maxi(tot_rows, 1))])
	quit(0)
