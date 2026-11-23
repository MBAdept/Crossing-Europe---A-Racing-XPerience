extends SceneTree
## QA-R7a probe (headless, R7a tree): main-thread cost of SightCorridor.warm() as the streamer calls it – a deadline of
## WARM_US (0.25 ms) per call, the deadline checked only after each camera: how long does one call really take
## (max, p99, calls above 1 / 2 / 4 ms)? Also ensure() for a whole chunk of 32 rows at once (a collect that finds the
## corridor not warmed – the "sync" path). Per stage, whole stage.
##   godot --headless --path . -s <this> [-- --stage=<dir>,…]
const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var names: Array = ["saragossa_pau__saragossa", "kiel_hamburg__kiel", "kassel_wuerzburg__kassel", "bern_mailand__bern"]
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
		for mode: String in ["warm", "chunk"]:
			var p := RoadPath3D.new()
			p.setup(t, 0, r1)
			p.set_clear_reach(1842.0)
			p.ensure(t.segment_count - 1)
			var sc := SightCorridor.new()
			sc.setup(p, t, tc)
			var times := PackedFloat64Array()
			var n := t.segment_count - 1
			if mode == "warm":
				var guard := 0
				while sc.front() <= n and guard < 1000000:
					var t0 := Time.get_ticks_usec()
					sc.warm(n, t0 + 250)
					times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
					guard += 1
			else:
				var k := 0
				while k < n:
					var t0 := Time.get_ticks_usec()
					sc.ensure(mini(k + 32, n))
					times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
					k += 32
			var srt := times.duplicate()
			srt.sort()
			var c1 := 0
			var c2 := 0
			var c4 := 0
			var sum := 0.0
			for v in times:
				sum += v
				if v > 1.0:
					c1 += 1
				if v > 2.0:
					c2 += 1
				if v > 4.0:
					c4 += 1
			var m := srt.size()
			print("WARMCOST %-32s %-5s rows %d calls %d cameras %d skipped %d: total %.0f ms, mean %.3f, p50 %.3f, p99 %.3f, max %.2f ms; >1 ms %d, >2 ms %d, >4 ms %d" % [
				dir["name"], mode, n, m, sc.cameras, sc.skipped, sum, sum / maxf(1.0, float(m)), srt[m / 2], srt[mini(m - 1, int(m * 0.99))],
				srt[m - 1], c1, c2, c4])
	quit(0)
