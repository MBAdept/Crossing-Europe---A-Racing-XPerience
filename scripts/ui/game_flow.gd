extends Node
## Autoload "GameFlow": screen flow – title, race/stage selection, vehicle, start time, route choice,
## stage screen (map, weather, record marquee, top 10), race, results/name entry, leaderboards,
## options, ferry scene, save/continue. Owner: UI module. Public API = contract (ARCHITECTURE.md §10):
## boot(), start_stage(setup). Navigation helpers below are additions (docs/ui.md).
##
## Race progression lives in RaceState (pure, unit tested); data access goes through UiData.
## The attract mode (child AttractMode, `attract`) shows a demo after a minute without input on the title; its
## race scene comes from start_attract_stage() and never reaches the race flow (nothing is saved).
## Debug: --screen=<title|race_select|vehicle|start_time|stage_select|route_choice|stage_screen|
## result|race_result|leaderboards|options|ferry|graphics_choice|benchmark> shows a screen with sample data
## (screenshots); with --sample-fuel=<litres> the stage screen shows that tank carried over from the last stage.
##
## v0.8.0, graphics modes (docs/grafik-modi.md, docs/dev/v080_contract.md §4.1, §4.7.1, §4.8):
## - first start without a stored graphics mode and without any command line argument: the chooser "GRAFIK WÄHLEN"
##   before the title (Settings.needs_graphics_choice(), contract D32);
## - the sound profile: AudioManager.set_profile(Settings.sound()) at boot and whenever the resolved profile changes
##   (Settings.sound_profile_changed) – never while a stage runs: such a change waits for the menus or the next
##   stage. Next to every set_music() the music context of the Modern sound is set (set_music_context: "title",
##   "menu", "race_menu" for the screens between stages, "race", "result");
## - leaving the mode "Modern" (options, chooser, the crash-guard question) frees what Modern loaded (model caches,
##   shared materials) – through the scripts' paths and only if something loaded them: no file an Arcade start
##   loads may name a class of scripts/race3d or ModelDB (tests/unit/audio_modern/check_arcade_lean.gd);
## - the Leistungstest: start_benchmark() runs ModernBenchmark (scripts/race3d/benchmark.gd, loaded at run time),
##   which drives the race scene through start_attract_stage(); its result goes to the screen "benchmark".
##   Command line: --bench=<scene id,…|all> [--bench-out=<file.json>] [--bench-seconds=<s>] runs it and quits.

const RACE_SCENE := "res://scenes/race/race.tscn"
const BENCH_SCRIPT := "res://scripts/race3d/benchmark.gd"
## Scripts of the mode "Modern" whose caches go when the mode is left (_release_modern) – reached by path.
const MODEL_DB_SCRIPT := "res://scripts/core/model_db.gd"
const MATERIALS_SCRIPT := "res://scripts/race3d/modern_materials.gd"
## Music context of the Modern sound per screen (AudioManager.set_music_context); every other screen: "menu".
const MUSIC_CONTEXTS := {"title": "title", "graphics_choice": "title", "result": "result", "race_result": "result",
	"stage_screen": "race_menu", "route_choice": "race_menu", "ferry": "race_menu"}
## Save-game key (addition to the race state): result of the last stage while its result screen /
## name entry is not done yet – "Rennen fortsetzen" shows that screen again (docs/ui.md).
const PENDING_RESULT_KEY := "pending_result"
const SCREENS := {
	"title": "res://scripts/ui/screens/title_screen.gd",
	"race_select": "res://scripts/ui/screens/race_select_screen.gd",
	"vehicle": "res://scripts/ui/screens/vehicle_screen.gd",
	"start_time": "res://scripts/ui/screens/start_time_screen.gd",
	"route_choice": "res://scripts/ui/screens/route_choice_screen.gd",
	"stage_screen": "res://scripts/ui/screens/stage_screen.gd",
	"result": "res://scripts/ui/screens/result_screen.gd",
	"race_result": "res://scripts/ui/screens/race_result_screen.gd",
	"stage_select": "res://scripts/ui/screens/stage_select_screen.gd",
	"leaderboards": "res://scripts/ui/screens/leaderboards_screen.gd",
	"options": "res://scripts/ui/screens/options_screen.gd",
	"ferry": "res://scripts/ui/screens/ferry_screen.gd",
	"graphics_choice": "res://scripts/ui/screens/graphics_choice_screen.gd",
	"benchmark": "res://scripts/ui/screens/benchmark_screen.gd",
}

