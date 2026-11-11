extends Node2D
## Race scene root (scenes/race/race.tscn): runs one stage – countdown, per-frame simulation of all
## gameplay systems, HUD/renderer/audio feeding, messages, pause, finish.
## Started by GameFlow (which sets `setup` before adding the scene to the tree) or standalone from
## the command line (see ARCHITECTURE.md §Debug-CLI and docs/renn-modul.md). Owner: race module.
##
## setup: {mode: "race"|"single", race_id, stage_id, from_city, vehicle, start_world_minutes,
##         weather, start_km (debug), autopilot (debug), seed, start_fuel_l (race, v0.7.0: litres carried over from
##         the last stage; missing or -1 = the stage's own filling), last_stage (race, v0.7.0: the stage ends the
##         race – its tank goes nowhere), gfx (v0.8.0, optional: "arcade" | "modern" – graphics mode of this stage
##         for attract demos, the Leistungstest and tests; missing = Settings.effective_graphics())}
## result (signal stage_finished): see ARCHITECTURE.md §Ergebnis (v0.7.0 adds fuel_start_l, fuel_end_l, tank_l,
## start_towed; v0.8.0 gfx, after a fallback from Modern to Arcade gfx_fallback, after a step-down of the quality
## preset by the slowness watchdog gfx_lowered).
## Fuel carried over (v0.7.0): FuelSystem.start_check() decides at the build – a tank that does not reach the first
## fuel lane even at the lane trigger speed gets the tow service before the start (_tow_before_start); the countdown
## names the carried litres and what they are good for (SessionRules.carry_messages).
##
## Simulation runs in _physics_process (fixed steps), the view in _process. Scripted control
## requests (fuel before police) are handed to VehicleModel.auto_control(); while the FuelSystem holds
## the car (refuelling, tow) the police stop is blocked (PoliceSystem.set_blocked). Collisions use
## TrafficSystem.find_collision (with the 1/3-visibility rule of RoadProjection) and space_beside
## without the car just hit; they stay active while the car rolls out (empty tank, finish) and in
## scripted phases faster than render.scripted_collision_min_kmh (SessionRules.collisions_active).
## On the tutorial stage (StagePlan.tutorial) a TutorialCoach adds explanatory hints.
##
## Steam Deck / gamepad (QA v0.5.1, docs/steam-deck.md "Prüfung v0.5.1"):
## - the view is interpolated between the last two simulation steps (Engine.get_physics_interpolation_fraction):
##   the simulation stays at fixed 1/60 s steps, but at 40 or 45 fps and at 90 Hz the road moved by 1 and 2 steps
##   in turn (judder); now every frame shows the state at its own moment (view_state()).
## - steering with the stick: an own curve on the raw stick value (input.stick_deadzone 0.12, full lock from
##   input.stick_full 0.92 – SessionRules.stick_steer) instead of the action's 0.2 deadzone; keys and D-pad stay 1.0.
##   Only the stick of the pad used last steers (InputMode.device, player_steer()): a resting second pad with a
##   drifting stick does not.
## - gamepad vibration (Haptics, Optionen "Vibration"): collisions, guardrail, shoulder/grass, understeer, radar.
## - pause: the pause key, focus loss (also during the countdown), the gamepad in use disconnected
##   (InputSetup.pad_disconnected), back from standby; the paused race draws at FrameCap.IDLE_FPS.
## - every sprite sheet the stage can show is loaded before the start (no loading hitch in the race).
##
## Graphics modes (v0.8.0, ARCHITECTURE.md §15, docs/dev/v080_contract.md §4.4): the stage is drawn by one of two
## renderers behind the same interface (RaceRenderers) – "arcade" = RoadRenderer as before, "modern" = ModernRenderer
## (real 3D). The mode is setup.gfx (attract demos, Leistungstest, tests) or Settings.effective_graphics(), fixed for
## the whole stage. The simulation is the same in both modes and never reads the renderer. Modern only:
## - the crash-guard marker is written before the renderer is built and removed after CRASH_GUARD_S of drawn frames
##   (or when the stage falls back to Arcade or leaves the tree in an orderly way before that): it only survives a
##   crash or a hang that had to be killed – then the next start of the game is Arcade (Settings.crash_guard);
## - the window is filled (stretch aspect "expand"); Arcade keeps "keep" (GameFlow);
## - the renderer prepares the stage over several frames behind a loading overlay (canvas layer 6). Until
##   is_prepared() nothing of the stage runs: no simulation step, no countdown, no HUD timer, no sound, and the
##   Screenshotter's clock stands – equal shot times show equal simulation states in both modes (_gfx_state);
## - a renderer that is not healthy() is replaced by the Arcade renderer before the start (_fall_back): message in
##   the HUD, result fields gfx = "arcade" and gfx_fallback = <reason>;
## - only the HUD icons are loaded as sprite sheets – the vehicle, prop and landmark sheets stay unloaded;
## - the renderer's slowness watchdog may step the quality preset down one step during the countdown (signal
##   quality_lowered): the HUD says so, gfx_lowered and the result field of that name carry the preset.
## Both modes send the hooks of the Modern sound (set_track, set_vehicle_state, event – contract §4.7.2) to the
## AudioManager where it has them; the sound profile is independent of the graphics mode.

signal stage_finished(result: Dictionary)
signal stage_aborted(reason: String)
signal restart_requested
## The stage starts to run (v0.8.0): emitted before its first simulation step – at once in an Arcade stage, after
## the renderer's preparation in Modern (the loading overlay goes). Whoever times something from the start of a
## stage (attract demo, Leistungstest) counts from here; is_live() asks for the same.
signal stage_live

var setup: Dictionary = {}
var standalone := false
var cfg: Dictionary = {}
var plan: StagePlan
var track: Track
var proj: RoadProjection
var renderer                     ## RoadRenderer (Arcade) or ModernRenderer (Modern), see RaceRenderers – untyped
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
## Driving diagnostics of the stage (debug, perf_stats()["drive"]): seconds on the shoulder or beyond
## (off_road_s), at the hard limit (limit_s), guardrail hits, seconds with understeer and its maximum.
var drive_stats := {"off_road_s": 0.0, "limit_s": 0.0, "rail_hits": 0, "understeer_s": 0.0, "understeer_max": 0.0}

var _start_world_minutes := 0.0
## Fuel at the start (v0.7.0): the litres the stage started with – carried over from the last stage of a race
## (setup start_fuel_l) or the stage's own filling – before a tow at the start.
var start_fuel_l := 0.0
## FuelSystem.start_check() of a carried tank ({} without one): reaches the first fuel lane at full speed / only
## gently / not at all.
var start_check: Dictionary = {}
## The carried tank did not reach the first fuel lane even at the lane trigger speed: the tow service came before the
## start (fuel.tow_penalty_s in penalty_time, the tank at fuel.tow_refill_fraction, one tow in the statistics).
var start_towed := false
var _final_fuel_l := -1.0          ## litres when the car crossed the finish line (the roll-out after it uses none)
var _last_station_noted := false   ## race: "last station before the finish" was shown (or is waiting, see below)
## Race with the tutorial coach (Kiel – Hamburg as a race's first stage): the note on the last station waits until the
## car has passed it (km of that station; -1 = nothing waiting) – at the 5-km announcement the coach explains the fuel
## lane, three messages at once filled the HUD (QA v0.7.0).
var _last_station_after := -1.0
var _carry_pending: Array[Dictionary] = []   ## carried-tank message waiting for the end of "LOS!" (weather hint first)
const CARRY_AFTER_GO_S := 1.2      ## … shown this long after the start (the HUD's "LOS!" stands 1.1 s)
var _record: Dictionary = {}
var _flash := 0.0
var _last_country := ""
var _was_city := false
var _zones_km := -1.0                ## odometer km of the last zone check (City Limits announcement)
var _was_bridge := false
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

