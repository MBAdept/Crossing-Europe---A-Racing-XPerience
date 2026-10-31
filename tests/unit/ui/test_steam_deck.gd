extends TestCase
## Steam Deck / gamepad-only play (docs/steam-deck.md): the active input device (InputMode) switches
## with gamepad buttons, clear stick movement and key presses; with a gamepad the key hints show only
## gamepad glyphs (pad buttons, D-pad for arrow keys); the tutorial's control hints follow the device;
## the options' player name can be entered with the gamepad (on-screen keyboard); the HUD shortens
## texts that would overrun their panel.


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _axis(value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func _keypress(code: Key, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	return e


func test_input_mode_follows_the_device() -> void:
	var before := InputMode.gamepad
	InputMode.gamepad = false
	assert_false(InputMode.note(_axis(0.2)), "Stick-Rauschen schaltet nicht um")
	assert_false(InputMode.note(_pad(JOY_BUTTON_A, false)), "Loslassen schaltet nicht um")
	assert_true(InputMode.note(_pad(JOY_BUTTON_A)), "Gamepad-Taste schaltet auf Gamepad")
	assert_true(InputMode.gamepad, "Gamepad aktiv")
	assert_false(InputMode.note(_pad(JOY_BUTTON_B)), "bleibt Gamepad")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_false(InputMode.note(click), "Maus/Touch (Trackpad des Steam Deck) schaltet nicht um")
	assert_false(InputMode.note(_keypress(KEY_ENTER, true)), "gehaltene Taste (Echo) schaltet nicht um")
	assert_true(InputMode.note(_keypress(KEY_ENTER)), "Tastendruck schaltet zurück")
	assert_false(InputMode.gamepad, "Tastatur aktiv")
	assert_true(InputMode.note(_axis(-0.9)), "deutlicher Stickausschlag schaltet auf Gamepad")
	InputMode.gamepad = before


func test_key_hints_gamepad_only() -> void:
	var hints := [
		[["Enter", "pad:A"], "Auswählen"], [["Esc", "pad:B"], "Zurück"], [["ud"], "Wählen"],
		[["ud", "lr"], "Tastatur"], [["left", "right", "pad:LS"], "Lenken"], [["up", "pad:RT"], "Gas"],
		[["Esc"], "Nur Tastatur"], [["lr"], "Ändern"],
	]
	assert_eq(KeyHints.visible_hints(hints, false), hints, "Tastatur: Tasten und Gamepad nebeneinander (unverändert)")
	var pad := KeyHints.visible_hints(hints, true)
	assert_eq(pad, [
		[["pad:A"], "Auswählen"], [["pad:B"], "Zurück"], [["dpad:ud"], "Wählen"], [["dpad:udlr"], "Tastatur"],
		[["pad:LS"], "Lenken"], [["pad:RT"], "Gas"], [["dpad:lr"], "Ändern"],
	], "Gamepad: nur Gamepad-Symbole, Pfeile als Steuerkreuz, reine Tastaturhinweise entfallen")
	for h in pad:
		for k in h[0]:
			assert_true(str(k).begins_with("pad:") or str(k).begins_with("dpad:"), "kein Tastatursymbol: %s" % str(k))
	# every footer of the menus keeps at least one hint with a gamepad
	assert_eq(KeyHints.visible_hints(NameEntry.key_hints(), true).size(), 3, "Namenseingabe: A, Steuerkreuz, B")


func test_tutorial_control_hints_follow_the_device() -> void:
	var c := TutorialCoach.new()
	c.setup(cfg())
	c.gamepad = true
	var pad := c.hints_for("start")
	assert_eq(pad.size(), 1, "mit Gamepad nur der Gamepad-Hinweis")
	assert_true(pad[0].contains("Gamepad") and pad[0].contains("Trigger"), "Gamepad-Hinweis (%s)" % pad[0])
	c.gamepad = false
	var keys := c.hints_for("start")
	assert_eq(keys.size(), 3, "Tastatur: Lenken, Gas/Bremse, Gamepad")
	assert_true(keys[0].contains("Pfeiltasten"), "Tastatur zuerst (%s)" % keys[0])


func test_options_name_with_gamepad_keyboard() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	if root.get_node_or_null("GameFlow") == null or root.get_node_or_null("Settings") == null:
		return
	var settings: Node = root.get_node("Settings")
	var old_name := str(settings.get("player_name"))
	settings.set("player_name", "Anke")
	var s := OptionsScreen.new()
	s.build()
	var field: LineEdit = s.get("_name")
	assert_eq(field.text, "Anke", "Feld zeigt den gespeicherten Namen")
	s._on_name_input(_pad(JOY_BUTTON_B))
	assert_true(s.keyboard == null, "B öffnet keine Tastatur")
	s._on_name_input(_pad(JOY_BUTTON_A))
	assert_true(s.keyboard != null, "Gamepad A im Namensfeld öffnet die Bildschirmtastatur")
	var ne: NameEntry = s.keyboard.entry
	assert_eq(ne.line.text, "Anke", "Tastatur beginnt mit dem Namen")
	ne._backspace()
	ne._type("i")
	s.keyboard.answer(true)
	assert_eq(field.text, "Anki", "OK übernimmt den Namen ins Feld")
	assert_eq(str(settings.get("player_name")), "Anki", "und in die Einstellungen")
	assert_true(s.keyboard == null, "Tastatur geschlossen")
	s.open_keyboard()
	s.keyboard.entry.line.text = "Zzz"
	s.keyboard.answer(false)
	assert_eq(field.text, "Anki", "Abbrechen (Esc) ändert nichts")
	settings.set("player_name", old_name)
	s.free()


func test_hud_fit_shortens_long_texts() -> void:
	var hud := Hud.new()
	var f := UiTheme.font(UiTheme.F.BODY)
	assert_eq(hud._fit("Kiel – Hamburg", f, 19, 300.0), "Kiel – Hamburg", "kurzer Text unverändert")
	var long := "REKORD 12:34.56 · Maximilian Mustermann"
	var fitted := hud._fit(long, f, 19, 200.0)
	assert_true(fitted.ends_with("…") and fitted.length() < long.length(), "gekürzt mit … (%s)" % fitted)
	assert_true(f.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x <= 200.0, "passt in die Breite")
	hud.free()
