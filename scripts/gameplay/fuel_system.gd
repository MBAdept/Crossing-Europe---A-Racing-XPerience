class_name FuelSystem
extends RefCounted
## Fuel, fuel stations, fuel lane and towing – pure logic. Owner: gameplay module.
## Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
##
## Rules (design document "Tanken"):
##  * consumption (L/100 km) = base + quad_coeff * v² (14 + 0.00034 v²), times the vehicle factor;
##    consumption counts odometer km
##  * stations from the StagePlan; announcements 30 / 15 / 5 km before (signal announced)
##  * fuel lane on the right = the last 1–2 km before the station (StagePlan.fuel_lanes).
##    In the lane and below 60 km/h the refuelling runs automatically: the car stops (control_request),
##    duration = refuel_fixed_s + refuel_s_per_5l per 5 litres; "Volltanken?" / "Gas = Weiterfahren";
##    pressing the throttle (a fresh press, not held) aborts and keeps the litres pumped so far
##  * empty tank: car rolls to a stop, tow service -> time penalty fuel.tow_penalty_s, refill to
##    fuel.tow_refill_fraction of the tank
## STUB: consumption/range/announcements only – the gameplay module implements lane/refuel/tow.

enum State { NORMAL, REFUELING, TOWING }

signal announced(km_before: int, station_km: float)
signal refuel_started
signal refuel_finished(liters: float, aborted: bool)
signal ran_dry
signal tow_finished(penalty_s: float)

var cfg: Dictionary = {}
var plan: StagePlan
var tank_l := 50.0
var fuel_l := 50.0
var consumption_factor := 1.0
var state: int = State.NORMAL
var refuel_progress := 0.0       ## 0..1 of the running refuel
var refuel_time_left := 0.0      ## seconds
var liters_added := 0.0          ## litres of the running/last refuel
var _penalty := 0.0
var _announced: Dictionary = {}


func setup(config: Dictionary, vehicle_spec: Dictionary, stage_plan: StagePlan) -> void:
	cfg = config
	plan = stage_plan
	tank_l = float(vehicle_spec.get("tank_l", ConfigLoader.lookup(config, "vehicles.base_tank_l", 50.0)))
	consumption_factor = float(vehicle_spec.get("consumption_factor", 1.0))
	fuel_l = tank_l * float(ConfigLoader.lookup(config, "fuel.start_fill_fraction", 1.0))
	state = State.NORMAL
	_announced.clear()


static func base_consumption(config: Dictionary, speed_kmh: float) -> float:
	return float(ConfigLoader.lookup(config, "fuel.base_l_per_100km", 14.0)) + float(ConfigLoader.lookup(config, "fuel.quad_coeff", 0.00034)) * speed_kmh * speed_kmh


## Litres per 100 odometer km at speed, for this vehicle.
func consumption_per_100km(speed_kmh: float) -> float:
	return base_consumption(cfg, speed_kmh) * consumption_factor


## Remaining range (odometer km) at the given speed.
func range_km(speed_kmh: float) -> float:
	return fuel_l / consumption_per_100km(maxf(speed_kmh, 60.0)) * 100.0


## Distance (km) to the next station ahead, -1 if none.
func distance_to_next_station(pos_km: float) -> float:
	var s := plan.next_station_km(pos_km) if plan else -1.0
	return s - pos_km if s >= 0.0 else -1.0


## Called every physics frame. delta_km = odometer km driven this frame.
func update(dt: float, pos_km: float, delta_km: float, speed_kmh: float, in_fuel_lane: bool, throttle: float) -> void:
	if state == State.NORMAL:
		fuel_l = maxf(0.0, fuel_l - consumption_per_100km(speed_kmh) * delta_km / 100.0)
		for s in plan.fuel_stations_km:
			for k in ConfigLoader.lookup(cfg, "fuel.announce_km", [30, 15, 5]):
				var key := "%d@%.2f" % [int(k), s]
				if not _announced.has(key) and pos_km >= s - float(k) and pos_km < s:
					_announced[key] = true
					announced.emit(int(k), s)


## Scripted control wanted by the fuel system: {} or {"target_kmh": float, "rate_kmh_s": float}.
func control_request() -> Dictionary:
	return {}


## Returns and clears the accumulated time penalty (towing) in seconds.
func take_penalty() -> float:
	var p := _penalty
	_penalty = 0.0
	return p