## Graphics mode the stage is drawn in (Gfx.ARCADE | Gfx.MODERN); "arcade" after a fallback (result field gfx).
var gfx := Gfx.ARCADE
## Why Modern could not draw this stage and Arcade took over ("" = no fallback): the renderer's fail_reason() –
## "selftest:<reason>", "manifest", "shader", "timeout" – or "renderer" (it could not be created). Result field.
var gfx_fallback := ""
## Quality preset the Modern renderer's slowness watchdog stepped down to during the countdown ("" = it did not):
## "medium" | "low". For this stage only – nothing is stored; result field (the result screens may offer to keep it).
var gfx_lowered := ""
## Receiver of the sound hooks set_track / set_vehicle_state / event (contract §4.7.2); null = the AudioManager.
## Tests set a recorder before the scene enters the tree.
var audio_hooks: Object = null
## Modern start-up: PREPARING = the renderer prepares the stage (loading overlay, nothing runs), PREPARED = done in
## the last frame, the next simulation step starts the stage (_go_live), LIVE = running. Arcade is LIVE at once.
enum GfxState { LIVE, PREPARING, PREPARED }
const CRASH_GUARD_S := 2.0       ## Modern: drawn seconds after which the crash-guard marker is removed
const LOADING_LAYER := 6         ## canvas layer of the loading overlay (HUD and pause menu: 5)
var _gfx_state := GfxState.LIVE
var _loading: CanvasLayer        ## loading overlay while a Modern renderer prepares the stage
var _loading_overlay: LoadingOverlay
var _shot: Screenshotter         ## --screenshot: its clock is held while the stage is prepared
var _guard_armed := false        ## Modern: the crash-guard marker of this stage is still out
var _guard_s := -1.0             ## … drawn seconds left until it is removed (< 0: the stage has not started yet)
## The session that gave the sound its track / armed the crash guard last (instance ids). GameFlow adds the scene of
## the next stage before the one before has left the tree: a leaving stage must not take away what the new one set.
static var _track_owner := 0
static var _guard_owner := 0
var _pause_wanted := false       ## auto_pause() came while the stage was prepared: pause at the start
var _holds_shots := false        ## this stage counts in Screenshotter.preparing (every Screenshotter's clock stands)
## Seconds this scene was drawn before its first physics callback: 0 when it entered the tree between two frames
## (the race scene as main scene, a stage started from a menu), one frame when GameFlow starts it at boot (--stage:
## the deferred GameFlow.boot() runs after the physics callbacks of that frame). An Arcade stage has counted these
## frames on its clocks before its first simulation step; a Modern stage, held until then, gets them at its start.
var _lead_s := 0.0
var _ticked := false             ## the scene has had a physics callback (_lead_s is complete)
var _stage_sets: Array[String] = []   ## every sprite set the stage can show (_stage_sprite_sets)
var _stage_start_sent := false   ## sound event "stage_start" (before the first simulation step)
var _hooks_state := false        ## the sound receiver takes set_vehicle_state (checked once)
var _hit_info: Dictionary = {}   ## collision that starts the next crash (sound event "collision")

