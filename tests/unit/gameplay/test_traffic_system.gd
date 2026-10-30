extends TestCase
## TrafficSystem: density/speed factors, spawning out of sight, car following, lane changes, merging,
## evading the player, fuel lane use, collision queries, determinism.

const Fx := preload("res://tests/sim/fixtures.gd")
const Sim := preload("res://tests/sim/gameplay_sim.gd")
const FakeTrack := preload("res://tests/sim/fake_track.gd")
const DT := 1.0 / 60.0

var _sets: Array[String] = ["traffic/sedan_blue", "traffic/hatch_green"]
var _heavy: Array[String] = ["traffic/truck_white"]


## Config without automatic traffic (cars are placed by the test).
func _empty_cfg(extra: Dictionary = {}) -> Dictionary:
	var o := {"traffic": {"base_density_per_km": {"autobahn": 0.0, "landstrasse": 0.0, "city": 0.0}, "cull_visible_fraction": 10.0}}
	return ConfigLoader.deep_merge(Fx.config(o), extra)


func _system(c: Dictionary, track: Object, seed: int = 7) -> TrafficSystem:
	var ts := TrafficSystem.new()
	ts.setup(c, track, _sets, _heavy, seed)
	return ts


## Places a car with a given cruise speed (speed_frac is chosen to give exactly that cruise speed).
func _car(ts: TrafficSystem, c: Dictionary, id: int, z: float, lane: int, kmh: float, heavy: bool = false) -> TrafficSystem.Car:
	var car := TrafficSystem.Car.new()
	car.id = id
	car.z = z
	car.lane = lane
	car.x = float(ts.track.lane_center_x(z, lane))
	car.speed = kmh
	car.heavy = heavy
	car.length = 16.5 if heavy else 4.5
	car.width = 2.5 if heavy else 1.8
	var road := str(ts.track.road_type_at(z))
	var r: Array = ConfigLoader.lookup(c, ("traffic.truck_speeds_kmh." if heavy else "traffic.speeds_kmh.") + road, [100, 130])
	car.speed_frac = (kmh - float(r[0])) / (float(r[1]) - float(r[0]))
	car.cruise_speed = kmh
	car.set_id = "traffic/truck_white" if heavy else "traffic/sedan_blue"
	ts.cars.append(car)
	return car


func test_daily_curve_and_night_speed() -> void:
	var c := cfg()
	var ts := _system(c, FakeTrack.new())
	var curve: Array = ConfigLoader.lookup(c, "traffic.hourly_density", [])
	assert_near(ts.density_factor(8.0), float(curve[8]), 0.0001, "08:00")
	assert_near(ts.density_factor(7.5), (float(curve[7]) + float(curve[8])) * 0.5, 0.0001, "interpoliert")
	var peak := maxf(ts.density_factor(8.0), ts.density_factor(17.0))
	for h in [1.0, 2.0, 3.0, 4.0]:
		assert_true(ts.density_factor(h) < peak * 0.25, "Minimum 1–5 Uhr (%d Uhr)" % int(h))
	for h in [7.5, 8.0, 8.5, 16.5, 17.0, 18.0]:
		assert_true(ts.density_factor(h) > ts.density_factor(12.0), "Spitze bei %.1f Uhr" % h)
	assert_near(ts.speed_factor(0.0), 1.15, 0.0001, "nachts +15 %")
	assert_near(ts.speed_factor(23.5), 1.15, 0.0001, "ab 23 Uhr")
	assert_near(ts.speed_factor(3.9), 1.15, 0.0001, "bis 4 Uhr")
	assert_near(ts.speed_factor(4.1), 1.0, 0.0001, "ab 4 Uhr normal")
	assert_near(ts.speed_factor(12.0), 1.0, 0.0001, "tagsüber normal")
	assert_true(ts.is_night_hour(23.0) and not ts.is_night_hour(22.9), "Nachtfenster")


