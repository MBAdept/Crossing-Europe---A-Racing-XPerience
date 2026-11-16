extends SceneTree
## R6 helper: km positions of the structures of a stage direction (fuel lanes, borders, radars, city limits, finish).
##   godot --headless --path . -s <this> -- --stage=dev_testetappe [--from=dev_start]

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var stage := str(args.get("stage", "dev_testetappe"))
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, [stage]):
		var from := str(args.get("from", dir["stage"]["from"]))
		if str(dir["from"]) != from:
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		print("STAGE %s from %s  length %.1f km  z %.0f  time_scale %.1f" % [stage, from, plan.length_km, t.length_z, t.time_scale])
		for l: Dictionary in plan.fuel_lanes:
			print("  fuel lane %.2f – %.2f km" % [float(l["start_km"]), float(l["end_km"])])
		for b: Dictionary in plan.borders:
			print("  border km %.2f to %s (%s)" % [float(b["km"]), str(b["to"]), str(b.get("name_local", ""))])
		for r: Dictionary in plan.radars:
			print("  radar km %.2f – %.2f limit %d (warn %.2f)" % [float(r["km"]), float(r["end_km"]), int(r["limit"]), float(r["warn_km"])])
		print("  city limits km %.2f, centre %.2f" % [plan.city_limits_km, plan.city_center_km])
		for tn: Dictionary in plan.tunnels:
			print("  tunnel %.2f – %.2f" % [float(tn["start_km"]), float(tn["end_km"])])
		for z: Dictionary in t.zones:
			if str(z["kind"]) in ["fuel", "border"]:
				print("  zone %s z %.0f – %.0f (km %.2f – %.2f)" % [str(z["kind"]), float(z["z0"]), float(z["z1"]), t.z_to_km(float(z["z0"])), t.z_to_km(float(z["z1"]))])
	quit(0)
