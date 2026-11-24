extends SceneTree
## RINT-M3 probe: vertex counts of the road, roadside and terrain parts of every chunk of a stage (sync mode, real
## builders) – to choose ChunkBuilder.PIECE_VERTICES.
const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var stages: Array = Array(OS.get_cmdline_user_args()[0].split(",", false))
	var reg := load("res://scripts/race3d/builder_registry.gd")
	for dir: Dictionary in Fair.directions(net, stages):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
		var st := ChunkStreamer.new()
		st.setup(p, tp, t, cfg, {}, true)
		for id: String in ["road", "roadside", "terrain"]:
			st.register(load("res://scripts/race3d/builders/%s.gd" % id).new())
		var vals := {"road": [], "roadside": [], "terrain": []}
		var seen := {}
		var cam := 0.0
		var end_z := float(t.segment_count - 1) * t.seg_len
		while cam < end_z:
			st.update(cam, 900.0)
			for ch: Dictionary in st.snapshot()["chunks"]:
				if seen.has(int(ch["index"])):
					continue
				seen[int(ch["index"])] = true
				var parts: Dictionary = ch["parts"]
				for id: String in vals:
					var d: Dictionary = parts.get(id, {})
					(vals[id] as Array).append(int(d.get("vertices", 0)))
			cam += 600.0
		st.clear()
		st.free()
		for id: String in vals:
			var a: Array = vals[id]
			a.sort()
			if a.is_empty():
				continue
			print("VCOUNT %s %s n=%d min=%d p50=%d p90=%d max=%d" % [dir["name"], id, a.size(), a[0], a[a.size() / 2], a[int(a.size() * 0.9)], a[-1]])
	quit()
