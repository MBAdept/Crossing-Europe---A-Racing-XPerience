extends SceneTree
## QA-R6 independent F1 check: can a border pillar or a canopy column that the builders really build hide part of a
## sign board from a camera in a lane? World-space 2D line of sight (RoadPath3D, curves included) from lane centres
## 55–600 m before the sign to 9 points across its board, against the pillar's footprint (heights ignored: pillars span
## the board heights). Prints every pillar–sign pair with an occluded share and a summary.
##   godot --headless --path . -s <this> [-- --only=<stage>]

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")
const N := 32

var cfg: Dictionary
var stats := {"pillars": 0, "pairs": 0, "pairs_occluded": 0, "pairs_occluded_px4": 0, "by_kind": {}}


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	cfg = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, only)
	if only.is_empty():
		dirs.append_array(Fair.directions(net, ["dev_testetappe"]))
	for dir: Dictionary in dirs:
		_scan(net, dir)
	print("F1-SUMMARY ", JSON.stringify(stats))
	quit(0)


func _scan(net: Dictionary, dir: Dictionary) -> void:
	var name := str(dir["name"])
	var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
	var t := Track.new()
	t.setup(plan, cfg, net["scenery"])
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), t.scenery_db)
	var cl := float(N) * t.seg_len
	var chunks := {}
	for zn: Dictionary in t.zones:
		var k := str(zn["kind"])
		if k == "fuel_canopy" or k == "border":
			for c in range(int(floor((float(zn["z0"]) - 4.0) / cl)), int(floor((float(zn["z1"]) + 4.0) / cl)) + 1):
				if c >= 0:
					chunks[c] = true
	var sb: ChunkBuilder = StationB.new()
	var bb: ChunkBuilder = BorderB.new()
	var posts: Array = []        ## [z, x, width, kind, what]
	var keys := chunks.keys()
	keys.sort()
	for c: int in keys:
		p.ensure((c + 1) * N + 900)
		var ctx := ChunkContext.new()
		ctx.cfg = cfg
		ctx.scenery_db = t.scenery_db
		ctx.capture(c, c * N, c * N + N, p, tp, t)
		var sp: Dictionary = sb.debug(sb.build(ctx, sb.collect(ctx)))
		for q: Array in sp.get("column_at", []):
			posts.append([float(q[0]), float(q[1]), StationB.MAST_W if str(q[2]).begins_with("mast") else StationB.PILLAR_W, "station_" + str(q[2])])
		var bp: Dictionary = bb.debug(bb.build(ctx, bb.collect(ctx)))
		for q: Array in bp.get("pillar_at", []):
			posts.append([float(q[0]), float(q[1]), BorderB.PILLAR_W, "border_" + str(q[2])])
	for post: Array in posts:
		stats["pillars"] += 1
		var zp := float(post[0])
		var xp := float(post[1])
		var w := float(post[2])
		var kind := str(post[3])
		p.ensure(t.segment_index_at(zp + 650.0) + 2)
		var pw := p.world(zp, xp, 0.0)
		var P := Vector2(pw.x, pw.z)
		# signs from the pillar to 600 m behind it
		for i in range(t.segment_index_at(zp), t.segment_index_at(zp + 600.0) + 1):
			var s := t.get_segment(i)
			if s.tunnel:
				continue
			for spr: Variant in s.sprites:
				var it: Dictionary = spr
				if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
					continue
				var zs := float(it.get("z", s.z))
				if zs <= zp + 0.3:
					continue
				var xs := float(it.get("x", 0.0))
				var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
				stats["pairs"] += 1
				var worst := 0.0
				var worst_d := 0.0
				var worst_px := 0.0
				var d := 55.0
				while d <= 600.0:
					var zc := zs - d
					if zc >= zp - 1.0:
						d += 5.0
						continue
					var half := t.lanes_at(zc) * t.lane_w * 0.5
					var nl := int(t.lanes_at(zc))
					for li in nl:
						var xc := -half + t.lane_w * (float(li) + 0.5)
						var cw := p.world(zc, xc, 0.0)
						var C := Vector2(cw.x, cw.z)
						var occ := 0
						for k in 9:
							var xb := xs - hw + 2.0 * hw * float(k) / 8.0
							var bw := p.world(zs, xb, 0.0)
							var Bp := Vector2(bw.x, bw.z)
							if _dist_to_segment(P, C, Bp) < w * 0.5:
								occ += 1
						var frac := float(occ) / 9.0
						if frac > worst:
							worst = frac
							worst_d = d
							worst_px = 711.0 * 2.0 * hw / d
					d += 5.0
				if worst > 0.0:
					stats["pairs_occluded"] += 1
					if worst_px >= 4.0:
						stats["pairs_occluded_px4"] += 1
					stats["by_kind"][kind] = int(stats["by_kind"].get(kind, 0)) + 1
					print("OCC %s km %.3f %s x %.2f hides %.0f %% of '%s' (km %.3f, x %.2f) from %.0f m (board %.0f px)" % [name,
						t.z_to_km(zp), kind, xp, worst * 100.0, str(it.get("sign", "")), t.z_to_km(zs), xs, worst_d, worst_px])


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)
