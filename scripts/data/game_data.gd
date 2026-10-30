extends Node
## Autoload "GameData": static game data (network of cities/stages/ferries/races, countries, scenery, map).
## Owner: data module. Public API is a contract (ARCHITECTURE.md §4.4); extend, don't break.
## The logic lives in RoadNetwork (scripts/data/road_network.gd, pure and testable); this node loads the
## files and delegates. Routing rules, data format extensions and helpers: docs/daten.md.
##
## A "network.json" next to the exported executable (or in a "data" folder next to it) replaces the
## built-in network – so new stages/races can be tried without rebuilding.

const NETWORK_PATH := "res://data/network.json"
const COUNTRIES_PATH := "res://data/countries.json"
const SCENERY_PATH := "res://data/scenery.json"
const MAP_PATH := "res://data/map/europe_map.json"
const NETWORK_OVERRIDE_NAME := "network.json"

var cities: Dictionary = {}      ## id -> {id, name, country, latlon, map_pos, name_local?, dev?}
var stages: Dictionary = {}      ## id -> raw stage dictionary (as in network.json)
var ferries: Dictionary = {}     ## id -> {id, from, to, name, fixed_time_s, world_hours}
var races: Dictionary = {}       ## id -> {id, name, start, finish, waypoints, avoid_stages?, tour?, description}
var race_order: Array[String] = []
var countries: Dictionary = {}   ## code -> country dictionary (data/countries.json)
var scenery: Dictionary = {}     ## id -> scenery dictionary (data/scenery.json, authored by the race module)
var map_data: Dictionary = {}    ## data/map/europe_map.json (may be empty)
var warnings: Array[String] = []
var network := RoadNetwork.new() ## the routing/validation logic behind this autoload
var network_source := NETWORK_PATH


func _init() -> void:
	reload()


func reload() -> void:
	var net := _load_network()
	var c: Variant = ConfigLoader.load_json(COUNTRIES_PATH)
	countries = c.get("countries", {}) if c is Dictionary else {}
	var sc: Variant = ConfigLoader.load_json(SCENERY_PATH)
	scenery = sc.get("scenery", {}) if sc is Dictionary else {}
	var m: Variant = ConfigLoader.load_json(MAP_PATH) if FileAccess.file_exists(MAP_PATH) else null
	map_data = m if m is Dictionary else {}
	network = RoadNetwork.new()
	network.setup(net, countries, ConfigLoader.load_merged(), map_data)
	cities = network.cities
	stages = network.stages
	ferries = network.ferries
	races = network.races
	race_order = network.race_order
	warnings = network.load_warnings.duplicate()
	for w in warnings:
		push_warning("network.json: " + w)
	if network_source != NETWORK_PATH:
		# A hand-edited network next to the executable: report every rule violation once.
		for w in validate():
			push_warning("%s: %s" % [network_source, w])


func _load_network() -> Dictionary:
	for p in network_override_paths():
		if not FileAccess.file_exists(p):
			continue
		var d: Variant = JsonFile.read(p)
		if d is Dictionary and _non_empty_array(d.get("stages")) and _non_empty_array(d.get("cities")):
			network_source = p
			print("GameData: Streckennetz aus ", p)
			return d
		push_warning("GameData: %s ist kein gültiges Streckennetz – nutze das eingebaute" % p)
	network_source = NETWORK_PATH
	var net: Variant = ConfigLoader.load_json(NETWORK_PATH)
	return net if net is Dictionary else {}


static func _non_empty_array(v: Variant) -> bool:
	return v is Array and not (v as Array).is_empty()


## Override locations for network.json (exported builds only).
static func network_override_paths() -> Array[String]:
	var paths: Array[String] = []
	if OS.has_feature("template"):
		var dir := OS.get_executable_path().get_base_dir()
		paths.append(dir.path_join(NETWORK_OVERRIDE_NAME))
		paths.append(dir.path_join("data").path_join(NETWORK_OVERRIDE_NAME))
	return paths


# --- Lookups ---------------------------------------------------------------------------------------

func get_city(id: String) -> Dictionary:
	return cities.get(id, {})


func city_name(id: String) -> String:
	return str(cities.get(id, {}).get("name", id))


func country_name(code: String) -> String:
	return str(countries.get(code, {}).get("name", code))


func police_set_for(country_code: String) -> String:
	return str(countries.get(country_code, {}).get("police", "police/de"))


func get_stage(id: String) -> Dictionary:
	return stages.get(id, {})


func get_race(id: String) -> Dictionary:
	return races.get(id, {})


func get_ferry(id: String) -> Dictionary:
	return ferries.get(id, {})


## Resolves a stage for the direction starting in from_city_id (empty = defined direction).
func get_stage_plan(stage_id: String, from_city_id: String = "") -> StagePlan:
	if not stages.has(stage_id):
		push_error("Unbekannte Etappe: " + stage_id)
		return null
	var p := StagePlan.build(stages[stage_id], from_city_id, cities, countries, ConfigLoader.load_merged())
	for w in p.warnings:
		push_warning(w)
	return p


func stage_board_key(stage_id: String, from_city_id: String) -> String:
	return network.stage_board_key(stage_id, from_city_id)


func race_board_key(race_id: String) -> String:
	return "race:" + race_id


## Length in km behind a leaderboard key (stage length, or the shortest route of a race).
func board_length_km(board_key: String) -> float:
	return network.board_length_km(board_key)


