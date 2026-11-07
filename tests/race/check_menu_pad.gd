extends SceneTree
## Gamepad in the real game, end to end (headless; docs/steam-deck.md "Prüfung v0.5.1"):
##   godot --headless --path . -s res://tests/race/check_menu_pad.gd
## Events go through Input.parse_input_event – the Input singleton's state (just pressed, held) and the viewport
## see them like a real pad's. Checks:
##   stick_wert   one clean stick push (0.3 0.6 0.9 1.0 0.9 0.6 0.3 0, one event per frame) = one step on the vehicle
##                and start time screens and on an options row; a held, noisy stick (0.75 ± 0.01) = one step
##                before the repeat starts (QA v0.5.1: 3–5 vehicles, up to 14 hours)
##   halten       ▼ on the D-pad held 1 s in the leaderboards moves the focus about 7 entries (repeat after 0.5 s,
##                then every 0.1 s); RB jumps 8 entries
##   geraet1      a second pad (device 1): A confirms, B goes back (QA v0.5.1: only device 0)
##   tippen       options: the name field reached with the D-pad takes typed keys (Steam keyboard / PC keyboard)
##   tastatur     options: A opens the on-screen keyboard, B deletes one character, B in the empty field closes it,
##                the name is unchanged
##   beenden      title: "Beenden" asks first (the game keeps running), B cancels
##   rennen       race: RT and the stick of device 1 drive, Start (device 1) pauses; a disconnected pad pauses; a
##                collision vibrates the pad, the pause stops it; the view is interpolated between two steps
## Prints "CHECK <name> OK|FEHLER …"; exit code 0 when all pass. Settings go to a test file (user://), which is
## removed afterwards. Autoloads are accessed untyped (this script compiles before they exist).

const SETTINGS_TEST := "user://test_check_menu_pad_settings.json"

var _gf: Node
var _settings: Node
var _failed: Array[String] = []
var _clock := 0.0
var _wall0 := 0
var _axis_last: Dictionary = {}
var _old_settings_path := ""
var _old_name := ""


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(delta: float) -> bool:
	_clock += delta
	if (Time.get_ticks_msec() - _wall0) / 1000.0 > 180.0:
		print("FEHLER: Zeitlimit")
		quit(2)
	return false


# --- helpers ------------------------------------------------------------------------------------------