var current: Node = null
var shell: MenuShell = null
var race: RaceState = null          ## running race (mode "race")
var mode := ""                      ## "race" | "single" | "" (debug start)
var draft: Dictionary = {}          ## race being configured: {race_id, vehicle}
var single: Dictionary = {}         ## single stage: {stage_id, from_city, hour, weather, vehicle}
var pending_leg: Dictionary = {}    ## next leg {kind, id, from, to, length_km}
var pending_weather := "normal"
var last_setup: Dictionary = {}
var last_result: Dictionary = {}
var sample_mode := false
var attract: AttractMode = null     ## attract mode: demo after a minute without input on the title (docs/ui.md)
var title_choice := -1              ## title entry chosen last (focused again on the way back, -1 = default)
var _history: Array[Dictionary] = []
var _screen_name := ""
var _screen_params: Dictionary = {}
var _focus_sound_after := 0
var _result_pending := false        ## the save holds PENDING_RESULT_KEY
var _loading := false               ## start_pending_stage(): "Etappe wird geladen …" is showing
var benchmark: Node = null          ## running Leistungstest (ModernBenchmark), null otherwise
var _bench_layer: CanvasLayer       ## its overlay (BenchOverlay) above the race picture
var _sound_pending := false         ## the sound profile changed while a stage ran: applied with the menus / next stage
var _release_pending := false       ## the mode "Modern" was left while a stage ran: its caches go with the menus
var _music_context := ""            ## music context set last ("" = none since the last set_music())


func _ready() -> void:
	apply_default_leaderboard_filter()
	attract = AttractMode.new()
	attract.name = "AttractMode"
	add_child(attract)
	# v0.8.0: the stored sound profile ("Klang", or as the chosen graphics) from the first frame on; later changes
	# of the options and the chooser arrive through the signals
	Settings.sound_profile_changed.connect(_on_sound_profile_changed)
	Settings.graphics_changed.connect(_on_graphics_changed)
	AudioManager.set_race_music(bool(Settings.race_music))
	AudioManager.set_profile(Settings.sound())


## A window without focus (Alt+Tab, the Steam overlay where it takes the focus) draws at FrameCap.IDLE_FPS.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		FrameCap.hold("focus", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		FrameCap.hold("focus", false)


## Central config leaderboard.default_filter: applies while the player has not picked a filter in the
## leaderboard browser yet (no "leaderboard_filter" in the settings file) and replaces a stored filter
## that is no longer valid (e.g. a removed vehicle type). Returns the active filter.
func apply_default_leaderboard_filter() -> String:
	var stored: Variant = null
	if FileAccess.file_exists(Settings.PATH):
		var d: Variant = ConfigLoader.load_json(Settings.PATH)
		if d is Dictionary and (d as Dictionary).has("leaderboard_filter"):
			stored = Settings.leaderboard_filter   # chosen (and loaded) by the player
	Settings.leaderboard_filter = UiData.effective_filter(Config.data, stored)
	return str(Settings.leaderboard_filter)


## Called by the main scene. CLI "--stage=..." starts that stage directly (debug).
func boot() -> void:
	var vp := get_viewport()
	if not vp.gui_focus_changed.is_connected(_on_focus_changed):
		vp.gui_focus_changed.connect(_on_focus_changed)
	if CliArgs.has("stage"):
		var race_script: GDScript = load("res://scripts/race/race_session.gd")
		start_stage(race_script.setup_from_cli())
		return
	if CliArgs.has("screenshot"):
		var shot := Screenshotter.new()
		get_tree().root.add_child.call_deferred(shot)
		var times := CliArgs.get_float_list("shot-times")
		if times.is_empty():
			times = [1.5]
		shot.configure(CliArgs.get_string("screenshot"), times)
	if CliArgs.has("bench"):
		# the Leistungstest from the command line: runs its scenes, writes the result file(s) and quits
		start_benchmark(bench_scene_ids(CliArgs.get_string("bench", "all")), {"quit": true})
		return
	if CliArgs.has("screen"):
		_debug_screen(CliArgs.get_string("screen", "title"))
		return
	if Settings.needs_graphics_choice() and not CliArgs.has("no-chooser"):
		# first start of v0.8.0 (new and existing players): "GRAFIK WÄHLEN" once, then the title
		go("graphics_choice", {}, true)
		return
	show_title()


