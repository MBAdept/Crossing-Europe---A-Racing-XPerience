extends Node
## Autoload "SaveGame": race progress, saved after every stage (user://savegame.json).
## Race state (owned by GameFlow): {race_id, vehicle, start_hour, current_city, waypoint_index,
##   legs: [{kind, id, from, to, time_s, avg_kmh, weather, start_world_minutes, end_world_minutes}],
##   total_time_s, world_minutes (start of the next stage), route: [city ids], seed}
## Owner: data module.

const PATH := "user://savegame.json"


func has_race() -> bool:
	return FileAccess.file_exists(PATH) and not load_race().is_empty()


func load_race() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var d: Variant = ConfigLoader.load_json(PATH)
	return d.get("race", {}) if d is Dictionary else {}


func save_race(state: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "race": state}, "\t"))


func clear_race() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
