extends SceneTree
## Network check of contracts A-17 and A-24 for what the builders really draw (FIX-R7a, finding QR7a-01 of QA-R7a;
## RINT-M3): no prop taller than 0.5 m that the props builder may leave out stands with any part of its MODEL inside the
## envelope of the sight lines of a bend – not its foot, not the crown of a tree, not the near edge of an edge-aligned
## house, not a balcony beyond that edge; the props a model brings along ("attach_list") included.
## Builds the shipped ChunkStreamer in sync mode with the real props and city builders over whole stage directions
## and measures every drawn prop against the exact envelope (TerrainProfile.envelope_width(), computed on a path of
## its own over the whole stage; F7 of tests/sim/modern_sight.gd checks that envelope against an independent
## reference). The object (A-24, computed here from the model manifest, not through the builder's footprint()): the
## AABB of the union of the set's variant models, scaled, mirrored and turned by the yaw the builder placed it with
## (9th element of its list entry); an edge-aligned item reaches at least to its near edge (the set's extent); a
## stand-in without a model: half its width as crown, the extent when aligned. Along the road its whole extent, across
## the road the part nearest to the road; between two rows the larger envelope of the two (as
## ChunkContext.bend_intrusion()). Tolerance 5 cm.
##   godot --headless --path . -s res://tests/race3d/check_props_footprint.gd [-- --full] [--stage=<dir>,…] [--verbose]
## Normal run (gate of tools/run_tests.sh): six directions with the review positions T1–T4, C1, S0, S4 and the town
## bends (about 1 minute); --full: all 128 directions (about 5 minutes). Owner: the owner of builders/props.gd (A-24).
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const TOLERANCE_M := 0.05
const MANIFEST := "res://assets/models/manifest.json"
const QUICK := ["kassel_wuerzburg__kassel", "saragossa_pau__saragossa", "dortmund_frankfurt__dortmund", "kiel_hamburg__kiel",
	"muenchen_nuernberg__nuernberg", "slavonski_brod_belgrad__slavonski_brod"]


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var t_all := Time.get_ticks_msec()
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var aabbs := {}
	if man is Dictionary:
		for mid: String in ((man as Dictionary).get("models", {}) as Dictionary):
			var a: Array = (man["models"][mid] as Dictionary).get("aabb", [])
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
	var tot := {"props": 0, "attached": 0, "checked": 0, "in": 0, "fixed": 0, "max_m": 0.0, "no_aabb": 0}
	var by_cls := {}
	var dirs := 0
	for dir: Dictionary in Fair.directions(net, only):
		dirs += 1
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		# the yardstick: the envelope on a path of its own over the whole stage
		var pe := RoadPath3D.new()
		pe.setup(t, 0, r1)
		var te := TerrainProfile.new()
		te.setup(pe, t, tc, net["scenery"])
		# the real streamer with the real builders
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
				var entries: Array = []
				for e: Array in part.get("list", []):
					entries.append([e, false])
				for e: Array in part.get("attach_list", []):
					entries.append([e, true])
					tot["attached"] = int(tot["attached"]) + 1
				for pair: Array in entries:
					var e: Array = pair[0]
					tot["props"] = int(tot["props"]) + 1
					var r := _judge(e, bool(pair[1]), t, te, pb.library, aabbs)
					if r.is_empty():
						continue
					tot["checked"] = int(tot["checked"]) + 1
					if bool(r.get("no_aabb", false)):
						tot["no_aabb"] = int(tot["no_aabb"]) + 1
					if not bool(r["in"]):
						continue
					if not bool(r["droppable"]):
						tot["fixed"] = int(tot["fixed"]) + 1
						continue
					n_in += 1
					var cls := str(r["cls"])
					by_cls[cls] = int(by_cls.get(cls, 0)) + 1
					tot["max_m"] = maxf(float(tot["max_m"]), float(r["depth"]))
					if verbose:
						print("FOOTPRINT %s km %.2f %s%s side %d: %.2f m in the envelope (%s)" % [dir["name"], t.z_to_km(float(e[4])), str(e[2]),
							" (attached)" if bool(pair[1]) else "", int(r["side"]), float(r["depth"]), str(r["where"])])
			cam += 600.0
		st.clear()
		st.free()
		tot["in"] = int(tot["in"]) + n_in
		print("FOOTPRINT %-40s chunks %d: %d props in the sight lines" % [dir["name"], seen.size(), n_in])
	var ok := int(tot["in"]) == 0 and int(tot["checked"]) > 0
	print("FOOTPRINT %d directions, %d props drawn (%d attached), %d measured (> 0.5 m beside the road; %d stand-ins without a model AABB): %d with their model in the envelope %s (deepest %.2f m); %d that the builder never leaves out (landmarks, stage events) (%.0f s)" % [
		dirs, int(tot["props"]), int(tot["attached"]), int(tot["checked"]), int(tot["no_aabb"]), int(tot["in"]), str(by_cls),
		float(tot["max_m"]), int(tot["fixed"]), float(Time.get_ticks_msec() - t_all) / 1000.0])
	print("CHECK props_footprint %s %d Requisiten über 0,5 m mit ihrem Modell in der Hülle der Sichtlinien (%d gemessen, %d Etappenrichtungen)" % [
		"OK    " if ok else "FEHLER", int(tot["in"]), int(tot["checked"]), dirs])
	quit(0 if ok else 1)


