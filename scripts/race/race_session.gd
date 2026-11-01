extends Node2D
## Race scene root (scenes/race/race.tscn): runs one stage – countdown, per-frame simulation of all
## gameplay systems, HUD/renderer/audio feeding, messages, pause, finish.
## Started by GameFlow (which sets `setup` before adding the scene to the tree) or standalone from
## the command line (see ARCHITECTURE.md §Debug-CLI and docs/renn-modul.md). Owner: race module.
##
## setup: {mode: "race"|"single", race_id, stage_id, from_city, vehicle, start_world_minutes,
##         weather, start_km (debug), autopilot (debug), seed}
## result (signal stage_finished): see ARCHITECTURE.md §Ergebnis.
##
## Simulation runs in _physics_process (fixed steps), the view in _process. Scripted control
## requests (fuel before police) are handed to VehicleModel.auto_control(); while the FuelSystem holds
## the car (refuelling, tow) the police stop is blocked (PoliceSystem.set_blocked). Collisions use
## TrafficSystem.find_collision (with the 1/3-visibility rule of RoadProjection) and space_beside
## without the car just hit; they stay active while the car rolls out (empty tank, finish) and in
## scripted phases faster than render.scripted_collision_min_kmh (SessionRules.collisions_active).
## On the tutorial stage (StagePlan.tutorial) a TutorialCoach adds explanatory hints.

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
var coach: TutorialCoach         ## tutorial hints (only on the tutorial stage or with --tutorial), else null
var weather := "normal"
var time_scale := 12.0

var pos_z := 0.0                 ## player car centre (visual m)
var pos_km := 0.0                ## odometer km
var stage_time := 0.0            ## real seconds since the start signal (without penalties)
var penalty_time := 0.0          ## added time penalties (towing)
var countdown := 3.0
var running := false
var finished := false
var bg_offset := 0.0             ## background heading (radians), turns with the curves
var cam_x := 0.0                 ## camera lateral position (follows the car with a slight lag)
var stats := {"collisions": 0, "refuels": 0, "liters": 0.0, "radar_flashes": 0, "police_stops": 0, "police_escapes": 0, "tows": 0}
var last_input: Dictionary = {}
var traffic_enabled := true

var _start_world_minutes := 0.0
var _record: Dictionary = {}
var _flash := 0.0
var _last_country := ""
var _was_city := false
var _was_tunnel := false
var _was_radar_zone := false
var _reserve_warned := false
var _finish_timer := -1.0
var _final_time := 0.0
var _result_sent := false
var _real_time := 0.0
var _beacon_t := 0.0
var _last_beep := 99
var _shake_t := 0.0
var _draw_distance := 900.0
var _curve_r1 := 120.0
var _bg_turn := 1.0
var _sim_us_sum := 0
var _sim_us_max := 0
var _sim_steps := 0
var _start_wall_ms := 0
var _trace_next := 0.0
var _scripted_min_kmh := 30.0    ## render.scripted_collision_min_kmh
var _was_limit := -1             ## speed limit of the last step (tutorial: first section without limit)
var _police_side := -1.0         ## side on which the police car passes (-1 left, +1 right)
var _pull_over_m := 12.0
var _police_off_last := NAN      ## police car offset of the last view (its speed for the sprite pose)
var _police_off_t := 0.0
var _police_rel_kmh := 0.0

