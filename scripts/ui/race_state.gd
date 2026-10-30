class_name RaceState
extends RefCounted
## Pure race progression logic (no autoloads, unit tested): where the player is, which mandatory
## waypoint comes next, the legs driven so far, the race total (sum of stage times + fixed ferry
## times, pauses never count) and the world time at which the next leg starts.
## Serialised for SaveGame with to_dict()/from_dict() – format ARCHITECTURE.md §10 "Rennstand"
## (plus a few additional keys: race_name, version; legs also carry distance_km, penalty_s, name).
##
## Rules (design document "Tageszeit und Wetter", "Streckennetz, Etappen und Rennen"):
##  * next stage starts stage_pause_hours (12 h) world time after the end of the previous stage
##    (EnvironmentModel.next_stage_start) – the pause does not count towards the race time
##  * a ferry is a fixed intermediate time: fixed_time_s is added to the race total, world_hours
##    to the world clock; the next stage starts when the ferry arrives
##  * race finished = finish city reached after all mandatory waypoints

const VERSION := 1

var race_id := ""
var race_name := ""
var vehicle := ""
var start_hour := 8.0
var start_city := ""
var finish_city := ""
var waypoints: Array[String] = []
var current_city := ""
var waypoint_index := 0              ## index of the next mandatory waypoint (== waypoints.size() -> finish)
var legs: Array[Dictionary] = []     ## driven legs (see apply_stage_result / apply_ferry)
var total_time_s := 0.0              ## race time so far (stage times incl. penalties + ferry times)
var world_minutes := 0.0             ## absolute world time at which the next leg starts
var route: Array[String] = []        ## visited city ids in order (start city first)
var seed := 0


## New race from a race definition {id, name, start, finish, waypoints}.
static func create(race: Dictionary, vehicle_id: String, start_hour_value: float, race_seed: int) -> RaceState:
	var s := RaceState.new()
	s._read_race(race)
	s.race_id = str(race.get("id", ""))
	s.vehicle = vehicle_id
	s.start_hour = fposmod(start_hour_value, 24.0)
	s.current_city = s.start_city
	s.route.clear()
	s.route.append(s.start_city)
	s.world_minutes = s.start_hour * 60.0
	s.seed = race_seed
	s._advance_waypoints()
	return s


## Restores a saved race state. `race` is the race definition (for start/finish/waypoints).
static func from_dict(d: Dictionary, race: Dictionary = {}) -> RaceState:
	var s := RaceState.new()
	s._read_race(race)
	s.race_id = str(d.get("race_id", race.get("id", "")))
	if s.race_name == "":
		s.race_name = str(d.get("race_name", s.race_id))
	s.vehicle = str(d.get("vehicle", ""))
	s.start_hour = float(d.get("start_hour", 8.0))
	s.current_city = str(d.get("current_city", s.start_city))
	s.waypoint_index = int(d.get("waypoint_index", 0))
	s.seed = int(d.get("seed", 0))
	for l in d.get("legs", []):
		if l is Dictionary:
			s.legs.append((l as Dictionary).duplicate(true))
	for c in d.get("route", []):
		s.route.append(str(c))
	if s.route.is_empty():
		s.route.append(s.start_city if s.start_city != "" else s.current_city)
	s.world_minutes = float(d.get("world_minutes", s.start_hour * 60.0))
	s.total_time_s = float(d.get("total_time_s", 0.0))
	if not s.legs.is_empty():
		s.total_time_s = s.sum_leg_times()
	s.waypoint_index = clampi(s.waypoint_index, 0, s.waypoints.size())
	return s


func _read_race(race: Dictionary) -> void:
	race_name = str(race.get("name", race.get("id", "")))
	start_city = str(race.get("start", ""))
	finish_city = str(race.get("finish", ""))
	waypoints.clear()
	for w in race.get("waypoints", []):
		waypoints.append(str(w))


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"race_id": race_id,
		"race_name": race_name,
		"vehicle": vehicle,
		"start_hour": start_hour,
		"current_city": current_city,
		"waypoint_index": waypoint_index,
		"legs": legs.duplicate(true),
		"total_time_s": total_time_s,
		"world_minutes": world_minutes,
		"route": route.duplicate(),
		"seed": seed,
	}


