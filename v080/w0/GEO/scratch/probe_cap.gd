extends SceneTree
## Scratch: where does the 16-chunk cap leave out a chunk, and how near is it by air?

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var hist := {"<500": 0, "500-600": 0, "600-700": 0, "700-800": 0, ">=800": 0}
	var hits := 0
	var positions := 0
	var worst: Array = []
	var by_dir := {}
	var count_hist := {}
	for dir: Dictionary in Fair.directions(net, []):
		if Fair.max_curve_of_stage(cfg, dir["stage"]) < 0.4:
			continue
		var geo := Fair.build_geo(cfg, net, dir)
		var path: RoadPath3D = geo["path"]
		var n: int = geo["n"]
		var st := ChunkStreamer.new()
		st.setup(path, null, geo["track"], cfg, {}, true)
		var cam := 0
		while cam < n - 2:
			positions += 1
			var cam_z := float(cam) * 3.0
			st.max_chunks = 1000
			var wanted := st.wanted_for(cam_z, 900.0)
			count_hist[wanted.size()] = int(count_hist.get(wanted.size(), 0)) + 1
			if wanted.size() > 16:
				hits += 1
				by_dir[geo["name"]] = int(by_dir.get(geo["name"], 0)) + 1
				st.max_chunks = 16
				var kept := st.wanted_for(cam_z, 900.0)
				var cp := path.centre_at(cam_z)
				var nearest := INF
				var nearest_path := 0.0
				for ci: int in wanted:
					if kept.has(ci):
						continue
					for row: int in [ci * 32, ci * 32 + 16, mini(ci * 32 + 32, n - 1)]:
						var p := path.point(row)
						var d := Vector2(p.x - cp.x, p.z - cp.z).length()
						if d < nearest:
							nearest = d
							nearest_path = float(row) * 3.0 - cam_z
				var key := "<500" if nearest < 500.0 else ("500-600" if nearest < 600.0 else ("600-700" if nearest < 700.0 else ("700-800" if nearest < 800.0 else ">=800")))
				hist[key] = int(hist[key]) + 1
				worst.append([nearest, geo["name"], cam_z * float(geo["km_per_m"]), nearest_path])
			cam += 32
		st.free()
	worst.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	print("CAP positions with more than 16 wanted chunks: %d (of %d in the curvy stage directions); nearest left-out chunk by air: %s" % [hits, positions, str(hist)])
	print("CAP wanted-chunk counts: ", count_hist)
	print("CAP by stage direction: ", by_dir)
	for w: Array in worst.slice(0, 8):
		print("CAP   %.0f m by air (%.0f m of path ahead)  %s km %.1f" % [float(w[0]), float(w[3]), w[1], float(w[2])])
	quit(0)