const POLICE_VIEW_ID := -2       ## vehicle id of the police car in the view (pose smoothing in the renderer)


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
	_draw_distance = float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))
	_curve_r1 = float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	_bg_turn = float(ConfigLoader.lookup(cfg, "render.background_parallax", 1.0))
	_scripted_min_kmh = float(ConfigLoader.lookup(cfg, "render.scripted_collision_min_kmh", 30.0))
	_pull_over_m = float(ConfigLoader.lookup(cfg, "police.pull_over_offset_m", 12.0))
	plan = GameData.get_stage_plan(str(setup.get("stage_id", "kiel_hamburg")), str(setup.get("from_city", "")))
	if plan == null:
		push_error("Etappe konnte nicht geladen werden")
		call_deferred("emit_signal", "stage_aborted", "no_stage")
		return
	weather = str(setup.get("weather", "normal"))
	if not ["normal", "rain", "snow"].has(weather):
		weather = "normal"
	_start_world_minutes = float(setup.get("start_world_minutes", 8.0 * 60.0))

	if CliArgs.has("scenery"):
		# debug: one scenery for the whole stage (screenshots of background styles)
		for sec in plan.sections:
			sec["scenery"] = CliArgs.get_string("scenery", "north_plain")
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
	AudioManager.set_vehicle(vehicle.type_id)   # engine sound of this car (cycle bank, start clip)

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
	traffic.set_dimensions(SpriteDB.sets)
	traffic_enabled = not CliArgs.has("no-traffic")

	fuel = FuelSystem.new()
	fuel.setup(cfg, vehicle.spec, plan)
	if CliArgs.has("fuel"):
		fuel.fuel_l = fuel.tank_l * clampf(CliArgs.get_float("fuel", 1.0), 0.0, 1.0)
	police = PoliceSystem.new()
	police.setup(cfg, plan)

	var start_km := clampf(float(setup.get("start_km", 0.0)), 0.0, plan.length_km - 0.5)
	pos_km = start_km
	pos_z = track.km_to_z(start_km)
	track.update_window(pos_z - proj.cam_distance, _draw_distance + 60.0)
	var lane := int(CliArgs.get_float("lane", float(track.lane_count_at(pos_z) - 1)))
	vehicle.x = track.lane_center_x(pos_z, clampi(lane, 0, track.lane_count_at(pos_z) - 1))
	if CliArgs.has("x"):
		vehicle.x = CliArgs.get_float("x", vehicle.x)
	cam_x = vehicle.x
	vehicle.speed = clampf(CliArgs.get_float("start-speed", 0.0), 0.0, 300.0)
	if traffic_enabled and (CliArgs.has("traffic-warmup") or bool(setup.get("traffic_warmup", false))):
		_warm_up_traffic()
	if traffic_enabled:
		var h0 := Units.hour_of_day(_start_world_minutes)
		traffic.update(0.0, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed},
			{"hour": h0, "chase": false, "camera_z": pos_z - proj.cam_distance, "visibility_m": _visibility_m(h0)})
	_last_country = plan.country_at(pos_km)
	_was_city = plan.is_city(pos_km)
	_was_tunnel = plan.in_tunnel(pos_km)
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
		autopilot.obey_radar = not CliArgs.has("autopilot-speeding") and not bool(setup.get("autopilot_speeding", false))
		autopilot.refuel_mode = CliArgs.get_string("autopilot-refuel", str(setup.get("autopilot_refuel", "auto")))
	if plan.tutorial or CliArgs.has("tutorial") or bool(setup.get("tutorial", false)):
		coach = TutorialCoach.new()
		coach.setup(cfg)

	_connect_signals()
	countdown = float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0))
	if CliArgs.has("no-countdown") or bool(setup.get("no_countdown", false)):
		countdown = 0.0
	_last_beep = int(ceil(countdown)) + 1
	if CliArgs.has("screenshot"):
		var shot := Screenshotter.new()
		add_child(shot)
		var times := CliArgs.get_float_list("shot-times")
		if times.is_empty():
			times = [1.0]
		shot.configure(CliArgs.get_string("screenshot"), times)
	if CliArgs.has("timescale"):
		var ts := clampf(CliArgs.get_float("timescale", 1.0), 0.05, 200.0)
		Engine.time_scale = ts
		Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
		Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	_start_wall_ms = Time.get_ticks_msec()


## Current sight distance (m): draw distance reduced by night, weather and tunnels.
func _visibility_m(hour: float) -> float:
	return _draw_distance * env.visibility_factor(hour, weather, track.is_tunnel_at(pos_z - proj.cam_distance + 5.0))


## Debug/screenshots: lets traffic build up around the start position by simulating a virtual
## player that approaches from 1.5 km behind at 250 km/h (TrafficSystem only spawns ahead).
func _warm_up_traffic() -> void:
	var hour := Units.hour_of_day(_start_world_minutes)
	var fake := maxf(0.0, pos_z - 1500.0)
	while fake < pos_z:
		var step := minf(14.0, pos_z - fake)
		fake += step
		traffic.update(0.2, {"z": fake, "x": vehicle.x, "speed": 250.0}, {"hour": hour, "chase": false, "camera_z": fake - proj.cam_distance})
	for c in traffic.cars:
		if absf(c.z - pos_z) < 25.0 and absf(c.x - vehicle.x) < 2.5:
			c.z += 40.0


