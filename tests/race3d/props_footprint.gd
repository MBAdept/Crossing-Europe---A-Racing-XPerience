extends SceneTree
## Network check of contract A-17 for what the builders really draw (FIX-R7a, finding QR7a-01 of QA-R7a): no prop
## taller than 0.5 m that the props builder may leave out stands with any part of its footprint inside the envelope
## of the sight lines of a bend – not its foot, not the crown of a tree, not the near edge of an edge-aligned house.
## Builds the shipped ChunkStreamer in sync mode with the real props and city builders over whole stage directions
## and measures every drawn prop against the exact envelope (TerrainProfile.envelope_width(), computed on a path of
## its own over the whole stage; F7 of tests/sim/modern_sight.gd checks that envelope against an independent
## reference). Footprint: half the model's width along the road; towards the road the crown's radius, or for an
## edge-aligned item the distance from its anchor to its near edge; between two rows the larger envelope of the two
## (as ChunkContext.bend_intrusion()). Tolerance 5 cm.
##   godot --headless --path . -s res://tests/race3d/props_footprint.gd [-- --full] [--stage=<dir>,…] [--verbose]
## Normal run: six directions with the review positions T1–T4, C1, S0, S4 and the town bends (about 1 minute);
## --full: all 128 directions (about 5 minutes).
## NOT a gate yet (its name does not start with check_, so tools/run_tests.sh does not run it): the props builder
## (builders/props.gd, R7c) tests only the foot of a prop until the change FIX-R7a hands over is merged (its report,
## notes_for_next) – on FIX-R7a's head alone this check fails with about 5,600 props. After that merge the assembly
## renames it to check_props_footprint.gd (git mv), which makes it a gate of run_tests.sh. Owner: race3d kernel.
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const TOLERANCE_M := 0.05
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
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var full := _arg("full", "") != ""
	var verbose := _arg("verbose", "") != ""
	var only: Array = Array(_arg("stage", "").split(",", false))
	if only.is_empty() and not full:
		only = QUICK.duplicate()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var tot := {"props": 0, "checked": 0, "in": 0, "fixed": 0, "max_m": 0.0}
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
				for e: Array in (ch["parts"] as Dictionary).get("props", {}).get("list", []):
					tot["props"] = int(tot["props"]) + 1
					var r := _judge(e, t, te, pb.library)
					if r.is_empty():
						continue
					tot["checked"] = int(tot["checked"]) + 1
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
						print("FOOTPRINT %s km %.2f %s side %d: %.2f m in the envelope" % [dir["name"], t.z_to_km(float(e[4])), str(e[2]),
							int(r["side"]), float(r["depth"])])
			cam += 600.0
		st.clear()
		st.free()
		tot["in"] = int(tot["in"]) + n_in
		print("FOOTPRINT %-40s chunks %d: %d props in the sight lines" % [dir["name"], seen.size(), n_in])
	var ok := int(tot["in"]) == 0 and int(tot["checked"]) > 0
	print("FOOTPRINT %d directions, %d props drawn, %d measured (> 0.5 m beside the road): %d with their footprint in the envelope %s (deepest %.2f m); %d that the builder never leaves out (landmarks, stage events) (%.0f s)" % [
		dirs, int(tot["props"]), int(tot["checked"]), int(tot["in"]), str(by_cls), float(tot["max_m"]), int(tot["fixed"]),
		float(Time.get_ticks_msec() - t_all) / 1000.0])
	print("CHECK props_footprint %s %d Requisiten über 0,5 m mit dem Fußabdruck in der Hülle der Sichtlinien (%d gemessen, %d Etappenrichtungen)" % [
		"OK    " if ok else "FEHLER", int(tot["in"]), int(tot["checked"]), dirs])
	quit(0 if ok else 1)


## One drawn prop [seg, j, set, x, z, scale, flipped, kind] against the envelope: {} when it is not measured (on the
## road, not beside it, at most 0.5 m high, unknown set), else {in, droppable, depth, cls, side}.
static func _judge(e: Array, t: Track, te: TerrainProfile, lib: PropLibrary) -> Dictionary:
	var seg := int(e[0])
	var j := int(e[1])
	var x := float(e[3])
	var z := float(e[4])
	var sc := float(e[5])
	var flipped := int(e[6]) != 0
	var s := t.get_segment(seg)
	if j < 0 or j >= s.sprites.size():
		return {}
	var it: Dictionary = s.sprites[j]
	var side := int(it.get("side", 1))
	var le: Dictionary = lib.sets.get(str(e[2]), {})
	if side == 0 or le.is_empty() or float(le["height"]) * sc <= 0.5:
		return {}
	var half_w := float(le["width"]) * sc * 0.5
	var reach := half_w
	if it.has("align"):
		reach = (float(le["extent_l"]) if (side > 0 or flipped) else float(le["extent_r"])) * sc
	var n := int(ceil(half_w * 2.0 / t.seg_len))
	var depth := -INF
	for q in n + 1:
		var zq := z if n == 0 else z - half_w + half_w * 2.0 * float(q) / float(n)
		var fq := maxf(zq, 0.0) / t.seg_len
		var k := int(floor(fq))
		var u := fq - float(k)
		var m := absf(x) - lerpf(te.edge(k, side), te.edge(k + 1, side), u)
		if m <= 0.0:
			continue
		var cw := maxf(te.envelope_width(k, side), te.envelope_width(k + 1, side))   # as ChunkContext.bend_intrusion()
		if cw > 0.0:
			depth = maxf(depth, cw - (m - reach))
	var cls := str(le["cls"])
	if cls == "building" and s.city:
		cls = "city_building"
	var droppable := (not it.has("offset") or bool(le["veg"])) and not bool(it.get("landmark", false))
	return {"in": depth > TOLERANCE_M, "droppable": droppable, "depth": depth, "cls": cls, "side": side}
