extends SceneTree
## AU-R: proof of the mixed hash (R2). For every visible stage in both directions: the concrete decision of every
## autobahn section (km-weighted per country) and the cobble decision of every block of the destination's city centre
## (length-weighted per city), with the hash before AU-R (djb2, low 24 bits) and the new one (AudioFeed.unit_hash).
## Output: "SEC {...}", "CITY {...}", "COUNTRY {...}", "TOTAL {...}" lines; "KH {...}" for Kiel – Hamburg.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade

func _initialize() -> void:
	_run.call_deferred()


static func old_hash(key: String) -> float:
	return float(key.hash() & 0xFFFFFF) / float(0x1000000)


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var feedcfg: Dictionary = ConfigLoader.lookup(cfg, "audio.modern.feed", {})
	var styles: Array = feedcfg.get("cobble_styles", [])
	var share := float(feedcfg.get("cobble_share", 0.6))
	var block_m := float(feedcfg.get("cobble_block_m", 90.0))
	var cshare: Dictionary = feedcfg.get("concrete_share", {})
	var roads: Array = feedcfg.get("concrete_roads", ["autobahn"])
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 10.0))
	var ids: Array = gd.call("visible_stage_ids")
	var seen_sec := {}
	var seen_city := {}
	var country := {}      # c -> [km, km_old, km_new, n_sections]
	var cities := {}       # to_id -> {blocks, old, new, style}
	for id: String in ids:
		var st: Dictionary = gd.call("get_stage", id)
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: Object = gd.call("get_stage_plan", id, from)
			if plan == null:
				continue
			for s: Dictionary in plan.get("sections"):
				if not roads.has(str(s.get("road", ""))):
					continue
				var c := str(s.get("country", ""))
				var key := "%s|%s|%.3f|%s|%s" % [str(plan.get("stage_id")), str(s.get("name", "")), float(s.get("length_km", 0.0)),
					c, str(s.get("scenery", ""))]
				if seen_sec.has(key):
					continue      # the same section in the other direction (same key: same decision)
				seen_sec[key] = true
				var p := float(cshare.get(c, cshare.get("_", 0.0)))
				var km := float(s.get("length_km", 0.0))
				var o := old_hash(key) < p
				var n := AudioFeed.unit_hash(key) < p
				var row: Array = country.get(c, [0.0, 0.0, 0.0, 0, p])
				row[0] = float(row[0]) + km
				row[1] = float(row[1]) + (km if o else 0.0)
				row[2] = float(row[2]) + (km if n else 0.0)
				row[3] = int(row[3]) + 1
				country[c] = row
				if id == "kiel_hamburg" and from == "kiel":
					print("KH ", JSON.stringify({"section": s.get("name", ""), "start_km": s.get("start_km"), "end_km": s.get("end_km"),
						"old": o, "new": n}))
			# the destination's city centre
			var to_id := str(plan.get("to_id"))
			var style := str(plan.get("city_style"))
			if seen_city.has(to_id) or not styles.has(style):
				continue
			seen_city[to_id] = true
			var length := float(plan.get("length_km"))
			var center := float(plan.get("city_center_km"))
			var len_m := maxf(length - center, 0.0) * 1000.0 / ts
			var nb := int(ceil(len_m / block_m))
			var w_all := 0.0
			var w_old := 0.0
			var w_new := 0.0
			var pattern_old := ""
			var pattern_new := ""
			for b in nb:
				var w := minf(block_m, len_m - b * block_m)
				var k := "%s|%d" % [to_id, b]
				var o2 := old_hash(k) < share
				var n2 := AudioFeed.unit_hash(k) < share
				w_all += w
				w_old += w if o2 else 0.0
				w_new += w if n2 else 0.0
				pattern_old += "P" if o2 else "-"
				pattern_new += "P" if n2 else "-"
			cities[to_id] = {"style": style, "blocks": nb, "m": snappedf(len_m, 0.1), "old": snappedf(w_old / maxf(w_all, 1.0), 0.001),
				"new": snappedf(w_new / maxf(w_all, 1.0), 0.001), "old_pattern": pattern_old, "new_pattern": pattern_new,
				"w": w_all, "w_old": w_old, "w_new": w_new}
	var t := {"km": 0.0, "old": 0.0, "new": 0.0, "target": 0.0}
	for c: String in country:
		var row: Array = country[c]
		var km := float(row[0])
		print("COUNTRY ", JSON.stringify({"country": c, "sections": row[3], "km": km, "configured": row[4],
			"old": snappedf(float(row[1]) / maxf(km, 0.001), 0.001), "new": snappedf(float(row[2]) / maxf(km, 0.001), 0.001)}))
		t["km"] = float(t["km"]) + km
		t["old"] = float(t["old"]) + float(row[1])
		t["new"] = float(t["new"]) + float(row[2])
		t["target"] = float(t["target"]) + km * float(row[4])
	var cw := 0.0
	var co := 0.0
	var cn := 0.0
	var all_o := 0
	var none_o := 0
	var all_n := 0
	var none_n := 0
	for k: String in cities:
		var c2: Dictionary = cities[k]
		print("CITY ", JSON.stringify({"city": k, "style": c2["style"], "blocks": c2["blocks"], "m": c2["m"], "old": c2["old"],
			"new": c2["new"], "old_pattern": c2["old_pattern"], "new_pattern": c2["new_pattern"]}))
		cw += float(c2["w"])
		co += float(c2["w_old"])
		cn += float(c2["w_new"])
		all_o += 1 if float(c2["old"]) >= 0.999 else 0
		none_o += 1 if float(c2["old"]) <= 0.001 else 0
		all_n += 1 if float(c2["new"]) >= 0.999 else 0
		none_n += 1 if float(c2["new"]) <= 0.001 else 0
	print("TOTAL ", JSON.stringify({"concrete_km": t["km"], "concrete_target": snappedf(float(t["target"]) / maxf(float(t["km"]), 0.001), 0.001),
		"concrete_old": snappedf(float(t["old"]) / maxf(float(t["km"]), 0.001), 0.001),
		"concrete_new": snappedf(float(t["new"]) / maxf(float(t["km"]), 0.001), 0.001),
		"cities": cities.size(), "cobble_target": share, "cobble_old": snappedf(co / maxf(cw, 1.0), 0.001),
		"cobble_new": snappedf(cn / maxf(cw, 1.0), 0.001), "cities_all_old": all_o, "cities_none_old": none_o,
		"cities_all_new": all_n, "cities_none_new": none_n}))
	quit(0)
