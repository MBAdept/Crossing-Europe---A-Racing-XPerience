class_name Units
extends RefCounted
## Unit conventions (see ARCHITECTURE.md):
##  * speed: km/h
##  * stage distance ("km", odometer): advances time_scale (12) times faster than the visual road
##  * visual distance ("m", z): what the renderer scrolls; 1 km/h on the speedometer = 1 km/h visually
##  * game time: real seconds; world time: minutes, advancing time_scale times faster


static func kmh_to_mps(v_kmh: float) -> float:
	return v_kmh / 3.6


static func km_to_visual_m(km: float, time_scale: float) -> float:
	return km * 1000.0 / time_scale


static func visual_m_to_km(m: float, time_scale: float) -> float:
	return m * time_scale / 1000.0


## Odometer kilometres covered in dt real seconds.
static func odometer_km_delta(speed_kmh: float, dt: float, time_scale: float) -> float:
	return speed_kmh * dt * time_scale / 3600.0


## Visual metres covered in dt real seconds.
static func visual_m_delta(speed_kmh: float, dt: float) -> float:
	return speed_kmh / 3.6 * dt


## Real (game) seconds needed for distance_km at a constant speed. 100 km @ 100 km/h -> 300 s.
static func game_seconds_for(distance_km: float, speed_kmh: float, time_scale: float) -> float:
	if speed_kmh <= 0.0:
		return INF
	return distance_km / speed_kmh * 3600.0 / time_scale


## Average speed as shown in results/leaderboards (consistent with the speedometer).
static func avg_speed_kmh(distance_km: float, game_seconds: float, time_scale: float) -> float:
	if game_seconds <= 0.0:
		return 0.0
	return distance_km / (game_seconds * time_scale / 3600.0)


static func world_minutes_delta(game_seconds: float, time_scale: float) -> float:
	return game_seconds * time_scale / 60.0


static func hour_of_day(world_minutes: float) -> float:
	return fposmod(world_minutes, 1440.0) / 60.0


## "HH:MM" for an absolute world time in minutes.
static func format_clock(world_minutes: float) -> String:
	var m := int(floor(fposmod(world_minutes, 1440.0)))
	return "%02d:%02d" % [m / 60, m % 60]


## Race/stage time: "m:ss.cc" below one hour, otherwise "h:mm:ss.c".
static func format_race_time(seconds: float) -> String:
	if seconds < 0.0 or is_inf(seconds) or is_nan(seconds):
		return "--:--.--"
	var cs := int(round(seconds * 100.0))
	var h := cs / 360000
	var m := (cs / 6000) % 60
	var s := (cs / 100) % 60
	var c := cs % 100
	if h > 0:
		return "%d:%02d:%02d.%d" % [h, m, s, c / 10]
	return "%d:%02d.%02d" % [m, s, c]
