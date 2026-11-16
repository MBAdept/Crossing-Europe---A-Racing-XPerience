extends SceneTree
## Which race routes contain the stage erfurt_kassel, and in which direction.

func _initialize() -> void:
	var net: Variant = ConfigLoader.load_json("res://data/network.json")
	var c: Variant = ConfigLoader.load_json("res://data/countries.json")
	var rn := RoadNetwork.new()
	rn.setup(net, c.get("countries", {}), ConfigLoader.load_merged(), {})
	for rid: String in rn.race_order:
		var routes := rn.race_routes(rid)
		var n := 0
		for r: Dictionary in routes:
			for l: Dictionary in r["legs"]:
				if str(l["id"]) == "erfurt_kassel":
					n += 1
					print("RACE %s route %s : leg %s -> %s (%.0f km)  route km %.0f" % [rid, " ".join(r["cities"]), l["from"], l["to"], float(l["length_km"]), float(r["km"])])
		print("RACE %s: %d routes, %d with erfurt_kassel" % [rid, routes.size(), n])
	quit()
