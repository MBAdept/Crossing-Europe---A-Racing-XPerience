extends SceneTree
## QA-R5 (independent review of R5, not part of the project): every bridge and every tunnel of the network, each
## direction of each stage (and the dev stage), built headless with builders/bridge.gd and builders/tunnel.gd; the
## parts compared with Arcade's events of the same track (Track._build_bridge: pylons, truss portals, bridge lamps) and
## Arcade's tunnel elements (lamps every lamp_every_m, a green niche sign every 150 m, portal, cap); banks at both ends;
## nothing of the structure / tube over the lanes below 4.5 m; no stay cable within 1.5 m of a lane; the portal hill
## never above the approach road inside its sight corridor (F7).
## Run: godot --headless --path <tree> -s res://tests/qa_r5/qa_scan.gd [-- --only=<stage ids,…>]

const CLEAR_H := 4.5
var _out: Array[String] = []
var _bad: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print(s)
	_out.append(s)


static func _road_coords(ctx: ChunkContext, p: Vector3) -> Vector3:
	var w := p + ctx.origin
	var path := ctx.path
	var best := ctx.seg_a
	var bd := INF
	for k in range(maxi(path.first, ctx.seg_a - 60), mini(path.last(), ctx.seg_b + 60) + 1):
		var d := (w - path.point(k)).dot(RoadPath3D.fwd_of(path.heading(k)))
		if absf(d) < bd:
			bd = absf(d)
			best = k
	var rel := w - path.point(best)
	return Vector3(float(best) * ctx.seg_len + rel.dot(RoadPath3D.fwd_of(path.heading(best))), rel.dot(RoadPath3D.right_of(path.heading(best))), rel.y)


