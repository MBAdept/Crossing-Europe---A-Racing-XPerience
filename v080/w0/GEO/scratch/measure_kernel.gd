extends SceneTree
## Scratch (GEO): the measured numbers of the kernel for the report.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")


func _real_track(cfg: Dictionary, net: Dictionary, stage_id: String) -> Track:
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		return t
	return null


func _pct(a: PackedFloat32Array, p: float) -> float:
	return Fair.percentile(a, p)


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	# 1 arc
	for radius: float in [134.0, 400.0]:
		var t: Track = SynTrack.new()
		t.fill(cfg, SynTrack.arc(304, radius))
		var p := RoadPath3D.new()
		p.setup(t, 0, 120.0)
		var a := p.arrays(0, 300)
		var worst := 0.0
		for k in 301:
			var th := float(k) * 3.0 / radius
			worst = maxf(worst, Vector2((a["x"] as PackedFloat64Array)[k] - radius * (1.0 - cos(th)), (a["z"] as PackedFloat64Array)[k] + radius * sin(th)).length())
		print("ARC R %.0f m over 900 m: max deviation from the closed form %.2f mm" % [radius, worst * 1000.0])
	# 3 camera parity on a straight
	var proj := Fair.make_projection(cfg)
	var cam := Fair.make_camera(cfg, proj)
	var ts: Track = SynTrack.new()
	ts.fill(cfg, SynTrack.straight(400), SynTrack.grades(400, [[0, 0.05], [90, -0.06], [200, 0.0]]))
	var ps := RoadPath3D.new()
	ps.setup(ts, 0, 120.0)
	for size: Vector2 in [Vector2(1280, 720), Vector2(1280, 800), Vector2(1680, 720)]:
		var pr := RoadProjection.new()
		pr.setup(ConfigLoader.lookup(cfg, "render", {}), size)
		pr.focal = proj.focal
		var fr := cam.frustum(size)
		var worst := 0.0
		for cam_z: float in [12.0, 190.5, 301.0]:
			for cam_x: float in [-3.75, 0.0, 2.2]:
				var cam_y := ts.height_at(cam_z + 9.0) + 3.4
				var xf := cam.transform({"camera_z": cam_z, "camera_x": cam_x, "camera_y": cam_y}, ps)
				var d := 10.0
				while d <= 600.0:
					for x: float in [-9.0, -3.75, 0.0, 5.6, 9.0]:
						for h: float in [0.0, 1.5, 4.2]:
							var p3 := ChaseCamera3D.project(xf, fr, size, ps.world(cam_z + d, x, h))
							var pa := pr.project(x - cam_x, ts.height_at(cam_z + d) + h - cam_y, d)
							worst = maxf(worst, Vector2(p3.x - pa.x, p3.y - pa.y).length())
					d += 14.75
		print("CAMERA %dx%d: max deviation from Arcade's projection on a straight up to 600 m: %.4f px" % [int(size.x), int(size.y), worst])
	# reference positions: parity in bends with the tangent camera (look_gain 0) and with the shipped camera
	for ref: Array in [["kassel_wuerzburg", 46.2], ["kassel_wuerzburg", 46.5], ["kassel_wuerzburg", 61.9], ["saragossa_pau", 198.3], ["saragossa_pau", 198.8], ["saragossa_pau", 172.8]]:
		var t := _real_track(cfg, net, str(ref[0]))
		var geo := Fair.geo_of_track(cfg, t, str(ref[0]))
		var path: RoadPath3D = geo["path"]
		var c := int(t.km_to_z(float(ref[1])) / 3.0)
		var line := "PARITY %s km %.1f (curve %.2f at the camera): " % [ref[0], float(ref[1]), t.get_segment(c).curve]
		for gain: float in [0.0, 0.6]:
			var cm := Fair.make_camera(cfg, proj, {"look_gain": gain})
			var cam_y := t.height_at(float(c + 3) * 3.0) + proj.cam_height
			var xf := cm.transform({"camera_z": float(c) * 3.0, "camera_x": 0.0, "camera_y": cam_y}, path)
			var fr := cm.frustum(proj.screen)
			line += "look_gain %.1f:" % gain
			for lim: float in [100.0, 150.0, 200.0, 300.0]:
				var worst := 0.0
				var k := 4
				while float(k) * 3.0 <= lim:
					for x: float in [-5.6, 0.0, 5.6]:
						var p3 := ChaseCamera3D.project(xf, fr, proj.screen, path.world(float(c + k) * 3.0, x, 0.0))
						var pa := proj.project(Fair.arcade_x(geo, c, k) + x, t.get_segment(c + k).y - cam_y, float(k) * 3.0)
						worst = maxf(worst, absf(p3.x - pa.x))
					k += 1
				line += " <=%.0f m %.1f px" % [lim, worst]
			line += " | "
		print(line)
	# 4 streamer timings on real stages (real scenery, debug road)
	for spec: Array in [["kiel_hamburg", 2.0, 250.0], ["saragossa_pau", 168.0, 140.0], ["dortmund_frankfurt", 215.0, 120.0]]:
		for sync: bool in [false, true]:
			var t := _real_track(cfg, net, str(spec[0]))
			var p := RoadPath3D.new()
			var tp := TerrainProfile.new()
			tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
			var st := ChunkStreamer.new()
			st.setup(p, tp, t, cfg, {}, sync)
			st.register(BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD))
			root.add_child(st)
			var cam_z := t.km_to_z(float(spec[1]))
			var step := float(spec[2]) / 3.6 / 60.0
			var t0 := Time.get_ticks_usec()
			t.update_window(cam_z, 960.0)
			st.update(cam_z, 900.0)
			var load_ms := float(Time.get_ticks_usec() - t0) / 1000.0
			var load_chunks := st.chunk_count()
			st.reset_stats()
			var times := PackedFloat32Array()
			var track_times := PackedFloat32Array()
			var max_chunks := 0
			for f in 3600:
				cam_z += step
				var a := Time.get_ticks_usec()
				t.update_window(cam_z, 960.0)
				var b := Time.get_ticks_usec()
				st.update(cam_z, 900.0)
				var c := Time.get_ticks_usec()
				track_times.append(float(b - a) / 1000.0)
				times.append(float(c - b) / 1000.0)
				max_chunks = maxi(max_chunks, st.chunk_count())
			var s := st.stats()
			print("STREAM %-18s %s %3.0f km/h: load %.1f ms (%d chunks) | update() per frame avg %.3f ms p95 %.3f p99 %.3f max %.3f | Track.update_window avg %.3f max %.3f | collect avg %.2f max %.2f ms, build avg %.2f max %.2f ms, commit avg %.2f max %.2f ms (%d chunks built), max %d chunks" % [
				spec[0], "sync    " if sync else "threaded", float(spec[2]), load_ms, load_chunks, _pct(times, 50.0) * 0.0 + _avg(times), _pct(times, 95.0), _pct(times, 99.0), _pct(times, 100.0),
				_avg(track_times), _pct(track_times, 100.0), float(s["collect_ms_avg"]), float(s["collect_ms_max"]), float(s["build_ms_avg"]), float(s["build_ms_max"]),
				float(s["commit_ms_avg"]), float(s["commit_ms_max"]), int(s["builds"]), max_chunks])
			st.clear()
			st.queue_free()
	# 5 single costs
	var tk := _real_track(cfg, net, "saragossa_pau")
	var pk := RoadPath3D.new()
	pk.setup(tk, 5200, 120.0)
	var tpk := TerrainProfile.new()
	tpk.setup(pk, tk, {}, {})
	pk.clear_reach_m = 1842.0
	pk.ensure(5200 + 2400)
	var n := 0
	var u0 := Time.get_ticks_usec()
	for k in range(5800, 6600, 8):
		pk.clearance(k, 1)
		n += 1
	var u1 := Time.get_ticks_usec()
	print("COST clearance of one coarse row (both sides, window ±1842 m): %.1f us" % (float(u1 - u0) / float(n)))
	u0 = Time.get_ticks_usec()
	for c in range(190, 200):
		tpk.rows(c * 32, c * 32 + 32)
	u1 = Time.get_ticks_usec()
	print("COST TerrainProfile.rows() of one chunk: %.2f ms" % (float(u1 - u0) / 10000.0))
	u0 = Time.get_ticks_usec()
	for c in range(200, 210):
		var ctx := ChunkContext.new()
		ctx.capture(c, c * 32, c * 32 + 32, pk, tpk, tk)
	u1 = Time.get_ticks_usec()
	print("COST ChunkContext.capture() of one chunk (no scenery sprites): %.2f ms" % (float(u1 - u0) / 10000.0))
	quit(0)


func _avg(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(1.0, float(a.size()))