var haptics: Haptics             ## gamepad vibration (Settings.vibration, no autopilot)
var preloaded_sets: Array[String] = []   ## sprite sets loaded before the start (_preload_sprites)
var _stick_dz := 0.12            ## input.stick_deadzone
var _stick_full := 0.92          ## input.stick_full
# render interpolation: state before the last simulation step (_physics_process)
var _prev_pos_z := NAN
var _prev_x := NAN
var _prev_bg := NAN
var _prev_time := NAN
var _prev_police_off := NAN
var _view_alpha := -1.0          ## tests: fixed interpolation fraction (< 0 = Engine's)
# standby detection: wall clock vs. monotonic clock between two frames
var _wall_last := -1.0
var _ticks_last := 0


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
	var s := {
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
	# --carry-fuel=<litres>: a race stage that starts with this tank carried over from the last one (v0.7.0)
	if CliArgs.has("carry-fuel"):
		s["mode"] = "race"
		s["start_fuel_l"] = maxf(0.0, CliArgs.get_float("carry-fuel", 0.0))
	return s


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

	# graphics mode of this stage (v0.8.0): chosen once, the renderer is never swapped while the stage runs
	gfx = Gfx.MODERN if str(setup.get("gfx", Settings.effective_graphics()["mode"])) == Gfx.MODERN else Gfx.ARCADE
	if gfx == Gfx.MODERN:
		# first of all the crash-guard marker: a crash or hang while Modern builds or draws leaves it for the next start
		Settings.arm_crash_guard()
		_guard_armed = true
		_guard_owner = get_instance_id()
		if _create_renderer(Gfx.MODERN):
			get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND   # Modern fills the window
			if renderer.has_method(&"prepare"):   # the Modern-only part of the interface (RaceRenderers)
				_gfx_state = GfxState.PREPARING
		else:
			_abandon_modern("renderer")
	if gfx == Gfx.ARCADE:
		_create_renderer(Gfx.ARCADE)

	vehicle = VehicleModel.new()
	vehicle.setup(cfg, str(setup.get("vehicle", "limousine")))
	if gfx == Gfx.ARCADE:
		SpriteDB.preload_sets([str(vehicle.spec.get("sprite", ""))])   # as in v0.5.1, also with --no-sprite-preload
	var stick: Variant = ConfigLoader.lookup(cfg, "input", {})
	if stick is Dictionary:
		_stick_dz = clampf(float((stick as Dictionary).get("stick_deadzone", _stick_dz)), 0.0, 0.9)
		_stick_full = clampf(float((stick as Dictionary).get("stick_full", _stick_full)), _stick_dz + 0.05, 1.0)
	AudioManager.set_vehicle(vehicle.type_id)   # engine sound of this car (cycle bank, start clip)
	var sink := _audio_receiver()
	_hooks_state = sink != null and sink.has_method(&"set_vehicle_state")
	_audio_call(&"set_track", [track, plan])
	_track_owner = get_instance_id()

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
	_stage_sets = _stage_sprite_sets(cars, heavy)
	if gfx == Gfx.MODERN:
		_preload_sprites(SpriteDB.ids_with_tag("icon"))   # HUD icons only: the models are the renderer's job (prepare)
	elif not CliArgs.has("no-sprite-preload"):   # debug: sheets loaded when first drawn, as in v0.5.1 (A/B timing)
		_preload_sprites(_stage_sets)

	fuel = FuelSystem.new()
	# race (v0.7.0): the tank of the last stage goes on (setup start_fuel_l, -1 = the stage's own filling)
	var carried := float(setup.get("start_fuel_l", -1.0))
	fuel.setup(cfg, vehicle.spec, plan, carried)
	if CliArgs.has("fuel"):
		fuel.fuel_l = fuel.tank_l * clampf(CliArgs.get_float("fuel", 1.0), 0.0, 1.0)
		carried = fuel.fuel_l if str(setup.get("mode", "")) == "race" else -1.0
	start_fuel_l = fuel.fuel_l
	if carried >= 0.0:
		start_check = FuelSystem.start_check(cfg, vehicle.spec, plan, fuel.fuel_l)
		if str(start_check["state"]) == "tow":
			_tow_before_start()
	police = PoliceSystem.new()
	police.setup(cfg, plan)

	var start_km := clampf(float(setup.get("start_km", 0.0)), 0.0, plan.length_km - 0.5)
	pos_km = start_km
	pos_z = track.km_to_z(start_km)
	track.update_window(pos_z - proj.cam_distance, _draw_distance + 60.0)
	# start lane and speed (setup start_lane / start_speed_kmh – a flying start of the attract demos – or the debug
	# CLI) are set before the traffic is built, so the warm-up clears the start for them (Review v0.5.0)
	var lane := int(CliArgs.get_float("lane", float(setup.get("start_lane", track.lane_count_at(pos_z) - 1))))
	vehicle.x = track.lane_center_x(pos_z, clampi(lane, 0, track.lane_count_at(pos_z) - 1))
	if CliArgs.has("x"):
		vehicle.x = CliArgs.get_float("x", vehicle.x)
	cam_x = vehicle.x
	vehicle.speed = clampf(CliArgs.get_float("start-speed", float(setup.get("start_speed_kmh", 0.0))), 0.0, 300.0)
	if traffic_enabled and (CliArgs.has("traffic-warmup") or bool(setup.get("traffic_warmup", false))):
		_warm_up_traffic()
	if traffic_enabled:
		var h0 := Units.hour_of_day(_start_world_minutes)
		traffic.update(0.0, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed},
			{"hour": h0, "chase": false, "camera_z": pos_z - proj.cam_distance, "visibility_m": _visibility_m(h0),
			"weather": weather, "brake_mps2": _player_brake_mps2()})
	_last_country = plan.country_at(pos_km)
	_was_city = plan.is_city(pos_km)
	_zones_km = pos_km
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
	# rain and snow: what the weather does to the car, during the countdown (SessionRules.weather_hint)
	var weather_hint := SessionRules.weather_hint(cfg, weather)
	if weather_hint != "":
		hud.show_message(weather_hint, "warn", float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0)) + 4.0)
	# race (v0.7.0): what the carried tank means for the way to the first station – it replaces the start announcement
	# of that station and the reserve warning of the first metres. During the countdown; on a rain or snow stage the
	# weather hint holds the line above the countdown digit (a second line would reach it), then right after "LOS!".
	var carry_msgs := SessionRules.carry_messages(cfg, start_check, start_fuel_l, fuel.tank_l, start_towed)
	if not carry_msgs.is_empty():
		fuel.announce_start = false
		_reserve_warned = fuel.fuel_l < float(ConfigLoader.lookup(cfg, "fuel.reserve_warning_l", 8.0))
		if weather_hint == "":
			for m: Dictionary in carry_msgs:
				hud.show_message(str(m["text"]), str(m["kind"]), float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0)) + 4.0)
		else:
			_carry_pending = carry_msgs

	if bool(setup.get("autopilot", false)):
		autopilot = Autopilot.new()
		autopilot.target_kmh = CliArgs.get_float("autopilot-target", float(setup.get("autopilot_target",
			ConfigLoader.lookup(cfg, "debug.autopilot_target_kmh", 235.0))))
		autopilot.obey_radar = not CliArgs.has("autopilot-speeding") and not bool(setup.get("autopilot_speeding", false))
		autopilot.refuel_mode = CliArgs.get_string("autopilot-refuel", str(setup.get("autopilot_refuel", "auto")))
		autopilot.curve_brake = not CliArgs.has("autopilot-no-curve-brake") and not bool(setup.get("autopilot_no_curve_brake", false))
		# race (v0.7.0): the fuel at the finish starts the next stage – the refuel decision at the last station
		# covers the way to the next stage's first station as well (at most fuel.first_station_max_km)
		if tank_carries_on():
			autopilot.carry_km = float(ConfigLoader.lookup(cfg, "fuel.first_station_max_km", 20.0))
	if plan.tutorial or CliArgs.has("tutorial") or bool(setup.get("tutorial", false)):
		coach = TutorialCoach.new()
		coach.setup(cfg)
	haptics = Haptics.new()
	haptics.configure(cfg)
	haptics.device = InputMode.device
	haptics.enabled = autopilot == null and bool(Settings.vibration)
	if not InputSetup.pad_disconnected.is_connected(_on_pad_disconnected):
		InputSetup.pad_disconnected.connect(_on_pad_disconnected)

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
		_shot = shot
	if CliArgs.has("timescale"):
		var ts := clampf(CliArgs.get_float("timescale", 1.0), 0.05, 200.0)
		Engine.time_scale = ts
		Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
		Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	if _gfx_state == GfxState.PREPARING:
		_begin_prepare()
	elif gfx == Gfx.MODERN:
		_guard_s = CRASH_GUARD_S   # a renderer without prepare(): the stage runs at once
	elif gfx_fallback != "":
		_show_fallback_message()
	_start_wall_ms = Time.get_ticks_msec()


# --- graphics modes (v0.8.0) --------------------------------------------------------------------------------

## True once the stage runs (signal stage_live): from its first simulation step on – in Modern not while the renderer
## still prepares the stage behind the loading overlay.
func is_live() -> bool:
	return _stage_start_sent


## Creates the renderer of `mode` as the first child (below the HUD's canvas layer) and sets it up. False when the
## Modern renderer cannot be created.
func _create_renderer(mode: String) -> bool:
	var r: Node = RaceRenderers.create(mode)
	if r == null:
		return false
	renderer = r
	add_child(r)
	move_child(r, 0)
	renderer.setup(track, proj, cfg, GameData.scenery)
	if mode == Gfx.MODERN and r.has_signal(&"quality_lowered"):
		r.connect(&"quality_lowered", _on_quality_lowered)
	if mode == Gfx.ARCADE and CliArgs.has("no-glow-occlusion"):
		renderer.set_glow_occlusion(false)   # debug: lights as in v0.5.0 (A/B screenshots, docs/renn-modul.md §11)
	return true


## Modern: the renderer prepares the stage over several frames (render self-test, models, shader warm-up) behind
## the loading overlay. The HUD's timers and the Screenshotter's clock stand until the stage starts (_go_live).
func _begin_prepare() -> void:
	hud.set_process(false)
	if _shot != null:
		_shot.hold = true
	# … and so does the clock of a Screenshotter this scene does not know (GameFlow's in an attract demo); with
	# --shot-fast the picture stays rendered – the renderer's self-test and warm-up wait for drawn frames
	Screenshotter.preparing += 1
	_holds_shots = true
	_loading = CanvasLayer.new()
	_loading.layer = LOADING_LAYER
	add_child(_loading)
	var cover := ColorRect.new()   # opaque: the warm-up pictures behind it are not for the player
	cover.color = Color(0.015, 0.02, 0.07)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(cover)
	_loading_overlay = LoadingOverlay.new(tr("Etappe wird geladen …"))
	_loading.add_child(_loading_overlay)
	if renderer.has_method(&"apply_quality"):
		renderer.apply_quality(Settings.quality_levels())
	renderer.prepare({"sets": _stage_sets.duplicate(), "plan": plan, "vehicle": vehicle.type_id, "weather": weather,
		"hour": clock.hour(), "sync": CliArgs.has("gfx-sync")})


## Every frame while the Modern renderer prepares: progress of the loading overlay, the end of the preparation, or
## the fallback to Arcade when the renderer reports that it cannot draw the stage.
func _poll_prepare() -> void:
	if renderer.has_method(&"healthy") and not bool(renderer.healthy()):
		_fall_back(str(renderer.fail_reason()) if renderer.has_method(&"fail_reason") else "")
	elif not renderer.has_method(&"is_prepared") or bool(renderer.is_prepared()):
		_gfx_state = GfxState.PREPARED
	elif _loading_overlay != null and _loading_overlay.has_method(&"set_progress") and renderer.has_method(&"prepare_progress"):
		_loading_overlay.call(&"set_progress", clampf(float(renderer.prepare_progress()), 0.0, 1.0))