func _check(name: String, ok: bool, msg: String = "") -> void:
	print("CHECK %-12s %s  %s" % [name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(name)


func _wait(s: float) -> void:
	var t0 := _clock
	while _clock - t0 < s:
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _btn(b: JoyButton, pressed: bool, dev: int = 0) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	e.pressed = pressed
	e.pressure = 1.0 if pressed else 0.0
	_send(e)


func _tap(b: JoyButton, dev: int = 0) -> void:
	_btn(b, true, dev)
	await _frames(3)
	_btn(b, false, dev)
	await _frames(6)


func _axis(a: JoyAxis, v: float, dev: int = 0) -> void:
	var k := "%d/%d" % [dev, a]
	if float(_axis_last.get(k, 99.0)) == v:
		return
	_axis_last[k] = v
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = a
	e.axis_value = v
	_send(e)


## One clean stick push, one motion event per frame.
func _flick(a: JoyAxis, sign_: float) -> void:
	for v in [0.3, 0.6, 0.9, 1.0, 0.9, 0.6, 0.3, 0.0]:
		_axis(a, v * sign_)
		await process_frame
	await _frames(4)


func _key(code: Key, ch: String = "") -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = ch.unicode_at(0) if ch != "" and pressed else 0
		e.pressed = pressed
		_send(e)
		await process_frame


func _screen() -> Node:
	var shell: Variant = _gf.get("shell")
	if shell == null or not is_instance_valid(shell):
		return null
	return (shell as Node).get("current_screen")


func _go(screen: String, params: Dictionary = {}) -> Node:
	_gf.call("go", screen, params, true)
	await _frames(8)
	return _screen()


func _focus() -> Control:
	return root.gui_get_focus_owner()


# --- run ----------------------------------------------------------------------------------------------

func _run() -> void:
	_gf = root.get_node_or_null("GameFlow")
	_settings = root.get_node_or_null("Settings")
	if _gf == null or _settings == null:
		print("FEHLER: Autoloads fehlen")
		quit(1)
		return
	_old_settings_path = str(_settings.get("file_path"))
	_old_name = str(_settings.get("player_name"))
	_settings.set("file_path", SETTINGS_TEST)
	_settings.set("player_name", "Anke")
	var am: Node = _gf.get("attract")
	if am != null:
		am.set("enabled", false)
	_gf.call("boot")
	await _frames(10)
	await _check_stick_values()
	await _check_hold_and_page()
	await _check_device1()
	await _check_typing()
	await _check_osk()
	await _check_quit()
	await _check_race()
	_settings.set("file_path", _old_settings_path)
	_settings.set("player_name", _old_name)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SETTINGS_TEST + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST + suffix))
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _check_stick_values() -> void:
	var races: Array = root.get_node("GameData").call("visible_race_ids")
	_gf.set("draft", {"race_id": str(races[0]) if not races.is_empty() else ""})
	_gf.set("mode", "race")
	var vs: Node = await _go("vehicle", {"mode": "race"})
	var i0 := int(vs.get("_index"))
	await _flick(JOY_AXIS_LEFT_X, 1.0)
	var n: int = (vs.get("_ids") as Array).size()
	var d1 := posmod(int(vs.get("_index")) - i0, n)
	# a held, noisy stick shorter than the repeat delay
	var i1 := int(vs.get("_index"))
	var t_hold := _clock
	var k := 0
	while _clock - t_hold < 0.4:   # 0.4 s, noisy (QA v0.5.1: 3 vehicles)
		_axis(JOY_AXIS_LEFT_X, 0.75 + (0.01 if k % 2 == 0 else -0.01))
		k += 1
		await process_frame
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(4)
	var d2 := posmod(int(vs.get("_index")) - i1, n)
	var st: Node = await _go("start_time")
	var s0 := int(st.get("_index"))
	await _flick(JOY_AXIS_LEFT_X, 1.0)
	var s1 := int(st.get("_index"))
	await _flick(JOY_AXIS_LEFT_Y, -1.0)   # ▲ = one hour
	var s2 := int(st.get("_index"))
	var per_hour := int(st.get("_per_hour"))
	await _go("options")
	var row: Node = _focus()
	var v0 := int(row.get("index")) if row != null else -1
	await _flick(JOY_AXIS_LEFT_X, -1.0)
	var v1 := int(row.get("index")) if row != null else -1
	_check("stick_wert", d1 == 1 and d2 == 1 and s1 - s0 == 1 and s2 - s1 == per_hour and v0 - v1 == 1,
		"Fahrzeug %d / gehalten %d, Startzeit %d / ▲ %d (je Stunde %d), Lautstärke %d → %d" % [d1, d2, s1 - s0, s2 - s1, per_hour, v0, v1])


func _check_hold_and_page() -> void:
	var lb: Node = await _go("leaderboards")
	var list: Array = lb.get("_list")
	await _frames(4)
	var f0 := list.find(_focus())
	_btn(JOY_BUTTON_DPAD_DOWN, true)
	await _wait(1.0)
	_btn(JOY_BUTTON_DPAD_DOWN, false)
	await _frames(4)
	var f1 := list.find(_focus())
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	var f2 := list.find(_focus())
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	var f3 := list.find(_focus())
	_check("halten", f0 == 0 and f1 - f0 >= 5 and f1 - f0 <= 9 and f2 - f1 == 8 and f2 - f3 == 8,
		"Steuerkreuz 1 s gehalten: %d Einträge (vorher 1), RB +%d, LB −%d, %d Einträge" % [f1 - f0, f2 - f1, f2 - f3, list.size()])


func _check_device1() -> void:
	var title: Node = await _go("title")
	var buttons: Array = title.get("_buttons")
	(buttons[2] as Control).grab_focus()   # "Einzelne Etappe"
	await _frames(3)
	await _tap(JOY_BUTTON_A, 1)
	await _frames(6)
	var after_a := str(_gf.call("current_screen_name"))
	await _tap(JOY_BUTTON_B, 1)
	await _frames(6)
	var after_b := str(_gf.call("current_screen_name"))
	_check("geraet1", after_a == "stage_select" and after_b == "title", "zweites Gamepad: A → %s, B → %s" % [after_a, after_b])


func _check_typing() -> void:
	var op: Node = await _go("options")
	var field: LineEdit = op.get("_name")
	var vib: Control = op.get("vibration")
	vib.grab_focus()
	await _frames(3)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var on_field := _focus() == field
	var editing0 := field.is_editing()
	field.text = "Anke"
	await _key(KEY_Q, "Q")
	await _key(KEY_X, "x")
	var typed := field.text
	field.unedit()
	field.text = "Anke"
	_settings.set("player_name", "Anke")
	_check("tippen", on_field and not editing0 and typed == "AnkeQx",
		"Feld per Steuerkreuz erreicht (Bearbeitung %s), getippt Q, x → '%s'" % [editing0, typed])


