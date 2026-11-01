class_name AttractMode
extends Node
## Attract mode (arcade demo), a child of GameFlow. After `idle_s` seconds (config attract.idle_s, 60) without any
## input on the title screen a demo of `demo_s` seconds (30) starts: the real race scene, driven by the autopilot,
## in one of the curated scenes of attract.scenes (stage, start km, hour, weather, car, speed), in turn – the next
## demo shows the next scene. The title music keeps playing; every effect bus (SFX, Room, Engine, Siren,
## TrafficV<n>) is muted for the demo and restored afterwards (the Music bus is never touched). An overlay shows the
## logo, "DEMO" with the scene's name and a blinking "Taste drücken"; the HUD is reduced to clock and speedometer.
## Any key, gamepad button, clear stick push, mouse click or touch ends the demo at once and returns to the title
## WITHOUT triggering a menu action: the event is consumed here (before the GUI sees it), and that key/button stays
## swallowed until it is released (plus a short guard time, `guard_s`). After demo_s it fades back by itself; the
## idle timer then starts again. Nothing is saved: the demo scene is not connected to GameFlow's race flow (no
## savegame, leaderboard or settings writes; the race session itself writes nothing).
## Timers count frame time without Engine.time_scale (real seconds; video seconds in a Movie Maker recording).
## Debug CLI: --attract-after=<s> (idle time), --attract-scene=<index|id> (first scene), --attract-demo-s=<s>,
## --attract-press=<s> (recordings: a key press – Enter, through the viewport like a player's – s seconds into the
## first demo), --no-attract.

signal demo_started(scene: Dictionary)
signal demo_ended(reason: String)

enum State { IDLE, STARTING, DEMO, ENDING }

## Buses muted during the demo (with every bus whose name starts with TRAFFIC_BUS_PREFIX); never "Music".
const EFFECT_BUSES: Array[String] = ["SFX", "Room", "Engine", "Siren"]
const TRAFFIC_BUS_PREFIX := "TrafficV"
## Stick/trigger deflection that ends the demo (as InputMode.AXIS_THRESHOLD: resting noise does not count).
const WAKE_AXIS := 0.5
const OVERLAY_LAYER := 60

var enabled := true
var idle_s := 60.0
var demo_s := 30.0
var fade_s := 0.6
var guard_s := 0.4
var scenes: Array[Dictionary] = []
var scene_index := 0                 ## scene of the next demo
var state := State.IDLE
var current_scene: Dictionary = {}
var race_scene: Node = null          ## the running demo's race scene
var demos_shown := 0
var last_end_reason := ""
## Clock in seconds (frame time without Engine.time_scale); tests replace it.
var clock: Callable
## Is the title screen showing and free (no question box)? Tests replace it.
var title_check: Callable

var _clock_s := 0.0
var _last_activity := 0.0
var _demo_t0 := 0.0
var _guard_until := -1.0
var _swallow: Dictionary = {}        ## keys/buttons pressed during the demo: swallowed until released
var _saved_mutes: Dictionary = {}    ## bus name -> mute state before the demo
var _boards_before: Dictionary = {}  ## leaderboard boards in memory before the demo (key -> true)
var _boards_taken := false           ## _boards_before holds the snapshot of the running demo
var _layer: CanvasLayer
var _overlay: AttractOverlay
var _fade: ColorRect
var _tween: Tween
var _press_at := -1.0                ## debug --attract-press: seconds into the first demo (-1 = off)


func _init() -> void:
	clock = func() -> float: return _clock_s
	title_check = _title_ready


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	configure(_config())
	_last_activity = now()


