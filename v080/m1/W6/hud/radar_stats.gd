extends SceneTree
func _init() -> void:
	var cfg := ConfigLoader.load_merged()
	var n := RoadNetwork.new()
	var countries: Variant = ConfigLoader.load_json("res://data/countries.json")
	n.setup(ConfigLoader.load_json("res://data/network.json"), countries.get("countries", {}), cfg, ConfigLoader.load_json("res://data/map/europe_map.json"))
	var hist := {}
	var at_start := 0
	var total := 0
	for id in n.stage_order:
		var s: Dictionary = n.stages[id]
		if bool(s.get("dev", false)):
			continue
		for from_id in [str(s["from"]), str(s["to"])]:
			var p := n.get_stage_plan(id, from_id)
			var line := ""
			for r in p.radars:
				var d := float(r["km"]) - float(r["warn_km"])
				total += 1
				if float(r["warn_km"]) <= 0.0001:
					at_start += 1
					line += " [Start:%.1f]" % d
				else:
					hist[int(d)] = int(hist.get(int(d), 0)) + 1
					line += " %d" % int(d)
			if id == "kiel_hamburg":
				print("kiel_hamburg ab ", from_id, ":", line)
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		print("%2d km: %d" % [k, hist[k]])
	print("am Start: ", at_start, " von ", total)
	quit()
