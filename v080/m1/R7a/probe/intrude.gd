extends SceneTree
## R7a probe (headless): props the builder draws whose near part reaches into the envelope of the sight lines
## (A-17: nothing over 0.5 m inside). The props builder tests the foot only (drop_reason(): (z, x) = the anchor, for
## "align: edge" items the anchor is the near edge pushed out by the model's extent). Near part here: the near edge
## (scenery x) of an edge-aligned item, the crown/footprint half width towards the road for everything else.
## Counted with the corridor of the base (old band) and with the envelope (new) deciding what is drawn; the intrusion
## is always measured against the envelope.
##   godot --headless --path . -s <this> [-- --full]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const PB := preload("props_back.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var full := OS.get_cmdline_user_args().has("--full")
	var names: Array = []
	for p: Array in PB.POSITIONS:
		var nm := "%s__%s" % [p[1], p[2]]
		if not names.has(nm):
			names.append(nm)
	var dirs: Array[Dictionary] = Fair.directions(net, [] if full else names)
	if not full:
		var keep: Array[Dictionary] = []
		for d: Dictionary in dirs:
			if names.has(str(d["name"])):
				keep.append(d)
		dirs = keep
	var lib: PropLibrary = Props.new()._lib()
	var cover: Array = ConfigLoader.lookup(cfg, "graphics.modern.props.bend_cover", [])
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var tot := {}
	var t0 := Time.get_ticks_msec()
	for dir: Dictionary in dirs:
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var track: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1500.0 + 150.0 + 192.0)
		var tp := TerrainProfile.new()
		tp.setup(path, track, tc, net["scenery"])
		var r := _scan(track, tp, lib, cover, int(geo["nz"]))
		for key: String in r:
			if key.begins_with("max"):
				tot[key] = maxf(float(tot.get(key, 0.0)), float(r[key]))
			else:
				tot[key] = float(tot.get(key, 0.0)) + float(r[key])
		print("INTR %-40s %s" % [dir["name"], _fmt(r)])
		geo["path"] = null
	print("INTR TOTAL %d directions: %s  (%.0f s)" % [dirs.size(), _fmt(tot), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


static func _fmt(r: Dictionary) -> String:
	var s := ""
	for cls: String in ["building", "city_building", "tree", "plant", "rock", "other"]:
		s += "%s old %d new %d reach %d (deepest %.1f m); " % [cls, int(r.get("old_" + cls, 0)), int(r.get("new_" + cls, 0)),
			int(r.get("reach_" + cls, 0)), float(r.get("max_" + cls, 0.0))]
	s += "| back: foot test %d, reach test %d; reach test drops %d the base draws" % [int(r.get("back_new", 0)),
		int(r.get("back_reach", 0)), int(r.get("reach_drops_base_drawn", 0))]
	return s


## ChunkContext.in_bend_corridor(z, x, reach, half_len) on the whole track (the new corridor).
static func _in_bend_reach(tp: TerrainProfile, track: Track, z: float, x: float, reach: float, half_len: float) -> bool:
	var n := 0 if half_len <= 0.0 else int(ceil(half_len * 2.0 / track.seg_len))
	var side := -1 if x < 0.0 else 1
	var cmin := maxf(0.0, tp.corridor_min_m - track.shoulder_w)
	for q in n + 1:
		var zq := z if n == 0 else z - half_len + half_len * 2.0 * float(q) / float(n)
		var f := maxf(zq, 0.0) / track.seg_len
		var k := int(floor(f))
		var u := clampf(f - float(k), 0.0, 1.0)
		var e := lerpf(PB._paved(track, k, side), PB._paved(track, k + 1, side), u)
		var m := absf(x) - e - track.shoulder_w
		var cw := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), u)
		if cw > cmin + 0.5 and m > 0.0 and m - maxf(reach, 0.0) <= cw:
			return true
	return false


static func _scan(track: Track, tp: TerrainProfile, lib: PropLibrary, cover: Array, n: int) -> Dictionary:
	var r := {}
	for k in range(0, n):
		var s := track.get_segment(k)
		for j in s.sprites.size():
			var it: Dictionary = s.sprites[j]
			if str(it.get("kind", "prop")) != "prop":
				continue
			var e := PB._setof(lib, str(it.get("set", "")))
			var sc := float(it.get("scale", 1.0))
			if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
				e = PB._setof(lib, str(it.get("fallback", "")))
				if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
					continue
				sc *= float(it.get("fallback_scale", 1.0))
			var side := int(it.get("side", 1))
			if side == 0 or bool(it.get("landmark", false)) or cover.has(str(e["set"])):
				continue
			if float(e["height"]) * sc <= 0.5:
				continue
			var x := float(it.get("x", 0.0))
			var z := float(it.get("z", s.z))
			var near := x
			if it.has("align"):
				var flipped := side < 0 and bool(e["mirror_left"])
				x = Props.edge_anchor_x(x, side, flipped, float(e["extent_l"]), float(e["extent_r"]), sc)
			else:
				near = x - float(side) * float(e["width"]) * sc * 0.5
			var edge := PB._paved(track, k, side) + track.shoulder_w
			if absf(x) - edge > tp.limit(k, side) - Props.RIBBON_MARGIN_M:
				continue
			var decorative := not it.has("offset")
			var droppable := decorative or bool(e["veg"])
			var drawn_old := not (droppable and PB._in_bend(tp, track, z, x, true))
			var drawn_new := not (droppable and PB._in_bend(tp, track, z, x, false))
			var reach := absf(x) - absf(near)
			var half_len := float(e["width"]) * sc * 0.5
			var drawn_reach := not (droppable and _in_bend_reach(tp, track, z, x, reach, half_len))
			var dropped_old := not drawn_old
			if dropped_old and drawn_new:
				r["back_new"] = int(r.get("back_new", 0)) + 1
			if dropped_old and drawn_reach:
				r["back_reach"] = int(r.get("back_reach", 0)) + 1
			if drawn_old and not drawn_reach:
				r["reach_drops_base_drawn"] = int(r.get("reach_drops_base_drawn", 0)) + 1
			# the near part against the envelope (exact, both rows of the foot)
			var env := maxf(tp.sight.width_near(k, side), tp.sight.width_near(k + 1, side))
			if env <= 0.0:
				continue
			var m_near := absf(near) - edge
			var m_far := absf(x) - edge
			if m_near > env or m_far <= 0.0:
				continue
			var depth := env - maxf(m_near, 0.0)
			var cls := str(e["cls"])
			if not cls in ["building", "tree", "plant", "rock"]:
				cls = "other"
			if cls == "building" and s.city:
				cls = "city_building"
			if drawn_old:
				r["old_" + cls] = int(r.get("old_" + cls, 0)) + 1
			if drawn_reach:
				r["reach_" + cls] = int(r.get("reach_" + cls, 0)) + 1
			if drawn_new:
				r["new_" + cls] = int(r.get("new_" + cls, 0)) + 1
				r["max_" + cls] = maxf(float(r.get("max_" + cls, 0.0)), depth)
	return r