## Loads the race scene with the given setup (see race_session.gd) and switches to it.
func start_stage(setup: Dictionary) -> void:
	last_setup = setup
	_apply_pending_modes(true)   # a sound profile changed during the last stage: now, between two stages
	AudioManager.set_music(false)
	AudioManager.stop_all()
	_music_context = ""
	_set_music_context("race", {"stage_id": str(setup.get("stage_id", "")), "race_id": str(setup.get("race_id", "")),
		"mode": str(setup.get("mode", "")), "weather": str(setup.get("weather", "normal")),
		"last_stage": bool(setup.get("last_stage", false))})
	var scene: Node = (load(RACE_SCENE) as PackedScene).instantiate()
	scene.set("setup", setup)
	scene.connect("stage_finished", _on_stage_finished)
	scene.connect("stage_aborted", _on_stage_aborted)
	scene.connect("restart_requested", func() -> void: start_stage(setup))
	shell = null
	_screen_name = ""
	_set_menu_stretch(false)
	_switch_to(scene)


## Attract mode (AttractMode) and Leistungstest (ModernBenchmark): the race scene of a demo. Unlike start_stage()
## the music is left alone (the title music keeps playing in a demo) and the scene's signals do not reach the race
## flow – the caller handles them; nothing is saved. The graphics mode is the session's own choice: the effective
## mode (Settings.effective_graphics()) unless the caller's setup names one (the Leistungstest: "modern").
func start_attract_stage(setup: Dictionary) -> Node:
	var scene: Node = (load(RACE_SCENE) as PackedScene).instantiate()
	scene.set("setup", setup)
	shell = null
	_screen_name = ""
	_set_menu_stretch(false)
	_switch_to(scene)
	return scene


func _switch_to(node: Node) -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	get_tree().root.add_child(node)
	current = node


# --- screen navigation ---------------------------------------------------------------------

func go(screen_name: String, p: Dictionary = {}, reset_history: bool = false) -> void:
	if reset_history:
		_history.clear()
	elif _screen_name != "":
		_history.append({"name": _screen_name, "params": _screen_params})
	_show(screen_name, p)


func back() -> void:
	if _history.is_empty():
		show_title()
		return
	var h: Dictionary = _history.pop_back()
	_show(str(h["name"]), h["params"])


func show_title() -> void:
	go("title", {}, true)


func current_screen_name() -> String:
	return _screen_name


func _show(screen_name: String, p: Dictionary) -> void:
	_ensure_shell()
	_set_music_context(str(MUSIC_CONTEXTS.get(screen_name, "menu")))
	var script: GDScript = load(SCREENS.get(screen_name, SCREENS["title"]))
	var s: Control = script.new(p)
	_screen_name = screen_name
	_screen_params = p
	_focus_sound_after = Time.get_ticks_msec() + 250
	shell.set_screen(s)


func _ensure_shell() -> void:
	if shell != null and is_instance_valid(shell) and current == shell:
		return
	get_tree().paused = false
	_set_menu_stretch(true)
	shell = MenuShell.new()
	_switch_to(shell)
	_apply_pending_modes()   # back from a stage: a sound profile or graphics mode changed meanwhile applies now
	AudioManager.set_music(true)
	_music_context = ""      # set_music() chose the context: the screen's own follows (_show)


# --- graphics mode and sound profile (v0.8.0) ------------------------------------------------------------

## True while a race scene is the current scene (a stage, an attract demo, a scene of the Leistungstest).
func stage_running() -> bool:
	return current != null and is_instance_valid(current) and current != shell


## Music context of the Modern sound (AudioManager.set_music_context – the Arcade profile only remembers it). A
## context already in force is not sent again, except "race": every start of a stage is a new piece.
func _set_music_context(ctx: String, args: Dictionary = {}) -> void:
	if ctx == _music_context and ctx != "race":
		return
	_music_context = ctx
	AudioManager.set_music_context(ctx, args)


## The resolved sound profile changed (options "Klang", or "Grafik" while "Klang" is "Wie Grafik", the chooser).
func _on_sound_profile_changed(_profile: String) -> void:
	_sound_pending = true
	_apply_pending_modes()


