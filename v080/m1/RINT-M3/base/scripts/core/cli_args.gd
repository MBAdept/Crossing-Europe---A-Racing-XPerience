class_name CliArgs
extends RefCounted
## Parses user command line arguments (everything after "--"):
##   godot --path . -- --stage=kiel_hamburg --hour=21.5 --autopilot
## "--key=value" -> {"key": "value"}, "--flag" -> {"flag": true}. See ARCHITECTURE.md ("Debug-CLI").

static var _parsed: Dictionary = {}
static var _done := false


static func all() -> Dictionary:
	if not _done:
		_parsed = parse(OS.get_cmdline_user_args())
		_done = true
	return _parsed


static func parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out


static func has(key: String) -> bool:
	return all().has(key)


static func get_string(key: String, default: String = "") -> String:
	var v: Variant = all().get(key, default)
	return default if v is bool else str(v)


static func get_float(key: String, default: float = 0.0) -> float:
	var v: Variant = all().get(key, null)
	if v == null or v is bool:
		return default
	return float(v)


static func get_float_list(key: String) -> Array[float]:
	var out: Array[float] = []
	var s := get_string(key, "")
	if s == "":
		return out
	for part in s.split(",", false):
		out.append(float(part))
	return out
