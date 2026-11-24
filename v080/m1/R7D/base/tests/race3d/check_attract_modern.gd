extends SceneTree
## v0.8.0 (UI1): an attract demo in the graphics mode "Modern" whose renderer needs time to prepare the stage
## (headless, ~10 s), through the generic hook of tools/run_tests.sh:
##   godot --headless --path . -s res://tests/race3d/check_attract_modern.gd
## The demo's race scene gets the test renderer of the seam (tests/race3d/fixtures/seam_probe_renderer.gd, through
## RaceRenderers.modern_script) with a preparation of PREPARE_FRAMES frames. Checks: the demo runs in the effective
## mode (Modern, no setup.gfx of its own) and fills the window ("expand"); while the stage prepares the picture stays
## black, the demo's clock and its progress line stand; the demo_s count from RaceSession.stage_live – not from the
## start of the scene – and the demo ends by time; back on the title the menus have their aspect again.
## Prints "CHECK <name> OK|FEHLER" lines; exit code 1 on a failure. Autoload and session classes are reached at
## run time (a -s script compiles before the autoloads exist).

const PROBE := "res://tests/race3d/fixtures/seam_probe_renderer.gd"
const RENDERERS := "res://scripts/race/race_renderers.gd"
const PREPARE_FRAMES := 150
const DEMO_S := 2.0
const STATE_IDLE := 0
const STATE_DEMO := 2

var _gf: Node
var _am: Node
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


func _state() -> int:
	return int(_am.get("state"))


func _wait_for(cond: Callable, max_ms: int) -> bool:
	var t := Time.get_ticks_msec()
	while not bool(cond.call()) and Time.get_ticks_msec() - t < max_ms:
		await process_frame
	return bool(cond.call())


func _run() -> void:
	_gf = root.get_node_or_null("GameFlow")
	_am = _gf.get("attract")
	var settings := root.get_node_or_null("Settings")
	var renderers := load(RENDERERS) as GDScript
	var probe := load(PROBE) as GDScript
	var mode_before := str(settings.get("graphics_mode"))
	settings.set("graphics_mode", "modern")
	renderers.set("modern_script", PROBE)
	probe.call("reset")
	probe.set("marker_path", str(settings.get("marker_path")))
	probe.set("prepare_frames", PREPARE_FRAMES)
	probe.set("fail_at_frame", -1)
	_am.set("idle_s", 0.5)
	_am.set("demo_s", DEMO_S)
	_am.set("fade_s", 0.1)
	_am.set("guard_s", 0.2)
	_am.set("scene_index", 0)
	_gf.call("boot")
	var started := await _wait_for(func() -> bool: return _state() == STATE_DEMO and _gf.get("current") != null \
		and is_instance_valid(_gf.get("current")) and (_gf.get("current") as Node).has_method(&"is_live"), 15000)
	var race: Node = _gf.get("current")
	# while the stage prepares: black, the clock of the demo stands, no progress
	await process_frame
	await process_frame
	var fade: ColorRect = _am.get("_fade")
	var preparing := started and not bool(race.call(&"is_live"))
	var black := fade != null and fade.color.a >= 0.99
	var live_flag := bool(_am.get("_demo_live"))
	var overlay: Variant = _am.get("_overlay")
	var progress0 := float((overlay as Node).get("progress")) if overlay is Node and is_instance_valid(overlay) else -1.0
	_check("vorbereitung", preparing and black and not live_flag and progress0 <= 0.0,
		"Etappe bereitet vor %s, Bild schwarz %s, Demo läuft %s, Fortschritt %.2f" % [preparing, black, live_flag, progress0])
	_check("modus", started and str(race.get("gfx")) == "modern" and not (race.get("setup") as Dictionary).has("gfx")
		and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,
		"Modus %s (setup.gfx %s), Seitenverhältnis %s" % [race.get("gfx") if started else "-",
			(race.get("setup") as Dictionary).get("gfx", "–") if started else "-",
			"expand" if root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND else "keep"])
	# live: the demo's clock starts now
	var live := await _wait_for(func() -> bool: return bool(race.call(&"is_live")), 20000)
	await process_frame
	var launch_t := float(_am.get("_launch_t"))
	var demo_t0 := float(_am.get("_demo_t0"))
	var prep_s := demo_t0 - launch_t
	var ended := await _wait_for(func() -> bool: return _state() == STATE_IDLE, 20000)
	var end_t := float(_am.call("now"))
	var demo_len := end_t - demo_t0
	_check("ab_start", live and ended and prep_s > 0.0 and str(_am.get("last_end_reason")) == "time"
		and demo_len >= DEMO_S - 0.05 and demo_len <= DEMO_S + 0.5 and end_t - launch_t >= DEMO_S + prep_s - 0.05,
		"Vorbereitung %.2f s, Demo ab dem Start der Etappe %.2f s (demo_s %.1f), ab dem Szenenstart %.2f s, Ende %s" % [
			prep_s, demo_len, DEMO_S, end_t - launch_t, _am.get("last_end_reason")])
	await _wait_for(func() -> bool: return str(_gf.call("current_screen_name")) == "title", 5000)
	_check("titel", str(_gf.call("current_screen_name")) == "title" and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,
		"zurück im Titel, Menüs mit „expand“")
	_am.set("enabled", false)
	renderers.set("modern_script", renderers.get("MODERN_SCRIPT"))
	settings.set("graphics_mode", mode_before)
	print("CHECKS %s  (%d von %d bestanden, %d s)" % ["OK" if _failed.is_empty() else "FEHLER", _n - _failed.size(), _n,
		(Time.get_ticks_msec() - _t0) / 1000])
	quit(0 if _failed.is_empty() else 1)
