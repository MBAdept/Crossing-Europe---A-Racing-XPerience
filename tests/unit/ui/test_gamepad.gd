extends TestCase
## Gamepad and Steam Deck check v0.5.1 (docs/steam-deck.md "Prüfung v0.5.1"): every gamepad drives (InputMap
## device -1), ◀▶ values take one step per stick push (UiKit.ui_step), held directions repeat (PadRepeat), LB / RB
## page long lists, the on-screen keyboard (B deletes one character, closes when empty; A / Start in an empty field
## go to the keys), the question box names its keys, steering with the stick (SessionRules.stick_steer), vibration
## (Haptics), the full-screen start value under gamescope and only the chosen value saved, standby detection, the
## interpolated race view and the sprite sets a stage loads before the start. Review of the fixes: only the active
## pad's stick steers (a drifting second pad does not), a disconnected pad pauses only when it was in use, the title
## does not remember "Beenden", the list footers name PageUp / PageDown, an old settings file's "Vollbild: Aus" is not
## a choice. The live input path (frames, the Input singleton) is checked by tests/race/check_menu_pad.gd.

const SettingsScript := preload("res://scripts/core/settings.gd")
const RaceScript := preload("res://scripts/race/race_session.gd")
const DIR := "user://test_gamepad"
const SETTINGS_FILE := DIR + "/settings.json"


func _ensure_input_map() -> void:
	var setup: Node = load("res://scripts/core/input_setup.gd").new()
	setup.free()


