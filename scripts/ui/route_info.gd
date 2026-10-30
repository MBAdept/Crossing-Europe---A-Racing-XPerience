class_name RouteInfo
extends RefCounted
## Route options of the route choice as whole routes: an option of GameData.next_options() is the
## next leg plus the (shortest) continuation to the next mandatory target. The totals over all those
## legs make the design's trade-off visible at the decision point ("Route über Kassel" vs "über
## Frankfurt": length, stages, autobahn, km without limit, radars, fuel stations, tunnels, traffic,
## countries) – the first stage alone often points the wrong way.
## Pure functions (routes, links and stage summaries are passed in) – unit tested.

## Keys a data-module summary of the whole option may use (has-key checks, see apply_data_summary).
const SUMMARY_KEYS: Array[String] = ["autobahn_km", "unlimited_km", "radars", "stations", "tunnels", "traffic", "countries", "stages", "ferries"]


## Legs after `option` up to its target, in driving order. Sources, first match wins:
##  1. option["continuation"] (legs, added by the data module),
##  2. the shortest continuation among the complete race routes (`routes`: Array of leg arrays, e.g.
##     GameData.race_routes) that start with the driven cities `driven` (race.route) + this option,
##  3. option["via"] (city ids after the leg up to the target) with the legs found by
##     link_fn.call(from_id, to_id) -> leg Dictionary ({} if there is no direct connection).
## Returns [] when the option ends at the target or nothing is known.
static func continuation(option: Dictionary, target: String, driven: Array = [], routes: Array = [], link_fn: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var to := str(option.get("to", ""))
	if to == "" or to == target:
		return out
	var given: Variant = option.get("continuation", null)
	if given is Array:
		for l in given:
			if l is Dictionary:
				out.append(l)
		return out
	out = _from_routes(option, target, driven, routes)
	if not out.is_empty():
		return out
	var via: Variant = option.get("via", null)
	if via is Array and link_fn.is_valid():
		var cur := to
		for c in via:
			var nxt := str(c)
			var leg: Variant = link_fn.call(cur, nxt)
			if not leg is Dictionary or (leg as Dictionary).is_empty():
				return [] as Array[Dictionary]
			out.append(leg)
			cur = nxt
			if nxt == target:
				break
	return out


## Shortest continuation of `option` in complete routes whose city sequence starts with driven + [to].
static func _from_routes(option: Dictionary, target: String, driven: Array, routes: Array) -> Array[Dictionary]:
	var best: Array[Dictionary] = []
	var best_km := INF
	if driven.is_empty():
		return best
	var n := driven.size() - 1          # legs already driven
	for r in routes:
		if not r is Array or (r as Array).size() <= n:
			continue
		var legs: Array = r
		var ok := str((legs[0] as Dictionary).get("from", "")) == str(driven[0])
		for k in n:
			if not ok:
				break
			ok = str((legs[k] as Dictionary).get("to", "")) == str(driven[k + 1])
		var first: Dictionary = legs[n]
		if not ok or str(first.get("to", "")) != str(option.get("to", "")) or str(first.get("id", "")) != str(option.get("id", first.get("id", ""))):
			continue
		var cont: Array[Dictionary] = []
		var km := 0.0
		var reached := false
		for k in range(n + 1, legs.size()):
			var l: Dictionary = legs[k]
			cont.append(l)
			km += float(l.get("length_km", 0.0))
			if str(l.get("to", "")) == target:
				reached = true
				break
		if reached and km < best_km:
			best_km = km
			best = cont
	return best


## Totals over legs (the option first). summary_fn.call(leg) -> StagePlan.summary()-like Dictionary
## for a stage leg ({} if unknown; ferries are counted, not summed). Returns {km, stages, ferries,
## autobahn_km, unlimited_km, radars, stations, tunnels, traffic (length-weighted), countries (in order)}.
static func totals(legs: Array, summary_fn: Callable) -> Dictionary:
	var t := {"km": 0.0, "stages": 0, "ferries": 0, "autobahn_km": 0.0, "unlimited_km": 0.0, "radars": 0,
		"stations": 0, "tunnels": 0, "traffic": 1.0, "countries": []}
	var traffic_w := 0.0
	var traffic_km := 0.0
	var countries: Array[String] = []
	for l in legs:
		if not l is Dictionary:
			continue
		var leg: Dictionary = l
		if str(leg.get("kind", "stage")) == "ferry":
			t["ferries"] = int(t["ferries"]) + 1
			continue
		t["stages"] = int(t["stages"]) + 1
		var s: Variant = summary_fn.call(leg) if summary_fn.is_valid() else {}
		var sm: Dictionary = s if s is Dictionary else {}
		var km := float(sm.get("length_km", leg.get("length_km", 0.0)))
		t["km"] = float(t["km"]) + km
		t["autobahn_km"] = float(t["autobahn_km"]) + float(sm.get("autobahn_km", 0.0))
		t["unlimited_km"] = float(t["unlimited_km"]) + float(sm.get("unlimited_km", 0.0))
		t["radars"] = int(t["radars"]) + int(sm.get("radars", 0))
		t["stations"] = int(t["stations"]) + int(sm.get("stations", 0))
		t["tunnels"] = int(t["tunnels"]) + int(sm.get("tunnels", 0))
		if sm.has("traffic"):
			traffic_w += km * float(sm["traffic"])
			traffic_km += km
		for c in sm.get("countries", []):
			if not countries.has(str(c)):
				countries.append(str(c))
	if traffic_km > 0.0:
		t["traffic"] = traffic_w / traffic_km
	t["countries"] = countries
	return t


## Lets figures computed by the data module win: option["route_km"] (km to the target) and a summary
## Dictionary under option["route_summary"] or option["summary"] (keys of SUMMARY_KEYS, each checked).
static func apply_data_summary(t: Dictionary, option: Dictionary) -> Dictionary:
	if option.has("route_km"):
		t["km"] = float(option["route_km"])
	for key in ["route_summary", "summary"]:
		var s: Variant = option.get(key, null)
		if not s is Dictionary:
			continue
		for k in SUMMARY_KEYS:
			if (s as Dictionary).has(k):
				t[k] = s[k]
		if (s as Dictionary).has("km") and not option.has("route_km"):
			t["km"] = float(s["km"])
		break
	return t


## Cities the route passes before the target: the option's destination and every intermediate stop.
static func via_cities(option: Dictionary, cont: Array, target: String) -> Array[String]:
	var out: Array[String] = []
	var to := str(option.get("to", ""))
	if to != "" and to != target:
		out.append(to)
	for l in cont:
		var c := str((l as Dictionary).get("to", ""))
		if c != target and c != "" and not out.has(c):
			out.append(c)
	return out
