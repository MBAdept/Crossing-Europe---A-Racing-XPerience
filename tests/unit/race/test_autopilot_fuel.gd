extends TestCase
## Autopilot and the tank carried over in a race (v0.7.0, docs/renn-modul.md §10): the refuel decision at the last
## station of a race stage covers the next stage's first station (carry_km), and a carried tank too small for the next
## station at its pace makes it drive the economy pace – unless not even 60 km/h would get there (then it keeps its
## pace and rolls out of it into the fuel lane, check_session "dry_into_lane").

const Fx := preload("res://tests/sim/fixtures.gd")


func _fuel(c: Dictionary, plan: StagePlan, litres: float, factor: float = 1.0) -> FuelSystem:
	var f := FuelSystem.new()
	f.setup(c, {"tank_l": 60.0, "consumption_factor": factor}, plan, litres)
	return f


## 25 L at km 100, last station at km 110, finish at 150: enough for the finish (22.4 L with the margins at 235 km/h),
## not for 20 km more into the next stage (29.7 L) – a race stage refuels there, a single stage does not.
func test_last_station_covers_the_next_stage() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 150.0, [30.0, 110.0])
	var f := _fuel(c, plan, 25.0)
	var ap := Autopilot.new()
	ap.target_kmh = 235.0
	assert_false(ap._needs_fuel(f, plan, 100.0, 110.0), "Einzeletappe: reicht bis ins Ziel")
	ap.carry_km = float(ConfigLoader.lookup(c, "fuel.first_station_max_km", 20.0))
	assert_true(ap._needs_fuel(f, plan, 100.0, 110.0), "Rennen: auch die erste Tankstelle der nächsten Etappe")
	var single := Autopilot.new()
	single.target_kmh = 235.0
	assert_eq(ap._needs_fuel(f, plan, 20.0, 30.0), single._needs_fuel(f, plan, 20.0, 30.0), "vor der vorletzten Tankstelle zählt die nächste, nicht carry_km")


## Gran Turismo (×1.3) with 3 L, 12 km to the station: at 300 km/h it would need 7 L – the economy pace is the
## fastest that gets there with 0.5 L left (about 77 km/h). With 2 L not even 60 km/h would do: no economy pace (it
## keeps its pace and rolls into the lane); with 20 L the target pace is fine.
func test_economy_pace_to_the_next_station() -> void:
	var c := cfg()
	var plan := Fx.make_plan(c, 150.0, [12.0, 86.0])
	var ap := Autopilot.new()
	ap.target_kmh = 300.0
	var f := _fuel(c, plan, 3.0, 1.3)
	var eco := ap._eco_kmh(f, 12.0)
	assert_between(eco, 60.0, 100.0, "Spartempo %.0f km/h" % eco)
	assert_near(f.litres_for(12.0, eco), 2.5, 0.01, "mit 0,5 L Rest an der Tankstelle")
	assert_eq(ap._eco_kmh(_fuel(c, plan, 2.0, 1.3), 12.0), INF, "nicht einmal mit 60 km/h: kein Spartempo")
	assert_eq(ap._eco_kmh(_fuel(c, plan, 20.0, 1.3), 12.0), INF, "genug Sprit: Wunschtempo")
