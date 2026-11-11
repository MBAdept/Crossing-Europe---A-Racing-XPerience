extends SceneTree
## AU-R: per-country hash thresholds for the concrete sections (audio.modern.feed.concrete_threshold).
##
## The feed decides each autobahn section once from a hash of what identifies it (AudioFeed._concrete_section). A
## section is concrete when its hash is below its country's threshold; with the share itself as the threshold the
## country hits its share only on average over many sections – Austria with 15 sections got none at 0.15, Germany
## 0.27 at 0.35 (measured over all stages). This tool goes over every visible stage once (the same key in both
## directions), sorts each country's sections by hash and takes the threshold between the two hashes where the
## concrete kilometres come nearest to concrete_share × the country's kilometres. Prints the thresholds as one JSON
## line to paste into the configuration, and the share each country gets with them.
##   godot --headless --path . -s res://tools/audio/modern/calibrate_concrete.gd -- --graphics=arcade
## Run it again when stages are added or sections renamed: a stale threshold only moves a country's share a little.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var feedcfg: Dictionary = ConfigLoader.lookup(cfg, "audio.modern.feed", {})
	var cshare: Dictionary = feedcfg.get("concrete_share", {})
	var roads: Array = feedcfg.get("concrete_roads", ["autobahn"])
	var seen := {}
	var rows := {}         # country -> [[hash, km], …]
	for id: String in gd.call("visible_stage_ids"):
		var st: Dictionary = gd.call("get_stage", id)
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: Object = gd.call("get_stage_plan", id, from)
			if plan == null:
				continue
			for s: Dictionary in plan.get("sections"):
				if not roads.has(str(s.get("road", ""))):
					continue
				var c := str(s.get("country", ""))
				var key := AudioFeed.section_key(str(plan.get("stage_id")), s)
				if seen.has(key):
					continue
				seen[key] = true
				var list: Array = rows.get(c, [])
				list.append([AudioFeed.unit_hash(key), float(s.get("length_km", 0.0))])
				rows[c] = list
	var out := {}
	var countries: Array = rows.keys()
	countries.sort()
	for c: String in countries:
		var list: Array = rows[c]
		list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var total := 0.0
		for r: Array in list:
			total += float(r[1])
		var share := float(cshare.get(c, cshare.get("_", 0.0)))
		var target := share * total
		var best_k := 0
		var best_d := absf(target)
		var acc := 0.0
		for k in list.size():
			acc += float(list[k][1])
			if absf(acc - target) < best_d:
				best_d = absf(acc - target)
				best_k = k + 1
		var lo := float(list[best_k - 1][0]) if best_k > 0 else 0.0
		var hi := float(list[best_k][0]) if best_k < list.size() else 1.0
		var thr := snappedf((lo + hi) * 0.5, 0.000001)
		out[c] = [share, thr]        # valid for this share only (AudioFeed.concrete_threshold_for)
		var got := 0.0
		for k in best_k:
			got += float(list[k][1])
		var plain := 0.0
		for r: Array in list:
			plain += float(r[1]) if float(r[0]) < share else 0.0
		print("LAND %s Abschnitte %d, %.0f km, Soll %.2f -> %.3f (ohne Schwelle %.3f; Schwelle %.6f)" % [c, list.size(),
			total, share, got / maxf(total, 0.001), plain / maxf(total, 0.001), thr])
	print("concrete_threshold ", JSON.stringify(out))
	quit(0)