func _advance_waypoints() -> void:
	while waypoint_index < waypoints.size() and waypoints[waypoint_index] == current_city:
		waypoint_index += 1


## City the race heads for next: the next mandatory waypoint, else the finish.
func next_target() -> String:
	return waypoints[waypoint_index] if waypoint_index < waypoints.size() else finish_city


func is_finished() -> bool:
	return waypoint_index >= waypoints.size() and current_city == finish_city and not legs.is_empty()


## Visited cities (for GameData.next_options).
func visited() -> Array:
	return route.duplicate()


func stage_legs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in legs:
		if str(l.get("kind", "stage")) == "stage":
			out.append(l)
	return out


func stage_count() -> int:
	return stage_legs().size()


## 1-based number of the stage that will be driven next.
func next_stage_number() -> int:
	return stage_count() + 1


func sum_leg_times() -> float:
	var t := 0.0
	for l in legs:
		t += float(l.get("time_s", 0.0))
	return t


func total_distance_km() -> float:
	var d := 0.0
	for l in stage_legs():
		d += float(l.get("distance_km", 0.0))
	return d


func driven_time_s() -> float:
	var t := 0.0
	for l in stage_legs():
		t += float(l.get("time_s", 0.0))
	return t


## Average speed over all driven stages (ferry time excluded), speedometer-consistent.
func average_kmh(time_scale: float) -> float:
	return Units.avg_speed_kmh(total_distance_km(), driven_time_s(), time_scale)


## Hour of day (0..24) at which the next leg starts.
func next_start_hour() -> float:
	return Units.hour_of_day(world_minutes)


func last_leg() -> Dictionary:
	return legs[-1] if not legs.is_empty() else {}


## Deterministic seed for the next stage (weather, traffic) – identical after save/continue.
func stage_seed(stage_id: String) -> int:
	return absi(hash("%d|%d|%s" % [seed, legs.size(), stage_id])) & 0x7fffffff


## Records a finished stage. leg = chosen option {kind, id, from, to, length_km};
## result = race session result (ARCHITECTURE.md §8). Returns the stored leg record.
func apply_stage_result(leg: Dictionary, result: Dictionary, config: Dictionary) -> Dictionary:
	var time_scale := float(ConfigLoader.lookup(config, "time.time_scale", 12.0))
	var time_s := float(result.get("time_s", 0.0))
	var start_min := float(result.get("start_world_minutes", world_minutes))
	var end_min := float(result.get("end_world_minutes", start_min + Units.world_minutes_delta(time_s, time_scale)))
	var rec := {
		"kind": "stage",
		"id": str(leg.get("id", result.get("stage_id", ""))),
		"from": str(leg.get("from", result.get("from_city", current_city))),
		"to": str(leg.get("to", result.get("to_city", ""))),
		"name": str(result.get("stage_name", "")),
		"time_s": time_s,
		"penalty_s": float(result.get("penalty_s", 0.0)),
		"avg_kmh": float(result.get("avg_speed_kmh", 0.0)),
		"distance_km": float(result.get("distance_km", leg.get("length_km", 0.0))),
		"weather": str(result.get("weather", "normal")),
		"daytime": str(result.get("daytime", "")),
		"start_world_minutes": start_min,
		"end_world_minutes": end_min,
	}
	legs.append(rec)
	total_time_s += time_s
	_arrive(str(rec["to"]))
	world_minutes = EnvironmentModel.next_stage_start(end_min, config)
	return rec


## Records a ferry crossing {id, from, to, name, fixed_time_s, world_hours}: fixed time counts,
## the world clock advances by world_hours, the next stage starts on arrival.
func apply_ferry(ferry: Dictionary, leg: Dictionary = {}) -> Dictionary:
	var fixed := float(ferry.get("fixed_time_s", 0.0))
	var hours := float(ferry.get("world_hours", 0.0))
	var to := str(leg.get("to", ferry.get("to", "")))
	var rec := {
		"kind": "ferry",
		"id": str(ferry.get("id", leg.get("id", ""))),
		"from": str(leg.get("from", ferry.get("from", current_city))),
		"to": to,
		"name": str(ferry.get("name", "")),
		"time_s": fixed,
		"penalty_s": 0.0,
		"avg_kmh": 0.0,
		"distance_km": 0.0,
		"weather": "",
		"start_world_minutes": world_minutes,
		"end_world_minutes": world_minutes + hours * 60.0,
	}
	legs.append(rec)
	total_time_s += fixed
	_arrive(to)
	world_minutes = float(rec["end_world_minutes"])
	return rec