static func _lane_edge(ctx: ChunkContext, z: float, x: float) -> float:
	var row := clampi(int(round(ctx.row_of(z))), 0, ctx.row_count() - 1)
	return ctx.rows_edge[row].y if x > 0.0 else -ctx.rows_edge[row].x


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var BridgeB: GDScript = load("res://scripts/race3d/builders/bridge.gd")
	var TunnelB: GDScript = load("res://scripts/race3d/builders/tunnel.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var radius := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var terrain_cfg: Variant = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var tcfg: Dictionary = ConfigLoader.lookup(cfg, "render.tunnel", {})
	var peek := float(tcfg.get("peek_m", 45.0))
	var lamp_every := float(tcfg.get("light_every_m", 12.0))
	var only: Array = []
	var cli := CliArgs.all()
	if cli.has("only"):
		only = str(cli["only"]).split(",")
	var dirs: Array = Fair.call("directions", net, only)
	if only.is_empty():
		dirs.append_array(Fair.call("directions", net, ["dev_testetappe"]))
	var nb := 0
	var nt := 0
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.bridges.is_empty() and plan.tunnels.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, radius)
		var tp := TerrainProfile.new()
		tp.setup(p, t, terrain_cfg, net["scenery"])
		p.set_clear_reach(1842.0)
		var bb: Object = BridgeB.new()
		var tb: Object = TunnelB.new()
		var last_chunk := floori(float(t.segment_count - 1) / 32.0) - 1
		var items: Array = []
		for br: Dictionary in t.bridges:
			items.append([float(br["z0"]), float(br["z1"]), "bridge", br])
		for tu: Dictionary in plan.tunnels:
			items.append([t.km_to_z(float(tu["start_km"])), t.km_to_z(float(tu["end_km"])), "tunnel", tu])
		items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for item: Array in items:
			var is_bridge := str(item[2]) == "bridge"
			var z0 := float(item[0])
			var z1 := float(item[1])
			var c0 := maxi(int(floor(z0 / t.seg_len / 32.0)) - 1, 0)
			var c1 := mini(int(floor(z1 / t.seg_len / 32.0)) + 1, last_chunk)
			var d: Dictionary = item[3]
			var what := "%s | %s (%s %s, km %.2f–%.2f)" % [str(dir["name"]), str(d.get("name", "?")), str(item[2]),
				str(d.get("type", "")), t.z_to_km(z0), t.z_to_km(z1)]
			var miss: Array[String] = []
			var sums := {}
			var in_lane := 0
			var lane_ex := ""
			var cable_min := INF
			var hill_bad := 0
			var hill_ex := ""
			var bank_near := 0
			var bank_far := 0
			var z_mid := (z0 + z1) * 0.5
			var proc_ctx := {}
			for ci in range(c0, c1 + 1):
				p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = net["scenery"]
				ctx.levels = {"shadow_casters": 2, "details": 1}
				ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
				if is_bridge:
					for i in ctx.row_count() - 1:
						var zz := float(ctx.seg_a + i) * ctx.seg_len
						if zz < z0 - 0.01 or zz >= z1 - 0.01:
							continue
						for it: Dictionary in ctx.segs[i]["sprites"]:
							if it.has("bridge"):
								var pr := str(it.get("proc", ""))
								proc_ctx[pr] = int(proc_ctx.get(pr, 0)) + 1
				var b: Object = bb if is_bridge else tb
				var inp: Variant = b.call("collect", ctx)
				var part: Dictionary = b.call("build", ctx, inp)
				var dbg: Dictionary = b.call("debug", part)
				for k: String in dbg:
					sums[k] = int(sums.get(k, 0)) + int(dbg[k])
				var beacons := 0
				for l: Dictionary in part.get("lamps", []):
					if l.has("blink"):
						beacons += 1
				sums["beacons"] = int(sums.get("beacons", 0)) + beacons
				# geometry over the lanes (struct / tube / portal triangles sampled), banks per end, cables, hill
				var meshes: Array = []
				if is_bridge:
					meshes.append(["struct", part.get("struct", [])])
				else:
					meshes.append(["tube", part.get("tube", [])])
					meshes.append(["portal", part.get("portal", [])])
				for m: Array in meshes:
					var arr: Array = m[1]
					if arr.is_empty():
						continue
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					for k in range(0, idx.size(), 3):
						if str(m[0]) == "tube" and absf(uv2[idx[k]].x - 1.0) < 0.01:
							continue     # the cap (K_CAP): closes the tube for a camera outside only
						var a := v[idx[k]]
						var bv := v[idx[k + 1]]
						var cv := v[idx[k + 2]]
						for s: Vector2 in [Vector2(0.33, 0.33), Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5)]:
							var q := a + (bv - a) * s.x + (cv - a) * s.y
							var rc := _road_coords(ctx, q)
							if not is_bridge and str(m[0]) == "portal":
								var zp := float(ceili(t.km_to_z(float(d["start_km"])) / t.seg_len - 1.0e-6)) * t.seg_len
								if rc.x < zp - 2.0 and rc.z > 0.5 and absf(rc.y) < _lane_edge(ctx, rc.x, rc.y) + t.shoulder_w + 5.5:
									hill_bad += 1
									hill_ex = "z%+.1f x %.1f h %.1f" % [rc.x - zp, rc.y, rc.z]
								continue
							if rc.z > 0.3 and rc.z < CLEAR_H and absf(rc.y) < _lane_edge(ctx, rc.x, rc.y) and rc.x >= z0 - 3.0 and rc.x <= z1 + 3.0:
								in_lane += 1
								lane_ex = "%s km %.3f x %.2f h %.2f" % [str(m[0]), t.z_to_km(rc.x), rc.y, rc.z]
				if is_bridge:
					var w: Array = part.get("water", [])
					if not w.is_empty():
						var v: PackedVector3Array = w[Mesh.ARRAY_VERTEX]
						var uv2: PackedVector2Array = w[Mesh.ARRAY_TEX_UV2]
						for k in range(0, v.size(), 4):
							if absf(uv2[k].x) < 0.01:
								continue
							var rc := _road_coords(ctx, v[k])
							if rc.x < z_mid:
								bank_near += 1
							else:
								bank_far += 1
					var cin: Dictionary = inp if inp is Dictionary else {}
					for c: Array in cin.get("cables", []):
						for qq in 11:
							var pt: Vector3 = (c[0] as Vector3).lerp(c[1], float(qq) / 10.0)
							var rc := _road_coords(ctx, pt)
							cable_min = minf(cable_min, absf(rc.y) - _lane_edge(ctx, rc.x, rc.y))
			if is_bridge:
				nb += 1
				var typ := str(d.get("type", "river"))
				# Arcade's events of the bridge
				var ev := {}
				var boats := 0
				for k in range(int(floor(z0 / t.seg_len)) - 1, int(ceil(z1 / t.seg_len)) + 1):
					for e: Dictionary in t.events_for_segment(k):
						if e.has("bridge"):
							var pr := str(e.get("proc", ""))
							ev[pr] = int(ev.get(pr, 0)) + 1
						elif str(e.get("set", "")) in ["props/houseboat", "props/ferry_ship"]:
							boats += 1
				var exp_py := int(ev.get("pylon", 0))
				var exp_po := int(ev.get("truss_portal", 0))
				var exp_la := int(ev.get("bridge_lamp", 0))
				if int(sums.get("pylons", 0)) != exp_py:
					miss.append("Pylone %d statt %d (Arcade)" % [int(sums.get("pylons", 0)), exp_py])
				if int(sums.get("beacons", 0)) != exp_py:
					miss.append("Flugfeuer %d statt %d" % [int(sums.get("beacons", 0)), exp_py])
				if int(sums.get("cables", 0)) != exp_py * 14:
					miss.append("Seile %d statt %d" % [int(sums.get("cables", 0)), exp_py * 14])
				if int(sums.get("portals", 0)) != exp_po:
					miss.append("Fachwerkportale %d statt %d (Arcade)" % [int(sums.get("portals", 0)), exp_po])
				if int(sums.get("lamps", 0)) != exp_la:
					miss.append("Brückenlampen %d statt %d (Arcade)" % [int(sums.get("lamps", 0)), exp_la])
				if int(sums.get("water_quads", 0)) <= 0:
					miss.append("Wasser")
				if bank_near <= 0 or bank_far <= 0:
					miss.append("Ufer an beiden Enden (vorn %d, hinten %d)" % [bank_near, bank_far])
				if typ == "truss_arch" and int(sums.get("truss", 0)) <= 0:
					miss.append("Fachwerkträger")
				if typ in ["stone_arch", "canal", "causeway"] and int(sums.get("arches", 0)) <= 0:
					miss.append("Bögen")
				if in_lane > 0:
					miss.append("%d Tragwerkspunkte über den Spuren unter %.1f m (%s)" % [in_lane, CLEAR_H, lane_ex])
				if exp_py > 0 and cable_min < 1.5:
					miss.append("Seil %.2f m neben der Spur" % cable_min)
				_log("BRIDGE %s: py %d/%d po %d/%d la %d/%d cables %d beacons %d water %d banks %d|%d walls %d arches %d truss %d piers %d boats %d cable_min %.2f%s" % [
					what, int(sums.get("pylons", 0)), exp_py, int(sums.get("portals", 0)), exp_po, int(sums.get("lamps", 0)), exp_la,
					int(sums.get("cables", 0)), int(sums.get("beacons", 0)), int(sums.get("water_quads", 0)), bank_near, bank_far,
					int(sums.get("walls", 0)), int(sums.get("arches", 0)), int(sums.get("truss", 0)), int(sums.get("piers", 0)), boats,
					cable_min if cable_min < INF else -1.0, "" if miss.is_empty() else "  !! " + "; ".join(miss)])
			else:
				nt += 1
				var zp := float(ceili(z0 / t.seg_len - 1.0e-6)) * t.seg_len
				var ze := float(ceili(z1 / t.seg_len - 1.0e-6)) * t.seg_len
				var len_m := ze - zp
				var exp_cap := 1 if zp + peek < ze - t.seg_len else 0
				var exp_niche := 0
				var exp_lamps := 0
				var k := int(round(zp / t.seg_len))
				while float(k) * t.seg_len < ze - 0.01:
					var zz := float(k) * t.seg_len
					if fposmod(zz, 150.0) < t.seg_len:
						exp_niche += 1
					k += 1
				var zl := ceilf(zp / lamp_every) * lamp_every
				while zl < ze:
					exp_lamps += 2
					zl += lamp_every
				if int(sums.get("portals", 0)) != 1:
					miss.append("Portale %d" % int(sums.get("portals", 0)))
				if int(sums.get("exits", 0)) != 1:
					miss.append("Ausfahrtsrahmen %d" % int(sums.get("exits", 0)))
				if int(sums.get("caps", 0)) != exp_cap:
					miss.append("Kappe %d statt %d" % [int(sums.get("caps", 0)), exp_cap])
				if absi(int(sums.get("niches", 0)) - exp_niche) > 1:
					miss.append("Nischen %d statt %d (Arcade)" % [int(sums.get("niches", 0)), exp_niche])
				if int(sums.get("segments", 0)) <= 0:
					miss.append("Röhre")
				if in_lane > 0:
					miss.append("%d Röhrenpunkte über den Spuren unter %.1f m (%s)" % [in_lane, CLEAR_H, lane_ex])
				if hill_bad > 0:
					miss.append("%d Hügelpunkte über der Anfahrt im Sichtkorridor (%s)" % [hill_bad, hill_ex])
				_log("TUNNEL %s: len %.0f m seg %d portals %d exits %d caps %d/%d niches %d/%d doors %d fans %d lamp_entries %d (Arcade lamps %d) tube_tris %d portal_tris %d%s" % [
					what, len_m, int(sums.get("segments", 0)), int(sums.get("portals", 0)), int(sums.get("exits", 0)), int(sums.get("caps", 0)), exp_cap,
					int(sums.get("niches", 0)), exp_niche, int(sums.get("doors", 0)), int(sums.get("fans", 0)), int(sums.get("lamp_entries", sums.get("lamps", 0))),
					exp_lamps, int(sums.get("tube_triangles", 0)), int(sums.get("portal_triangles", 0)), "" if miss.is_empty() else "  !! " + "; ".join(miss)])
			if not miss.is_empty():
				_bad.append(what + ": " + "; ".join(miss))
	ModernMaterials.drop_shared()
	_log("QA-SCAN %d Brücken, %d Tunnel, %d mit Befund, %.0f s" % [nb, nt, _bad.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for b: String in _bad:
		_log("BEFUND " + b)
	quit(0)
