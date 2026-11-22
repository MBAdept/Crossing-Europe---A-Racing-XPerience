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
	# v0.5.0: no night speed bonus any more (faster traffic made overtaking even easier); the factor stays tunable
	var night := float(ConfigLoader.lookup(c, "traffic.night.speed_factor", 1.0))
	assert_near(night, 1.0, 0.0001, "nachts kein Tempobonus")
	assert_near(ts.speed_factor(0.0), night, 0.0001, "nachts")
	assert_near(ts.speed_factor(23.5), night, 0.0001, "ab 23 Uhr")
	assert_near(ts.speed_factor(3.9), night, 0.0001, "bis 4 Uhr")
	assert_near(ts.speed_factor(4.1), 1.0, 0.0001, "ab 4 Uhr normal")
	assert_near(ts.speed_factor(12.0), 1.0, 0.0001, "tagsüber normal")
	var tuned := _system(Fx.config({"traffic": {"night": {"speed_factor": 1.15}}}), FakeTrack.new())
	assert_near(tuned.speed_factor(0.0), 1.15, 0.0001, "per Konfiguration weiter einstellbar")
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


## Review v0.5.0: in snow the traffic braked with up to 8 m/s² – nearly the player's whole snow braking (9.7). Now its
## braking follows the weather (traffic.weather.<w>.decel_factor, snow × 0.5: at most 4 m/s², comfortable 1.25),
## it starts earlier and still stops behind a standing car; behind the player the dry limit stays (he may brake
## hard or cut in – nobody runs into him).
func test_traffic_brakes_softer_in_snow() -> void:
	var c := _empty_cfg()
	var max_dry := float(ConfigLoader.lookup(c, "traffic.max_decel_mps2", 8.0))
	var f_snow := float(ConfigLoader.lookup(c, "traffic.weather.snow.decel_factor", 1.0))
	assert_between(f_snow, 0.4, 0.6, "Schnee etwa halbe Bremsung wie beim Spieler")
	var out := {}
	for weather in ["normal", "snow"]:
		var track := FakeTrack.new(30000.0, "landstrasse", 1)
		var ts := _system(c, track)
		var ctx := {"hour": 12.0, "weather": weather}
		ts.update(0.0, {"z": 900.0, "x": -60.0, "speed": 0.0}, ctx)
		var stopped := _car(ts, c, 1, 1130.0, 0, 0.0)
		var car := _car(ts, c, 2, 1000.0, 0, 90.0)
		var peak := 0.0
		var gap_min := INF
		for i in 900:
			var v0 := car.speed
			ts.update(DT, {"z": 900.0, "x": -60.0, "speed": 0.0}, ctx)
			stopped.z = 1130.0   # a car standing in the lane (pinned)
			stopped.speed = 0.0
			peak = maxf(peak, (v0 - car.speed) / 3.6 / DT)
			gap_min = minf(gap_min, stopped.z - car.z - 4.5)
		out[weather] = peak
		assert_true(gap_min > 2.0, "%s: hält hinter dem stehenden Auto (%.1f m)" % [weather, gap_min])
		assert_true(car.speed < 1.0, "%s: steht (%.1f km/h)" % [weather, car.speed])
	assert_true(float(out["snow"]) <= max_dry * f_snow + 0.05, "Schnee höchstens %.1f m/s²: %.2f" % [max_dry * f_snow, float(out["snow"])])
	assert_true(float(out["normal"]) <= max_dry + 0.05, "trocken höchstens %.1f m/s²: %.2f" % [max_dry, float(out["normal"])])
	# behind the player (standing in the lane) the dry limit applies: no car runs into him, also in snow
	var track2 := FakeTrack.new(30000.0, "landstrasse", 1)
	var ts2 := _system(c, track2)
	var ctx2 := {"hour": 12.0, "weather": "snow"}
	var pz := 1100.0
	var px := float(track2.lane_center_x(pz, 0))
	ts2.update(0.0, {"z": pz, "x": px, "speed": 0.0}, ctx2)
	var car2 := _car(ts2, c, 3, 1000.0, 0, 90.0)
	var peak2 := 0.0
	var gap2 := INF
	for i in 900:
		var v0 := car2.speed
		ctx2["camera_z"] = pz - 9.0
		ts2.update(DT, {"z": pz, "x": px, "speed": 0.0}, ctx2)
		peak2 = maxf(peak2, (v0 - car2.speed) / 3.6 / DT)
		gap2 = minf(gap2, pz - car2.z - 4.6)
	assert_true(gap2 > 0.0, "fährt nicht in den Spieler (%.1f m)" % gap2)
	assert_true(peak2 > max_dry * f_snow + 0.5, "hinter dem Spieler darf es stärker bremsen: %.2f m/s²" % peak2)


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


