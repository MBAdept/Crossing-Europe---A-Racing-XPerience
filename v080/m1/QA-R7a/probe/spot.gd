extends SceneTree
## QA-R7a probe (headless, R7a tree): the props of a stretch – foot beyond the shoulder, the exact envelope of the
## sight lines (sight.width), the rounded corridor (corridor_width), L of the camera 30 m before, the curve – to see
## why a prop Arcade shows is dropped.   -- --stage=<dir> --km0=<km> --km1=<km> [--side=1]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=")
		a[kv[0]] = kv[1] if kv.size() > 1 else ""
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	for dir: Dictionary in Fair.directions(net, []):
		if str(dir["name"]) != str(a.get("stage", "")):
			continue
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var t: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1842.0)
		var tp := TerrainProfile.new()
		tp.setup(path, t, tc, net["scenery"])
		var lib: PropLibrary = Props.new()._lib()
		var k0 := int(t.km_to_z(float(a["km0"])) / t.seg_len)
		var k1 := int(t.km_to_z(float(a["km1"])) / t.seg_len)
		var strip := tp.corridor_min_m - t.shoulder_w
		for k in range(k0, k1):
			var s := t.get_segment(k)
			for j in s.sprites.size():
				var it: Dictionary = s.sprites[j]
				if str(it.get("kind", "prop")) != "prop":
					continue
				var side := int(it.get("side", 1))
				if side == 0:
					continue
				var e: Dictionary = lib.sets.get(str(it.get("set", "")), {})
				if e.is_empty():
					if not lib._have_sprites:
						lib._load_sprite_manifest()
					e = lib._resolve(str(it.get("set", "")))
					lib.sets[str(it.get("set", ""))] = e
				var x := float(it.get("x", 0.0))
				var z := float(it.get("z", s.z))
				var kk := int(floor(z / t.seg_len))
				var half := s.lanes * t.lane_w * 0.5
				var edge := (half if side < 0 else half + s.fuel_lane * t.lane_w) + t.shoulder_w
				var foot := absf(x) - edge
				var env := tp.sight.width(kk, side)
				var cw := tp.corridor_width(kk, side)
				var dropped := cw > strip + 0.5 and foot > 0.0 and foot <= cw
				print("SPOT km %.3f seg %d side %+d %-26s h %.1f w %.1f foot %.1f | env %.1f rounded %.1f -> %s | curve %.2f L(cam) %.0f" % [
					t.z_to_km(z), kk, side, str(it.get("set", "")), float(e.get("height", 0.0)) * float(it.get("scale", 1.0)),
					float(e.get("width", 0.0)) * float(it.get("scale", 1.0)), foot, env, cw, "DROP" if dropped else "draw",
					s.curve, tp.sight.chord_at(maxi(0, kk - 10))])
	quit(0)
