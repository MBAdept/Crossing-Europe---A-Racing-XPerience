extends Node
## Autoload "GameData": static game data (network of cities/stages/ferries/races, countries, scenery, map).
## Owner: data module. Public API is a contract (ARCHITECTURE.md §Daten); extend, don't break.
## STUB: minimal routing (direct connections only) – replaced by the data module.

const NETWORK_PATH := "res://data/network.json"
const COUNTRIES_PATH := "res://data/countries.json"
const SCENERY_PATH := "res://data/scenery.json"
const MAP_PATH := "res://data/map/europe_map.json"

var cities: Dictionary = {}      ## id -> {id, name, country, latlon, map_pos, dev?}
var stages: Dictionary = {}      ## id -> raw stage dictionary (as in network.json)
var ferries: Dictionary = {}     ## id -> {id, from, to, name, fixed_time_s, world_hours}
var races: Dictionary = {}       ## id -> {id, name, start, finish, waypoints, ...}
var race_order: Array[String] = []
var countries: Dictionary = {}   ## code -> country dictionary (data/countries.json)
var scenery: Dictionary = {}     ## id -> scenery dictionary (data/scenery.json, authored by the race module)
var map_data: Dictionary = {}    ## data/map/europe_map.json (may be empty)
var warnings: Array[String] = []


func _init() -> void:
	reload()


func reload() -> void:
	cities.clear()
	stages.clear()
	ferries.clear()
	races.clear()
	race_order.clear()
	warnings.clear()
	var net: Variant = ConfigLoader.load_json(NETWORK_PATH)
	if net is Dictionary:
		for c in net.get("cities", []):
			cities[str(c["id"])] = c
		for s in net.get("stages", []):
			stages[str(s["id"])] = s
		for f in net.get("ferries", []):
			ferries[str(f["id"])] = f
		for r in net.get("races", []):
			races[str(r["id"])] = r
			race_order.append(str(r["id"]))
	var c: Variant = ConfigLoader.load_json(COUNTRIES_PATH)
	countries = c.get("countries", {}) if c is Dictionary else {}
	var sc: Variant = ConfigLoader.load_json(SCENERY_PATH)
	scenery = sc.get("scenery", {}) if sc is Dictionary else {}
	var m: Variant = ConfigLoader.load_json(MAP_PATH) if FileAccess.file_exists(MAP_PATH) else null
	map_data = m if m is Dictionary else {}


func get_city(id: String) -> Dictionary:
	return cities.get(id, {})


func city_name(id: String) -> String:
	return str(cities.get(id, {}).get("name", id))


func country_name(code: String) -> String:
	return str(countries.get(code, {}).get("name", code))


func police_set_for(country_code: String) -> String:
	return str(countries.get(country_code, {}).get("police", "police/de"))


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
	var s: Dictionary = stages.get(stage_id, {})
	return "stage:%s:%s" % [stage_id, "rev" if str(s.get("to", "")) == from_city_id else "fwd"]


func race_board_key(race_id: String) -> String:
	return "race:" + race_id


## All legs leaving city_id: [{kind: "stage"|"ferry", id, from, to, length_km}]
func connections_from(city_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in stages:
		var s: Dictionary = stages[id]
		if str(s["from"]) == city_id:
			out.append({"kind": "stage", "id": id, "from": city_id, "to": str(s["to"]), "length_km": float(s.get("length_km", 0))})
		elif str(s["to"]) == city_id:
			out.append({"kind": "stage", "id": id, "from": city_id, "to": str(s["from"]), "length_km": float(s.get("length_km", 0))})
	for id in ferries:
		var f: Dictionary = ferries[id]
		if str(f["from"]) == city_id:
			out.append({"kind": "ferry", "id": id, "from": city_id, "to": str(f["to"]), "length_km": 0.0})
	return out


## Legal next legs of a race from current_city (towards the next waypoint / finish).
## STUB: returns every connection; the data module implements detour-limited routing.
func next_options(race_id: String, current_city: String, waypoint_index: int, visited: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for leg in connections_from(current_city):
		if not visited.has(leg["to"]):
			out.append(leg)
	return out


## Races shown in menus (dev races hidden).
func visible_race_ids() -> Array[String]:
	var out: Array[String] = []
	for id in race_order:
		if not bool(races[id].get("dev", false)):
			out.append(id)
	return out


## Stages shown in the single-stage menu (dev stages hidden).
func visible_stage_ids() -> Array[String]:
	var out: Array[String] = []
	for id in stages:
		if not bool(stages[id].get("dev", false)):
			out.append(id)
	out.sort()
	return out


func validate() -> Array[String]:
	return warnings
