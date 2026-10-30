class_name RoadNetwork
extends RefCounted
## Pure network logic behind the GameData autoload (no autoload access – usable in headless tests):
## cities, stages, ferries and races of data/network.json, Dijkstra routing over stages (both directions)
## and ferries, route options of a race within the detour tolerance, summaries for menus and validation.
## Owner: data module. See docs/daten.md for the routing rules.
##
## Races: {id, name, start, finish, waypoints[], avoid_stages[]?, tour?, description, dev?}. The race is a chain of
## legs start → waypoints[0] → … → finish. `waypoint_index` = index of the next target in
## race_targets() (= waypoints + [finish]); waypoints.size() means "heading for the finish".
## Within a leg no city may be visited twice; between legs cities may repeat (Königsrennen: Belgrad).

const SCENERY_IDS: Array[String] = ["north_plain", "heath", "forest_hills", "rhine_main", "industrial", "polder",
	"ardennes", "farmland_fr", "loire", "pyrenees", "meseta", "mediterranean", "alps", "lombardy", "karst",
	"balkan_hills", "pannonian_plain", "bohemian", "east_plain", "baltic_forest", "coast", "city"]
const ROAD_TYPES: Array[String] = ["autobahn", "landstrasse"]
const MAX_ROUTES := 64

var cities: Dictionary = {}       ## id -> {id, name, country, latlon, map_pos, name_local?, dev?}
var stages: Dictionary = {}       ## id -> raw stage dictionary
var stage_order: Array[String] = []
var ferries: Dictionary = {}      ## id -> {id, from, to, name, fixed_time_s, world_hours}
var races: Dictionary = {}        ## id -> race dictionary
var race_order: Array[String] = []
var countries: Dictionary = {}
var map_data: Dictionary = {}
var cfg: Dictionary = {}
var detour_tolerance := 0.35
var max_options := 4
var load_warnings: Array[String] = []   ## problems found while reading the file (duplicates, bad entries)

var _adj: Dictionary = {}               ## city id -> Array of leg dictionaries (both directions)
var _route_cache: Dictionary = {}       ## race id -> {routes, choices}
var _summary_cache: Dictionary = {}     ## "stage_id|from_city" -> StagePlan.summary() (read only)


## Reads the network dictionary (data/network.json). country_data = data/countries.json["countries"].
func setup(network: Dictionary, country_data: Dictionary, config: Dictionary, map: Dictionary = {}) -> void:
	cities = {}
	stages = {}
	stage_order = []
	ferries = {}
	races = {}
	race_order = []
	load_warnings = []
	_route_cache = {}
	_summary_cache = {}
	countries = country_data
	cfg = config
	map_data = map
	detour_tolerance = float(ConfigLoader.lookup(cfg, "routing.detour_tolerance", 0.35))
	max_options = maxi(1, int(ConfigLoader.lookup(cfg, "routing.max_options", 4)))
	for c in _array(network, "cities"):
		var id := _id_of(c, "Stadt")
		if id != "":
			cities[id] = c
	for s in _array(network, "stages"):
		var id := _id_of(s, "Etappe")
		if id != "":
			if not stages.has(id):
				stage_order.append(id)
			stages[id] = s
	for f in _array(network, "ferries"):
		var id := _id_of(f, "Fähre")
		if id != "":
			ferries[id] = f
	for r in _array(network, "races"):
		var id := _id_of(r, "Rennen")
		if id != "":
			if not races.has(id):
				race_order.append(id)
			races[id] = r
	_build_adjacency()


func _id_of(entry: Variant, what: String) -> String:
	if not entry is Dictionary or str((entry as Dictionary).get("id", "")) == "":
		load_warnings.append("%s ohne id übersprungen" % what)
		return ""
	var id := str(entry["id"])
	var known := false
	match what:
		"Stadt": known = cities.has(id)
		"Etappe": known = stages.has(id)
		"Fähre": known = ferries.has(id)
		"Rennen": known = races.has(id)
	if known:
		load_warnings.append("%s %s doppelt definiert" % [what, id])
	return id


