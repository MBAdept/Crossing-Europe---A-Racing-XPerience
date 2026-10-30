extends TestCase
## Menu input (INPUT-1, FLOW-1, SAVE-2): gamepad A/B trigger ui_accept/ui_cancel, the name entry works
## with the gamepad alone (A on a key types, B deletes, A in the field or on OK submits, explicit
## D-pad neighbours), the single-stage screen's focus chain reaches "Weiter" with ▼ without passing
## through the stage list, and a stage result stays in the save game until its name entry is done.
## The test runner runs before the root viewport enters the tree, so these tests check the wiring and
## the handlers directly; the live input path is exercised by the menu flow driver (docs/ui.md).
## Screen and save tests use the runner's autoloads (GameData, GameFlow, SaveGame) and return early
## without them.

const PENDING := "pending_result"   ## GameFlow.PENDING_RESULT_KEY (save-game key, docs/ui.md)


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


## The InputMap as InputSetup registers it (independent of whether the autoload ran).
func _ensure_input_map() -> void:
	var setup: Node = load("res://scripts/core/input_setup.gd").new()
	setup.free()


## Control behind a focus neighbour path ("" side = none set).
func _nb(c: Control, side: Side) -> Control:
	var p: NodePath
	match side:
		SIDE_LEFT:
			p = c.focus_neighbor_left
		SIDE_RIGHT:
			p = c.focus_neighbor_right
		SIDE_TOP:
			p = c.focus_neighbor_top
		_:
			p = c.focus_neighbor_bottom
	return c.get_node_or_null(p) as Control if not p.is_empty() else null


func _key(ne: NameEntry, label: String) -> Button:
	for b in ne.grid.get_children():
		if (b as Button).text == label:
			return b
	return null


func test_gamepad_a_b_are_menu_actions() -> void:
	_ensure_input_map()
	var a := _pad(JOY_BUTTON_A)
	var b := _pad(JOY_BUTTON_B)
	assert_true(a.is_action_pressed("ui_accept"), "Gamepad A = ui_accept")
	assert_true(b.is_action_pressed("ui_cancel"), "Gamepad B = ui_cancel")
	assert_true(a.is_action_pressed("accelerate"), "Gamepad A gibt im Rennen weiter Gas")
	assert_false(_pad(JOY_BUTTON_START).is_action_pressed("ui_accept"), "Start ist kein ui_accept (Pausenmenü)")
	assert_false(b.is_action_pressed("ui_accept"), "B bestätigt nicht")
	assert_true(_pad(JOY_BUTTON_DPAD_DOWN).is_action_pressed("ui_down"), "Steuerkreuz navigiert")


func test_name_entry_gamepad_handlers() -> void:
	_ensure_input_map()
	var ne := NameEntry.new("")
	var got: Array[String] = []
	ne.submitted.connect(func(n: String) -> void: got.append(n))
	# A on a key presses the button (ui_accept) -> types
	_key(ne, "E").pressed.emit()
	_key(ne, "F").pressed.emit()
	assert_eq(ne.line.text, "Ef", "Tasten tippen, zweiter Buchstabe klein")
	# B with the focus inside the entry deletes; B elsewhere or A does nothing
	assert_true(ne.handle_gamepad_cancel(_pad(JOY_BUTTON_B), _key(ne, "F")), "B auf einer Taste behandelt")
	assert_eq(ne.line.text, "E", "B löscht das letzte Zeichen")
	var outside := Button.new()
	assert_false(ne.handle_gamepad_cancel(_pad(JOY_BUTTON_B), outside), "B außerhalb: nicht behandelt")
	assert_false(ne.handle_gamepad_cancel(_pad(JOY_BUTTON_A), ne.line), "A ist kein Löschen")
	outside.free()
	# A in the text field submits once
	ne._on_line_input(_pad(JOY_BUTTON_A))
	ne._on_line_input(_pad(JOY_BUTTON_A))
	assert_eq(got, ["E"] as Array[String], "A im Feld trägt genau einmal ein")
	ne.free()


