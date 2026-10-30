extends Node
## Autoload "Config": read access to the central configuration.
## Pure logic classes receive the dictionary (Config.data) explicitly instead of using this autoload.

var data: Dictionary = {}


func _init() -> void:
	data = ConfigLoader.load_merged()


func reload() -> void:
	data = ConfigLoader.load_merged(true)


func value(path: String, default: Variant = null) -> Variant:
	return ConfigLoader.lookup(data, path, default)


func f(path: String, default: float = 0.0) -> float:
	return float(value(path, default))


func i(path: String, default: int = 0) -> int:
	return int(value(path, default))


func section(path: String) -> Dictionary:
	var v: Variant = value(path, {})
	return v if v is Dictionary else {}