func test_density_factors_section_city_chase() -> void:
	var c := cfg()
	var track := FakeTrack.new()
	track.set_sections([{"length": 5000.0, "road": "autobahn", "lanes": 3}, {"length": 5000.0, "road": "autobahn", "lanes": 3, "traffic": 1.5},
		{"length": 5000.0, "road": "landstrasse", "lanes": 2}])
	track.city_z = 12000.0
	var ts := _system(c, track)
	var base_a := float(ConfigLoader.lookup(c, "traffic.base_density_per_km.autobahn", 0.0))
	var base_c := float(ConfigLoader.lookup(c, "traffic.base_density_per_km.city", 0.0))
	var hourly := ts.density_factor(12.0)
	assert_near(ts.density_per_km_at(1000.0, 12.0, false), base_a * hourly, 0.0001, "Grunddichte * Tageskurve")
	assert_near(ts.density_per_km_at(6000.0, 12.0, false), base_a * hourly * 1.5, 0.0001, "Abschnittsfaktor")
	var city := float(ConfigLoader.lookup(c, "city_limits.density_factor", 2.5))
	assert_near(ts.density_per_km_at(13000.0, 12.0, false), base_c * hourly * city, 0.0001, "City Limits x2,5")
	assert_near(ts.density_per_km_at(1000.0, 12.0, true), base_a * hourly * 0.2, 0.0001, "Verfolgung -80 %")
	assert_eq(ts.density_per_km_at(-10.0, 12.0, false), 0.0, "vor dem Start kein Verkehr")


func test_cars_appear_and_vanish_only_out_of_sight() -> void:
	var c := cfg()
	# fast player (spawns ahead), slow player (spawns behind), stopping player, chase starting
	var fast := Sim.traffic_run(c, FakeTrack.new(40000.0), 8.0, 230.0, 40.0)
	var slow := Sim.traffic_run(c, FakeTrack.new(40000.0), 8.0, 60.0, 40.0)
	var chase := Sim.traffic_run(c, FakeTrack.new(60000.0), 17.0, 225.0, 45.0, {"chase_at": 15.0})
	for r: Dictionary in [fast, slow, chase]:
		assert_eq(int(r["pops_in"]), 0, "kein Auftauchen im Bild")
		assert_eq(int(r["pops_out"]), 0, "kein Verschwinden im Bild (außer tief im Nebel / unter dem Blitz)")
		assert_eq(int(r["overlaps"]), 0, "keine Überlappungen")
	assert_true(int(chase["hidden_culls"]) > 0, "Verfolgungsbeginn: überzählige Autos verschwinden unter dem Radarblitz")
	assert_true(int(fast["unique_cars"]) > 20 and int(slow["unique_cars"]) > 10, "es kommt Verkehr nach")


func test_cars_from_behind_are_faster_than_the_player() -> void:
	var c := cfg()
	var r := Sim.traffic_run(c, FakeTrack.new(40000.0), 12.0, 120.0, 40.0)
	var ts: TrafficSystem = r["system"]
	var behind := 0
	for car in ts.cars:
		if car.from_behind:
			behind += 1
			assert_true(car.cruise_speed > 120.0, "von hinten nur schnellere Autos (%.0f)" % car.cruise_speed)
	var fast := Sim.traffic_run(c, FakeTrack.new(40000.0), 12.0, 250.0, 20.0)
	for car in (fast["system"] as TrafficSystem).cars:
		assert_false(car.from_behind and car.age < 5.0, "bei 250 km/h kommt niemand von hinten")


func test_despawn_far_behind_and_far_ahead() -> void:
	var c := cfg()
	var r := Sim.traffic_run(c, FakeTrack.new(40000.0), 12.0, 250.0, 30.0)
	var ts: TrafficSystem = r["system"]
	var pz := 200.0 + 250.0 / 3.6 * 50.0
	var behind := float(ConfigLoader.lookup(c, "traffic.despawn_behind_m", 220.0))
	for car in ts.cars:
		assert_true(car.z > pz - behind - 10.0, "weit hinten entfernt")
	assert_true(ts.despawned_total >= 5, "überholte Autos werden entfernt (%d)" % ts.despawned_total)