## Reads config attract.* and the debug command line.
func configure(cfg: Dictionary) -> void:
	var a: Variant = ConfigLoader.lookup(cfg, "attract", {})
	var ac: Dictionary = a if a is Dictionary else {}
	enabled = bool(ac.get("enabled", true)) and not CliArgs.has("no-attract")
	idle_s = maxf(0.1, float(ac.get("idle_s", 60.0)))
	demo_s = maxf(1.0, float(ac.get("demo_s", 30.0)))
	fade_s = clampf(float(ac.get("fade_s", 0.6)), 0.0, 3.0)
	guard_s = clampf(float(ac.get("guard_s", 0.4)), 0.0, 3.0)
	scenes = parse_scenes(ac.get("scenes", []))
	if CliArgs.has("attract-after"):
		idle_s = maxf(0.1, CliArgs.get_float("attract-after", idle_s))
	if CliArgs.has("attract-demo-s"):
		demo_s = maxf(1.0, CliArgs.get_float("attract-demo-s", demo_s))
	scene_index = scene_index_for(scenes, CliArgs.get_string("attract-scene", "0"))
	_press_at = CliArgs.get_float("attract-press", -1.0)


func now() -> float:
	return float(clock.call())


## Usable scenes of the configuration (entries with a stage).
static func parse_scenes(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for s in raw:
			if s is Dictionary and str((s as Dictionary).get("stage", "")) != "":
				out.append(s)
	return out


## Index of a scene given as a number (0-based) or by its id; 0 if unknown.
static func scene_index_for(list: Array[Dictionary], key: String) -> int:
	if list.is_empty():
		return 0
	if key.is_valid_int():
		return posmod(key.to_int(), list.size())
	for i in list.size():
		if str(list[i].get("id", "")) == key:
			return i
	return 0


## Race session setup of a demo scene (ARCHITECTURE.md §8 plus the debug keys the session reads from `setup`).
static func scene_setup(scene: Dictionary, cfg: Dictionary) -> Dictionary:
	return {
		"mode": "demo",
		"demo": true,
		"race_id": "",
		"stage_id": str(scene.get("stage", "")),
		"from_city": str(scene.get("from", "")),
		"vehicle": str(scene.get("vehicle", ConfigLoader.lookup(cfg, "vehicles.default", "limousine"))),
		"start_world_minutes": float(scene.get("hour", 12.0)) * 60.0,
		"weather": str(scene.get("weather", "normal")),
		"start_km": float(scene.get("km", 0.0)),
		"autopilot": true,
		"autopilot_target": float(scene.get("cruise_kmh", 180.0)),
		"autopilot_speeding": false,
		"autopilot_refuel": "never",
		"no_countdown": true,
		"traffic_warmup": true,
		"seed": int(scene.get("seed", 0)),
	}


# --- input -----------------------------------------------------------------------------------

## Input that ends the demo: a key press (not an echo), a gamepad button, a clear stick/trigger push, a mouse
## button or a touch.
static func is_wake_event(e: InputEvent) -> bool:
	if e is InputEventKey:
		return (e as InputEventKey).pressed and not (e as InputEventKey).echo
	if e is InputEventJoypadButton:
		return (e as InputEventJoypadButton).pressed
	if e is InputEventJoypadMotion:
		return absf((e as InputEventJoypadMotion).axis_value) >= WAKE_AXIS
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).pressed
	if e is InputEventScreenTouch:
		return (e as InputEventScreenTouch).pressed
	return false


## Input that restarts the idle timer on the title: everything that ends a demo, releases, mouse movement, drags.
static func is_activity_event(e: InputEvent) -> bool:
	if is_wake_event(e):
		return true
	if e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton or e is InputEventScreenTouch:
		return true
	if e is InputEventMouseMotion:
		return (e as InputEventMouseMotion).relative.length() >= 1.0
	return e is InputEventScreenDrag


