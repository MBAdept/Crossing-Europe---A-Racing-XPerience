extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var plan: StagePlan = root.get_node("GameData").call("get_stage_plan", "kiel_hamburg", "kiel")
	print("Länge %.1f, City Limits %.1f, Zentrum %.1f, Stil %s, Szenerie %s / %s" % [plan.length_km, plan.city_limits_km, plan.city_center_km, plan.city_style, plan.city_scenery_outskirts, plan.city_scenery_center])
	for s in plan.sections:
		print("Abschnitt %.1f–%.1f %s %s %s" % [float(s["start_km"]), float(s["end_km"]), str(s.get("name","")), str(s.get("scenery","")), str(s.get("road",""))])
	print("Tankstellen ", plan.fuel_stations_km)
	for t in plan.tunnels: print("Tunnel ", t)
	for b in plan.bridges: print("Brücke ", JSON.stringify(b).left(200))
	quit(0)
