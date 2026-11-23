extends SceneTree
## QA-R7a probe (headless): REAL chunk builds of the props and city builders through the shipped ChunkStreamer (sync
## mode), whole stages, in whichever tree it runs (base or R7a). Per stage:
##  * props drawn / dropped by reason (the builder's own counters), city fence pieces drawn / dropped;
##  * props taller than 0.5 m whose footprint reaches into the envelope of the sight lines of A-17 (measured with a
##    copy of R7a's kernel, env_kernel.gd, on a separate whole-stage path – the same yardstick in both trees):
##    foot in the envelope / only the near part (crown radius, near edge of an edge-aligned item) in it, by class;
##    deepest reach; and the same for items the builder never drops (event buildings, landmarks).
##   godot --headless --path . -s <this> [-- --stage=<dir>,<dir> --step=<m>]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const Env := preload("env_kernel.gd")

const DEFAULT := ["saragossa_pau__saragossa", "kassel_wuerzburg__kassel", "kiel_hamburg__kiel", "dortmund_frankfurt__dortmund",
	"muenchen_nuernberg__nuernberg", "slavonski_brod_belgrad__slavonski_brod", "hamburg_hannover__hamburg", "lyon_bern__lyon",
	"montpellier_lyon__montpellier", "wuerzburg_nuernberg__wuerzburg"]


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var names: Array = DEFAULT.duplicate()
	var step := 600.0
	var detail := false
	var dump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			names = Array(a.substr(8).split(",", false))
		elif a.begins_with("--step="):
			step = float(a.substr(7))
		elif a == "--detail":
			detail = true
		elif a.begins_with("--dump="):
			dump = a.substr(7)
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var tot := {}
	var t_all := Time.get_ticks_msec()
	var df: FileAccess = FileAccess.open(dump, FileAccess.WRITE) if dump != "" else null
	for dir: Dictionary in Fair.directions(net, []):
		if not names.has(str(dir["name"])) and not names.has("all"):
			continue
		var t0 := Time.get_ticks_msec()
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		# yardstick: the A-17 envelope on its own whole-stage path
		var pe := RoadPath3D.new()
		pe.setup(t, 0, r1)
		var env = Env.new()
		env.setup(pe, t, tc)
		# the real streamer with the real builders
		var p := RoadPath3D.new()
		var tp := TerrainProfile.new()
		tp.setup(p, t, tc, net["scenery"])
		var st := ChunkStreamer.new()
		st.setup(p, tp, t, cfg, {}, true)
		var pb := Props.new()
		st.register(pb)
		var cb := CityB.new()
		st.register(cb)
		var seen := {}
		var r := {}
		var end_z := float(t.segment_count - 1) * t.seg_len
		var cam := 0.0
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
				var cp: Dictionary = parts.get("city", {})
				r["fence_drawn"] = int(r.get("fence_drawn", 0)) + int(cp.get("fence_segments", 0))
				r["fence_dropped"] = int(r.get("fence_dropped", 0)) + int(cp.get("fence_dropped", 0))
				for e: Array in pp.get("list", []):
					r["props"] = int(r.get("props", 0)) + 1
					if df != null:
						df.store_line("%s %d %d %s %.1f" % [dir["name"], int(e[0]), int(e[1]), str(e[2]), t.z_to_km(float(e[4]))])
					_judge(e, t, pb.library, env, r, detail, str(dir["name"]))
			cam += step
		st.clear()
		st.free()
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		print("REAL %-40s chunks %d %s (%.0f s)" % [dir["name"], seen.size(), _fmt(r), secs])
		for key: String in r:
			if key.begins_with("max"):
				tot[key] = maxf(float(tot.get(key, 0.0)), float(r[key]))
			else:
				tot[key] = int(tot.get(key, 0)) + int(r[key])
	print("REAL TOTAL %s (%.0f s)" % [_fmt(tot), (Time.get_ticks_msec() - t_all) / 1000.0])
	if df != null:
		df.close()
	quit(0)


