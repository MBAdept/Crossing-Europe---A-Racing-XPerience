class_name EnvironmentModel
extends RefCounted
## Numeric effects of time of day and weather – pure logic. Owner: gameplay module.
## (Colours/palettes belong to the renderer: scripts/race/palette.gd.)
## Rules, decisions and tuning numbers: docs/gameplay.md.
##
## Rules (design document "Tageszeit und Wetter"):
##  * weather normal/rain/snow lowers max speed (driving.weather_vmax_factor) and visibility
##    (weather.visibility_factor); night lowers visibility (weather.night_visibility_factor, per weather) and slightly
##    max speed (driving.night_vmax_factor), smoothly over dusk and dawn (config "daytime")
##  * rain + night still allows 220 km/h for the slowest car (230 km/h * 0.975 * 0.99 = 222) – police escape;
##    snow may prevent an escape
##  * grip (driving.weather_grip_factor) lowers the safe curve speed (VehicleModel.safe_curve_speed)
##  * race weather by weather.race_mode: region = weighted by the climate of the stage, random = uniform,
##    fixed = the stage's "weather" field (StagePlan.weather_hint)
##  * the next stage of a race starts time.stage_pause_hours after the end of the previous one

const WEATHER_TYPES := ["normal", "rain", "snow"]

var cfg: Dictionary = {}


func setup(config: Dictionary) -> void:
	cfg = config


func _f(path: String, default: float) -> float:
	return float(ConfigLoader.lookup(cfg, path, default))


## 0 = full day … 1 = full night, smooth over dawn (dawn_start..day_start) and dusk (dusk_start..night_start).
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


## Max-speed factor for weather and time of day (VehicleModel env.vmax_factor).
func vmax_factor(hour: float, weather: String) -> float:
	var w := _f("driving.weather_vmax_factor." + weather, 1.0)
	var n := lerpf(1.0, _f("driving.night_vmax_factor", 0.99), night_amount(hour))
	return w * n


## Grip factor of the weather (lowers the safe curve speed).
func grip(weather: String) -> float:
	return _f("driving.weather_grip_factor." + weather, 1.0)


## Multiplier for the draw distance (1 = clear day). In a tunnel only the tunnel lighting counts.
## Night: weather.night_visibility_factor – one number for every weather, or one per weather (snow brightens the
## night: with the halved braking in snow the sight must still cover the stopping distance to the slowest
## traffic, docs/gameplay.md (i6)).
func visibility_factor(hour: float, weather: String, in_tunnel: bool) -> float:
	if in_tunnel:
		return _f("weather.tunnel_visibility_factor", 0.4)
	var v := _f("weather.visibility_factor." + weather, 1.0)
	return v * lerpf(1.0, night_visibility_factor(weather), night_amount(hour))


## Visibility factor of a full night in this weather (weather.night_visibility_factor: a number or {weather: number}).
func night_visibility_factor(weather: String) -> float:
	var n: Variant = ConfigLoader.lookup(cfg, "weather.night_visibility_factor", 0.55)
	if n is Dictionary:
		return float((n as Dictionary).get(weather, (n as Dictionary).get("normal", 0.55)))
	return float(n)


## Deterministic weather for a race stage. climate: north|continental|alpine|mediterranean|default.
## weather.race_mode: "region" (weights weather.climate_weights[climate]), "random" (uniform),
## "fixed" (hint = the stage's weather field; falls back to "region" without a valid hint).
func pick_weather(seed: int, climate: String, hint: String = "") -> String:
	var mode := str(ConfigLoader.lookup(cfg, "weather.race_mode", "region"))
	var types := weather_types()
	if mode == "fixed" and types.has(hint):
		return hint
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := rng.randf()
	if mode == "random":
		return types[mini(int(r * types.size()), types.size() - 1)]
	var weights: Dictionary = ConfigLoader.lookup(cfg, "weather.climate_weights." + climate,
		ConfigLoader.lookup(cfg, "weather.climate_weights.default", {"normal": 1.0}))
	var total := 0.0
	for w in types:
		total += maxf(0.0, float(weights.get(w, 0.0)))
	if total <= 0.0:
		return "normal"
	var acc := 0.0
	for w in types:
		acc += maxf(0.0, float(weights.get(w, 0.0))) / total
		if r < acc:
			return w
	return types[types.size() - 1]


## Weather of a stage within a race: deterministic for (race seed, stage, leg index), using the stage's
## climate and weather hint according to weather.race_mode. The tutorial stage (StagePlan.tutorial) is driven in
## weather.tutorial_weather (dry; empty = race weather) – like RaceState.leg_weather in the menus.
func race_weather(plan: StagePlan, race_seed: int, leg_index: int = 0) -> String:
	if plan == null:
		return "normal"
	var tut := str(ConfigLoader.lookup(cfg, "weather.tutorial_weather", "normal"))
	if plan.tutorial and weather_types().has(tut):
		return tut
	var s := hash("%d:%s:%d:%d" % [race_seed, plan.stage_id, int(plan.reversed), leg_index]) & 0x7fffffff
	return pick_weather(s, plan.climate, plan.weather_hint)


## Weather ids from weather.types (default normal, rain, snow).
func weather_types() -> Array[String]:
	var out: Array[String] = []
	for w in ConfigLoader.lookup(cfg, "weather.types", WEATHER_TYPES):
		out.append(str(w))
	if out.is_empty():
		out.append("normal")
	return out


## World minutes at which the next stage of a race starts (stage end + time.stage_pause_hours).
## The pause does not count towards the race time.
static func next_stage_start(end_world_minutes: float, config: Dictionary) -> float:
	return end_world_minutes + float(ConfigLoader.lookup(config, "time.stage_pause_hours", 12.0)) * 60.0
