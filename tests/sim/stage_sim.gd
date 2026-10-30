extends SceneTree
## Headless stage simulation with the real StagePlan/Track (data files) and all gameplay systems, driven by a
## simple bot. Same update order as the race session. Reports collisions (with geometry), refuels, police.
##   godot --headless --path . -s res://tests/sim/stage_sim.gd -- --stage=dev_testetappe --vehicle=limousine
##       [--hour=8] [--weather=normal] [--speeding] [--seed=0] [--target=235] [--no-traffic] [--verbose]
##       [--fuel=<litres at start>]
## Owner: gameplay module (diagnostics only, no autoloads).

const DT := 1.0 / 60.0

var cfg: Dictionary
var plan: StagePlan
var track: Track
var vehicle: VehicleModel
var traffic: TrafficSystem
var fuel: FuelSystem
var police: PoliceSystem
var clock: WorldClock
var env: EnvironmentModel
var weather := "normal"
var speeding := false
var target_kmh := 235.0
var verbose := false
var pos_z := 0.0
var pos_km := 0.0
var lane := -1
var log_lines: Array[String] = []
var stats := {"collisions": 0, "rear": 0, "lane_change_hits": 0, "refuels": 0, "liters": 0.0, "flashes": 0,
	"escapes": 0, "stops": 0, "tows": 0, "aborted_refuels": 0, "off_road_s": 0.0, "rail_hits": 0}


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	cfg = ConfigLoader.load_merged()
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var scen: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var scenery: Dictionary = (scen as Dictionary).get("scenery", {}) if scen is Dictionary else {}
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var stage_id := _arg("stage", "dev_testetappe")
	var stage: Dictionary = {}
	for s: Dictionary in net.get("stages", []):
		if str(s["id"]) == stage_id:
			stage = s
	if stage.is_empty():
		print("Etappe nicht gefunden: ", stage_id)
		quit(1)
		return
	plan = StagePlan.build(stage, _arg("from", ""), cities, countries, cfg)
	track = Track.new()
	track.setup(plan, cfg, scenery)
	weather = _arg("weather", "normal")
	speeding = _arg("speeding", "") != ""
	verbose = _arg("verbose", "") != ""
	target_kmh = float(_arg("target", "235"))
	vehicle = VehicleModel.new()
	vehicle.setup(cfg, _arg("vehicle", "limousine"))
	env = EnvironmentModel.new()
	env.setup(cfg)
	clock = WorldClock.new()
	clock.setup(cfg, float(_arg("hour", "8")) * 60.0)
	traffic = TrafficSystem.new()
	var sets: Array[String] = ["traffic/hatch_green", "traffic/sedan_blue", "traffic/sedan_red", "traffic/sedan_silver", "traffic/van_white"]
	var heavy: Array[String] = ["traffic/truck_white"]
	if _arg("no-traffic", "") != "":
		sets = []
		heavy = []
	traffic.setup(cfg, track, sets, heavy, plan.seed + 17 + int(_arg("seed", "0")))
	fuel = FuelSystem.new()
	fuel.setup(cfg, vehicle.spec, plan)
	if _arg("fuel", "") != "":
		fuel.fuel_l = float(_arg("fuel", "50"))
	police = PoliceSystem.new()
	police.setup(cfg, plan)
	_connect()
	pos_km = float(_arg("start-km", "0"))
	pos_z = track.km_to_z(pos_km)
	track.update_window(pos_z - 6.6, 960.0)
	vehicle.x = track.lane_center_x(pos_z, track.lane_count_at(pos_z) - 1)
	_run()
	quit(0)


func _connect() -> void:
	vehicle.crash_started.connect(_on_crash)
	fuel.refuel_finished.connect(func(l: float, aborted: bool) -> void:
		stats["refuels"] = int(stats["refuels"]) + 1
		stats["liters"] = float(stats["liters"]) + l
		if aborted:
			stats["aborted_refuels"] = int(stats["aborted_refuels"]) + 1
		_log("Tanken %s: %.1f L" % ["abgebrochen" if aborted else "fertig", l]))
	fuel.ran_dry.connect(func() -> void:
		stats["tows"] = int(stats["tows"]) + 1
		_log("Tank leer"))
	police.flashed.connect(func(r: Dictionary, v: float) -> void:
		stats["flashes"] = int(stats["flashes"]) + 1
		_log("Geblitzt: %.0f km/h bei Limit %d" % [v, int(r["limit"])]))
	police.escaped.connect(func() -> void:
		stats["escapes"] = int(stats["escapes"]) + 1
		_log("Entkommen nach %.1f s" % police.chase_time))
	police.caught.connect(func() -> void:
		stats["stops"] = int(stats["stops"]) + 1
		_log("Angehalten"))


