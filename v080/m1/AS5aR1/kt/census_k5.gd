extends SceneTree
## KRITIK-5a1 scratch tool: where the city sets stand on given stage directions, binned per 0.25 km.
##   godot --headless --path . -s res://tools/kritik/census_k5.gd -- --dirs=kiel_hamburg__kiel,...

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var only: Array = str(args.get("dirs", "")).split(",", false)
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, []):
		if not only.has(str(dir["name"])):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var n := t.segment_index_at(t.km_to_z(plan.length_km)) - 1
		var bins := {}
		for i in range(0, n):
			var s := t.get_segment(i)
			for it: Dictionary in s.sprites:
				if str(it.get("kind", "prop")) != "prop":
					continue
				var key := str(it.get("set", ""))
				if not key.begins_with("props/city_"):
					continue
				var km := t.z_to_km(s.z)
				var b := int(floor(km * 4.0))
				var d: Dictionary = bins.get(b, {})
				var short := key.substr(11)
				var side := "L" if int(it.get("side", 1)) < 0 else "R"
				var tag := "%s%s@%.1f*%.2f%s" % [short, side, absf(float(it.get("x", 0.0))), float(it.get("scale", 1.0)),
					("#" + str(it["tint"])) if it.has("tint") else ""]
				var arr: Array = d.get("items", [])
				arr.append(tag)
				d["items"] = arr
				bins[b] = d
			t.update_window(s.z, 10.0)
		print("==== ", dir["name"], " length ", plan.length_km)
		var keys := bins.keys()
		keys.sort()
		for b: int in keys:
			var arr: Array = (bins[b] as Dictionary)["items"]
			print("  km %6.2f  n=%2d  %s" % [b / 4.0, arr.size(), " ".join(arr.slice(0, 8))])
	quit(0)