func _check_osk() -> void:
	var op: Node = await _go("options")
	var field: LineEdit = op.get("_name")
	field.grab_focus()
	await _frames(3)
	await _tap(JOY_BUTTON_A)
	await _frames(4)
	var kb: Variant = op.get("keyboard")
	var opened := kb != null
	await _tap(JOY_BUTTON_B)
	var after_one := ""
	if opened and is_instance_valid(kb):
		after_one = str((kb as Node).get("entry").get("line").text)
	for i in 3:
		await _tap(JOY_BUTTON_B)
	var still_open := op.get("keyboard") != null
	await _tap(JOY_BUTTON_B)
	var closed := op.get("keyboard") == null
	_check("tastatur", opened and after_one == "Ank" and still_open and closed and field.text == "Anke",
		"A öffnet (%s), erstes B: '%s', leer noch offen (%s), B schließt (%s), Name '%s'" % [opened, after_one, still_open, closed, field.text])


func _check_quit() -> void:
	var title: Node = await _go("title")
	var buttons: Array = title.get("_buttons")
	(buttons[buttons.size() - 1] as Control).grab_focus()   # "Beenden"
	await _frames(3)
	await _tap(JOY_BUTTON_A)
	await _frames(4)
	var asked := bool(title.call("has_modal"))
	await _tap(JOY_BUTTON_B)
	await _frames(4)
	var gone := not bool(title.call("has_modal"))
	_check("beenden", asked and gone, "Abfrage vor dem Beenden (%s), B bricht ab (%s)" % [asked, gone])


func _check_race() -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 10.0, "autopilot": false,
		"no_countdown": true, "seed": 3}
	_gf.call("start_stage", setup)
	await _frames(10)
	var sc: Node = _gf.get("current")
	if sc == null or sc.get("plan") == null:
		_check("rennen", false, "Rennszene fehlt")
		return
	# device 1 drives
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 1)
	_axis(JOY_AXIS_LEFT_X, 1.0, 1)
	await _wait(0.4)
	var inp: Dictionary = sc.get("last_input")
	var steer := float(inp.get("steer", 0.0))
	var throttle := float(inp.get("throttle", 0.0))
	_axis(JOY_AXIS_LEFT_X, 0.0, 1)
	await _tap(JOY_BUTTON_START, 1)
	var was_paused := paused
	await _wait(0.2)   # the pause menu ignores input in its first 120 ms
	await _tap(JOY_BUTTON_START, 1)
	var resumed := not paused
	# pad disconnected: the race pauses, held axes are released
	sc.call("_on_joy_connection_changed", 1, false)
	await _frames(2)
	var paused_dc := paused
	var throttle_released := Input.get_action_strength("accelerate") == 0.0
	sc.call("_on_resume")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0, 1)
	await _frames(4)
	# a collision vibrates the pad in use, the pause stops it
	var im: GDScript = load("res://scripts/core/input_mode.gd")
	im.set("gamepad", true)
	im.set("device", 1)
	var haptics: Object = sc.get("haptics")
	haptics.set("enabled", true)
	(sc.get("vehicle") as Object).emit_signal("crash_started", 1)
	await _frames(3)
	var vib := Input.get_joy_vibration_strength(1)
	sc.call("_pause_now")
	var vib_stop := Input.get_joy_vibration_strength(1)
	sc.call("_on_resume")
	await _frames(3)
	# interpolated view: halfway between the last two steps at fraction 0.5
	sc.set("_view_alpha", 0.5)
	var vs: Dictionary = sc.call("view_state")
	var prev_z := float(sc.get("_prev_pos_z"))
	var cur_z := float(sc.get("pos_z"))
	var mid_ok := absf(float(vs["pos_z"]) - (prev_z + cur_z) * 0.5) < 0.001 and cur_z > prev_z
	sc.set("_view_alpha", -1.0)
	_check("rennen", steer > 0.9 and throttle > 0.9 and was_paused and resumed and paused_dc and throttle_released and vib.y > 0.5 and vib_stop == Vector2.ZERO and mid_ok,
		"Gerät 1: Lenkung %.2f, Gas %.2f, Start pausiert %s / weiter %s; Gamepad getrennt: Pause %s, Gas losgelassen %s; Kollision: Vibration %s, Pause: %s; Ansicht halb zwischen zwei Schritten %s" % [
			steer, throttle, was_paused, resumed, paused_dc, throttle_released, str(vib), str(vib_stop), mid_ok])
	_gf.call("show_title")
	await _frames(6)
