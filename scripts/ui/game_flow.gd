extends Node
## Autoload "GameFlow": screen flow – title, race/stage selection, vehicle, start time, route choice,
## stage screen (map, weather, record marquee, top 10), race, results/name entry, leaderboards,
## options, ferry scene, save/continue. Owner: UI module. Public API = contract (ARCHITECTURE.md §Ablauf).
## STUB: debug start + a minimal title screen – the UI module replaces it.

const RACE_SCENE := "res://scenes/race/race.tscn"

var current: Node = null


## Called by the main scene. CLI "--stage=..." starts that stage directly (debug).
func boot() -> void:
	if CliArgs.has("stage"):
		var race_script: GDScript = load("res://scripts/race/race_session.gd")
		start_stage(race_script.setup_from_cli())
		return
	_show_title_stub()


## Loads the race scene with the given setup (see race_session.gd) and switches to it.
func start_stage(setup: Dictionary) -> void:
	var scene: Node = (load(RACE_SCENE) as PackedScene).instantiate()
	scene.set("setup", setup)
	scene.connect("stage_finished", _on_stage_finished)
	scene.connect("stage_aborted", _on_stage_aborted)
	scene.connect("restart_requested", func() -> void: start_stage(setup))
	_switch_to(scene)


func _switch_to(node: Node) -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	get_tree().root.add_child(node)
	current = node


func _on_stage_finished(result: Dictionary) -> void:
	print("Etappe beendet: ", Units.format_race_time(float(result.get("time_s", 0.0))))
	_show_title_stub()


func _on_stage_aborted(_reason: String) -> void:
	_show_title_stub()


func _show_title_stub() -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.text = "Crossing Europe – A Racing Xperience\n\nEnter: Kiel – Hamburg starten"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	c.add_child(l)
	_switch_to(c)
	c.set_process_unhandled_input(true)
	c.gui_input.connect(func(_e: InputEvent) -> void: pass)
	await get_tree().process_frame
	while is_instance_valid(c) and current == c:
		if Input.is_action_just_pressed("ui_accept"):
			start_stage({"mode": "single", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
				"start_world_minutes": 8.0 * 60.0, "weather": "normal"})
			return
		await get_tree().process_frame
