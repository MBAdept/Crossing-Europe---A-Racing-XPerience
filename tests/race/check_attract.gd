extends SceneTree
## Attract mode end to end in the real game (GameFlow, title screen, AttractMode, race scene):
##   godot --headless --path . -s res://tests/race/check_attract.gd
##   (under Xvfb without --headless the title music plays on the Dummy driver and its continuity is measured)
## Shortened times (idle 1 s, demo 4 s, fades 0.2 s); events go through the root viewport (push_input), the same
## path as keys, gamepad buttons and clicks. Checks:
##   idle        the demo starts idle_s after the last input on the title (an input restarts the timer)
##   demo        real race scene with the autopilot, reduced HUD, overlay, race aspect "keep"; effect buses muted,
##               Music bus untouched, the title music stays on
##   dauer       after demo_s it returns to the title by itself; buses back to their states, menus "expand"
##   naechste    the next demo shows the next scene
##   taste       Enter ends the demo at once; its echo and release, and the guard time, trigger no menu action
##               (still the title, no question box, race flow untouched); afterwards ▼ moves the focus again
##   gamepad     Gamepad A ends the demo without a menu action
##   klick       a mouse click ends the demo without a menu action
##   ziel        a stage that finishes inside the demo ends it – the result reaches no one
##   keine_daten savegame, leaderboards and settings files unchanged (existence, size, time, MD5); no new
##               leaderboard entry or board in memory; settings values unchanged; GameFlow's race state untouched
##   musik       the title music never stopped (headless: it stayed requested; with audio: playing throughout,
##               playback position only moving forwards or wrapping at the loop end)
## Prints "CHECK <name> OK|FEHLER …"; exit code 0 when all pass. Autoloads are accessed untyped (this script
## compiles before they exist).

const STATE_IDLE := 0
const STATE_DEMO := 2
const FILES := ["user://savegame.json", "user://leaderboards.json", "user://settings.json"]

var _gf: Node
var _am: Node
var _audio: Node
var _failed: Array[String] = []
var _clock := 0.0
var _music: Array = []           ## [time, playing, position, wanted] per frame since the title is up
var _sample_music := false
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(delta: float) -> bool:
	_clock += delta
	if _audio != null and _sample_music:
		var p := _music_player()
		var playing := false
		var pos := -1.0
		if p != null:
			playing = p.playing
			pos = p.get_playback_position()
		# the request flag is AudioManager-internal: a music source without it counts as requested
		var wanted: Variant = _audio.get("_music_wanted")
		_music.append([_clock, playing, pos, true if wanted == null else bool(wanted)])
	if (Time.get_ticks_msec() - _wall0) / 1000.0 > 240.0:
		print("FEHLER: Zeitlimit")
		quit(2)
	return false


# --- helpers --------------------------------------------------------------------------------------

## The player of the title music: AudioManager's `_music`, else its first player on the Music bus (whatever the
## music source is called).
func _music_player() -> AudioStreamPlayer:
	var p: Variant = _audio.get("_music")
	if p is AudioStreamPlayer and is_instance_valid(p):
		return p
	for c in _audio.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == "Music":
			return c
	return null


