extends SceneTree
## R7a probe (headless): (1) L (sight line length the corridor covers) at the camera of the picture / occlusion
## positions; (2) start dependence: the corridor of the rows from the camera to 1,600 m ahead when the stream starts
## there (path from the chunk 150 m behind the camera, like ChunkStreamer._restart) against a stream from km 0.
const Fair := preload("res://tests/race3d/fairness.gd")
const POS := [["T1", "kassel_wuerzburg", "kassel", 46.5], ["T2", "kassel_wuerzburg", "kassel", 61.9],
	["T3", "saragossa_pau", "saragossa", 172.8], ["T4", "saragossa_pau", "saragossa", 198.8], ["C1", "dortmund_frankfurt", "dortmund", 221.0],
	["S4", "kiel_hamburg", "kiel", 80.0], ["S0", "kiel_hamburg", "kiel", 0.0], ["Lyon", "montpellier_lyon", "montpellier", 297.4],
	["Bern", "lyon_bern", "lyon", 302.7], ["Muenchen", "muenchen_nuernberg", "nuernberg", 161.7],
	["Nuernberg", "wuerzburg_nuernberg", "wuerzburg", 102.7], ["Belgrad", "slavonski_brod_belgrad", "slavonski_brod", 187.4],
	["Hannover", "hamburg_hannover", "hamburg", 142.4]]


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	for p: Array in POS:
		var dir: Dictionary = {}
		for d: Dictionary in Fair.directions(net, [p[1]]):
			if str(d["from"]) == str(p[2]):
				dir = d
		# full stream from km 0
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t1 := Track.new()
		t1.setup(plan, cfg, net["scenery"])
		var p1 := RoadPath3D.new()
		p1.setup(t1, 0, 120.0)
		p1.set_clear_reach(1842.0)
		var tp1 := TerrainProfile.new()
		tp1.setup(p1, t1, tc, net["scenery"])
		var car := t1.km_to_z(float(p[3]))
		var cam := car - 9.0
		var k_cam := int(floor(maxf(cam, 0.0) / t1.seg_len))
		var k_end := k_cam + 533
		var full := PackedFloat32Array()
		for k in range(k_cam, k_end):
			full.append(tp1.corridor_width(k, -1))
			full.append(tp1.corridor_width(k, 1))
		var L := tp1.sight.chord_at(k_cam)
		var need := tp1.sight.need_at(k_cam + 3)
		# stream started at the position (the track generated up to there, then the path from the chunk behind)
		var t2 := Track.new()
		t2.setup(plan, cfg, net["scenery"])
		t2.update_window(cam, 960.0)
		var c_lo := maxi(0, int(floor((cam - 150.0) / 96.0)))
		var p2 := RoadPath3D.new()
		p2.setup(t2, c_lo * 32, 120.0)
		p2.set_clear_reach(1842.0)
		var tp2 := TerrainProfile.new()
		tp2.setup(p2, t2, tc, net["scenery"])
		var diff := 0
		var worst := 0.0
		var worst_at := -1
		var i := 0
		for k in range(k_cam, k_end):
			for si in 2:
				var w := tp2.corridor_width(k, -1 if si == 0 else 1)
				var dlt := full[i] - w
				if absf(dlt) > 0.01:
					diff += 1
					if dlt > worst:
						worst = dlt
						worst_at = k
				i += 1
		print("POSL %-9s %s km %.1f: L at the camera %.0f m (F2 need at the car %.0f m, need/0.6 %.0f m); start in place: path from row %d (%.0f m behind the camera), %d of %d row sides differ, narrower by up to %.2f m (row %d, %.0f m ahead)" % [
			p[0], dir["name"], float(p[3]), L, need, need / 0.6, p2.first, cam - float(p2.first) * 3.0, diff, i, worst, worst_at,
			float(worst_at) * 3.0 - cam if worst_at >= 0 else 0.0])
	quit(0)
