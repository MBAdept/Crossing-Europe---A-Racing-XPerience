extends SceneTree
## Scratch: how many scenery props stand inside the sight corridor on the inside of bends (rule F7 for the props builder)?

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var only: Array = Array(str(CliArgs.all().get("stage", "")).split(",", false))
	if only.is_empty():
		only = Fair.HARDEST.duplicate()
	var total := 0
	var in_bend := 0
	var beyond := 0
	var by_set := {}
	var by_set_total := {}
	var veg_in := 0
	var veg_total := 0
	var segs := 0
	for dir: Dictionary in Fair.directions(net, only):
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var terr := Fair.build_terrain(cfg, geo, net["scenery"])
		var rows: Dictionary = terr["rows"]
		var corr: PackedVector2Array = rows["corridor"]
		var edges: PackedVector2Array = rows["edge"]
		var limits: PackedVector2Array = rows["limit"]
		var tp: TerrainProfile = terr["terrain"]
		var track: Track = geo["track"]
		var min_c := tp.corridor_min_m - track.shoulder_w
		var n: int = geo["n"]
		segs += n
		for k in n:
			var s := track.get_segment(k)
			for sp: Dictionary in s.sprites:
				if str(sp.get("kind", "prop")) != "prop" or bool(sp.get("landmark", false)) or bool(sp.get("overhead", false)):
					continue
				var x := float(sp.get("x", 0.0))
				var si := 0 if x < 0.0 else 1
				var m := absf(x) - (edges[k].x if si == 0 else edges[k].y)
				var c := corr[k].x if si == 0 else corr[k].y
				var lim := limits[k].x if si == 0 else limits[k].y
				var set_id := str(sp.get("set", ""))
				var veg := set_id.contains("tree_") or set_id.contains("bush_") or set_id.contains("heather")
				total += 1
				by_set_total[set_id] = int(by_set_total.get(set_id, 0)) + 1
				if veg:
					veg_total += 1
				if m > lim:
					beyond += 1
				if c > min_c + 0.5 and m <= c:
					in_bend += 1
					by_set[set_id] = int(by_set.get(set_id, 0)) + 1
					if veg:
						veg_in += 1
	print("PROPS %d segments, %d scenery props; inside a bend's sight corridor: %d (%.1f %%), of them vegetation %d of %d vegetation props (%.1f %%); beyond the ribbon: %d (%.2f %%)" % [
		segs, total, in_bend, 100.0 * float(in_bend) / maxf(1.0, float(total)), veg_in, veg_total, 100.0 * float(veg_in) / maxf(1.0, float(veg_total)),
		beyond, 100.0 * float(beyond) / maxf(1.0, float(total))])
	var keys := by_set.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(by_set[a]) > int(by_set[b]))
	for k: String in keys.slice(0, 14):
		print("PROPS   %-28s %6d of %6d in a bend corridor" % [k, int(by_set[k]), int(by_set_total[k])])
	quit(0)