## Zipper at a lane drop (QA v0.5.0: cars stopped unannounced at the end of the right lane before the City Limits, the
## middle lane stood behind them): the car that must leave its lane signals at once (signal_merge) and waits for the
## gap, the car behind it in the target lane opens the gap – it merges while moving, nobody stops.
func test_zipper_at_a_lane_drop() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new()
	track.set_sections([{"length": 3000.0, "road": "autobahn", "lanes": 3}, {"length": 20000.0, "road": "autobahn", "lanes": 2}])
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var merger := _car(ts, c, 1, 2440.0, 2, 110.0)
	# middle lane: a column at the merger's speed, the merger level with a gap that is too short
	var column: Array[TrafficSystem.Car] = []
	for k in 6:
		column.append(_car(ts, c, 10 + k, 2470.0 - 30.0 * float(k), 1, 110.0))
	var trans := float(track.lane_transition_m)
	var signalled_at := -1.0
	var min_speed := INF
	var t := 0.0
	for i in 1800:
		ts.update(DT, {"z": merger.z - 250.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		t += DT
		if signalled_at < 0.0 and merger.signal_merge:
			signalled_at = merger.z
		for car in column:
			min_speed = minf(min_speed, car.speed)
		min_speed = minf(min_speed, merger.speed)
		if merger.lane <= 1 and absf(merger.x - track.lane_center_x(merger.z, 1)) < 0.4:
			break
	assert_true(signalled_at > 0.0 and signalled_at < 3000.0 - trans - 100.0,
		"blinkt früh (%.0f m vor dem Spurende)" % (3000.0 - trans - signalled_at))
	assert_true(merger.lane <= 1, "eingefädelt")
	assert_true(merger.z < 3000.0, "vor dem Ende der Spur (%.0f)" % merger.z)
	assert_true(min_speed > 30.0, "niemand bleibt stehen (min %.0f km/h)" % min_speed)


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
	# a car in line (directly ahead, a few cm to either side) is not beside: it blocks neither side
	var ahead := _car(ts, c, 3, 1004.5, 1, 60.0)
	for off: float in [0.02, -0.02]:
		ahead.x = off
		var s2 := ts.space_beside(1000.0, 0.0, 2.3, -8.125, 8.125)
		assert_near(s2.y, 8.125, 0.001, "Auto genau vorn (%+.2f m) sperrt rechts nicht" % off)
		assert_near(s2.x, 3.75 - 0.9, 0.001, "links weiter nur das Auto daneben")
	# a car offset by more than half its width is beside and blocks its side
	ahead.x = 1.2
	assert_near(ts.space_beside(1000.0, 0.0, 2.3, -8.125, 8.125).y, 1.2 - 0.9, 0.001, "versetzt: blockiert rechts")
	assert_near(ts.space_beside(1000.0, 0.0, 2.3, -8.125, 8.125, ahead).y, 8.125, 0.001, "exclude: getroffenes Auto zählt nicht")


## COLL-1 end to end (TrafficSystem + VehicleModel, the same calls as the race session): the player rear-ends
## the car ahead in its own lane exactly from behind (a few cm offset either way). The push goes to the side
## with more free road incl. shoulder and other cars beside – never decided by the cm offset – and equal space
## (± collision.equal_space_tolerance_m) goes LEFT.
func test_centre_hit_pushes_to_side_with_more_space() -> void:
	var c := _empty_cfg()
	# [lanes, road, player lane, player offset (m), car beside in lane (-1 = none), fuel lane open, expected]
	var cases := [
		[3, "autobahn", 2, 0.03, -1, false, -1],    # right lane: 11.9 m left vs 4.4 m right
		[3, "autobahn", 2, -0.03, -1, false, -1],
		[3, "autobahn", 0, 0.03, -1, false, 1],     # left lane: more space on the right
		[3, "autobahn", 0, -0.03, -1, false, 1],
		[3, "autobahn", 1, 0.03, -1, false, -1],    # middle lane: equal space -> left
		[3, "autobahn", 1, -0.03, -1, false, -1],
		[3, "autobahn", 1, -0.03, 0, false, 1],     # middle lane, car beside on the left -> right
		[3, "autobahn", 1, 0.03, 2, false, -1],     # middle lane, car beside on the right -> left
		[3, "autobahn", 2, 0.03, -1, true, -1],     # right lane next to an open fuel lane: 11.9 vs 8.1 -> left
		[2, "landstrasse", 1, 0.03, -1, false, -1], # two lanes, right lane -> left
		[2, "landstrasse", 0, -0.03, -1, false, 1], # two lanes, left lane -> right
	]
	for k in cases.size():
		var cs: Array = cases[k]
		for use_exclude: bool in [true, false]:
			var track := FakeTrack.new(30000.0, str(cs[1]), int(cs[0]))
			var pz := 1000.0
			if bool(cs[5]):
				track.add_fuel_lane(900.0, 1300.0)
			var ts := _system(c, track)
			ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
			var lane := int(cs[2])
			var hit_car := _car(ts, c, 1, pz + 15.0, lane, 60.0)
			hit_car.lane_cooldown = 1000.0   # keep it in its lane (no lane changes during the test)
			if int(cs[4]) >= 0:
				var beside := _car(ts, c, 2, pz, int(cs[4]), 150.0)
				beside.lane_cooldown = 1000.0
			var v := Fx.vehicle(c, "limousine")
			v.speed = 150.0
			v.x = float(track.lane_center_x(pz, lane)) + float(cs[3])
			var dir := 0
			for i in 240:
				v.update(DT, {"throttle": 1.0}, track.road_info(pz), {"vmax_factor": 1.0})
				pz += v.speed / 3.6 * DT
				ts.update(DT, {"z": pz, "x": v.x, "speed": v.speed}, {"hour": 12.0, "camera_z": pz - 9.0})
				var hit := ts.find_collision({"z": pz, "x": v.x, "length": v.length_m, "width": v.width_m}, pz - 9.0, Callable())
				if hit != null:
					assert_eq(hit, hit_car, "Fall %d: das Auto vorn getroffen" % k)
					assert_true(absf(v.x - hit.x) <= 0.25 * v.width_m, "Fall %d: Treffer mittig (dx %.3f)" % [k, v.x - hit.x])
					var e: Vector2 = track.road_edges_at(pz)
					var space := ts.space_beside(pz, v.x, v.length_m * 0.5, e.x - track.shoulder_w, e.y + track.shoulder_w, hit if use_exclude else null)
					v.start_crash(hit.x, space.x, space.y)
					dir = v.crash_dir
					break
			assert_eq(dir, int(cs[6]), "Fall %d (%d Spuren, Spur %d, Versatz %+.2f, daneben %d, Tankspur %s, exclude %s)" % [
				k, int(cs[0]), lane, float(cs[3]), int(cs[4]), str(cs[5]), str(use_exclude)])


## TRAF-2: two cars of almost the same speed side by side on a two-lane road must not form a rolling roadblock:
## the one on the left passes decisively (or, if it cannot be clearly faster, drops back) and keeps right;
## faster traffic gets through. Trucks: no "elephant race" either.
func test_no_rolling_roadblock_side_by_side() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(60000.0, "landstrasse", 2)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var left := _car(ts, c, 1, 1005.0, 0, 74.0)
	var right := _car(ts, c, 2, 1000.0, 1, 75.0)
	var fast := _car(ts, c, 3, 860.0, 0, 95.0)
	var side := 0.0
	var t := 0.0
	var through := -1.0
	var overlaps := 0
	while t < 90.0:
		ts.update(DT, {"z": minf(fast.z, minf(left.z, right.z)) - 120.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		t += DT
		if left.lane != right.lane and absf(left.z - right.z) < 12.0:
			side += DT
		if through < 0.0 and fast.z > maxf(left.z, right.z) + 10.0:
			through = t
		for a in ts.cars:
			for b in ts.cars:
				if a.id < b.id and absf(a.x - b.x) < (a.width + b.width) * 0.5 - 0.1 and absf(a.z - b.z) < (a.length + b.length) * 0.5:
					overlaps += 1
	assert_true(side < 10.0, "nebeneinander nur kurz: %.1f s (vorher: die ganze Zeit)" % side)
	assert_eq(left.lane, 1, "das linke Auto ordnet sich rechts ein")
	assert_true(left.z > right.z, "es hat zügig überholt (statt neben ihm herzufahren)")
	assert_true(through > 0.0 and through < 60.0, "schnellerer Verkehr kommt vorbei (nach %.1f s)" % through)
	assert_eq(overlaps, 0, "keine Überlappungen")
	# trucks: no "elephant race" in the middle lane of an autobahn
	var c3 := _empty_cfg()
	var track3 := FakeTrack.new(60000.0, "autobahn", 3)
	var ts3 := _system(c3, track3)
	ts3.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var t1 := _car(ts3, c3, 1, 1010.0, 1, 114.0, true)
	var t2 := _car(ts3, c3, 2, 1000.0, 2, 112.0, true)
	var side3 := 0.0
	var tt := 0.0
	while tt < 90.0:
		ts3.update(DT, {"z": minf(t1.z, t2.z) - 120.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		tt += DT
		if t1.lane != t2.lane and absf(t1.z - t2.z) < (t1.length + t2.length) * 0.5 + 6.0:
			side3 += DT
	assert_true(side3 < 25.0, "Lkw nebeneinander nur kurz: %.1f s" % side3)
	assert_eq(t1.lane, 2, "Lkw ordnet sich wieder rechts ein")
	# normal traffic on a two-lane road (without the rule this seed has a pair side by side for ~40 s)
	var r := Sim.traffic_run(cfg(), FakeTrack.new(60000.0, "landstrasse", 2), 17.0, 90.0, 120.0, {"seed": 7})
	assert_true(float(r["max_side_by_side_s"]) < 10.0, "Landstraße 17 Uhr: längstes Nebeneinander %.1f s" % float(r["max_side_by_side_s"]))
	assert_eq(int(r["overlaps"]), 0, "keine Überlappungen")
	assert_eq(int(r["pops_in"]) + int(r["pops_out"]), 0, "kein Auftauchen/Verschwinden im Bild")


## TRAF-2, other branch: a car that cannot be clearly faster drops back and keeps right behind the other one
## (trucks on a Landstraße, top 80 km/h), and nobody races a clearly faster car that comes up on the right.
func test_side_rule_drops_back_when_it_cannot_pass() -> void:
	var c := _empty_cfg()
	var track := FakeTrack.new(60000.0, "landstrasse", 2)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var a := _car(ts, c, 1, 1004.0, 0, 78.0, true)
	var b := _car(ts, c, 2, 1000.0, 1, 76.0, true)
	var top: Array = ConfigLoader.lookup(c, "traffic.truck_speeds_kmh.landstrasse", [70, 80])
	var yielded := false
	var max_a := 0.0
	var side := 0.0
	var t := 0.0
	while t < 60.0:
		ts.update(DT, {"z": minf(a.z, b.z) - 120.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		t += DT
		yielded = yielded or a.yield_kmh >= 0.0
		max_a = maxf(max_a, a.speed)
		if a.lane != b.lane and absf(a.z - b.z) < (a.length + b.length) * 0.5 + 6.0:
			side += DT
	assert_true(yielded, "Lkw kann nicht klar schneller sein -> fällt zurück")
	assert_true(max_a <= float(top[1]) + 0.5, "kein Tempo über dem Lkw-Bereich (%.1f)" % max_a)
	assert_eq(a.lane, 1, "ordnet sich rechts ein")
	assert_true(a.z < b.z, "hinter dem anderen Lkw")
	assert_true(side < 15.0, "nebeneinander nur kurz: %.1f s" % side)
	# a clearly faster car comes up on the right: the car on the left lets it pass, no race
	var ts2 := _system(c, track)
	ts2.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var slow := _car(ts2, c, 1, 1050.0, 0, 80.0)
	var fast := _car(ts2, c, 2, 1000.0, 1, 98.0)
	var max_slow := 0.0
	t = 0.0
	while t < 40.0:
		ts2.update(DT, {"z": minf(slow.z, fast.z) - 120.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		t += DT
		max_slow = maxf(max_slow, slow.speed)
	assert_true(max_slow <= 80.5, "kein Wettrennen mit dem schnelleren Auto (%.1f km/h)" % max_slow)
	assert_true(fast.z > slow.z + 20.0, "das schnellere Auto ist vorbei")
	assert_eq(slow.lane, 1, "danach rechts eingeordnet")


## Snow on a two-lane Landstraße (limit 80): the player follows a truck (54 km/h) at 40 m, a car (56 km/h) in the
## left lane cannot pass the truck decisively and yields. Without the hold window it hovered at the edge of the side
## window – right beside the player, whose overtaking lane stayed blocked for 52 km (Saragossa – Pau). Now it drops
## back traffic.side_yield_hold_m further: the left lane next to the player is free most of the time.
## Second case: with a slightly slower truck the weather-scaled margins let the car pass decisively.
func test_yielding_car_does_not_hover_beside_the_player() -> void:
	var hold := _hover(_empty_cfg(), 80.0)
	var old := _hover(_empty_cfg({"traffic": {"side_yield_hold_m": 0.0}}), 80.0)
	print("    Lkw 54 km/h: linke Spur neben dem Spieler blockiert %.0f %% (ohne Haltefenster %.0f %%)" % [
		float(hold[0]) * 100.0, float(old[0]) * 100.0])
	assert_true(float(old[0]) > 0.8, "ohne Haltefenster blockiert es die linke Spur fast immer (%.0f %%)" % (float(old[0]) * 100.0))
	assert_true(float(hold[0]) < 0.5, "mit Haltefenster meist frei: blockiert %.0f %% der Zeit" % (float(hold[0]) * 100.0))
	# 52 km/h: 3.9 km/h (= 6 km/h × 0.65) slower than the car – an ordinary overtake (without the scaled margin: yield)
	var passing := _hover(_empty_cfg(), 77.0)
	assert_true(bool(passing[1]), "Lkw 52 km/h: das Auto überholt ihn (blockiert %.0f %%)" % (float(passing[0]) * 100.0))


## [share of 120 s in which the car in the left lane is within -12 .. +18 m of a player who follows a truck (dry
## cruise truck_dry_kmh, × 0.68 in snow) at 40 m in the right lane – the player cannot pull out then, car passed]
func _hover(c: Dictionary, truck_dry_kmh: float) -> Array:
	var track := FakeTrack.new(60000.0, "landstrasse", 2)
	track.set_sections([{"length": 60000.0, "road": "landstrasse", "lanes": 2, "limit": 80}])
	var ts := _system(c, track)
	var ctx := {"hour": 12.0, "weather": "snow"}
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, ctx)
	var truck := _car(ts, c, 1, 1040.0, 1, truck_dry_kmh, true)
	var car := _car(ts, c, 2, 1000.0 - 6.6, 0, 94.3)   # temperament 0.81: 56 km/h in snow under the limit of 80
	ts.update(0.0, {"z": 1000.0, "x": float(track.lane_center_x(1000.0, 1)), "speed": 0.0}, ctx)
	truck.speed = truck.cruise_speed
	car.speed = truck.speed
	var blocked := 0.0
	var t := 0.0
	while t < 120.0:
		var pz := truck.z - (truck.length + 4.6) * 0.5 - 40.0
		ts.update(DT, {"z": pz, "x": float(track.lane_center_x(pz, 1)), "speed": truck.speed}, ctx)
		t += DT
		if car.lane == 0 and car.z - pz > -12.0 and car.z - pz < 18.0:
			blocked += DT
	return [blocked / t, car.z > truck.z]


## v0.5.0 (playtest: "selbst bei Top-Speed sind die Gegner schnell genug"): realistic desired speeds – cars in the
## design range of the road type, trucks on the autobahn 80–90, buses 95–100; a speed limit caps cars at limit ×
## traffic.limit_tolerance and heavy vehicles at the limit; rain about −15 %, snow about −35 %; no night bonus.
func test_speeds_per_class_limit_and_weather() -> void:
	var c := cfg()
	var ts := _system(c, FakeTrack.new())
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	assert_near(ts.cruise_speed_for("autobahn", 0, 0.0), 110.0, 0.01, "Pkw Autobahn langsam")
	assert_near(ts.cruise_speed_for("autobahn", 0, 1.0), 150.0, 0.01, "Pkw Autobahn schnell")
	assert_near(ts.cruise_speed_for("autobahn", 1, 0.0), 80.0, 0.01, "Lkw Autobahn 80")
	assert_near(ts.cruise_speed_for("autobahn", 1, 1.0), 90.0, 0.01, "Lkw Autobahn 90")
	assert_between(ts.cruise_speed_for("autobahn", 2, 0.5), 95.0, 100.0, "Bus Autobahn ~95–100")
	assert_between(ts.cruise_speed_for("landstrasse", 1, 1.0), 60.0, 80.0, "Lkw Landstraße")
	# speed limits (0 = none): NL autobahn 100, French 130, city 50
	var tol: Array = ConfigLoader.lookup(c, "traffic.limit_tolerance", [0.92, 1.12])
	assert_near(ts.cruise_speed_for("autobahn", 0, 1.0, 100), 100.0 * float(tol[1]), 0.01, "schneller Pkw etwas über dem Limit")
	assert_near(ts.cruise_speed_for("autobahn", 0, 0.0, 100), 100.0 * float(tol[0]), 0.01, "vorsichtiger Pkw unter dem Limit")
	assert_near(ts.cruise_speed_for("autobahn", 0, 0.0, 130), 110.0, 0.01, "Limit über dem Wunschtempo: ohne Wirkung")
	assert_true(ts.cruise_speed_for("city", 0, 1.0, 50) <= 50.0 * float(tol[1]) + 0.01, "City: Limit 50")
	assert_near(ts.cruise_speed_for("autobahn", 1, 1.0, 80), 80.0, 0.01, "Lkw höchstens am Limit")
	# weather: the same driver slower in rain and snow; no night bonus
	var dry := ts.cruise_speed_for("autobahn", 0, 0.5)
	var dry_truck := ts.cruise_speed_for("autobahn", 1, 0.5)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0, "weather": "rain"})
	assert_between(ts.cruise_speed_for("autobahn", 0, 0.5) / dry, 0.8, 0.9, "Regen ≈ −15 %")
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0, "weather": "snow"})
	var snow_car := ts.cruise_speed_for("autobahn", 0, 0.5)
	assert_between(snow_car / dry, 0.6, 0.7, "Schnee ≈ −35 %")
	assert_between(ts.cruise_speed_for("autobahn", 0, 0.0), 65.0, 80.0, "Schnee: langsamer Pkw ~70")
	assert_between(ts.cruise_speed_for("autobahn", 0, 1.0), 90.0, 105.0, "Schnee: schneller Pkw ~100")
	assert_between(ts.cruise_speed_for("autobahn", 1, 0.5), 50.0, 70.0, "Schnee: Lkw 50–70")
	assert_true(ts.cruise_speed_for("autobahn", 1, 0.5) < dry_truck, "Lkw im Schnee langsamer")
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 0.5, "weather": "snow"})
	assert_near(ts.cruise_speed_for("autobahn", 0, 0.5), snow_car, 0.01, "nachts nicht schneller")
	# the real traffic: many heavy vehicles (share 50 %), every vehicle inside its class range
	var ch := Fx.config({"traffic": {"truck_share": {"autobahn": 0.5, "landstrasse": 0.5, "city": 0.5}}})
	var cars: Dictionary = ConfigLoader.lookup(c, "traffic.speeds_kmh", {})
	for spec: Array in [["autobahn", 3, 8.0], ["landstrasse", 2, 8.0], ["city", 2, 8.0]]:
		var road := str(spec[0])
		var track := FakeTrack.new(40000.0, "landstrasse" if road == "city" else road, int(spec[1]))
		if road == "city":
			track.city_z = 0.0
		var r := Sim.traffic_run(ch, track, float(spec[2]), 100.0 if road != "autobahn" else 160.0, 30.0)
		var heavy_lo := minf(float((ConfigLoader.lookup(c, "traffic.truck_speeds_kmh." + road, [0, 0]) as Array)[0]),
			float((ConfigLoader.lookup(c, "traffic.bus_speeds_kmh." + road, [0, 0]) as Array)[0]))
		var heavy_hi := maxf(float((ConfigLoader.lookup(c, "traffic.truck_speeds_kmh." + road, [0, 0]) as Array)[1]),
			float((ConfigLoader.lookup(c, "traffic.bus_speeds_kmh." + road, [0, 0]) as Array)[1]))
		var rng: Array = cars[road]
		assert_true(int(r["heavy_seen"]) >= 3, "%s: Lkw unterwegs (%d)" % [road, int(r["heavy_seen"])])
		assert_between(float(r["min_cruise_car"]), float(rng[0]) - 0.01, float(rng[1]) + 0.01, road + ": langsamster Pkw")
		assert_between(float(r["max_cruise"]), float(rng[0]) - 0.01, float(rng[1]) + 0.01, road + ": schnellstes Wunschtempo")
		assert_between(float(r["min_cruise_heavy"]), heavy_lo - 0.01, heavy_hi + 0.01, road + ": langsamstes schweres Fahrzeug")
		assert_between(float(r["max_cruise_heavy"]), heavy_lo - 0.01, heavy_hi + 0.01, road + ": schnellstes schweres Fahrzeug")


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
	assert_near(float(night["speed_factor_unique"]), float(ConfigLoader.lookup(c, "traffic.night.speed_factor", 1.0)), 0.001,
		"nachts: Wunschtempo × Nachtfaktor (seit v0.5.0 1,0 – kein Bonus)")


# --- v0.5.0: traffic as an obstacle (docs/gameplay.md "Verkehr als Hindernis") ---------------------------------

## Places a vehicle of class cls (0 car, 1 truck, 2 bus) with temperament frac at its desired speed.
func _car_frac(ts: TrafficSystem, id: int, z: float, lane: int, frac: float, cls: int = 0) -> TrafficSystem.Car:
	var car := TrafficSystem.Car.new()
	car.id = id
	car.z = z
	car.lane = lane
	car.x = float(ts.track.lane_center_x(z, lane))
	car.heavy = cls != 0
	car.bus = cls == 2
	car.length = 16.5 if cls == 1 else (12.8 if cls == 2 else 4.5)
	car.width = 2.55 if cls != 0 else 1.8
	car.speed_frac = frac
	car.cruise_speed = ts.cruise_speed_for(str(ts.track.road_type_at(z)), cls, frac)
	car.speed = car.cruise_speed
	car.set_id = "traffic/truck_white" if cls != 0 else "traffic/sedan_blue"
	ts.cars.append(car)
	return car


## Every lane change of the traffic is announced: the indicator comes on traffic.blink.lead_s (1–1.5 s, heavy
## vehicles longer) before the car moves, stays on while it moves and goes off in the new lane.
func test_lane_changes_are_signalled() -> void:
	var c := cfg()
	var lead: Array = ConfigLoader.lookup(c, "traffic.blink.lead_s", [1.0, 1.5])
	var r := Sim.traffic_run(c, FakeTrack.new(60000.0), 8.0, 120.0, 90.0, {"player_x": -60.0, "seed": 3})
	assert_true(int(r["signal_moves"]) >= 10, "Spurwechsel mit Blinker (%d)" % int(r["signal_moves"]))
	assert_true(float(r["min_signal_lead_s"]) >= float(lead[0]) - 0.02,
		"Blinker mindestens %.1f s vor dem Spurwechsel (kürzester: %.2f s)" % [float(lead[0]), float(r["min_signal_lead_s"])])
	assert_eq(int(r["overlaps"]), 0, "keine Überlappungen")
	var ts: TrafficSystem = r["system"]
	for car in ts.cars:
		if car.signal_dir != 0 and car.signal_lane == car.lane:
			assert_true(absf(car.x - float(ts.track.lane_center_x(car.z, car.lane))) >= 0.3, "Blinker aus, sobald das Auto in der Spur ist")


## Cut-in scenario on a 3-lane autobahn: a truck in the right lane, a fast car stuck right behind it, the player in
## the middle lane gap0 m behind the car. The player keeps his speed until the car moves into his lane, then brakes
## with brake_frac of his full braking in this weather until he is as slow as the car.
func _cut_in_run(weather: String, gap0: float, player_kmh: float, brake_frac: float) -> Dictionary:
	var c := _empty_cfg()
	var track := FakeTrack.new(60000.0, "autobahn", 3)
	var ts := _system(c, track)
	var env := EnvironmentModel.new()
	env.setup(c)
	var v := Fx.vehicle(c, "limousine")
	var brake := v.brake_decel_mps2(env.grip(weather))
	var ctx := {"hour": 12.0, "weather": weather, "brake_mps2": brake, "camera_z": 0.0}
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, ctx)
	var truck := _car_frac(ts, 1, 3000.0, 2, 0.2, 1)
	var car := _car_frac(ts, 2, 3000.0 - 45.0, 2, 0.9, 0)
	car.speed = truck.speed
	var pz := car.z - (car.length + v.length_m) * 0.5 - gap0
	var px := float(track.lane_center_x(pz, 1))
	var pv := player_kmh
	var braking := false
	var out := {"gap_at_move": -1.0, "floor": -1.0, "lead_s": -1.0, "min_gap": INF, "hit": false, "rel_kmh": 0.0}
	for i in 1200:
		ctx["camera_z"] = pz - 9.0
		ts.update(DT, {"z": pz, "x": px, "speed": pv, "length": v.length_m, "width": v.width_m}, ctx)
		if not braking and car.lane == 1:
			braking = true
			out["gap_at_move"] = float(ts.last_cut_in.get("gap_m", -1.0))
			out["floor"] = float(ts.last_cut_in.get("floor_m", -1.0))
			out["rel_kmh"] = float(ts.last_cut_in.get("rel_kmh", 0.0))
			out["lead_s"] = car.signal_age
		if braking and pv > car.speed:
			pv = maxf(car.speed, pv - brake * brake_frac * 3.6 * DT)
		pz += pv / 3.6 * DT
		if absf(car.x - px) < (car.width + v.width_m) * 0.5 and car.z > pz:
			var g := car.z - pz - (car.length + v.length_m) * 0.5
			out["min_gap"] = minf(float(out["min_gap"]), g)
			out["hit"] = bool(out["hit"]) or g < 0.0
	out["cut_ins"] = ts.cut_ins
	out["passed"] = pz > car.z
	return out


## Traffic no longer clears the way for a fast player: the car stuck behind the truck pulls out in front of a player
## coming up at top speed (much closer than a careful driver would – the old rule waited for ~390 m) – with the
## indicator on first, and never closer than the fairness floor: braking with 70 % of his full braking once the
## car moves, the player stays behind it. Dry and snow (weaker braking -> larger floor). Too close: it waits.
func test_cut_in_in_front_of_a_fast_player_is_fair() -> void:
	var lead: Array = ConfigLoader.lookup(cfg(), "traffic.blink.lead_s", [1.0, 1.5])
	for spec: Array in [["normal", 240.0, 230.0], ["snow", 330.0, 205.0]]:
		var w := str(spec[0])
		var r := _cut_in_run(w, float(spec[1]), float(spec[2]), 0.7)
		var label := "%s, Spieler %.0f km/h" % [w, float(spec[2])]
		assert_eq(int(r["cut_ins"]), 1, label + ": zieht vor dem Spieler heraus")
		assert_true(float(r["gap_at_move"]) >= float(r["floor"]) and float(r["floor"]) > 0.0,
			label + ": Abstand %.0f m >= Untergrenze %.0f m" % [float(r["gap_at_move"]), float(r["floor"])])
		assert_true(float(r["gap_at_move"]) < 300.0, label + ": echtes Hereinziehen (%.0f m vor dem Spieler)" % float(r["gap_at_move"]))
		assert_true(float(r["lead_s"]) >= float(lead[0]) - 0.02, label + ": Blinker %.2f s vorher" % float(r["lead_s"]))
		assert_false(bool(r["hit"]), label + ": mit 70 %% Bremsung kein Auffahren (kleinster Abstand %.1f m)" % float(r["min_gap"]))
		assert_true(float(r["min_gap"]) > 3.0, label + ": kleinster Abstand %.1f m" % float(r["min_gap"]))
	var near := _cut_in_run("normal", 60.0, 230.0, 0.0)
	assert_eq(int(near["cut_ins"]), 0, "zu nah: wartet, bis der Spieler vorbei ist")
	assert_true(bool(near["passed"]) and not bool(near["hit"]), "Spieler fährt ungebremst vorbei")


## Elefantenrennen (v0.5.0): on a 3-lane autobahn a truck held up by a slower one pulls out (indicator first) and
## passes it at its own pace in the middle lane – two lanes blocked at truck speed for a while –, never in the left
## lane; a too small difference makes it give up after traffic.elephant.max_s and wait traffic.elephant.retry_s.
## On a 2-lane road it stays behind.
func test_elephant_race_on_three_lanes_only() -> void:
	var c := _empty_cfg()
	var max_s := float(ConfigLoader.lookup(c, "traffic.elephant.max_s", 45.0))
	var retry_s := float(ConfigLoader.lookup(c, "traffic.elephant.retry_s", 60.0))
	for spec: Array in [[0.0, 1.0, true], [0.35, 0.75, false]]:
		var track := FakeTrack.new(90000.0, "autobahn", 3)
		var ts := _system(c, track)
		ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		var slow := _car_frac(ts, 1, 1200.0, 2, float(spec[0]), 1)
		var fast := _car_frac(ts, 2, 1155.0, 2, float(spec[1]), 1)   # 28.5 m behind it, catching up
		var blocked := 0.0
		var t := 0.0
		var pulled := -1.0
		var back := -1.0
		var retry := -1.0
		var signalled := false
		var left := false
		var was_mid := false
		while t < 170.0:
			var zmin := minf(slow.z, fast.z)
			ts.update(DT, {"z": zmin - 150.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0, "camera_z": zmin - 160.0})
			t += DT
			signalled = signalled or fast.signal_dir < 0
			if fast.lane == 1 and not was_mid:
				if pulled < 0.0:
					pulled = t
				elif retry < 0.0:
					retry = t
			was_mid = fast.lane == 1
			if pulled >= 0.0 and back < 0.0 and fast.lane == 2:
				back = t
			left = left or fast.lane == 0 or slow.lane == 0
			# both right lanes held by the two trucks close together (at truck speed)
			if fast.lane != slow.lane and absf(fast.z - slow.z) < 100.0:
				blocked += DT
		var label := "Lkw %.0f vs %.0f km/h" % [slow.cruise_speed, fast.cruise_speed]
		assert_true(signalled and pulled > 0.0, label + ": schert mit Blinker aus")
		assert_true(blocked > 15.0, label + ": Elefantenrennen, zwei Spuren %.1f s blockiert" % blocked)
		assert_true(back > 0.0 and back - pulled < max_s + 30.0, label + ": nach %.1f s wieder rechts" % (back - pulled))
		assert_false(left, label + ": nie auf der linken Spur")
		if bool(spec[2]):
			assert_true(fast.z > slow.z, label + ": überholt")
		else:
			assert_true(back - pulled >= max_s - 0.5, label + ": gibt erst nach %.0f s auf (%.1f s)" % [max_s, back - pulled])
			assert_true(retry < 0.0 or retry - back >= retry_s - 0.5, label + ": neuer Versuch frühestens nach %.0f s" % retry_s)
	var track2 := FakeTrack.new(90000.0, "landstrasse", 2)
	var ts2 := _system(c, track2)
	ts2.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
	var s2 := _car_frac(ts2, 1, 1200.0, 1, 0.0, 1)
	var f2 := _car_frac(ts2, 2, 1100.0, 1, 1.0, 1)
	var stayed := true
	for i in 3600:
		ts2.update(DT, {"z": minf(s2.z, f2.z) - 150.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0})
		stayed = stayed and f2.lane == 1
	assert_true(stayed, "zweispurig: kein Elefantenrennen, der schnellere Lkw bleibt dahinter")


## Elefantenrennen in snow (QA v0.5.0): the speed margins of the side rule shrink with the weather (× 0.65 = 3.9 km/h),
## so after max_s a truck 5 km/h faster than the one beside it counted as an ordinary overtake and went on – 121 s
## with both right lanes blocked at 55 km/h. Now it gives up after traffic.elephant.max_s and drops back behind it.
func test_elephant_race_gives_up_in_snow() -> void:
	var c := _empty_cfg()
	var max_s := float(ConfigLoader.lookup(c, "traffic.elephant.max_s", 45.0))
	var track := FakeTrack.new(90000.0, "autobahn", 3)
	var ts := _system(c, track)
	ts.update(0.0, {"z": 0.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0, "weather": "snow"})
	var slow := _car_frac(ts, 1, 1200.0, 2, 0.08, 1)
	var fast := _car_frac(ts, 2, 1160.0, 2, 0.82, 1)
	var diff := fast.cruise_speed - slow.cruise_speed
	assert_between(diff, 4.0, 6.0, "Schnee: %.1f gegen %.1f km/h" % [fast.cruise_speed, slow.cruise_speed])
	var t := 0.0
	var pulled := -1.0
	var back := -1.0
	var behind_when_back := false
	while t < 150.0 and back < 0.0:
		var zmin := minf(slow.z, fast.z)
		ts.update(DT, {"z": zmin - 150.0, "x": -60.0, "speed": 0.0}, {"hour": 12.0, "camera_z": zmin - 160.0, "weather": "snow"})
		t += DT
		if pulled < 0.0 and fast.lane == 1:
			pulled = t
		if pulled >= 0.0 and fast.lane == 2:
			back = t
			behind_when_back = fast.z < slow.z
	assert_true(pulled > 0.0, "Elefantenrennen beginnt")
	assert_true(back > 0.0, "zurück auf der rechten Spur")
	assert_true(back - pulled >= max_s - 0.5 and back - pulled < max_s + 30.0,
		"gibt nach %.0f s auf, nach %.1f s wieder rechts" % [max_s, back - pulled])
	assert_true(behind_when_back, "fällt hinter den langsameren Lkw zurück, statt weiter zu überholen")


## New traffic often comes in clusters (traffic.cluster): platoons behind a slow vehicle and Elefantenrennen, with
## empty stretches between them – the spacing of the vehicles along the road (all lanes, the view ahead) varies
## clearly more than with evenly spread traffic (coefficient of variation of the gaps), at the same density.
func test_traffic_comes_in_clusters() -> void:
	var on := Fx.config({"traffic": {"cluster": {"chance": {"autobahn": 1.0}}}})
	var off := Fx.config({"traffic": {"cluster": {"chance": {"autobahn": 0.0}}}})
	var cv := [0.0, 0.0]
	var count := [0.0, 0.0]
	for k in 2:
		for seed: int in [11, 12, 13]:
			var r := Sim.traffic_run([off, on][k], FakeTrack.new(60000.0), 8.0, 200.0, 60.0, {"seed": seed})
			cv[k] = float(cv[k]) + float(r["spacing_cv"]) / 3.0
			count[k] = float(count[k]) + float(r["avg_cars"]) / 3.0
			assert_eq(int(r["overlaps"]), 0, "keine Überlappungen")
			assert_eq(int(r["pops_in"]), 0, "Gruppen erscheinen außer Sicht")
	assert_true(float(cv[1]) > float(cv[0]) + 0.08, "Gruppen und Lücken: Streuung der Abstände %.2f statt %.2f" % [float(cv[1]), float(cv[0])])
	assert_true(absf(float(count[1]) - float(count[0])) < float(count[0]) * 0.15, "gleiche Dichte (%.1f / %.1f Autos)" % [float(count[1]), float(count[0])])