func _log(s: String) -> void:
	log_lines.append("[%6.1f s km %6.1f] %s" % [_t, pos_km, s])


var _t := 0.0


func _on_crash(dir: int) -> void:
	stats["collisions"] = int(stats["collisions"]) + 1
	var info := "?"
	for c in traffic.cars:
		if absf(c.z - pos_z) < (c.length + vehicle.length_m) * 0.5 + 0.5 and absf(c.x - vehicle.x) < (c.width + vehicle.width_m) * 0.5 + 0.3:
			var changing := absf(c.x - float(track.lane_center_x(c.z, c.lane))) > 0.4 if c.lane != TrafficSystem.FUEL_LANE else false
			if c.z < pos_z:
				stats["rear"] = int(stats["rear"]) + 1
			if changing:
				stats["lane_change_hits"] = int(stats["lane_change_hits"]) + 1
			info = "Auto %d %s dz=%.1f dx=%.2f v=%.0f (Spieler %.0f) Spur %d%s%s" % [c.id, c.set_id, c.z - pos_z, c.x - vehicle.x, c.speed,
				vehicle.speed, c.lane, " WECHSELT" if changing else "", " VON HINTEN" if c.z < pos_z else ""]
	_log("Kollision (Schub %+d): %s" % [dir, info])


func _road(z: float) -> Dictionary:
	var e := track.road_edges_at(z)
	return {"curve": track.curve_at(z), "grade": track.grade_at(z), "left_edge": e.x, "right_edge": e.y,
		"shoulder_m": track.shoulder_w, "guardrail": track.segment_at(z).guardrail, "grip": env.grip(weather)}


func _bot() -> Dictionary:
	var lanes := track.lane_count_at(pos_z + 40.0)
	if lane < 0 or lane >= lanes:
		lane = lanes - 1
	var want := target_kmh
	var to_station := fuel.distance_to_next_station(pos_km)
	var go_fuel := fuel.fuel_l < fuel.tank_l * 0.4 and to_station >= 0.0 and to_station < 8.0
	var tx := track.lane_center_x(pos_z + 20.0, lane)
	if fuel.state == FuelSystem.State.REFUELING:
		return {"steer": 0.0, "throttle": 0.0, "brake": 0.0}
	if go_fuel:
		lane = lanes - 1
		tx = track.lane_center_x(pos_z + 20.0, lane)
		if track.fuel_lane_at(pos_z + 25.0) or track.fuel_lane_at(pos_z):
			tx = track.fuel_lane_x(pos_z + 15.0)
			want = 40.0
		elif to_station < 3.0:
			want = 100.0
	else:
		var ahead := _car_ahead(tx, 30.0 + vehicle.speed / 3.6 * 2.0)
		if ahead != null and ahead.speed < vehicle.speed - 3.0:
			var moved := false
			for cand: int in [lane - 1, lane + 1]:
				if cand >= 0 and cand < lanes and _lane_free(cand):
					lane = cand
					moved = true
					break
			if not moved:
				want = minf(want, ahead.speed - 5.0)
			tx = track.lane_center_x(pos_z + 20.0, lane)
	if not speeding:
		var r := plan.next_radar(pos_km)
		if not r.is_empty() and pos_km > float(r["km"]) - 2.0:
			want = minf(want, float(r["limit"]) * 1.1)
	for d: float in [30.0, 70.0, 120.0]:
		want = minf(want, vehicle.safe_curve_speed(track.curve_at(pos_z + d), env.grip(weather)) * (0.97 + d / 3000.0))
	var steer := clampf((tx - vehicle.x) * 0.7, -1.0, 1.0)
	return {"steer": steer, "throttle": 1.0 if vehicle.speed < want - 1.0 else 0.0, "brake": 1.0 if vehicle.speed > want + 6.0 else 0.0}


func _car_ahead(x: float, dist: float) -> TrafficSystem.Car:
	var best: TrafficSystem.Car = null
	for c in traffic.cars:
		if c.z > pos_z and c.z - pos_z < dist + c.length and absf(c.x - x) < 2.4:
			if best == null or c.z < best.z:
				best = c
	return best


