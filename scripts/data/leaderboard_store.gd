class_name LeaderboardStore
extends RefCounted
## Leaderboard logic behind the Leaderboards autoload (pure, no autoload access – testable with a temp path).
## Owner: data module.
##  * Board keys: "stage:<stage_id>:fwd|rev", "race:<race_id>".
##  * Entry: {name, time_s, avg_kmh, vehicle, weather, start_hour, daytime, date, route? (race boards),
##    seeded? (true for generated default entries)}.
##  * Storage: per board one list sorted by time (ties: earlier entry first). With
##    leaderboard.store_per_vehicle every vehicle type keeps its own top `size` (so a filtered view is always
##    complete); otherwise only the overall top `size` is kept.
##  * Filter: "" or "all" = all vehicles, otherwise a vehicle id.
##  * Seeding (leaderboard.seed_entries): a board that has never been written gets `size` deterministic
##    default entries (names from seed_names, average speed within seed_avg_kmh, mixed vehicles) computed
##    from the board length (stage length / shortest race route) – so there is always a record to beat.
##    Review v0.5.0: from the make-up of the board (profile_provider, RoadNetwork.board_profile) – seed_avg_kmh is
##    the average of a typical stage (seed_ref_km with city_limits.length_km of City Limits); the City Limits of every
##    stage are driven at seed_city_kmh, the rest at the open-road speed that gives seed_avg_kmh on the typical stage,
##    plus seed_fuel_stop_s for each stage that starts with a partly filled tank (the tutorial's stop) and the ferry
##    times of a race. Short stages with their fixed 20 km of City Limits are no longer unreachable.
##  * File: {"version": 2, "boards": {key: [entries]}} written atomically (JsonFile); a corrupt file is kept
##    as "<path>.corrupt" and the store starts empty (or from the ".bak" copy).

const VERSION := 2
const ALL := "all"

var path := ""
var boards: Dictionary = {}          ## key -> Array of entry dictionaries, sorted by time_s
var size := 10
var store_per_vehicle := true
var seed_enabled := true
var seed_avg_kmh := Vector2(150.0, 190.0)
var seed_names: Array[String] = []
var vehicle_ids: Array[String] = []
var time_scale := 12.0
var daytime_cfg: Dictionary = {}
var length_provider: Callable        ## func(board_key: String) -> float (km); invalid = no seeding
## func(board_key: String) -> Dictionary {length_km, stages, fuel_stops, fixed_s} (RoadNetwork.board_profile);
## invalid or {} = seeding from the length only (as if one stage without stops)
var profile_provider: Callable
var seed_ref_km := 235.0             ## leaderboard.seed_ref_km: typical stage length for seed_avg_kmh
var seed_city_kmh := Vector2(60.0, 80.0)
var seed_fuel_stop_s := 35.0
var city_km := 20.0                  ## city_limits.length_km
var load_problem := ""               ## non-empty if the file could not be read


## cfg = merged configuration; file_path "" = memory only.
func setup(cfg: Dictionary, file_path: String, lengths: Callable = Callable(), profiles: Callable = Callable()) -> void:
	path = file_path
	length_provider = lengths
	profile_provider = profiles
	size = maxi(1, int(ConfigLoader.lookup(cfg, "leaderboard.size", 10)))
	store_per_vehicle = bool(ConfigLoader.lookup(cfg, "leaderboard.store_per_vehicle", true))
	seed_enabled = bool(ConfigLoader.lookup(cfg, "leaderboard.seed_entries", true))
	var avg: Variant = ConfigLoader.lookup(cfg, "leaderboard.seed_avg_kmh", [150, 190])
	if avg is Array and (avg as Array).size() >= 2:
		seed_avg_kmh = Vector2(float(avg[0]), float(avg[1]))
	var ck: Variant = ConfigLoader.lookup(cfg, "leaderboard.seed_city_kmh", [60, 80])
	if ck is Array and (ck as Array).size() >= 2:
		seed_city_kmh = Vector2(maxf(5.0, float(ck[0])), maxf(5.0, float(ck[1])))
	seed_ref_km = maxf(1.0, float(ConfigLoader.lookup(cfg, "leaderboard.seed_ref_km", 235.0)))
	seed_fuel_stop_s = maxf(0.0, float(ConfigLoader.lookup(cfg, "leaderboard.seed_fuel_stop_s", 35.0)))
	city_km = maxf(0.0, float(ConfigLoader.lookup(cfg, "city_limits.length_km", 20.0)))
	seed_names.clear()
	for n in ConfigLoader.lookup(cfg, "leaderboard.seed_names", []):
		seed_names.append(str(n))
	if seed_names.is_empty():
		seed_names.append("Fahrer")
	vehicle_ids.clear()
	for v in ConfigLoader.lookup(cfg, "vehicles.order", []):
		vehicle_ids.append(str(v))
	if vehicle_ids.is_empty():
		vehicle_ids.append("limousine")
	time_scale = float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var dt: Variant = ConfigLoader.lookup(cfg, "daytime", {})
	daytime_cfg = dt if dt is Dictionary else {}