func _pad(button: JoyButton, device: int = 0, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	return e


func _axis(axis: JoyAxis, value: float, device: int = 0) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = value
	return e


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


## Through the Input singleton (its state) and InputMode (InputSetup._input does that in the game).
func _feed(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	InputMode.note(e)


func test_every_gamepad_drives_and_confirms() -> void:
	_ensure_input_map()
	for dev in [0, 1, 3]:
		var tag := "Gerät %d" % dev
		# the stick is read from the active pad (InputMode.device, test_only_the_active_pads_stick_steers)
		assert_false(_axis(JOY_AXIS_LEFT_X, 1.0, dev).is_action("steer_right"), tag + ": Stick nicht in der Lenkaktion")
		assert_near(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, dev).get_action_strength("accelerate"), 1.0, 0.001, tag + ": RT gibt Gas")
		assert_near(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0, dev).get_action_strength("brake"), 1.0, 0.001, tag + ": LT bremst")
		assert_true(_pad(JOY_BUTTON_A, dev).is_action_pressed("accelerate"), tag + ": A gibt Gas")
		assert_true(_pad(JOY_BUTTON_A, dev).is_action_pressed("ui_accept"), tag + ": A bestätigt")
		assert_true(_pad(JOY_BUTTON_B, dev).is_action_pressed("ui_cancel"), tag + ": B geht zurück")
		assert_true(_pad(JOY_BUTTON_X, dev).is_action_pressed("brake"), tag + ": X bremst")
		assert_true(_pad(JOY_BUTTON_START, dev).is_action_pressed("pause"), tag + ": Start pausiert")
		assert_true(_pad(JOY_BUTTON_DPAD_LEFT, dev).is_action_pressed("steer_left"), tag + ": Steuerkreuz lenkt")
		assert_true(_pad(JOY_BUTTON_LEFT_SHOULDER, dev).is_action_pressed("ui_page_up"), tag + ": LB = Seite hoch")
		assert_true(_pad(JOY_BUTTON_RIGHT_SHOULDER, dev).is_action_pressed("ui_page_down"), tag + ": RB = Seite runter")
	for a in ["steer_left", "steer_right", "accelerate", "brake", "pause", "ui_accept", "ui_cancel", "ui_page_up", "ui_page_down"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				assert_eq(e.device, -1, "%s: %s für alle Geräte" % [a, e.as_text()])


func test_ui_step_counts_a_stick_once_per_frame_and_keys_with_echo() -> void:
	_ensure_input_map()
	# keys and the D-pad as before (the key's echo repeats), the repeat of a held pad direction counts
	var k := InputEventKey.new()
	k.keycode = KEY_LEFT
	k.physical_keycode = KEY_LEFT
	k.pressed = true
	k.echo = true
	assert_true(UiKit.ui_step(k, "ui_left"), "Tastenwiederholung zählt")
	assert_true(UiKit.ui_step(_pad(JOY_BUTTON_DPAD_LEFT), "ui_left"), "Steuerkreuz zählt")
	assert_false(UiKit.ui_step(_pad(JOY_BUTTON_DPAD_LEFT, 0, false), "ui_left"), "Loslassen zählt nicht")
	assert_true(UiKit.ui_step(PadRepeat.repeat_event(&"ui_left"), "ui_left"), "Wiederholung (InputEventAction) zählt")
	assert_false(UiKit.ui_step(PadRepeat.repeat_event(&"ui_right"), "ui_left"), "andere Richtung zählt nicht")
	# a stick push: many motion events above the deadzone, one step (Input state as the engine sees it)
	var steps := 0
	for v in [0.3, 0.6, 0.9, 1.0, 0.9, 0.6, 0.3, 0.0]:
		var e := _axis(JOY_AXIS_LEFT_X, -v)
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		if UiKit.ui_step(e, "ui_left"):
			steps += 1
	assert_eq(steps, 1, "ein Stick-Schnipser = ein Schritt (QA v0.5.1: 5)")
	var noise := 0
	for v in [0.74, 0.76, 0.75, 0.74]:
		var e2 := _axis(JOY_AXIS_LEFT_X, v)
		Input.parse_input_event(e2)
		Input.flush_buffered_events()
		if UiKit.ui_step(e2, "ui_right"):
			noise += 1
	assert_true(noise <= 1, "rauschender, gehaltener Stick: höchstens ein Schritt (%d)" % noise)
	Input.parse_input_event(_axis(JOY_AXIS_LEFT_X, 0.0))
	Input.flush_buffered_events()


func test_pad_repeat_after_delay_only_while_held() -> void:
	_ensure_input_map()
	var r := PadRepeat.new()
	var held := {"ui_down": true}
	r.is_held = func(a: StringName) -> bool: return bool(held.get(String(a), false))
	r.note(_pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(r.held(), &"ui_down", "Steuerkreuz ▼ gehalten")
	var fired := 0
	var t := 0.0
	while t < 1.0:
		if r.update(1.0 / 60.0, true) != &"":
			fired += 1
		t += 1.0 / 60.0
	# first repeat after 0.5 s, then every 0.1 s: (1.0 - 0.5) / 0.1 + 1 = 6
	assert_between(float(fired), 5.0, 7.0, "1 s gehalten: Wiederholungen")
	assert_eq(r.update(0.5, false), &"", "ohne Fokus keine Wiederholung")
	held["ui_down"] = false
	assert_eq(r.update(0.2, true), &"", "losgelassen: Schluss")
	assert_eq(r.held(), &"", "nichts mehr gehalten")
	# a key press of a direction stops the pad repeat (the keyboard repeats by itself)
	held["ui_left"] = true
	r.note(_axis(JOY_AXIS_LEFT_X, -0.9))
	assert_eq(r.held(), &"ui_left", "Stick links gehalten")
	var k := InputEventKey.new()
	k.keycode = KEY_LEFT
	k.physical_keycode = KEY_LEFT
	k.pressed = true
	r.note(k)
	assert_eq(r.held(), &"", "Taste übernimmt")
	# stick noise does not restart the delay; returning below the deadzone stops
	r.note(_axis(JOY_AXIS_LEFT_X, -0.9))
	assert_eq(r.update(0.4, true), &"", "0,4 s gehalten: noch ein einzelner Schritt (Stick-Stoß)")
	r.note(_axis(JOY_AXIS_LEFT_X, -0.88))
	assert_eq(r.update(0.11, true), &"ui_left", "Rauschen startet die Verzögerung nicht neu")
	r.note(_axis(JOY_AXIS_LEFT_X, -0.2))
	assert_eq(r.held(), &"", "Stick zurück: Schluss")


func test_page_index_clamps() -> void:
	assert_eq(UiKit.page_index(0, UiKit.PAGE_STEP, 51), 8, "RB: 8 weiter")
	assert_eq(UiKit.page_index(47, UiKit.PAGE_STEP, 51), 50, "am Ende stehen bleiben")
	assert_eq(UiKit.page_index(3, -UiKit.PAGE_STEP, 51), 0, "LB: am Anfang stehen bleiben")
	assert_eq(UiKit.page_index(0, 8, 0), 0, "leere Liste")


func test_name_entry_b_deletes_one_character_also_with_selection() -> void:
	_ensure_input_map()
	var ne := NameEntry.new("Jörg")
	ne.line.select_all()
	assert_true(ne.line.has_selection(), "Name vorausgewählt (wie beim Fokus)")
	ne._backspace()
	assert_eq(ne.line.text, "Jör", "erstes B löscht nur ein Zeichen (QA v0.5.1: alles)")
	ne.free()


func test_name_entry_box_b_on_empty_closes_without_change() -> void:
	_ensure_input_map()
	var box := NameEntryBox.new("Spielername", "Al")
	var got := []
	box.submitted.connect(func(n: String) -> void: got.append("ok:" + n))
	box.cancelled.connect(func() -> void: got.append("abbruch"))
	var ne := box.entry
	assert_true(ne.can_close, "Box: B im leeren Feld schließt")
	assert_eq(ne.current_hints()[2][1], "Löschen", "Hinweis B: Löschen")
	assert_true(ne.handle_gamepad_cancel(_pad(JOY_BUTTON_B), ne.line), "B behandelt")
	assert_true(ne.handle_gamepad_cancel(_pad(JOY_BUTTON_B), ne.line), "B behandelt")
	assert_eq(ne.line.text, "", "zwei B: leer")
	assert_eq(ne.current_hints()[2][1], "Schließen", "Hinweis B im leeren Feld: Schließen")
	assert_true(got.is_empty(), "noch nichts beantwortet")
	assert_true(ne.handle_gamepad_cancel(_pad(JOY_BUTTON_B), ne.line), "B im leeren Feld behandelt")
	assert_eq(got, ["abbruch"], "B im leeren Feld schließt ohne Änderung")
	box.free()


func test_name_entry_a_or_start_in_empty_field_go_to_the_keys() -> void:
	_ensure_input_map()
	var ne := NameEntry.new("")
	var got: Array[String] = []
	ne.submitted.connect(func(n: String) -> void: got.append(n))
	assert_false(ne.submit_or_type(), "A im leeren Feld trägt nicht ein")
	ne._on_line_input(_pad(JOY_BUTTON_A))
	assert_true(got.is_empty(), "kein „Unbekannt“ aus Versehen")
	assert_false(ne.can_close, "Ergebnis: kein Schließen")
	ne._type("A")
	ne._type("n")
	assert_true(ne.handle_gamepad_start(_pad(JOY_BUTTON_START), ne.line), "Start behandelt")
	assert_eq(got, ["An"] as Array[String], "Start trägt den getippten Namen ein")
	ne.free()
	var ne2 := NameEntry.new("")
	var got2: Array[String] = []
	ne2.submitted.connect(func(n: String) -> void: got2.append(n))
	ne2._submit()   # OK on an empty field: still "Unbekannt", but the screens do not remember it as the name
	assert_eq(got2, ["Unbekannt"] as Array[String], "OK im leeren Feld: Unbekannt")
	assert_eq(ne2.typed_name(), "", "getippter Name leer (wird nicht als Spielername gemerkt)")
	ne2.free()


func test_name_entry_hints_follow_the_focus() -> void:
	var ne := NameEntry.new("Al")
	var seen: Array = []
	ne.hints_changed.connect(func(h: Array) -> void: seen.append(h))
	ne._set_on_key(true)
	assert_eq(ne.current_hints()[0][1], "Tippen", "auf den Tasten: A tippt")
	ne._set_on_key(false)
	assert_eq(ne.current_hints()[0][1], "Eintragen", "im Feld mit Namen: A trägt ein")
	assert_eq(seen.size(), 2, "Fußzeile bekommt jede Änderung")
	ne.line.text = ""
	assert_eq(ne.current_hints()[0][1], "Tippen", "im leeren Feld: A springt zum Tippen auf die Tasten")
	ne._set_on_key(false, true)
	assert_eq(ne.current_hints()[0][1], "Eintragen", "auf OK: A trägt ein (auch leer: Unbekannt)")
	ne.line.text = "Al"
	var pads := KeyHints.visible_hints(ne.current_hints(), true)
	assert_eq(pads.size(), 4, "Gamepad: A, Steuerkreuz, B, Start")
	ne.free()


func test_typing_starts_editing_a_navigated_line_edit() -> void:
	var le := LineEdit.new()
	le.text = "Jo"
	var k := InputEventKey.new()
	k.keycode = KEY_R
	k.unicode = "r".unicode_at(0)
	k.pressed = true
	assert_false(le.is_editing(), "per Navigation erreicht: nicht im Bearbeitungsmodus")
	assert_true(NameEntry.begin_typing(le, k), "die erste Taste startet die Bearbeitung")
	assert_eq(le.caret_column, 2, "am Ende weiter tippen")
	var bs := InputEventKey.new()
	bs.keycode = KEY_BACKSPACE
	bs.pressed = true
	assert_true(NameEntry.types_text(bs), "Rücktaste auch")
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_DOWN
	arrow.pressed = true
	assert_false(NameEntry.types_text(arrow), "Pfeiltaste navigiert weiter")
	le.free()


func test_confirm_box_names_its_keys() -> void:
	var box := ConfirmBox.new("Spiel beenden?", "", "Beenden", "Abbrechen")
	var h := box.key_hints()
	assert_eq(KeyHints.visible_hints(h, true), [[["dpad:lr"], "Wählen"], [["pad:A"], "Bestätigen"], [["pad:B"], "Abbrechen"]],
		"Gamepad: ◀▶ wählen, A bestätigt, B = Abbrechen")
	box.free()


func test_stick_steering_curve() -> void:
	var dz := 0.12
	var full := 0.92
	assert_eq(SessionRules.stick_steer(0.10, 0.0, dz, full), 0.0, "0,10: Ruherauschen")
	assert_near(SessionRules.stick_steer(0.92, 0.0, dz, full), 1.0, 0.001, "0,92: volle Lenkung")
	assert_near(SessionRules.stick_steer(1.0, 0.0, dz, full), 1.0, 0.001, "1,0: voll")
	assert_true(SessionRules.stick_steer(cos(deg_to_rad(30.0)), 0.0, dz, full) >= 0.9, "30° schräg ≥ 0,9 (vorher 0,83)")
	assert_true(SessionRules.stick_steer(0.2, 0.0, dz, full) > 0.05, "kleine Korrektur 0,2 lenkt (vorher 0)")
	assert_near(SessionRules.stick_steer(0.0, 1.0, dz, full), -1.0, 0.001, "Taste/Steuerkreuz links: voll")
	assert_near(SessionRules.stick_steer(0.6, 1.0, dz, full), 0.6 - 1.0, 0.001, "Steuerkreuz links + Stick rechts")
	# actions (keys / D-pad) and the active pad's stick: per direction the stronger, as with the stick in the actions
	assert_near(SessionRules.pad_steer(0.0, 0.0, 0.6, dz, full), 0.6, 0.001, "Stick rechts 0,6")
	assert_near(SessionRules.pad_steer(0.0, 0.0, -1.0, dz, full), -1.0, 0.001, "Stick links voll")
	assert_near(SessionRules.pad_steer(0.0, 1.0, 0.6, dz, full), 0.6 - 1.0, 0.001, "Steuerkreuz links + Stick rechts")
	assert_near(SessionRules.pad_steer(1.0, 0.0, 0.3, dz, full), 1.0, 0.001, "Taste rechts + Stick rechts: voll")
	assert_eq(SessionRules.pad_steer(0.0, 0.0, 0.1, dz, full), 0.0, "Ruherauschen des aktiven Pads")


## Steering reads the left stick of the active pad only (InputMode.device, race_session.gd player_steer): a resting
## second pad with a drifting stick does not steer (QA v0.5.1 review: 0.16 drift = 5 % steering), a switch of pads in
## the race moves the steering to the pad used last, keys and the D-pad of every pad steer fully. Two devices in the
## real Input state.
func test_only_the_active_pads_stick_steers() -> void:
	_ensure_input_map()
	var old_dev := InputMode.device
	var old_pad := InputMode.gamepad
	var dz := 0.12
	var full := 0.92
	_feed(_axis(JOY_AXIS_LEFT_X, 0.16, 0))          # pad 0 lies around, its stick drifts
	_feed(_pad(JOY_BUTTON_A, 1))                    # pad 1 is used
	_feed(_pad(JOY_BUTTON_A, 1, false))
	assert_eq(InputMode.device, 1, "Gerät 1 benutzt (A)")
	assert_eq(RaceScript.player_steer(dz, full), 0.0, "Pad 0 driftet (0,16): keine Lenkung (vorher 0,05)")
	_feed(_axis(JOY_AXIS_LEFT_X, 0.6, 1))
	assert_near(RaceScript.player_steer(dz, full), 0.6, 0.001, "Stick von Pad 1: 0,6")
	_feed(_axis(JOY_AXIS_LEFT_X, -0.3, 1))
	assert_near(RaceScript.player_steer(dz, full), -0.225, 0.001, "kleine Korrektur links, nicht vom Drift gemindert (vorher -0,175)")
	# switching pads in the race: a clear push on pad 0 makes it the active pad
	_feed(_axis(JOY_AXIS_LEFT_X, -1.0, 0))
	assert_eq(InputMode.device, 0, "Pad 0 übernimmt (deutlicher Ausschlag)")
	_feed(_axis(JOY_AXIS_LEFT_X, 0.8, 1))           # a clear push on pad 1 takes it back
	assert_eq(InputMode.device, 1, "Pad 1 wieder (deutlicher Ausschlag)")
	assert_near(RaceScript.player_steer(dz, full), 0.85, 0.001, "nur Pad 1 lenkt (Pad 0 hält noch −1,0)")
	_feed(_axis(JOY_AXIS_LEFT_X, 0.3, 0))           # a light touch on pad 0 does not take over
	assert_eq(InputMode.device, 1, "leichte Berührung von Pad 0 wechselt nicht")
	_feed(_axis(JOY_AXIS_LEFT_X, 0.0, 1))
	assert_eq(RaceScript.player_steer(dz, full), 0.0, "Pad 1 in Mittelstellung, Pad 0 bei 0,3: geradeaus")
	# keys and the D-pad of any pad: full lock, the active pad does not matter
	_feed(_pad(JOY_BUTTON_DPAD_LEFT, 3))
	assert_near(RaceScript.player_steer(dz, full), -1.0, 0.001, "Steuerkreuz von Pad 3: voll links")
	_feed(_pad(JOY_BUTTON_DPAD_LEFT, 3, false))
	_feed(_key(KEY_RIGHT))
	assert_near(RaceScript.player_steer(dz, full), 1.0, 0.001, "Pfeil rechts: voll")
	_feed(_key(KEY_RIGHT, false))
	for d in [0, 1]:
		_feed(_axis(JOY_AXIS_LEFT_X, 0.0, d))
	assert_eq(RaceScript.player_steer(dz, full), 0.0, "alles los: geradeaus")
	InputMode.device = old_dev
	InputMode.gamepad = old_pad


## A disconnected gamepad (InputSetup.pad_disconnected; the race pauses on `in_use`): only the active pad or one still
## holding a button, stick or trigger is in use – a keyboard player's idle pad switching off is not (QA v0.5.1 review:
## every disconnect paused the race and released the keyboard's throttle as well). The engine has released the pad's
## own state already (Input::joy_connection_changed) – the race releases nothing.
func test_pad_disconnect_counts_only_a_pad_in_use() -> void:
	var old_dev := InputMode.device
	var old_pad := InputMode.gamepad
	var old_held: Dictionary = InputMode._held.duplicate(true)
	InputMode._held.clear()   # earlier tests note presses without their release
	# a keyboard player; pad 0 lies around with a drifting stick
	InputMode.note(_pad(JOY_BUTTON_A, 0))
	InputMode.note(_pad(JOY_BUTTON_A, 0, false))
	InputMode.note(_axis(JOY_AXIS_LEFT_X, 0.16, 0))
	InputMode.note(_key(KEY_UP))
	assert_false(InputMode.gamepad, "Tastatur aktiv")
	assert_false(InputMode.holds(0), "Drift 0,16 gilt als Ruhe")
	assert_false(InputMode.pad_lost(0, [1]), "ruhendes Pad eines Tastaturspielers: nicht in Benutzung")
	# the active pad, nothing held
	InputMode.note(_pad(JOY_BUTTON_A, 1))
	InputMode.note(_pad(JOY_BUTTON_A, 1, false))
	assert_true(InputMode.pad_lost(1, [0]), "aktives Pad: in Benutzung")
	assert_eq(InputMode.device, 0, "das verbliebene Pad übernimmt (Lenkung, Vibration)")
	assert_true(InputMode.gamepad, "eines ist noch da: Gamepad bleibt aktiv")
	# a pad that still holds the trigger while the keyboard drives
	InputMode.note(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.8, 2))
	InputMode.note(_key(KEY_UP))
	assert_true(InputMode.holds(2), "Trigger gehalten")
	assert_true(InputMode.pad_lost(2, [0]), "Pad hält noch den Trigger: in Benutzung")
	assert_false(InputMode.holds(2), "vergessen")
	# a held button counts, a released one not
	InputMode.note(_pad(JOY_BUTTON_X, 3))
	InputMode.note(_key(KEY_UP))
	assert_true(InputMode.pad_lost(3, [0]), "Pad hält X: in Benutzung")
	InputMode.note(_pad(JOY_BUTTON_Y, 4))
	InputMode.note(_pad(JOY_BUTTON_Y, 4, false))
	InputMode.note(_key(KEY_UP))
	assert_false(InputMode.pad_lost(4, [0]), "Y losgelassen, Tastatur aktiv: nicht in Benutzung")
	# InputSetup reports it (decided before the mode changes: with no pad left the keyboard is active afterwards)
	var setup: Node = load("res://scripts/core/input_setup.gd").new()
	var got: Array = []
	setup.connect("pad_disconnected", func(d: int, in_use: bool) -> void: got.append([d, in_use]))
	InputMode.gamepad = true
	InputMode.device = 5
	setup.call("_on_joy_connection_changed", 5, false)
	setup.call("_on_joy_connection_changed", 6, true)
	assert_eq(got, [[5, true]], "Trennen des aktiven Pads gemeldet, Verbinden nicht")
	setup.free()
	InputMode.device = old_dev
	InputMode.gamepad = old_pad
	InputMode._held = old_held


## The title focuses Einzelne Etappe, Bestenlisten or Optionen again on the way back (GameFlow.title_choice) – nothing
## else: after a cancelled quit question every later title (also after an attract demo) focused "Beenden" (QA v0.5.1
## review); the race entries leave it to the save.
func test_title_remembers_only_the_screens_it_comes_back_from() -> void:
	assert_eq(TitleScreen.remembered_choice(2), 2, "Einzelne Etappe")
	assert_eq(TitleScreen.remembered_choice(3), 3, "Bestenlisten")
	assert_eq(TitleScreen.remembered_choice(4), 4, "Optionen")
	assert_eq(TitleScreen.remembered_choice(5), -1, "Beenden wird nicht gemerkt")
	assert_eq(TitleScreen.remembered_choice(0), -1, "Rennen starten: der Spielstand entscheidet")
	assert_eq(TitleScreen.remembered_choice(1), -1, "Rennen fortsetzen: der Spielstand entscheidet")


## LB / RB page the long lists, PageUp / PageDown as well: the footers of Einzelne Etappe and Bestenlisten name both
## (keycaps "Bild ↑" / "Bild ↓", drawn – the fonts have no arrows) and fit the footer with keyboard and gamepad (QA
## v0.5.1 review: "LB RB Seite" only).
func test_list_footers_name_the_page_keys_and_fit() -> void:
	_ensure_input_map()
	var page_keys := {}
	for e in InputMap.action_get_events("ui_page_up") + InputMap.action_get_events("ui_page_down"):
		if e is InputEventKey:
			page_keys[(e as InputEventKey).keycode] = true
	assert_true(page_keys.has(KEY_PAGEUP) and page_keys.has(KEY_PAGEDOWN), "Bild ↑ / Bild ↓ blättern (ui_page_up/down)")
	var fb := UiTheme.font(UiTheme.F.BODY_BOLD)
	assert_true(KeyHints.glyph_width("pgup", fb) > KeyHints.glyph_width("Esc", fb), "Taste „Bild ↑“: Beschriftung und Pfeil")
	var screens := {"Einzelne Etappe": StageSelectScreen.footer_hints(), "Bestenlisten": LeaderboardsScreen.footer_hints()}
	for n: String in screens:
		var h: Array = screens[n]
		var page: Array = []
		for hint in h:
			if str(hint[1]) == "Seite":
				page = hint
		assert_eq(page, [["pgup", "pgdn", "pad:LB", "pad:RB"], "Seite"], n + ": Tastatur und Gamepad")
		assert_eq(KeyHints.visible_hints([page], true), [[["pad:LB", "pad:RB"], "Seite"]], n + ": mit Gamepad nur LB RB")
		for gamepad in [false, true]:
			var w := KeyHints.drawn_width(h, gamepad)
			assert_true(w <= UiScreen.FOOTER.size.x, "%s: Fußzeile %s %.0f px ≤ %.0f px" % [n, "Gamepad" if gamepad else "Tastatur", w, UiScreen.FOOTER.size.x])


func test_haptics_pulses_levels_and_rate() -> void:
	var h := Haptics.new()
	h.configure(cfg())
	var calls: Array = []
	h.start_cb = func(d: int, w: float, s: float, t: float) -> void: calls.append(["start", d, w, s, t])
	h.stop_cb = func(d: int) -> void: calls.append(["stop", d])
	h.device = 2
	h.collision()
	var out := h.update(1.0 / 60.0, Vector2.ZERO)
	assert_near(out.y, 0.9, 0.001, "Kollision: starker Motor 0,9")
	assert_eq(calls.size(), 1, "ein Aufruf")
	assert_eq(int(calls[0][1]), 2, "an das benutzte Gamepad")
	for i in 10:
		h.update(1.0 / 60.0, Vector2.ZERO)
	assert_true(calls.size() <= 4, "höchstens ~15 Aufrufe je Sekunde (%d in 0,18 s)" % calls.size())
	for i in 30:
		h.update(1.0 / 60.0, Vector2.ZERO)
	assert_eq(str(calls[calls.size() - 1][0]), "stop", "nach 0,35 s aus")
	# levels: understeer, shoulder, guardrail scraping
	assert_eq(h.level_for(100.0, 0, false, 0.1), Vector2.ZERO, "leichtes Untersteuern unter 0,15: nichts")
	assert_near(h.level_for(100.0, 0, false, 0.5).x, 0.1 + 0.35 * 0.5, 0.001, "Untersteuern 0,5")
	assert_eq(h.level_for(25.0, 1, false, 0.0), Vector2.ZERO, "Bankett langsam: nichts")
	assert_between(h.level_for(200.0, 1, false, 0.0).x, 0.12, 0.25, "Bankett bei 200")
	assert_near(h.level_for(150.0, 2, true, 0.0).x, 0.35, 0.001, "an der Leitplanke entlang")
	# off: disabled, keyboard active, stop
	calls.clear()
	h.active = false
	h.collision()
	h.update(1.0 / 60.0, Vector2(0.5, 0.0))
	assert_true(calls.is_empty(), "Tastatur aktiv: kein Aufruf")
	h.active = true
	h.enabled = false
	h.update(1.0 / 60.0, Vector2(0.5, 0.0))
	assert_true(calls.is_empty(), "Vibration aus: kein Aufruf")
	h.enabled = true
	h.update(1.0, Vector2(0.4, 0.0))
	h.stop()
	assert_eq(str(calls[calls.size() - 1][0]), "stop", "stop() hält an")


func test_fullscreen_start_value_under_gamescope_and_only_the_choice_saved() -> void:
	assert_true(SettingsScript.fullscreen_by_default(1080, 1.0, true), "gamescope (Deck angedockt, Nativ 1080p): Vollbild")
	assert_false(SettingsScript.fullscreen_by_default(1080, 1.0, false), "Desktop 1080p: Fenster")
	DirAccess.make_dir_recursive_absolute(DIR)
	JsonFile.remove_all(SETTINGS_FILE)
	var s: Node = SettingsScript.new()
	s.set("file_path", SETTINGS_FILE)
	s.call("load_settings")
	s.set("player_name", "Deck")
	s.set("vibration", false)
	assert_true(bool(s.call("save_settings")), "gespeichert")
	var d: Variant = ConfigLoader.load_json(SETTINGS_FILE)
	assert_true(d is Dictionary and not (d as Dictionary).has("fullscreen"), "Vollbild nicht gewählt: nicht gespeichert")
	assert_true(d is Dictionary and (d as Dictionary).get("vibration", true) == false, "Vibration gespeichert")
	s.set("fullscreen", true)
	assert_true(bool(s.get("fullscreen_chosen")), "Umschalten = Wahl")
	s.call("save_settings")
	var t: Node = SettingsScript.new()
	t.set("file_path", SETTINGS_FILE)
	t.call("load_settings")
	assert_true(bool(t.get("fullscreen")) and bool(t.get("fullscreen_chosen")), "gewähltes Vollbild bleibt")
	assert_false(bool(t.get("vibration")), "Vibration aus geladen")
	s.free()
	t.free()
	JsonFile.remove_all(SETTINGS_FILE)


## settings.json of v0.5.1 and older always held "fullscreen": without "settings_version" only a stored true counts as
## chosen – a false (e.g. saved while the Steam Deck was docked on a large screen) gives the start value again (QA
## v0.5.1 review: the Deck kept starting windowed in game mode). From version 2 on the stored value is the choice.
func test_old_settings_file_counts_only_a_stored_fullscreen_true() -> void:
	assert_false(SettingsScript.fullscreen_stored_as_choice({"fullscreen": false}), "alt, Aus: nicht gewählt")
	assert_true(SettingsScript.fullscreen_stored_as_choice({"fullscreen": true}), "alt, An: gewählt")
	assert_true(SettingsScript.fullscreen_stored_as_choice({"fullscreen": false, "settings_version": 2.0}), "v2, Aus: gewählt")
	assert_false(SettingsScript.fullscreen_stored_as_choice({"settings_version": 2}), "v2 ohne Vollbild: nicht gewählt")
	DirAccess.make_dir_recursive_absolute(DIR)
	JsonFile.remove_all(SETTINGS_FILE)
	# a v0.5.1 file written while docked: "fullscreen": false; the start value in game mode is full screen
	assert_true(JsonFile.save_atomic(SETTINGS_FILE, {"master_volume": 0.5, "fullscreen": false, "player_name": "Deck"}), "alte Datei")
	var s: Node = SettingsScript.new()
	s.set("file_path", SETTINGS_FILE)
	s.set("fullscreen", true)
	s.set("fullscreen_chosen", false)
	s.call("load_settings")
	assert_true(bool(s.get("fullscreen")), "alte Datei mit Vollbild Aus: Startwert bleibt (Vollbild)")
	assert_false(bool(s.get("fullscreen_chosen")), "nicht als Wahl gezählt")
	assert_eq(str(s.get("player_name")), "Deck", "übrige Werte gelesen")
	assert_false(bool(s.call("has_unsaved_changes")), "nur gelesen: nichts zu speichern")
	s.set("master_volume", 0.6)
	assert_true(bool(s.call("save_settings")), "gespeichert")
	var d: Variant = ConfigLoader.load_json(SETTINGS_FILE)
	assert_true(d is Dictionary and int((d as Dictionary).get("settings_version", 0)) == 2, "Version 2 geschrieben")
	assert_true(d is Dictionary and not (d as Dictionary).has("fullscreen"), "Vollbild nicht gewählt: nicht mehr gespeichert")
	s.free()
	# a v0.5.1 file with "fullscreen": true stays full screen (chosen); a v2 file with false is the player's choice
	JsonFile.remove_all(SETTINGS_FILE)
	JsonFile.save_atomic(SETTINGS_FILE, {"fullscreen": true})
	var t: Node = SettingsScript.new()
	t.set("file_path", SETTINGS_FILE)
	t.call("load_settings")
	assert_true(bool(t.get("fullscreen")) and bool(t.get("fullscreen_chosen")), "alte Datei mit Vollbild An: gewählt")
	t.free()
	JsonFile.remove_all(SETTINGS_FILE)
	JsonFile.save_atomic(SETTINGS_FILE, {"settings_version": 2, "fullscreen": false})
	var u: Node = SettingsScript.new()
	u.set("file_path", SETTINGS_FILE)
	u.set("fullscreen", true)
	u.set("fullscreen_chosen", false)
	u.call("load_settings")
	assert_false(bool(u.get("fullscreen")), "Version 2 mit Vollbild Aus: Fenster (gewählt)")
	assert_true(bool(u.get("fullscreen_chosen")), "als Wahl gezählt")
	u.free()
	JsonFile.remove_all(SETTINGS_FILE)


func test_standby_detection() -> void:
	assert_false(SessionRules.resumed_from_sleep(0.016, 0.016), "normales Bild")
	assert_false(SessionRules.resumed_from_sleep(5.0, 5.0), "Hänger: beide Uhren gleich")
	assert_true(SessionRules.resumed_from_sleep(600.0, 0.02), "Standby: Wanduhr lief weiter")


func test_view_interpolation_is_even_at_40_fps() -> void:
	# 60 Hz steps shown at 40 fps: 1, 2, 1, 2 steps per frame, fractions 0.5, 0.0, 0.5, 0.0 – the interpolated
	# position advances 1.5 steps every frame (QA v0.5.1: 1 and 2 steps in turn without interpolation)
	var z := 0.0
	var prev := 0.0
	var shown: Array[float] = []
	var pattern := [[1, 0.5], [2, 0.0], [1, 0.5], [2, 0.0], [1, 0.5], [2, 0.0]]
	for p in pattern:
		for i in int(p[0]):
			prev = z
			z += 1.0
		shown.append(SessionRules.lerp_view(prev, z, float(p[1])))
	for i in range(1, shown.size()):
		assert_near(shown[i] - shown[i - 1], 1.5, 0.001, "gleichmäßig 1,5 Schritte je Bild (%d)" % i)
	assert_eq(SessionRules.lerp_view(NAN, 5.0, 0.3), 5.0, "ohne vorigen Wert: aktueller")
	assert_eq(SessionRules.lerp_view(0.0, 100.0, 0.3), 100.0, "Sprung: nicht überblenden")


func test_track_sprite_sets_cover_everything_the_stage_draws() -> void:
	var t := _city_track()
	var sets := t.sprite_sets()
	var fb := t.sprite_fallbacks()
	var missing := {}
	var z := 0.0
	while z < t.length_z:
		t.update_window(z, 10.0)
		for it: Dictionary in t.segment_at(z).sprites:
			var id := str(it.get("set", ""))
			if id != "" and not sets.has(id) and not sets.has(str(fb.get(id, "-"))):
				missing[id] = true
		z += t.seg_len * 8.0
	for e: Dictionary in t.plan.skyline:
		if not sets.has(str(e.get("set", ""))):
			missing[str(e.get("set", ""))] = true
	assert_true(missing.is_empty(), "alle gezeichneten Sätze vorab bekannt, fehlend: %s" % str(missing.keys()))
	assert_true(sets.has("props/fuel_station"), "Tankstelle dabei")
	assert_true(sets.has("landmarks/test_tower"), "Wahrzeichen dabei")


func _city_track() -> Track:
	var countries := {"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}}}
	var cities := {"a": {"name": "Astadt", "country": "DE"}, "b": {"name": "Bstadt", "country": "DE"}}
	var stage := {"id": "t_pre", "from": "a", "to": "b", "length_km": 60, "seed": 77,
		"sections": [{"length_km": 30, "road": "autobahn", "curviness": 1, "hills": 1, "scenery": "north_plain", "country": "DE", "speed_limit": null},
			{"length_km": 30, "road": "autobahn", "curviness": 2, "hills": 2, "scenery": "forest_hills", "country": "DE", "speed_limit": 120}],
		"fuel_stations_km": [25], "radars": [{"km": 20, "limit": 120}]}
	var db := {"center_km": 6.0, "country_style": {"DE": "german"},
		"styles": {"german": {"outskirts": "city_german_outskirts", "center": "city_german_center"}},
		"landmark_sets": {"landmarks/test_tower": {"name": "Testturm", "height_m": 200, "width_m": 30, "fallback": "props/building_tall"}},
		"cities": {"b": {"style": "german", "landmarks": [{"set": "landmarks/test_tower", "km_to_finish": 2.0, "side": 1, "x_m": 60.0}],
			"skyline": ["landmarks/test_tower"], "bridges": [{"km_to_finish": 9.0, "length_m": 120, "type": "truss_arch", "name": "Brücke"}]}}}
	var p := StagePlan.build(stage, "a", cities, countries, cfg(), db)
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var t := Track.new()
	t.setup(p, cfg(), (sc as Dictionary).get("scenery", {}) if sc is Dictionary else {})
	return t