func _connect_signals() -> void:
	fuel.announced.connect(func(k: int, _st: float) -> void:
		if k <= 5:
			hud.show_message(tr("Tankstelle in %d km – Tankspur rechts") % k, "info", 3.5)
			_tutorial("fuel_lane")
		else:
			hud.show_message(tr("Tankstelle in %d km") % k, "info")
			_tutorial("fuel_announce"))
	fuel.refuel_started.connect(func() -> void:
		stats["refuels"] += 1
		AudioManager.play("fuel_start")
		hud.show_message(tr("Tanken …"), "info", 1.5)
		_tutorial("refuel"))
	fuel.refuel_finished.connect(func(l: float, aborted: bool) -> void:
		stats["liters"] += l
		_reserve_warned = false
		hud.show_message((tr("Tanken abgebrochen – %.0f L") if aborted else tr("Vollgetankt – %.0f L")) % l, "info")
		AudioManager.play("fuel_done"))
	# ran_dry fires when the tank reaches 0 L – the car may still roll into a fuel lane and refuel there,
	# so a tow is only counted when it really happened (tow_finished)
	fuel.ran_dry.connect(func() -> void:
		if _can_roll_into_fuel_lane():
			hud.show_message(tr("Tank leer! Rechts in die Tankspur rollen lassen"), "alert", 4.0)
		else:
			hud.show_message(tr("Tank leer! Der Abschleppdienst kommt …"), "alert", 4.0))
	fuel.tow_finished.connect(func(p: float) -> void:
		stats["tows"] += 1
		_reserve_warned = false
		hud.show_message(tr("Zeitstrafe Abschleppdienst: +%s") % Units.format_race_time(p), "warn", 4.0))
	police.radar_warning.connect(func(r: Dictionary) -> void:
		hud.show_message(tr("Radarkontrolle in %d km – Limit %d km/h") % [int(round(float(ConfigLoader.lookup(cfg, "radar.warning_km", 10.0)))), int(r["limit"])], "warn", 4.0)
		_tutorial("radar", {"limit": float(r.get("limit", 120))}))
	police.radar_zone.connect(func(r: Dictionary, entered: bool) -> void:
		if entered:
			hud.show_message(tr("Radarkontrolle – Limit %d km/h") % int(r["limit"]), "warn", 2.5)
		else:
			hud.show_message(tr("Ende der Radarkontrolle"), "info", 2.0))
	police.flashed.connect(func(_r: Dictionary, _v: float) -> void:
		stats["radar_flashes"] += 1
		_flash = 1.0
		AudioManager.play("flash")
		hud.show_message(tr("Geblitzt! Die Polizei ist hinter dir her!"), "alert", 3.5))
	police.chase_started.connect(func() -> void:
		AudioManager.set_siren(true, 0.3)
		hud.show_message(tr("Polizei! Flucht nur mit über %d km/h") % int(ConfigLoader.lookup(cfg, "police.escape_speed_kmh", 220.0)), "alert", 3.0)
		_tutorial("chase"))
	police.escaped.connect(func() -> void:
		stats["police_escapes"] += 1
		AudioManager.set_siren(false, 0.0)
		hud.show_message(tr("Entkommen!"), "info"))
	police.pull_over.connect(func() -> void:
		hud.show_message(tr("Polizei! Rechts ranfahren!"), "alert", 2.5))
	police.caught.connect(func() -> void:
		stats["police_stops"] += 1
		hud.show_message(tr("Führerschein, bitte!"), "alert", float(ConfigLoader.lookup(cfg, "police.stop_duration_s", 10.0))))
	police.released.connect(func() -> void:
		AudioManager.set_siren(false, 0.0)
		hud.show_message(tr("Gute Fahrt!"), "info"))
	vehicle.crash_started.connect(func(_d: int) -> void:
		if not finished:
			stats["collisions"] += 1   # a bump during the finish roll-out does not count for the stage
			_tutorial("collision")
		_shake_t = 0.45
		AudioManager.play("crash")
		hud.flash(Color(1, 0.3, 0.2, 0.35), 0.25))