func _arrive(city: String) -> void:
	current_city = city
	route.append(city)
	_advance_waypoints()


## Weather of a race stage, honouring weather.race_mode:
##   "region" (default) = EnvironmentModel.pick_weather(seed, climate), "random" = uniform,
##   "fixed" = the stage's "weather" field (normal if missing).
static func choose_weather(config: Dictionary, climate: String, weather_hint: String, weather_seed: int) -> String:
	var types: Array = ConfigLoader.lookup(config, "weather.types", ["normal", "rain", "snow"])
	var mode := str(ConfigLoader.lookup(config, "weather.race_mode", "region"))
	match mode:
		"fixed":
			return weather_hint if types.has(weather_hint) else "normal"
		"random":
			var rng := RandomNumberGenerator.new()
			rng.seed = weather_seed
			return str(types[rng.randi_range(0, types.size() - 1)]) if not types.is_empty() else "normal"
	var env := EnvironmentModel.new()
	env.setup(config)
	return env.pick_weather(weather_seed, climate)


## Enumerates complete routes from the race start to the finish. options_fn is
## Callable(race_id, current_city, waypoint_index, visited) -> Array of legs (GameData.next_options).
## Each route is an Array of legs. Bounded by max_routes / max_depth / max_calls (big tours).
static func enumerate_routes(race: Dictionary, options_fn: Callable, max_routes: int = 64, max_depth: int = 60, max_calls: int = 3000) -> Array:
	var probe := RaceState.create(race, "", 8.0, 0)
	var out: Array = []
	var budget := [max_calls]
	_dfs(probe.race_id, probe.finish_city, probe.waypoints, probe.current_city, probe.waypoint_index, probe.route.duplicate(), [], options_fn, out, max_routes, max_depth, budget)
	return out


static func _dfs(race_id: String, finish: String, wps: Array[String], city: String, wp_index: int, visited: Array, path: Array, options_fn: Callable, out: Array, max_routes: int, max_depth: int, budget: Array) -> void:
	if out.size() >= max_routes or int(budget[0]) <= 0:
		return
	if wp_index >= wps.size() and city == finish and not path.is_empty():
		out.append(path.duplicate())
		return
	if path.size() >= max_depth:
		return
	budget[0] = int(budget[0]) - 1
	var opts: Variant = options_fn.call(race_id, city, wp_index, visited)
	if not opts is Array:
		return
	for leg in opts:
		if not leg is Dictionary:
			continue
		var to := str(leg.get("to", ""))
		if to == "" or (visited.has(to) and to != finish):
			continue
		var idx := wp_index
		while idx < wps.size() and wps[idx] == to:
			idx += 1
		var v2: Array = visited.duplicate()
		v2.append(to)
		path.append(leg)
		_dfs(race_id, finish, wps, to, idx, v2, path, options_fn, out, max_routes, max_depth, budget)
		path.pop_back()
		if out.size() >= max_routes:
			return


## Length/stage-count range of enumerated routes: {count, min_km, max_km, min_stages, max_stages, ferry}.
static func route_stats(routes: Array) -> Dictionary:
	var st := {"count": routes.size(), "min_km": 0.0, "max_km": 0.0, "min_stages": 0, "max_stages": 0, "ferry": false}
	var first := true
	for r in routes:
		var km := 0.0
		var stages := 0
		for leg in r:
			if str(leg.get("kind", "stage")) == "ferry":
				st["ferry"] = true
			else:
				stages += 1
				km += float(leg.get("length_km", 0.0))
		if first:
			st["min_km"] = km
			st["max_km"] = km
			st["min_stages"] = stages
			st["max_stages"] = stages
			first = false
		else:
			st["min_km"] = minf(float(st["min_km"]), km)
			st["max_km"] = maxf(float(st["max_km"]), km)
			st["min_stages"] = mini(int(st["min_stages"]), stages)
			st["max_stages"] = maxi(int(st["max_stages"]), stages)
	return st
