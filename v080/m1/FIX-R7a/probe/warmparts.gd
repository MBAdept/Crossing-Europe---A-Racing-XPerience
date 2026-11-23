extends SceneTree
## FIX-R7a probe (headless): what one step of SightCorridor costs on the main thread – the geometry block
## (_geometry), the F2 need block (_ensure_need) and the fan of one camera – and what a warm() call with the
## streamer's deadline (0.25 ms) really takes. Whole stages, path generated beforehand (as QA-R7a's warmcost.gd), and
## once more with the path generated lazily (path.ensure inside _geometry, as in the game).
##   godot --headless --path . -s <this> [-- --stage=<dir>,…]
const Fair := preload("res://tests/race3d/fairness.gd")


func _stats(name: String, v: PackedFloat64Array) -> String:
	if v.is_empty():
		return "%s –" % name
	var s := v.duplicate()
	s.sort()
	var sum := 0.0
	for x in v:
		sum += x
	var m := s.size()
	return "%s n %d mean %.3f p50 %.3f p99 %.3f max %.2f ms" % [name, m, sum / float(m), s[m / 2], s[mini(m - 1, int(m * 0.99))], s[m - 1]]


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var names: Array = ["saragossa_pau__saragossa", "kiel_hamburg__kiel", "bern_mailand__bern"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			names = Array(a.substr(8).split(",", false))
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	for dir: Dictionary in Fair.directions(net, []):
		if not names.has(str(dir["name"])):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var n := t.segment_count - 1
		# parts, path ready
		var p := RoadPath3D.new()
		p.setup(t, 0, r1)
		p.set_clear_reach(1842.0)
		p.ensure(n)
		var sc := SightCorridor.new()
		sc.setup(p, t, tc)
		sc.warm(-1000000, -1)     # starts it
		var geo := PackedFloat64Array()
		var need := PackedFloat64Array()
		var cam := PackedFloat64Array()
		var guard := 0
		while sc.front() <= n and guard < 1000000:
			var c := sc.front()
			var t0 := Time.get_ticks_usec()
			var g1: int = sc._g1
			sc._geometry(c)
			var t1 := Time.get_ticks_usec()
			if sc._g1 != g1:
				geo.append(float(t1 - t0) / 1000.0)
			var nh: int = sc._n_hi
			sc._ensure_need(c + sc._cam_rows)
			var t2 := Time.get_ticks_usec()
			if sc._n_hi != nh:
				need.append(float(t2 - t1) / 1000.0)
			sc.warm(c, -1)
			cam.append(float(Time.get_ticks_usec() - t2) / 1000.0)
			guard += 1
		print("PARTS %-28s %s | %s | %s" % [dir["name"], _stats("geometry", geo), _stats("need", need), _stats("camera", cam)])
		# warm() with the streamer's deadline, path lazily generated as far as the corridor needs it
		for lazy: bool in [false, true]:
			var p2 := RoadPath3D.new()
			p2.setup(t, 0, r1)
			p2.set_clear_reach(1842.0)
			if not lazy:
				p2.ensure(n)
			else:
				p2.ensure(200)
			var s2 := SightCorridor.new()
			s2.setup(p2, t, tc)
			var calls := PackedFloat64Array()
			guard = 0
			while s2.front() <= n and guard < 1000000:
				var t0 := Time.get_ticks_usec()
				s2.warm(n, t0 + 250)
				calls.append(float(Time.get_ticks_usec() - t0) / 1000.0)
				guard += 1
			var over := 0
			for v in calls:
				if v > 0.5:
					over += 1
			print("WARM  %-28s %s %s; calls > 0.5 ms: %d" % [dir["name"], "lazy " if lazy else "ready", _stats("call", calls), over])
	quit(0)
