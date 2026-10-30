extends Node2D
## Race scene root (scenes/race/race.tscn): runs one stage – countdown, per-frame simulation of all
## gameplay systems, HUD/renderer/audio feeding, messages, pause, finish.
## Started by GameFlow (which sets `setup` before adding the scene to the tree) or standalone from
## the command line (see ARCHITECTURE.md §Debug-CLI). Owner: race module.
##
## setup: {mode: "race"|"single", race_id, stage_id, from_city, vehicle, start_world_minutes,
##         weather, start_km (debug), autopilot (debug), seed}
## result (signal stage_finished): see ARCHITECTURE.md §Ergebnis.

signal stage_finished(result: Dictionary)
signal stage_aborted(reason: String)
signal restart_requested

var setup: Dictionary = {}
var standalone := false
var cfg: Dictionary = {}
var plan: StagePlan
var track: Track
var proj: RoadProjection
var renderer: RoadRenderer
var vehicle: VehicleModel
var traffic: TrafficSystem
var fuel: FuelSystem
var police: PoliceSystem
var clock: WorldClock
var env: EnvironmentModel
var hud: Hud
var pause_menu: PauseMenu
var autopilot: Autopilot
var weather := "normal"
var time_scale := 12.0

var pos_z := 0.0                 ## player car centre (visual m)
var pos_km := 0.0                ## odometer km
var stage_time := 0.0            ## real seconds since the start signal (without penalties)
var penalty_time := 0.0          ## added time penalties (towing)
var countdown := 3.0
var running := false
var finished := false
var bg_offset := 0.0
var stats := {"collisions": 0, "refuels": 0, "liters": 0.0, "radar_flashes": 0, "police_stops": 0, "police_escapes": 0, "tows": 0}

var _start_world_minutes := 0.0
var _record: Dictionary = {}
var _flash := 0.0
var _last_country := ""
var _was_city := false
var _was_tunnel := false
var _finish_timer := -1.0
var _real_time := 0.0
var _beacon_t := 0.0


func _ready() -> void:
	cfg = Config.data
	if setup.is_empty():
		setup = setup_from_cli()
		standalone = true
	_build()


## Builds a setup dictionary from the command line (standalone/debug start).
static func setup_from_cli() -> Dictionary:
	var c := ConfigLoader.load_merged()
	var hour := CliArgs.get_float("hour", float(ConfigLoader.lookup(c, "time.default_start_hour", 8.0)))
	return {
		"mode": "single",
		"race_id": "",
		"stage_id": CliArgs.get_string("stage", "kiel_hamburg"),
		"from_city": CliArgs.get_string("from", ""),
		"vehicle": CliArgs.get_string("vehicle", str(ConfigLoader.lookup(c, "vehicles.default", "limousine"))),
		"start_world_minutes": hour * 60.0,
		"weather": CliArgs.get_string("weather", "normal"),
		"start_km": CliArgs.get_float("start-km", 0.0),
		"autopilot": CliArgs.has("autopilot"),
		"seed": int(CliArgs.get_float("seed", 0.0)),
	}


