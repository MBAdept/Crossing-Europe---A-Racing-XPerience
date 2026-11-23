extends SceneTree
## QA-R7a probe (headless, R7a tree): city fence/hedge/wall pieces (builders/city.gd: segment and side, Arcade's gaps,
## x = shoulder edge + fence x) – how many the rounded corridor drops (ChunkContext.in_bend_corridor() semantics:
## a corridor counts as a bend's only beyond the plain strip + 0.5 m, and where any sight line leaves the road it is
## at least strip + BEND_FLOOR_M) although the EXACT envelope of the sight lines (TerrainProfile.sight.width_near(), as
## border.gd's pillar_in_sight()) does not reach the piece's line. Those pieces could stand (A-17: nothing > 0.5 m in
## the envelope – the piece is outside it).
const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var scen: Dictionary = net["scenery"]
	var tot_arcade := 0
	var tot_drop := 0
	var tot_exact_drop := 0
	for dir: Dictionary in Fair.directions(net, []):
		var geo := Fair.build_geo(cfg, net, dir, scen)
		var track: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1842.0)
		var tp := TerrainProfile.new()
		tp.setup(path, track, tc, scen)
		var strip := maxf(0.0, tp.corridor_min_m - track.shoulder_w)
		var arcade := 0
		var drop := 0
		var exact_drop := 0
		var n := int(geo["nz"])
		for k in range(0, n - 1):
			var s := track.get_segment(k)
			if not s.city or s.tunnel or s.water:
				continue
			var fd: Variant = (scen.get(s.scenery, {}) as Dictionary).get("fence")
			if not fd is Dictionary:
				continue
			var every := float((fd as Dictionary).get("gap_every_m", 24.0))
			var gap := float((fd as Dictionary).get("gap_m", 3.5))
			var off := float((fd as Dictionary).get("x", 0.6))
			for side: int in [-1, 1]:
				if every > 0.0 and fposmod(s.z + (every * 0.5 if side > 0 else 0.0), every) < gap:
					continue
				arcade += 1
				# rounded corridor at the piece's two ends and middle (city.gd since R7a)
				var c0 := tp.corridor_width(k, side)
				var c1 := tp.corridor_width(k + 1, side)
				var cm := (c0 + c1) * 0.5
				var dropped := (c0 > strip + 0.5 and off <= c0) or (c1 > strip + 0.5 and off <= c1) or (cm > strip + 0.5 and off <= cm)
				if dropped:
					drop += 1
					var env := maxf(tp.sight.width_near(k, side), tp.sight.width_near(k + 1, side))
					if env > 0.0 and off <= env:
						exact_drop += 1
		tot_arcade += arcade
		tot_drop += drop
		tot_exact_drop += exact_drop
		geo["path"] = null
	print("FENCE pieces arcade %d; dropped by the rounded corridor %d (%.1f %%); of them inside the exact envelope %d; could stand %d (drawn would be %.1f %% of Arcade instead of %.1f %%)" % [
		tot_arcade, tot_drop, 100.0 * tot_drop / maxf(1.0, tot_arcade), tot_exact_drop, tot_drop - tot_exact_drop,
		100.0 * (tot_arcade - tot_exact_drop) / maxf(1.0, tot_arcade), 100.0 * (tot_arcade - tot_drop) / maxf(1.0, tot_arcade)])
	quit(0)
