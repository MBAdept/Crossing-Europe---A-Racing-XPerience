extends SceneTree
## Scratch tool (AS1b): which sprite sets does the Track of a stage really emit in the first N km?
##   godot --headless --path . -s <this file> -- --stage=kiel_hamburg --km=75 [--from=kiel]

const Fair := preload("res://tests/race3d/fairness.gd")


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var stage_id := _arg("stage", "kiel_hamburg")
	var km := float(_arg("km", "75"))
	var start_km := float(_arg("start", "0"))
	var list_set := _arg("list", "")
	var from := _arg("from", "")
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if from != "" and str(dir["from"]) != from:
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var zmax := t.km_to_z(km)
		var counts := {}
		var objs := {}
		var first_km := {}
		var sides := {}
		var scales := {}
		var n := t.segment_index_at(zmax)
		for i in range(0, n + 1):
			var s := t.get_segment(i)
			if t.z_to_km(s.z) < start_km:
				t.update_window(s.z, 10.0)
				continue
			for it: Dictionary in s.sprites:
				var kind := str(it.get("kind", "prop"))
				var key := ""
				if kind == "prop":
					key = str(it.get("set", ""))
				elif kind == "object":
					key = "object:" + str(it.get("obj", ""))
				else:
					continue
				counts[key] = int(counts.get(key, 0)) + 1
				if list_set != "" and (list_set == "all" or list_set.split(",").has(key)):
					print("  LISTE %s km %.2f x %.1f side %s" % [key, t.z_to_km(s.z), float(it.get("x", 0.0)), str(it.get("side", 0))])
				if not first_km.has(key):
					first_km[key] = snappedf(t.z_to_km(s.z), 0.1)
				var sd := str(int(it.get("side", 0)))
				var sk: Dictionary = sides.get(key, {})
				sk[sd] = int(sk.get(sd, 0)) + 1
				sides[key] = sk
				var sc := float(it.get("scale", 1.0))
				var r: Array = scales.get(key, [INF, -INF])
				scales[key] = [minf(r[0], sc), maxf(r[1], sc)]
			t.update_window(s.z, 10.0)
		print("STAGE %s from %s: length %.1f km, %d segments in the first %.0f km" % [stage_id, str(dir["from"]), plan.length_km, n + 1, km])
		var keys := counts.keys()
		keys.sort()
		for k: String in keys:
			print("  %-34s %6d  first at km %6.1f  sides %s  scale %.2f..%.2f" % [k, int(counts[k]), float(first_km[k]), str(sides[k]), scales[k][0], scales[k][1]])
		var all := t.sprite_sets()
		print("  sprite_sets(): ", ", ".join(all))
		print("  fallbacks: ", t.sprite_fallbacks())
		var secs: Array = []
		for sec: Dictionary in plan.sections:
			secs.append("%s@%.1f" % [str(sec.get("scenery", "")), float(sec.get("start_km", 0.0))])
		print("  sections: ", ", ".join(secs))
	quit(0)
