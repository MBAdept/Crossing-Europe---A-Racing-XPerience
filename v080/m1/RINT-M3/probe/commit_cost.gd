extends SceneTree
## RINT-M3 probe (Xvfb, opengl3): main-thread cost of commit() of road, roadside and terrain parts of real chunks, whole
## and in 2 / 3 pieces – median and max over many commits (the node not in the tree, as in the streamer), and the cost of
## the first frame that draws the committed meshes.
const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var t: Track = null
	for dir: Dictionary in Fair.directions(net, ["kiel_hamburg"]):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		t = Track.new()
		t.setup(plan, cfg, net["scenery"])
		break
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
	var st := ChunkStreamer.new()
	st.setup(p, tp, t, cfg, {"shadow_casters": 1}, true)
	var builders := {}
	for id: String in ["road", "roadside", "terrain"]:
		var b: ChunkBuilder = load("res://scripts/race3d/builders/%s.gd" % id).new()
		builders[id] = b
		st.register(b)
	root.add_child(st)
	st.update(2000.0, 900.0)
	var parts := {"road": [], "roadside": [], "terrain": []}
	var ctxs: Array = []
	for c: Variant in st.get("_chunks").values():
		ctxs.append(c.ctx)
		for i in 3:
			var b: ChunkBuilder = st.builders()[i]
			(parts[b.id()] as Array).append([c.ctx, c.parts[i]])
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	for id: String in parts:
		for pieces in [1, 2, 3]:
			var times: Array = []
			for rep in 3:
				for pr: Array in parts[id]:
					var part: Dictionary = (pr[1] as Dictionary).duplicate()
					if id == "terrain":
						part["pieces"] = ChunkBuilder.split_arrays(builders[id].call("arrays_of", part), pieces) if pieces > 1 else []
					else:
						part["pieces"] = ChunkBuilder.split_arrays(part["arrays"], pieces) if pieces > 1 else []
					var node := Node3D.new()
					var steps: int = builders[id].commit_steps(part)
					for k in steps:
						var t0 := Time.get_ticks_usec()
						builders[id].commit_step(pr[0], part, node, k)
						times.append(Time.get_ticks_usec() - t0)
					node.free()
			times.sort()
			print("COMMIT %-9s pieces=%d steps=%d median=%.3f ms p90=%.3f ms max=%.3f ms" % [id, pieces, times.size(), times[times.size() / 2] / 1000.0,
				times[int(times.size() * 0.9)] / 1000.0, times[-1] / 1000.0])
	quit()
