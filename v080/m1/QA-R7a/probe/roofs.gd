extends SceneTree
## QA-R7a probe (headless): every border roof of the network – which pillars stand, which side hangs from masts – with
## the shipped border builder of THIS tree (base or R7a) and a plain TerrainProfile. Runs unchanged in both trees.
##   godot --headless --path . -s <this>
const Fair := preload("res://tests/race3d/fairness.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var roofs := 0
	var hang := 0
	var dirs: Array[Dictionary] = Fair.directions(net, [])
	for dir: Dictionary in dirs:
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var track: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1842.0)
		var tp := TerrainProfile.new()
		tp.setup(path, track, tc, net["scenery"])
		for zn: Dictionary in track.zones:
			if str(zn.get("kind", "")) != "border":
				continue
			roofs += 1
			var ctx := ChunkContext.new()
			ctx.seg_len = track.seg_len
			ctx.seg_a = int(floor(float(zn["z0"]) / track.seg_len)) - 1
			ctx.seg_b = int(ceil(float(zn["z1"]) / track.seg_len)) + 2
			ctx.track = track
			ctx.terrain = tp
			var sup := BorderB.supports_in_chunk(ctx)
			var kinds: Array = []
			for p: Array in sup["pillars"]:
				kinds.append("%s%s%s" % ["L" if int(p[1]) < 0 else "R", str(p[2]), "+mast" if bool(p[4]) else ""])
			kinds.sort()
			var free := 0
			for f: Array in sup["free"]:
				free = int(f[2])
			if free != 0:
				hang += 1
			print("ROOF %-40s km %6.2f free %+d %s" % [dir["name"], track.z_to_km(float(zn["z0"])), free, str(kinds)])
		geo["path"] = null
	print("ROOFS %d in %d directions: hanging %d" % [roofs, dirs.size(), hang])
	quit(0)
