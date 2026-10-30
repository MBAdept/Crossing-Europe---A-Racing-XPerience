class_name WorldClock
extends RefCounted
## World time with time-lapse (1 h world = 5 game minutes, factor time.time_scale = 12):
## 10 game minutes = 2 world hours. world_minutes is absolute (day 0 00:00 = 0). Owner: gameplay module.
## Time penalties (towing) advance the clock as well (the race session calls advance(penalty)).

var world_minutes := 0.0
var time_scale := 12.0
# --- additions ---
var start_world_minutes := 0.0   ## world time at setup (stage start)


func setup(config: Dictionary, start_world_min: float) -> void:
	time_scale = float(ConfigLoader.lookup(config, "time.time_scale", 12.0))
	world_minutes = start_world_min
	start_world_minutes = start_world_min


## Advance by real (game) seconds.
func advance(real_dt: float) -> void:
	world_minutes += real_dt * time_scale / 60.0


## Hour of the day 0..24 (fractional).
func hour() -> float:
	return Units.hour_of_day(world_minutes)


## Day number since day 0 (stage pauses of 12 h move on to the next day).
func day_index() -> int:
	return int(floor(world_minutes / 1440.0))


## "HH:MM"
func text() -> String:
	return Units.format_clock(world_minutes)


## World minutes passed since setup.
func elapsed_world_minutes() -> float:
	return world_minutes - start_world_minutes


## Real (game) seconds that correspond to the world time passed since setup.
func elapsed_game_seconds() -> float:
	return elapsed_world_minutes() * 60.0 / maxf(time_scale, 0.0001)


## "night", "dawn", "day" or "dusk" for an hour of the day (config "daytime").
static func daytime_category(hour_of_day: float, config: Dictionary) -> String:
	var d: Dictionary = ConfigLoader.lookup(config, "daytime", {})
	var h := fposmod(hour_of_day, 24.0)
	if h < float(d.get("dawn_start", 5.0)) or h >= float(d.get("night_start", 20.5)):
		return "night"
	if h < float(d.get("day_start", 7.5)):
		return "dawn"
	if h < float(d.get("dusk_start", 18.0)):
		return "day"
	return "dusk"


## Absolute world minutes for a day index and an hour of the day.
static func world_minutes_at(day: int, hour_of_day: float) -> float:
	return float(day) * 1440.0 + hour_of_day * 60.0
