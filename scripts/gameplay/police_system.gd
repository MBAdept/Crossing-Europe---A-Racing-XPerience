class_name PoliceSystem
extends RefCounted
## Radar traps and police chases – pure logic. Owner: gameplay module.
## Public API = contract (ARCHITECTURE.md §Gameplay); extend, don't break.
##
## Rules (design document "Radar, Polizei und City Limits"):
##  * warning radar.warning_km before a radar zone, showing the limit (signal radar_warning)
##  * zone radar.zone_length_km long; triggers when speed > limit * (1 + tolerance) anywhere inside
##  * triggered -> flash + police chase. Escape possible when the average speed over
##    police.escape_window_s is >= police.escape_speed_kmh (220)
##  * during the chase traffic is reduced by 80 % (traffic_factor())
##  * caught: car brakes (control_request), stands police.stop_duration_s ("Führerschein, bitte!"),
##    then must accelerate from standstill. Effective loss about 15–20 s
##  * a chase can continue into the City Limits; no radar zones there (StagePlan guarantees that)
## STUB: no radar/chase logic – the gameplay module implements it.

enum State { IDLE, CHASE, STOPPING, STOPPED }

signal radar_warning(radar: Dictionary)
signal radar_zone(radar: Dictionary, entered: bool)
signal flashed(radar: Dictionary, speed_kmh: float)
signal chase_started
signal escaped
signal caught
signal released

var cfg: Dictionary = {}
var plan: StagePlan
var state: int = State.IDLE
var chase_time := 0.0
var gap_m := 0.0                 ## distance of the police car behind the player (visual m)
var escape_progress := 0.0       ## 0..1 (HUD)
var avg_speed := 0.0             ## rolling average over the escape window (km/h)
var stop_time_left := 0.0
var active_radar: Dictionary = {}


func setup(config: Dictionary, stage_plan: StagePlan) -> void:
	cfg = config
	plan = stage_plan
	state = State.IDLE


func update(dt: float, pos_km: float, speed_kmh: float) -> void:
	pass


func chase_active() -> bool:
	return state == State.CHASE or state == State.STOPPING


## Traffic density multiplier (0.2 during a chase).
func traffic_factor() -> float:
	return float(ConfigLoader.lookup(cfg, "traffic.chase_density_factor", 0.2)) if chase_active() else 1.0


## Scripted control wanted by the police: {} or {"target_kmh": 0.0, "rate_kmh_s": float}.
func control_request() -> Dictionary:
	return {}


## Position of the police car relative to the player in visual metres (negative = behind).
## NAN when no police car is around.
func police_car_offset_m() -> float:
	return NAN