## The stage no longer holds the Screenshotters' clocks (it starts, or it leaves while it was still preparing).
func _release_shots() -> void:
	if _holds_shots:
		_holds_shots = false
		Screenshotter.preparing = maxi(0, Screenshotter.preparing - 1)


## The first simulation step after the preparation starts the stage: the loading overlay goes, HUD timers and the
## Screenshotter's clock run from this frame on – as from the first frame of an Arcade stage. Frames an Arcade stage
## started the same way would have drawn before its first step (_lead_s) are credited to the clocks that stood:
## the Screenshotter, the HUD's timers and the beacon phase.
func _go_live() -> void:
	_gfx_state = GfxState.LIVE
	_release_shots()
	if _loading != null:
		_loading.queue_free()
		_loading = null
		_loading_overlay = null
	hud.set_process(true)
	if _lead_s > 0.0:
		hud._process(_lead_s)
		_beacon_t += _lead_s
	if is_instance_valid(_shot):   # the attract mode frees the session's Screenshotter
		_shot.hold = false
		_shot.skip(_lead_s)
	if gfx == Gfx.MODERN and _guard_armed:
		_guard_s = CRASH_GUARD_S
	if _pause_wanted:
		_pause_wanted = false
		auto_pause.call_deferred()


## Modern cannot draw this stage (render self-test failed, model manifest missing or broken, shader error, timeout):
## the Arcade renderer takes over before the stage starts – its sprite sheets are loaded now, the window goes back
## to 16:9 with bars, the HUD says so and the result carries gfx = "arcade" and gfx_fallback = <reason>.
func _fall_back(reason: String) -> void:
	if renderer != null:
		remove_child(renderer)
		renderer.queue_free()
		renderer = null
	_abandon_modern(reason)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_create_renderer(Gfx.ARCADE)
	SpriteDB.preload_sets([str(vehicle.spec.get("sprite", ""))])
	if not CliArgs.has("no-sprite-preload"):
		_preload_sprites(_stage_sets)
	_show_fallback_message()
	_gfx_state = GfxState.PREPARED


## Book-keeping of a fallback: mode and reason of the result; the crash-guard marker of this stage goes (Modern
## failed in an orderly way).
func _abandon_modern(reason: String) -> void:
	gfx = Gfx.ARCADE
	gfx_fallback = reason if reason != "" else "unknown"
	_release_crash_guard(false)
	push_warning("Modus Modern nicht möglich (%s) – die Etappe läuft im Modus Arcade" % gfx_fallback)


## Modern: the slowness watchdog of the renderer stepped the quality preset down (once, during the countdown).
func _on_quality_lowered(preset: String) -> void:
	gfx_lowered = preset
	var names := {"low": tr("Niedrig"), "medium": tr("Mittel"), "high": tr("Hoch"), "deck": tr("Steam Deck")}
	if hud != null:
		hud.show_message(tr("Das Bild läuft zu langsam – die Grafikqualität ist für diese Etappe auf „%s“ gesenkt.") % str(names.get(preset, preset)),
			"warn", 6.0)


func _show_fallback_message() -> void:
	hud.show_message(tr("Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten. Das Spiel läuft im Modus „Arcade“ weiter."),
		"warn", float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0)) + 6.0)


## Modern: the crash-guard marker goes after CRASH_GUARD_S of drawn frames (real seconds, also in fast time).
func _tick_crash_guard(delta: float) -> void:
	if not _guard_armed or _guard_s <= 0.0:
		return
	_guard_s -= delta / maxf(Engine.time_scale, 0.001)
	if _guard_s <= 0.0:
		_release_crash_guard(true)


## Takes back the crash-guard marker of this stage. works = Modern has drawn for CRASH_GUARD_S: a marker of the last
## run is settled as well (Modern may be used again in this run). Otherwise – fallback to Arcade, the stage leaves
## the tree in an orderly way – a marker of the last run stays for the question on the title. A marker that a newer
## stage has armed in the meantime is not ours to remove.
func _release_crash_guard(works: bool) -> void:
	if not _guard_armed:
		return
	_guard_armed = false
	_guard_s = -1.0
	if _guard_owner != get_instance_id():
		return
	_guard_owner = 0
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	if works:
		settings.call("disarm_crash_guard")
	elif not bool(settings.get("crash_guard")):
		settings.call("disarm_crash_guard", false)


## The receiver of the sound hooks (audio_hooks or the AudioManager); null once it is gone (the game is quitting).
func _audio_receiver() -> Object:
	var a: Object = audio_hooks if audio_hooks != null else AudioManager
	return a if is_instance_valid(a) else null


## Calls a hook of the Modern sound if the receiver has it (set_track, set_vehicle_state, event – contract §4.7.2;
## with the Arcade sound profile the AudioManager ignores them).
func _audio_call(method: StringName, args: Array) -> void:
	var a := _audio_receiver()
	if a != null and a.has_method(method):
		a.callv(method, args)


## Sound event of the stage (in addition to the unchanged AudioManager.play() calls).
func _audio_event(event_name: String, args: Dictionary = {}) -> void:
	_audio_call(&"event", [event_name, args])


## The car's state for the sound, every frame of a running stage (contract §4.7.2): position of the car centre,
## driving state, road edges at the car, camera in a tunnel, weather and hour.
func _audio_state(vz: float, vx: float, throttle: float, cam_tunnel: bool, hour: float) -> Dictionary:
	var edges := track.road_edges_at(pos_z)
	return {"z": vz, "x": vx, "speed": vehicle.speed, "throttle": throttle, "brake": float(last_input.get("brake", 0.0)),
		"steer": float(last_input.get("steer", 0.0)), "understeer": vehicle.understeer, "lat_speed": vehicle.lat_speed,
		"off_road": vehicle.off_road, "rail_contact": vehicle.rail_contact, "road_left": edges.x, "road_right": edges.y,
		"shoulder_m": track.shoulder_w, "in_tunnel": cam_tunnel, "weather": weather, "hour": hour,
		"crash": vehicle.state == VehicleModel.State.CRASH, "finished": finished}


## Loads every sprite sheet the stage can draw before the start: the player's car, all traffic and heavy vehicles,
## the police of the stage's countries, the track's props, landmarks and skyline (Track.sprite_sets(), a missing
## set by its fallback) and the HUD's weather / daytime icons (the daytime changes during a stage). SpriteDB loaded
## a sheet when it was first drawn – synchronously in the middle of the frame: 13–20 ms for a building, 16 ms for a
## truck, 33 ms for the Frankfurt skyline at a 7 ms median (QA v0.5.1; more on a Steam Deck reading from a microSD
## card). Costs ~0.2–0.3 s more loading of the first stage; the sheets stay cached.
## Modern (v0.8.0) loads only the HUD icons this way; the list of the stage's sets goes to its renderer (prepare).
func _preload_sprites(ids: Array[String]) -> void:
	var fallbacks := track.sprite_fallbacks()
	preloaded_sets.clear()
	for id in ids:
		if id == "" or preloaded_sets.has(id):
			continue
		preloaded_sets.append(id)
		if SpriteDB.texture(id) == null and fallbacks.has(id):
			SpriteDB.texture(str(fallbacks[id]))


