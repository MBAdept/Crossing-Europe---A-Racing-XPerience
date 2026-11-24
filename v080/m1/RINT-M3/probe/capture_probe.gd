extends SceneTree
## RINT-M3 probe (note 7): main-thread cost of ChunkContext.capture() per chunk along a whole stage (headless), with the
## sight corridor computed beforehand (as the streamer's warm() does in play, so no synchronous corridor work), and its
## parts: RoadPath3D.rows_local(), the segment snapshots, TerrainProfile.rows(), the envelope loop (R7a). Works on the
## base too (no corridor there: the envelope part is skipped).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a: Dictionary = CliArgs.all()
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "kiel")), "vehicle": "limousine", "start_world_minutes": 12.0 * 60.0,
		"weather": "normal", "start_km": 0.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 7, "gfx": "modern", "no_countdown": true, "traffic_warmup": false}
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 6000:
		await process_frame
		n += 1
	var r: Object = sc.get("renderer")
	var terrain: Object = r.get("terrain")
	var path: Object = r.get("path")
	var tr: Object = r.get("track")
	var sight: Variant = terrain.get("sight")
	var end := int(path.call("end_index"))
	path.call("ensure", end)
	if sight != null:
		(sight as Object).call("warm", end, -1)
	var cs := 32
	var rows := {"capture": [], "rows_local": [], "segs": [], "t_rows": [], "envelope": []}
	var worst: Array = []
	var ci := 1
	while (ci + 1) * cs <= end:
		var sa := ci * cs
		var sb := sa + cs
		var ctx := ChunkContext.new()
		var t0 := Time.get_ticks_usec()
		ctx.capture(ci, sa, sb, path, terrain, tr)
		var us := Time.get_ticks_usec() - t0
		(rows["capture"] as Array).append(us)
		worst.append([us, ci, sa])
		# the parts again (warm caches of the path and of the clearance)
		var t1 := Time.get_ticks_usec()
		path.call("rows_local", sa, sb)
		var t2 := Time.get_ticks_usec()
		for q in sb - sa + 1:
			ChunkContext.seg_snapshot(tr.call("get_segment", sa + q))
		var t3 := Time.get_ticks_usec()
		terrain.call("rows", sa, sb)
		var t4 := Time.get_ticks_usec()
		if sight != null:
			var em := int(ctx.get("envelope").size() - (sb - sa + 1)) / 2
			for q in sb - sa + 1 + 2 * em:
				var k := sa - em + q
				terrain.call("envelope_width", k, -1)
				terrain.call("envelope_width", k, 1)
		var t5 := Time.get_ticks_usec()
		(rows["rows_local"] as Array).append(t2 - t1)
		(rows["segs"] as Array).append(t3 - t2)
		(rows["t_rows"] as Array).append(t4 - t3)
		(rows["envelope"] as Array).append(t5 - t4)
		ci += 1
	print("PROBE stage %s: %d chunks of %d rows, corridor %s" % [str(setup["stage_id"]), (rows["capture"] as Array).size(), cs,
		"yes" if sight != null else "no (base)"])
	for k: String in rows:
		var v: Array = rows[k]
		if v.is_empty():
			continue
		var s := 0
		for x: int in v:
			s += x
		var srt := v.duplicate()
		srt.sort()
		print("PROBE %-10s avg %.3f ms median %.3f ms p90 %.3f ms max %.3f ms" % [k, float(s) / v.size() / 1000.0,
			srt[srt.size() / 2] / 1000.0, srt[int(srt.size() * 0.9)] / 1000.0, srt[-1] / 1000.0])
	worst.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	for w: Array in worst.slice(0, 8):
		print("PROBE capture %.3f ms chunk %d km %.2f" % [float(w[0]) / 1000.0, int(w[1]),
			float(tr.call("z_to_km", float(w[2]) * float(tr.get("seg_len"))))])
	quit(0)
