extends SceneTree
## R6 helper: the signs on the right around every fuel canopy of every stage direction (z relative to the canopy
## front), to see which column of a canopy could hide a sign (F1).
##   godot --headless --path . -s <this> [-- --only=dev_testetappe]

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = [a.substr(7)]
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var n := 0
	var under := 0
	var behind := 0
	for dir: Dictionary in Fair.directions(net, only):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.fuel_lanes.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for z: Dictionary in t.zones:
			if str(z["kind"]) != "fuel_canopy":
				continue
			n += 1
			var z0 := float(z["z0"])
			var z1 := float(z["z1"])
			var line := ""
			var u := false
			var b := false
			for i in range(t.segment_index_at(z0 - 3.0), t.segment_index_at(z1 + 120.0) + 1):
				var s := t.get_segment(i)
				for sp: Variant in s.sprites:
					var it: Dictionary = sp
					if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) <= 0:
						continue
					var zs := float(it.get("z", s.z))
					line += " [%+.1f %s x=%.2f]" % [zs - z0, str(it.get("sign", "")), float(it.get("x", 0.0))]
					if zs >= z0 - 1.0 and zs <= z1:
						u = true
					elif zs > z1:
						b = true
			if u:
				under += 1
			if b:
				behind += 1
			if line != "":
				print("%s canopy z %.0f-%.0f (km %.2f):%s" % [str(dir["name"]), z0, z1, t.z_to_km(z0), line])
	print("CANOPIES %d  sign under a canopy %d  sign within 120 m behind one %d" % [n, under, behind])
	quit(0)