## Every sprite set the stage can show, each once, in loading order: the player's car, all traffic and heavy
## vehicles, the police of the stage's countries, the HUD icons, the track's props, landmarks and skyline.
func _stage_sprite_sets(cars: Array[String], heavy: Array[String]) -> Array[String]:
	var ids: Array[String] = [str(vehicle.spec.get("sprite", ""))]
	ids.append_array(cars)
	ids.append_array(heavy)
	for code in plan.countries_in_order:
		ids.append(GameData.police_set_for(str(code)))
	ids.append_array(SpriteDB.ids_with_tag("icon"))
	for id in track.sprite_sets():
		ids.append(id)
	var out: Array[String] = []
	for id in ids:
		if id != "" and not out.has(id):
			out.append(id)
	return out


## Full braking (m/s²) of the player's car in this weather (TrafficSystem ctx.brake_mps2: no car pulls out in front
## of the player closer than he can still brake for). The weather grip also inside a tunnel: the dry tunnel road
## would let a car beyond the exit pull out at the dry floor, which the player cannot meet back on snow.
func _player_brake_mps2() -> float:
	return vehicle.brake_decel_mps2(env.grip(weather))


## Current sight distance (m): draw distance reduced by night, weather and tunnels.
func _visibility_m(hour: float) -> float:
	return _draw_distance * env.visibility_factor(hour, weather, track.is_tunnel_at(pos_z - proj.cam_distance + 5.0))


## Debug/screenshots/attract demos: lets traffic build up around the start position by simulating a virtual
## player that approaches from 1.5 km behind at 250 km/h (TrafficSystem only spawns ahead). Then the start is cleared
## for the start speed (Review v0.5.0 – the demos start at 90–170 km/h; a car 15 m ahead at 38 km/h meant a hard brake
## right after the fade-in, and moving the cars around the player 40 m ahead put one only 15–25 m in front of him): a
## car in the start lane from 30 m behind to warm_up_clear_m() ahead goes behind the player.
func _warm_up_traffic() -> void:
	var hour := Units.hour_of_day(_start_world_minutes)
	var fake := maxf(0.0, pos_z - 1500.0)
	while fake < pos_z:
		var step := minf(14.0, pos_z - fake)
		fake += step
		traffic.update(0.2, {"z": fake, "x": vehicle.x, "speed": 250.0}, {"hour": hour, "chase": false, "camera_z": fake - proj.cam_distance,
			"weather": weather, "brake_mps2": _player_brake_mps2()})
	var behind := pos_z - 30.0
	var moved: Array = []
	for c in traffic.cars:
		var dz: float = c.z - pos_z
		if absf(c.x - vehicle.x) < (c.width + vehicle.width_m) * 0.5 + 0.6 and dz > -30.0 and dz < warm_up_clear_m(c.speed):
			moved.append(c)
	moved.sort_custom(func(a: Object, b: Object) -> bool: return float(a.get("z")) > float(b.get("z")))
	for c in moved:
		behind -= maxf(25.0, (c.length + vehicle.length_m) * 0.5 + 18.0)
		c.z = behind
		c.speed = minf(c.speed, vehicle.speed)


## Gap (m) a car at car_kmh needs ahead of the player in his lane at the start: 12 m + 0.9 s at the start speed plus the
## braking distance down to its speed with half the player's braking in this weather.
func warm_up_clear_m(car_kmh: float) -> float:
	var v := vehicle.speed / 3.6
	var rel := maxf(0.0, v - car_kmh / 3.6)
	return 12.0 + v * 0.9 + rel * rel / (2.0 * 0.5 * _player_brake_mps2())


func _connect_signals() -> void:
	# k = the threshold (30 / 15 / 5) or, at the start, the real distance to the first station (0.1 km: "in 8,5 km")
	fuel.announced.connect(func(k: float, st: float) -> void:
		if k <= 5.0:
			hud.show_message(tr("Tankstelle in %s km – Tankspur rechts") % UiFormat.number(k, 1), "info", 3.5)
			_tutorial("fuel_lane")
			# race (v0.7.0): at the lane of the last station the tank is decided for the next stage as well – with the
			# tutorial coach (it explains the fuel lane right now) said once the car has passed the station
			if tank_carries_on() and not _last_station_noted and not plan.fuel_stations_km.is_empty() \
					and absf(st - plan.fuel_stations_km[-1]) < 0.001:
				_last_station_noted = true
				if coach != null:
					_last_station_after = st
				else:
					hud.show_message(tr("Letzte Tankstelle vor dem Ziel – der Tank geht in die nächste Etappe mit"), "info", 4.0)
		else:
			hud.show_message(tr("Tankstelle in %s km") % UiFormat.number(k, 1), "info")
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
		haptics.radar_flash()
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
		if not finished:
			haptics.collision()
		AudioManager.play("crash")
		hud.flash(Color(1, 0.3, 0.2, 0.35), 0.25))
	# sound events of the Modern profile (v0.8.0, contract §4.7.2): sent next to the play() calls above, in both
	# graphics modes and both sound profiles (connected after them – the play() of an event comes first)
	fuel.refuel_started.connect(func() -> void: _audio_event("refuel_start"))
	fuel.refuel_finished.connect(func(l: float, aborted: bool) -> void: _audio_event("refuel_done", {"liters": l, "aborted": aborted}))
	fuel.ran_dry.connect(func() -> void: _audio_event("out_of_fuel"))
	fuel.tow_started.connect(func() -> void: _audio_event("tow"))
	police.flashed.connect(func(_r: Dictionary, _v: float) -> void: _audio_event("radar_flash"))
	police.chase_started.connect(func() -> void: _audio_event("chase_start"))
	police.escaped.connect(func() -> void: _audio_event("escaped"))
	police.caught.connect(func() -> void: _audio_event("busted"))
	vehicle.crash_started.connect(func(_d: int) -> void: _audio_event("collision", _hit_info))


## Tutorial stage: queue the hints of a topic (no-op on other stages).
func _tutorial(topic: String, args: Dictionary = {}) -> void:
	if coach != null:
		coach.trigger(topic, args)


## Race (v0.7.0): the fuel at the finish goes into the next stage – in a race, except on its last stage (setup
## last_stage, GameFlow.stage_setup).
func tank_carries_on() -> bool:
	return str(setup.get("mode", "")) == "race" and not bool(setup.get("last_stage", false))


## Race (v0.7.0): the tank carried over from the last stage does not reach the first fuel lane even at the lane
## trigger speed (FuelSystem.start_check "tow") – the tow service comes before the start, at the price of a tow on
## the road: fuel.tow_penalty_s in the stage time (and on the world clock, as on the road), the tank filled up to
## fuel.tow_refill_fraction, one tow in the statistics. The countdown says so (SessionRules.carry_messages).
func _tow_before_start() -> void:
	var pen := float(ConfigLoader.lookup(cfg, "fuel.tow_penalty_s", 90.0))
	start_towed = true
	penalty_time += pen
	clock.advance(pen)
	fuel.fuel_l = maxf(fuel.fuel_l, fuel.tank_l * float(ConfigLoader.lookup(cfg, "fuel.tow_refill_fraction", 0.5)))
	stats["tows"] += 1


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
			_pause_now()
		get_viewport().set_input_as_handled()


## Pauses the race and opens the pause menu: engine, wind, siren, rain and skid sounds off, vibration off, the
## frame rate capped (FrameCap) while the paused picture stands.
func _pause_now() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	AudioManager.set_engine(0.0, 0.0, vehicle.vmax_effective, false)
	AudioManager.set_wind(0.0)
	AudioManager.set_siren(false, 0.0)
	AudioManager.set_rain(0.0)
	AudioManager.set_skid(0.0)
	if haptics != null:
		haptics.stop()
	FrameCap.hold("pause", true)
	pause_menu.open()


