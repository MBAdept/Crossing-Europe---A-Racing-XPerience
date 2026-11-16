extends SceneTree
## QA lens 1: are the roads of the fairness sims (Track without a scenery db, whole track kept) the roads of the game
## (GameData plan, scenery db, window cut behind the camera as the session drives)?

const Fair := preload("res://tests/race3d/fairness.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var game_data: Node = root.get_node("GameData")
	var bad := 0
	var checked := 0
	for name: String in ["saragossa_pau__pau", "bukarest_sibiu__sibiu", "kiel_hamburg__kiel", "bern_mailand__bern", "dortmund_frankfurt__dortmund", "erfurt_kassel__erfurt"]:
		var dir: Dictionary = Fair.directions(net, [name])[0]
		var geo := Fair.build_geo(cfg, net, dir)          # as modern_sight.gd builds it: no scenery
		var sim_track: Track = geo["track"]
		# the game's own track: plan from GameData, scenery db, generated on demand while a camera drives along
		var plan: StagePlan = game_data.call("get_stage_plan", str(dir["stage"]["id"]), str(dir["from"]))
		var t := Track.new()
		t.setup(plan, game_data.get("cfg") if game_data.get("cfg") != null else cfg, game_data.get("scenery"))
		var n := t.segment_count
		var diffs := 0
		var worst_c := 0.0
		var worst_y := 0.0
		var cam := 0
		var lanes_diff := 0
		while cam < n - 1:
			t.update_window(float(cam) * t.seg_len, 900.0)
			for k in range(cam, mini(cam + 20, n - 1)):
				var a := t.get_segment(k)
				var b := sim_track.get_segment(k)
				if a.index != k or b.index != k:
					continue
				worst_c = maxf(worst_c, absf(a.curve - b.curve))
				worst_y = maxf(worst_y, absf(a.y - b.y))
				if a.lanes != b.lanes or a.fuel_lane != b.fuel_lane or a.tunnel != b.tunnel or a.water != b.water or a.city != b.city:
					lanes_diff += 1
				checked += 1
			cam += 20
		var same := n == sim_track.segment_count and worst_c == 0.0 and worst_y == 0.0 and lanes_diff == 0
		if not same:
			bad += 1
		print("QA-GEO %-32s %s  %d segments (sim %d): curve diff %.6f, height diff %.6f, lanes/tunnel/water/city differ on %d" % [name, "same  " if same else "ANDERS", n, sim_track.segment_count, worst_c, worst_y, lanes_diff])
	print("QA-GEO ERGEBNIS %d von 6 verschieden, %d Segmente verglichen" % [bad, checked])
	quit(0 if bad == 0 else 1)