## Identity of a key/button/axis event for swallowing until release ("" = none). A stick or trigger counts as
## pressed while it is pushed at least WAKE_AXIS (a stick that woke the demo keeps sending motion events).
static func _button_key(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		return "k%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if e is InputEventJoypadButton:
		return "j%d" % (e as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion:
		return "a%d" % (e as InputEventJoypadMotion).axis
	if e is InputEventMouseButton:
		return "m%d" % (e as InputEventMouseButton).button_index
	if e is InputEventScreenTouch:
		return "t%d" % (e as InputEventScreenTouch).index
	return ""


static func _is_pressed(e: InputEvent) -> bool:
	if e is InputEventJoypadMotion:
		return absf((e as InputEventJoypadMotion).axis_value) >= WAKE_AXIS
	return e.is_pressed()


func _input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


## The input logic; returns true if the event is consumed (the GUI and the race scene never see it).
func handle_input(event: InputEvent) -> bool:
	var t := now()
	var key := _button_key(event)
	if state == State.IDLE:
		if key != "" and _swallow.has(key):
			if not _is_pressed(event):
				_swallow.erase(key)
			return true
		if key != "" and t < _guard_until:
			if _is_pressed(event):
				_swallow[key] = true
			return true
		if is_activity_event(event):
			_last_activity = t
		return false
	# STARTING, DEMO, ENDING: nothing reaches the menus or the race scene
	if key != "":
		if _is_pressed(event):
			_swallow[key] = true
		else:
			_swallow.erase(key)
	if is_wake_event(event):
		InputMode.note(event)   # the device that woke the game shows its hints on the title
		if state == State.STARTING:
			_cancel_start()
		elif state == State.DEMO:
			finish("input")
	return true


# --- idle timer --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# frame time without Engine.time_scale: real seconds for the player (a test running the game at 40x does
	# not shorten the minute), video seconds in a Movie Maker recording (fixed fps), and when frames lag the
	# demo still shows 30 s of driving
	_clock_s += delta / maxf(Engine.time_scale, 0.0001)
	var t := now()
	match state:
		State.IDLE:
			if idle_due(t, bool(title_check.call())):
				begin()
		State.DEMO:
			_keep_muted()
			if _press_at >= 0.0 and t - _demo_t0 >= _press_at and is_inside_tree():
				_press_at = -1.0
				_press_key()
			elif t - _demo_t0 >= demo_s:
				finish("time")
			elif _overlay != null:
				_overlay.progress = clampf((t - _demo_t0) / demo_s, 0.0, 1.0)


## Debug (--attract-press): Enter pressed and released, pushed through the viewport like a player's key.
func _press_key() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = KEY_ENTER
		e.keycode = KEY_ENTER
		e.pressed = pressed
		get_viewport().push_input(e)


## True when the demo is due: the title has been showing (and free) for idle_s without input. While it is not
## showing the timer stays at zero, so it starts counting when the title appears.
func idle_due(t: float, title_shown: bool) -> bool:
	if not enabled or scenes.is_empty() or not title_shown:
		_last_activity = t
		return false
	return t - _last_activity >= idle_s


func _title_ready() -> bool:
	var gf := get_parent()
	if gf == null or not gf.has_method("current_screen_name") or not is_inside_tree() or get_tree().paused:
		return false
	if str(gf.call("current_screen_name")) != "title":
		return false
	var shell: Variant = gf.get("shell")
	if shell == null or not is_instance_valid(shell) or gf.get("current") != shell:
		return false
	var screen: Variant = (shell as Node).get("current_screen")
	if screen == null or not is_instance_valid(screen):
		return false
	return not (screen.has_method("has_modal") and bool(screen.call("has_modal")))


# --- demo lifecycle ------------------------------------------------------------------------------

## Starts the demo of the next scene: fade to black, then the race scene.
func begin() -> void:
	if state != State.IDLE or scenes.is_empty():
		return
	current_scene = scenes[scene_index % scenes.size()]
	state = State.STARTING
	_ensure_layer()
	_fade_to(1.0, fade_s, _launch)


func _launch() -> void:
	if state != State.STARTING:
		return
	var gf := get_parent()
	var setup := scene_setup(current_scene, _config())
	mute_effects()
	_stop_audio()
	_boards_before = {}
	var boards: Variant = _leaderboard_boards()
	_boards_taken = boards is Dictionary
	if _boards_taken:
		for k in boards:
			_boards_before[k] = true
	race_scene = gf.call("start_attract_stage", setup) if gf != null and gf.has_method("start_attract_stage") else null
	state = State.DEMO
	_demo_t0 = now()
	demos_shown += 1
	if race_scene == null or race_scene.get("plan") == null:
		push_warning("Attract-Modus: Szene %s nicht ladbar" % str(current_scene.get("id", scene_index)))
		finish("error")
		return
	_prepare_scene(race_scene, current_scene)
	_show_overlay()
	demo_started.emit(current_scene)
	_fade_to(0.0, fade_s)


## Start speed, lane, reduced HUD; the demo's own signals end it (the race flow never sees them).
func _prepare_scene(scene: Node, sc: Dictionary) -> void:
	var v: Object = scene.get("vehicle")
	var track: Object = scene.get("track")
	if v != null:
		v.set("speed", clampf(float(sc.get("speed_kmh", sc.get("cruise_kmh", 120.0))), 0.0, 300.0))
		if sc.has("lane") and track != null:
			var z := float(scene.get("pos_z"))
			var lanes := int(track.call("lane_count_at", z))
			var x := float(track.call("lane_center_x", z, clampi(int(sc["lane"]), 0, maxi(lanes - 1, 0))))
			v.set("x", x)
			scene.set("cam_x", x)
	var hud: Object = scene.get("hud")
	if hud != null:
		hud.set("reduced", true)
	for c in scene.get_children():
		if c is Screenshotter:
			c.queue_free()   # a --screenshot run is captured by GameFlow's screenshotter, not a second one
	scene.connect("stage_finished", func(_r: Dictionary) -> void: finish("finished"))
	scene.connect("stage_aborted", func(_r: String) -> void: finish("aborted"))


## Ends the demo. "input": at once (cut to the title, which fades in); otherwise fade to black first.
func finish(reason: String) -> void:
	if state == State.STARTING:
		_cancel_start()
		return
	if state != State.DEMO:
		return
	state = State.ENDING
	last_end_reason = reason
	if reason == "input" or reason == "error":
		# black at once; the scene switch runs after the input/physics callbacks of this frame
		_set_fade(1.0)
		var back := func() -> void:
			_return_to_title()
			_fade_to(0.0, minf(fade_s, 0.3))
		if is_inside_tree():
			back.call_deferred()
		else:
			back.call()   # unit tests drive the state machine without a scene tree
	else:
		_fade_to(1.0, fade_s, func() -> void:
			_return_to_title()
			_fade_to(0.0, fade_s))


func _cancel_start() -> void:
	state = State.IDLE
	_last_activity = now()
	_guard_until = now() + guard_s
	_fade_to(0.0, 0.2)


func _return_to_title() -> void:
	if race_scene != null and is_instance_valid(race_scene):
		race_scene.process_mode = Node.PROCESS_MODE_DISABLED   # no more audio calls from the scene
	_stop_audio()
	_hide_overlay()
	race_scene = null
	var gf := get_parent()
	if gf != null and gf.has_method("show_title"):
		gf.call("show_title")
	_forget_demo_boards()
	restore_effects()
	state = State.IDLE
	_last_activity = now()
	_guard_until = now() + guard_s
	if not scenes.is_empty():
		scene_index = (scene_index + 1) % scenes.size()
	demo_ended.emit(last_end_reason)


func is_running() -> bool:
	return state != State.IDLE


## The leaderboards in memory (autoload Leaderboards: board key -> entries), null without it.
func _leaderboard_boards() -> Variant:
	var ml := Engine.get_main_loop()
	var lb: Node = (ml as SceneTree).root.get_node_or_null("Leaderboards") if ml is SceneTree else null
	var b: Variant = lb.get("boards") if lb != null else null
	return b if b is Dictionary else null


## The race session reads the record of its board, which seeds a board never written before with generated default
## entries (in memory only). Boards only the demo created are forgotten again, so a later save of the leaderboards
## writes nothing the demo touched.
func _forget_demo_boards() -> void:
	var boards: Variant = _leaderboard_boards()
	if not boards is Dictionary or not _boards_taken:
		return
	_boards_taken = false
	for k in (boards as Dictionary).keys():
		if _boards_before.has(k):
			continue
		var seeded_only := true
		for e in (boards as Dictionary)[k]:
			seeded_only = seeded_only and e is Dictionary and bool((e as Dictionary).get("seeded", false))
		if seeded_only:
			(boards as Dictionary).erase(k)
	_boards_before = {}


## The game's configuration (autoload Config; tests and tools without it read the files). Autoloads are reached
## through the tree, so tools that compile before the autoloads exist can use this class.
func _config() -> Dictionary:
	var ml := Engine.get_main_loop()
	var c: Node = (ml as SceneTree).root.get_node_or_null("Config") if ml is SceneTree else null
	var d: Variant = c.get("data") if c != null else null
	return d if d is Dictionary else ConfigLoader.load_merged()


## AudioManager.stop_all(): engine, loops, one-shots and traffic voices silent at once (the music plays on).
func _stop_audio() -> void:
	var ml := Engine.get_main_loop()
	var am: Node = (ml as SceneTree).root.get_node_or_null("AudioManager") if ml is SceneTree else null
	if am != null and am.has_method("stop_all"):
		am.call("stop_all")


# --- audio buses -------------------------------------------------------------------------------

## Names of the effect buses that exist right now (SFX, Room, Engine, Siren, TrafficV<n>).
static func effect_bus_names() -> Array[String]:
	var out: Array[String] = []
	for i in AudioServer.bus_count:
		var n := AudioServer.get_bus_name(i)
		if EFFECT_BUSES.has(n) or n.begins_with(TRAFFIC_BUS_PREFIX):
			out.append(n)
	return out


## Mutes every effect bus and remembers its previous state (a second call keeps the first states).
func mute_effects() -> void:
	if not _saved_mutes.is_empty():
		return
	for n in effect_bus_names():
		var i := AudioServer.get_bus_index(n)
		_saved_mutes[n] = AudioServer.is_bus_mute(i)
		AudioServer.set_bus_mute(i, true)


## Puts every muted bus back to its state before the demo (a bus muted by the player's volume stays muted).
func restore_effects() -> void:
	for n: String in _saved_mutes:
		var i := AudioServer.get_bus_index(n)
		if i >= 0:
			AudioServer.set_bus_mute(i, bool(_saved_mutes[n]))
	_saved_mutes.clear()


## During the demo the effect buses stay muted even if something re-applies the volumes.
func _keep_muted() -> void:
	for n: String in _saved_mutes:
		var i := AudioServer.get_bus_index(n)
		if i >= 0 and not AudioServer.is_bus_mute(i):
			AudioServer.set_bus_mute(i, true)


# --- overlay and fades -----------------------------------------------------------------------

func _ensure_layer() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = OVERLAY_LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)


func _show_overlay() -> void:
	_ensure_layer()
	_hide_overlay()
	_overlay = AttractOverlay.new()
	_overlay.scene_name = str(current_scene.get("name", ""))
	_layer.add_child(_overlay)
	_layer.move_child(_fade, -1)   # the fade stays on top


func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _set_fade(a: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_ensure_layer()
	_fade.color.a = a


func _fade_to(a: float, duration: float, then: Callable = Callable()) -> void:
	_ensure_layer()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		_fade.color.a = a
		if then.is_valid():
			then.call()
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_fade, "color:a", a, duration)
	if then.is_valid():
		_tween.tween_callback(then)