# --- Persistence -----------------------------------------------------------------------------------

func load_boards() -> void:
	boards = {}
	load_problem = ""
	if path == "" or not (FileAccess.file_exists(path) or FileAccess.file_exists(path + JsonFile.BAK_SUFFIX)):
		return
	var main: Variant = JsonFile.read(path)
	var d: Dictionary = main if main is Dictionary else {}
	if not main is Dictionary and FileAccess.file_exists(path):
		load_problem = "Bestenlisten-Datei beschädigt – Sicherung gelesen"
		JsonFile.preserve_corrupt(path)
		d = JsonFile.load_dict(path)
	var version := int(d.get("version", 1)) if d.get("version", 1) is float or d.get("version", 1) is int else 1
	if version > VERSION:
		push_warning("Bestenlisten aus neuerer Version (%d) – lese kompatible Felder" % version)
	var raw: Variant = d.get("boards", {})
	if not raw is Dictionary:
		load_problem = "Bestenlisten-Datei ohne Listen"
		return
	for key: String in raw:
		var list: Variant = raw[key]
		if not list is Array:
			continue
		var clean: Array = []
		for e in list:
			var s := sanitize_entry(e)
			if not s.is_empty():
				clean.append(s)
		_sort(clean)
		boards[key] = _pruned(clean)


func save_boards() -> bool:
	if path == "":
		return true
	return JsonFile.save_atomic(path, {"version": VERSION, "boards": boards})


## Entry with the expected field types; {} if unusable (no positive finite time).
static func sanitize_entry(e: Variant) -> Dictionary:
	if not e is Dictionary:
		return {}
	var d: Dictionary = e
	var t: Variant = d.get("time_s", null)
	if not (t is float or t is int):
		return {}
	var time_s := float(t)
	if is_nan(time_s) or is_inf(time_s) or time_s <= 0.0:
		return {}
	var out := d.duplicate(true)
	out["time_s"] = time_s
	out["name"] = str(d.get("name", ""))
	out["vehicle"] = str(d.get("vehicle", ""))
	out["avg_kmh"] = float(d.get("avg_kmh", 0.0)) if (d.get("avg_kmh", 0.0) is float or d.get("avg_kmh", 0.0) is int) else 0.0
	out["weather"] = str(d.get("weather", "normal"))
	out["daytime"] = str(d.get("daytime", ""))
	out["date"] = str(d.get("date", ""))
	var sh: Variant = d.get("start_hour", 0.0)
	out["start_hour"] = float(sh) if (sh is float or sh is int) else 0.0
	return out


# --- Queries ---------------------------------------------------------------------------------------

## All stored entries of a board (seeded on first access), sorted by time.
func entries(board_key: String) -> Array:
	_ensure(board_key)
	return boards.get(board_key, [])


