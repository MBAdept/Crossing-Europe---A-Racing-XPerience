## "-- --full": every bridge and every tunnel of the network (each direction of each stage and of the dev stage) built
## chunk by chunk without a renderer and compared EXACTLY with Arcade's own elements of the same track (FIX-R5, QA-R5
## QR5-06; the method of QA-R5's independent scan):
##   bridge  pylons, truss portals and bridge lamps = Arcade's "pylon" / "truss_portal" / "bridge_lamp" events
##           (Track._build_bridge); one red aviation light per pylon; 2 × 7 stay cables per pylon (RoadRenderer._pylon);
##           water; banks at both ends; per type its truss / arches / piers; no vertex of the structure over a lane
##           between 0.3 and 4.5 m; no cable within 1.5 m of a lane;
##   tunnel  one portal and one exit frame; the cap at peek_m exactly where Arcade closes the tube; SOS niches by
##           Arcade's rule (a green sign in every tunnel segment whose road position mod 150 m < seg_len); at least
##           Arcade's two lamp rows every light_every_m; no point of the tube over a lane between 0.3 and 4.5 m (the cap
##           and the fans above 5.2 m aside); no point of the portal hill above the approach inside the sight corridor
##           (lanes + shoulder + 5.5 m, more than 0.5 m above the road – F7).
const SCAN_CLEAR_H := 4.5          ## nothing over a lane between 0.3 m and this
const SCAN_CABLE_MIN := 1.5        ## a stay cable at least this far beside a lane
const SCAN_CORRIDOR := 5.5         ## the approach's sight corridor beyond the shoulder (F7)


## Road coordinates (z, x, h) of a chunk-local point: the boundary of the path whose cross-section holds it.
static func _scan_road(ctx: ChunkContext, p: Vector3) -> Vector3:
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


static func _scan_lane_edge(ctx: ChunkContext, z: float, x: float) -> float:
	var row := clampi(int(round(ctx.row_of(z))), 0, ctx.row_count() - 1)
	return ctx.rows_edge[row].y if x > 0.0 else -ctx.rows_edge[row].x