## Tutorial stage: queue the hints of a topic (no-op on other stages).
func _tutorial(topic: String, args: Dictionary = {}) -> void:
	if coach != null:
		coach.trigger(topic, args)


## True when the car that just ran dry can still roll into a fuel lane slowly enough to refuel there
## (fuel.dry_coast_decel_kmh_s, fuel.lane_trigger_speed_kmh) – then no tow service is announced.
func _can_roll_into_fuel_lane() -> bool:
	var decel := float(ConfigLoader.lookup(cfg, "fuel.dry_coast_decel_kmh_s", 18.0))
	var trigger := float(ConfigLoader.lookup(cfg, "fuel.lane_trigger_speed_kmh", 60.0))
	var taper := float(ConfigLoader.lookup(cfg, "road.fuel_lane_taper_m", 40.0))
	for l in plan.fuel_lanes:
		var open_z := track.km_to_z(float(l["start_km"])) + taper
		if SessionRules.can_roll_into_lane(pos_z, vehicle.speed, decel, trigger, open_z, track.km_to_z(float(l["end_km"]))):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if plan == null:
		return
	if event.is_action_pressed("pause") and not finished:
		if get_tree().paused:
			_on_resume()
		else:
			get_tree().paused = true
			AudioManager.set_engine(0.0, 0.0, vehicle.vmax_effective, false)
			AudioManager.set_wind(0.0)
			AudioManager.set_siren(false, 0.0)
			AudioManager.set_rain(0.0)
			AudioManager.set_skid(0.0)
			pause_menu.open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and plan != null and running and not finished and autopilot == null and not standalone:
		if not get_tree().paused:
			get_tree().paused = true
			pause_menu.open()


func _on_resume() -> void:
	get_tree().paused = false
	pause_menu.close()
	if police.chase_active():
		AudioManager.set_siren(true, _chase01())


func _on_restart() -> void:
	get_tree().paused = false
	AudioManager.stop_all()
	if standalone:
		get_tree().reload_current_scene()
	else:
		restart_requested.emit()


func _on_quit() -> void:
	get_tree().paused = false
	AudioManager.stop_all()
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
	var seg := track.segment_at(z)
	return {
		"curve": track.curve_at(z),
		"grade": track.grade_at(z),
		"left_edge": edges.x,
		"right_edge": edges.y,
		"shoulder_m": track.shoulder_w,
		"guardrail": seg.guardrail or seg.tunnel,
		"grip": env.grip(weather),
	}


func _physics_process(dt: float) -> void:
	if plan == null:
		return
	var t0 := Time.get_ticks_usec()
	_step(dt)
	var us := Time.get_ticks_usec() - t0
	_sim_us_sum += us
	_sim_us_max = maxi(_sim_us_max, us)
	_sim_steps += 1