## Pause without the player's pause key – the window lost the focus, the gamepad in use was disconnected, the game came
## back from standby: in the countdown as well (the race would start without the player), not in demos, debug runs and
## after the finish.
func auto_pause() -> void:
	if plan != null and not finished and autopilot == null and not standalone:
		if _gfx_state != GfxState.LIVE:
			_pause_wanted = true   # Modern is still preparing the stage: pause when it starts (_go_live)
			return
		_pause_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		auto_pause()
	elif what == NOTIFICATION_EXIT_TREE:
		if haptics != null:
			haptics.stop()
		FrameCap.hold("pause", false)
		_leave_stage()


## The scene leaves the tree in an orderly way (next stage, back to the menus, the game quits): the sound gets its
## track back (set_track(null, null)) and a Modern stage takes its crash-guard marker along, also when it was still
## preparing – unless the next stage has already set its own (see _track_owner).
func _leave_stage() -> void:
	if plan == null:
		return
	_release_shots()
	if _track_owner == get_instance_id():
		_track_owner = 0
		_audio_call(&"set_track", [null, null])
	_release_crash_guard(false)


## A gamepad was disconnected (InputSetup.pad_disconnected: battery, Bluetooth, the docked Steam Deck's external pad).
## The engine has released what that pad held – only its own state: a key the player holds and the other pads keep
## theirs. The race pauses when the pad was in use – the active pad, or one still holding a button, stick or trigger
## (InputMode.pad_lost) –: it must not go on without the player's throttle or steering. A keyboard player's idle pad
## switching off changes nothing (QA v0.5.1 review: every disconnect paused and released the keyboard as well).
func _on_pad_disconnected(_device: int, in_use: bool) -> void:
	if in_use:
		auto_pause()


func _on_resume() -> void:
	get_tree().paused = false
	FrameCap.hold("pause", false)
	_wall_last = -1.0   # a standby during the pause must not pause the race again right after resuming
	pause_menu.close()
	if police.chase_active():
		AudioManager.set_siren(true, _chase01())


func _on_restart() -> void:
	get_tree().paused = false
	FrameCap.hold("pause", false)
	AudioManager.stop_all()
	if standalone:
		get_tree().reload_current_scene()
	else:
		restart_requested.emit()


func _on_quit() -> void:
	get_tree().paused = false
	FrameCap.hold("pause", false)
	AudioManager.stop_all()
	if standalone:
		get_tree().quit()
	else:
		stage_aborted.emit("quit")


func _read_input() -> Dictionary:
	if autopilot != null:
		return autopilot.drive(self)
	return {
		"steer": player_steer(_stick_dz, _stick_full),
		"throttle": Input.get_action_strength("accelerate"),
		"brake": Input.get_action_strength("brake"),
	}


## The player's steering (-1 left … 1 right): keys and the D-pad of every pad (steer_left / steer_right, full lock) and
## the left stick of the active gamepad only (InputMode.device – the pad used last, it follows a switch of pads in the
## race) through the stick curve (SessionRules.pad_steer). With every pad's stick in the actions, a resting second pad
## with a drifting stick (0.13–0.2, above the deadzone 0.12) steered (QA v0.5.1 review).
## Only a pad used since it connected steers by its stick (InputMode.stick_device()): a keyboard player's resting pad with
## a drifting stick steers nothing (review v0.6.0).
static func player_steer(deadzone: float, full: float) -> float:
	var dev := InputMode.stick_device()
	var stick := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X) if dev >= 0 else 0.0
	return SessionRules.pad_steer(Input.get_action_raw_strength("steer_right"), Input.get_action_raw_strength("steer_left"),
		stick, deadzone, full)


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
		"grip": track.grip_at(z, env.grip(weather)),   # dry inside tunnels
	}


func _physics_process(dt: float) -> void:
	if plan == null:
		return
	_ticked = true
	if _gfx_state != GfxState.LIVE:
		if _gfx_state == GfxState.PREPARING:
			return   # Modern is still preparing the stage: nothing of it runs yet
		_go_live()
	if not _stage_start_sent:
		_stage_start_sent = true
		stage_live.emit()
		_audio_event("stage_start", {"countdown_s": countdown})
	_snapshot()
	var t0 := Time.get_ticks_usec()
	_step(dt)
	var us := Time.get_ticks_usec() - t0
	_sim_us_sum += us
	_sim_us_max = maxi(_sim_us_max, us)
	_sim_steps += 1


## State before a simulation step, for the interpolated view (view_state()): camera position, the car's lateral
## position, background heading, time, the police car and every traffic car (TrafficSystem.Car.prev_z / prev_x).
func _snapshot() -> void:
	_prev_pos_z = pos_z
	_prev_x = vehicle.x
	_prev_bg = bg_offset
	_prev_time = _real_time
	_prev_police_off = police.police_car_offset_m()
	if traffic_enabled:
		for c in traffic.cars:
			c.prev_z = c.z
			c.prev_x = c.x


## Interpolation fraction of the frame being drawn: how far the time of this frame is past the last simulation
## step, in steps (Engine.get_physics_interpolation_fraction; tests may fix it with _view_alpha).
func view_alpha() -> float:
	if _view_alpha >= 0.0:
		return _view_alpha
	return clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)


## What the frame shows: the state between the last two simulation steps at view_alpha() – camera / car z, the
## car's x, background heading and time. The simulation itself stays at fixed steps (leaderboards, autopilot).
func view_state() -> Dictionary:
	var a := view_alpha()
	return {"alpha": a, "pos_z": SessionRules.lerp_view(_prev_pos_z, pos_z, a), "x": SessionRules.lerp_view(_prev_x, vehicle.x, a),
		"bg": SessionRules.lerp_view(_prev_bg, bg_offset, a, INF), "time": SessionRules.lerp_view(_prev_time, _real_time, a, INF)}


## Vibration of this step (Haptics): the continuous level of the car's state and the running pulses – only while a
## gamepad is the active input (a keyboard player's idle pad stays quiet).
func _update_haptics(dt: float) -> void:
	if haptics == null:
		return
	haptics.device = InputMode.device
	haptics.active = InputMode.gamepad
	haptics.update(dt, haptics.level_for(vehicle.speed, vehicle.off_road, vehicle.rail_contact, vehicle.understeer))


