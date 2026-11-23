extends SceneTree
## NACH-R7a probe (scratch, not committed): A-17 footprint check of the props the builders really draw, with the
## TRUE model geometry from the manifest AABB instead of the footprint model of FIX-R7a's push-out patch (half the
## library width along the road centred on the foot; reach = extent / half width):
##  - buildings and other yaw-0 models: the AABB scaled, mirrored (flipped), local x lateral, local z = -forward
##    (ChunkContext.frame()), so the body runs from z - maxz*sc to z - minz*sc along the road;
##  - trees, plants, rocks (random yaw): a circle of radius max(|x0|,|x1|,|z0|,|z1|)*sc (the farthest AABB face; the
##    crown reaches at least that far in some direction) - and, separately, the patch's own model for comparison.
## Also: overlaps of building footprints (same side, same chunk) - to see whether pushing creates new overlaps.
##   godot --headless --path <tree> -s res://nach_probe/fp_true.gd -- [--full] [--stage=a,b] [--verbose]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const TOL := 0.05
const QUICK := ["kassel_wuerzburg__kassel", "saragossa_pau__saragossa", "dortmund_frankfurt__dortmund", "kiel_hamburg__kiel",
	"muenchen_nuernberg__nuernberg", "slavonski_brod_belgrad__slavonski_brod"]

var aabbs := {}


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var t_all := Time.get_ticks_msec()
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/manifest.json"))
	for mid: String in (man["models"] as Dictionary).keys():
		var a: Array = man["models"][mid].get("aabb", [])
		if a.size() == 6:
			aabbs[mid] = a
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var full := _arg("full", "") != ""
	var verbose := _arg("verbose", "") != ""
	var only: Array = Array(_arg("stage", "").split(",", false))
	if only.is_empty() and not full:
		only = QUICK.duplicate()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var tot := {"props": 0, "attached": 0, "measured": 0, "in_patchmodel": 0, "in_true": 0, "in_true_05": 0, "in_true_1": 0,
		"in_true_2": 0, "max_true": 0.0, "overlap_pairs": 0, "overlap_m2": 0.0}
	var by_cls := {}
	var depths := {}
	var dirs := 0
	for dir: Dictionary in Fair.directions(net, only):
		dirs += 1
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var pe := RoadPath3D.new()
		pe.setup(t, 0, r1)
		var te := TerrainProfile.new()
		te.setup(pe, t, tc, net["scenery"])
		var p := RoadPath3D.new()
		var tp := TerrainProfile.new()
		tp.setup(p, t, tc, net["scenery"])
		var st := ChunkStreamer.new()
		st.setup(p, tp, t, cfg, {}, true)
		var pb := Props.new()
		st.register(pb)
		st.register(CityB.new())
		var seen := {}
		var end_z := float(t.segment_count - 1) * t.seg_len
		var cam := 0.0
		var n_in := 0
		while cam < end_z:
			st.update(cam, 900.0)
			for ch: Dictionary in st.snapshot()["chunks"]:
				var ci := int(ch["index"])
				if seen.has(ci) or str(ch["state"]) != "committed":
					continue
				seen[ci] = true
				var part: Dictionary = (ch["parts"] as Dictionary).get("props", {})
				var rects: Array = []
				for lst_name: String in ["list", "attach_list"]:
					for e: Array in part.get(lst_name, []):
						tot["props"] = int(tot["props"]) + 1
						if lst_name == "attach_list":
							tot["attached"] = int(tot["attached"]) + 1
						var r := _judge(e, t, te, pb.library, lst_name == "attach_list")
						if r.is_empty():
							continue
						if r.has("rect"):
							rects.append(r["rect"])
						if not bool(r["droppable"]):
							continue
						tot["measured"] = int(tot["measured"]) + 1
						if float(r["d_patch"]) > TOL:
							tot["in_patchmodel"] = int(tot["in_patchmodel"]) + 1
						var d := float(r["d_true"])
						if d > TOL:
							n_in += 1
							tot["in_true"] = int(tot["in_true"]) + 1
							var cls := str(r["cls"])
							by_cls[cls] = int(by_cls.get(cls, 0)) + 1
							if not depths.has(cls):
								depths[cls] = []
							(depths[cls] as Array).append(d)
							tot["max_true"] = maxf(float(tot["max_true"]), d)
							if d > 0.5:
								tot["in_true_05"] = int(tot["in_true_05"]) + 1
							if d > 1.0:
								tot["in_true_1"] = int(tot["in_true_1"]) + 1
							if d > 2.0:
								tot["in_true_2"] = int(tot["in_true_2"]) + 1
							if verbose:
								print("TRUEFP %s km %.2f %s %s side %d: true %.2f m (patch model %.2f m) at %s" % [dir["name"],
									t.z_to_km(float(e[4])), str(e[2]), lst_name, int(r["side"]), d, float(r["d_patch"]), str(r["where"])])
				# overlaps of building rectangles on the same side (road coordinates: z along, lateral |x|)
				for a in rects.size():
					for b in range(a + 1, rects.size()):
						var ra: Array = rects[a]
						var rb: Array = rects[b]
						if int(ra[4]) != int(rb[4]):
							continue
						var oz := minf(float(ra[1]), float(rb[1])) - maxf(float(ra[0]), float(rb[0]))
						var ox := minf(float(ra[3]), float(rb[3])) - maxf(float(ra[2]), float(rb[2]))
						if oz > 0.5 and ox > 0.5:
							tot["overlap_pairs"] = int(tot["overlap_pairs"]) + 1
							tot["overlap_m2"] = float(tot["overlap_m2"]) + oz * ox
							if verbose:
								print("OVERLAP %s km %.2f %s / %s: %.1f x %.1f m" % [dir["name"], t.z_to_km(float(ra[0])), str(ra[5]), str(rb[5]), oz, ox])
			cam += 600.0
		st.clear()
		st.free()
		print("TRUEFP %-40s chunks %d: %d props with true footprint in the envelope" % [dir["name"], seen.size(), n_in])
	var med := {}
	for cls: String in depths.keys():
		var arr: Array = depths[cls]
		arr.sort()
		med[cls] = "n %d median %.2f p90 %.2f max %.2f" % [arr.size(), float(arr[arr.size() / 2]), float(arr[int(arr.size() * 0.9)]), float(arr[-1])]
	print("TRUEFP total %s" % str(tot))
	print("TRUEFP by class %s" % str(med))
	print("TRUEFP %d directions, %.0f s" % [dirs, float(Time.get_ticks_msec() - t_all) / 1000.0])
	quit(0)


