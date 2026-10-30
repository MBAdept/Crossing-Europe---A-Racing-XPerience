class_name WorldClock
extends RefCounted
## World time with time-lapse (1 h world = 5 game minutes, factor time.time_scale = 12).
## world_minutes is absolute (day 0 00:00 = 0). Owner: gameplay module.

var world_minutes := 0.0
var time_scale := 12.0


func setup(config: Dictionary, start_world_minutes: float) -> void:
	time_scale = float(ConfigLoader.lookup(config, "time.time_scale", 12.0))
	world_minutes = start_world_minutes


## Advance by real (game) seconds.
func advance(real_dt: float) -> void:
	world_minutes += real_dt * time_scale / 60.0


func hour() -> float:
	return Units.hour_of_day(world_minutes)


func day_index() -> int:
	return int(floor(world_minutes / 1440.0))


func text() -> String:
	return Units.format_clock(world_minutes)


## "night", "dawn", "day" or "dusk" for an hour of the day (config "daytime").
static func daytime_category(hour: float, config: Dictionary) -> String:
	var d: Dictionary = ConfigLoader.lookup(config, "daytime", {})
	var h := fposmod(hour, 24.0)
	if h < float(d.get("dawn_start", 5.0)) or h >= float(d.get("night_start", 20.5)):
		return "night"
	if h < float(d.get("day_start", 7.5)):
		return "dawn"
	if h < float(d.get("dusk_start", 18.0)):
		return "day"
	return "dusk"