## Back from standby (Steam Deck: power button) the race pauses: the wall clock went on during the sleep, the
## monotonic clock of the frame times stood still (SessionRules.resumed_from_sleep). A hitch moves both alike.
func _check_standby() -> void:
	var wall := Time.get_unix_time_from_system()
	var ticks := Time.get_ticks_msec()
	if _wall_last >= 0.0 and SessionRules.resumed_from_sleep(wall - _wall_last, float(ticks - _ticks_last) / 1000.0):
		auto_pause()
	_wall_last = wall
	_ticks_last = ticks


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
			_audio_event("countdown", {"n": sec})
		if countdown <= 0.0:
			running = true
			hud.show_message(tr("LOS!"), "info", 1.2)
			AudioManager.play("go")
			_audio_event("go")
			if coach != null:
				# v0.7.0: the first station is only 15 km away – the low tank comes first (urgent), then the controls
				if fuel.fuel_l < fuel.tank_l * 0.6:
					coach.trigger("fuel_low", {"percent": 100.0 * fuel.fuel_l / maxf(fuel.tank_l, 0.001),
						"km": fuel.distance_to_next_station(pos_km)})
				coach.trigger("start")
				coach.trigger("fuel_hud")
				coach.hold(1.2)   # let "LOS!" stand alone for a moment
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
	_track_driving(dt)
	_update_haptics(dt)
	var dz := vehicle.speed / 3.6 * dt
	pos_z += dz
	var dkm := Units.visual_m_to_km(dz, time_scale)
	pos_km = track.z_to_km(pos_z)
	var cam_z := pos_z - proj.cam_distance
	track.update_window(cam_z, _draw_distance + 60.0)
	if traffic_enabled:
		traffic.update(dt, {"z": pos_z, "x": vehicle.x, "speed": vehicle.speed},
			{"hour": hour, "chase": police.chase_active(), "camera_z": cam_z, "visibility_m": _visibility_m(hour),
			"weather": weather, "brake_mps2": _player_brake_mps2()})
		_check_collision(cam_z, vehicle.state == VehicleModel.State.AUTO)
	var in_lane := track.fuel_lane_at(pos_z) and vehicle.x > track.main_right_edge(pos_z)
	fuel.update(dt, pos_km, dkm, vehicle.speed, in_lane, float(input.get("throttle", 0.0)))
	# while the fuel system holds the car (refuelling, tow) the police stop waits: a capture during
	# refuelling is served after the refuel
	police.set_blocked(fuel.state != FuelSystem.State.NORMAL)
	police.update(dt, pos_km, vehicle.speed, _police_curve_cap())
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
		print("TRACE km %6.1f  t %6.1f  v %5.1f  want %5.1f  x %5.2f  curve %5.2f  grade %5.3f  us %4.2f  fuel %4.1f  cars %d  state %d  %s" % [pos_km, total_time(), vehicle.speed,
			autopilot.last_want if autopilot != null else -1.0, vehicle.x, track.curve_at(pos_z), track.grade_at(pos_z), vehicle.understeer, fuel.fuel_l, traffic.cars.size(), vehicle.state, autopilot.last_reason if autopilot != null else ""])
	if pos_km >= plan.length_km:
		_finish()


## Curve limit of the police car at the player's position (PoliceSystem.update road_cap_kmh): only needed
## while a chase runs or one can start (a radar is announced/active), INF otherwise.
func _police_curve_cap() -> float:
	if police.state != PoliceSystem.State.CHASE and police.active_radar.is_empty():
		return INF
	return SessionRules.police_curve_cap_kmh(track, police, pos_z, env.grip(weather))


## Driving diagnostics (drive_stats), the feedback of a guardrail hit and the curve hint of the tutorial stage:
## it comes when the car understeers or a curve within the next 250 m needs clearly less than the current speed.
func _track_driving(dt: float) -> void:
	_tutorial_traffic()
	if vehicle.off_road > 0:
		drive_stats["off_road_s"] += dt
	if vehicle.off_road > 1:
		drive_stats["limit_s"] += dt
	if vehicle.rail_hit:
		drive_stats["rail_hits"] += 1
		_rail_feedback(vehicle.rail_impact)
		haptics.rail_hit(vehicle.rail_impact)
		# metal on metal: a light touch is a scrape, a slide into the rail (understeer drift) a loud bang
		AudioManager.play("rail", clampf(-10.0 + 2.0 * vehicle.rail_impact, -10.0, 2.0))
		var rail_edges := track.road_edges_at(pos_z)
		_audio_event("rail_hit", {"impact_mps": vehicle.rail_impact, "side": -1 if vehicle.x < (rail_edges.x + rail_edges.y) * 0.5 else 1})
	if vehicle.understeer > 0.0:
		drive_stats["understeer_s"] += dt
	drive_stats["understeer_max"] = maxf(float(drive_stats["understeer_max"]), vehicle.understeer)
	if coach == null or coach.shown.has("curve") or vehicle.state != VehicleModel.State.DRIVING:
		return
	var warn := vehicle.understeer > 0.3
	var grip := env.grip(weather)
	var d := 20.0
	while not warn and d <= 250.0:
		warn = vehicle.speed > vehicle.safe_curve_speed(track.curve_at(pos_z + d), track.grip_at(pos_z + d, grip)) * 1.05
		d += 10.0
	if warn:
		_tutorial("curve")


## Tutorial hints on the traffic rules of v0.5.0 (QA: the coach did not explain them): the first car within 200 m
## ahead that signals (it pulls out at once – "blinker"), the first truck overtaking a truck ahead ("elephant").
func _tutorial_traffic() -> void:
	if coach == null or not traffic_enabled or (coach.shown.has("blinker") and coach.shown.has("elephant")):
		return
	for c in traffic.cars:
		var dz: float = c.z - pos_z
		if dz <= 5.0 or dz > 200.0:
			continue
		if c.signal_dir != 0 and c.signal_lane != TrafficSystem.FUEL_LANE and absf(c.x - vehicle.x) < 6.0:
			_tutorial("blinker")
		if c.heavy and c.elephant_t >= 0.0:
			_tutorial("elephant")


## A guardrail hit is felt (the speed loss of an understeer slide into the rail can be half the speed): camera
## shake from render.rail_shake_min_s (a touch) up to render.rail_shake_max_s with the drift that hit the rail
## (rail_impact / render.rail_shake_full_mps), and from render.rail_flash_min_mps of drift a short flash.
## The impact sound belongs to the audio module (vehicle.rail_hit / rail_impact).
func _rail_feedback(impact_mps: float) -> void:
	var k := clampf(impact_mps / maxf(0.01, float(ConfigLoader.lookup(cfg, "render.rail_shake_full_mps", 8.0))), 0.0, 1.0)
	var lo := float(ConfigLoader.lookup(cfg, "render.rail_shake_min_s", 0.15))
	var hi := float(ConfigLoader.lookup(cfg, "render.rail_shake_max_s", 0.45))
	_shake_t = maxf(_shake_t, lerpf(lo, hi, k))
	if impact_mps >= float(ConfigLoader.lookup(cfg, "render.rail_flash_min_mps", 2.0)):
		hud.flash(Color(1.0, 0.55, 0.25, 0.12 + 0.2 * k), 0.12 + 0.1 * k)


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
			{"hour": clock.hour(), "chase": false, "camera_z": cam_z, "visibility_m": _visibility_m(clock.hour()),
			"weather": weather, "brake_mps2": _player_brake_mps2()})
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
	# for the sound event "collision": the player's speed, the closing speed, a heavy vehicle, the side it is on
	var hit_dx: float = hit.x - vehicle.x
	_hit_info = {"speed_kmh": vehicle.speed, "rel_kmh": vehicle.speed - float(hit.speed), "heavy": bool(hit.heavy),
		"side": 0 if absf(hit_dx) < 0.3 else (-1 if hit_dx < 0.0 else 1)}
	vehicle.start_crash(hit.x, space.x, space.y)