## The chosen graphics mode changed: when the game is no longer Modern, what Modern loaded goes – after the
## widgets that show Modern content (the showroom) have reacted to the same signal.
func _on_graphics_changed(_mode: String) -> void:
	_release_pending = true
	_apply_pending_modes.call_deferred()


## Applies a changed sound profile and frees the caches of a left mode "Modern" – never while a stage runs
## (AudioManager.set_profile ends every running sound; the renderer of the stage uses the caches): then they wait
## for the menus or for the start of the next stage (between_stages: start_stage() replaces the scene right now).
func _apply_pending_modes(between_stages: bool = false) -> void:
	if stage_running() and not between_stages:
		return
	if _sound_pending:
		_sound_pending = false
		AudioManager.set_profile(Settings.sound())
	if _release_pending:
		_release_pending = false
		_release_modern()


## Leaving the mode "Modern": the model caches and the shared materials (they hold the textures) go. The scripts
## are reached by path and only when something has loaded them – a game that never showed Modern loads nothing here.
func _release_modern() -> void:
	if Settings.is_modern():
		return
	if ResourceLoader.has_cached(MODEL_DB_SCRIPT):
		(load(MODEL_DB_SCRIPT) as GDScript).call("release_all")
	if ResourceLoader.has_cached(MATERIALS_SCRIPT):
		(load(MATERIALS_SCRIPT) as GDScript).call("drop_shared")


# --- Leistungstest ---------------------------------------------------------------------------------------

## Scene ids for --bench=<id,id,…|all>: [] = every scene of graphics.benchmark.scenes.
static func bench_scene_ids(arg: String) -> Array:
	var out: Array = []
	if arg == "" or arg == "all":
		return out
	for id in arg.split(",", false):
		out.append(id.strip_edges())
	return out


## Starts the Leistungstest: ModernBenchmark (scripts/race3d/benchmark.gd, loaded here at run time) drives the
## scenes of graphics.benchmark.scenes – [] = all – in the mode "Modern" through start_attract_stage(); nothing is
## saved but the result file. opts: "quit" (command line: print the result and quit instead of showing the result
## screen), "seconds" (per scene, tests), "out" (a second result file). Returns false if a test is already running.
func start_benchmark(scene_ids: Array = [], opts: Dictionary = {}) -> bool:
	if benchmark != null and is_instance_valid(benchmark):
		return false
	var script: GDScript = load(BENCH_SCRIPT) as GDScript if ResourceLoader.exists(BENCH_SCRIPT) else null
	if script == null:
		_on_benchmark_finished({"version": 1, "scenes": [], "error": "missing"}, bool(opts.get("quit", false)))
		return true
	get_viewport().gui_release_focus()
	benchmark = script.new()
	benchmark.name = "Leistungstest"
	benchmark.set("host", self)
	if opts.has("seconds"):
		benchmark.set("seconds_override", float(opts["seconds"]))
	if opts.has("out"):
		benchmark.set("out_path", str(opts["out"]))
	add_child(benchmark)
	benchmark.connect("finished", _on_benchmark_finished.bind(bool(opts.get("quit", false))))
	# what is going on, over the race picture: which scene, how far, how to end it
	_bench_layer = CanvasLayer.new()
	_bench_layer.layer = BenchOverlay.LAYER
	_bench_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bench_layer)
	var overlay := BenchOverlay.new()
	overlay.runner = benchmark
	_bench_layer.add_child(overlay)
	benchmark.connect("progress", func(_id: String, p: float) -> void:
		if is_instance_valid(overlay):
			overlay.progress = p)
	benchmark.call("start", scene_ids)
	return true


func _on_benchmark_finished(result: Dictionary, quit_after: bool) -> void:
	if benchmark != null and is_instance_valid(benchmark):
		benchmark.queue_free()
	benchmark = null
	if _bench_layer != null and is_instance_valid(_bench_layer):
		_bench_layer.queue_free()
	_bench_layer = null
	AudioManager.stop_all()
	if quit_after:
		print("LEISTUNGSTEST ", JSON.stringify(result))
		var ok := not (result.get("scenes", []) as Array).is_empty() and str(result.get("error", "")) == ""
		get_tree().quit(0 if ok else 1)
		return
	if _screen_name == "benchmark":
		_show("benchmark", {"result": result})   # it failed before a scene started: the result replaces the start page
	else:
		go("benchmark", {"result": result})


