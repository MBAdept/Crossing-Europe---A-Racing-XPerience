extends SceneTree
## KRITIK-R (R2): the effective concrete and cobble shares the feed itself decides, over every visible stage in both
## directions. The feed of the tree (AudioFeed with the tree's configuration) is asked directly – _concrete_section()
## and _cobbled() as _paving() uses them – along each stage every 50 m (concrete: autobahn outside the City Limits,
## not in tunnels, not on steel/stone decks) and every 5 m of the city centre (cobbles). No own hash.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade
## Output: "CONC {...}" per stage direction and country, "COBB {...}" per stage direction, "PAIR {...}" both
## directions equal.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var modern: Dictionary = ConfigLoader.lookup(cfg, "audio.modern", {})
	var feedcfg: Dictionary = modern.get("feed", {})
	var roads: Array = feedcfg.get("concrete_roads", ["autobahn"])
	# time scale of the track (visible metres) from one real Track
	var p0: Object = gd.call("get_stage_plan", "kiel_hamburg", "kiel")
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var t0 := Track.new()
	t0.setup(p0, cfg, (sc as Dictionary).get("scenery", {}))
	var ts := float(t0.get("time_scale"))
	print("TIMESCALE ", ts)
	var mismatch := 0
	for id: String in gd.call("visible_stage_ids"):
		var st: Dictionary = gd.call("get_stage", id)
		var dirs := {}
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: Object = gd.call("get_stage_plan", id, from)
			if plan == null:
				continue
			var f := AudioFeed.new()
			f.setup(modern)
			f.plan = plan
			f.set("_time_scale", ts)
			var length := float(plan.get("length_km"))
			# concrete per country: autobahn, outside the City Limits, not in a tunnel, not on a steel or stone deck
			var by_c := {}
			var sig := []
			var km := 0.025
			while km < length:
				var road := str(plan.call("road_at", km))
				if roads.has(road) and not bool(plan.call("is_city", km)) and not bool(plan.call("in_tunnel", km)):
					var br: Dictionary = plan.call("bridge_at", km)
					var dk := AudioFeed.deck_of(str(br.get("type", ""))) if not br.is_empty() else ""
					if dk != "steel" and dk != "stone":
						var c := str(plan.call("country_at", km))
						var row: Array = by_c.get(c, [0, 0])
						row[0] = int(row[0]) + 1
						var yes: bool = f.call("_concrete_section", km)
						if yes:
							row[1] = int(row[1]) + 1
						by_c[c] = row
						sig.append(1 if yes else 0)
				km += 0.05
			for c: String in by_c:
				print("CONC ", JSON.stringify({"stage": id, "from": from, "country": c, "km": snappedf(by_c[c][0] * 0.05, 0.01),
					"concrete_km": snappedf(by_c[c][1] * 0.05, 0.01)}))
			# cobbles in the centre of the destination
			var style := str(plan.get("city_style"))
			var centre := float(plan.get("city_center_km"))
			var n := 0
			var yes_n := 0
			var pattern := ""
			var last := -1
			var k2 := centre + 0.0025
			while k2 < length:
				if bool(plan.call("in_city_center", k2)):
					n += 1
					var cb: bool = f.call("_cobbled", k2)
					yes_n += 1 if cb else 0
					var b := int(floor((length - k2) * 1000.0 / ts / float(f.get("cobble_block_m"))))
					if b != last:
						pattern = ("P" if cb else "-") + pattern
						last = b
				k2 += 0.005
			print("COBB ", JSON.stringify({"stage": id, "from": from, "to": plan.get("to_id"), "style": style,
				"cobble_style": (f.get("cobble_styles") as Array).has(style), "centre_km": snappedf(length - centre, 0.001),
				"samples": n, "share": snappedf(float(yes_n) / maxf(float(n), 1.0), 0.0001), "blocks_from_centre_to_finish": pattern}))
			# both directions: the same sections must get the same decision (reverse order)
			dirs[from] = sig
		if dirs.size() == 2:
			var a: Array = dirs.values()[0]
			var b2: Array = dirs.values()[1]
			var same := a.size() == b2.size()
			if same:
				var rb := b2.duplicate()
				rb.reverse()
				var diff := 0
				for i in a.size():
					diff += 1 if a[i] != rb[i] else 0
				same = diff <= 4
				if not same:
					mismatch += 1
				print("PAIR ", JSON.stringify({"stage": id, "samples": a.size(), "diff": diff}))
	print("DONE mismatch=", mismatch)
	quit(0)
