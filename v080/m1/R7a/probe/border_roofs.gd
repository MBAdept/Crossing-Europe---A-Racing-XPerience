extends SceneTree
## R7a probe (headless): the border roofs of the whole network with the corridor of the base and with A-17 – which
## hang from masts (support_plan "free"), which pillars stand. BorderB.supports_in_chunk() on a context that spans the
## roof; the old corridor through a TerrainProfile whose corridor_width() is the base's formula.
const Fair := preload("res://tests/race3d/fairness.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")


class OldProfile extends TerrainProfile:
	func corridor_width(k: int, side: int) -> float:
		var kap := _kappa(k)
		var s := track.get_segment(k)
		var half := s.lanes * track.lane_w * 0.5
		var paved := half if side < 0 else half + s.fuel_lane * track.lane_w
		var k_c := kap.x if side < 0 else kap.y
		var corr := corridor_min_m
		if k_c > 1.0e-7:
			var k_edge := k_c / maxf(0.05, 1.0 - k_c * paved)
			corr = maxf(corr, corridor_chord_m * corridor_chord_m * 0.125 * k_edge)
		return maxf(0.0, corr - track.shoulder_w)


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var roofs := 0
	var hang_old := 0
	var hang_new := 0
	for dir: Dictionary in Fair.directions(net, []):
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var track: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1842.0)
		var tp_new := TerrainProfile.new()
		tp_new.setup(path, track, tc, net["scenery"])
		var tp_old := OldProfile.new()
		tp_old.setup(path, track, tc, net["scenery"])
		for zn: Dictionary in track.zones:
			if str(zn.get("kind", "")) != "border":
				continue
			roofs += 1
			var res := {}
			for which: String in ["old", "new"]:
				var ctx := ChunkContext.new()
				ctx.seg_len = track.seg_len
				ctx.seg_a = int(floor(float(zn["z0"]) / track.seg_len)) - 1
				ctx.seg_b = int(ceil(float(zn["z1"]) / track.seg_len)) + 2
				ctx.track = track
				ctx.terrain = tp_old if which == "old" else tp_new
				var sup := BorderB.supports_in_chunk(ctx)
				var kinds: Array = []
				for p: Array in sup["pillars"]:
					kinds.append("%s%s%s" % ["L" if int(p[1]) < 0 else "R", str(p[2]), "+mast" if bool(p[4]) else ""])
				var free := 0
				for f: Array in sup["free"]:
					free = int(f[2])
				res[which] = [free, kinds]
			if int(res["old"][0]) != 0:
				hang_old += 1
			if int(res["new"][0]) != 0:
				hang_new += 1
			var km := track.z_to_km(float(zn["z0"]))
			var mark := "  <==" if int(res["old"][0]) != int(res["new"][0]) or int(res["old"][0]) != 0 else ""
			print("ROOF %-40s km %6.2f  old free %+d %s | new free %+d %s%s" % [dir["name"], km, int(res["old"][0]), str(res["old"][1]),
				int(res["new"][0]), str(res["new"][1]), mark])
		geo["path"] = null
	print("ROOFS %d: hanging old %d, new %d" % [roofs, hang_old, hang_new])
	quit(0)
