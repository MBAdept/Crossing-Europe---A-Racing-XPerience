class_name ConfigLoader
extends RefCounted
## Loads the central configuration (res://config/game_config.json) and merges optional
## overrides on top of it:
##   1. "game_config.json" next to the exported executable (only in exported builds)
##   2. "user://game_config.json"
## Overrides only need to contain the keys that change (deep merge).
## All helpers are static so pure game logic and headless tests can use them without autoloads.

const DEFAULT_PATH := "res://config/game_config.json"
const OVERRIDE_NAME := "game_config.json"

static var _cache: Dictionary = {}


static func load_merged(force_reload: bool = false) -> Dictionary:
	if not _cache.is_empty() and not force_reload:
		return _cache
	var base: Variant = load_json(DEFAULT_PATH)
	var merged: Dictionary = base if base is Dictionary else {}
	for p in override_paths():
		if FileAccess.file_exists(p):
			var o: Variant = load_json(p)
			if o is Dictionary:
				merged = deep_merge(merged, o)
				print("Config: Overrides geladen aus ", p)
			else:
				push_warning("Config: %s ist kein gültiges JSON-Objekt" % p)
	_cache = merged
	return _cache


static func override_paths() -> Array[String]:
	var paths: Array[String] = []
	if OS.has_feature("template"):
		paths.append(OS.get_executable_path().get_base_dir().path_join(OVERRIDE_NAME))
	paths.append("user://" + OVERRIDE_NAME)
	return paths


## Parses a JSON file. Returns null (and warns) on failure.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("JSON-Datei fehlt: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON-Fehler in %s (Zeile %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Recursively merges `over` into a deep copy of `base`. Dictionaries merge, everything else replaces.
static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = deep_merge(out[k], over[k])
		else:
			out[k] = over[k].duplicate(true) if (over[k] is Dictionary or over[k] is Array) else over[k]
	return out


## Reads a dotted path like "fuel.refuel_fixed_s" from a nested dictionary.
static func lookup(d: Dictionary, path: String, default: Variant = null) -> Variant:
	var cur: Variant = d
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return default
	return cur