## One drawn prop [seg, j, set, x, z, scale, flipped, kind, yaw] (attached: an entry of "attach_list", item numbers
## beyond the track's) against the envelope: {} when it is not measured (on the road, not beside it, at most 0.5 m
## high, unknown set), else {in, droppable, depth, cls, side, no_aabb, where}.
static func _judge(e: Array, attached: bool, t: Track, te: TerrainProfile, lib: PropLibrary, aabbs: Dictionary) -> Dictionary:
	var seg := int(e[0])
	var j := int(e[1])
	var x := float(e[3])
	var z := float(e[4])
	var sc := float(e[5])
	var flipped := int(e[6]) != 0
	var yaw := float(e[8]) if e.size() > 8 else 0.0
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
	var aligned := it.has("align")
	var edge := 0.0
	if aligned:
		edge = (float(le["extent_l"]) if (side > 0 or flipped) else float(le["extent_r"])) * sc
	# the model: the union of the variants' AABBs, read from the manifest
	var vb := [INF, INF, INF, -INF, -INF, -INF]
	for v: Variant in le.get("variants", []):
		var a: Array = aabbs.get(str(v), [])
		if a.size() == 6:
			for c in 3:
				vb[c] = minf(float(vb[c]), float(a[c]))
				vb[c + 3] = maxf(float(vb[c + 3]), float(a[c + 3]))
	var near: float
	var zl: float
	var zh: float
	var no_aabb := float(vb[0]) == INF
	if no_aabb:
		var half_w := float(le["width"]) * sc * 0.5
		near = edge if aligned else half_w
		zl = z - half_w
		zh = z + half_w
	else:
		# the corners turned as ChunkContext.frame() turns the model: model +X = right of travel, model -Z = forward,
		# yaw + = to the right; a mirrored model is mirrored in its own x first
		var lat_lo := INF
		var lat_hi := -INF
		var f_lo := INF
		var f_hi := -INF
		for mx: float in [float(vb[0]), float(vb[3])]:
			for mz: float in [float(vb[2]), float(vb[5])]:
				var px := -mx if flipped else mx
				var l := (px * cos(yaw) - mz * sin(yaw)) * sc
				var f := (-px * sin(yaw) - mz * cos(yaw)) * sc
				lat_lo = minf(lat_lo, l)
				lat_hi = maxf(lat_hi, l)
				f_lo = minf(f_lo, f)
				f_hi = maxf(f_hi, f)
		near = -lat_lo if side > 0 else lat_hi
		if aligned:
			near = maxf(near, edge)
		zl = z + f_lo
		zh = z + f_hi
	var n := int(ceil((zh - zl) / t.seg_len))
	var depth := -INF
	for q in n + 1:
		var zq := zl if n == 0 else zl + (zh - zl) * float(q) / float(n)
		var fq := maxf(zq, 0.0) / t.seg_len
		var k := int(floor(fq))
		var u := fq - float(k)
		var m := absf(x) - lerpf(te.edge(k, side), te.edge(k + 1, side), u)
		if m <= 0.0:
			continue
		var cw := maxf(te.envelope_width(k, side), te.envelope_width(k + 1, side))   # as ChunkContext.bend_intrusion()
		if cw > 0.0:
			depth = maxf(depth, cw - (m - maxf(near, 0.0)))
	var cls := str(le["cls"])
	if cls == "building" and s.city:
		cls = "city_building"
	var droppable := attached or ((not it.has("offset") or bool(le["veg"])) and not bool(it.get("landmark", false)))
	return {"in": depth > TOLERANCE_M, "droppable": droppable, "depth": depth, "cls": cls, "side": side, "no_aabb": no_aabb,
		"where": "z %.1f..%.1f m, %.1f m towards the road" % [zl - z, zh - z, near]}