## Stretch aspect of the window: the menus use "expand" (the screens stay 1280×720 in the middle, the
## background fills a 16:10 screen like the Steam Deck's), the race keeps 16:9 with black bars ("keep",
## project setting) because the road picture is laid out for 1280×720.
func _set_menu_stretch(menus: bool) -> void:
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if menus else Window.CONTENT_SCALE_ASPECT_KEEP


func _on_focus_changed(_c: Control) -> void:
	if Time.get_ticks_msec() > _focus_sound_after and current == shell:
		AudioManager.play("ui_move")


func quit_game() -> void:
	get_tree().quit()


# --- race flow -----------------------------------------------------------------------------

func new_race() -> void:
	draft = {}
	mode = "race"
	go("race_select")


func select_race(race_id: String) -> void:
	draft = {"race_id": race_id}
	mode = "race"
	go("vehicle", {"mode": "race"})


func select_vehicle(vehicle_id: String) -> void:
	if mode == "single":
		single["vehicle"] = vehicle_id
		var other := UiData.stage_other_end(str(single.get("stage_id", "")), str(single.get("from_city", "")))
		var plan := UiData.stage_plan(str(single.get("stage_id", "")), str(single.get("from_city", "")))
		pending_leg = {"kind": "stage", "id": single.get("stage_id", ""), "from": single.get("from_city", ""), "to": other,
			"length_km": plan.length_km if plan != null else 0.0}
		pending_weather = str(single.get("weather", "normal"))
		go("stage_screen")
	else:
		draft["vehicle"] = vehicle_id
		go("start_time")


func select_start_time(hour: float) -> void:
	var r := UiData.race(str(draft.get("race_id", "")))
	# --race-seed=<n> (tests/race/run_race.gd): reproducible race weather and traffic
	var race_seed := int(CliArgs.get_float("race-seed", -1.0)) if CliArgs.has("race-seed") else randi() % 1000000
	race = RaceState.create(r, str(draft.get("vehicle", "limousine")), hour, race_seed)
	mode = "race"
	_save_race()
	_race_next(true)


func continue_race() -> void:
	var d := UiData.load_race()
	if d.is_empty():
		show_title()
		return
	var pending := restore_race(d)
	mode = "race"
	if not pending.is_empty():
		# the game was closed on a stage result (e.g. at the name prompt): show it again
		_result_pending = true
		last_result = pending
		pending_leg = race.last_leg()
		go("result", {"result": pending}, true)
		return
	_race_next(true)


## Sets `race` from a saved race (SaveGame) and returns its pending stage result ({} if none). Times saved with another
## time-lapse factor (v0.6.0: 12, no "time_scale") are converted to time.time_scale once – the race and the pending
## result alike (RaceState.from_dict / rescaled_result: same averages; the next start keeps the world time already
## shown) – and the converted state is saved.
func restore_race(d: Dictionary) -> Dictionary:
	var ts := float(ConfigLoader.lookup(Config.data, "time.time_scale", 10.0))
	var saved_ts := RaceState.saved_time_scale(d)
	race = RaceState.from_dict(d, UiData.race(str(d.get("race_id", ""))), ts)
	var pending: Dictionary = {}
	var p: Variant = d.get(PENDING_RESULT_KEY, null)
	if p is Dictionary:
		pending = p
	if saved_ts > 0.0 and ts > 0.0 and not is_equal_approx(saved_ts, ts):
		if not pending.is_empty():
			pending = RaceState.rescaled_result(pending, saved_ts / ts)
		_save_race(pending)
	return pending


## Saves the running race (SaveGame). `pending_result` = a stage result whose screen is not done yet.
func _save_race(pending_result: Dictionary = {}) -> void:
	if race == null:
		return
	var d := race.to_dict()
	if not pending_result.is_empty():
		d[PENDING_RESULT_KEY] = pending_result.duplicate(true)
	_result_pending = not pending_result.is_empty()
	UiData.save_race(d)


## The stage result screen is done (name entered, or "Weiter"): the save drops the pending result.
func stage_result_done() -> void:
	if _result_pending and mode == "race" and race != null:
		_save_race()


