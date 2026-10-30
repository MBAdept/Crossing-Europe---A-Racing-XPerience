class_name TrafficSystem
extends RefCounted
## Traffic in driving direction only, on fixed lanes – pure logic (no nodes, no autoloads).
## Owner: gameplay module. Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
##
## Rules (design document "Verkehr", "Kollisionen"):
##  * base speed per road type (traffic.speeds_kmh); trucks slower
##  * density follows the daily curve traffic.hourly_density (peaks 7–9 and 16–19, minimum 1–5)
##  * night 23–4: fewer vehicles and 15 % faster (traffic.night)
##  * during a police chase traffic is reduced by 80 % (ctx.chase)
##  * much more traffic in the City Limits (city_limits.density_factor)
##  * occasionally a car uses the fuel lane (traffic.fuel_lane_use_chance)
##  * cars overtaking from behind only collide once at least 1/3 of them is on screen
## The track object must provide (duck typing): length_z, lane_count_at(z), lane_center_x(z, lane),
## road_type_at(z), is_city_at(z), traffic_factor_at(z), fuel_lane_at(z), fuel_lane_x(z).
## STUB: simplified behaviour – the gameplay module replaces the internals.


class Car:
	var id := 0
	var z := 0.0              ## visual metres along the track (car centre)
	var x := 0.0              ## lateral metres (car centre)
	var lane := 0             ## current target lane (0 = leftmost); FUEL_LANE when using the fuel lane
	var speed := 120.0        ## km/h
	var cruise_speed := 120.0 ## desired speed
	var set_id := ""          ## sprite set id, e.g. "traffic/sedan_blue"
	var length := 4.5
	var width := 1.8
	var height := 1.5
	var heavy := false        ## truck/bus
	var braking := false      ## brake lights
	var in_fuel_lane := false


const FUEL_LANE := 99

var cfg: Dictionary = {}
var track: Object = null
var cars: Array[Car] = []
var car_sets: Array[String] = []
var heavy_sets: Array[String] = []
var rng := RandomNumberGenerator.new()
var _next_id := 1


## car_sets / heavy_sets: sprite set ids to choose from (SpriteDB tags "traffic" / "heavy").
func setup(config: Dictionary, track_api: Object, cars_ids: Array[String], heavy_ids: Array[String], seed: int) -> void:
	cfg = config
	track = track_api
	car_sets = cars_ids
	heavy_sets = heavy_ids
	rng.seed = seed
	cars.clear()


## player: {z, x, speed}; ctx: {hour: float, chase: bool, camera_z: float}
func update(dt: float, player: Dictionary, ctx: Dictionary) -> void:
	var pz := float(player.get("z", 0.0))
	for c in cars:
		c.z += c.speed / 3.6 * dt
		var lanes: int = track.lane_count_at(c.z)
		if c.lane >= lanes:
			c.lane = lanes - 1
		c.x = move_toward(c.x, track.lane_center_x(c.z, c.lane), float(ConfigLoader.lookup(cfg, "traffic.lane_change_mps", 2.5)) * dt)
	var behind := float(ConfigLoader.lookup(cfg, "traffic.despawn_behind_m", 220.0))
	var ahead := float(ConfigLoader.lookup(cfg, "traffic.spawn_ahead_m", 950.0))
	cars = cars.filter(func(c: Car) -> bool: return c.z > pz - behind and c.z < pz + ahead + 200.0 and c.z < track.length_z)
	var wanted := int(round(_target_count(pz, ctx)))
	if cars.size() < wanted:
		_spawn(pz + ahead * rng.randf_range(0.8, 1.0), ctx)


func _target_count(pz: float, ctx: Dictionary) -> float:
	var hour := float(ctx.get("hour", 12.0))
	var road: String = track.road_type_at(pz + 300.0)
	var per_km := float(ConfigLoader.lookup(cfg, "traffic.base_density_per_km." + road, 8.0))
	var f := density_factor(hour) * float(track.traffic_factor_at(pz + 300.0))
	if track.is_city_at(pz + 300.0):
		f *= float(ConfigLoader.lookup(cfg, "city_limits.density_factor", 2.5))
	if bool(ctx.get("chase", false)):
		f *= float(ConfigLoader.lookup(cfg, "traffic.chase_density_factor", 0.2))
	return per_km * f * float(ConfigLoader.lookup(cfg, "traffic.spawn_ahead_m", 950.0)) / 1000.0


func _spawn(z: float, ctx: Dictionary) -> void:
	if z >= track.length_z or car_sets.is_empty():
		return
	var lanes: int = track.lane_count_at(z)
	var lane := rng.randi_range(0, lanes - 1)
	for c in cars:
		if c.lane == lane and absf(c.z - z) < 40.0:
			return
	var road: String = track.road_type_at(z)
	var rangev: Array = ConfigLoader.lookup(cfg, "traffic.speeds_kmh." + road, [100, 130])
	var c := Car.new()
	c.id = _next_id
	_next_id += 1
	c.z = z
	c.lane = lane
	c.x = track.lane_center_x(z, lane)
	c.cruise_speed = rng.randf_range(float(rangev[0]), float(rangev[1])) * speed_factor(float(ctx.get("hour", 12.0)))
	c.speed = c.cruise_speed
	c.set_id = car_sets[rng.randi_range(0, car_sets.size() - 1)]
	cars.append(c)


## Daily density multiplier for an hour of the day (0..24).
func density_factor(hour: float) -> float:
	var curve: Array = ConfigLoader.lookup(cfg, "traffic.hourly_density", [1.0])
	var h := int(floor(fposmod(hour, 24.0))) % curve.size()
	var h2 := (h + 1) % curve.size()
	return lerpf(float(curve[h]), float(curve[h2]), fposmod(hour, 1.0))


## Speed multiplier (night: +15 %).
func speed_factor(hour: float) -> float:
	var n: Dictionary = ConfigLoader.lookup(cfg, "traffic.night", {})
	var hh := fposmod(hour, 24.0)
	var start := float(n.get("start_hour", 23.0))
	var end := float(n.get("end_hour", 4.0))
	var night := hh >= start or hh < end
	return float(n.get("speed_factor", 1.15)) if night else 1.0


## First car overlapping the player, or null. player: {z, x, length, width}.
## visible_fraction(dz_from_camera: float, height_m: float) -> float decides whether a car coming from
## behind is visible enough (collision.rear_min_visible_fraction) to collide.
func find_collision(player: Dictionary, camera_z: float, visible_fraction: Callable) -> Car:
	var pz := float(player.get("z", 0.0))
	var px := float(player.get("x", 0.0))
	var pl := float(player.get("length", 4.6))
	var pw := float(player.get("width", 1.85))
	for c in cars:
		if absf(c.z - pz) < (c.length + pl) * 0.5 and absf(c.x - px) < (c.width + pw) * 0.5:
			if c.z < pz and visible_fraction.call(c.z - c.length * 0.5 - camera_z, c.height) < float(ConfigLoader.lookup(cfg, "collision.rear_min_visible_fraction", 0.3333)):
				continue
			return c
	return null


## Free lateral metres left/right of a car of half length half_len at (z, x), limited by the road edges.
func space_beside(z: float, x: float, half_len: float, left_edge: float, right_edge: float) -> Vector2:
	var left := x - left_edge
	var right := right_edge - x
	for c in cars:
		if absf(c.z - z) < half_len + c.length * 0.5:
			if c.x < x:
				left = minf(left, x - c.x - c.width * 0.5)
			else:
				right = minf(right, c.x - x - c.width * 0.5)
	return Vector2(maxf(left, 0.0), maxf(right, 0.0))