## One simulation step (fixed dt).
func _step(dt: float) -> void:
	_real_time += dt
	_flash = maxf(0.0, _flash - dt / float(ConfigLoader.lookup(cfg, "radar.flash_s", 0.3)))
	_shake_t = maxf(0.0, _shake_t - dt)
	if not running:
		countdown -= dt
		var sec := int(ceil(countdown))
		if sec < _last_beep and sec > 0:
			_last_beep = sec   # the HUD plays the beep when the countdown number changes
		if countdown <= 0.0:
			running = true
			hud.show_message(tr("LOS!"), "info", 1.2)
			AudioManager.play("go")
			if coach != null:
				coach.hold(1.2)   # let "LOS!" stand alone for a moment
				coach.trigger("start")
				if fuel.fuel_l < fuel.tank_l * 0.6:
					coach.trigger("fuel_low", {"percent": 100.0 * fuel.fuel_l / maxf(fuel.tank_l, 0.001)})
				coach.trigger("fuel_hud")
		return
	if finished:
		_step_finished(dt)
		return
	var input := _read_input()
	last_input = input
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
	track.update_window(cam_z, _draw_distance + 60.0)
	if traffic_enabled:
		traffic.update(dt, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed},
			{"hour": hour, "chase": police.chase_active(), "camera_z": cam_z, "visibility_m": _visibility_m(hour)})
		_check_collision(cam_z, vehicle.state == VehicleModel.State.AUTO)
	var in_lane := track.fuel_lane_at(pos_z) and vehicle.x > track.main_right_edge(pos_z)
	fuel.update(dt, pos_km, dkm, vehicle.speed, in_lane, float(input.get("throttle", 0.0)))
	# while the fuel system holds the car (refuelling, tow) the police stop waits: a capture during
	# refuelling is served after the refuel
	police.set_blocked(fuel.state != FuelSystem.State.NORMAL)
	police.update(dt, pos_km, vehicle.speed)
	var pen := fuel.take_penalty()
	if pen > 0.0:
		penalty_time += pen
		clock.advance(pen)
	clock.advance(dt)
	stage_time += dt
	# the view turns with the road: heading change = arc length / radius
	bg_offset += track.curve_at(pos_z) / _curve_r1 * vehicle.speed / 3.6 * dt * _bg_turn
	_check_zones()
	if coach != null:
		var hint := coach.update(dt)
		if hint != "":
			hud.show_message(hint, "info", coach.hint_s)
	if CliArgs.has("trace") and pos_km >= _trace_next:
		_trace_next = pos_km + CliArgs.get_float("trace", 2.0) if not CliArgs.all()["trace"] is bool else pos_km + 2.0
		print("TRACE km %6.1f  t %6.1f  v %5.1f  want %5.1f  x %5.2f  curve %5.2f  grade %5.3f  fuel %4.1f  cars %d  state %d  %s" % [pos_km, total_time(), vehicle.speed,
			autopilot.last_want if autopilot != null else -1.0, vehicle.x, track.curve_at(pos_z), track.grade_at(pos_z), fuel.fuel_l, traffic.cars.size(), vehicle.state, autopilot.last_reason if autopilot != null else ""])
	if pos_km >= plan.length_km:
		_finish()


## Finish roll-out: the clock is frozen, the car brakes (render.finish_decel_kmh_s) while the player keeps
## steering; traffic still collides (the car does not drive through slower cars after the line).
func _step_finished(dt: float) -> void:
	var input := _read_input()
	last_input = input
	vehicle.auto_control(0.0, float(ConfigLoader.lookup(cfg, "render.finish_decel_kmh_s", 35.0)))
	vehicle.update(dt, {"steer": float(input.get("steer", 0.0))}, road_info(pos_z), {"vmax_factor": 1.0})
	pos_z = minf(pos_z + vehicle.speed / 3.6 * dt, track.length_z + track.runout_m - 30.0)
	pos_km = track.z_to_km(pos_z)
	bg_offset += track.curve_at(pos_z) / _curve_r1 * vehicle.speed / 3.6 * dt * _bg_turn
	var cam_z := pos_z - proj.cam_distance
	track.update_window(cam_z, _draw_distance + 60.0)
	if traffic_enabled:
		traffic.update(dt, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed},
			{"hour": clock.hour(), "chase": false, "camera_z": cam_z, "visibility_m": _visibility_m(clock.hour())})
		_check_collision(cam_z, true)
	_finish_timer -= dt
	if not _result_sent and (_finish_timer <= 0.0 or (vehicle.speed < 1.0 and _finish_timer < 2.0)):
		_result_sent = true
		_emit_result()


## Collision with traffic: TrafficSystem.find_collision with the 1/3-visibility rule. The push side comes
## from the free space beside the car without the car just hit, so a hit straight from behind or in front
## goes to the side with more room (left on a tie, VehicleModel.push_direction). scripted = the car is in
## a scripted phase (AUTO, finish roll-out): see SessionRules.collisions_active.
func _check_collision(cam_z: float, scripted: bool) -> void:
	if not SessionRules.collisions_active(vehicle.invulnerable, scripted, vehicle.speed, fuel.rolling_out, _scripted_min_kmh):
		return
	var hit := traffic.find_collision({"z": pos_z, "x": vehicle.x, "length": vehicle.length_m, "width": vehicle.width_m}, cam_z, proj.visible_fraction)
	if hit == null:
		return
	var edges := track.road_edges_at(pos_z)
	var space := traffic.space_beside(pos_z, vehicle.x, vehicle.length_m * 0.5, edges.x - track.shoulder_w, edges.y + track.shoulder_w, hit)
	vehicle.start_crash(hit.x, space.x, space.y)