## Next step of the running race: race result, route choice or the single next leg.
func _race_next(reset_history: bool = true) -> void:
	if race == null:
		show_title()
		return
	if race.is_finished():
		go("race_result", {}, true)
		return
	var opts := UiData.next_options(race.race_id, race.current_city, race.waypoint_index, race.visited())
	if opts.size() == 1:
		choose_leg(opts[0], reset_history)
	else:
		go("route_choice", {"options": opts}, reset_history)


## Chosen leg: ferry scene or stage screen (weather decided deterministically from the race seed).
func choose_leg(leg: Dictionary, reset_history: bool = false) -> void:
	pending_leg = leg
	if str(leg.get("kind", "stage")) == "ferry":
		go("ferry", {"leg": leg, "ferry": UiData.ferries().get(str(leg.get("id", "")), {})}, reset_history)
		return
	var plan := UiData.stage_plan(str(leg.get("id", "")), str(leg.get("from", "")))
	pending_weather = "normal"
	if plan != null and race != null:
		# tutorial stage: dry (weather.tutorial_weather), every other stage the race weather
		pending_weather = RaceState.leg_weather(Config.data, plan, race.stage_seed(str(leg["id"])))
	go("stage_screen", {}, reset_history)


func ferry_done() -> void:
	if race != null and str(pending_leg.get("kind", "")) == "ferry":
		race.apply_ferry(UiData.ferries().get(str(pending_leg.get("id", "")), {}), pending_leg)
		_save_race()
	_race_next(true)


## Setup dictionary for the race session (ARCHITECTURE.md §8). In a race the tank of the last stage goes into this
## one (start_fuel_l = RaceState.fuel_l, -1 = the stage's own filling: the race's first stage); a single stage starts
## with the stage's own filling. A restart or an abort of the stage reuses the same setup, so the same fuel.
## last_stage: this stage ends the race – its tank goes into no further stage.
func stage_setup() -> Dictionary:
	var s := {}
	if mode == "race" and race != null:
		s = {"mode": "race", "race_id": race.race_id, "stage_id": str(pending_leg.get("id", "")),
			"from_city": str(pending_leg.get("from", "")), "vehicle": race.vehicle,
			"start_world_minutes": race.world_minutes, "weather": pending_weather,
			"seed": race.stage_seed(str(pending_leg.get("id", ""))) % 100000, "start_fuel_l": race.fuel_l,
			"last_stage": race.finishes_race(pending_leg)}
	else:
		s = {"mode": "single", "race_id": "", "stage_id": str(single.get("stage_id", "")),
			"from_city": str(single.get("from_city", "")), "vehicle": str(single.get("vehicle", "limousine")),
			"start_world_minutes": float(single.get("hour", 8.0)) * 60.0, "weather": str(single.get("weather", "normal")),
			"seed": randi() % 100000}
	# debug/test hooks (command line only): drive the stages with the autopilot
	if CliArgs.has("autopilot"):
		s["autopilot"] = true
		s["autopilot_speeding"] = CliArgs.has("autopilot-speeding")
		s["autopilot_refuel"] = CliArgs.get_string("autopilot-refuel", "auto")
	if CliArgs.has("no-countdown"):
		s["no_countdown"] = true
	return s


## "Start" on the stage screen: shows "Etappe wird geladen …" over the screen for two frames (it is drawn), then
## builds the race scene – loading a stage takes 0.3–0.8 s here (more on a Steam Deck) and froze the menu without
## any feedback (QA v0.5.1). A second press while it loads does nothing.
func start_pending_stage() -> void:
	if sample_mode:
		AudioManager.play("go")
		return
	if _loading:
		return
	_loading = true
	var setup := stage_setup()
	var screen: Variant = shell.current_screen if shell != null and is_instance_valid(shell) else null
	if screen is Control and (screen as Control).is_inside_tree():
		var overlay := LoadingOverlay.new()
		(screen as Control).add_child(overlay)
		get_viewport().gui_release_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_instance_valid(screen) or shell == null or shell.current_screen != screen:
			_loading = false   # the screen went away in the meantime (nothing to start from)
			return
	_loading = false
	start_stage(setup)


func _on_stage_finished(result: Dictionary) -> void:
	last_result = result
	AudioManager.stop_all()
	if mode == "race" and race != null and not bool(result.get("aborted", false)):
		race.apply_stage_result(pending_leg, result, Config.data)
		# saved with the result: closing the game on the result screen / name prompt loses nothing
		_save_race(result)
	go("result", {"result": result}, true)


