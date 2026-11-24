class_name UiData
extends RefCounted
## Data access for the menus with graceful fallbacks. Wraps the autoloads GameData, Leaderboards and
## SaveGame (owned by the data module; their stubs implement the documented API) and checks optional
## additions with has_method() (race_routes, race_summary).
##
## Debug sample mode (CLI --screen=...): when the real network is too sparse (stub data), a small
## synthetic network around Kiel – Nürnberg is used, and leaderboards come from generated entries kept
## in memory (nothing is written to user://). See SampleData.

static var sample := false
static var _net: Dictionary = {}           ## sample network (cities, stages, ferries, races, countries)
static var _boards: Dictionary = {}        ## sample leaderboards: key -> Array[Dictionary]
static var _route_cache: Dictionary = {}
static var _map_override: Dictionary = {}
static var _plan_cache: Dictionary = {}


static func _node(n: String) -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null(n)
	return null


static func cfg() -> Dictionary:
	return ConfigLoader.load_merged()


static func use_sample_network() -> bool:
	return sample and not _net.is_empty()


static func enable_sample(net: Dictionary) -> void:
	sample = true
	_net = net
	_route_cache.clear()
	_plan_cache.clear()


# --- network ---------------------------------------------------------------------------------

static func _gd_dict(prop: String) -> Dictionary:
	if use_sample_network():
		return _net.get(prop, {})
	var gd := _node("GameData")
	if gd == null:
		return {}
	var v: Variant = gd.get(prop)
	return v if v is Dictionary else {}


static func cities() -> Dictionary:
	return _gd_dict("cities")


static func stages() -> Dictionary:
	return _gd_dict("stages")


static func ferries() -> Dictionary:
	return _gd_dict("ferries")


static func races() -> Dictionary:
	return _gd_dict("races")


static func countries() -> Dictionary:
	if use_sample_network():
		var gd := _node("GameData")
		if gd != null:
			return gd.get("countries")
	return _gd_dict("countries")


## Map polygons (GameData.map_data). Debug: CLI --map-file=<path> loads another map file of the
## same format (ARCHITECTURE.md §4.5), e.g. to test the polygon rendering before the real map exists.
static func map_data() -> Dictionary:
	if CliArgs.has("map-file"):
		if _map_override.is_empty():
			var d: Variant = ConfigLoader.load_json(CliArgs.get_string("map-file"))
			_map_override = d if d is Dictionary else {"countries": []}
		return _map_override
	var gd := _node("GameData")
	if gd == null:
		return {}
	var v: Variant = gd.get("map_data")
	return v if v is Dictionary else {}


static func city_name(id: String) -> String:
	return str(cities().get(id, {}).get("name", id))


static func country_name(code: String) -> String:
	return str(countries().get(code, {}).get("name", code))


static func country_colors(code: String) -> Array:
	var v: Variant = countries().get(code, {}).get("colors", [])
	return v if v is Array else []


static func race(race_id: String) -> Dictionary:
	return races().get(race_id, {})


static func race_name(race_id: String) -> String:
	return str(race(race_id).get("name", race_id))


static func visible_race_ids() -> Array[String]:
	var out: Array[String] = []
	if use_sample_network():
		for id in _net.get("race_order", []):
			out.append(str(id))
		return out
	var gd := _node("GameData")
	if gd != null and gd.has_method("visible_race_ids"):
		for id in gd.call("visible_race_ids"):
			out.append(str(id))
	return out


static func visible_stage_ids() -> Array[String]:
	var out: Array[String] = []
	if use_sample_network():
		for id in stages():
			if not bool(stages()[id].get("dev", false)):
				out.append(str(id))
		out.sort()
		return out
	var gd := _node("GameData")
	if gd != null and gd.has_method("visible_stage_ids"):
		for id in gd.call("visible_stage_ids"):
			out.append(str(id))
	return out


