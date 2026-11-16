extends SceneTree
# NACH-WASSER: the items of TrackSegment.sprites between two km of a stage direction (kind, set, side, x, scale, flags).
# usage: godot --headless --path <project> -s seg_dump.gd -- <stage>__<from> <km0> <km1> [min_abs_x]

const Fair := preload("res://tests/race3d/fairness.gd")


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var name := a[0]
	var km0 := float(a[1])
	var km1 := float(a[2])
	var min_x := float(a[3]) if a.size() > 3 else 0.0
	var net := Fair.load_network()
	var cfg := ConfigLoader.load_merged()
	for dir: Dictionary in Fair.directions(net):
		if str(dir["name"]) != name:
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var k0 := int(floor(t.km_to_z(km0) / t.seg_len))
		var k1 := int(floor(t.km_to_z(km1) / t.seg_len))
		print("seg_len %.1f m, km %.2f..%.2f = segments %d..%d, z %.0f..%.0f m" % [t.seg_len, km0, km1, k0, k1, k0 * t.seg_len, k1 * t.seg_len])
		var kinds := {}
		for k in range(k0, k1 + 1):
			var seg = t.get_segment(k)
			for it: Dictionary in seg.sprites:
				var x := float(it.get("x", 0.0))
				if absf(x) < min_x:
					continue
				var key := "%s|%s" % [str(it.get("kind", "prop")), str(it.get("set", it.get("obj", it.get("proc", "?"))))]
				kinds[key] = int(kinds.get(key, 0)) + 1
				if bool(it.get("landmark", false)) or str(it.get("kind", "prop")) != "prop" or absf(x) > 60.0:
					print("  km %.2f k=%d kind=%s set=%s obj=%s side=%d x=%.1f scale=%s proc=%s landmark=%s keys=%s" % [
						t.z_to_km(float(it.get("z", k * t.seg_len))), k, str(it.get("kind", "prop")), str(it.get("set", "")),
						str(it.get("obj", "")), int(it.get("side", 0)), x, str(it.get("scale", 1.0)), str(it.get("proc", "-")),
						str(it.get("landmark", false)), str(it.keys())])
		print("counts: ", kinds)
	quit(0)