func test_following_distance_and_brake_lights() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(30000.0, "landstrasse", 1)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var slow := _car(ts, c, 1, 400.0, 0, 70.0)
	var fast := _car(ts, c, 2, 250.0, 0, 100.0)
	var min_gap := float(ConfigLoader.lookup(c, "traffic.min_gap_m", 14.0))
	var braked := false
	var smallest := INF
	for i in 2400:
		ts.update(DT, {"z": fast.z - 100.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		braked = braked or fast.braking
		smallest = minf(smallest, slow.z - fast.z - 4.5)
	assert_true(braked, "Bremslicht beim Auffahren")
	assert_true(smallest >= min_gap * 0.9, "Abstand gehalten: %.1f m" % smallest)
	assert_near(fast.speed, slow.speed, 1.0, "folgt mit gleichem Tempo")
	var follow := float(ConfigLoader.lookup(c, "traffic.follow_time_s", 1.2))
	var gap := slow.z - fast.z - 4.5
	assert_true(gap >= min_gap + slow.speed / 3.6 * follow * 0.8, "Folgeabstand ~ min_gap + v * follow_time: %.1f m" % gap)


func test_overtakes_slower_car_and_keeps_right() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(30000.0, "autobahn", 2)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var truck := _car(ts, c, 1, 400.0, 1, 82.0, true)
	var car := _car(ts, c, 2, 280.0, 1, 140.0)
	var used_left := false
	for i in 3600:
		ts.update(DT, {"z": minf(truck.z, car.z) - 100.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		if car.lane == 0:
			used_left = true
	assert_true(used_left, "überholt links")
	assert_true(car.z > truck.z + 50.0, "ist vorbei")
	assert_eq(car.lane, 1, "fährt danach wieder rechts")
	assert_eq(truck.lane, 1, "Lkw bleibt rechts")


func test_merges_before_lane_ends() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new()
	track.set_sections([{"length": 3000.0, "road": "autobahn", "lanes": 3}, {"length": 20000.0, "road": "landstrasse", "lanes": 2}])
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var car := _car(ts, c, 1, 1800.0, 2, 120.0)
	var other := _car(ts, c, 2, 1820.0, 1, 120.0)
	var trans := float(track.lane_transition_m)
	var ok := true
	for i in 3000:
		ts.update(DT, {"z": minf(car.z, other.z) - 100.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		if car.z > 3000.0 - trans and car.lane >= 2:
			ok = false
	assert_true(ok, "vor dem Spurende eingefädelt")
	assert_true(car.lane <= 1 and other.lane <= 1, "beide auf den verbleibenden Spuren")
	assert_true(car.z > 3200.0 and other.z > 3200.0, "weitergefahren (Landstraßentempo)")
	assert_true(absf(car.z - other.z) > 10.0 or absf(car.x - other.x) > 3.0, "ohne Überlappung eingefädelt")
	var road_speed: Array = ConfigLoader.lookup(c, "traffic.speeds_kmh.landstrasse", [70, 100])
	assert_true(car.speed <= float(road_speed[1]) + 0.5, "Landstraßentempo übernommen")


func test_cars_avoid_the_stationary_player() -> void:
	var c := cfg()
	var r := Sim.traffic_run(c, FakeTrack.new(60000.0), 17.5, 0.0, 45.0, {"player_x": 0.0, "start_z": 3000.0})
	assert_eq(int(r["player_hits"]), 0, "kein Auto fährt in den stehenden Spieler")
	assert_true(int(r["unique_cars"]) > 10, "viele Autos sind vorbeigefahren")
	var city_track := FakeTrack.new(60000.0)
	city_track.city_z = 0.0
	var rc := Sim.traffic_run(c, city_track, 17.5, 0.0, 45.0, {"player_x": float(city_track.lane_center_x(3000.0, 1)), "start_z": 3000.0})
	assert_eq(int(rc["player_hits"]), 0, "auch in den City Limits")


func test_car_brakes_or_evades_when_player_cuts_in() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(30000.0, "autobahn", 2)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var car := _car(ts, c, 1, 1000.0, 1, 140.0)
	var pz := 1080.0
	var px := float(track.lane_center_x(pz, 1))
	var hits := 0
	var evaded := false
	var braked := false
	for i in 600:
		ts.update(DT, {"z": pz, "x": px, "speed": 60.0}, {"hour": 12.0, "camera_z": pz - 6.6})
		pz += 60.0 / 3.6 * DT
		if absf(car.z - pz) < 4.6 and absf(car.x - px) < 1.85:
			hits += 1
		evaded = evaded or car.lane == 0
		braked = braked or car.braking
	assert_eq(hits, 0, "kein Auffahren auf den langsameren Spieler")
	assert_true(evaded, "weicht auf die linke Spur aus")
	assert_true(car.z > pz, "hat den Spieler überholt")


func test_fuel_lane_use() -> void:
	var c := _empty_cfg({"traffic": {"fuel_lane_use_chance": 1.0}})
	var track := FakeTrack.new(30000.0, "landstrasse", 2)
	track.add_fuel_lane(3000.0, 3160.0)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var car := _car(ts, c, 1, 2300.0, 1, 95.0)
	var used := false
	var min_speed_in_lane := INF
	var centred := 0
	for i in 3600:
		ts.update(DT, {"z": car.z - 100.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		if car.in_fuel_lane:
			used = true
			min_speed_in_lane = minf(min_speed_in_lane, car.speed)
		if car.lane == TrafficSystem.FUEL_LANE and absf(car.x - float(track.fuel_lane_x(car.z))) < 0.3:
			centred += 1
			assert_true(car.z >= 3000.0 and car.z <= 3160.0, "nur innerhalb der Tankspur")
	var fuel_speed := float(ConfigLoader.lookup(c, "traffic.fuel_lane_speed_kmh", 50.0))
	assert_true(used, "nutzt die Tankspur")
	assert_true(centred > 120, "fährt mindestens 2 s mittig auf der Tankspur (%d Frames)" % centred)
	assert_near(min_speed_in_lane, fuel_speed, 6.0, "langsam auf der Tankspur")
	assert_false(car.in_fuel_lane, "danach wieder eingefädelt")
	assert_eq(car.lane, 1, "rechte Spur")
	assert_true(car.speed > 80.0, "beschleunigt wieder")
	# chance 0: nobody uses it
	var c0 := _empty_cfg({"traffic": {"fuel_lane_use_chance": 0.0}})
	var ts0 := _system(c0, track)
	ts0.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var car0 := _car(ts0, c0, 1, 2300.0, 1, 95.0)
	for i in 1500:
		ts0.update(DT, {"z": car0.z - 100.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		assert_false(car0.in_fuel_lane, "ohne Chance keine Tankspur")


func test_trucks_stay_right() -> void:
	var c := cfg()
	var r := Sim.traffic_run(c, FakeTrack.new(40000.0), 10.0, 180.0, 40.0)
	assert_true(int(r["heavy_seen"]) > 0, "Lkw unterwegs (%d)" % int(r["heavy_seen"]))
	assert_eq(int(r["heavy_lane0_frames"]), 0, "Lkw nie auf der linken Spur einer dreispurigen Autobahn")
	assert_true(float(r["heavy_right_share"]) > 0.6, "Lkw meist ganz rechts (%.2f)" % float(r["heavy_right_share"]))


func test_find_collision_and_rear_visibility_rule() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(30000.0, "autobahn", 3)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var player := {"z": 1000.0, "x": 0.0, "length": 4.6, "width": 1.85}
	var visible := func(_dz: float, _h: float) -> float: return 1.0
	var hidden := func(_dz: float, _h: float) -> float: return 0.2
	var ahead := _car(ts, c, 1, 1003.0, 1, 100.0)
	ahead.x = 0.5
	assert_eq(ts.find_collision(player, 993.4, hidden), ahead, "Auto vorn: Kollision unabhängig von der Sichtbarkeit")
	ahead.x = 3.0
	assert_eq(ts.find_collision(player, 993.4, visible), null, "daneben: keine Kollision")
	ts.cars.clear()
	var behind := _car(ts, c, 2, 997.5, 1, 160.0)
	behind.x = 0.6
	assert_eq(ts.find_collision(player, 993.4, hidden), null, "von hinten, kaum sichtbar: keine Kollision")
	assert_eq(ts.find_collision(player, 993.4, visible), behind, "von hinten, sichtbar: Kollision")
	# With the real camera: find the depth at which a third of the car becomes visible, then test
	# an overlapping car just before and just after that threshold (independent of camera tuning).
	var proj := RoadProjection.new()
	proj.setup(ConfigLoader.lookup(cfg(), "render", {}), Vector2(1280, 720))
	var cam_z := 1000.0 - proj.cam_distance
	var min_frac := float(ConfigLoader.lookup(cfg(), "collision.rear_min_visible_fraction", 0.3333))
	var dz_t := 0.0
	while dz_t < 20.0 and proj.visible_fraction(dz_t, behind.height) < min_frac:
		dz_t += 0.01
	var overlap := (behind.length + 4.6) * 0.5
	var hit: TrafficSystem.Car = null
	var z_hidden := cam_z + dz_t * 0.5 + behind.length * 0.5
	if absf(z_hidden - 1000.0) < overlap:
		behind.z = z_hidden
		hit = ts.find_collision(player, cam_z, proj.visible_fraction)
		assert_eq(hit, null, "mit echter Projektion: weniger als ein Drittel sichtbar")
	# else: the camera is so far behind the car that every overlapping car is already >= 1/3 visible
	behind.z = cam_z + dz_t + 0.4 + behind.length * 0.5
	assert_true(absf(behind.z - 1000.0) < overlap, "Testaufbau: Auto überlappt den Spieler (sichtbar)")
	hit = ts.find_collision(player, cam_z, proj.visible_fraction)
	assert_eq(hit, behind, "mit echter Projektion: zu mehr als einem Drittel sichtbar")


func test_space_beside() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(30000.0, "autobahn", 3)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var left_car := _car(ts, c, 1, 1001.0, 0, 120.0)
	var far_car := _car(ts, c, 2, 1100.0, 2, 120.0)
	var sp := ts.space_beside(1000.0, 0.0, 2.3, -8.125, 8.125)
	assert_near(sp.x, 3.75 - 0.9, 0.001, "links begrenzt durch das Auto daneben")
	assert_near(sp.y, 8.125, 0.001, "rechts bis zum Rand (Auto weit vorn zählt nicht)")
	assert_true(far_car.z > 1050.0 and left_car.x < 0.0, "Testaufbau")


func test_dimensions_from_manifest() -> void:
	var c := cfg()
	var track := FakeTrack.new(30000.0, "autobahn", 3)
	var ts := _system(c, track)
	ts.set_dimensions({"traffic/sedan_blue": {"object": {"length_m": 4.7, "width_m": 1.82, "height_m": 1.44}}})
	assert_eq(ts._dims_for("traffic/sedan_blue", false), Vector3(4.7, 1.82, 1.44), "Maße aus dem Manifest")
	assert_eq(ts._dims_for("traffic/truck_white", true).x, 16.5, "Lkw-Schätzung")


func test_deterministic_for_seed() -> void:
	var c := cfg()
	var a := Sim.traffic_run(c, FakeTrack.new(30000.0), 8.0, 150.0, 20.0, {"seed": 5, "warmup": 0.0})
	var b := Sim.traffic_run(c, FakeTrack.new(30000.0), 8.0, 150.0, 20.0, {"seed": 5, "warmup": 0.0})
	var d := Sim.traffic_run(c, FakeTrack.new(30000.0), 8.0, 150.0, 20.0, {"seed": 6, "warmup": 0.0})
	var ca := (a["system"] as TrafficSystem).cars
	var cb := (b["system"] as TrafficSystem).cars
	assert_eq(ca.size(), cb.size(), "gleiche Anzahl")
	var same := ca.size() == cb.size()
	for i in mini(ca.size(), cb.size()):
		if ca[i].id != cb[i].id or ca[i].z != cb[i].z or ca[i].x != cb[i].x or ca[i].speed != cb[i].speed or ca[i].set_id != cb[i].set_id:
			same = false
	assert_true(same, "gleicher Seed -> identischer Verkehr")
	var cd := (d["system"] as TrafficSystem).cars
	var differs := cd.size() != ca.size()
	for i in mini(ca.size(), cd.size()):
		if ca[i].z != cd[i].z:
			differs = true
	assert_true(differs, "anderer Seed -> anderer Verkehr")


func test_chase_and_city_change_visible_traffic() -> void:
	var c := cfg()
	var chase := Sim.traffic_run(c, FakeTrack.new(80000.0), 12.0, 225.0, 60.0, {"chase_at": 20.0, "settle": 15.0})
	assert_true(float(chase["avg_visible_after"]) < float(chase["avg_visible"]) * 0.4,
		"Verfolgung: %.1f -> %.1f sichtbare Autos" % [float(chase["avg_visible"]), float(chase["avg_visible_after"])])
	var night := Sim.traffic_run(c, FakeTrack.new(40000.0), 0.5, 160.0, 30.0)
	assert_near(float(night["speed_factor_unique"]), 1.15, 0.001, "nachts fährt jedes Auto 15 % schneller")
