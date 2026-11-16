extends SceneTree
## AU-R4: the cobble allocation of every old town at every arrival (all visible stages, both directions), computed
## from the plans in exact metres (no driving): AU-R3 (old copy below) against the tree's AudioFeed.cobbled_blocks.
## Prints one ROW per arrival and a SUMMARY. Shares:
##   heard  = (cobbled street + stone bridges) / (street + stone bridges)   street = centre − bridges − tunnels
##   street = cobbled street / street
##   godot --headless --path <tree> -s <this> -- --graphics=arcade


func _initialize() -> void:
	_run.call_deferred()


## AU-R3's cobbled_blocks (b6339ad), verbatim but for the name.
static func old_blocks(city: String, centre_m: float, block_m: float, share: float, skip: Array = []) -> Dictionary:
	var out := {}
	if centre_m <= 0.0 or block_m <= 0.0:
		return out
	var n := maxi(int(ceil(centre_m / block_m - 1.0e-6)), 1)
	var gaps := AudioFeed._merged_stretches(skip)
	var order: Array = []
	var street: Array[float] = []
	var cut_all := 0.0
	for b in n:
		order.append([AudioFeed.unit_hash("%s|%d" % [city, b]), b])
		out[b] = false
		var w := minf(block_m, centre_m - b * block_m)
		var cut := 0.0
		for g: Array in gaps:
			cut += maxf(minf(b * block_m + w, float(g[1])) - maxf(b * block_m, float(g[0])), 0.0)
		if cut > 0.0:
			cut = minf(cut, w)
			cut_all += cut
			w = w - cut if w - cut > 1.0e-6 else 0.0
		street.append(w)
	order.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var target := clampf(share, 0.0, 1.0) * (centre_m - cut_all)
	var got := 0.0
	for row: Array in order:
		var b := int(row[1])
		var w := street[b]
		if absf(got + w - target) < absf(got - target):
			got += w
			out[b] = true
	if cut_all > 0.0:
		AudioFeed._closer(out, street, order, got, target, AudioFeed.COBBLE_BAND * (centre_m - cut_all))
	return out


## Metres of [a0, a1] inside the merged stretches.
static func _inside(a0: float, a1: float, spans: Array) -> float:
	var m := 0.0
	for s: Array in spans:
		m += maxf(minf(a1, float(s[1])) - maxf(a0, float(s[0])), 0.0)
	return m


## {street, stone, gaps, cob_street} of an allocation, exact.
static func shares(alloc: Dictionary, centre_m: float, block_m: float, gaps: Array, stones: Array) -> Dictionary:
	var g := AudioFeed._merged_stretches(gaps)
	var st := AudioFeed._merged_stretches(stones)
	var street := 0.0
	var stone := 0.0
	var cob := 0.0
	var gap := 0.0
	for b: int in alloc:
		var a0 := b * block_m
		var a1 := minf(a0 + block_m, centre_m)
		var gm := _inside(a0, a1, g)
		var sm := _inside(a0, a1, st)
		var w := (a1 - a0) - gm - sm
		gap += gm
		stone += sm
		street += w
		cob += w if bool(alloc[b]) else 0.0
	return {"street": street, "stone": stone, "gap": gap, "cob": cob,
		"heard": (cob + stone) / maxf(street + stone, 1.0e-9), "street_share": cob / maxf(street, 1.0e-9)}


## [[street m, stone m], …] per block.
static func block_metres(centre_m: float, block_m: float, gaps: Array, stones: Array) -> Array:
	var g := AudioFeed._merged_stretches(gaps)
	var out: Array = []
	var n := maxi(int(ceil(centre_m / block_m - 1.0e-6)), 1)
	for b in n:
		var a0 := b * block_m
		var a1 := minf(a0 + block_m, centre_m)
		var gm := _inside(a0, a1, g)
		var sm := _inside(a0, a1, AudioFeed._merged_stretches(stones + gaps)) - gm
		out.append([snappedf((a1 - a0) - gm - sm, 0.01), snappedf(sm, 0.01)])
	return out


