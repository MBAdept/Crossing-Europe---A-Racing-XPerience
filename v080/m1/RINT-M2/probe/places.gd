extends SceneTree
## RINT-M2: tunnels, bridges (type) and borders of a few stages, for the A/B positions.


func _initialize() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var dirs: Array = Fair.call("directions", net, ["prag_nuernberg", "wuerzburg_nuernberg", "prag_leipzig", "dresden_leipzig", "bremen_amsterdam", "frankfurt_koeln"])
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var sid := "%s/%s" % [str((dir["stage"] as Dictionary).get("id", "?")), str(dir["from"])]
		for tu: Dictionary in plan.tunnels:
			print("PLACE %s tunnel %s %.2f-%.2f" % [sid, str(tu.get("name", "")), float(tu["start_km"]), float(tu["end_km"])])
		for br: Dictionary in t.bridges:
			print("PLACE %s bridge %s %s km %.2f-%.2f" % [sid, str(br.get("name", "")), str(br.get("type", br.get("style", ""))), t.z_to_km(float(br["z0"])), t.z_to_km(float(br["z1"]))])
		for b: Dictionary in plan.borders:
			print("PLACE %s border %s" % [sid, str(b)])
	quit(0)