func _check_zones() -> void:
	if not _carry_pending.is_empty() and stage_time >= CARRY_AFTER_GO_S:
		for m: Dictionary in _carry_pending:
			hud.show_message(str(m["text"]), str(m["kind"]), 6.0)
		_carry_pending.clear()
	if _last_station_after >= 0.0 and pos_km > _last_station_after + 0.05 and fuel.state == FuelSystem.State.NORMAL:
		_last_station_after = -1.0
		hud.show_message(tr("Das war die letzte Tankstelle vor dem Ziel – der Tank geht in die nächste Etappe mit"), "info", 4.0)
	var country := plan.country_at(pos_km)
	if country != _last_country:
		_last_country = country
		var local := str(GameData.countries.get(country, {}).get("name_local", ""))
		var name := GameData.country_name(country)
		hud.show_message((tr("Grenze: %s") % name) + ("" if local == "" or local == name else "  ·  " + local), "info", 3.0)
	var city := plan.is_city(pos_km)
	if SessionRules.city_announce_due(_zones_km, pos_km, plan.city_limits_km, track.city_announce_km()):
		hud.show_message(SessionRules.city_announce_text(plan.to_name, track.city_announce_km(), plan.city_speed_limit), "info", 3.5)
	_zones_km = pos_km
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
	var bridge := plan.bridge_at(pos_km)
	if not bridge.is_empty() and not _was_bridge and str(bridge.get("name", "")) != "":
		hud.show_message(str(bridge["name"]), "info", 2.0)
	_was_bridge = not bridge.is_empty()
	var reserve := float(ConfigLoader.lookup(cfg, "fuel.reserve_warning_l", 8.0))
	if fuel.fuel_l < reserve and not _reserve_warned and fuel.state == FuelSystem.State.NORMAL:
		_reserve_warned = true
		var st := fuel.distance_to_next_station(pos_km)
		if st >= 0.0:
			hud.show_message(tr("Reserve! Nächste Tankstelle in %d km") % int(round(st)), "warn", 3.5)
		else:
			hud.show_message(tr("Reserve! Keine Tankstelle mehr bis zum Ziel"), "warn", 3.5)


func _finish() -> void:
	_final_fuel_l = fuel.fuel_l
	_final_time = stage_time + penalty_time
	finished = true
	haptics.stop()
	_finish_timer = float(ConfigLoader.lookup(cfg, "render.finish_hold_s", 6.0))
	pos_km = plan.length_km
	AudioManager.play("finish")
	AudioManager.set_siren(false, 0.0)
	var best := float(_record.get("time_s", -1.0))
	_audio_event("stage_finish", {"record": best < 0.0 or _final_time < best, "last_stage": bool(setup.get("last_stage", false))})
	hud.show_message(tr("ZIEL!  %s") % Units.format_race_time(_final_time), "info", 5.0)


func total_time() -> float:
	if finished:
		return _final_time
	return stage_time + penalty_time


func build_result() -> Dictionary:
	var t := total_time()
	var start_hour := Units.hour_of_day(_start_world_minutes)
	var r := {
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
		"fuel_start_l": start_fuel_l,
		"fuel_end_l": _final_fuel_l if _final_fuel_l >= 0.0 else fuel.fuel_l,
		"tank_l": fuel.tank_l,
		"start_towed": start_towed,
		"aborted": false,
		# v0.8.0: graphics mode the stage was drawn in (hidden field for later analysis – never shown, never a filter)
		"gfx": gfx,
	}
	if gfx_fallback != "":
		r["gfx_fallback"] = gfx_fallback   # Modern was wanted, Arcade drew the stage: why
	if gfx_lowered != "":
		r["gfx_lowered"] = gfx_lowered     # the slowness watchdog stepped the quality preset down to this one
	return r


## Simulation and render timing (for tests/race/run_stage.gd and --perf), plus drive_stats as "drive".
func perf_stats() -> Dictionary:
	var r: Dictionary = renderer.perf_stats() if renderer != null else {}
	r["sim_steps"] = _sim_steps
	r["sim_avg_ms"] = float(_sim_us_sum) / maxf(1.0, float(_sim_steps)) / 1000.0
	r["sim_max_ms"] = float(_sim_us_max) / 1000.0
	r["wall_s"] = float(Time.get_ticks_msec() - _start_wall_ms) / 1000.0
	r["drive"] = drive_stats
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
	if not _ticked:
		_lead_s += delta   # drawn before the first physics callback (see _lead_s)
	if _gfx_state == GfxState.PREPARING:
		_poll_prepare()
	# Modern prepares the stage: the frozen start view is still drawn (behind the loading overlay – the renderer
	# builds and warms up what the first frame shows), but HUD, sound and every clock wait for the start
	var live := _gfx_state == GfxState.LIVE
	if live:
		_check_standby()
		_beacon_t += delta
	# the frame shows the state at its own time, between the last two simulation steps (render interpolation)
	var vs := view_state()
	var a: float = vs["alpha"]
	var vz: float = vs["pos_z"]
	var vx: float = vs["x"]
	var follow := float(ConfigLoader.lookup(cfg, "render.camera_follow", 7.0))
	var lag := float(ConfigLoader.lookup(cfg, "render.camera_lag_max_m", 1.1))
	cam_x = lerpf(cam_x, vx, 1.0 - exp(-follow * delta))
	cam_x = clampf(cam_x, vx - lag, vx + lag)
	var cam_z := vz - proj.cam_distance
	var hour := clock.hour()
	var cam_tunnel := track.is_tunnel_at(cam_z + 1.0)
	var pal := Palette.compute(hour, weather, ConfigLoader.lookup(cfg, "daytime", {}), false)
	var vis := _draw_distance * env.visibility_factor(hour, weather, cam_tunnel)
	var lights := float(pal.get("lights", 0.0))
	var cars: Array = []
	if traffic_enabled:
		for c in traffic.cars:
			cars.append({"kind": "car", "id": c.id, "set": c.set_id, "z": SessionRules.lerp_view(c.prev_z, c.z, a) - c.length * 0.5,
				"x": SessionRules.lerp_view(c.prev_x, c.x, a), "length": c.length,
				"tail": lights, "brake": 1.0 if c.braking else 0.0, "speed": c.speed, "heavy": c.heavy,
				"blink": c.signal_dir, "blink_t": c.signal_age})
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
		var off_v := SessionRules.lerp_view(_prev_police_off, off, a)
		var px := SessionRules.police_car_x(off_v, vx, _police_side, track.lane_w, _pull_over_m, (4.8 + vehicle.length_m) * 0.5)
		cars.append({"kind": "car", "id": POLICE_VIEW_ID, "set": GameData.police_set_for(plan.country_at(clampf(pos_km, 0.0, plan.length_km))), "z": vz + off_v - 2.4,
			"x": px, "tail": lights, "length": 4.8, "speed": maxf(0.0, vehicle.speed + _police_rel_kmh),
			"beacon": "a" if fmod(_beacon_t, 0.5) < 0.25 else "b"})
	# the renderer derives the visible yaw and body roll of the car from these (docs/renn-modul.md §8)
	var player := {"kind": "car", "player": true, "set": str(vehicle.spec.get("sprite", "player/limousine")),
		"type": vehicle.type_id,
		"z": vz - vehicle.length_m * 0.5, "x": vx, "length": vehicle.length_m, "width": vehicle.width_m,
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
		"camera_y": track.height_at(vz) + proj.cam_height,
		"camera_in_tunnel": cam_tunnel,
		"visibility_m": vis,
		"palette": pal,
		"weather": weather,
		"time": float(vs["time"]),
		"speed": vehicle.speed,
		"cars": cars,
		"player": player,
		"bg_offset": float(vs["bg"]),
		"scenery": plan.scenery_for(clampf(pos_km, 0.0, plan.length_km), GameData.scenery),
		"shake": shake,
		"countdown": countdown if not running else (-0.5 if _real_time < 1.0 + float(ConfigLoader.lookup(cfg, "time.countdown_s", 3.0)) else -1000.0),
		"chase01": chase,
		"radar_flash01": _flash,
		# v0.8.0, ignored by the Arcade renderer: world hour and the seconds of this frame
		"hour": hour,
		"dt": delta,
	})
	if not live:
		return
	_tick_crash_guard(delta)
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
	if _hooks_state:
		_audio_call(&"set_vehicle_state", [_audio_state(vz, vx, throttle, cam_tunnel, hour)])


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
		"escape_kmh": police.escape_kmh,
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