func test_name_entry_dpad_neighbours() -> void:
	var ne := NameEntry.new("")
	var keys := ne.grid.get_children()
	assert_eq(_nb(ne.line, SIDE_BOTTOM), _key(ne, "E"), "▼ aus dem Feld auf die Tastatur")
	assert_eq(_nb(_key(ne, "A"), SIDE_LEFT), _key(ne, "J"), "Zeile läuft links herum")
	assert_eq(_nb(_key(ne, "J"), SIDE_RIGHT), _key(ne, "A"), "Zeile läuft rechts herum")
	assert_eq(_nb(_key(ne, "C"), SIDE_TOP), ne.line, "▲ aus der ersten Reihe ins Feld")
	assert_eq(_nb(_key(ne, "C"), SIDE_BOTTOM), _key(ne, "M"), "▼ eine Reihe tiefer")
	var bottom := ne.ok_button.get_parent().get_children()
	assert_eq(_nb(_key(ne, "0"), SIDE_BOTTOM), ne.ok_button, "▼ aus der letzten Reihe auf die Knopfreihe")
	assert_eq(_nb(_key(ne, "1"), SIDE_BOTTOM), bottom[0], "▼ links -> Leerzeichen")
	assert_eq(_nb(ne.ok_button, SIDE_RIGHT), bottom[0], "▶ von OK läuft herum (nicht ins Textfeld)")
	assert_eq(_nb(bottom[0], SIDE_LEFT), ne.ok_button, "◀ von Leerzeichen auf OK")
	assert_true(_nb(ne.ok_button, SIDE_TOP) in keys, "▲ von OK auf die Tastatur")
	assert_eq(_nb(ne.ok_button, SIDE_BOTTOM), ne.ok_button, "▼ von OK bleibt")
	ne.free()


func test_stage_select_focus_chain() -> void:
	var root := _root()
	if root.get_node_or_null("GameFlow") == null or root.get_node_or_null("GameData") == null:
		return
	var s := StageSelectScreen.new()
	s.build()
	var sel := s.selected_button()
	if sel == null:
		s.free()
		return
	var dir: Control = s.get("_dir")
	var time: Control = s.get("_time")
	var weather: Control = s.get("_weather")
	var ok: Control = s.get("_ok")
	var stage := str(s.get("_stage"))
	assert_eq(_nb(sel, SIDE_RIGHT), dir, "▶ aus der Liste auf Richtung")
	assert_eq(_nb(dir, SIDE_BOTTOM), time, "Richtung ▼ Startzeit")
	assert_eq(_nb(time, SIDE_BOTTOM), weather, "Startzeit ▼ Wetter")
	assert_eq(_nb(weather, SIDE_BOTTOM), ok, "Wetter ▼ Weiter (nicht in die Liste)")
	assert_eq(_nb(ok, SIDE_TOP), weather, "Weiter ▲ Wetter")
	assert_eq(_nb(ok, SIDE_BOTTOM), dir, "Spalte läuft herum")
	assert_eq(_nb(dir, SIDE_TOP), ok, "Richtung ▲ Weiter")
	assert_eq(_nb(ok, SIDE_LEFT), sel, "◀ von Weiter auf den gewählten Eintrag")
	# no neighbour of the option column leads into another list entry
	for c: Control in [dir, time, weather, ok]:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_BOTTOM]:
			var n := _nb(c, side)
			assert_true(n != null, "Nachbar gesetzt (%s)" % c.name)
			assert_true(n == sel or n in [dir, time, weather, ok], "kein Sprung auf eine andere Etappe")
	# selecting another entry moves the ◀ target along, the stage only changes by the list
	var other: Button = _nb(sel, SIDE_BOTTOM) as Button
	assert_true(other != null and other != sel, "Liste hat einen Nachfolger")
	assert_eq(str(s.get("_stage")), stage, "Etappe unverändert ohne Listenfokus")
	s.free()


func test_pending_stage_result_stays_in_save_until_done() -> void:
	var root := _root()
	var gf := root.get_node_or_null("GameFlow")
	var sg := root.get_node_or_null("SaveGame")
	if gf == null or sg == null:
		return
	var old_path := str(sg.get("path"))
	var old_race: Variant = gf.get("race")
	var old_mode: Variant = gf.get("mode")
	sg.set("path", "user://test_ui_pending_savegame.json")
	var race := RaceState.create({"id": "t", "name": "T", "start": "kiel", "finish": "nuernberg", "waypoints": []}, "kombi", 8.0, 3)
	var res := {"board_key": "stage:a:fwd", "stage_id": "a", "time_s": 200.0, "end_world_minutes": 500.0, "start_world_minutes": 480.0}
	race.apply_stage_result({"kind": "stage", "id": "a", "from": "kiel", "to": "hamburg", "length_km": 95.0}, res, cfg())
	gf.set("race", race)
	gf.set("mode", "race")
	gf.call("_save_race", res)
	var d: Dictionary = sg.call("load_race")
	assert_true(d.has(PENDING), "Etappenergebnis bis zur Namenseingabe im Spielstand")
	assert_near(float((d.get(PENDING, {}) as Dictionary).get("time_s", 0.0)), 200.0, 0.001, "Ergebnis gespeichert")
	gf.call("stage_result_done")
	d = sg.call("load_race")
	assert_false(d.has(PENDING), "nach der Namenseingabe entfernt")
	assert_eq(str(d.get("current_city", "")), "hamburg", "Rennstand bleibt gespeichert")
	gf.call("finish_race")
	assert_true((sg.call("load_race") as Dictionary).is_empty(), "Rennende löscht den Spielstand")
	sg.set("path", old_path)
	gf.set("race", old_race)
	gf.set("mode", old_mode)