func _build() -> void:
	time_scale = float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	plan = GameData.get_stage_plan(str(setup.get("stage_id", "kiel_hamburg")), str(setup.get("from_city", "")))
	if plan == null:
		push_error("Etappe konnte nicht geladen werden")
		stage_aborted.emit("no_stage")
		return
	weather = str(setup.get("weather", "normal"))
	_start_world_minutes = float(setup.get("start_world_minutes", 8.0 * 60.0))

	proj = RoadProjection.new()
	proj.setup(ConfigLoader.lookup(cfg, "render", {}), Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))))
	track = Track.new()
	track.setup(plan, cfg, GameData.scenery)

	renderer = RoadRenderer.new()
	add_child(renderer)
	renderer.setup(track, proj, cfg, GameData.scenery)

	vehicle = VehicleModel.new()
	vehicle.setup(cfg, str(setup.get("vehicle", "limousine")))
	SpriteDB.preload_sets([str(vehicle.spec.get("sprite", ""))])

	env = EnvironmentModel.new()
	env.setup(cfg)
	clock = WorldClock.new()
	clock.setup(cfg, _start_world_minutes)

	traffic = TrafficSystem.new()
	var heavy := SpriteDB.ids_with_tag("heavy")
	var cars: Array[String] = []
	for id in SpriteDB.ids_with_tag("traffic"):
		if not heavy.has(id):
			cars.append(id)
	traffic.setup(cfg, track, cars, heavy, plan.seed + 17 + int(setup.get("seed", 0)))

	fuel = FuelSystem.new()
	fuel.setup(cfg, vehicle.spec, plan)
	police = PoliceSystem.new()
	police.setup(cfg, plan)

	var start_km := clampf(float(setup.get("start_km", 0.0)), 0.0, plan.length_km - 0.5)
	pos_km = start_km
	pos_z = track.km_to_z(start_km)
	track.update_window(pos_z - proj.cam_distance, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0)))
	vehicle.x = track.lane_center_x(pos_z, track.lane_count_at(pos_z) - 1)
	_last_country = plan.country_at(pos_km)
	_was_city = plan.is_city(pos_km)
	_record = Leaderboards.record(plan.board_key)

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.setup_stage(plan, cfg)
	pause_menu = PauseMenu.new()
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.quit_requested.connect(_on_quit)

	if bool(setup.get("autopilot", false)):
		autopilot = Autopilot.new()
		autopilot.target_kmh = float(ConfigLoader.lookup(cfg, "debug.autopilot_target_kmh", 235.0))
		autopilot.obey_radar = not CliArgs.has("autopilot-speeding")

	_connect_signals()
	countdown = float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0))
	if CliArgs.has("no-countdown"):
		countdown = 0.0
	if CliArgs.has("screenshot"):
		var shot := Screenshotter.new()
		add_child(shot)
		var times := CliArgs.get_float_list("shot-times")
		if times.is_empty():
			times = [1.0]
		shot.configure(CliArgs.get_string("screenshot"), times)
	if CliArgs.has("timescale"):
		Engine.time_scale = CliArgs.get_float("timescale", 1.0)
		Engine.physics_ticks_per_second = 60


func _connect_signals() -> void:
	fuel.announced.connect(func(k: int, _st: float) -> void:
		if k <= 5:
			hud.show_message(tr("Tankstelle in %d km – Tankspur rechts") % k, "info")
		else:
			hud.show_message(tr("Tankstelle in %d km") % k, "info"))
	fuel.refuel_started.connect(func() -> void:
		stats["refuels"] += 1
		AudioManager.play("fuel_start"))
	fuel.refuel_finished.connect(func(l: float, aborted: bool) -> void:
		stats["liters"] += l
		hud.show_message((tr("Tanken abgebrochen – %.0f L") if aborted else tr("Vollgetankt – %.0f L")) % l, "info")
		AudioManager.play("fuel_done"))
	fuel.ran_dry.connect(func() -> void:
		stats["tows"] += 1
		hud.show_message(tr("Tank leer! Der Abschleppdienst kommt …"), "alert", 4.0))
	fuel.tow_finished.connect(func(p: float) -> void:
		hud.show_message(tr("Zeitstrafe Abschleppdienst: +%s") % Units.format_race_time(p), "warn", 4.0))
	police.radar_warning.connect(func(r: Dictionary) -> void:
		hud.show_message(tr("Radarkontrolle in %d km – Limit %d km/h") % [int(round(float(ConfigLoader.lookup(cfg, "radar.warning_km", 10.0)))), int(r["limit"])], "warn", 4.0))
	police.flashed.connect(func(_r: Dictionary, _v: float) -> void:
		stats["radar_flashes"] += 1
		_flash = 1.0
		AudioManager.play("flash")
		hud.show_message(tr("Geblitzt! Die Polizei ist hinter dir her!"), "alert", 3.5))
	police.chase_started.connect(func() -> void: AudioManager.set_siren(true, 0.3))
	police.escaped.connect(func() -> void:
		stats["police_escapes"] += 1
		AudioManager.set_siren(false, 0.0)
		hud.show_message(tr("Entkommen!"), "info"))
	police.caught.connect(func() -> void:
		stats["police_stops"] += 1
		hud.show_message(tr("Führerschein, bitte!"), "alert", float(ConfigLoader.lookup(cfg, "police.stop_duration_s", 10.0))))
	police.released.connect(func() -> void:
		AudioManager.set_siren(false, 0.0)
		hud.show_message(tr("Gute Fahrt!"), "info"))
	vehicle.crash_started.connect(func(_d: int) -> void:
		stats["collisions"] += 1
		AudioManager.play("crash")
		hud.flash(Color(1, 0.3, 0.2, 0.35), 0.25))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished:
		if get_tree().paused:
			_on_resume()
		else:
			get_tree().paused = true
			pause_menu.open()
		get_viewport().set_input_as_handled()


