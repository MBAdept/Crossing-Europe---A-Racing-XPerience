extends SceneTree
## R7a probe: the props along C1 (Dortmund – Frankfurt km 221, the bend after the bridge) between 100 and 330 m ahead
## of the camera – foot (anchor) and near edge against the envelope of the sight lines (new) and the base's band (old).
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const PB := preload("props_back.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var km := 221.0
	var stage := "dortmund_frankfurt__dortmund"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--km="):
			km = float(a.substr(5))
		elif a.begins_with("--stage="):
			stage = a.substr(8)
	var dirs := Fair.directions(net, [stage])
	var lib: PropLibrary = Props.new()._lib()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	for dir: Dictionary in dirs:
		if str(dir["name"]) != stage:
			continue
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var track: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1500.0 + 150.0 + 192.0)
		var tp := TerrainProfile.new()
		tp.setup(path, track, tc, net["scenery"])
		var car := track.km_to_z(km)
		var cam := car - 9.0
		var kc := int(floor(cam / track.seg_len))
		print("C1 car z %.1f  cam row %d  L %.1f m" % [car, kc, tp.sight.chord_at(kc) if tp.sight.has_method("chord_at") else -1.0])
		for k in range(kc, kc + 340, 10):
			print("  row +%3d: env L %.1f R %.1f  old L %.1f R %.1f  curve %.5f" % [k - kc, tp.sight.width(k, -1), tp.sight.width(k, 1),
				PB._old_width(tp, track, k, -1), PB._old_width(tp, track, k, 1), track.get_segment(k).curve])
		for k in range(kc + 60, kc + 340):
			var s := track.get_segment(k)
			for j in s.sprites.size():
				var it: Dictionary = s.sprites[j]
				if str(it.get("kind", "prop")) != "prop":
					continue
				var e := PB._setof(lib, str(it.get("set", "")))
				if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
					e = PB._setof(lib, str(it.get("fallback", "")))
					if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
						continue
				var side := int(it.get("side", 1))
				if side == 0:
					continue
				var sc := float(it.get("scale", 1.0))
				var x := float(it.get("x", 0.0))
				var z := float(it.get("z", s.z))
				var near := x
				if it.has("align"):
					var flipped := side < 0 and (bool(e["mirror_left"]))
					x = Props.edge_anchor_x(x, side, flipped, float(e["extent_l"]), float(e["extent_r"]), sc)
				var edge := PB._paved(track, k, side) + track.shoulder_w
				var was := PB._in_bend(tp, track, z, x, true)
				var now := PB._in_bend(tp, track, z, x, false)
				var near_now := PB._in_bend(tp, track, z, near, false)
				print("  z +%6.1f %s %-34s cls %-8s h %5.1f w %5.1f foot %6.1f near %6.1f (beyond %5.1f / %5.1f)  env %5.1f old %5.1f  dropped old %s new %s near-in-env %s" % [
					z - cam, "L" if side < 0 else "R", str(e["set"]), str(e["cls"]), float(e["height"]) * sc, float(e["width"]) * sc,
					x, near, absf(x) - edge, absf(near) - edge, tp.sight.width(k, side), PB._old_width(tp, track, k, side),
					was, now, near_now])
	quit(0)
