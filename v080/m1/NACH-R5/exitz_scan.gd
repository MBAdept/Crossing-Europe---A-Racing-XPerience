extends SceneTree
## NACH-R5: independent check of tunnel_state.exit_z / the builder's tunnel range against Arcade's own segment flags
## (Track.get_segment(k).tunnel) for every tunnel of every direction (and the dev stage).

func _initialize() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var dirs: Array = Fair.call("directions", net, [])
	dirs.append_array(Fair.call("directions", net, ["dev_testetappe"]))
	var n := 0
	var bad := 0
	var min_gap := INF
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.tunnels.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for tu: Dictionary in plan.tunnels:
			n += 1
			var z_end := t.km_to_z(float(tu["end_km"]))
			var z_start := t.km_to_z(float(tu["start_km"]))
			var exit_z := float(ceili(z_end / t.seg_len - 1.0e-6)) * t.seg_len
			var portal_z := float(ceili(z_start / t.seg_len - 1.0e-6)) * t.seg_len
			# Arcade: first tunnel segment and first non-tunnel segment after it
			var k := int(floor(z_start / t.seg_len)) - 2
			while k < t.segment_count and not t.get_segment(k).tunnel:
				k += 1
			var first := k
			while k < t.segment_count and t.get_segment(k).tunnel:
				k += 1
			var arc_exit := float(k) * t.seg_len
			var arc_portal := float(first) * t.seg_len
			var frac: float = z_end / t.seg_len - floorf(z_end / t.seg_len)
			min_gap = minf(min_gap, minf(frac, 1.0 - frac))
			var ok := absf(arc_exit - exit_z) < 0.01 and absf(arc_portal - portal_z) < 0.01
			if not ok:
				bad += 1
			print("%s %s %s: end_km z %.2f exit_z %.2f arcade %.2f | portal %.2f arcade %.2f | %s" % ["OK" if ok else "ABWEICHUNG",
				str(dir["name"]), str(tu.get("name", "?")), z_end, exit_z, arc_exit, portal_z, arc_portal, "frac %.4f" % frac])
	print("EXITZ-SCAN %s: %d Tunnel, %d abweichend, kleinster Abstand von end_km zur Segmentgrenze %.4f Segmente" % [
		"OK" if bad == 0 else "FEHLER", n, bad, min_gap])
	quit(0 if bad == 0 else 1)
