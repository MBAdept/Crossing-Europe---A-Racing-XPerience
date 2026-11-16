extends SceneTree
## KRITIK-FAHRBAHN: lists every visible stage plan with bridges, tunnels, city style, countries, road classes.
## Output: one JSON line per stage ("STAGE {...}").

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var ids: Array = gd.call("visible_stage_ids")
	for id: String in ids:
		var st: Dictionary = gd.call("get_stage", id)
		var plan: Object = gd.call("get_stage_plan", id, "")
		if plan == null:
			continue
		var roads := {}
		var countries := {}
		for s: Dictionary in plan.get("sections"):
			var r := str(s.get("road", ""))
			roads[r] = float(roads.get(r, 0.0)) + float(s.get("length_km", 0.0))
			countries[str(s.get("country", ""))] = true
		var br: Array = []
		for b: Dictionary in plan.get("bridges"):
			br.append({"type": b.get("type", ""), "start_km": b.get("start_km", 0.0), "end_km": b.get("end_km", 0.0),
				"name": b.get("name", ""), "len_km": float(b.get("end_km", 0.0)) - float(b.get("start_km", 0.0))})
		var tu: Array = []
		for t: Dictionary in plan.get("tunnels"):
			tu.append({"start_km": t.get("start_km", 0.0), "end_km": t.get("end_km", 0.0), "name": t.get("name", "")})
		print("STAGE ", JSON.stringify({"id": id, "from": plan.get("from_id"), "to": plan.get("to_id"),
			"len_km": plan.get("length_km"), "city_style": plan.get("city_style"), "city_limits_km": plan.get("city_limits_km"),
			"city_center_km": plan.get("city_center_km"), "climate": plan.get("climate"),
			"countries": countries.keys(), "roads": roads, "bridges": br, "tunnels": tu,
			"borders": (plan.get("borders") as Array).size(), "fuel_lanes": (plan.get("fuel_lanes") as Array).size()}))
	quit(0)
