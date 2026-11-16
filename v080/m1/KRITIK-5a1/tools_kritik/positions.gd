extends SceneTree
## Scratch tool (AS4): where exactly does a stage direction place given sets? km, side, x, offset, scale per item.
##   godot --headless --path . -s <this file> -- --stage=<id> --from=<city> --sets=props/a,props/b [--km0=0 --km1=999]

const Fair := preload("res://tests/race3d/fairness.gd")


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var want := _arg("sets", "").split(",", false)
	var km0 := float(_arg("km0", "0"))
	var km1 := float(_arg("km1", "9999"))
	for dir: Dictionary in Fair.directions(net, [_arg("stage", "kiel_hamburg")]):
		if str(dir["from"]) != _arg("from", str(dir["from"])):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var n := t.segment_index_at(t.km_to_z(minf(km1, plan.length_km))) - 1
		print("STAGE ", dir["name"], " length ", plan.length_km)
		for i in range(0, n):
			var s := t.get_segment(i)
			var km := t.z_to_km(s.z)
			if km >= km0:
				for it: Dictionary in s.sprites:
					var key := str(it.get("set", ""))
					if want.has(key):
						print("  km %7.2f  %-26s side %2d  x %6.1f  offset %s  scale %.2f  %s" % [km, key, int(it.get("side", 0)),
							float(it.get("x", 0.0)), str(it.get("offset", "-")), float(it.get("scale", 1.0)),
							"bridge" if it.has("bridge") else ""])
			t.update_window(s.z, 10.0)
	quit(0)