func _check_zones() -> void:
	var country := plan.country_at(pos_km)
	if country != _last_country:
		_last_country = country
		var local := str(GameData.countries.get(country, {}).get("name_local", ""))
		var name := GameData.country_name(country)
		hud.show_message((tr("Grenze: %s") % name) + ("" if local == "" or local == name else "  ·  " + local), "info", 3.0)
	var city := plan.is_city(pos_km)
	if city and not _was_city:
		hud.show_message(tr("City Limits %s – Tempo %d") % [plan.to_name, plan.city_speed_limit], "info", 3.0)
		_tutorial("city", {"limit": plan.city_speed_limit})
	_was_city = city
	var limit := plan.speed_limit_at(clampf(pos_km, 0.0, plan.length_km))
	if limit == 0 and _was_limit != 0 and not city:
		_tutorial("unlimited")
	_was_limit = limit
	var tunnel := plan.tunnel_at(pos_km)
	if not tunnel.is_empty() and not _was_tunnel:
		var tname := str(tunnel.get("name", ""))
		hud.show_message(tname if tname != "" else tr("Tunnel"), "info", 2.0)
	_was_tunnel = not tunnel.is_empty()
	var reserve := float(ConfigLoader.lookup(cfg, "fuel.reserve_warning_l", 8.0))
	if fuel.fuel_l < reserve and not _reserve_warned and fuel.state == FuelSystem.State.NORMAL:
		_reserve_warned = true
		var st := fuel.distance_to_next_station(pos_km)
		if st >= 0.0:
			hud.show_message(tr("Reserve! Nächste Tankstelle in %d km") % int(round(st)), "warn", 3.5)
		else:
			hud.show_message(tr("Reserve! Keine Tankstelle mehr bis zum Ziel"), "warn", 3.5)


func _finish() -> void:
	_final_time = stage_time + penalty_time
	finished = true
	_finish_timer = float(ConfigLoader.lookup(cfg, "render.finish_hold_s", 6.0))
	pos_km = plan.length_km
	AudioManager.play("finish")
	AudioManager.set_siren(false, 0.0)
	hud.show_message(tr("ZIEL!  %s") % Units.format_race_time(_final_time), "info", 5.0)


func total_time() -> float:
	if finished:
		return _final_time
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
		"avg_speed_kmh": Units.avg_speed_kmh(plan.length_km - float(setup.get("start_km", 0.0)), t, time_scale),
		"distance_km": plan.length_km,
		"vehicle": str(vehicle.spec.get("id", setup.get("vehicle", ""))),
		"weather": weather,
		"start_world_minutes": _start_world_minutes,
		"end_world_minutes": _start_world_minutes + Units.world_minutes_delta(t, time_scale),
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


## Simulation and render timing (for tests/race/run_stage.gd and --perf).
func perf_stats() -> Dictionary:
	var r := renderer.perf_stats() if renderer != null else {}
	r["sim_steps"] = _sim_steps
	r["sim_avg_ms"] = float(_sim_us_sum) / maxf(1.0, float(_sim_steps)) / 1000.0
	r["sim_max_ms"] = float(_sim_us_max) / 1000.0
	r["wall_s"] = float(Time.get_ticks_msec() - _start_wall_ms) / 1000.0
	return r


func _emit_result() -> void:
	var r := build_result()
	AudioManager.set_engine(0.0, 0.0, vehicle.vmax_effective, false)
	AudioManager.set_siren(false, 0.0)
	if standalone:
		print("ERGEBNIS ", JSON.stringify(r))
		if CliArgs.has("perf"):
			print("PERF ", JSON.stringify(perf_stats()))
		if CliArgs.has("quit-at-finish"):
			get_tree().quit()
	else:
		stage_finished.emit(r)


func _chase01() -> float:
	if not police.chase_active():
		return 0.0
	var start_gap := float(ConfigLoader.lookup(cfg, "police.start_gap_m", 320.0))
	return clampf(1.0 - police.gap_m / maxf(1.0, start_gap), 0.15, 1.0)


