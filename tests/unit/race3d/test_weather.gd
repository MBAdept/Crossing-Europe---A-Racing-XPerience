extends TestCase
## R4 (contract §6 R4, §4.10, Rule 10): the pure parts of the weather layer (scripts/race3d/layers/weather.gd) and of
## the reflections of rear lamps on the wet road (layers/vehicles.gd). The pictures are judged by the render check
## tests/race3d/render/check_weather.gd.

const Weather := preload("res://scripts/race3d/layers/weather.gd")
const Vehicles := preload("res://scripts/race3d/layers/vehicles.gd")
const Flares := preload("res://scripts/race3d/layers/flares.gd")

## Arcade's particles (RoadRenderer._draw_weather): 240 drops in 28 × 9 × 42 m, 420 flakes in 28 × 9 × 36 m
const ARCADE_RAIN := 240.0 / (28.0 * 9.0 * 42.0)
const ARCADE_SNOW := 420.0 / (28.0 * 9.0 * 36.0)


func test_kinds_and_levels() -> void:
	assert_eq(Weather.kind_of("rain"), "rain", "Regen")
	assert_eq(Weather.kind_of("snow"), "snow", "Schnee")
	assert_eq(Weather.kind_of("normal"), "", "klares Wetter: nichts in der Luft")
	assert_eq(Weather.level_of(300), 0, "300 Teilchen: Stufe Aus")
	assert_eq(Weather.level_of(1500), 1, "1.500: Einfach")
	assert_eq(Weather.level_of(4000), 2, "4.000: Voll")


func test_every_effects_level_shows_at_least_arcades_density() -> void:
	var levels: Array = ConfigLoader.lookup(cfg(), "graphics.levels.effects", [])
	assert_eq(levels.size(), 3, "drei Effekt-Stufen")
	for i in levels.size():
		var count := int((levels[i] as Dictionary).get("particles", 0))
		assert_true(count > 0, "Stufe %d hat Teilchen (%d)" % [i, count])
		var lv := Weather.level_of(count)
		var rain := Weather.density("rain", lv, count)
		var snow := Weather.density("snow", lv, count)
		assert_true(rain >= ARCADE_RAIN * 0.99, "Stufe %d: Regen %.4f je m³ ≥ Arcade %.4f" % [i, rain, ARCADE_RAIN])
		assert_true(snow >= ARCADE_SNOW * 0.99, "Stufe %d: Schnee %.4f je m³ ≥ Arcade %.4f" % [i, snow, ARCADE_SNOW])
		var box_r := Weather.box_for("rain", lv)
		var box_s := Weather.box_for("snow", lv)
		assert_true(box_r.x >= 14.0 and box_r.y <= 3.0 and box_r.z >= 45.0, "Regen mindestens in Arcades Raum (±14 m, 3 … 45 m)")
		assert_true(box_s.x >= 12.0 and box_s.y <= 2.0 and box_s.z >= 30.0, "Schnee nah um die Kamera (2 … 30 m und mehr)")


func test_spray_puffs() -> void:
	var rear := Vector3(1.0, 0.0, 10.0)
	var back := Vector3(0.0, 0.0, 1.0)
	var right := Vector3(1.0, 0.0, 0.0)
	var one: Array = Weather.spray_puffs(rear, back, right, 1.8, 0.5, false, false)
	assert_eq(one.size(), 1, "„Effekte: Aus“: eine Wolke wie Arcades Ellipse")
	var p: Array = one[0]
	assert_near((p[1] as Vector2).x, 1.8 * 0.75, 1.0e-5, "… so breit wie Arcades Ellipse (0,75 × Breite)")
	assert_true((p[0] as Vector3).z > rear.z and (p[0] as Vector3).y > 0.2, "hinter dem Heck, über der Straße")
	var full: Array = Weather.spray_puffs(rear, back, right, 1.8, 0.5, false, true)
	assert_eq(full.size(), 3, "voll: zwei Radfahnen und ein Schleier")
	var l: Vector3 = (full[0] as Array)[0]
	var r: Vector3 = (full[1] as Array)[0]
	assert_true(l.x < rear.x and r.x > rear.x, "je eine Fahne hinter dem linken und rechten Rad")
	var truck: Array = Weather.spray_puffs(rear, back, right, 2.55, 0.5, true, true)
	assert_true(((truck[2] as Array)[1] as Vector2).y > ((full[2] as Array)[1] as Vector2).y, "Lkw: größerer Schleier")
	var fast: Array = Weather.spray_puffs(rear, back, right, 1.8, 1.0, false, true)
	assert_true(((fast[2] as Array)[0] as Vector3).z > ((full[2] as Array)[0] as Vector3).z, "schneller: der Schleier zieht weiter nach hinten")


func test_streak_length() -> void:
	assert_eq(Vehicles.streak_length(0.0), Vehicles.STREAK_MIN_M, "nah: kurze Spiegelung")
	assert_eq(Vehicles.streak_length(1000.0), Vehicles.STREAK_MAX_M, "fern: höchstens STREAK_MAX_M")
	assert_true(Vehicles.streak_length(40.0) > Vehicles.streak_length(15.0), "mit der Entfernung länger")


func test_lamp_streak_fresnel() -> void:
	# a street lamp 8 m high, the chase camera 2.6 m above the road
	assert_true(Flares.streak_fresnel(10.0, 8.0, 2.6) < 0.1, "Laterne 10 m voraus: Spiegelpunkt steil unter der Kamera – schwach")
	assert_eq(Flares.streak_fresnel(200.0, 8.0, 2.6), 1.0, "ferne Laterne: volle Spiegelung")
	var last := 0.0
	for i in 40:
		var k := Flares.streak_fresnel(5.0 + float(i) * 5.0, 8.0, 2.6)
		assert_true(k >= last - 1.0e-6 and k <= 1.0, "wächst mit der Entfernung, höchstens 1")
		last = k
	assert_true(Flares.streak_fresnel(30.0, 0.9, 2.6) > Flares.streak_fresnel(30.0, 8.0, 2.6),
		"eine tiefe Lampe spiegelt in gleicher Entfernung weiter von der Kamera, also flacher gesehen")