static func _fmt(r: Dictionary) -> String:
	var s := "props %d; dropped corridor %d ribbon %d density %d missing %d; fences drawn %d dropped %d;" % [
		int(r.get("props", 0)), int(r.get("drop_corridor", 0)), int(r.get("drop_ribbon", 0)), int(r.get("drop_density", 0)),
		int(r.get("drop_missing", 0)), int(r.get("fence_drawn", 0)), int(r.get("fence_dropped", 0))]
	s += " INTRUDE(>0.5 m, droppable): foot %d, near part %d [" % [int(r.get("foot", 0)), int(r.get("near", 0))]
	for cls: String in ["tree", "plant", "rock", "building", "city_building", "other"]:
		if r.has("near_" + cls) or r.has("foot_" + cls):
			s += "%s %d/%d max %.1f m; " % [cls, int(r.get("foot_" + cls, 0)), int(r.get("near_" + cls, 0)), float(r.get("max_" + cls, 0.0))]
	s += "] fixed (event/landmark) %d" % int(r.get("fixed", 0))
	return s


## One drawn prop [seg, j, set, x, z, sc, flipped, kind] against the envelope.
static func _judge(e: Array, t: Track, lib: PropLibrary, env, r: Dictionary, detail: bool, dname: String) -> void:
	var seg := int(e[0])
	var j := int(e[1])
	var set_id := str(e[2])
	var x := float(e[3])
	var z := float(e[4])
	var sc := float(e[5])
	var s := t.get_segment(seg)
	if j < 0 or j >= s.sprites.size():
		return
	var it: Dictionary = s.sprites[j]
	var side := int(it.get("side", 1))
	if side == 0:
		return
	var le: Dictionary = lib.sets.get(set_id, {})
	if le.is_empty():
		return
	var h := float(le["height"]) * sc
	if h <= 0.5:
		return
	var k := int(floor(z / t.seg_len))
	var u := z / t.seg_len - float(k)
	var half := s.lanes * t.lane_w * 0.5
	var edge := (half if side < 0 else half + s.fuel_lane * t.lane_w) + t.shoulder_w
	var foot := absf(x) - edge
	var near := foot
	if it.has("align"):
		near = minf(near, absf(float(it.get("x", x))) - edge)
	else:
		near = foot - float(le["width"]) * sc * 0.5
	# the envelope over the item's length along the road (half its width each way), rows k-? .. k+?
	var half_len := float(le["width"]) * sc * 0.5
	var w_foot: float = lerpf(env.width(k, side), env.width(k + 1, side), u)
	var w_max := w_foot
	var n := int(ceil(half_len * 2.0 / t.seg_len))
	for q in n + 1:
		var zq := z - half_len + half_len * 2.0 * float(q) / float(maxi(n, 1))
		var kq := maxi(0, int(floor(zq / t.seg_len)))
		w_max = maxf(w_max, env.width(kq, side))
	if w_max <= 0.05 or foot <= 0.0:
		return
	var decorative := not it.has("offset")
	var droppable := (decorative or bool(le["veg"])) and not bool(it.get("landmark", false))
	var cls := str(le["cls"])
	if cls == "building" and s.city:
		cls = "city_building"
	if not cls in ["tree", "plant", "rock", "building", "city_building"]:
		cls = "other"
	if foot < w_foot:
		if droppable:
			r["foot"] = int(r.get("foot", 0)) + 1
			r["foot_" + cls] = int(r.get("foot_" + cls, 0)) + 1
		else:
			r["fixed"] = int(r.get("fixed", 0)) + 1
		if detail:
			print("  FOOT %s km %.2f side %d %s foot %.1f env %.1f" % [dname, t.z_to_km(z), side, set_id, foot, w_foot])
	elif near < w_max:
		if droppable:
			r["near"] = int(r.get("near", 0)) + 1
			r["near_" + cls] = int(r.get("near_" + cls, 0)) + 1
			r["max_" + cls] = maxf(float(r.get("max_" + cls, 0.0)), w_max - near)
			print("DEPTH %s %.2f %.2f" % [cls, w_max - near, h])
		else:
			r["fixed"] = int(r.get("fixed", 0)) + 1
		if detail:
			print("  NEAR %s km %.2f side %d %s foot %.1f near %.1f env %.1f h %.1f" % [dname, t.z_to_km(z), side, set_id, foot, near, w_max, h])