## All legs leaving city_id: [{kind: "stage"|"ferry", id, from, to, length_km}] – stages in both directions,
## ferries in both directions (ferries also carry name, fixed_time_s, world_hours).
func connections_from(city_id: String) -> Array[Dictionary]:
	return network.connections_from(city_id)


# --- Races and routing ---------------------------------------------------------------------------

## Legal next legs of a race from current_city towards the next target (waypoint or finish): Dijkstra over
## all stages and ferries, every leg whose detour stays within routing.detour_tolerance of the best one,
## never revisiting a city of the current leg, at most routing.max_options (best first). `visited` may be
## the whole route of the race (route[] of the race state) or just the current leg.
## Each option: {kind, id, from, to, length_km, remaining_km, total_km, detour, best, target, target_index,
## via, name, board_key (stages), name/fixed_time_s/world_hours (ferries)}. [] when the race is complete.
## Whole route to the next target (show this in the route choice, not just the first leg): continuation
## (following legs on the shortest rest, each with name and board_key), route_km (= total_km), route_cities
## ([current_city, to, …, target]), route_summary (legs_summary() of leg + continuation, same keys as
## StagePlan.summary()) and via_distinct (cities only this option passes, e.g. Kassel vs. Frankfurt).
func next_options(race_id: String, current_city: String, waypoint_index: int, visited: Array) -> Array[Dictionary]:
	return network.next_options(race_id, current_city, waypoint_index, visited)


## Summary of a chain of legs as driven (e.g. an option's leg + continuation, or a route of race_routes()):
## the keys of StagePlan.summary() summed / length-weighted over all stages, plus cities, stages, ferries and
## ferry_time_s.
func legs_summary(legs: Array) -> Dictionary:
	return network.legs_summary(legs)


## The legs of a race route split into the ways between consecutive targets (start → waypoint → … → finish).
func target_segments(race_id: String, legs: Array) -> Array:
	return network.target_segments(race_id, legs)


## waypoints + [finish] of a race.
func race_targets(race_id: String) -> Array[String]:
	return network.race_targets(race_id)


## City id of the target with this index ("" = race complete).
func next_target(race_id: String, waypoint_index: int) -> String:
	return network.next_target(race_id, waypoint_index)


## New waypoint_index after arriving in city (store it in the race state after every leg).
func advance_waypoint_index(race_id: String, city: String, waypoint_index: int) -> int:
	return network.advance_waypoint_index(race_id, city, waypoint_index)


## True if arriving in city completes the race.
func is_race_finished(race_id: String, city: String, waypoint_index: int) -> bool:
	return network.is_race_finished(race_id, city, waypoint_index)


## All routes within the detour tolerance: [{cities, legs[{kind, id, from, to, length_km}], km, stages, ferries}].
func race_routes(race_id: String) -> Array[Dictionary]:
	return network.race_routes(race_id)


## Cities with a route choice: [{city, waypoint_index, options: [to ids]}].
func race_choices(race_id: String) -> Array[Dictionary]:
	return network.race_choices(race_id)


## {id, name, start, finish, waypoints, description, routes, min_km, max_km, min_stages, max_stages, ferries,
##  countries, choices}
func race_summary(race_id: String) -> Dictionary:
	return network.race_summary(race_id)


## StagePlan.summary() + {stage_id, from, to, name, board_key, roads, description}.
func stage_summary(stage_id: String, from_city_id: String = "") -> Dictionary:
	return network.stage_summary(stage_id, from_city_id)


## Shortest path between two cities over the whole (non-dev) network: {km, cities, legs}.
func shortest_path(from_id: String, to_id: String) -> Dictionary:
	return network.shortest_path(from_id, to_id)


## "Hamburg – Hannover" (stage leg) or the ferry name.
func leg_name(leg: Dictionary) -> String:
	return network.leg_name(leg)


## Races shown in menus (dev races hidden).
func visible_race_ids() -> Array[String]:
	var out: Array[String] = []
	for id in race_order:
		if not bool(races[id].get("dev", false)):
			out.append(id)
	return out


## Stages shown in the single-stage menu (dev stages hidden), in network order (grouped by region).
func visible_stage_ids() -> Array[String]:
	var out: Array[String] = []
	for id in network.stage_order:
		if not bool(stages[id].get("dev", false)):
			out.append(id)
	return out


# --- Map -------------------------------------------------------------------------------------------

## Pixel size of the map (data/map/europe_map.json "size").
func map_size() -> Vector2:
	return network.map_size()


## Map position of a latitude/longitude (same projection as the map polygons and cities[].map_pos).
func project_latlon(lat: float, lon: float) -> Vector2:
	return network.project_latlon(lat, lon)


func city_map_pos(city_id: String) -> Vector2:
	return network.city_map_pos(city_id)


# --- Validation ------------------------------------------------------------------------------------

## Full data check (see RoadNetwork.validate()); the result is also stored in `warnings`.
func validate() -> Array[String]:
	warnings = network.validate()
	return warnings


## Scenery ids used by stages but missing in data/scenery.json (the race module renders them with defaults).
func missing_scenery_ids() -> Array[String]:
	var out: Array[String] = []
	for id in network.stage_order:
		for sec in stages[id].get("sections", []):
			var sc := str(sec.get("scenery", ""))
			if sc != "" and not scenery.has(sc) and not out.has(sc):
				out.append(sc)
	return out
