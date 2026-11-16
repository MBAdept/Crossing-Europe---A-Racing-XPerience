extends SceneTree
## R5 scratch (not committed): km of the pylons and the ends of a few bridges.

func _initialize() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	for want: Array in [["kiel_hamburg", "kiel"], ["frankfurt_koeln", "frankfurt"], ["rostock_kiel", "rostock"], ["kassel_wuerzburg", "kassel"]]:
		for dir: Dictionary in Fair.call("directions", net, [want[0]]):
			if str(dir["from"]) != str(want[1]):
				continue
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg, net["scenery"])
			for br: Dictionary in t.bridges:
				print("BR %s %s %s km %.2f – %.2f depth %.1f slope %.1f bank '%s'" % [want[0], br["name"], br["type"], t.z_to_km(float(br["z0"])), t.z_to_km(float(br["z1"])), float(br["depth"]), float(br["slope"]), br["bank"]])
				var a := int(float(br["z0"]) / t.seg_len)
				var b := int(float(br["z1"]) / t.seg_len)
				for k in range(a, b + 1):
					var s := t.get_segment(k)
					for it: Dictionary in s.sprites:
						if str(it.get("proc", "")) == "pylon":
							print("   pylon km %.3f side %d h %.1f cables %.1f" % [t.z_to_km(float(it.get("z", 0.0))), int(it.get("side", 0)), float(it.get("height_m", 0.0)), float(it.get("cables", 0.0))])
	quit(0)