## Stage resolved for a direction (StagePlan, cached per session) – null if unknown.
static func stage_plan(stage_id: String, from_city: String) -> StagePlan:
	var key := "%s|%s|%s" % [stage_id, from_city, use_sample_network()]
	if _plan_cache.has(key):
		return _plan_cache[key]
	var plan: StagePlan = null
	if use_sample_network():
		if stages().has(stage_id):
			plan = StagePlan.build(stages()[stage_id], from_city, cities(), countries(), cfg())
	else:
		var gd := _node("GameData")
		if gd != null and gd.get("stages").has(stage_id):
			plan = gd.call("get_stage_plan", stage_id, from_city)
	_plan_cache[key] = plan
	return plan


static func stage_board_key(stage_id: String, from_city: String) -> String:
	if not use_sample_network():
		var gd := _node("GameData")
		if gd != null:
			return str(gd.call("stage_board_key", stage_id, from_city))
	var s: Dictionary = stages().get(stage_id, {})
	return "stage:%s:%s" % [stage_id, "rev" if str(s.get("to", "")) == from_city else "fwd"]


static func race_board_key(race_id: String) -> String:
	var gd := _node("GameData")
	if gd != null and not use_sample_network():
		return str(gd.call("race_board_key", race_id))
	return "race:" + race_id


## The other end of a stage seen from `from_city`.
static func stage_other_end(stage_id: String, from_city: String) -> String:
	var s: Dictionary = stages().get(stage_id, {})
	var a := str(s.get("from", ""))
	var b := str(s.get("to", ""))
	return b if (from_city == a or from_city == "") else a