func _process(delta: float) -> void:
	if plan == null:
		return
	_beacon_t += delta
	var follow := float(ConfigLoader.lookup(cfg, "render.camera_follow", 7.0))
	var lag := float(ConfigLoader.lookup(cfg, "render.camera_lag_max_m", 1.1))
	cam_x = lerpf(cam_x, vehicle.x, 1.0 - exp(-follow * delta))
	cam_x = clampf(cam_x, vehicle.x - lag, vehicle.x + lag)
	var cam_z := pos_z - proj.cam_distance
	var hour := clock.hour()
	var cam_tunnel := track.is_tunnel_at(cam_z + 1.0)
	var pal := Palette.compute(hour, weather, ConfigLoader.lookup(cfg, "daytime", {}), false)
	var vis := _draw_distance * env.visibility_factor(hour, weather, cam_tunnel)
	var lights := float(pal.get("lights", 0.0))
	var cars: Array = []
	if traffic_enabled:
		for c in traffic.cars:
			cars.append({"kind": "car", "id": c.id, "set": c.set_id, "z": c.z - c.length * 0.5, "x": c.x, "length": c.length,
				"tail": lights, "brake": 1.0 if c.braking else 0.0, "speed": c.speed, "heavy": c.heavy})
	# police car at PoliceSystem.police_car_offset_m() (animated by the gameplay module): it passes the
	# player one lane beside him and pulls in ahead of him for the stop (SessionRules.police_car_x)
	var off := police.police_car_offset_m()
	if is_nan(off):
		_police_off_last = NAN
		_police_rel_kmh = 0.0
	else:
		# its own speed (pose of the sprite while it pulls over): player speed + change of the offset
		if not is_nan(_police_off_last) and _real_time > _police_off_t + 0.0005:
			_police_rel_kmh = (off - _police_off_last) / (_real_time - _police_off_t) * 3.6
		if is_nan(_police_off_last) or _real_time > _police_off_t + 0.0005:
			_police_off_last = off
			_police_off_t = _real_time
		if off < -proj.cam_distance - 6.0:
			# out of sight behind the camera: choose the side it will pass on
			_police_side = SessionRules.police_pass_side(vehicle.x, track.road_edges_at(pos_z).x, track.lane_w)
		var px := SessionRules.police_car_x(off, vehicle.x, _police_side, track.lane_w, _pull_over_m, (4.8 + vehicle.length_m) * 0.5)
		cars.append({"kind": "car", "id": POLICE_VIEW_ID, "set": GameData.police_set_for(plan.country_at(clampf(pos_km, 0.0, plan.length_km))), "z": pos_z + off - 2.4,
			"x": px, "tail": lights, "length": 4.8, "speed": maxf(0.0, vehicle.speed + _police_rel_kmh),
			"beacon": "a" if fmod(_beacon_t, 0.5) < 0.25 else "b"})
	# the renderer derives the visible yaw and body roll of the car from these (docs/renn-modul.md §8)
	var player := {"kind": "car", "player": true, "set": str(vehicle.spec.get("sprite", "player/limousine")),
		"z": pos_z - vehicle.length_m * 0.5, "x": vehicle.x, "length": vehicle.length_m, "width": vehicle.width_m,
		"steer": vehicle.steer_visual, "lat_speed": vehicle.lat_speed, "push_speed": vehicle.push_speed,
		"understeer": vehicle.understeer,
		"tail": lights, "brake": 1.0 if vehicle.braking else 0.0, "visible": vehicle.blink_visible, "speed": vehicle.speed}
	var shake := Vector2.ZERO
	if vehicle.off_road > 0 and vehicle.speed > 30.0:
		shake = Vector2(randf_range(-1.2, 1.2), randf_range(-1.5, 1.5)) * minf(vehicle.speed / 100.0, 2.0)
	if _shake_t > 0.0:
		shake += Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0)) * (_shake_t / 0.45)
	var chase := _chase01()
	renderer.render({
		"camera_z": cam_z,
		"camera_x": cam_x,
		"camera_y": track.height_at(pos_z) + proj.cam_height,
		"camera_in_tunnel": cam_tunnel,
		"visibility_m": vis,
		"palette": pal,
		"weather": weather,
		"time": _real_time,
		"speed": vehicle.speed,
		"cars": cars,
		"player": player,
		"bg_offset": bg_offset,
		"scenery": plan.scenery_at(clampf(pos_km, 0.0, plan.length_km)) if not plan.is_city(pos_km) or not GameData.scenery.has("city") else "city",
		"shake": shake,
		"countdown": countdown if not running else (-0.5 if _real_time < 1.0 + float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0)) else -1000.0),
		"chase01": chase,
		"radar_flash01": _flash,
	})
	hud.update_state(_hud_state(hour))
	var throttle := float(last_input.get("throttle", 0.0)) if autopilot != null else Input.get_action_strength("accelerate")
	AudioManager.set_engine(vehicle.speed, throttle, vehicle.vmax_effective, not finished or vehicle.speed > 1.0)
	AudioManager.set_wind(vehicle.speed)
	AudioManager.set_rain(1.0 if weather == "rain" and not cam_tunnel else 0.0)
	AudioManager.set_skid(clampf(vehicle.understeer + (0.5 if vehicle.state == VehicleModel.State.CRASH else 0.0), 0.0, 1.0))
	if chase > 0.0:
		AudioManager.set_siren(true, chase)
	# pass-by sounds at the vehicles' positions, the siren at the police car (id -2) and the tunnel reverb
	# (docs/verkehrsgeraeusche.md); listener = chase camera. Once the result is out the traffic fades out.
	if not _result_sent:
		AudioManager.set_traffic(cars, {"z": cam_z, "x": cam_x, "speed": vehicle.speed})
	AudioManager.set_environment({"tunnel": cam_tunnel})