static func _array(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	return v if v is Array else []


func _build_adjacency() -> void:
	_adj = {}
	for id in stage_order:
		var s: Dictionary = stages[id]
		var a := str(s.get("from", ""))
		var b := str(s.get("to", ""))
		var length := float(s.get("length_km", 0.0))
		if a == "" or b == "" or a == b:
			continue
		_add_leg(a, {"kind": "stage", "id": id, "from": a, "to": b, "length_km": length})
		_add_leg(b, {"kind": "stage", "id": id, "from": b, "to": a, "length_km": length})
	for id in ferries:
		var f: Dictionary = ferries[id]
		var a := str(f.get("from", ""))
		var b := str(f.get("to", ""))
		if a == "" or b == "" or a == b:
			continue
		for pair in [[a, b], [b, a]]:
			_add_leg(str(pair[0]), {"kind": "ferry", "id": id, "from": str(pair[0]), "to": str(pair[1]), "length_km": 0.0,
				"name": str(f.get("name", id)), "fixed_time_s": float(f.get("fixed_time_s", 0.0)),
				"world_hours": float(f.get("world_hours", 0.0))})


func _add_leg(city: String, leg: Dictionary) -> void:
	if not _adj.has(city):
		_adj[city] = []
	(_adj[city] as Array).append(leg)


# --- Basic queries -----------------------------------------------------------------------------

func city_name(id: String) -> String:
	return str(cities.get(id, {}).get("name", id))


## All legs leaving city_id (stages in both directions and ferries): [{kind, id, from, to, length_km, …}].
func connections_from(city_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for leg: Dictionary in _adj.get(city_id, []):
		out.append(leg.duplicate())
	return out


## "Hamburg – Hannover" for a stage leg, the ferry name for a ferry leg.
func leg_name(leg: Dictionary) -> String:
	if str(leg.get("kind", "")) == "ferry":
		return str(leg.get("name", leg.get("id", "")))
	return "%s – %s" % [city_name(str(leg.get("from", ""))), city_name(str(leg.get("to", "")))]


func is_dev_leg(leg: Dictionary) -> bool:
	if str(leg.get("kind", "")) == "stage" and bool(stages.get(str(leg["id"]), {}).get("dev", false)):
		return true
	return bool(cities.get(str(leg.get("from", "")), {}).get("dev", false)) or bool(cities.get(str(leg.get("to", "")), {}).get("dev", false))


## Dijkstra from from_id to to_id. avoid_cities / avoid_stages are sets (Dictionary keys); the target itself
## is never avoided. Returns {km (INF if unreachable), cities: [from … to], legs: [leg, …]}.
func shortest_path(from_id: String, to_id: String, avoid_cities: Dictionary = {}, avoid_stages: Dictionary = {},
		include_dev: bool = false) -> Dictionary:
	if from_id == to_id:
		return {"km": 0.0, "cities": [from_id], "legs": []}
	var dist := {from_id: 0.0}
	var prev := {}
	var done := {}
	while true:
		var cur := ""
		var best := INF
		for c: String in dist:
			if not done.has(c) and float(dist[c]) < best:
				best = float(dist[c])
				cur = c
		if cur == "" or cur == to_id:
			break
		done[cur] = true
		for leg: Dictionary in _adj.get(cur, []):
			var nxt := str(leg["to"])
			if done.has(nxt) or avoid_stages.has(leg["id"]) or (avoid_cities.has(nxt) and nxt != to_id):
				continue
			if not include_dev and is_dev_leg(leg):
				continue
			var nd := best + float(leg["length_km"])
			if nd < float(dist.get(nxt, INF)) - 0.000001:
				dist[nxt] = nd
				prev[nxt] = leg
	if not dist.has(to_id):
		return {"km": INF, "cities": [], "legs": []}
	var legs: Array[Dictionary] = []
	var c := to_id
	while c != from_id:
		var leg: Dictionary = prev[c]
		legs.push_front(leg.duplicate())
		c = str(leg["from"])
	var path: Array[String] = [from_id]
	for l in legs:
		path.append(str(l["to"]))
	return {"km": float(dist[to_id]), "cities": path, "legs": legs}


# --- Races -------------------------------------------------------------------------------------

## Targets of a race in order: waypoints + [finish].
func race_targets(race_id: String) -> Array[String]:
	var out: Array[String] = []
	var race: Dictionary = races.get(race_id, {})
	if race.is_empty():
		return out
	for w in race.get("waypoints", []):
		out.append(str(w))
	out.append(str(race.get("finish", "")))
	return out


## City id of the target with this index ("" when the race is complete).
func next_target(race_id: String, waypoint_index: int) -> String:
	var t := race_targets(race_id)
	if waypoint_index < 0:
		waypoint_index = 0
	return t[waypoint_index] if waypoint_index < t.size() else ""


## Index of the next target after arriving in city (skips every target the city satisfies).
func advance_waypoint_index(race_id: String, city: String, waypoint_index: int) -> int:
	var t := race_targets(race_id)
	var i := clampi(waypoint_index, 0, t.size())
	while i < t.size() and t[i] == city:
		i += 1
	return i


## True if arriving in city completes the race.
func is_race_finished(race_id: String, city: String, waypoint_index: int) -> bool:
	var t := race_targets(race_id)
	return not t.is_empty() and advance_waypoint_index(race_id, city, waypoint_index) >= t.size()


## Cities of the current leg that may not be visited again: the part of `visited` since the last
## occurrence of the leg's start (previous target or race start), plus the current city.
func leg_visited(race_id: String, waypoint_index: int, visited: Array, current_city: String) -> Dictionary:
	var race: Dictionary = races.get(race_id, {})
	var t := race_targets(race_id)
	var leg_start := str(race.get("start", ""))
	if waypoint_index > 0 and waypoint_index - 1 < t.size():
		leg_start = t[waypoint_index - 1]
	var from := 0
	for i in range(visited.size() - 1, -1, -1):
		if str(visited[i]) == leg_start:
			from = i
			break
	var out := {}
	for i in range(from, visited.size()):
		out[str(visited[i])] = true
	out[current_city] = true
	return out


func _avoid_set(race: Dictionary) -> Dictionary:
	var out := {}
	for s in race.get("avoid_stages", []):
		out[str(s)] = true
	return out


## Legal next legs of a race from current_city towards the next target: every leg whose detour (leg length +
## shortest remaining distance, avoiding the cities of the current leg) is within routing.detour_tolerance of
## the best option; at most routing.max_options, best first. Without a known race: all unvisited connections.
## Extra fields: remaining_km, total_km, detour (fraction), best, target, target_index, via (cities after
## this leg up to the target on the shortest continuation), name, board_key (stages).
## The whole route to the next target (the first leg alone often hides the trade-off of a route choice):
##   continuation  – legs after this one on the shortest rest, in driving order:
##                   [{kind, id, from, to, length_km, name, board_key (stages), ferry fields}]
##   route_km      – length of leg + continuation (= total_km)
##   route_cities  – [current_city, to, …, target]
##   route_summary – legs_summary() of leg + continuation: the keys of StagePlan.summary() (length_km,
##                   autobahn_km, unlimited_km, landstrasse_km, radars, stations, tunnels, tunnel_km, borders,
##                   traffic/hills/curviness length-weighted, max_hills, countries) plus cities, stages,
##                   ferries, ferry_time_s – summed over the whole route to the target
##   via_distinct  – cities of this route (without current city and target) that no other offered option
##                   passes, e.g. ["hannover", "kassel"] vs ["bremen", "dortmund", "frankfurt"] in Hamburg
## Without a race the details describe the single leg (continuation []).
func next_options(race_id: String, current_city: String, waypoint_index: int, visited: Array) -> Array[Dictionary]:
	var out := _race_options(race_id, current_city, waypoint_index, visited)
	_add_route_details(out, current_city)
	return out


## next_options() without the route details (used to enumerate all routes of a race).
func _race_options(race_id: String, current_city: String, waypoint_index: int, visited: Array) -> Array[Dictionary]:
	var race: Dictionary = races.get(race_id, {})
	if race.is_empty():
		var free: Array[Dictionary] = []
		for leg in connections_from(current_city):
			if not visited.has(leg["to"]):
				free.append(leg)
		return free
	var t := race_targets(race_id)
	var idx := advance_waypoint_index(race_id, current_city, waypoint_index)
	if idx >= t.size():
		return []
	var target := t[idx]
	var blocked := leg_visited(race_id, idx, visited, current_city)
	var avoid := _avoid_set(race)
	var dev_ok := bool(race.get("dev", false))
	var opts: Array[Dictionary] = []
	for leg: Dictionary in _adj.get(current_city, []):
		var to := str(leg["to"])
		if avoid.has(leg["id"]) or blocked.has(to) or (not dev_ok and is_dev_leg(leg)):
			continue
		var rest := {"km": 0.0, "cities": [to], "legs": []}
		if to != target:
			rest = shortest_path(to, target, blocked, avoid, dev_ok)
			if is_inf(float(rest["km"])):
				continue
		var o := leg.duplicate()
		o["remaining_km"] = float(rest["km"])
		o["total_km"] = float(leg["length_km"]) + float(rest["km"])
		o["via"] = (rest["cities"] as Array).slice(1)
		o["continuation"] = rest["legs"]
		o["target"] = target
		o["target_index"] = idx
		opts.append(o)
	if opts.is_empty():
		return opts
	var best := INF
	for o in opts:
		best = minf(best, float(o["total_km"]))
	var out: Array[Dictionary] = []
	for o in opts:
		if float(o["total_km"]) <= best * (1.0 + detour_tolerance) + 0.001:
			o["detour"] = (float(o["total_km"]) / best - 1.0) if best > 0.0 else 0.0
			o["best"] = absf(float(o["total_km"]) - best) < 0.001
			o["name"] = leg_name(o)
			if str(o["kind"]) == "stage":
				o["board_key"] = stage_board_key(str(o["id"]), current_city)
			out.append(o)
	out.sort_custom(_option_before)
	if out.size() > max_options:
		out.resize(max_options)
	return out


static func _option_before(a: Dictionary, b: Dictionary) -> bool:
	if absf(float(a["total_km"]) - float(b["total_km"])) > 0.001:
		return float(a["total_km"]) < float(b["total_km"])
	return str(a["id"]) < str(b["id"])


## Adds continuation (with names/board keys), route_km, route_cities, route_summary and via_distinct.
func _add_route_details(opts: Array[Dictionary], current_city: String) -> void:
	for o in opts:
		var cont: Array[Dictionary] = []
		for l in o.get("continuation", []):
			var c: Dictionary = (l as Dictionary).duplicate()
			c["name"] = leg_name(c)
			if str(c.get("kind", "")) == "stage":
				c["board_key"] = stage_board_key(str(c["id"]), str(c["from"]))
			cont.append(c)
		o["continuation"] = cont
		o["route_km"] = float(o.get("total_km", o.get("length_km", 0.0)))
		var route_cities: Array[String] = [current_city, str(o["to"])]
		for c in cont:
			route_cities.append(str(c["to"]))
		o["route_cities"] = route_cities
		var chain: Array = [o]
		chain.append_array(cont)
		o["route_summary"] = legs_summary(chain)
	for i in opts.size():
		var others := {}
		for j in opts.size():
			if j != i:
				for c in opts[j]["route_cities"]:
					others[str(c)] = true
		var target := str(opts[i].get("target", ""))
		var distinct: Array[String] = []
		for c in (opts[i]["route_cities"] as Array).slice(1):
			var id := str(c)
			if id != target and not others.has(id):
				distinct.append(id)
		opts[i]["via_distinct"] = distinct


## Plain-data summary of a chain of legs as driven (stages in their driving direction, ferries) in the format of
## StagePlan.summary(): sums of length_km, autobahn_km, unlimited_km, landstrasse_km, radars (of the driving
## direction), stations, tunnels, tunnel_km, borders; traffic, hills and curviness length-weighted; max_hills;
## countries in driving order (without repeats). Additionally cities [first from … last to], stages, ferries and
## ferry_time_s. Ferries count 0 km; unknown stages are skipped. Used for route_summary and race routes.
func legs_summary(legs: Array) -> Dictionary:
	var s := {"length_km": 0.0, "autobahn_km": 0.0, "unlimited_km": 0.0, "landstrasse_km": 0.0, "radars": 0,
		"stations": 0, "tunnels": 0, "tunnel_km": 0.0, "borders": 0, "traffic": 0.0, "hills": 0.0,
		"curviness": 0.0, "max_hills": 0, "countries": [], "cities": [], "stages": 0, "ferries": 0,
		"ferry_time_s": 0.0}
	var countries_out: Array[String] = []
	var cities_out: Array[String] = []
	var traffic_w := 0.0
	var hills_w := 0.0
	var curves_w := 0.0
	for leg in legs:
		if not leg is Dictionary:
			continue
		var l: Dictionary = leg
		var from := str(l.get("from", ""))
		var to := str(l.get("to", ""))
		var codes: Array = []
		if str(l.get("kind", "stage")) == "ferry":
			var ferry: Dictionary = ferries.get(str(l.get("id", "")), {})
			s["ferries"] = int(s["ferries"]) + 1
			s["ferry_time_s"] = float(s["ferry_time_s"]) + float(ferry.get("fixed_time_s", l.get("fixed_time_s", 0.0)))
			codes = [str(cities.get(from, {}).get("country", "")), str(cities.get(to, {}).get("country", ""))]
		else:
			var st := _stage_summary_cached(str(l.get("id", "")), from)
			if st.is_empty():
				continue
			var length := float(st["length_km"])
			s["stages"] = int(s["stages"]) + 1
			s["length_km"] = float(s["length_km"]) + length
			for key in ["autobahn_km", "unlimited_km", "landstrasse_km", "tunnel_km"]:
				s[key] = float(s[key]) + float(st[key])
			for key in ["radars", "stations", "tunnels", "borders"]:
				s[key] = int(s[key]) + int(st[key])
			traffic_w += float(st["traffic"]) * length
			hills_w += float(st["hills"]) * length
			curves_w += float(st["curviness"]) * length
			s["max_hills"] = maxi(int(s["max_hills"]), int(st["max_hills"]))
			codes = st["countries"]
		if cities_out.is_empty():
			cities_out.append(from)
		cities_out.append(to)
		for c in codes:
			var code := str(c)
			if code != "" and (countries_out.is_empty() or countries_out[-1] != code):
				countries_out.append(code)
	var total := float(s["length_km"])
	if total > 0.0:
		s["traffic"] = traffic_w / total
		s["hills"] = hills_w / total
		s["curviness"] = curves_w / total
	s["countries"] = countries_out
	s["cities"] = cities_out
	return s


## StagePlan.summary() of a stage in the direction starting at from_city, cached (the network does not change
## after setup()). Read only – callers must not modify the returned dictionary.
func _stage_summary_cached(stage_id: String, from_city: String) -> Dictionary:
	var key := "%s|%s" % [stage_id, from_city]
	if not _summary_cache.has(key):
		var p := get_stage_plan(stage_id, from_city)
		_summary_cache[key] = p.summary() if p != null else {}
	return _summary_cache[key]


## Splits the legs of a race route into the ways between consecutive targets (start → first waypoint → … →
## finish), e.g. for the Königsrennen [[kiel→hamburg], [hamburg→bremen], [bremen→amsterdam], …]. An unfinished
## last way (route still running) is the last element.
func target_segments(race_id: String, legs: Array) -> Array:
	var out: Array = []
	var seg: Array = []
	var idx := 0
	for leg in legs:
		if not leg is Dictionary:
			continue
		seg.append(leg)
		var next_idx := advance_waypoint_index(race_id, str((leg as Dictionary).get("to", "")), idx)
		if next_idx != idx:
			out.append(seg)
			seg = []
			idx = next_idx
	if not seg.is_empty():
		out.append(seg)
	return out


## Every complete route a player can drive by following next_options (cached), shortest first:
## [{cities: [ids], legs: [{kind, id, from, to, length_km}], km, stages, ferries}].
func race_routes(race_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _routes_of(race_id)["routes"]:
		out.append(r.duplicate(true))
	return out


## Cities with a route choice: [{city, waypoint_index, options: [to ids]}].
func race_choices(race_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _routes_of(race_id)["choices"]:
		out.append(c.duplicate(true))
	return out


func _routes_of(race_id: String) -> Dictionary:
	if _route_cache.has(race_id):
		return _route_cache[race_id]
	var result := {"routes": [], "choices": []}
	var race: Dictionary = races.get(race_id, {})
	if not race.is_empty():
		var start := str(race.get("start", ""))
		var routes: Array[Dictionary] = []
		var choices := {}
		_collect(race_id, start, 0, [start], [], 0.0, routes, choices)
		routes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["km"]) < float(b["km"]))
		result["routes"] = routes
		result["choices"] = choices.values()
	_route_cache[race_id] = result
	return result


func _collect(race_id: String, city: String, idx: int, route: Array, legs: Array, km: float,
		out: Array[Dictionary], choices: Dictionary) -> void:
	if out.size() >= MAX_ROUTES or route.size() > 400:
		return
	var opts := _race_options(race_id, city, idx, route)
	if opts.size() > 1:
		var key := "%s|%d" % [city, idx]
		if not choices.has(key):
			var to: Array[String] = []
			for o in opts:
				to.append(str(o["to"]))
			choices[key] = {"city": city, "waypoint_index": idx, "options": to}
	for o in opts:
		var to := str(o["to"])
		var r2 := route.duplicate()
		r2.append(to)
		var l2 := legs.duplicate()
		l2.append({"kind": o["kind"], "id": o["id"], "from": o["from"], "to": to, "length_km": float(o["length_km"])})
		var next_idx := advance_waypoint_index(race_id, to, int(o["target_index"]))
		if next_idx >= race_targets(race_id).size():
			var n_stages := 0
			for l: Dictionary in l2:
				if str(l["kind"]) == "stage":
					n_stages += 1
			out.append({"cities": r2, "legs": l2, "km": km + float(o["length_km"]), "stages": n_stages,
				"ferries": l2.size() - n_stages})
		else:
			_collect(race_id, to, next_idx, r2, l2, km + float(o["length_km"]), out, choices)


## Overview of a race for menus: {id, name, start, finish, waypoints, description, routes, min_km, max_km,
## min_stages, max_stages, ferries, countries (shortest route), choices}.
func race_summary(race_id: String) -> Dictionary:
	var race: Dictionary = races.get(race_id, {})
	if race.is_empty():
		return {}
	var routes := race_routes(race_id)
	var s := {
		"id": race_id, "name": str(race.get("name", race_id)), "start": str(race.get("start", "")),
		"finish": str(race.get("finish", "")), "waypoints": (race.get("waypoints", []) as Array).duplicate(),
		"description": str(race.get("description", "")), "routes": routes.size(),
		"min_km": 0.0, "max_km": 0.0, "min_stages": 0, "max_stages": 0, "ferries": 0, "countries": [],
		"choices": race_choices(race_id),
	}
	if routes.is_empty():
		return s
	s["min_km"] = float(routes[0]["km"])
	s["max_km"] = float(routes[-1]["km"])
	var lo := 1000000
	var hi := 0
	for r in routes:
		lo = mini(lo, int(r["stages"]))
		hi = maxi(hi, int(r["stages"]))
	s["min_stages"] = lo
	s["max_stages"] = hi
	s["ferries"] = int(routes[0]["ferries"])
	var cs: Array[String] = []
	for leg: Dictionary in routes[0]["legs"]:
		if str(leg["kind"]) != "stage":
			continue
		var p := get_stage_plan(str(leg["id"]), str(leg["from"]))
		for c in p.countries_in_order:
			if cs.is_empty() or cs[-1] != c:
				cs.append(c)
	s["countries"] = cs
	return s


# --- Stages --------------------------------------------------------------------------------------

func get_stage_plan(stage_id: String, from_city_id: String = "") -> StagePlan:
	if not stages.has(stage_id):
		return null
	return StagePlan.build(stages[stage_id], from_city_id, cities, countries, cfg)


func stage_board_key(stage_id: String, from_city_id: String) -> String:
	var s: Dictionary = stages.get(stage_id, {})
	return "stage:%s:%s" % [stage_id, "rev" if str(s.get("to", "")) == from_city_id else "fwd"]


## StagePlan.summary() plus {stage_id, from, to, name, board_key, roads, description}; {} if unknown.
func stage_summary(stage_id: String, from_city_id: String = "") -> Dictionary:
	var p := get_stage_plan(stage_id, from_city_id)
	if p == null:
		return {}
	var s := p.summary()
	s["stage_id"] = stage_id
	s["from"] = p.from_id
	s["to"] = p.to_id
	s["name"] = p.display_name
	s["board_key"] = p.board_key
	s["roads"] = str(stages[stage_id].get("roads", ""))
	s["description"] = str(stages[stage_id].get("description", ""))
	return s


## Length (km) of a leaderboard board: stage length or the shortest route of a race (0 if unknown).
func board_length_km(board_key: String) -> float:
	var parts := board_key.split(":")
	if parts.size() >= 2 and parts[0] == "stage":
		return float(stages.get(parts[1], {}).get("length_km", 0.0))
	if parts.size() >= 2 and parts[0] == "race":
		var routes: Array = _routes_of(parts[1])["routes"]
		return float(routes[0]["km"]) if not routes.is_empty() else 0.0
	return 0.0


# --- Map -----------------------------------------------------------------------------------------

func map_size() -> Vector2:
	var s: Variant = map_data.get("size", [0, 0])
	return Vector2(float(s[0]), float(s[1])) if s is Array and (s as Array).size() >= 2 else Vector2.ZERO


## Map coordinates of a geographic position with the projection of data/map/europe_map.json
## (Lambert azimuthal equal-area; same formula as tools/map/build_map.mjs).
func project_latlon(lat: float, lon: float) -> Vector2:
	var pp: Dictionary = map_data.get("projection_params", {})
	if pp.is_empty():
		return Vector2.ZERO
	var center: Array = pp.get("center_lonlat", [15.0, 52.0])
	var tr: Array = pp.get("translate", [0.0, 0.0])
	var sc := float(pp.get("scale", 1.0))
	var l0 := deg_to_rad(float(center[0]))
	var p1 := deg_to_rad(float(center[1]))
	var l := deg_to_rad(lon)
	var p := deg_to_rad(lat)
	var k := sqrt(2.0 / maxf(1.0 + sin(p1) * sin(p) + cos(p1) * cos(p) * cos(l - l0), 0.000001))
	var xr := k * cos(p) * sin(l - l0)
	var yr := k * (cos(p1) * sin(p) - sin(p1) * cos(p) * cos(l - l0))
	return Vector2(float(tr[0]) + sc * xr, float(tr[1]) - sc * yr)


func city_map_pos(city_id: String) -> Vector2:
	var mp: Variant = cities.get(city_id, {}).get("map_pos", null)
	if mp is Array and (mp as Array).size() >= 2:
		return Vector2(float(mp[0]), float(mp[1]))
	return Vector2.ZERO


# --- Validation ----------------------------------------------------------------------------------

## Full consistency check of the data: referential integrity, section sums, scenery ids, design rules of
## every stage in both directions (StagePlan warnings, dev stages forward only), fuel spacing, radar limits,
## landscape change at every border (outside the City Limits), routability of every race, stage lengths of
## tours (split_violations), map positions. Returns human-readable problems (empty = all fine).
func validate() -> Array[String]:
	var w: Array[String] = load_warnings.duplicate()
	for id: String in cities:
		_validate_city(id, w)
	for id in stage_order:
		_validate_stage(id, w)
	for id: String in ferries:
		var f: Dictionary = ferries[id]
		for end in ["from", "to"]:
			if not cities.has(str(f.get(end, ""))):
				w.append("Fähre %s: unbekannte Stadt '%s'" % [id, str(f.get(end, ""))])
		if float(f.get("fixed_time_s", -1.0)) < 0.0 or float(f.get("world_hours", -1.0)) < 0.0:
			w.append("Fähre %s: fixed_time_s/world_hours fehlen" % id)
	for id in race_order:
		_validate_race(id, w)
	return w


func _validate_city(id: String, w: Array[String]) -> void:
	var c: Dictionary = cities[id]
	if str(c.get("name", "")) == "":
		w.append("Stadt %s ohne Namen" % id)
	if not countries.has(str(c.get("country", ""))):
		w.append("Stadt %s: unbekanntes Land '%s'" % [id, str(c.get("country", ""))])
	var ll: Variant = c.get("latlon", null)
	if not (ll is Array and (ll as Array).size() == 2):
		w.append("Stadt %s ohne latlon" % id)
		return
	var size := map_size()
	if size == Vector2.ZERO:
		return
	var mp: Variant = c.get("map_pos", null)
	if not (mp is Array and (mp as Array).size() == 2):
		w.append("Stadt %s ohne map_pos" % id)
		return
	var pos := city_map_pos(id)
	if pos.x < 0.0 or pos.y < 0.0 or pos.x > size.x or pos.y > size.y:
		w.append("Stadt %s liegt außerhalb der Karte (%s)" % [id, str(pos)])
	if not map_data.get("projection_params", {}).is_empty():
		var proj := project_latlon(float(ll[0]), float(ll[1]))
		if proj.distance_to(pos) > 1.0:
			w.append("Stadt %s: map_pos %s passt nicht zu latlon (%s)" % [id, str(pos), str(proj)])


func _validate_stage(id: String, w: Array[String]) -> void:
	var s: Dictionary = stages[id]
	var dev := bool(s.get("dev", false))
	var a := str(s.get("from", ""))
	var b := str(s.get("to", ""))
	if not cities.has(a) or not cities.has(b) or a == b:
		w.append("Etappe %s: ungültige Städte '%s' → '%s'" % [id, a, b])
		return
	var length := float(s.get("length_km", 0.0))
	var secs: Array = s.get("sections", [])
	if length <= 0.0 or secs.is_empty():
		w.append("Etappe %s: Länge oder Abschnitte fehlen" % id)
		return
	var sum := 0.0
	for sec in secs:
		if not sec is Dictionary:
			w.append("Etappe %s: ungültiger Abschnitt" % id)
			return
		sum += float(sec.get("length_km", 0.0))
		var road := str(sec.get("road", "autobahn"))
		var country := str(sec.get("country", ""))
		var scen := str(sec.get("scenery", ""))
		if not ROAD_TYPES.has(road):
			w.append("Etappe %s: unbekannter Straßentyp '%s'" % [id, road])
		if not SCENERY_IDS.has(scen) or scen == "city":
			w.append("Etappe %s: Landschaft '%s' nicht erlaubt" % [id, scen])
		if not countries.has(country):
			w.append("Etappe %s: unbekanntes Land '%s'" % [id, country])
		for key in ["curviness", "hills"]:
			var v := float(sec.get(key, 1))
			if v < 0.0 or v > 3.0 or v != floorf(v):
				w.append("Etappe %s: %s=%s außerhalb 0–3" % [id, key, str(v)])
		if float(sec.get("traffic", 1.0)) <= 0.0:
			w.append("Etappe %s: Verkehrsfaktor ≤ 0" % id)
		if sec.has("speed_limit") and sec["speed_limit"] == null and not (country == "DE" and road == "autobahn"):
			w.append("Etappe %s: Abschnitt ohne Tempolimit außerhalb deutscher Autobahnen" % id)
	if absf(sum - length) > 0.5:
		w.append("Etappe %s: Abschnitte %.1f km ≠ Länge %.1f km" % [id, sum, length])
	if str(secs[0].get("country", "")) != str(cities[a].get("country", "")):
		w.append("Etappe %s: erster Abschnitt nicht im Land von %s" % [id, a])
	if str(secs[-1].get("country", "")) != str(cities[b].get("country", "")):
		w.append("Etappe %s: letzter Abschnitt nicht im Land von %s" % [id, b])
	for r in s.get("radars", []):
		var d := str(r.get("dir", "both"))
		if not ["both", "fwd", "rev"].has(d):
			w.append("Etappe %s: Radar-Richtung '%s' unbekannt" % [id, d])
	for from_id in ([a] if dev else [a, b]):
		var p := get_stage_plan(id, from_id)
		for msg in p.warnings:
			w.append("Etappe %s ab %s: %s" % [id, from_id, msg])
		if dev:
			continue
		_validate_plan_extras(p, w)


func _validate_plan_extras(p: StagePlan, w: Array[String]) -> void:
	var tag := "Etappe %s ab %s" % [p.stage_id, p.from_id]
	var spacing: Array = ConfigLoader.lookup(cfg, "fuel.station_spacing_km", [60, 90])
	var lo := float(spacing[0]) - 0.5
	var hi := float(spacing[1]) + 0.5
	var prev := 0.0
	for st in p.fuel_stations_km:
		var gap := st - prev
		if (prev > 0.0 and (gap < lo or gap > hi)) or (prev == 0.0 and gap > hi):
			w.append("%s: Tankstellenabstand %.1f km (Soll 60–90)" % [tag, gap])
		prev = st
	if p.fuel_stations_km.is_empty() or p.length_km - prev > hi:
		w.append("%s: zu großer Abstand von der letzten Tankstelle zum Ziel" % tag)
	for r in p.radars:
		for sec in p.sections:
			if float(sec["end_km"]) > float(r["km"]) + 0.001 and float(sec["start_km"]) < float(r["end_km"]) - 0.001:
				if int(sec["speed_limit"]) != int(r["limit"]):
					w.append("%s: Radar bei km %.1f (%d km/h) in Abschnitt mit Limit %d" % [tag, float(r["km"]), int(r["limit"]), int(sec["speed_limit"])])
		if float(r["end_km"]) > p.length_km - 50.0 + 0.001:
			w.append("%s: Radar bei km %.1f in den letzten 50 km" % [tag, float(r["km"])])
	# Design: "Grenzübergänge: Wechsel von Schildern, Landschaft und Polizeifahrzeugen" – the scenery changes at
	# every border, and the border lies outside the City Limits (there both sides would show "city").
	var margin := float(ConfigLoader.lookup(cfg, "stages.border_min_before_city_km", 5.0))
	for b in p.borders:
		var km := float(b["km"])
		var before := p.scenery_at(maxf(0.0, km - 0.05))
		var after := p.scenery_at(minf(p.length_km, km + 0.05))
		if before == after:
			w.append("%s: Grenze %s → %s bei km %.1f ohne Landschaftswechsel (%s)" % [tag, str(b["from"]), str(b["to"]), km, before])
		if km > p.city_limits_km - margin + 0.001:
			w.append("%s: Grenze bei km %.1f weniger als %.0f km vor den City Limits" % [tag, km, margin])


func _validate_race(id: String, w: Array[String]) -> void:
	var r: Dictionary = races[id]
	var start := str(r.get("start", ""))
	var finish := str(r.get("finish", ""))
	for c in [start, finish]:
		if not cities.has(c):
			w.append("Rennen %s: unbekannte Stadt '%s'" % [id, c])
			return
	var wps: Array = r.get("waypoints", [])
	for c in wps:
		if not cities.has(str(c)):
			w.append("Rennen %s: unbekannte Pflichtstation '%s'" % [id, str(c)])
			return
	if wps.is_empty() and start == finish:
		w.append("Rennen %s: Start = Ziel ohne Pflichtstationen" % id)
		return
	if not wps.is_empty() and str(wps[0]) == start:
		w.append("Rennen %s: erste Pflichtstation = Start" % id)
	for s in r.get("avoid_stages", []):
		if not stages.has(str(s)):
			w.append("Rennen %s: avoid_stages enthält unbekannte Etappe '%s'" % [id, str(s)])
	var routes := race_routes(id)
	if routes.is_empty():
		w.append("Rennen %s ist nicht fahrbar (kein Weg zu allen Pflichtstationen)" % id)
		return
	if not bool(r.get("dev", false)):
		for route in routes:
			for leg: Dictionary in route["legs"]:
				if is_dev_leg(leg):
					w.append("Rennen %s nutzt Entwickler-Etappe %s" % [id, str(leg["id"])])
	if bool(r.get("tour", false)):
		for msg in split_violations(id, routes):
			w.append(msg)


## Tours (race field "tour": true – the Königsrennen): when the way between two consecutive targets needs
## several stages, every one of them must be stages.split_length_km long (design: "Lange Abschnitte werden in
## Etappen von 200–400 km geteilt"); a single natural stage between two targets may be shorter. Returns the
## violations for the given routes (validate() calls it for every tour).
func split_violations(race_id: String, routes: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	var bounds: Array = ConfigLoader.lookup(cfg, "stages.split_length_km", [200, 400])
	var lo := float(bounds[0])
	var hi := float(bounds[1])
	for route in routes:
		for seg: Array in target_segments(race_id, route["legs"]):
			var parts: Array[Dictionary] = []
			for leg: Dictionary in seg:
				if str(leg.get("kind", "")) == "stage":
					parts.append(leg)
			if parts.size() < 2:
				continue
			for leg in parts:
				var km := float(leg["length_km"])
				if km < lo - 0.001 or km > hi + 0.001:
					var msg := "Rennen %s: Etappe %s (%s, %.0f km) teilt den Abschnitt %s – %s, Soll %.0f–%.0f km" % [
						race_id, str(leg["id"]), leg_name(leg), km, city_name(str((seg[0] as Dictionary)["from"])),
						city_name(str((seg[-1] as Dictionary)["to"])), lo, hi]
					if not out.has(msg):
						out.append(msg)
	return out
