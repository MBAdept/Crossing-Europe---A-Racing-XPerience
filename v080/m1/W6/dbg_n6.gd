extends SceneTree
## W6 scratch (not committed): N6 placement of every landmark model of the network – yaw, face turn, shift, band.
const Fair := preload("res://tests/race3d/fairness.gd")
const Landmarks := preload("res://scripts/race3d/builders/landmarks.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var net := Fair.load_network()
	var rows: Array = []
	var want: Array = []
	for dir: Dictionary in Fair.directions(net):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		rows.append([str(dir["name"]), plan])
		for s: String in Landmarks.wanted_sets(t):
			if not want.has(s):
				want.append(s)
	var lib := PropLibrary.new()
	lib.request(want, self)
	var guard := 0
	while lib.pending() > 0 and guard < 60000:
		OS.delay_msec(1)
		guard += 1
	var hulls := {}
	var boxes := {}
	for row: Array in rows:
		var t := Track.new()
		t.setup(row[1], cfg, net["scenery"])
		var pfb := Landmarks.plan_fallbacks(t)
		for it: Dictionary in t.landmarks:
			var p: Dictionary = Landmarks.resolve_item(it, lib.sets, pfb)
			if int(p["rep"]) != Landmarks.MODEL or absf(float(p.get("view_yaw", 0.0))) < 1.0e-4:
				continue
			var mid := str(p["model"])
			if not hulls.has(mid):
				var reps: Array = (lib.models.get(mid, {}) as Dictionary).get("reps", [])
				var parts: Array = lib.mesh_parts(mid, str(reps[0]))
				hulls[mid] = Landmarks.footprint_hull(parts)
				boxes[mid] = Landmarks.parts_box(parts)
			p["hull"] = hulls[mid]
			var z := float(p["z"])
			var path := RoadPath3D.new()
			path.setup(t, maxi(0, int(floor((z - 800.0) / t.seg_len))), r1)
			path.ensure(int(ceil(z / t.seg_len)) + 2)
			var origin := path.world(z, float(p["x"]), 0.0)
			var g := Landmarks.placement_guard(p, t)
			var pm := Landmarks.place_model(path, z, origin, int(p["side"]), float(p["scale"]), bool(p.get("mirror", false)), boxes[mid], float(p["view_yaw"]), g)
			print("N6 %-28s %-34s side %2d edge %6.1f after %7.1f yaw %6.1f/%6.1f turn %6.1f shift %5.2f" % [str(row[0]), mid.trim_prefix("landmarks/"), int(p["side"]), float(g.get("edge_m", 0.0)), float(g.get("clear_after", 0.0)), rad_to_deg(float(pm["yaw"])), rad_to_deg(float(p["view_yaw"])), rad_to_deg(float(pm["turn"])), float(pm["shift"])])
	lib.clear(self)
	quit(0)
