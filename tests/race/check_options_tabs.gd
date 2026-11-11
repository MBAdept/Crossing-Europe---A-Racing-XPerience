extends SceneTree
## v0.8.0 (UI1): the options with the pages ALLGEMEIN / GRAFIK, operated with real gamepad events in the real game
## (headless, ~10 s):
##   godot --headless --path . -s res://tests/race/check_options_tabs.gd -- --graphics=arcade
## RB / LB switch the page and move the focus to its first row; ◀▶ on "Grafik" switch Arcade / Modern and "Klang:
## Wie Grafik" follows; in Arcade the quality rows are dimmed and skipped by the focus; a changed single value makes
## the preset "Eigene"; "Musik im Rennen" can only be reached with the Modern sound; B saves (settings version 3).
## Prints "CHECK <name> OK|FEHLER" lines, exit code 1 on a failure. (Not in tools/run_tests.sh yet: the integration
## hooks it in – docs/grafik-modi.md.)

const SETTINGS_TEST := "user://test_check_options_tabs.json"

var _gf: Node
var _settings: Node
var _failed: Array[String] = []
var _n := 0
var _t0 := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _check(check_name: String, ok: bool, msg: String = "") -> void:
	_n += 1
	print("CHECK %-15s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## One press and release of a gamepad button through the engine's input (as a real pad: InputSetup maps it).
func _tap(b: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = b
		e.pressed = pressed
		e.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await _frames(3)
	await _frames(3)


func _taps(b: JoyButton, n: int) -> void:
	for i in n:
		await _tap(b)


func _focus_label() -> String:
	var f := root.gui_get_focus_owner()
	if f == null:
		return "<kein Fokus>"
	var lt: Variant = f.get("label_text")
	if lt != null and str(lt) != "":
		return str(lt)
	if f is Button:
		return (f as Button).text
	return f.get_class()


func _screen() -> Node:
	var shell: Node = _gf.get("shell")
	return shell.get("current_screen") if shell != null else null


func _focusable(row: Variant) -> bool:
	return row is Control and (row as Control).focus_mode != Control.FOCUS_NONE


func _run() -> void:
	_gf = root.get_node_or_null("GameFlow")
	_settings = root.get_node_or_null("Settings")
	var old_path := str(_settings.get("file_path"))
	_settings.set("file_path", SETTINGS_TEST)
	_settings.set("graphics_mode", "")
	_settings.set("sound_profile", "auto")
	_settings.set("sound_profile_chosen", false)
	_settings.set("gfx_preset", "")
	_settings.set("gfx_custom", {})
	_settings.set("race_music", true)
	_settings.set("race_music_chosen", false)
	(_gf.get("attract") as Node).set("enabled", false)
	_gf.call("boot")
	await _frames(10)
	_gf.call("go", "options", {}, true)
	await _frames(8)
	var screen := _screen()
	var tabs := "Seite %d, Fokus %s"
	_check("start", int(screen.get("tab")) == 0 and _focus_label() == "Gesamtlautstärke"
		and not _focusable(screen.get("race_music_row")),
		(tabs % [int(screen.get("tab")), _focus_label()]) + ", Musik im Rennen wählbar %s" % _focusable(screen.get("race_music_row")))
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	var rows: Dictionary = screen.get("quality_rows")
	_check("rb_grafik", int(screen.get("tab")) == 1 and _focus_label() == "Grafik" and not _focusable(screen.get("gfx_preset"))
		and not _focusable(rows.get("shadows")),
		(tabs % [int(screen.get("tab")), _focus_label()]) + ", Qualität wählbar %s" % _focusable(screen.get("gfx_preset")))
	# no choice yet (Arcade): ▶ chooses Modern – "Klang: Wie Grafik" follows
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	_check("modern", str(_settings.get("graphics_mode")) == "modern" and str(_settings.call("sound")) == "modern"
		and str(_settings.get("sound_profile")) == "auto" and _focusable(rows.get("shadows")),
		"Grafik %s, Klang %s (%s), Qualität wählbar %s" % [_settings.get("graphics_mode"), _settings.call("sound"),
			_settings.get("sound_profile"), _focusable(rows.get("shadows"))])
	await _taps(JOY_BUTTON_DPAD_DOWN, 2)
	_check("modern_zeilen", _focus_label() == "Voreinstellung", "Fokus " + _focus_label())
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var before := str((_settings.call("stored_quality") as Dictionary)["preset"])
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	var q: Dictionary = _settings.call("stored_quality")
	_check("eigene", _focus_label() == "Schatten" and str(_settings.get("gfx_preset")) == "custom" and int(q["shadows"]) == 3,
		"Fokus %s, Voreinstellung %s -> %s, %s" % [_focus_label(), before, _settings.get("gfx_preset"), JSON.stringify(q)])
	await _taps(JOY_BUTTON_DPAD_UP, 3)
	_check("zurueck_oben", _focus_label() == "Grafik", "Fokus " + _focus_label())
	# back to Arcade: the quality rows are skipped – ▼▼ from "Grafik" is "Vollbild", then "Leistungstest"
	await _tap(JOY_BUTTON_DPAD_LEFT)
	await _taps(JOY_BUTTON_DPAD_DOWN, 2)
	_check("arcade_springt", str(_settings.get("graphics_mode")) == "arcade" and _focus_label() == "Leistungstest"
		and str(_settings.call("sound")) == "arcade",
		"Grafik %s, Fokus %s, Klang %s" % [_settings.get("graphics_mode"), _focus_label(), _settings.call("sound")])
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check("lb_allgemein", int(screen.get("tab")) == 0 and _focus_label() == "Gesamtlautstärke",
		tabs % [int(screen.get("tab")), _focus_label()])
	# "Klang": Wie Grafik -> Arcade -> Modern; then "Musik im Rennen" can be reached and switched off
	await _taps(JOY_BUTTON_DPAD_DOWN, 3)
	var on_klang := _focus_label()
	await _taps(JOY_BUTTON_DPAD_RIGHT, 2)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	var on_music := _focus_label()
	await _tap(JOY_BUTTON_DPAD_LEFT)
	_check("klang_musik", on_klang == "Klang" and str(_settings.get("sound_profile")) == "modern"
		and str(_settings.call("sound")) == "modern" and on_music == "Musik im Rennen" and not bool(_settings.get("race_music")),
		"Fokus %s -> %s, Klang %s, Musik im Rennen %s" % [on_klang, on_music, _settings.get("sound_profile"), _settings.get("race_music")])
	await _tap(JOY_BUTTON_B)
	await _frames(4)
	var d: Dictionary = JsonFile.load_dict(SETTINGS_TEST)
	_check("gespeichert", str(_gf.call("current_screen_name")) == "title" and str(d.get("graphics_mode", "")) == "arcade"
		and int(d.get("settings_version", 0)) == 3 and str(d.get("gfx_preset", "")) == "custom"
		and str(d.get("sound_profile", "")) == "modern" and d.get("race_music", true) == false,
		"%s, %s" % [_gf.call("current_screen_name"), JSON.stringify(d)])
	_settings.set("file_path", old_path)
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SETTINGS_TEST + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST + suffix))
	print("CHECKS %s  (%d von %d bestanden, %d s)" % ["OK" if _failed.is_empty() else "FEHLER", _n - _failed.size(), _n,
		(Time.get_ticks_msec() - _t0) / 1000])
	quit(0 if _failed.is_empty() else 1)