func _on_resume() -> void:
	get_tree().paused = false
	pause_menu.close()


func _on_restart() -> void:
	get_tree().paused = false
	if standalone:
		get_tree().reload_current_scene()
	else:
		restart_requested.emit()


func _on_quit() -> void:
	get_tree().paused = false
	if standalone:
		get_tree().quit()
	else:
		stage_aborted.emit("quit")


func _read_input() -> Dictionary:
	if autopilot != null:
		return autopilot.drive(self)
	return {
		"steer": Input.get_axis("steer_left", "steer_right"),
		"throttle": Input.get_action_strength("accelerate"),
		"brake": Input.get_action_strength("brake"),
	}


func road_info(z: float) -> Dictionary:
	var edges := track.road_edges_at(z)
	return {
		"curve": track.curve_at(z),
		"grade": track.grade_at(z),
		"left_edge": edges.x,
		"right_edge": edges.y,
		"shoulder_m": track.shoulder_w,
		"guardrail": track.segment_at(z).guardrail,
		"grip": env.grip(weather),
	}


func _physics_process(dt: float) -> void:
	if plan == null:
		return
	_real_time += dt
	_flash = maxf(0.0, _flash - dt / float(ConfigLoader.lookup(cfg, "radar.flash_s", 0.3)))
	if not running:
		countdown -= dt
		if countdown <= 0.0:
			running = true
			hud.show_message(tr("LOS!"), "info", 1.2)
			AudioManager.play("go")
		return
	if finished:
		vehicle.auto_control(0.0, 30.0)
		vehicle.update(dt, {}, road_info(pos_z), {"vmax_factor": 1.0})
		pos_z += vehicle.speed / 3.6 * dt
		_finish_timer -= dt
		if _finish_timer <= 0.0 and _finish_timer > -100.0:
			_finish_timer = -1000.0
			_emit_result()
		return
	var input := _read_input()
	var req := fuel.control_request()
	if req.is_empty():
		req = police.control_request()
	if not req.is_empty():
		vehicle.auto_control(float(req.get("target_kmh", 0.0)), float(req.get("rate_kmh_s", 40.0)), float(req.get("steer_x", NAN)))
	else:
		vehicle.release_auto()
	var hour := clock.hour()
	vehicle.update(dt, input, road_info(pos_z), {"vmax_factor": env.vmax_factor(hour, weather)})
	var dz := vehicle.speed / 3.6 * dt
	pos_z += dz
	var dkm := Units.visual_m_to_km(dz, time_scale)
	pos_km = track.z_to_km(pos_z)
	var cam_z := pos_z - proj.cam_distance
	track.update_window(cam_z, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0)) + 60.0)
	traffic.update(dt, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed},
		{"hour": hour, "chase": police.chase_active(), "camera_z": cam_z})
	if not vehicle.invulnerable:
		var hit := traffic.find_collision({"z": pos_z, "x": vehicle.x, "length": vehicle.length_m, "width": vehicle.width_m}, cam_z, proj.visible_fraction)
		if hit != null:
			var edges := track.road_edges_at(pos_z)
			var space := traffic.space_beside(pos_z, vehicle.x, vehicle.length_m * 0.5, edges.x - track.shoulder_w, edges.y + track.shoulder_w)
			vehicle.start_crash(hit.x, space.x, space.y)
	var in_lane := track.fuel_lane_at(pos_z) and vehicle.x > track.main_right_edge(pos_z)
	fuel.update(dt, pos_km, dkm, vehicle.speed, in_lane, float(input.get("throttle", 0.0)))
	police.update(dt, pos_km, vehicle.speed)
	var pen := fuel.take_penalty()
	if pen > 0.0:
		penalty_time += pen
		clock.advance(pen)
	clock.advance(dt)
	stage_time += dt
	bg_offset += track.curve_at(pos_z) * vehicle.speed * dt * float(ConfigLoader.lookup(cfg, "render.background_parallax", 0.0025))
	_check_zones()
	if pos_km >= plan.length_km:
		_finish()


