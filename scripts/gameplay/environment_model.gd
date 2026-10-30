class_name EnvironmentModel
extends RefCounted
## Numeric effects of time of day and weather – pure logic. Owner: gameplay module.
## (Colours/palettes belong to the renderer: scripts/race/palette.gd.)
##
## Rules (design document "Tageszeit und Wetter"):
##  * weather normal/rain/snow lowers max speed and visibility; night lowers visibility (and slightly
##    max speed) – factors in config driving.* and weather.*
##  * rain + night must still allow 220 km/h for the slowest car (230 km/h) – police escape
##  * race weather by weather.race_mode (region = weighted by climate)
##  * next stage of a race starts time.stage_pause_hours after the end of the previous one
## STUB: simplified – the gameplay module refines it.

var cfg: Dictionary = {}


func setup(config: Dictionary) -> void:
	cfg = config


## 0 = full day … 1 = full night, smooth over dawn/dusk.
func night_amount(hour: float) -> float:
	var d: Dictionary = ConfigLoader.lookup(cfg, "daytime", {})
	var h := fposmod(hour, 24.0)
	var dawn0 := float(d.get("dawn_start", 5.0))
	var day0 := float(d.get("day_start", 7.5))
	var dusk0 := float(d.get("dusk_start", 18.0))
	var night0 := float(d.get("night_start", 20.5))
	if h < dawn0 or h >= night0:
		return 1.0
	if h < day0:
		return 1.0 - smoothstep(dawn0, day0, h)
	if h < dusk0:
		return 0.0
	return smoothstep(dusk0, night0, h)


func is_night(hour: float) -> bool:
	return night_amount(hour) > 0.5


func vmax_factor(hour: float, weather: String) -> float:
	var w := float(ConfigLoader.lookup(cfg, "driving.weather_vmax_factor." + weather, 1.0))
	var n := lerpf(1.0, float(ConfigLoader.lookup(cfg, "driving.night_vmax_factor", 0.985)), night_amount(hour))
	return w * n


func grip(weather: String) -> float:
	return float(ConfigLoader.lookup(cfg, "driving.weather_grip_factor." + weather, 1.0))


## Multiplier for the draw distance (1 = clear day).
func visibility_factor(hour: float, weather: String, in_tunnel: bool) -> float:
	var v := float(ConfigLoader.lookup(cfg, "weather.visibility_factor." + weather, 1.0))
	if in_tunnel:
		return minf(v, float(ConfigLoader.lookup(cfg, "weather.tunnel_visibility_factor", 0.4)) * 1.0)
	return v * lerpf(1.0, float(ConfigLoader.lookup(cfg, "weather.night_visibility_factor", 0.55)), night_amount(hour))


## Deterministic weather for a race stage.
func pick_weather(seed: int, climate: String) -> String:
	var weights: Dictionary = ConfigLoader.lookup(cfg, "weather.climate_weights." + climate, ConfigLoader.lookup(cfg, "weather.climate_weights.default", {"normal": 1.0}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := rng.randf()
	var acc := 0.0
	for w in ["normal", "rain", "snow"]:
		acc += float(weights.get(w, 0.0))
		if r < acc:
			return w
	return "normal"


static func next_stage_start(end_world_minutes: float, config: Dictionary) -> float:
	return end_world_minutes + float(ConfigLoader.lookup(config, "time.stage_pause_hours", 12.0)) * 60.0
