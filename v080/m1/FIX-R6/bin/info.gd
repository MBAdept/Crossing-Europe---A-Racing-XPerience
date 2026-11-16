extends SceneTree
## QA-R6: element positions (km) of stage directions: fuel lanes, radars, borders, city ranges, finish.
##   godot --headless --path . -s <this> -- --only=dev_testetappe,kiel_hamburg

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, only):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		print("== %s  length %.2f km" % [dir["name"], t.z_to_km(t.length_z)])
		for l: Dictionary in plan.fuel_lanes:
			print("  fuel lane %.3f – %.3f" % [float(l["start_km"]), float(l["end_km"])])
		for r: Dictionary in plan.radars:
			print("  radar km %.3f (cam %.3f, mid cam %.3f) limit %d" % [float(r["km"]), float(r["km"]) + 0.25, (float(r["km"]) + float(r["end_km"])) * 0.5 + 0.25, int(r["limit"])])
		for b: Dictionary in plan.borders:
			print("  border km %.3f to %s (%s)" % [float(b["km"]), str(b["to"]), str(b.get("name_local", ""))])
		var in_city := false
		var c0 := 0.0
		for i in t.segment_index_at(t.length_z) + 1:
			var s := t.get_segment(i)
			if s.city != in_city:
				if s.city:
					c0 = t.z_to_km(s.z)
				else:
					print("  city %.2f – %.2f" % [c0, t.z_to_km(s.z)])
				in_city = s.city
		if in_city:
			print("  city %.2f – end" % c0)
	quit(0)
