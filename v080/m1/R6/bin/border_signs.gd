extends SceneTree
## R6 helper: the signs around every border station of every stage direction (z relative to the roof front), to see
## which pillar of the roof could hide a sign (F1).
##   godot --headless --path . -s <this> [-- --only=dev_testetappe]

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = [a.substr(7)]
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var n_borders := 0
	var in_zone := [0, 0]
	var after60 := [0, 0]
	var after150 := [0, 0]
	for dir: Dictionary in Fair.directions(net, only):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.borders.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for z: Dictionary in t.zones:
			if str(z["kind"]) != "border":
				continue
			n_borders += 1
			var z0 := float(z["z0"])
			var z1 := float(z["z1"])
			var line := "%s border z %.0f (km %.2f) to %s:" % [str(dir["name"]), z0, t.z_to_km(z0), str(z["country"])]
			var flags := [[false, false, false], [false, false, false]]
			for i in range(t.segment_index_at(z0 - 25.0), t.segment_index_at(z1 + 160.0) + 1):
				var s := t.get_segment(i)
				for sp: Variant in s.sprites:
					var it: Dictionary = sp
					if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
						continue
					var zs := float(it.get("z", s.z))
					var side := int(it.get("side", 1))
					var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
					line += " [%s %+.1f %s x=%.2f hw=%.2f]" % ["R" if side > 0 else "L", zs - z0, str(it.get("sign", "")), float(it.get("x", 0.0)), hw]
					var si := 0 if side < 0 else 1
					if zs > z0 and zs <= z1:
						flags[si][0] = true
					elif zs > z1 and zs <= z1 + 60.0:
						flags[si][1] = true
					elif zs > z1 + 60.0 and zs <= z1 + 150.0:
						flags[si][2] = true
			for si in 2:
				if flags[si][0]:
					in_zone[si] += 1
				if flags[si][1]:
					after60[si] += 1
				if flags[si][2]:
					after150[si] += 1
			print(line)
	print("BORDERS %d  sign in zone L/R %s  sign within 60 m after the roof L/R %s  60-150 m L/R %s" % [n_borders, str(in_zone), str(after60), str(after150)])
	quit(0)
