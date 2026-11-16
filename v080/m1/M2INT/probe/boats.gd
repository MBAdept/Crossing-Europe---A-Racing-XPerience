extends SceneTree
## Lists every ship / houseboat item the Track places on some stage directions, with the water flag of its segment
## and the water flags of the segments its hull covers (z +- 25 m). godot --headless --path <wt> -s <this> [-- names]

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		only.append(a)
	var total := 0
	var dry := 0
	for d: Dictionary in Fair.directions(net):
		var name := str(d["name"])
		if not only.is_empty() and not only.has(name) and not only.has(str(d["stage"].get("id", ""))):
			continue
		var verbose := not only.is_empty()
		var plan := StagePlan.build(d["stage"], str(d["from"]), net["cities"], net["countries"], cfg, net.get("city_db", {}))
		var track := Track.new()
		track.setup(plan, cfg, {})
		var n := track.segment_count
		for i in n:
			var s := track.get_segment(i)
			for it: Dictionary in s.sprites:
				var sid := str(it.get("set", ""))
				if sid != "props/ferry_ship" and sid != "props/houseboat":
					continue
				var z := float(it.get("z", float(i) * track.seg_len))
				var k0 := clampi(int(floor((z - 25.0) / track.seg_len)), 0, n - 1)
				var k1 := clampi(int(floor((z + 25.0) / track.seg_len)), 0, n - 1)
				var wet := 0
				for k in range(k0, k1 + 1):
					if track.get_segment(k).water:
						wet += 1
				total += 1
				if not s.water:
					dry += 1
				if verbose or not s.water:
					print("%s z %.0f m %s side %d x %.1f h %.1f water %s bridge %d hull %d/%d" % [name, z,
						sid, int(it.get("side", 0)), float(it.get("x", 0.0)), float(it.get("h", 0.0)), str(s.water), s.bridge_i, wet, k1 - k0 + 1])
	print("BOATS total %d, on a segment without water %d" % [total, dry])
	quit(0)
