extends SceneTree
## QA-R7c probe (headless): REAL chunk builds of the props builder (+ city builder) through the shipped ChunkStreamer
## (sync mode) on every stage direction, in whichever tree it runs (base or R7c):
##  * props drawn / dropped by reason, attached props (R7c), per-set counts (dump file for a base/R7c diff)
##  * R7c only: every committed model MultiMesh has a band meta, its instances carry custom a in [1, 2) (tint + phase)
##  * R7c only: the bands of every model at Details 0/1/2 cover every distance 0..4000 m exactly once (dither sum = 1)
##  * ground_sink: how deep rocks/cliffs sink below their centre ground (relative to their height)
##   godot --headless --path . -s <this> -- [--stage=<dir>,<dir>|all] [--step=<m>] [--dump=<file>]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const N := 32

var r7c := false
var _ctx_cache: Dictionary = {}


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var names: Array = ["all"]
	var step := 600.0
	var dump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			names = Array(a.substr(8).split(",", false))
		elif a.begins_with("--step="):
			step = float(a.substr(7))
		elif a.begins_with("--dump="):
			dump = a.substr(7)
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var tot := {}
	var t_all := Time.get_ticks_msec()
	var df: FileAccess = FileAccess.open(dump, FileAccess.WRITE) if dump != "" else null
	var bands_checked := false
	var dirs := Fair.directions(net, [])
	dirs.append_array(Fair.directions(net, ["dev_testetappe"]))
	for dir: Dictionary in dirs:
		if not names.has(str(dir["name"])) and not names.has("all"):
			continue
		var t0 := Time.get_ticks_msec()
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		var tp := TerrainProfile.new()
		tp.setup(p, t, tc, net["scenery"])
		var st := ChunkStreamer.new()
		st.setup(p, tp, t, cfg, {}, true)
		var pb := Props.new()
		st.register(pb)
		var cb := CityB.new()
		st.register(cb)
		r7c = pb.has_method("model_bands")
		# a second path/terrain for the ground probes of ground_sink (same data, own contexts)
		var p2 := RoadPath3D.new()
		p2.setup(t, 0, r1)
		var tp2 := TerrainProfile.new()
		tp2.setup(p2, t, tc, net["scenery"])
		var seen := {}
		var r := {}
		_ctx_cache.clear()
		var tq := Time.get_ticks_msec()
		var end_z := float(t.segment_count - 1) * t.seg_len
		var cam := 0.0
		printerr("  dir %s end_z %.0f setup %.1f s" % [dir["name"], end_z, (Time.get_ticks_msec() - t0) / 1000.0])
		while cam < end_z:
			st.update(cam, 900.0)
			var snap := st.snapshot()
			for ch: Dictionary in snap["chunks"]:
				var ci := int(ch["index"])
				if seen.has(ci) or str(ch["state"]) != "committed":
					continue
				seen[ci] = true
				var parts: Dictionary = ch["parts"]
				var pp: Dictionary = parts.get("props", {})
				var dr: Dictionary = pp.get("dropped", {})
				for key: String in dr:
					r["drop_" + key] = int(r.get("drop_" + key, 0)) + int(dr[key])
				var lst: Array = pp.get("list", [])
				r["props"] = int(r.get("props", 0)) + lst.size()
				r["attached"] = int(r.get("attached", 0)) + (pp.get("attach_list", []) as Array).size()
				r["cover"] = int(r.get("cover", 0)) + (pp.get("cover_list", []) as Array).size()
				for e: Array in lst:
					if df != null:
						df.store_line("%s %d %d %s %.2f %.2f %.3f %d" % [dir["name"], int(e[0]), int(e[1]), str(e[2]), float(e[3]), float(e[4]), float(e[5]), int(e[6])])
					if r7c:
						_sink_probe(e, t, p2, tp2, cfg, pb.library, r, str(dir["name"]))
			if r7c:
				for h: Variant in pb.get("_holders"):
					if is_instance_valid(h) and not (h as Node).has_meta(&"qa_seen"):
						(h as Node).set_meta(&"qa_seen", true)
						_check_holder(h as Node, r)
			cam += step
		print("  stream %.1f s" % ((Time.get_ticks_msec() - tq) / 1000.0))
		# the committed holders: band metas, custom data
		if r7c:
			printerr("  holders checked %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
			if not bands_checked:
				bands_checked = true
				_check_bands(pb, cfg)
		st.clear()
		st.free()
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		print("SCAN %-42s chunks %d %s (%.0f s)" % [dir["name"], seen.size(), _fmt(r), secs])
		for key: String in r:
			if key.begins_with("max"):
				tot[key] = maxf(float(tot.get(key, 0.0)), float(r[key]))
			else:
				tot[key] = int(tot.get(key, 0)) + int(r[key])
	print("SCAN TOTAL %s (%.0f s)" % [_fmt(tot), (Time.get_ticks_msec() - t_all) / 1000.0])
	if df != null:
		df.close()
	quit(0)


static func _fmt(r: Dictionary) -> String:
	var keys := r.keys()
	keys.sort()
	var s := ""
	for k: Variant in keys:
		var v: Variant = r[k]
		s += "%s=%s " % [k, ("%.2f" % float(v)) if v is float else str(v)]
	return s


## R7c: every model MultiMesh under a holder has a band; every instance's custom a lies in [1, 2) (tint flag + phase)
func _check_holder(h: Node, r: Dictionary) -> void:
	for c: Node in h.get_children():
		if not (c is MultiMeshInstance3D):
			continue
		var mmi := c as MultiMeshInstance3D
		if c.has_meta(&"caster"):
			r["mm_caster"] = int(r.get("mm_caster", 0)) + 1
			continue
		if not c.has_meta(&"model"):
			r["mm_other"] = int(r.get("mm_other", 0)) + 1
			continue
		r["mm_model"] = int(r.get("mm_model", 0)) + 1
		var b: Vector4 = c.get_meta(&"band", Vector4.ZERO)
		if not (b.x <= b.y and b.y <= b.z and b.z <= b.w):
			r["bad_band_meta"] = int(r.get("bad_band_meta", 0)) + 1
		var mm := mmi.multimesh
		if mm == null or not mm.use_custom_data:
			r["mm_no_custom"] = int(r.get("mm_no_custom", 0)) + 1
			continue
		var buf := mm.buffer
		var stride := 12 + (4 if mm.use_colors else 0) + 4
		for i in mm.instance_count:
			var a := buf[i * stride + stride - 1]
			if a < 1.0 or a >= 2.0:
				r["bad_phase"] = int(r.get("bad_phase", 0)) + 1
			r["inst_checked"] = int(r.get("inst_checked", 0)) + 1


## R7c: for every model at Details 0/1/2: sum over its representations of the dither share fin x fout = 1 at every
## distance (no hole, no pixel twice), the last representation reaches 'endless'
func _check_bands(pb: Object, cfg: Dictionary) -> void:
	var dets: Array = ConfigLoader.lookup(cfg, "graphics.levels.details", [])
	var lib: PropLibrary = pb.get("library")
	var bad := 0
	var checked := 0
	var info := {}
	for di in dets.size():
		pb.call("apply_quality", dets[di])
		for mid: String in lib.models:
			var bands: Dictionary = pb.call("model_bands", mid)
			checked += 1
			var d := 0.0
			var worst := 0.0
			var worst_d := 0.0
			while d <= 4000.0:
				var s := 0.0
				for rep: String in bands:
					var b: Vector4 = bands[rep]
					if d < b.x or d > b.w:
						continue
					var fin := clampf((d - b.x) / maxf(b.y - b.x, 0.001), 0.0, 1.0)
					var fout := clampf((b.w - d) / maxf(b.w - b.z, 0.001), 0.0, 1.0)
					s += fin * fout if not (fin >= 1.0 and fout >= 1.0) else 1.0
				if absf(s - 1.0) > worst:
					worst = absf(s - 1.0)
					worst_d = d
				d += 0.25
			if worst > 0.02:
				bad += 1
				print("BANDS BAD details %d %s worst %.3f at %.2f m %s" % [di, mid, worst, worst_d, str(bands)])
			if di == 1:
				var reps: Array = (lib.models[mid] as Dictionary).get("reps", [])
				var ends := []
				for rep: String in bands:
					ends.append("%s %.0f-%.0f" % [rep, (bands[rep] as Vector4).z, (bands[rep] as Vector4).w])
				info[mid] = "%s lod_m %s | %s" % [str(reps), str((lib.models[mid] as Dictionary).get("lod_m")), ", ".join(ends)]
	var ks := info.keys()
	ks.sort()
	for k: Variant in ks:
		print("BANDS MITTEL %s: %s" % [k, info[k]])
	print("BANDS CHECKED %d (model x details), BAD %d" % [checked, bad])
	pb.call("apply_quality", dets[1])


## ground_sink: depth of the sink below the centre ground, relative to the prop's height (R7c only changes the height)
func _sink_probe(e: Array, t: Track, p2: RoadPath3D, tp2: TerrainProfile, cfg: Dictionary, lib: PropLibrary, r: Dictionary, dname: String) -> void:
	var set_id := str(e[2])
	var le: Dictionary = lib.sets.get(set_id, {})
	if le.is_empty() or not bool(le.get("ground_sink", false)):
		return
	var z := float(e[4])
	var x := float(e[3])
	var sc := float(e[5])
	var c := int(floor(z / t.seg_len)) / N
	var ctx: ChunkContext = _ctx_cache.get(c)
	if ctx == null:
		p2.ensure((c + 1) * N + 700)
		ctx = ChunkContext.new()
		ctx.cfg = cfg
		ctx.scenery_db = t.scenery_db
		ctx.capture(c, c * N, c * N + N, p2, tp2, t)
		_ctx_cache.clear()
		_ctx_cache[c] = ctx
	var h0 := ctx.ground(z, x)
	var rr := 0.5 * maxf(float(le["width"]), float(le.get("length", le["width"]))) * sc
	var ps: Variant = Props
	var h: float = ps.call("sink_height", ctx, z, x, rr, h0)
	var depth := h0 - h
	var hgt := float(le["height"]) * sc
	var rel := depth / maxf(0.01, hgt)
	r["sink_n"] = int(r.get("sink_n", 0)) + 1
	r["max_sink_rel"] = maxf(float(r.get("max_sink_rel", 0.0)), rel)
	r["max_sink_m"] = maxf(float(r.get("max_sink_m", 0.0)), depth)
	if rel > 0.5:
		r["sink_over_half"] = int(r.get("sink_over_half", 0)) + 1
		if int(r.get("sink_over_half", 0)) <= 3:
			print("  SINK>50%% %s km %.2f %s x %.1f h %.1f m depth %.2f m (%.0f %%)" % [dname, t.z_to_km(z), set_id, x, hgt, depth, rel * 100.0])
