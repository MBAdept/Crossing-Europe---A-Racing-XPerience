extends SceneTree
## FIX-R6 probe for B-01: every border roof of the network – its pillar plan, which pillars build() keeps (bend
## corridor, F7) and, for candidate pillar places on the inside of a bend, how many camera→car lines of sight (lane
## centres, camera 5–300 m before the pillar, car up to 270 m ahead of the camera) the pillar's footprint cuts.
##   godot --headless --path . -s <this> [-- --only=<stage>] [--all]

const Fair := preload("res://tests/race3d/fairness.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")
const N := 32

var cfg: Dictionary
var verbose := false
var stats := {"roofs": 0, "one_sided": 0}


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a == "--all":
			verbose = true
	cfg = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var dirs := Fair.directions(net, only)
	if only.is_empty():
		dirs.append_array(Fair.directions(net, ["dev_testetappe"]))
	for dir: Dictionary in dirs:
		_scan(net, dir)
	print("PROBE-SUMMARY ", JSON.stringify(stats))
	quit(0)


func _ctx(t: Track, p: RoadPath3D, tp: TerrainProfile, c: int) -> ChunkContext:
	p.ensure((c + 1) * N + 900)
	var ctx := ChunkContext.new()
	ctx.cfg = cfg
	ctx.scenery_db = t.scenery_db
	ctx.capture(c, c * N, c * N + N, p, tp, t)
	return ctx


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
	for zn: Dictionary in t.zones:
		if str(zn["kind"]) != "border":
			continue
		var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
		var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
		if t.get_segment(t.segment_index_at(r0 + 0.1)).tunnel:
			continue
		stats["roofs"] += 1
		var c := int(floor(r0 / cl))
		var ctx := _ctx(t, p, tp, c)
		var ctx2 := _ctx(t, p, tp, int(floor(r1 / cl)))
		# the same sign list as BorderB.pillars_in_chunk()
		t.get_segment(t.segment_index_at(r1 + BorderB.SIGN_SCAN_M + t.generation_lead_m()) + 2)
		var signs: Array = []
		for i in range(t.segment_index_at(r0), t.segment_index_at(r1 + BorderB.SIGN_SCAN_M) + 1):
			var s := t.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) != 0:
					var zs := float(it.get("z", s.z))
					var side := int(it.get("side", 1))
					var ed := BorderB.edges_at(t, zs)
					var edge := ed.y if side > 0 else -ed.x
					var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
					signs.append([zs, side, absf(float(it.get("x", 0.0))) + hw - edge, str(it.get("sign", ""))])
		var pl := BorderB.pillar_plan(r0, r1, signs)
		var kept := {-1: [], 1: []}
		var desc := []
		for q: Array in pl:
			var zp := float(q[0])
			var sd := int(q[1])
			var cx := ctx if zp < float(c + 1) * cl else ctx2
			var row := clampi(int(floor(zp / t.seg_len)) - cx.seg_a, 0, cx.row_count() - 2)
			var edge := cx.shoulder_edge(row, sd)
			var px := float(sd) * (edge + float(q[3]))
			var corr := cx.in_bend_corridor(zp, px)
			var keep := str(q[2]) == "front" or not corr
			if keep:
				(kept[sd] as Array).append(str(q[2]))
			desc.append("%s%s@%.1f+%.2f%s" % ["L" if sd < 0 else "R", q[2], zp - r0, float(q[3]), "(corr)" if corr else ""])
		var one := (kept[-1] as Array).is_empty() or (kept[1] as Array).is_empty()
		if one:
			stats["one_sided"] += 1
		if not one and not verbose:
			continue
		var under := []
		for s: Array in signs:
			if float(s[0]) < r1 + 0.1:
				under.append("%s%s@%.1f out %.2f" % ["L" if int(s[1]) < 0 else "R", s[3], float(s[0]) - r0, float(s[2])])
		print("ROOF %s km %.3f len %.0f m %s | plan %s | signs<=r1 %s" % [name, t.z_to_km(r0), r1 - r0, "ONE-SIDED" if one else "ok",
			str(desc), str(under)])
		if one:
			var side := 1 if (kept[1] as Array).is_empty() else -1
			_occlusion(t, p, ctx, r0, r1, side, signs)


## Car lines of sight cut by candidate pillars of `side`.
func _occlusion(t: Track, p: RoadPath3D, ctx: ChunkContext, r0: float, r1: float, side: int, signs: Array) -> void:
	var zf := r0 + BorderB.PILLAR_IN
	var row := clampi(int(floor(zf / t.seg_len)) - ctx.seg_a, 0, ctx.row_count() - 2)
	var edge := ctx.shoulder_edge(row, side)
	var far := BorderB.outer_place(signs, side, r0 - 1.0, r1 + BorderB.SIGN_SCAN_M)
	var zback := -1.0
	for s: Array in signs:
		if int(s[1]) == side and float(s[0]) >= zf - BorderB.PLINTH_HALF and float(s[0]) < r1:
			zback = maxf(zback, float(s[0]) + 0.35 + BorderB.PLINTH_HALF)
	var cands := {"arcade_front": [zf, BorderB.PILLAR_OUT], "front_out": [zf, far], "end": [r1 - BorderB.PILLAR_IN, BorderB.PILLAR_OUT]}
	if zback > 0.0:
		cands["front_back"] = [zback, BorderB.PILLAR_OUT]
	var line := "  OCC side %d (zback %.1f, roof end %.1f):" % [side, zback - r0 if zback > 0.0 else -1.0, r1 - r0]
	var hit_by := {}
	for k: String in cands:
		hit_by[k] = {}
		var zp := float(cands[k][0])
		var px := float(side) * (edge + float(cands[k][1]))
		p.ensure(t.segment_index_at(zp + 300.0) + 2)
		var pw := p.world(zp, px, 0.0)
		var P := Vector2(pw.x, pw.z)
		var n := 0
		var occ := 0
		var occ_far := 0.0
		var zc := zp - 300.0
		while zc <= zp - 5.0:
			var nl := int(t.lanes_at(zc))
			var half := float(nl) * t.lane_w * 0.5
			for li in nl:
				var cw := p.world(zc, -half + t.lane_w * (float(li) + 0.5), 0.0)
				var C := Vector2(cw.x, cw.z)
				var zt := zp + 1.0
				while zt <= zc + 270.0:
					var nt := int(t.lanes_at(zt))
					var ht := float(nt) * t.lane_w * 0.5
					for lj in nt:
						var tw := p.world(zt, -ht + t.lane_w * (float(lj) + 0.5), 0.0)
						n += 1
						if _dist(P, C, Vector2(tw.x, tw.z)) < BorderB.PILLAR_W * 0.5:
							occ += 1
							(hit_by[k] as Dictionary)["%d|%d|%d|%d" % [int(zc), li, int(zt * 10.0), lj]] = true
							occ_far = maxf(occ_far, zt - zc)
					zt += 5.0
			zc += 5.0
		line += " %s(+%.1f@%.1f) %d/%d farthest %.0f m;" % [k, float(cands[k][1]), zp - r0, occ, n, occ_far]
	print(line)
	var only := 0
	for key: String in (hit_by["front_out"] as Dictionary):
		if not (hit_by["arcade_front"] as Dictionary).has(key):
			only += 1
	print("  EXCL front_out hides %d lines arcade_front does not (of %d)" % [only, (hit_by["front_out"] as Dictionary).size()])


static func _dist(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var u := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1.0e-9), 0.0, 1.0)
	return q.distance_to(a + ab * u)