func _env(te: TerrainProfile, t: Track, zq: float, side: int) -> Vector2:
	var fq := maxf(zq, 0.0) / t.seg_len
	var k := int(floor(fq))
	var u := fq - float(k)
	var edge := lerpf(te.edge(k, side), te.edge(k + 1, side), u)
	var cw := maxf(te.envelope_width(k, side), te.envelope_width(k + 1, side))
	return Vector2(edge, cw)


## Depth (m) of the footprint lateral near point |x| - near over the z span [z_lo, z_hi] into the envelope.
func _depth(te: TerrainProfile, t: Track, x: float, side: int, near: float, z_lo: float, z_hi: float) -> Array:
	var n := maxi(1, int(ceil((z_hi - z_lo) * 2.0 / t.seg_len)))
	var depth := -INF
	var where := 0.0
	for q in n + 1:
		var zq := z_lo + (z_hi - z_lo) * float(q) / float(n)
		var ec := _env(te, t, zq, side)
		if ec.y <= 0.0 or absf(x) - ec.x <= 0.0:
			continue       # as the kernel: a foot on the road or the shoulder is not a corridor case (Arcade's posts)
		var m := absf(x) - near - ec.x    # how far beyond the shoulder the near face stands (may be <0: over the shoulder)
		var d := ec.y - m
		if d > depth:
			depth = d
			where = zq
	return [depth if depth > -INF else -1.0, where]


func _judge(e: Array, t: Track, te: TerrainProfile, lib: PropLibrary, attached: bool) -> Dictionary:
	var seg := int(e[0])
	var j := int(e[1])
	var x := float(e[3])
	var z := float(e[4])
	var sc := float(e[5])
	var flipped := int(e[6]) != 0
	var s := t.get_segment(seg)
	var it: Dictionary = {}
	if not attached:
		if j < 0 or j >= s.sprites.size():
			return {}
		it = s.sprites[j]
	var side := int(it.get("side", 1)) if not attached else (1 if x >= 0.0 else -1)
	var le: Dictionary = lib.sets.get(str(e[2]), {})
	if side == 0 or le.is_empty() or float(le["height"]) * sc <= 0.5:
		return {}
	var cls := str(le["cls"])
	if cls == "building" and s.city:
		cls = "city_building"
	var droppable := (attached and bool(le["veg"])) or ((not it.has("offset") or bool(le["veg"])) and not bool(it.get("landmark", false)) and not attached)
	# the patch's own model
	var half_w := float(le["width"]) * sc * 0.5
	var reach := half_w
	if it.has("align"):
		reach = (float(le["extent_l"]) if (side > 0 or flipped) else float(le["extent_r"])) * sc
	var dp: Array = _depth(te, t, x, side, reach, z - half_w, z + half_w)
	# the true geometry: the largest AABB of the set's variants
	var vb := [INF, INF, INF, -INF, -INF, -INF]
	for v: Variant in le.get("variants", []):
		var a: Array = aabbs.get(str(v), [])
		if a.size() == 6:
			for c in 3:
				vb[c] = minf(float(vb[c]), float(a[c]))
				vb[c + 3] = maxf(float(vb[c + 3]), float(a[c + 3]))
	if float(vb[0]) == INF:
		return {"droppable": droppable, "d_patch": float(dp[0]), "d_true": float(dp[0]), "cls": cls + "(no aabb)", "side": side, "where": dp[1]}
	var x0 := float(vb[0]) * sc
	var x1 := float(vb[3]) * sc
	var z0 := float(vb[2]) * sc
	var z1 := float(vb[5]) * sc
	var near: float
	var far: float
	var zl: float
	var zh: float
	var rnd := bool(le["veg"]) or str(le["cls"]) == "rock"
	if rnd:
		var r := maxf(maxf(absf(x0), absf(x1)), maxf(absf(z0), absf(z1)))
		near = r
		far = r
		zl = z - r
		zh = z + r
	else:
		# local x: lateral to the right; mirrored when flipped. Towards the road: -x on the right side, +x on the left
		var toward_neg := (side > 0) != flipped
		near = -x0 if toward_neg else x1
		far = x1 if toward_neg else -x0
		zl = z - z1
		zh = z - z0
	var dt: Array = _depth(te, t, x, side, near, zl, zh)
	var out := {"droppable": droppable, "d_patch": float(dp[0]), "d_true": float(dt[0]), "cls": cls, "side": side, "where": "z %.1f..%.1f near %.1f (patch reach %.1f, z +-%.1f)" % [zl - z, zh - z, near, reach, half_w]}
	if str(le["cls"]) == "building":
		out["rect"] = [zl, zh, absf(x) - near, absf(x) + far, side, str(e[2])]
	return out