func _lane_free(l: int) -> bool:
	var x := track.lane_center_x(pos_z, l)
	for c in traffic.cars:
		if absf(c.x - x) < 2.6 and c.z > pos_z - 15.0 - maxf(0.0, c.speed - vehicle.speed) * 0.6 and c.z < pos_z + 60.0 + vehicle.speed / 3.6:
			return false
	return true


func _run() -> void:
	var ts := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var t_end := 1800.0
	traffic.update(0.0, {"z": pos_z, "x": vehicle.x, "speed": 0.0}, {"hour": clock.hour(), "chase": false, "camera_z": pos_z - 6.6})
	while _t < t_end and pos_km < plan.length_km:
		var input := _bot()
		var req := fuel.control_request()
		if req.is_empty():
			req = police.control_request()
		if not req.is_empty():
			vehicle.auto_control(float(req.get("target_kmh", 0.0)), float(req.get("rate_kmh_s", 40.0)), float(req.get("steer_x", NAN)))
		else:
			vehicle.release_auto()
		var hour := clock.hour()
		vehicle.update(DT, input, _road(pos_z), {"vmax_factor": env.vmax_factor(hour, weather)})
		var dz := vehicle.speed / 3.6 * DT
		pos_z += dz
		var dkm := Units.visual_m_to_km(dz, ts)
		pos_km = track.z_to_km(pos_z)
		var cam_z := pos_z - 6.6
		track.update_window(cam_z, 960.0)
		var vis := 900.0 * env.visibility_factor(hour, weather, track.is_tunnel_at(cam_z + 5.0))
		traffic.update(DT, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed}, {"hour": hour, "chase": police.chase_active(), "camera_z": cam_z, "visibility_m": vis})
		if not vehicle.invulnerable:
			var hit := traffic.find_collision({"z": pos_z, "x": vehicle.x, "length": vehicle.length_m, "width": vehicle.width_m}, cam_z, _visible)
			if hit != null:
				var e := track.road_edges_at(pos_z)
				var space := traffic.space_beside(pos_z, vehicle.x, vehicle.length_m * 0.5, e.x - track.shoulder_w, e.y + track.shoulder_w, hit)
				vehicle.start_crash(hit.x, space.x, space.y)
		var in_lane := track.fuel_lane_at(pos_z) and vehicle.x > track.main_right_edge(pos_z)
		fuel.update(DT, pos_km, dkm, vehicle.speed, in_lane, float(input.get("throttle", 0.0)))
		police.set_blocked(fuel.holds_car())   # a police stop is served after refuelling/towing
		police.update(DT, pos_km, vehicle.speed)
		var pen := fuel.take_penalty()
		if pen > 0.0:
			clock.advance(pen)
			_t += pen
		clock.advance(DT)
		_t += DT
		if vehicle.off_road > 0:
			stats["off_road_s"] = float(stats["off_road_s"]) + DT
		if vehicle.rail_hit:
			stats["rail_hits"] = int(stats["rail_hits"]) + 1
		if verbose and int(_t / DT) % 600 == 0:
			_log("v=%.0f x=%.2f Spur %d Autos %d (Ziel %.1f) Tank %.1f L" % [vehicle.speed, vehicle.x, lane, traffic.cars.size(), traffic.target_count, fuel.fuel_l])
			var rel: Array[String] = []
			for c in traffic.cars:
				rel.append("%.0f/%d/%.0f" % [c.z - pos_z, c.lane, c.speed])
			_log("   Autos (dz/Spur/v): " + ", ".join(rel))
	for l in log_lines:
		print(l)
	print("ZEIT %.1f s  Ø %.1f km/h  km %.1f  %s" % [_t, Units.avg_speed_kmh(pos_km, _t, ts), pos_km, JSON.stringify(stats)])
	print("Verkehr: %d erzeugt, %d entfernt" % [traffic.spawned_total, traffic.despawned_total])


var _proj: RoadProjection = null


func _visible(dz: float, h: float) -> float:
	if _proj == null:
		_proj = RoadProjection.new()
		_proj.setup(ConfigLoader.lookup(cfg, "render", {}), Vector2(1280, 720))
	return _proj.visible_fraction(dz, h)
