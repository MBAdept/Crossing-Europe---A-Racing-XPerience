extends Node
## Autoload "SaveGame": race progress, saved after every stage (user://savegame.json).
## Race state (owned by GameFlow): {race_id, vehicle, start_hour, current_city, waypoint_index,
##   legs: [{kind, id, from, to, time_s, avg_kmh, weather, start_world_minutes, end_world_minutes}],
##   total_time_s, world_minutes (start of the next stage), route: [city ids], seed}
## Owner: data module.
## File: {"version": 2, "saved_at": "...", "game_version": "...", "race": state}, written atomically
## (JsonFile: temp file + rename, previous version kept as .bak). Loading is robust: a missing or damaged
## file (or one without a usable race) falls back to the .bak copy, otherwise "no saved race".
## `path` can be changed (tests use a temporary file).

const PATH := "user://savegame.json"
const VERSION := 2
## Fields every race state gets on load (with these defaults) – numbers come back as the right type.
const DEFAULTS := {
	"race_id": "", "vehicle": "", "start_hour": 8.0, "current_city": "", "waypoint_index": 0, "legs": [],
	"total_time_s": 0.0, "world_minutes": 0.0, "route": [], "seed": 0,
}

var path := PATH


func has_race() -> bool:
	var r := load_race()
	if r.is_empty():
		return false
	# In the running game also check that race and city still exist in the (possibly updated) network.
	var gd: Node = get_node_or_null("/root/GameData") if is_inside_tree() else null
	if gd != null:
		return not (gd.get("races") as Dictionary).get(str(r["race_id"]), {}).is_empty() \
			and not (gd.get("cities") as Dictionary).get(str(r["current_city"]), {}).is_empty()
	return true


## Saved race state ({} if there is none). Missing fields are filled with defaults.
func load_race() -> Dictionary:
	for p in [path, path + JsonFile.BAK_SUFFIX]:
		var d: Variant = JsonFile.read(p)
		if d is Dictionary:
			var r := sanitize_state((d as Dictionary).get("race", null))
			if not r.is_empty():
				return r
	return {}


## Saves the race state atomically. Returns false if writing failed.
func save_race(state: Dictionary) -> bool:
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"race": state,
	}
	var ok := JsonFile.save_atomic(path, data)
	if not ok:
		push_warning("Spielstand konnte nicht gespeichert werden: " + path)
	return ok


func clear_race() -> void:
	JsonFile.remove_all(path)


## Normalized copy of a race state, {} if it is not usable (no race_id/current_city).
static func sanitize_state(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var r: Dictionary = (raw as Dictionary).duplicate(true)
	if str(r.get("race_id", "")) == "" or str(r.get("current_city", "")) == "":
		return {}
	for k: String in DEFAULTS:
		var def: Variant = DEFAULTS[k]
		var v: Variant = r.get(k, def)
		if def is String:
			r[k] = str(v)
		elif def is int:
			r[k] = int(v) if (v is float or v is int) else int(def)
		elif def is float:
			r[k] = float(v) if (v is float or v is int) else float(def)
		elif def is Array:
			r[k] = v if v is Array else []
	return r