func _on_stage_aborted(_reason: String) -> void:
	AudioManager.stop_all()
	if mode == "race" and race != null and not pending_leg.is_empty():
		choose_leg(pending_leg, true)
	elif mode == "single":
		go("stage_select", {}, true)
	else:
		show_title()


## "Weiter" on the stage result screen.
func result_continue() -> void:
	if mode == "race" and race != null:
		stage_result_done()
		_race_next(true)
	elif mode == "single":
		go("stage_select", {}, true)
	else:
		show_title()


## Race completed and its leaderboard entry (if any) stored: the save game is no longer needed.
## Called by the race result screen – right away without a placement, after the name entry otherwise.
func finish_race() -> void:
	_result_pending = false
	UiData.clear_race()


func leave_race_to_title() -> void:
	race = null
	mode = ""
	show_title()


# --- single stage --------------------------------------------------------------------------

func single_stage() -> void:
	mode = "single"
	go("stage_select")


func configure_single(stage_id: String, from_city: String, hour: float, weather: String) -> void:
	mode = "single"
	var veh := str(single.get("vehicle", ConfigLoader.lookup(Config.data, "vehicles.default", "limousine")))
	single = {"stage_id": stage_id, "from_city": from_city, "hour": hour, "weather": weather, "vehicle": veh}
	go("vehicle", {"mode": "single"})


func remember_player_name(player_name: String) -> void:
	Settings.player_name = player_name
	if not sample_mode:
		Settings.save_settings()


# --- debug screens with sample data --------------------------------------------------------

func _debug_screen(screen_name: String) -> void:
	sample_mode = true
	UiData.sample = true
	if SampleData.real_network_sparse(UiData.cities()):
		UiData.enable_sample(SampleData.network())
	var c := Config.data
	var ids := UiData.visible_race_ids()
	# --race=<id> picks the race, --stages-done=<n> how far the sample race has got (debug screenshots)
	var rid := CliArgs.get_string("race", ids[0] if not ids.is_empty() else "")
	var done := int(CliArgs.get_float("stages-done", -1.0))
	match screen_name:
		"race_select":
			draft = {"race_id": rid} if CliArgs.has("race") else {}   # the race in focus
			go("race_select", {}, true)
		"vehicle":
			mode = "race"
			draft = {"race_id": rid}
			if CliArgs.has("sample-vehicle"):
				draft["vehicle"] = CliArgs.get_string("sample-vehicle", "limousine")   # the car in focus (showroom pictures)
			go("vehicle", {"mode": "race"}, true)
		"start_time":
			mode = "race"
			draft = {"race_id": rid, "vehicle": "sportwagen"}
			go("start_time", {}, true)
		"route_choice", "stage_screen":
			mode = "race"
			race = SampleData.race_state(rid, done if done >= 0 else 1, c)
			if CliArgs.has("sample-fuel"):
				race.fuel_l = CliArgs.get_float("sample-fuel", -1.0)   # the tank carried into the stage (v0.7.0)
			var opts := UiData.next_options(race.race_id, race.current_city, race.waypoint_index, race.visited())
			if screen_name == "route_choice" or opts.is_empty():
				go("route_choice", {"options": opts}, true)
			else:
				choose_leg(opts[0], true)
		"result":
			mode = "race"
			race = SampleData.race_state(rid, done if done >= 1 else 2, c)
			var last := race.last_leg()
			pending_leg = last
			var res := SampleData.stage_result(str(last.get("id", "")), str(last.get("from", "")), c)
			go("result", {"result": res}, true)
		"race_result":
			mode = "race"
			race = SampleData.race_state(rid, done if done >= 1 else 999, c)
			go("race_result", {}, true)
		"ferry":
			mode = "race"
			race = SampleData.race_state(rid, 1, c)
			var fid := ""
			for f in UiData.ferries():
				fid = str(f)
				break
			var fd: Dictionary = UiData.ferries().get(fid, {})
			pending_leg = {"kind": "ferry", "id": fid, "from": str(fd.get("from", "")), "to": str(fd.get("to", ""))}
			go("ferry", {"leg": pending_leg, "ferry": fd}, true)
		_:
			if SCREENS.has(screen_name):
				go(screen_name, {}, true)
			else:
				show_title()