## Legal next legs of a race (GameData.next_options; sample mode: detour-limited routing).
static func next_options(race_id: String, current_city: String, waypoint_index: int, visited: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if use_sample_network():
		return _sample_next_options(race_id, current_city, waypoint_index, visited)
	var gd := _node("GameData")
	if gd == null:
		return out
	var res: Variant = gd.call("next_options", race_id, current_city, waypoint_index, visited)
	if res is Array:
		for leg in res:
			if leg is Dictionary:
				out.append(leg)
	return out


## Possible complete routes of a race (cached): GameData.race_routes() if available, else enumerated
## with next_options. Each route = Array of legs.
static func race_routes(race_id: String) -> Array:
	if _route_cache.has(race_id):
		return _route_cache[race_id]
	var routes: Array = []
	var gd := _node("GameData")
	if not use_sample_network() and gd != null and gd.has_method("race_routes"):
		var res: Variant = gd.call("race_routes", race_id)
		if res is Array:
			for r in res:
				if r is Array:
					routes.append(r)
				elif r is Dictionary and (r as Dictionary).get("legs", null) is Array:
					routes.append(r["legs"])
	if routes.is_empty():
		var opt_fn := func(rid: String, city: String, wp: int, visited: Array) -> Array:
			return next_options(rid, city, wp, visited)
		routes = RaceState.enumerate_routes(race(race_id), opt_fn, 48, 80, 1500, 160.0)
	_route_cache[race_id] = routes
	return routes


## Direct connection a -> b as a leg {kind, id, from, to, length_km} (shortest stage, else a ferry; {} if none).
static func link_between(a: String, b: String) -> Dictionary:
	var best: Dictionary = {}
	for id in stages():
		var st: Dictionary = stages()[id]
		var f := str(st.get("from", ""))
		var t := str(st.get("to", ""))
		if (f == a and t == b) or (f == b and t == a):
			var km := float(st.get("length_km", 0.0))
			if best.is_empty() or km < float(best["length_km"]):
				best = {"kind": "stage", "id": str(id), "from": a, "to": b, "length_km": km}
	if not best.is_empty():
		return best
	for id in ferries():
		var fe: Dictionary = ferries()[id]
		if (str(fe.get("from", "")) == a and str(fe.get("to", "")) == b) or (str(fe.get("from", "")) == b and str(fe.get("to", "")) == a):
			return {"kind": "ferry", "id": str(id), "from": a, "to": b, "length_km": 0.0}
	return {}


## A route option of the route choice as a whole route to its target (RouteInfo): {legs (option +
## continuation), continuation, totals, via (city ids before the target), target, km (to the target)}.
## Uses the data module's "continuation" / "route_km" / route summary when present, otherwise the
## complete race routes (race_routes) or the option's "via" cities.
static func route_option(option: Dictionary, race_id: String, driven: Array, fallback_target: String = "") -> Dictionary:
	var target := str(option.get("target", fallback_target))
	var routes: Array = []
	if not option.has("continuation"):
		routes = race_routes(race_id)
	var cont := RouteInfo.continuation(option, target, driven, routes, link_between)
	var legs: Array[Dictionary] = [option]
	legs.append_array(cont)
	var t := RouteInfo.totals(legs, _leg_summary)
	if cont.is_empty() and str(option.get("to", "")) != target and option.has("total_km"):
		t["km"] = float(option["total_km"])   # continuation unknown: at least the length is right
	RouteInfo.apply_data_summary(t, option)
	return {"legs": legs, "continuation": cont, "totals": t, "via": RouteInfo.via_cities(option, cont, target),
		"target": target, "km": float(t["km"])}


## StagePlan.summary() of a stage leg in its driving direction ({} for ferries).
static func _leg_summary(leg: Dictionary) -> Dictionary:
	if str(leg.get("kind", "stage")) != "stage":
		return {}
	var plan := stage_plan(str(leg.get("id", "")), str(leg.get("from", "")))
	return plan.summary() if plan != null else {"length_km": float(leg.get("length_km", 0.0))}


## {count, min_km, max_km, min_stages, max_stages, ferry} – GameData.race_summary() keys win if present.
static func race_summary(race_id: String) -> Dictionary:
	var st := RaceState.route_stats(race_routes(race_id))
	var gd := _node("GameData")
	if not use_sample_network() and gd != null and gd.has_method("race_summary"):
		var res: Variant = gd.call("race_summary", race_id)
		if res is Dictionary:
			for pair in [["min_km", ["min_km", "length_min_km", "min_length_km"]], ["max_km", ["max_km", "length_max_km", "max_length_km"]],
					["min_stages", ["min_stages", "stages_min"]], ["max_stages", ["max_stages", "stages_max"]]]:
				for k in pair[1]:
					if (res as Dictionary).has(k):
						st[pair[0]] = res[k]
						break
	return st


# --- leaderboards ------------------------------------------------------------------------------

static func top(board_key: String, vehicle_filter: String = "", count: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := "" if vehicle_filter == "all" else vehicle_filter
	if sample:
		for e in _sample_board(board_key):
			if f == "" or str(e.get("vehicle", "")) == f:
				out.append(e)
				if out.size() >= count:
					break
		return out
	var lb := _node("Leaderboards")
	if lb == null:
		return out
	var res: Variant = lb.call("top", board_key, f, count)
	if res is Array:
		for e in res:
			if e is Dictionary:
				out.append(e)
	return out


static func record(board_key: String, vehicle_filter: String = "") -> Dictionary:
	var t := top(board_key, vehicle_filter, 1)
	return t[0] if not t.is_empty() else {}


static func would_rank(board_key: String, time_s: float, vehicle_filter: String = "") -> int:
	if sample:
		var list := top(board_key, vehicle_filter, 10)
		for i in list.size():
			if time_s < float(list[i].get("time_s", INF)):
				return i + 1
		return list.size() + 1 if list.size() < 10 else 0
	var lb := _node("Leaderboards")
	return int(lb.call("would_rank", board_key, time_s, "" if vehicle_filter == "all" else vehicle_filter)) if lb != null else 0


## Index of a just-submitted entry (same name and time) in a board list, -1 if it is not there.
static func entry_index(list: Array, entry: Dictionary) -> int:
	for i in list.size():
		var e: Dictionary = list[i]
		if str(e.get("name", "")) == str(entry.get("name", "")) and absf(float(e.get("time_s", 0.0)) - float(entry.get("time_s", -1.0))) < 0.0005:
			return i
	return -1


## Filter under which a submitted entry shows up: "" = it is in the overall top 10, else its vehicle
## type (it only made the list of its own vehicle – "TOP 10 KOMPAKT").
static func board_filter_for(board_key: String, entry: Dictionary) -> String:
	if entry_index(top(board_key, "", 10), entry) >= 0:
		return ""
	return str(entry.get("vehicle", ""))


## Valid leaderboard filters: "all" + the vehicle ids of the configuration.
static func valid_filters(config: Dictionary) -> Array[String]:
	var out: Array[String] = ["all"]
	for v in ConfigLoader.lookup(config, "vehicles.order", []):
		out.append(str(v))
	return out


## Leaderboard filter to use: the stored choice of the player (`stored` = value from the settings
## file, null if never chosen) if it is still valid, else leaderboard.default_filter (central config),
## else "all".
static func effective_filter(config: Dictionary, stored: Variant) -> String:
	var valid := valid_filters(config)
	if stored != null and valid.has(str(stored)):
		return str(stored)
	var def := str(ConfigLoader.lookup(config, "leaderboard.default_filter", "all"))
	return def if valid.has(def) else "all"


## Inserts an entry, returns its rank (0 = not placed). Sample mode: in memory only.
static func submit(board_key: String, entry: Dictionary) -> int:
	if sample:
		var list: Array = _sample_board(board_key)
		list.append(entry)
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time_s"]) < float(b["time_s"]))
		_boards[board_key] = list
		var r := list.find(entry) + 1
		return r if r <= 10 else 0
	var lb := _node("Leaderboards")
	return int(lb.call("submit", board_key, entry)) if lb != null else 0


static func _sample_board(board_key: String) -> Array:
	if not _boards.has(board_key):
		_boards[board_key] = SampleData.board_entries(board_key, cfg())
	return _boards[board_key]


# --- save game -------------------------------------------------------------------------------

static func has_saved_race() -> bool:
	if sample:
		return true
	var sg := _node("SaveGame")
	return sg != null and bool(sg.call("has_race"))


static func load_race() -> Dictionary:
	if sample:
		return SampleData.saved_race()
	var sg := _node("SaveGame")
	if sg == null:
		return {}
	var d: Variant = sg.call("load_race")
	return d if d is Dictionary else {}


static func save_race(state: Dictionary) -> void:
	if sample:
		return
	var sg := _node("SaveGame")
	if sg != null:
		sg.call("save_race", state)


static func clear_race() -> void:
	if sample:
		return
	var sg := _node("SaveGame")
	if sg != null:
		sg.call("clear_race")


# --- sample routing (detour-limited, like routing.detour_tolerance) ----------------------------

static func _sample_next_options(race_id: String, current: String, wp_index: int, visited: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := race(race_id)
	var wps: Array = r.get("waypoints", [])
	var target := str(wps[wp_index]) if wp_index < wps.size() else str(r.get("finish", ""))
	var legs := _sample_connections(current)
	var dist := _dijkstra(target)
	var base: float = dist.get(current, INF)
	var tol := float(ConfigLoader.lookup(cfg(), "routing.detour_tolerance", 0.35))
	for leg in legs:
		var to := str(leg["to"])
		if visited.has(to) and to != target:
			continue
		var via := float(leg["length_km"]) + float(dist.get(to, INF))
		if via <= base * (1.0 + tol) + 0.01:
			out.append(leg)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["length_km"]) < float(b["length_km"]))
	return out


static func _sample_connections(city: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in stages():
		var s: Dictionary = stages()[id]
		if str(s["from"]) == city:
			out.append({"kind": "stage", "id": id, "from": city, "to": str(s["to"]), "length_km": float(s.get("length_km", 0))})
		elif str(s["to"]) == city:
			out.append({"kind": "stage", "id": id, "from": city, "to": str(s["from"]), "length_km": float(s.get("length_km", 0))})
	for id in ferries():
		var f: Dictionary = ferries()[id]
		if str(f["from"]) == city:
			out.append({"kind": "ferry", "id": id, "from": city, "to": str(f["to"]), "length_km": 0.0})
	return out


static func _dijkstra(target: String) -> Dictionary:
	var dist := {target: 0.0}
	var open: Array[String] = [target]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[best]]):
				best = i
		var c := open[best]
		open.remove_at(best)
		for leg in _sample_connections(c):
			var nd := float(dist[c]) + float(leg["length_km"])
			var to := str(leg["to"])
			if nd < float(dist.get(to, INF)):
				dist[to] = nd
				if not open.has(to):
					open.append(to)
	return dist
