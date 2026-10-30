extends Node
## Autoload "Leaderboards": local top lists per stage (and direction) and per race, saved as JSON.
## Board keys: "stage:<stage_id>:fwd|rev", "race:<race_id>".
## Entry: {name, time_s, avg_kmh, vehicle, weather, start_hour, daytime, date, route?(race boards)}
## Owner: data module. STUB: simple in-memory list + JSON file; replaced by the data module.

const PATH := "user://leaderboards.json"

var boards: Dictionary = {}   ## key -> Array[Dictionary] sorted by time_s


func _ready() -> void:
	load_boards()


func load_boards() -> void:
	boards.clear()
	if FileAccess.file_exists(PATH):
		var d: Variant = ConfigLoader.load_json(PATH)
		if d is Dictionary:
			boards = d.get("boards", {})


func save_boards() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "boards": boards}, "\t"))


## Top entries of a board, optionally only one vehicle type ("" or "all" = all vehicles).
func top(board_key: String, vehicle_filter: String = "", count: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in boards.get(board_key, []):
		if vehicle_filter == "" or vehicle_filter == "all" or e.get("vehicle", "") == vehicle_filter:
			out.append(e)
			if out.size() >= count:
				break
	return out


func record(board_key: String, vehicle_filter: String = "") -> Dictionary:
	var t := top(board_key, vehicle_filter, 1)
	return t[0] if not t.is_empty() else {}


## 1-based rank the time would reach in the (filtered) top list, 0 = not in the top list.
func would_rank(board_key: String, time_s: float, vehicle_filter: String = "") -> int:
	var list := top(board_key, vehicle_filter, 10)
	for i in list.size():
		if time_s < float(list[i]["time_s"]):
			return i + 1
	return list.size() + 1 if list.size() < 10 else 0


## Inserts an entry; returns its 1-based rank in the overall list (0 = not placed). Saves to disk.
func submit(board_key: String, entry: Dictionary) -> int:
	var list: Array = boards.get(board_key, [])
	list.append(entry)
	list.sort_custom(func(a, b): return float(a["time_s"]) < float(b["time_s"]))
	boards[board_key] = list
	save_boards()
	var rank := list.find(entry) + 1
	return rank if rank <= 10 else 0