## Top entries of a board, optionally only one vehicle type ("" or "all" = all vehicles). count < 0 = size.
func top(board_key: String, vehicle_filter: String = "", count: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if count < 0:
		count = size
	count = mini(count, size)
	for e: Dictionary in entries(board_key):
		if _matches(e, vehicle_filter):
			out.append(e)
			if out.size() >= count:
				break
	return out


func record(board_key: String, vehicle_filter: String = "") -> Dictionary:
	var t := top(board_key, vehicle_filter, 1)
	return t[0] if not t.is_empty() else {}


## 1-based rank a new time would reach in the (filtered) top list, 0 = not in the top `size`.
## Equal times rank behind existing entries (consistent with submit()).
func would_rank(board_key: String, time_s: float, vehicle_filter: String = "") -> int:
	if is_nan(time_s) or is_inf(time_s) or time_s <= 0.0:
		return 0
	if not store_per_vehicle and not _matches({}, vehicle_filter) and would_rank(board_key, time_s, ALL) == 0:
		return 0   # only the overall list is stored – the entry would be dropped
	var better := 0
	for e: Dictionary in entries(board_key):
		if _matches(e, vehicle_filter) and float(e["time_s"]) <= time_s:
			better += 1
			if better >= size:
				return 0
	return better + 1


## Rank of a time within one vehicle type (0 = not in that type's top list).
func rank_for_vehicle(board_key: String, time_s: float, vehicle: String) -> int:
	return would_rank(board_key, time_s, vehicle)


## True if the time enters the overall top list or (store_per_vehicle) the list of its vehicle type –
## i.e. the player should be asked for a name.
func qualifies(board_key: String, time_s: float, vehicle: String) -> bool:
	if would_rank(board_key, time_s, ALL) > 0:
		return true
	return store_per_vehicle and vehicle != "" and would_rank(board_key, time_s, vehicle) > 0


## Inserts an entry and saves. Returns its 1-based rank in the list selected by vehicle_filter
## ("" / "all" = overall, a vehicle id = that type's list), 0 = not placed in that list.
## The return value equals would_rank(board_key, entry.time_s, vehicle_filter) before the call.
func submit(board_key: String, entry: Dictionary, vehicle_filter: String = "") -> int:
	var e := sanitize_entry(entry)
	if e.is_empty():
		return 0
	e.erase("seeded")
	var rank := would_rank(board_key, float(e["time_s"]), vehicle_filter)
	var list: Array = entries(board_key).duplicate()
	var pos := list.size()
	for i in list.size():
		if float(list[i]["time_s"]) > float(e["time_s"]):
			pos = i
			break
	list.insert(pos, e)
	boards[board_key] = _pruned(list)
	save_boards()
	return rank


## Removes all entries of a board (it will not be seeded again until reset_board()).
func clear_board(board_key: String) -> void:
	boards[board_key] = []
	save_boards()


## Forgets a board completely (seeded again on next access).
func reset_board(board_key: String) -> void:
	boards.erase(board_key)
	save_boards()


func board_keys() -> Array[String]:
	var out: Array[String] = []
	for k: String in boards:
		out.append(k)
	out.sort()
	return out


# --- Seeding ---------------------------------------------------------------------------------------

## Deterministic default entries for a board of length_km (empty if length_km <= 0). profile (RoadNetwork.board_profile):
## stages (City Limits each, default 1), fuel_stops, fixed_s (ferries) – see the class comment; {} = one stage.
func seed_entries_for(board_key: String, length_km: float, profile: Dictionary = {}) -> Array:
	var out: Array = []
	if length_km <= 0.0:
		return out
	var city := minf(length_km, city_km * float(maxi(1, int(profile.get("stages", 1)))))
	var extra_s := seed_fuel_stop_s * float(maxi(0, int(profile.get("fuel_stops", 0)))) + maxf(0.0, float(profile.get("fixed_s", 0.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = board_key.hash()
	var names := seed_names.duplicate()
	_shuffle(names, rng)
	var vehicles := vehicle_ids.duplicate()
	_shuffle(vehicles, rng)
	var speeds: Array[float] = []
	for i in size:
		var f := float(i) / float(maxi(size - 1, 1))
		var v := lerpf(seed_avg_kmh.y, seed_avg_kmh.x, f) + rng.randf_range(-1.5, 1.5)
		speeds.append(clampf(v, minf(seed_avg_kmh.x, seed_avg_kmh.y), maxf(seed_avg_kmh.x, seed_avg_kmh.y)))
	speeds.sort()
	speeds.reverse()
	for i in size:
		var f := float(i) / float(maxi(size - 1, 1))
		var hours := seed_hours(length_km, city, speeds[i], lerpf(seed_city_kmh.y, seed_city_kmh.x, f))
		var time_s := snappedf(hours * 3600.0 / time_scale + extra_s, 0.01)
		var weather_roll := rng.randf()
		var weather := "normal" if weather_roll < 0.8 else ("rain" if weather_roll < 0.95 else "snow")
		var hour := float(rng.randi_range(12, 40)) * 0.5
		var e := {
			"name": names[i % names.size()],
			"time_s": time_s,
			"avg_kmh": snappedf(length_km / (time_s * time_scale / 3600.0), 0.1),
			"vehicle": vehicles[i % vehicles.size()],
			"weather": weather,
			"start_hour": hour,
			"daytime": _daytime(hour),
			"date": "",
			"seeded": true,
		}
		if board_key.begins_with("race:"):
			e["route"] = []
		out.append(e)
	return out


## Hours (odometer km / km/h) of a seeded entry over length_km with city_len_km of City Limits: those at city_kmh, the rest at
## the open-road speed that makes a typical stage (seed_ref_km, city_limits.length_km of them City Limits) average
## avg_kmh – on that stage the time is exactly seed_ref_km / avg_kmh, as before the Review.
func seed_hours(length_km: float, city_len_km: float, avg_kmh: float, city_kmh: float) -> float:
	var ref_city := minf(city_km, seed_ref_km * 0.5)
	var open_h := maxf(seed_ref_km / maxf(avg_kmh, 1.0) - ref_city / maxf(city_kmh, 1.0), 0.001)
	var open_kmh := (seed_ref_km - ref_city) / open_h
	var c := clampf(city_len_km, 0.0, length_km)
	return (length_km - c) / open_kmh + c / maxf(city_kmh, 1.0)


func _ensure(board_key: String) -> void:
	if boards.has(board_key):
		return
	var list: Array = []
	if seed_enabled and length_provider.is_valid():
		var length: Variant = length_provider.call(board_key)
		if length is float or length is int:
			var profile: Dictionary = {}
			if profile_provider.is_valid():
				var p: Variant = profile_provider.call(board_key)
				profile = p if p is Dictionary else {}
			list = seed_entries_for(board_key, float(length), profile)
	boards[board_key] = list


func _daytime(hour: float) -> String:
	var dawn := float(daytime_cfg.get("dawn_start", 5.0))
	var day := float(daytime_cfg.get("day_start", 7.5))
	var dusk := float(daytime_cfg.get("dusk_start", 18.0))
	var night := float(daytime_cfg.get("night_start", 20.5))
	var h := fposmod(hour, 24.0)
	if h < dawn or h >= night:
		return "night"
	if h < day:
		return "dawn"
	if h >= dusk:
		return "dusk"
	return "day"


# --- Helpers ---------------------------------------------------------------------------------------

static func _matches(e: Dictionary, vehicle_filter: String) -> bool:
	return vehicle_filter == "" or vehicle_filter == ALL or str(e.get("vehicle", "")) == vehicle_filter


## Stable sort by time (insertion order breaks ties).
static func _sort(list: Array) -> void:
	for i in list.size():
		list[i]["_i"] = i
	list.sort_custom(_entry_before)
	for e in list:
		e.erase("_i")


static func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	if float(a["time_s"]) != float(b["time_s"]):
		return float(a["time_s"]) < float(b["time_s"])
	return int(a.get("_i", 0)) < int(b.get("_i", 0))


## Keeps the overall top `size` or (store_per_vehicle) the top `size` of every vehicle type.
func _pruned(sorted_list: Array) -> Array:
	var out: Array = []
	var per_vehicle := {}
	for e in sorted_list:
		if store_per_vehicle:
			var v := str(e.get("vehicle", ""))
			var n := int(per_vehicle.get(v, 0))
			if n >= size:
				continue
			per_vehicle[v] = n + 1
		elif out.size() >= size:
			break
		out.append(e)
	return out


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