func _hud_state(hour: float) -> Dictionary:
	var km := clampf(pos_km, 0.0, plan.length_km)
	var next_radar := plan.next_radar(km)
	var radar_warn := {}
	var limit := plan.speed_limit_at(km)
	if not next_radar.is_empty() and km >= float(next_radar["warn_km"]):
		var in_zone := km >= float(next_radar["km"])
		radar_warn = {"distance_km": maxf(0.0, float(next_radar["km"]) - km), "limit": int(next_radar["limit"]), "in_zone": in_zone}
		if in_zone:
			limit = int(next_radar["limit"])
	var st_police := "none"
	match police.state:
		PoliceSystem.State.CHASE: st_police = "chase"
		PoliceSystem.State.STOPPING: st_police = "stopping"
		PoliceSystem.State.STOPPED: st_police = "stopped"
	return {
		"speed_kmh": vehicle.speed,
		"vmax_kmh": vehicle.vmax_effective,
		"stage_km": km,
		"stage_length_km": plan.length_km,
		"remaining_km": maxf(0.0, plan.length_km - km),
		"clock_text": clock.text(),
		"hour": hour,
		"stage_time_s": total_time(),
		"penalty_s": penalty_time,
		"record_time_s": float(_record.get("time_s", -1.0)),
		"record_name": str(_record.get("name", "")),
		"fuel_l": fuel.fuel_l,
		"tank_l": fuel.tank_l,
		"range_km": fuel.range_km(vehicle.speed),   # at the current speed (FuelSystem floors standstill at 60 km/h)
		"next_station_km": SessionRules.next_station_km(plan, km, fuel.state == FuelSystem.State.REFUELING),
		"speed_limit": limit,
		"radar_warning": radar_warn,
		"police_state": st_police,
		"police_gap_m": police.gap_m,
		"escape01": police.escape_progress,
		"refuel": {"active": fuel.state == FuelSystem.State.REFUELING, "progress01": fuel.refuel_progress, "liters": fuel.liters_added, "time_left_s": fuel.refuel_time_left} if fuel.state == FuelSystem.State.REFUELING else {},
		"tow": {"active": true} if fuel.state == FuelSystem.State.TOWING else {},
		"weather": weather,
		"country": plan.country_at(km),
		"city_limits": plan.is_city(km),
		"in_tunnel": plan.in_tunnel(km),
		"radar_flash01": _flash,
		"countdown": int(ceil(countdown)) if not running else -1,
		"stage_name": plan.display_name,
		"finished": finished,
		"understeer": vehicle.understeer,
		"collision": vehicle.state == VehicleModel.State.CRASH,
	}
