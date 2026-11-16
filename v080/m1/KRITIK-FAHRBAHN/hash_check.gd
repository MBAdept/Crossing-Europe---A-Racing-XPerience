extends SceneTree
## KRITIK-FAHRBAHN: AudioFeed.unit_hash in the engine – the cobble decision per city block and the concrete decision
## per autobahn section of every stage (effective share against the configured one).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	print("HASH djb2 check: ", "hamburg|0".hash(), " ", "hamburg|1".hash())
	var gd: Node = root.get_node("GameData")
	var feedcfg: Dictionary = ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.modern.feed", {})
	var styles: Array = feedcfg.get("cobble_styles", [])
	var share := float(feedcfg.get("cobble_share", 0.6))
	var cshare: Dictionary = feedcfg.get("concrete_share", {})
	var ids: Array = gd.call("visible_stage_ids")
	var conc_km := {}
	var all_km := {}
	for id: String in ids:
		var plan: Object = gd.call("get_stage_plan", id, "")
		if plan == null:
			continue
		# cobbles: the destination city of this direction
		var to_id := str(plan.get("to_id"))
		var style := str(plan.get("city_style"))
		var n := 0
		var yes := 0
		var vals: Array = []
		for b in 12:
			var u := AudioFeed.unit_hash("%s|%d" % [to_id, b])
			vals.append(snappedf(u, 0.001))
			n += 1
			yes += 1 if u < share else 0
		print("COBBLE ", JSON.stringify({"stage": id, "to": to_id, "style": style, "style_cobbled": styles.has(style),
			"blocks_cobbled": yes, "of": n, "u": vals}))
		for s: Dictionary in plan.get("sections"):
			if str(s.get("road", "")) != "autobahn":
				continue
			var country := str(s.get("country", ""))
			var key := "%s|%s|%.3f|%s|%s" % [str(plan.get("stage_id")), str(s.get("name", "")), float(s.get("length_km", 0.0)),
				country, str(s.get("scenery", ""))]
			var c := AudioFeed.unit_hash(key) < float(cshare.get(country, cshare.get("_", 0.0)))
			all_km[country] = float(all_km.get(country, 0.0)) + float(s.get("length_km", 0.0))
			if c:
				conc_km[country] = float(conc_km.get(country, 0.0)) + float(s.get("length_km", 0.0))
	for c: String in all_km:
		print("CONCRETE ", JSON.stringify({"country": c, "km": all_km[c], "concrete_km": conc_km.get(c, 0.0),
			"share": float(conc_km.get(c, 0.0)) / maxf(float(all_km[c]), 0.001), "configured": cshare.get(c, cshare.get("_", 0.0))}))
	quit(0)