func _check_zones() -> void:
	var country := plan.country_at(pos_km)
	if country != _last_country:
		_last_country = country
		hud.show_message(tr("Grenze: %s") % GameData.country_name(country), "info", 3.0)
	var city := plan.is_city(pos_km)
	if city and not _was_city:
		hud.show_message(tr("City Limits %s") % plan.to_name, "info", 3.0)
	_was_city = city
	var tunnel := plan.tunnel_at(pos_km)
	if not tunnel.is_empty() and not _was_tunnel and str(tunnel.get("name", "")) != "":
		hud.show_message(str(tunnel["name"]), "info", 2.0)
	_was_tunnel = not tunnel.is_empty()


func _finish() -> void:
	finished = true
	_finish_timer = 2.0
	pos_km = plan.length_km
	AudioManager.play("finish")
	hud.show_message(tr("ZIEL!  %s") % Units.format_race_time(total_time()), "info", 3.0)


func total_time() -> float:
	return stage_time + penalty_time


func build_result() -> Dictionary:
	var t := total_time()
	var start_hour := Units.hour_of_day(_start_world_minutes)
	return {
		"board_key": plan.board_key,
		"stage_id": plan.stage_id,
		"from_city": plan.from_id,
		"to_city": plan.to_id,
		"stage_name": plan.display_name,
		"time_s": t,
		"penalty_s": penalty_time,
		"avg_speed_kmh": Units.avg_speed_kmh(plan.length_km, t, time_scale),
		"distance_km": plan.length_km,
		"vehicle": vehicle.type_id,
		"weather": weather,
		"start_world_minutes": _start_world_minutes,
		"end_world_minutes": clock.world_minutes,
		"start_hour": start_hour,
		"daytime": WorldClock.daytime_category(start_hour, cfg),
		"collisions": stats["collisions"],
		"refuels": stats["refuels"],
		"liters_refueled": stats["liters"],
		"radar_flashes": stats["radar_flashes"],
		"police_stops": stats["police_stops"],
		"police_escapes": stats["police_escapes"],
		"tow_events": stats["tows"],
		"aborted": false,
	}


func _emit_result() -> void:
	var r := build_result()
	if standalone:
		print("ERGEBNIS ", JSON.stringify(r))
		if CliArgs.has("quit-at-finish"):
			get_tree().quit()
	else:
		stage_finished.emit(r)