func _check(name: String, ok: bool, msg: String = "") -> void:
	print("CHECK %-12s %s  %s" % [name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(name)


func _state() -> int:
	return int(_am.get("state"))


func _wait(s: float) -> void:
	var t0 := _clock
	while _clock - t0 < s:
		await process_frame


func _wait_state(st: int, timeout_s: float) -> bool:
	var t0 := _clock
	while _state() != st:
		if _clock - t0 > timeout_s:
			return false
		await process_frame
	return true


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	root.push_input(e)


func _pad(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	root.push_input(e)


func _click(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	root.push_input(e)


func _screen() -> Node:
	var shell: Variant = _gf.get("shell")
	if shell == null or not is_instance_valid(shell):
		return null
	return (shell as Control).get("current_screen")


func _title_ok() -> bool:
	var s := _screen()
	return str(_gf.call("current_screen_name")) == "title" and s != null and not bool(s.call("has_modal"))


func _bus_mutes() -> Dictionary:
	var d := {}
	for i in AudioServer.bus_count:
		d[AudioServer.get_bus_name(i)] = AudioServer.is_bus_mute(i)
	return d


func _files() -> Dictionary:
	var d := {}
	for f: String in FILES:
		for p in [f, f + ".bak", f + ".tmp"]:
			if FileAccess.file_exists(p):
				d[p] = [FileAccess.get_file_as_bytes(p).size(), FileAccess.get_modified_time(p), FileAccess.get_md5(p)]
			else:
				d[p] = null
	return d


## Board keys in memory: the demo's race session seeds its board on reading the record – forgotten after the demo.
func _board_keys() -> Array:
	var keys: Array = (root.get_node("Leaderboards").get("boards") as Dictionary).keys()
	keys.sort()
	return keys


func _settings() -> Dictionary:
	var s := root.get_node("Settings")
	var d := {}
	for k in ["master_volume", "sfx_volume", "music_volume", "fullscreen", "player_name", "language", "leaderboard_filter"]:
		d[k] = s.get(k)
	return d


## Leaderboard entries a player made (not the generated default entries) – in memory.
func _own_entries() -> int:
	var n := 0
	var boards: Dictionary = root.get_node("Leaderboards").get("boards")
	for k in boards:
		for e in boards[k]:
			if not bool((e as Dictionary).get("seeded", false)):
				n += 1
	return n


func _flow_state() -> Array:
	return [_gf.get("race"), str(_gf.get("mode")), (_gf.get("last_result") as Dictionary).duplicate(true),
		(_gf.get("last_setup") as Dictionary).duplicate(true)]


# --- the run -------------------------------------------------------------------------------------

func _run() -> void:
	_gf = root.get_node_or_null("GameFlow")
	_audio = root.get_node_or_null("AudioManager")
	if _gf == null or _gf.get("attract") == null:
		print("FEHLER: GameFlow/AttractMode fehlt")
		quit(1)
		return
	_am = _gf.get("attract")
	var files0 := _files()
	var settings0 := _settings()
	var entries0 := _own_entries()
	var keys0 := _board_keys()
	var flow0 := _flow_state()
	var mutes0 := _bus_mutes()
	var scenes: Array = _am.get("scenes")
	_am.set("idle_s", 1.0)
	_am.set("demo_s", 4.0)
	_am.set("fade_s", 0.2)
	_am.set("guard_s", 0.4)
	_am.set("scene_index", 0)
	_gf.call("boot")
	await _wait(0.5)
	_check("titel", _title_ok(), "Titelbildschirm")
	_sample_music = true

	# idle timer: an input after 0.5 s restarts it
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	var t_input := _clock
	await _wait(0.8)
	var early := _state() != STATE_IDLE
	var ok := await _wait_state(1, 4.0)
	var waited := _clock - t_input
	_check("idle", ok and not early and waited >= 0.95 and waited <= 1.35, "Demo %.2f s nach der letzten Eingabe (idle_s 1)" % waited)

	# the demo
	ok = await _wait_state(STATE_DEMO, 8.0)
	var t_demo := _clock
	var race: Variant = _gf.get("current")
	var has_race: bool = ok and race != null and is_instance_valid(race) and race.get("plan") != null
	var hud: Variant = race.get("hud") if has_race else null
	var muted_ok := true
	for n: String in (_am.call("effect_bus_names") as Array):
		muted_ok = muted_ok and AudioServer.is_bus_mute(AudioServer.get_bus_index(n))
	var music_idx := AudioServer.get_bus_index("Music")
	var music_bus_ok := music_idx < 0 or AudioServer.is_bus_mute(music_idx) == bool(mutes0.get("Music", false))
	var first := str((_am.get("current_scene") as Dictionary).get("id", ""))
	await _wait(1.0)
	var speed := float(race.get("vehicle").get("speed")) if has_race else 0.0
	_check("demo", has_race and race.get("autopilot") != null and hud != null and bool(hud.get("reduced"))
		and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and speed > 20.0,
		"Szene %s, Autopilot %.0f km/h, HUD reduziert, Seitenverhältnis keep" % [first, speed])
	_check("busse", muted_ok and music_bus_ok and (_am.call("effect_bus_names") as Array).size() >= 2,
		"Effekt-Busse stumm %s, Music unverändert" % str((_am.call("effect_bus_names") as Array)))

	# ends by itself after demo_s
	ok = await _wait_state(STATE_IDLE, 8.0)
	var dur := _clock - t_demo
	# from here a longer idle time: the input checks after each return (≈1 s) must stay clear of the next demo's
	# start even at a low frame rate (a key pressed while the next demo fades in would cancel that start instead)
	_am.set("idle_s", 2.5)
	# the effect buses come back once their reverb/delay tails have died away (at most AttractMode.UNMUTE_MAX_S)
	await _wait(1.3)
	_check("dauer", ok and dur >= 3.95 and dur <= 4.6 and str(_am.get("last_end_reason")) == "time" and _title_ok()
		and _bus_mutes() == mutes0 and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,
		"%.2f s (demo_s 4 + Überblendung), zurück im Titel, Busse wie vorher" % dur)

	# next demo: next scene; Enter ends it without a menu action
	ok = await _wait_state(STATE_DEMO, 8.0)
	var second := str((_am.get("current_scene") as Dictionary).get("id", ""))
	_check("naechste", ok and scenes.size() > 1 and second == str((scenes[1] as Dictionary).get("id", "")) and second != first,
		"%s nach %s" % [second, first])
	await _wait(0.8)
	var flow_before := _flow_state()
	_key(KEY_ENTER, true)
	await process_frame
	await process_frame
	var ended := _state() == STATE_IDLE and str(_am.get("last_end_reason")) == "input"
	_key(KEY_ENTER, true, true)     # held: echo
	await _wait(0.2)
	_key(KEY_ENTER, false)
	await _wait(0.6)
	var focus0 := root.gui_get_focus_owner()
	var default_focus: Variant = _screen().get("default_focus") if _screen() != null else null
	_check("taste", ended and _title_ok() and _flow_state() == flow_before and focus0 != null and focus0 == default_focus,
		"Enter beendet sofort, Echo/Loslassen ohne Wirkung, Fokus auf %s" % (str((focus0 as Button).text) if focus0 is Button else "–"))
	_key(KEY_DOWN, true)
	_key(KEY_DOWN, false)
	await process_frame
	await process_frame
	var focus1 := root.gui_get_focus_owner()
	_check("menue", focus1 != null and focus1 != focus0 and _title_ok(), "▼ bewegt den Fokus wieder")
	_key(KEY_UP, true)
	_key(KEY_UP, false)

	# gamepad A ends the next demo
	ok = await _wait_state(STATE_DEMO, 8.0)
	await _wait(0.5)
	_pad(JOY_BUTTON_A, true)
	await process_frame
	await process_frame
	ended = _state() == STATE_IDLE and str(_am.get("last_end_reason")) == "input"
	_pad(JOY_BUTTON_A, false)
	await _wait(0.6)
	_check("gamepad", ok and ended and _title_ok() and _flow_state() == flow_before, "Gamepad A beendet die Demo, kein Menüpunkt")

	# a mouse click ends the next one (pressed where "Rennen starten" sits on the title)
	ok = await _wait_state(STATE_DEMO, 8.0)
	await _wait(0.5)
	var at := Vector2(1040, 300)
	_click(at, true)
	await process_frame
	await process_frame
	ended = _state() == STATE_IDLE and str(_am.get("last_end_reason")) == "input"
	_click(at, false)
	await _wait(0.6)
	_check("klick", ok and ended and _title_ok() and _flow_state() == flow_before, "Klick beendet die Demo, kein Menüpunkt")

	# a stage that finishes inside the demo: its result reaches no one
	var finish_scene := {"id": "test_ziel", "name": "Test", "stage": "kiel_hamburg", "from": "kiel", "km": 94.5,
		"hour": 12.0, "weather": "normal", "vehicle": "kompakt", "speed_kmh": 110, "cruise_kmh": 110, "seed": 1}
	var with_finish: Array[Dictionary] = []
	for s in scenes:
		with_finish.append(s)
	with_finish.append(finish_scene)
	_am.set("scenes", with_finish)
	_am.set("scene_index", with_finish.size() - 1)
	_am.set("demo_s", 14.0)
	ok = await _wait_state(STATE_DEMO, 8.0)
	ok = ok and await _wait_state(STATE_IDLE, 16.0)
	await _wait(1.3)   # effect buses back after their tails (AttractMode.UNMUTE_MAX_S)
	_check("ziel", ok and str(_am.get("last_end_reason")) == "finished" and _title_ok() and _flow_state() == flow0,
		"Ziel in der Demo: Ende %s, kein Ergebnis" % str(_am.get("last_end_reason")))
	_am.set("enabled", false)

	# nothing written
	_check("keine_daten", _files() == files0 and _settings() == settings0 and _own_entries() == entries0
		and _board_keys() == keys0 and _flow_state() == flow0 and _bus_mutes() == mutes0,
		"Spielstand, Bestenlisten (Dateien und Speicher: %d Listen), Einstellungen unverändert" % keys0.size())
	_check_music()
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


## The title music never stopped: requested all the time; with an audio driver also playing all the time and its
## position never jumping back (except wrapping at the end of the loop).
func _check_music() -> void:
	var wanted := true
	var playing_from := -1
	var stopped := 0
	var jumps := 0
	var prev := -1.0
	for i in _music.size():
		var m: Array = _music[i]
		wanted = wanted and bool(m[3])
		if bool(m[1]):
			if playing_from < 0:
				playing_from = i
			var pos := float(m[2])
			if prev >= 0.0 and pos < prev - 0.05:
				var p := _music_player()
				var length := p.stream.get_length() if p != null and p.stream != null else 0.0
				if length <= 0.0 or prev < length - 1.0:
					jumps += 1   # back to an earlier position, not the loop wrap
			prev = pos
		elif playing_from >= 0:
			stopped += 1
	if playing_from < 0:
		_check("musik", wanted, "ohne Audioausgabe (headless): Titelmusik blieb angefordert")
	else:
		_check("musik", wanted and stopped == 0 and jumps == 0,
			"lief durchgehend (%d Frames, %d Aussetzer, %d Sprünge zurück)" % [_music.size() - playing_from, stopped, jumps])
