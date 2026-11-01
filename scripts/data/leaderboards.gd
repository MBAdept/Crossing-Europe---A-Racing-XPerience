extends Node
## Autoload "Leaderboards": local top lists per stage (and direction) and per race, saved as JSON.
## Board keys: "stage:<stage_id>:fwd|rev", "race:<race_id>".
## Entry: {name, time_s, avg_kmh, vehicle, weather, start_hour, daytime, date, route?(race boards), seeded?}
## Owner: data module. Logic in LeaderboardStore (scripts/data/leaderboard_store.gd): per-vehicle top lists,
## vehicle filter ("" / "all" / vehicle id), deterministic seeded entries, atomic versioned file.

const PATH := "user://leaderboards.json"

var store := LeaderboardStore.new()
## Raw boards (key -> sorted entries); kept for compatibility with the original stub.
var boards: Dictionary:
	get:
		return store.boards


func _ready() -> void:
	var lengths := Callable()
	var profiles := Callable()
	var gd := get_node_or_null("/root/GameData")
	if gd != null and gd.has_method("board_length_km"):
		lengths = Callable(gd, "board_length_km")
	if gd != null and gd.has_method("board_profile"):
		profiles = Callable(gd, "board_profile")
	store.setup(Config.data, PATH, lengths, profiles)
	load_boards()


func load_boards() -> void:
	store.load_boards()
	if store.load_problem != "":
		push_warning(store.load_problem)


func save_boards() -> void:
	store.save_boards()


## Top entries of a board, optionally only one vehicle type ("" or "all" = all vehicles).
func top(board_key: String, vehicle_filter: String = "", count: int = 10) -> Array[Dictionary]:
	return store.top(board_key, vehicle_filter, count)


func record(board_key: String, vehicle_filter: String = "") -> Dictionary:
	return store.record(board_key, vehicle_filter)


## 1-based rank the time would reach in the (filtered) top list, 0 = not in the top list.
func would_rank(board_key: String, time_s: float, vehicle_filter: String = "") -> int:
	return store.would_rank(board_key, time_s, vehicle_filter)


## Rank of a time within the list of one vehicle type (0 = not placed).
func rank_for_vehicle(board_key: String, time_s: float, vehicle: String) -> int:
	return store.rank_for_vehicle(board_key, time_s, vehicle)


## True if the time enters the overall list or its vehicle type's list (ask for the name).
func qualifies(board_key: String, time_s: float, vehicle: String) -> bool:
	return store.qualifies(board_key, time_s, vehicle)


## Inserts an entry; returns its 1-based rank in the list selected by vehicle_filter ("" = overall,
## 0 = not placed). Saves to disk.
func submit(board_key: String, entry: Dictionary, vehicle_filter: String = "") -> int:
	return store.submit(board_key, entry, vehicle_filter)


## Board keys that exist in memory/on disk (sorted).
func board_keys() -> Array[String]:
	return store.board_keys()
