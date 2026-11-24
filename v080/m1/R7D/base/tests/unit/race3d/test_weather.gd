extends TestCase
## R4 (contract §6 R4, §4.10, Rule 10): the pure parts of the weather layer (scripts/race3d/layers/weather.gd) and of
## the reflections of rear lamps on the wet road (layers/vehicles.gd). The pictures are judged by the render check
## tests/race3d/render/check_weather.gd.

const Weather := preload("res://scripts/race3d/layers/weather.gd")
const Vehicles := preload("res://scripts/race3d/layers/vehicles.gd")
const Flares := preload("res://scripts/race3d/layers/flares.gd")
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const TerrainBuilder := preload("res://scripts/race3d/builders/terrain.gd")

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



# --- FIX-R4 (QA-R4 B1, B4, B5) ----------------------------------------------------------------------------------------

## A synthetic path: level for 300 segments, then a steady climb of 4 %, then level again (the road ahead climbs
## towards a far car – QA-R4 B1).
func _climb_path() -> RoadPath3D:
	var n := 1400
	var curves := PackedFloat32Array()
	curves.resize(n)
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, SynTrack.grades(n, [[0, 0.0], [300, 0.04], [600, 0.0]]))
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	p.ensure(n - 2)
	return p


## The streak of a rear lamp follows the road: its profile is the road's height between the car and the camera, it
## goes into the basis of the instance (flare.gdshader CE_STREAK), and the strip has sections to bend over it.
func test_streak_follows_the_road_profile() -> void:
	var path := _climb_path()
	var prof := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var z_cam := 800.0          # level road below the climb (segments 300 … 600 of 3 m = 900 … 1800 m)
	var z_car := z_cam + 300.0  # the car 300 m ahead, 200 m up the climb
	Flares.road_profile(path, z_car, z_cam, path.z_min(), float(path.last()) * path.seg_len, prof)
	var h_car := path.height_at(z_car)
	for i in 6:
		var z := lerpf(z_car, z_cam, float(i + 1) / 6.0)
		assert_near(prof[i], path.height_at(z) - h_car, 1.0e-4, "Profil %d = Straßenhöhe dort minus am Auto" % i)
	assert_true(prof[5] < -3.0, "das Auto steht höher als die Kamera (Kamerafuß %.2f m tiefer)" % -prof[5])
	assert_true(prof[0] > prof[5], "das Profil fällt zur Kamera hin")
	# level road: a flat profile
	Flares.road_profile(path, 500.0, 200.0, path.z_min(), float(path.last()) * path.seg_len, prof)
	for i in 6:
		assert_near(prof[i], 0.0, 1.0e-4, "ebene Straße: flaches Profil")
	# the layout in the MultiMesh buffer: basis columns 0 and 1, column 2 x = 1
	var buf := PackedFloat32Array()
	buf.resize(40)
	buf.fill(-7.0)
	var pr := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
	Flares.put_profile(buf, 20, pr)
	assert_eq(Vector3(buf[20], buf[24], buf[28]), Vector3(1.0, 2.0, 3.0), "Spalte 0 = Profil 1–3")
	assert_eq(Vector3(buf[21], buf[25], buf[29]), Vector3(4.0, 5.0, 6.0), "Spalte 1 = Profil 4–6")
	assert_eq(Vector3(buf[22], buf[26], buf[30]), Vector3(1.0, 0.0, 0.0), "Spalte 2: x = 1 (Profil gegeben)")
	assert_eq(buf[23], -7.0, "der Ursprung (Lampe) bleibt unberührt")
	assert_eq(buf[19], -7.0, "die Instanz davor bleibt unberührt")
	# the strip
	var strip: ArrayMesh = Flares.streak_mesh()
	var verts: PackedVector3Array = strip.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), (Flares.STREAK_SECTIONS + 1) * 2, "Streifen mit %d Abschnitten" % Flares.STREAK_SECTIONS)
	assert_true(Flares.STREAK_SECTIONS >= 8, "genug Abschnitte, um einer Steigung zu folgen")


## The snow banks of a built chunk are never higher than 0.45 m above the ground under them (they can never hide a
## car) – measured on the mesh the builder makes, not on bank_height().
func test_snow_bank_mesh_height() -> void:
	assert_true(TerrainBuilder.BANK_MAX_M <= 0.45 + 1.0e-6, "BANK_MAX_M höchstens 0,45 m")
	var hmax := 0.0
	for k in 4000:
		hmax = maxf(hmax, TerrainBuilder.bank_height(k))
	assert_true(hmax <= 0.45 + 1.0e-6 and hmax > 0.1, "bank_height() 0,1–0,45 m (%.3f)" % hmax)
	var n := 800
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = 0.2 * sin(float(i) * 0.01)
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, SynTrack.grades(n, [[0, 0.02], [300, -0.03]]), {"hills": 2})
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), {})
	p.set_clear_reach(1842.0)
	p.ensure(n - 2)
	var top := 0.0
	var tris := 0
	for ci: int in [3, 8, 14]:
		var ctx := ChunkContext.new()
		ctx.cfg = cfg()
		ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
		var b := TerrainBuilder.new()
		var inp: Dictionary = b.collect(ctx)
		inp["snow"] = true
		var part: Dictionary = b.build(ctx, inp)
		tris += int(part.get("bank_tris", 0))
		top = maxf(top, float(part.get("bank_max_m", -1.0)))
	assert_true(tris > 0, "Schneewälle gebaut (%d Dreiecke)" % tris)
	assert_true(top > 0.1 and top <= 0.45 + 1.0e-4, "höchster Wallpunkt im Netz 0,1–0,45 m über dem Boden (%.3f m)" % top)


## The slowness watchdog stepped „Effekte“ down: the precipitation draws the lower count in the lower box.
func test_weather_follows_the_watchdog() -> void:
	var dummy := Node.new()
	var w: Node3D = Weather.new()
	w.call("setup", dummy)
	w.call("apply_quality", {"particles": 4000, "spray": true})
	w.call("prepare", {"weather": "rain"})
	var snap: Dictionary = (w.call("snapshot") as Dictionary)["weather"]
	assert_eq(int(snap["particles"]), 4000, "Voll: 4.000 Teilchen")
	assert_eq(int(snap["drawn"]), 4000, "… alle gezeichnet")
	w.call("quality_lowered", {"particles": 1500, "spray": false})
	snap = (w.call("snapshot") as Dictionary)["weather"]
	assert_eq(int(snap["particles"]), 1500, "nach dem Herabstufen: 1.500 Teilchen")
	assert_eq(int(snap["drawn"]), 1500, "… und nur so viele gezeichnet")
	assert_eq(int(snap["level"]), 1, "Stufe Einfach")
	var box: Vector3 = Weather.RAIN_BOX[1]
	assert_eq(snap["box"], [box.x, box.y, box.z], "im Kasten der Stufe")
	assert_false(bool(snap["spray_full"]), "Gischt der niedrigeren Stufe")
	assert_true(Weather.density("rain", 1, 1500) >= ARCADE_RAIN * 0.99, "auch dann mindestens Arcades Dichte")
	w.free()
	dummy.free()
