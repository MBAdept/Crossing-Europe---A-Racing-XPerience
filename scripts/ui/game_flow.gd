extends Node
## Autoload "GameFlow": screen flow – title, race/stage selection, vehicle, start time, route choice,
## stage screen (map, weather, record marquee, top 10), race, results/name entry, leaderboards,
## options, ferry scene, save/continue. Owner: UI module. Public API = contract (ARCHITECTURE.md §10):
## boot(), start_stage(setup). Navigation helpers below are additions (docs/ui.md).
##
## Race progression lives in RaceState (pure, unit tested); data access goes through UiData.
## Debug: --screen=<title|race_select|vehicle|start_time|stage_select|route_choice|stage_screen|
## result|race_result|leaderboards|options|ferry> shows a screen with sample data (screenshots).

const RACE_SCENE := "res://scenes/race/race.tscn"
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
var _history: Array[Dictionary] = []
var _screen_name := ""
var _screen_params: Dictionary = {}
var _focus_sound_after := 0


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
	if CliArgs.has("screen"):
		_debug_screen(CliArgs.get_string("screen", "title"))
		return
	show_title()


## Loads the race scene with the given setup (see race_session.gd) and switches to it.
func start_stage(setup: Dictionary) -> void:
	last_setup = setup
	AudioManager.set_music(false)
	AudioManager.stop_all()
	var scene: Node = (load(RACE_SCENE) as PackedScene).instantiate()
	scene.set("setup", setup)
	scene.connect("stage_finished", _on_stage_finished)
	scene.connect("stage_aborted", _on_stage_aborted)
	scene.connect("restart_requested", func() -> void: start_stage(setup))
	shell = null
	_screen_name = ""
	_switch_to(scene)


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
	shell = MenuShell.new()
	_switch_to(shell)
	AudioManager.set_music(true)


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
	race = RaceState.create(r, str(draft.get("vehicle", "limousine")), hour, randi() % 1000000)
	mode = "race"
	UiData.save_race(race.to_dict())
	_race_next(true)


func continue_race() -> void:
	var d := UiData.load_race()
	if d.is_empty():
		show_title()
		return
	race = RaceState.from_dict(d, UiData.race(str(d.get("race_id", ""))))
	mode = "race"
	_race_next(true)


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
		pending_weather = RaceState.choose_weather(Config.data, plan.climate, plan.weather_hint, race.stage_seed(str(leg["id"])))
	go("stage_screen", {}, reset_history)


func ferry_done() -> void:
	if race != null and str(pending_leg.get("kind", "")) == "ferry":
		race.apply_ferry(UiData.ferries().get(str(pending_leg.get("id", "")), {}), pending_leg)
		UiData.save_race(race.to_dict())
	_race_next(true)


## Setup dictionary for the race session (ARCHITECTURE.md §8).
func stage_setup() -> Dictionary:
	var s := {}
	if mode == "race" and race != null:
		s = {"mode": "race", "race_id": race.race_id, "stage_id": str(pending_leg.get("id", "")),
			"from_city": str(pending_leg.get("from", "")), "vehicle": race.vehicle,
			"start_world_minutes": race.world_minutes, "weather": pending_weather,
			"seed": race.stage_seed(str(pending_leg.get("id", ""))) % 100000}
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


func start_pending_stage() -> void:
	if sample_mode:
		AudioManager.play("go")
		return
	start_stage(stage_setup())


func _on_stage_finished(result: Dictionary) -> void:
	last_result = result
	AudioManager.stop_all()
	if mode == "race" and race != null and not bool(result.get("aborted", false)):
		race.apply_stage_result(pending_leg, result, Config.data)
		UiData.save_race(race.to_dict())
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
		_race_next(true)
	elif mode == "single":
		go("stage_select", {}, true)
	else:
		show_title()


## Race completed and shown: the save game is no longer needed.
func finish_race() -> void:
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
	var rid := ids[0] if not ids.is_empty() else ""
	match screen_name:
		"vehicle":
			mode = "race"
			draft = {"race_id": rid}
			go("vehicle", {"mode": "race"}, true)
		"start_time":
			mode = "race"
			draft = {"race_id": rid, "vehicle": "sportwagen"}
			go("start_time", {}, true)
		"route_choice", "stage_screen":
			mode = "race"
			race = SampleData.race_state(rid, 1, c)
			var opts := UiData.next_options(race.race_id, race.current_city, race.waypoint_index, race.visited())
			if screen_name == "route_choice" or opts.is_empty():
				go("route_choice", {"options": opts}, true)
			else:
				choose_leg(opts[0], true)
		"result":
			mode = "race"
			race = SampleData.race_state(rid, 2, c)
			var last := race.last_leg()
			pending_leg = last
			var res := SampleData.stage_result(str(last.get("id", "")), str(last.get("from", "")), c)
			go("result", {"result": res}, true)
		"race_result":
			mode = "race"
			race = SampleData.race_state(rid, 99, c)
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
