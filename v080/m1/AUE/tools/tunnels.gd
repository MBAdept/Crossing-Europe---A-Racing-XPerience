extends SceneTree
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	await process_frame
	var net: Variant = ConfigLoader.load_json("res://data/network.json")
	var rows: Array = []
	for st: Dictionary in (net as Dictionary)["stages"]:
		for from: String in [str(st["from"]), str(st["to"])]:
			var plan: StagePlan = root.get_node("GameData").call("get_stage_plan", str(st["id"]), from)
			if plan == null:
				continue
			for t in plan.tunnels:
				rows.append([float(t["end_km"]) - float(t["start_km"]), str(st["id"]), from, JSON.stringify(t)])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 12):
		print("TUN ", r)
	quit(0)