static func pattern(alloc: Dictionary) -> String:
	var keys: Array = alloc.keys()
	keys.sort()
	var s := ""
	for k: int in keys:
		s += "P" if bool(alloc[k]) else "-"
	return s


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var feedcfg: Dictionary = ConfigLoader.lookup(cfg, "audio.modern.feed", {})
	var styles: Array = feedcfg.get("cobble_styles", [])
	var share := float(feedcfg.get("cobble_share", 0.6))
	var block := float(feedcfg.get("cobble_block_m", 90.0))
	var ts := float(ConfigLoader.lookup(cfg, "road.time_scale", 10.0))
	var by_city := {}
	var out_old := 0
	var out_new := 0
	var rows := 0
	for id: String in gd.call("visible_stage_ids"):
		var st: Dictionary = gd.call("get_stage", id)
		for from: String in [str(st.get("from", "")), str(st.get("to", ""))]:
			var plan: StagePlan = gd.call("get_stage_plan", id, from)
			if plan == null or not styles.has(plan.city_style):
				continue
			var centre_m := maxf(plan.length_km - plan.city_center_km, 0.0) * 1000.0 / ts
			var br := AudioFeed.bridge_stretches(plan, plan.length_km, ts)
			var stn := AudioFeed.stone_stretches(plan, plan.length_km, ts)
			var tun := AudioFeed.tunnel_stretches(plan, plan.length_km, ts)
			var old := old_blocks(plan.to_id, centre_m, block, share, br)
			var new := AudioFeed.cobbled_blocks(plan.to_id, centre_m, block, share, br, stn, tun)
			var city_only := AudioFeed.cobbled_blocks(plan.to_id, centre_m, block, share, br, stn)
			var so := shares(old, centre_m, block, br + tun, stn)
			var sn := shares(new, centre_m, block, br + tun, stn)
			var oo := absf(float(so["heard"]) - share) > AudioFeed.COBBLE_BAND + 1.0e-9
			var on := absf(float(sn["heard"]) - share) > AudioFeed.COBBLE_BAND + 1.0e-9
			out_old += 1 if oo else 0
			out_new += 1 if on else 0
			rows += 1
			var row := {"to": plan.to_id, "from": from, "centre_m": snappedf(centre_m, 0.1),
				"stone_m": snappedf(float(sn["stone"]), 0.1), "gap_m": snappedf(float(sn["gap"]), 0.1),
				"tunnel_m": snappedf(_inside(0.0, centre_m, AudioFeed._merged_stretches(tun)), 0.1),
				"old": pattern(old), "new": pattern(new), "city_pattern": pattern(city_only),
				"heard_old": snappedf(float(so["heard"]), 0.0001), "heard_new": snappedf(float(sn["heard"]), 0.0001),
				"street_old": snappedf(float(so["street_share"]), 0.0001), "street_new": snappedf(float(sn["street_share"]), 0.0001),
				"out_old": oo, "out_new": on, "blocks": block_metres(centre_m, block, br + tun, stn)}
			print("ROW ", JSON.stringify(row))
			var c: Array = by_city.get(plan.to_id, [])
			c.append(row)
			by_city[plan.to_id] = c
	var changed: Array = []
	var differ: Array = []
	for c: String in by_city:
		var pats := {}
		var any := false
		for r: Dictionary in by_city[c]:
			pats[r["new"]] = true
			any = any or r["new"] != r["old"]
		if any:
			changed.append(c)
		if pats.size() > 1:
			differ.append(c)
	print("SUMMARY ", JSON.stringify({"arrivals": rows, "cities": by_city.size(), "out_of_band_heard_old": out_old,
		"out_of_band_heard_new": out_new, "cities_changed": changed, "cities_with_differing_patterns": differ}))
	quit(0)