func _full_scan() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var BridgeB: GDScript = load("res://scripts/race3d/builders/bridge.gd")
	var TunnelB: GDScript = load("res://scripts/race3d/builders/tunnel.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var radius := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var terrain_cfg: Variant = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var tcfg: Variant = ConfigLoader.lookup(cfg, "render.tunnel", {})
	var peek := float((tcfg as Dictionary).get("peek_m", 45.0)) if tcfg is Dictionary else 45.0
	var lamp_every := float((tcfg as Dictionary).get("light_every_m", 12.0)) if tcfg is Dictionary else 12.0
	var cli := CliArgs.all()
	var only: Array = []
	if cli.has("only-stage"):
		only = str(cli["only-stage"]).split(",")
	var dirs: Array = Fair.call("directions", net, only)
	if only.is_empty():
		dirs.append_array(Fair.call("directions", net, ["dev_testetappe"]))
	var bridges := 0
	var tunnels := 0
	var bad: Array[String] = []
	var types := {}
	var totals := {"pylons": 0, "portals": 0, "lamps": 0, "cables": 0, "niches": 0, "caps": 0}
	var verbose := cli.has("verbose")
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
		# the elements of the direction in the order of the road: [z0, z1, kind, data]
		var items: Array = []
		for br: Dictionary in t.bridges:
			items.append([float(br["z0"]), float(br["z1"]), "bridge", br])
		for tu: Dictionary in plan.tunnels:
			items.append([t.km_to_z(float(tu["start_km"])), t.km_to_z(float(tu["end_km"])), "tunnel", tu])
		items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var bb: Object = BridgeB.new()
		var tb: Object = TunnelB.new()
		var last_chunk := floori(float(t.segment_count - 1) / 32.0) - 1     # its rows stay inside the track
		for item: Array in items:
			var is_bridge := str(item[2]) == "bridge"
			var z0 := float(item[0])
			var z1 := float(item[1])
			var d: Dictionary = item[3]
			var c0 := maxi(int(floor(z0 / t.seg_len / 32.0)) - 1, 0)
			var c1 := mini(int(floor(z1 / t.seg_len / 32.0)) + 1, last_chunk)
			var what := "%s %s (%s %s, km %.2f–%.2f)" % [str(dir["name"]), str(d.get("name", "?")), str(item[2]), str(d.get("type", "")),
				t.z_to_km(z0), t.z_to_km(z1)]
			var sums := {}
			var in_lane := 0
			var lane_ex := ""
			var cable_min := INF
			var hill_bad := 0
			var hill_ex := ""
			var bank_near := 0
			var bank_far := 0
			var z_mid := (z0 + z1) * 0.5
			var zp := float(ceili(z0 / t.seg_len - 1.0e-6)) * t.seg_len
			var seg_lo := c0 * 32
			var seg_hi := (c1 + 1) * 32
			for ci in range(c0, c1 + 1):
				p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = net["scenery"]
				ctx.levels = {"shadow_casters": 2, "details": 1}
				ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
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
				# geometry over the lanes (triangles sampled), banks per end, cables, the hill in the approach corridor
				var meshes: Array = [["struct", part.get("struct", [])]] if is_bridge else [["tube", part.get("tube", [])], ["portal", part.get("portal", [])]]
				for m: Array in meshes:
					var arr: Array = m[1]
					if arr.is_empty():
						continue
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					for k in range(0, idx.size(), 3):
						if str(m[0]) == "tube":
							var kind := uv2[idx[k]].x
							if absf(kind - 1.0) < 0.01:
								continue     # the cap (K_CAP): closes the tube for a camera outside only
						var a := v[idx[k]]
						var bv := v[idx[k + 1]]
						var cv := v[idx[k + 2]]
						for s: Vector2 in [Vector2(0.33, 0.33), Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5)]:
							var rc := _scan_road(ctx, a + (bv - a) * s.x + (cv - a) * s.y)
							if str(m[0]) == "portal":
								if rc.x < zp - 2.0 and rc.z > 0.5 and absf(rc.y) < _scan_lane_edge(ctx, rc.x, rc.y) + t.shoulder_w + SCAN_CORRIDOR:
									hill_bad += 1
									hill_ex = "z%+.1f x %.1f h %.1f" % [rc.x - zp, rc.y, rc.z]
								continue
							if rc.z > 0.3 and rc.z < SCAN_CLEAR_H and absf(rc.y) < _scan_lane_edge(ctx, rc.x, rc.y) and rc.x >= z0 - 3.0 and rc.x <= z1 + 3.0:
								in_lane += 1
								lane_ex = "%s km %.3f x %.2f h %.2f" % [str(m[0]), t.z_to_km(rc.x), rc.y, rc.z]
				if is_bridge:
					var w: Array = part.get("water", [])
					if not w.is_empty():
						var wv: PackedVector3Array = w[Mesh.ARRAY_VERTEX]
						var wuv2: PackedVector2Array = w[Mesh.ARRAY_TEX_UV2]
						for k in range(0, wv.size(), 4):
							if absf(wuv2[k].x) < 0.01:
								continue          # water (K_WATER); every other kind is a bank
							if _scan_road(ctx, wv[k]).x < z_mid:
								bank_near += 1
							else:
								bank_far += 1
					var cin: Dictionary = inp if inp is Dictionary else {}
					for c: Array in cin.get("cables", []):
						for q in 11:
							var rc := _scan_road(ctx, (c[0] as Vector3).lerp(c[1], float(q) / 10.0))
							cable_min = minf(cable_min, absf(rc.y) - _scan_lane_edge(ctx, rc.x, rc.y))
			var miss: Array[String] = []
			if is_bridge:
				bridges += 1
				var typ := str(d.get("type", "river"))
				types[typ] = int(types.get(typ, 0)) + 1
				# Arcade's events in the segments these chunks built (other bridges there count on both sides)
				var ev := {}
				for k in range(seg_lo, seg_hi):
					if k >= t.segment_count:
						break
					for e: Dictionary in t.events_for_segment(k):
						if e.has("bridge"):
							ev[str(e.get("proc", ""))] = int(ev.get(str(e.get("proc", "")), 0)) + 1
				var exp_py := int(ev.get("pylon", 0))
				var exp_po := int(ev.get("truss_portal", 0))
				var exp_la := int(ev.get("bridge_lamp", 0))
				if int(sums.get("pylons", 0)) != exp_py:
					miss.append("Pylone %d statt %d (Arcade)" % [int(sums.get("pylons", 0)), exp_py])
				if int(sums.get("beacons", 0)) != exp_py:
					miss.append("Flugfeuer %d statt %d" % [int(sums.get("beacons", 0)), exp_py])
				if int(sums.get("cables", 0)) != exp_py * 2 * 7:
					miss.append("Seile %d statt %d (Arcade: 7 je Richtung)" % [int(sums.get("cables", 0)), exp_py * 14])
				if int(sums.get("portals", 0)) != exp_po:
					miss.append("Fachwerkportale %d statt %d (Arcade)" % [int(sums.get("portals", 0)), exp_po])
				if int(sums.get("lamps", 0)) != exp_la:
					miss.append("Brückenlampen %d statt %d (Arcade)" % [int(sums.get("lamps", 0)), exp_la])
				if typ == "cable_stayed" and exp_py < 2:
					miss.append("Schrägseilbrücke ohne Pylone in Arcades Ereignissen")
				if int(sums.get("water_quads", 0)) <= 0:
					miss.append("Wasser")
				if bank_near <= 0 or bank_far <= 0:
					miss.append("Ufer an beiden Enden (vorn %d, hinten %d)" % [bank_near, bank_far])
				match typ:
					"truss_arch":
						if int(sums.get("truss", 0)) <= 0:
							miss.append("Fachwerkträger")
					"stone_arch", "canal", "causeway":
						if int(sums.get("arches", 0)) <= 0:
							miss.append("Bögen")
					"river":
						if int(sums.get("piers", 0)) <= 0:
							miss.append("Pfeiler")
				if in_lane > 0:
					miss.append("%d Tragwerkspunkte über den Spuren unter %.1f m (%s)" % [in_lane, SCAN_CLEAR_H, lane_ex])
				if exp_py > 0 and cable_min < SCAN_CABLE_MIN:
					miss.append("Seil %.2f m neben der Spur" % cable_min)
				totals["pylons"] += int(sums.get("pylons", 0))
				totals["portals"] += int(sums.get("portals", 0))
				totals["lamps"] += int(sums.get("lamps", 0))
				totals["cables"] += int(sums.get("cables", 0))
				if verbose:
					print("BRIDGE %s: Pylone %d/%d Portale %d/%d Lampen %d/%d Seile %d Feuer %d Ufer %d|%d Seil-Abstand %.2f" % [what,
						int(sums.get("pylons", 0)), exp_py, int(sums.get("portals", 0)), exp_po, int(sums.get("lamps", 0)), exp_la,
						int(sums.get("cables", 0)), int(sums.get("beacons", 0)), bank_near, bank_far, cable_min if cable_min < INF else -1.0])
			else:
				tunnels += 1
				var ze := float(ceili(z1 / t.seg_len - 1.0e-6)) * t.seg_len
				var first := int(round(zp / t.seg_len))
				var end := int(round(ze / t.seg_len))
				var exp_cap := 1 if zp + peek < ze - t.seg_len else 0
				var exp_niche := 0
				for k in range(first, end):
					if t.get_segment(k).tunnel and fposmod(float(k) * t.seg_len, 150.0) < t.seg_len:
						exp_niche += 1
				var exp_lamps := 0
				var zl := ceilf(zp / lamp_every) * lamp_every
				while zl < ze:
					exp_lamps += 2
					zl += lamp_every
				if int(sums.get("portals", 0)) != 1:
					miss.append("Portale %d statt 1" % int(sums.get("portals", 0)))
				if int(sums.get("exits", 0)) != 1:
					miss.append("Ausfahrtsrahmen %d statt 1" % int(sums.get("exits", 0)))
				if int(sums.get("caps", 0)) != exp_cap:
					miss.append("Kappe %d statt %d" % [int(sums.get("caps", 0)), exp_cap])
				if int(sums.get("niches", 0)) != exp_niche:
					miss.append("Nischen %d statt %d (Arcades grüne Schilder)" % [int(sums.get("niches", 0)), exp_niche])
				if int(sums.get("lamps", 0)) < exp_lamps:
					miss.append("Leuchten %d, Arcade %d" % [int(sums.get("lamps", 0)), exp_lamps])
				if int(sums.get("segments", 0)) != end - first or int(sums.get("tube_triangles", 0)) <= 0:
					miss.append("Röhre %d von %d Segmenten" % [int(sums.get("segments", 0)), end - first])
				if in_lane > 0:
					miss.append("%d Röhrenpunkte über den Spuren unter %.1f m (%s)" % [in_lane, SCAN_CLEAR_H, lane_ex])
				if hill_bad > 0:
					miss.append("%d Hügelpunkte über der Anfahrt im Sichtkorridor (%s)" % [hill_bad, hill_ex])
				totals["niches"] += int(sums.get("niches", 0))
				totals["caps"] += int(sums.get("caps", 0))
				if verbose:
					print("TUNNEL %s: %.0f m Portale %d Ausfahrten %d Kappe %d/%d Nischen %d/%d Leuchten %d (Arcade %d)" % [what, ze - zp,
						int(sums.get("portals", 0)), int(sums.get("exits", 0)), int(sums.get("caps", 0)), exp_cap, int(sums.get("niches", 0)),
						exp_niche, int(sums.get("lamps", 0)), exp_lamps])
			if not miss.is_empty():
				bad.append("%s: %s" % [what, "; ".join(miss)])
	ModernMaterials.drop_shared()
	for b: String in bad:
		print("MANGEL " + b)
	var problems: Array[String] = []
	problems.assign(bad.slice(0, 12))
	if bridges == 0 or tunnels == 0:
		problems.append("keine Brücke oder kein Tunnel gefunden")
	if only.is_empty():
		for typ: String in CityData.BRIDGE_TYPES:
			if not types.has(typ):
				problems.append("kein Brückentyp %s im Netz" % typ)
	_report("tunnel_bridge_full", problems, "%d Brücken %s, %d Tunnel exakt gegen Arcade geprüft (%s), %d mit Mängeln, %.0f s" % [bridges,
		JSON.stringify(types), tunnels, JSON.stringify(totals), bad.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(),
		(Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)