func _process(delta: float) -> void:
	if plan == null:
		return
	_beacon_t += delta
	var cam_z := pos_z - proj.cam_distance
	var hour := clock.hour()
	var in_tunnel := track.is_tunnel_at(cam_z + 5.0)
	var pal := Palette.compute(hour, weather, ConfigLoader.lookup(cfg, "daytime", {}), in_tunnel)
	var vis := float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0)) * env.visibility_factor(hour, weather, in_tunnel)
	var lights := float(pal.get("lights", 0.0))
	var cars: Array = []
	for c in traffic.cars:
		cars.append({"kind": "car", "set": c.set_id, "z": c.z - c.length * 0.5, "x": c.x, "tail": lights, "brake": 1.0 if c.braking else 0.0})
	var off := police.police_car_offset_m()
	if not is_nan(off):
		cars.append({"kind": "car", "set": GameData.police_set_for(plan.country_at(pos_km)), "z": pos_z + off - 2.3,
			"x": vehicle.x, "tail": lights, "beacon": "a" if fmod(_beacon_t, 0.5) < 0.25 else "b"})
	var angle := "c"
	if vehicle.steer_visual > 0.25:
		angle = "r1"
	elif vehicle.steer_visual < -0.25:
		angle = "l1"
	var player := {"kind": "car", "player": true, "set": str(vehicle.spec.get("sprite", "player/limousine")),
		"z": pos_z - vehicle.length_m * 0.5, "x": vehicle.x, "angle": angle,
		"tail": lights, "brake": 1.0 if vehicle.braking else 0.0, "visible": vehicle.blink_visible}
	var shake := Vector2.ZERO
	if vehicle.off_road > 0 and vehicle.speed > 30.0:
		shake = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)) * minf(vehicle.speed / 100.0, 2.0)
	renderer.render({
		"camera_z": cam_z,
		"camera_x": vehicle.x,
		"camera_y": track.height_at(pos_z) + proj.cam_height,
		"visibility_m": vis,
		"palette": pal,
		"weather": weather,
		"time": _real_time,
		"speed": vehicle.speed,
		"cars": cars,
		"player": player,
		"bg_offset": bg_offset,
		"scenery": plan.scenery_at(pos_km),
		"shake": shake,
	})
	hud.update_state(_hud_state(hour))
	AudioManager.set_engine(vehicle.speed, 1.0 if Input.is_action_pressed("accelerate") else 0.0, vehicle.vmax_effective, running and not finished)
	AudioManager.set_wind(vehicle.speed)


func _hud_state(hour: float) -> Dictionary:
	var next_radar := plan.next_radar(pos_km)
	var radar_warn := {}
	if not next_radar.is_empty() and pos_km >= float(next_radar["warn_km"]):
		radar_warn = {"distance_km": maxf(0.0, float(next_radar["km"]) - pos_km), "limit": int(next_radar["limit"]),
			"in_zone": pos_km >= float(next_radar["km"])}
	var st_police := "none"
	match police.state:
		PoliceSystem.State.CHASE: st_police = "chase"
		PoliceSystem.State.STOPPING: st_police = "stopping"
		PoliceSystem.State.STOPPED: st_police = "stopped"
	return {
		"speed_kmh": vehicle.speed,
		"vmax_kmh": vehicle.vmax_effective,
		"stage_km": pos_km,
		"stage_length_km": plan.length_km,
		"remaining_km": maxf(0.0, plan.length_km - pos_km),
		"clock_text": clock.text(),
		"hour": hour,
		"stage_time_s": total_time(),
		"penalty_s": penalty_time,
		"record_time_s": float(_record.get("time_s", -1.0)),
		"record_name": str(_record.get("name", "")),
		"fuel_l": fuel.fuel_l,
		"tank_l": fuel.tank_l,
		"range_km": fuel.range_km(maxf(vehicle.speed, 80.0)),
		"next_station_km": fuel.distance_to_next_station(pos_km),
		"speed_limit": plan.speed_limit_at(pos_km),
		"radar_warning": radar_warn,
		"police_state": st_police,
		"police_gap_m": police.gap_m,
		"escape01": police.escape_progress,
		"refuel": {"active": fuel.state == FuelSystem.State.REFUELING, "progress01": fuel.refuel_progress, "liters": fuel.liters_added, "time_left_s": fuel.refuel_time_left} if fuel.state == FuelSystem.State.REFUELING else {},
		"tow": {"active": true} if fuel.state == FuelSystem.State.TOWING else {},
		"weather": weather,
		"country": plan.country_at(pos_km),
		"city_limits": plan.is_city(pos_km),
		"in_tunnel": plan.in_tunnel(pos_km),
		"radar_flash01": _flash,
		"countdown": int(ceil(countdown)) if not running else -1,
		"stage_name": plan.display_name,
		"finished": finished,
		"understeer": vehicle.understeer,
		"collision": vehicle.state == VehicleModel.State.CRASH,
	}
