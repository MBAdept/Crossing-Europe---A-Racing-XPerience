extends SceneTree
## QA lens 1: ChunkStreamer on real mountain stages – at most 16 chunks, sync twice = same snapshots,
## threaded ends in the same snapshot, also with changing visibility and a realistic frame cadence.

const Fair := preload("res://tests/race3d/fairness.gd")

var cfg: Dictionary
var net: Dictionary
var fails := 0

func _ok(name: String, cond: bool, msg: String) -> void:
	print("QA-STREAM %-26s %s  %s" % [name, "OK    " if cond else "FEHLER", msg])
	if not cond:
		fails += 1

func _track(name: String, scenery: bool) -> Track:
	var dir: Dictionary = Fair.directions(net, [name])[0]
	var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
	var t := Track.new()
	t.setup(plan, cfg, net["scenery"] if scenery else {})
	return t

func _streamer(t: Track, sync: bool, with_road: bool, levels: Dictionary = {}) -> Array:
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
	var st := ChunkStreamer.new()
	st.setup(p, tp, t, cfg, levels, sync)
	if with_road:
		st.register(BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD))
	root.add_child(st)
	return [st, p, tp]

func _vis(z: float, vary: bool) -> float:
	if not vary:
		return 900.0
	# fog banks: the visibility swings between 250 m and 900 m along the road
	return 575.0 + 325.0 * sin(z * 0.004)

## Drives the camera from km a to km b of visible road like the session: update_window, then the streamer.
func _drive(name: String, z0: float, z1: float, step: float, sync: bool, vary_vis: bool, levels: Dictionary = {}) -> Dictionary:
	var t := _track(name, true)
	var m := _streamer(t, sync, true, levels)
	var st: ChunkStreamer = m[0]
	var z := z0
	var max_chunks := 0
	var hashes: Array = []
	var n := 0
	var draw := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	while z < z1:
		t.update_window(z, draw)
		st.update(z, _vis(z, vary_vis))
		max_chunks = maxi(max_chunks, st.chunk_count())
		if sync and n % 16 == 0:
			hashes.append(JSON.stringify(st.snapshot()).hash())
		z += step
		n += 1
	# settle: the camera stands, the streamer finishes what it wants
	var settle := 0
	while (not st.is_idle() or settle < 3) and settle < 400:
		st.update(z - step, _vis(z - step, vary_vis))
		settle += 1
		if not sync:
			OS.delay_msec(2)
	st.flush()
	var final := JSON.stringify(st.snapshot())
	var stats := st.stats()
	var ids: Array = []
	for c: Dictionary in st.snapshot()["chunks"]:
		ids.append(int(c["index"]))
	st.clear()
	root.remove_child(st)
	st.free()
	return {"max": max_chunks, "hashes": hashes, "final": final, "ids": ids, "stats": stats, "updates": n, "settle": settle}

func _initialize() -> void:
	cfg = ConfigLoader.load_merged()
	net = Fair.load_network()
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	# saragossa_pau__pau km 40-44 is where the load rule wants 17-18 chunks (GEO's report): visible z = km * 1000 / 12
	var scale := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	for case: Array in [["saragossa_pau__pau", 38.0, 46.0], ["bukarest_sibiu__sibiu", 54.0, 60.0]]:
		var name: String = case[0]
		var z0 := float(case[1]) * 1000.0 / scale
		var z1 := float(case[2]) * 1000.0 / scale
		var a := _drive(name, z0, z1, 3.0, true, false)
		var b := _drive(name, z0, z1, 3.0, true, false)
		_ok("sync twice " + name, a["hashes"] == b["hashes"] and a["final"] == b["final"], "km %.0f–%.0f, %d updates, %d snapshots compared, final snapshots equal %s" % [case[1], case[2], int(a["updates"]), (a["hashes"] as Array).size(), a["final"] == b["final"]])
		_ok("max chunks " + name, int(a["max"]) <= 16, "largest number of chunks held: %d (limit 16); rebases %d, restarts %d" % [int(a["max"]), int(a["stats"]["rebases"]), int(a["stats"]["restarts"])])
		# threaded with the cadence of a drive at 250 km/h (1.16 m per frame) and a fast one
		for step: float in [1.16, 7.0]:
			var c := _drive(name, z0, z1, step, false, false)
			var s2 := _drive(name, z0, z1, step, true, false)
			var same: bool = c["final"] == s2["final"]
			_ok("threaded %.2f m %s" % [step, name], same and int(c["max"]) <= 16, "threaded ends in the sync snapshot: %s (chunks %s vs %s), max %d, builds %d, settle updates %d" % [same, str(c["ids"]), str(s2["ids"]), int(c["max"]), int(c["stats"]["builds"]), int(c["settle"])])
		# changing visibility (fog banks)
		var v1 := _drive(name, z0, z1, 3.0, true, true)
		var v2 := _drive(name, z0, z1, 3.0, false, true)
		var same_ids: bool = v1["ids"] == v2["ids"]
		_ok("changing visibility " + name, int(v1["max"]) <= 16 and int(v2["max"]) <= 16, "max %d (sync) / %d (threaded); final chunk sets %s: %s vs %s; snapshots equal %s" % [int(v1["max"]), int(v2["max"]),
			"equal" if same_ids else "DIFFERENT", str(v1["ids"]), str(v2["ids"]), v1["final"] == v2["final"]])
	if CliArgs.has("long"):
		# the whole stage, threaded at 2.9 m per frame against sync
		var t := _track("saragossa_pau__pau", false)
		var z_end := t.length_z - 30.0
		var l1 := _drive("saragossa_pau__pau", 10.0, z_end, 2.9, false, false)
		var l2 := _drive("saragossa_pau__pau", 10.0, z_end, 2.9, true, false)
		_ok("whole stage threaded", l1["final"] == l2["final"] and int(l1["max"]) <= 16 and int(l2["max"]) <= 16 and int(l1["stats"]["rebases"]) > 3,
			"%.1f km of visible road, %d updates: threaded = sync at the end %s, max %d / %d, rebases %d / %d, restarts %d / %d" % [z_end / 1000.0, int(l1["updates"]),
			l1["final"] == l2["final"], int(l1["max"]), int(l2["max"]), int(l1["stats"]["rebases"]), int(l2["stats"]["rebases"]), int(l1["stats"]["restarts"]), int(l2["stats"]["restarts"])])
	# Details: Hoch (outer ring 1,000 m)
	var h1 := _drive("saragossa_pau__pau", 40.0 * 1000.0 / scale, 43.0 * 1000.0 / scale, 3.0, true, false, {"terrain_outer_m": 1000.0})
	var h2 := _drive("saragossa_pau__pau", 40.0 * 1000.0 / scale, 43.0 * 1000.0 / scale, 3.0, false, false, {"terrain_outer_m": 1000.0})
	_ok("outer ring 1000 m", h1["final"] == h2["final"] and int(h1["max"]) <= 16, "sync = threaded %s, max %d" % [h1["final"] == h2["final"], int(h1["max"])])
	print("QA-STREAM ERGEBNIS %d fehlgeschlagen (%.0f s)" % [fails, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if fails == 0 else 1)
