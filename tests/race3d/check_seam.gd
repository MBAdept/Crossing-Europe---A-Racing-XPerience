extends SceneTree
## Seam between the race session and the two renderers (v0.8.0, docs/dev/v080_contract.md §4.4.2), checked in the
## real race scene, headless:
##   godot --headless --path . -s res://tests/race3d/check_seam.gd [-- --only=ablauf,marker]
## tools/run_tests.sh runs it through its generic hook (tests/race3d/check_*.gd). The Modern renderer is replaced by
## a probe (tests/race3d/fixtures/seam_probe_renderer.gd) that takes a set number of frames to prepare, can fail and
## records what the session does with it – so these checks hold whatever the real renderer becomes.
##   ablauf      Modern: the crash-guard marker exists before the renderer is created; setup, apply_quality, prepare
##               in this order; the window is filled; loading overlay on canvas layer 6; until is_prepared() no
##               simulation step, no countdown, no HUD timer, no HUD state, no sound hook – but the start view is
##               drawn; afterwards the stage starts as an Arcade stage does. Context of prepare(), quality levels,
##               the view keys of v0.8.0 (hour, dt, player.type), result gfx. Only the HUD icons are loaded as
##               sprite sheets – no vehicle, prop or landmark sheet (first scenario: nothing is cached yet).
##   marker      the marker stays while the stage is prepared and for the first 2 s of frames, then it is removed
##   abgang      a stage that ends before those 2 s takes its marker along; one that never got past the preparation
##               leaves it (the next start is Arcade)
##   rueckfall   the renderer fails in the middle of the preparation: Arcade renderer and sprites, HUD message,
##               16:9 window, result gfx = "arcade" + gfx_fallback, marker removed, nothing ran before the start
##   ohne_renderer  the Modern renderer cannot be created: the stage is an Arcade stage from the start
##   klang       the sound hooks of contract §4.7.2 in an Arcade stage: set_track, stage_start, countdown 3-2-1, go,
##               set_vehicle_state with exactly the 18 keys every frame, collision, rail_hit, the events of fuel and
##               police, stage_finish, set_track(null, null) at the end
##   startmarker a marker found at the start of the game: the stored choice Modern runs as Arcade (reason
##               "crash_guard") until the guard is lifted
## Prints "CHECK <name> OK|FEHLER …" per check; exit code 0 when all pass.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const PROBE := "res://tests/race3d/fixtures/seam_probe_renderer.gd"
const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["ablauf", "marker", "abgang", "rueckfall", "ohne_renderer", "klang", "startmarker"]
const FALLBACK_TEXT := "Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten. Das Spiel läuft im Modus „Arcade“ weiter."
const STATE_KEYS := ["brake", "crash", "finished", "hour", "in_tunnel", "lat_speed", "off_road", "rail_contact", "road_left",
	"road_right", "shoulder_m", "speed", "steer", "throttle", "understeer", "weather", "x", "z"]

var _failed: Array[String] = []
var _probe: GDScript
var _renderers: GDScript
var _settings: Node
var _sprites: Node
var _marker := ""
var _flow_scene: Node
var _wall0 := 0


## Records the sound hooks of a session (race_session.audio_hooks).
class HookRecorder extends RefCounted:
	var tracks: Array = []
	var states: Array = []
	var events: Array = []

	func set_track(track: Object, plan: Object) -> void:
		tracks.append([track, plan])

	func set_vehicle_state(state: Dictionary) -> void:
		states.append(state)

	func event(event_name: String, args: Dictionary = {}) -> void:
		events.append([event_name, args])

	func names() -> Array[String]:
		var out: Array[String] = []
		for e: Array in events:
			out.append(str(e[0]))
		return out

	func args_of(event_name: String) -> Dictionary:
		for e: Array in events:
			if str(e[0]) == event_name:
				return e[1]
		return {}


func _initialize() -> void:
	var ts := 20.0
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)
	Engine.max_physics_steps_per_frame = 64
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	_settings = root.get_node("Settings")
	_sprites = root.get_node("SpriteDB")
	_marker = str(_settings.get("marker_path"))
	_probe.set("marker_path", _marker)
	_settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var cli_graphics: Variant = cli.get("graphics", null)
	cli.erase("graphics")   # these checks choose the mode themselves
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	if _flow_scene != null and is_instance_valid(_flow_scene):
		await _free(_flow_scene)
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))
	_settings.call("disarm_crash_guard")
	if cli_graphics != null:
		cli["graphics"] = cli_graphics
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-14s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _use_probe(prepare_frames: int, fail_at_frame: int = -1, fail_text: String = "shader") -> void:
	_renderers.set("modern_script", PROBE)
	_probe.call("reset")
	_probe.set("prepare_frames", prepare_frames)
	_probe.set("fail_at_frame", fail_at_frame)
	_probe.set("fail_text", fail_text)


func _launch(extra: Dictionary, hooks: Object = null) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 3.0, "autopilot": false, "seed": 3}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	if hooks != null:
		sc.set("audio_hooks", hooks)
	root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP   # GameFlow does this between stages


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits until `cond` is true (checked every frame), at most `max_frames`. Returns the frames waited.
func _until(cond: Callable, max_frames: int = 4000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _renderer_file(sc: Node) -> String:
	var r: Variant = sc.get("renderer")
	if r == null or not (r is Object) or (r as Object).get_script() == null:
		return ""
	return str(((r as Object).get_script() as Script).resource_path).get_file()


## The loading overlay of the session: its canvas layer (6) with a LoadingOverlay inside, or null.
func _loading_layer(sc: Node) -> CanvasLayer:
	for c in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 6 and not c.is_queued_for_deletion():
			for k in c.get_children():
				if k.get_script() != null and str((k.get_script() as Script).resource_path).get_file() == "loading_overlay.gd":
					return c
	return null


func _hud_texts(sc: Node) -> Array[String]:
	var out: Array[String] = []
	var hud: Object = sc.get("hud")
	for m: Dictionary in hud.get("_messages"):
		out.append(str(m["text"]))
	return out


func _probe_log() -> Array[String]:
	var out: Array[String] = []
	for e: String in _probe.get("log"):
		out.append(e)
	return out


func _marker_exists() -> bool:
	return FileAccess.file_exists(_marker)


# --- ablauf: the session flow of Modern ------------------------------------------------------------------------------

func _check_ablauf() -> void:
	var p: Array[String] = []
	_use_probe(8)
	var loads0 := int(_sprites.get("loads"))
	var rec := HookRecorder.new()
	# rain: a weather hint is in the HUD from the start (its timer must stand while the stage is prepared)
	var sc := _launch({"gfx": "modern", "weather": "rain", "autopilot": true}, rec)
	_flow_scene = sc
	_need(p, bool(_probe.get("marker_at_init")), "Marker vor dem Erzeugen des Renderers")
	_need(p, _marker_exists(), "Marker nach dem Aufbau")
	_need(p, " ".join(_probe_log()) == "init setup apply_quality prepare", "Reihenfolge init, setup, apply_quality, prepare (ist: %s)" % " ".join(_probe_log()))
	_need(p, str(sc.get("gfx")) == "modern" and _renderer_file(sc) == "seam_probe_renderer.gd", "Modern-Renderer aktiv")
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Fenster wird gefüllt (expand)")
	_need(p, _loading_layer(sc) != null, "Ladebild auf Ebene 6")
	_need(p, sc.get_child(0) == sc.get("renderer"), "Renderer ist das erste Kind")
	var hud: Object = sc.get("hud")
	var msgs: Array = hud.get("_messages")
	var hint_t0 := float((msgs[0] as Dictionary)["t"]) if not msgs.is_empty() else -1.0
	_need(p, hint_t0 > 0.0, "Wetterhinweis steht im HUD")
	var countdown0 := float(sc.get("countdown"))
	var frames := 0
	var worst_steps := 0
	var hud_moved := false
	var hud_state := false
	var clock_moved := false
	var hooks_early := 0
	var overlay_gone_early := false
	while not _probe_log().has("prepared") and frames < 300:
		await process_frame
		frames += 1
		if _probe_log().has("prepared"):
			break   # this frame ended the preparation
		worst_steps = maxi(worst_steps, int(sc.get("_sim_steps")))
		msgs = hud.get("_messages")
		hud_moved = hud_moved or msgs.is_empty() or not is_equal_approx(float((msgs[0] as Dictionary)["t"]), hint_t0)
		hud_state = hud_state or not (hud.get("state") as Dictionary).is_empty()
		clock_moved = clock_moved or not is_equal_approx(float(sc.get("countdown")), countdown0) or float(sc.get("_real_time")) != 0.0 \
			or float(sc.get("stage_time")) != 0.0 or float(sc.get("_beacon_t")) != 0.0
		hooks_early = maxi(hooks_early, rec.states.size() + rec.events.size())
		overlay_gone_early = overlay_gone_early or _loading_layer(sc) == null
	_need(p, frames >= 8, "Vorbereitung über mehrere Bilder (%d)" % frames)
	_need(p, worst_steps == 0, "kein Simulationsschritt vor is_prepared() (%d)" % worst_steps)
	_need(p, not clock_moved, "Countdown, Etappenzeit und Uhren stehen")
	_need(p, not hud_moved, "HUD-Meldungen altern nicht")
	_need(p, not hud_state, "HUD bekommt keinen Zustand (kein Countdown-Piep)")
	_need(p, hooks_early == 0, "keine Klang-Hooks vor dem Start (%d)" % hooks_early)
	_need(p, not overlay_gone_early, "Ladebild bleibt bis zum Start")
	var before := int(_probe.get("views_before_prepared"))
	_need(p, before >= 7, "die Startansicht wird während der Vorbereitung gezeichnet (%d Bilder)" % before)
	# the stage starts with the next simulation step
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 200)
	_need(p, int(sc.get("_sim_steps")) > 0, "die Simulation startet nach der Vorbereitung")
	_need(p, _loading_layer(sc) == null, "Ladebild weg")
	_need(p, (hud as Node).is_processing(), "HUD läuft")
	_need(p, not rec.events.is_empty() and str(rec.events[0][0]) == "stage_start"
		and is_equal_approx(float((rec.events[0][1] as Dictionary).get("countdown_s", -1.0)), countdown0), "Klang-Ereignis stage_start zuerst")
	await _until(func() -> bool: return bool(sc.get("running")) and float(sc.get("stage_time")) > 1.0)
	_need(p, " ".join(rec.names()).begins_with("stage_start countdown countdown countdown go"), "Countdown 3-2-1-go (ist: %s)" % " ".join(rec.names()))
	_need(p, not rec.states.is_empty(), "set_vehicle_state läuft")
	# what the renderer got
	var ctx: Dictionary = _probe.get("ctx_seen")
	var sets: Array = ctx.get("sets", [])
	var traffic_sets := sets.filter(func(s: String) -> bool: return s.begins_with("traffic/"))
	_need(p, sets.has("player/limousine") and traffic_sets.size() >= 10 and sets.has("ui/weather_rain") and sets.size() > 40,
		"prepare(ctx.sets): Spieler, Verkehr, Icons, Requisiten (%d Sets)" % sets.size())
	_need(p, ctx.get("plan", null) is StagePlan and str(ctx.get("vehicle", "")) == "limousine" and str(ctx.get("weather", "")) == "rain"
		and is_equal_approx(float(ctx.get("hour", -1.0)), 12.0) and ctx.get("sync", null) == false, "prepare(ctx): plan, vehicle, weather, hour, sync")
	var lv: Dictionary = _probe.get("levels_seen")
	_need(p, lv.has("preset") and lv.has("msaa") and lv.has("shadow_atlas") and lv.has("scale_3d") and lv.has("omni_pool"), "apply_quality(levels)")
	var view: Dictionary = _probe.get("last_view")
	var player: Dictionary = view.get("player", {})
	_need(p, view.get("hour", null) is float and view.get("dt", null) is float and float(view.get("dt", 0.0)) > 0.0
		and str(player.get("type", "")) == "limousine", "Ansicht mit hour, dt, player.type")
	for k: String in ["camera_z", "camera_x", "camera_y", "camera_in_tunnel", "visibility_m", "palette", "weather", "time", "speed", "cars",
			"player", "bg_offset", "scenery", "shake", "countdown", "chase01", "radar_flash01"]:
		_need(p, view.has(k), "Ansicht behält " + k)
	var res: Dictionary = sc.call("build_result")
	_need(p, str(res.get("gfx", "")) == "modern" and not res.has("gfx_fallback"), "Ergebnis gfx = modern")
	# sprite sheets: only the HUD icons
	var log: Array = _sprites.get("load_log")
	var loaded := int(_sprites.get("loads")) - loads0
	var foreign := log.filter(func(id: String) -> bool: return not id.begins_with("ui/"))
	var pre: Array = sc.get("preloaded_sets")
	_need(p, loaded > 0 and foreign.is_empty(), "nur HUD-Icons als Sprite-Blätter geladen (fremd: %s)" % str(foreign))
	_need(p, not pre.is_empty() and pre.filter(func(id: String) -> bool: return not id.begins_with("ui/")).is_empty(), "preloaded_sets nur ui/*")
	await _until(func() -> bool: return float(sc.get("stage_time")) > 6.0)
	_need(p, int(_sprites.get("loads")) - loads0 == loaded, "auch während der Fahrt kein Sprite-Blatt nachgeladen")
	_report("ablauf", p, "Modern mit Prüf-Renderer: %d Bilder Vorbereitung ohne Simulationsschritt, %d Startansichten gezeichnet, %d Sets an prepare(), %d Sprite-Blätter geladen (nur ui/*)" % [
		frames, before, sets.size(), loaded])


# --- marker: removed after 2 s of frames ------------------------------------------------------------------------------

func _check_marker() -> void:
	var p: Array[String] = []
	var sc := _flow_scene
	if sc == null or not is_instance_valid(sc):
		_use_probe(3)
		sc = _launch({"gfx": "modern", "autopilot": true, "no_countdown": true})
		_flow_scene = sc
		await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 200)
	# the flow check took well under a second of real time since the stage started
	var guard := float(sc.get("_guard_s"))
	_need(p, guard > 0.0 and guard <= 2.0 and _marker_exists(), "Marker steht nach dem Start noch (Rest %.2f s)" % guard)
	var t0 := Time.get_ticks_msec()
	var gone_at := -1
	while Time.get_ticks_msec() - t0 < 4000 and gone_at < 0:
		await process_frame
		if not _marker_exists():
			gone_at = Time.get_ticks_msec() - t0
	_need(p, gone_at >= 0, "Marker nach 2 s gezeichneter Bilder entfernt")
	_need(p, gone_at < 0 or float(gone_at) / 1000.0 >= guard - 0.3, "nicht zu früh (nach %.2f s bei Rest %.2f s)" % [float(gone_at) / 1000.0, guard])
	_need(p, float(sc.get("_guard_s")) <= 0.0, "Zähler abgelaufen")
	_report("marker", p, "Marker %.2f s nach dem Start noch da, %.2f s später entfernt" % [2.0 - guard, float(gone_at) / 1000.0])
	await _free(sc)
	_flow_scene = null


# --- abgang: the stage ends early -------------------------------------------------------------------------------------

func _check_abgang() -> void:
	var p: Array[String] = []
	# a) started, then left within the 2 s: an orderly end – the marker goes along
	_use_probe(3)
	var sc := _launch({"gfx": "modern", "autopilot": true, "no_countdown": true})
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 200)
	_need(p, _marker_exists() and float(sc.get("_guard_s")) > 1.0, "a) Marker steht kurz nach dem Start")
	await _free(sc)
	_need(p, not _marker_exists(), "a) früh, aber ordentlich beendet: Marker entfernt")
	_need(p, _probe_log().has("exit"), "a) Renderer mit der Szene freigegeben")
	# b) left while the renderer was still preparing (the player closed a game that hung): the marker stays
	_use_probe(1000000)
	sc = _launch({"gfx": "modern", "autopilot": true})
	await _frames(5)
	_need(p, int(sc.get("_sim_steps")) == 0 and _marker_exists(), "b) noch in der Vorbereitung")
	await _free(sc)
	var stays := _marker_exists()
	_need(p, stays, "b) nie gestartet: Marker bleibt für den nächsten Start")
	_settings.call("disarm_crash_guard")
	_report("abgang", p, "nach dem Start früh beendet: Marker weg; in der Vorbereitung beendet: Marker %s" % ("bleibt" if stays else "FEHLT"))


# --- rueckfall: the renderer fails while preparing --------------------------------------------------------------------------

func _check_rueckfall() -> void:
	var p: Array[String] = []
	_use_probe(50, 4, "shader")
	var loads0 := int(_sprites.get("loads"))
	var rec := HookRecorder.new()
	var sc := _launch({"gfx": "modern", "autopilot": true}, rec)
	var hud: Object = sc.get("hud")
	_need(p, _renderer_file(sc) == "seam_probe_renderer.gd" and _marker_exists(), "beginnt in Modern mit Marker")
	var frames := 0
	var ran_before := 0
	while str(sc.get("gfx_fallback")) == "" and frames < 200:
		ran_before = maxi(ran_before, int(sc.get("_sim_steps")) + rec.events.size() + rec.states.size())
		await process_frame
		frames += 1
	_need(p, frames >= 3 and frames < 20, "Ausfall mitten in der Vorbereitung (Bild %d)" % frames)
	_need(p, ran_before == 0, "bis dahin lief nichts (%d)" % ran_before)
	_need(p, _renderer_file(sc) == "road_renderer.gd" and sc.get_child(0) == sc.get("renderer"), "Arcade-Renderer an erster Stelle")
	_need(p, _probe_log().has("exit") and int(_probe.get("instances")) == 1, "Modern-Renderer freigegeben")
	_need(p, str(sc.get("gfx")) == "arcade" and str(sc.get("gfx_fallback")) == "shader", "gfx arcade, gfx_fallback shader")
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Fenster wieder 16:9")
	_need(p, _hud_texts(sc).has(FALLBACK_TEXT), "Meldung im HUD")
	_need(p, not _marker_exists(), "Marker entfernt (kein Absturz)")
	var pre: Array = sc.get("preloaded_sets")
	var loaded := int(_sprites.get("loads")) - loads0
	_need(p, pre.has("player/limousine") and pre.size() > 40 and loaded > 20, "Arcade-Sprites jetzt geladen (%d Sets, %d Blätter)" % [pre.size(), loaded])
	await _until(func() -> bool: return bool(sc.get("running")) and float(sc.get("stage_time")) > 1.0)
	_need(p, bool(sc.get("running")) and (hud as Node).is_processing() and _loading_layer(sc) == null, "die Etappe läuft in Arcade")
	_need(p, " ".join(rec.names()).begins_with("stage_start countdown countdown countdown go"), "Countdown erst nach dem Rückfall")
	var res: Dictionary = sc.call("build_result")
	_need(p, str(res.get("gfx", "")) == "arcade" and str(res.get("gfx_fallback", "")) == "shader", "Ergebnis gfx = arcade, gfx_fallback = shader")
	_need(p, float(sc.get("_guard_s")) <= 0.0, "kein Marker-Zähler in Arcade")
	_report("rueckfall", p, "Ausfall in Bild %d der Vorbereitung: weiter mit %s, %d Sprite-Sets, Meldung im HUD, Ergebnis gfx_fallback '%s'" % [
		frames, _renderer_file(sc), pre.size(), str(res.get("gfx_fallback", ""))])
	await _free(sc)


# --- ohne_renderer: the Modern renderer cannot be created -------------------------------------------------------------------

func _check_ohne_renderer() -> void:
	var p: Array[String] = []
	_renderers.set("modern_script", "res://tests/race3d/fixtures/gibt_es_nicht.gd")
	var sc := _launch({"gfx": "modern", "autopilot": true, "no_countdown": true})
	_need(p, _renderer_file(sc) == "road_renderer.gd" and str(sc.get("gfx")) == "arcade" and str(sc.get("gfx_fallback")) == "renderer", "Arcade von Anfang an, gfx_fallback renderer")
	_need(p, int(sc.get("_gfx_state")) == 0 and _loading_layer(sc) == null, "kein Ladebild, sofort startklar")
	_need(p, _hud_texts(sc).has(FALLBACK_TEXT), "Meldung im HUD")
	_need(p, not _marker_exists(), "Marker entfernt")
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Fenster 16:9")
	_need(p, (sc.get("preloaded_sets") as Array).has("player/limousine"), "Arcade-Sprites geladen")
	await _until(func() -> bool: return float(sc.get("stage_time")) > 1.0, 400)
	_need(p, float(sc.get("stage_time")) > 1.0, "die Etappe läuft")
	_report("ohne_renderer", p, "Modern-Skript fehlt: %s, gfx_fallback '%s'" % [_renderer_file(sc), str(sc.get("gfx_fallback"))])
	await _free(sc)
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))


# --- klang: sound hooks -------------------------------------------------------------------------------------------------

func _check_klang() -> void:
	var p: Array[String] = []
	var rec := HookRecorder.new()
	var sc := _launch({"gfx": "arcade"}, rec)
	var track: Object = sc.get("track")
	var plan: Object = sc.get("plan")
	_need(p, rec.tracks.size() == 1 and rec.tracks[0][0] == track and rec.tracks[0][1] == plan, "set_track(track, plan) beim Aufbau")
	_need(p, rec.events.is_empty(), "vor dem ersten Schritt kein Ereignis")
	await _until(func() -> bool: return bool(sc.get("running")))
	var names := " ".join(rec.names())
	_need(p, names == "stage_start countdown countdown countdown go", "stage_start, countdown ×3, go (ist: %s)" % names)
	var counts: Array = []
	for e: Array in rec.events:
		if str(e[0]) == "countdown":
			counts.append(int((e[1] as Dictionary).get("n", 0)))
	_need(p, counts == [3, 2, 1], "countdown n = 3, 2, 1 (ist %s)" % str(counts))
	_need(p, is_equal_approx(float(rec.args_of("stage_start").get("countdown_s", 0.0)), 3.0), "stage_start countdown_s 3")
	# the state of the car, every frame
	await _frames(3)
	var n0 := rec.states.size()
	await _frames(10)
	_need(p, rec.states.size() - n0 == 10, "set_vehicle_state in jedem Bild (%d in 10 Bildern)" % (rec.states.size() - n0))
	var st: Dictionary = rec.states[-1]
	var keys: Array = st.keys()
	keys.sort()
	_need(p, keys == STATE_KEYS, "set_vehicle_state mit genau den 18 Schlüsseln (ist %s)" % str(keys))
	var edges: Vector2 = track.call("road_edges_at", float(sc.get("pos_z")))
	_need(p, is_equal_approx(float(st["road_left"]), edges.x) and is_equal_approx(float(st["road_right"]), edges.y)
		and float(st["shoulder_m"]) > 0.0 and st["in_tunnel"] is bool and str(st["weather"]) == "normal" and absf(float(st["hour"]) - 12.0) < 0.1
		and st["crash"] == false and st["finished"] == false and int(st["off_road"]) == 0 and is_equal_approx(float(st["z"]), float(sc.get("pos_z")))
		and is_equal_approx(float(st["speed"]), 0.0), "Werte des Zustands (ist %s)" % str(st))
	# a rear-end collision with a car straight ahead
	var v: VehicleModel = sc.get("vehicle")
	var traffic: TrafficSystem = sc.get("traffic")
	var z := float(sc.get("pos_z"))
	v.x = track.call("lane_center_x", z, 1)
	v.speed = 150.0
	traffic.cars.clear()
	var c := TrafficSystem.Car.new()
	c.id = 4711
	c.z = z + 30.0
	c.x = v.x + 0.01
	c.lane = 1
	c.speed = 60.0
	c.cruise_speed = 60.0
	c.set_id = "traffic/sedan_blue"
	c.lane_cooldown = 1000.0
	c.lane_timer = 1000.0
	traffic.cars.append(c)
	var only_ours := func() -> bool:   # the spawner keeps adding traffic far ahead
		for k in traffic.cars.duplicate():
			if k != c:
				traffic.cars.erase(k)
		return rec.names().has("collision")
	await _until(only_ours, 3000)
	var hit := rec.args_of("collision")
	_need(p, hit.has("speed_kmh") and float(hit.get("speed_kmh", 0.0)) > 100.0 and hit.get("heavy", null) == false and int(hit.get("side", 9)) == 0
		and float(hit.get("rel_kmh", 0.0)) > 40.0, "collision {speed_kmh, heavy, side} (ist %s)" % str(hit))
	# a slide into the left guardrail
	await _until(func() -> bool: return v.state == VehicleModel.State.DRIVING, 3000)
	sc.set("traffic_enabled", false)
	traffic.cars.clear()
	var e2: Vector2 = track.call("road_edges_at", float(sc.get("pos_z")))
	v.speed = 200.0
	v.x = e2.x - float(track.get("shoulder_w")) + v.width_m * 0.5 + 0.05
	v.push_speed = -6.0
	await _until(func() -> bool: return rec.names().has("rail_hit"), 2000)
	var rail := rec.args_of("rail_hit")
	_need(p, float(rail.get("impact_mps", 0.0)) > 1.0 and int(rail.get("side", 0)) == -1, "rail_hit {impact_mps, side −1} (ist %s)" % str(rail))
	# fuel and police: the wiring of their signals
	var fuel: Object = sc.get("fuel")
	var police: Object = sc.get("police")
	fuel.emit_signal("refuel_started")
	fuel.emit_signal("refuel_finished", 12.5, false)
	fuel.emit_signal("ran_dry")
	fuel.emit_signal("tow_started")
	police.emit_signal("flashed", {}, 150.0)
	police.emit_signal("chase_started")
	police.emit_signal("escaped")
	police.emit_signal("caught")
	for want: String in ["refuel_start", "refuel_done", "out_of_fuel", "tow", "radar_flash", "chase_start", "escaped", "busted"]:
		_need(p, rec.names().count(want) == 1, "Ereignis " + want)
	_need(p, is_equal_approx(float(rec.args_of("refuel_done").get("liters", 0.0)), 12.5), "refuel_done {liters}")
	await _free(sc)
	_need(p, rec.tracks.size() == 2 and rec.tracks[1][0] == null and rec.tracks[1][1] == null, "set_track(null, null) am Ende")
	# the finish, in a Modern stage (the hooks do not depend on the graphics mode)
	_use_probe(2)
	var rec2 := HookRecorder.new()
	var sc2 := _launch({"gfx": "modern", "start_km": 129.4, "autopilot": true, "no_countdown": true, "start_speed_kmh": 150.0, "last_stage": true}, rec2)
	await _until(func() -> bool: return bool(sc2.get("finished")), 6000)
	var fin := rec2.args_of("stage_finish")
	_need(p, bool(sc2.get("finished")) and fin.get("record", null) is bool and fin.get("last_stage", null) == true, "stage_finish {record, last_stage} (ist %s)" % str(fin))
	_need(p, rec2.names().has("stage_start") and not rec2.states.is_empty(), "Hooks auch in Modern")
	await _frames(2)
	_need(p, (rec2.states[-1] as Dictionary).get("finished", false) == true, "Zustand finished nach dem Ziel")
	await _free(sc2)
	_report("klang", p, "Klang-Hooks: %d Ereignisse (%s), %d Zustände mit 18 Schlüsseln" % [rec.events.size(), " ".join(rec.names()), rec.states.size()])


# --- startmarker: the marker of the last run ---------------------------------------------------------------------------------

func _check_startmarker() -> void:
	var p: Array[String] = []
	_use_probe(2)
	var chosen_before := str(_settings.get("graphics_mode"))
	_settings.call("arm_crash_guard")     # the last run died in Modern …
	_settings.call("_ready")               # … and this is the next start of the game
	_settings.set("graphics_mode", "modern")
	_need(p, bool(_settings.get("crash_guard")), "Marker beim Start gefunden")
	var eff: Dictionary = _settings.call("effective_graphics")
	_need(p, str(eff.get("mode", "")) == "arcade" and str(eff.get("reason", "")) == "crash_guard", "gewähltes Modern läuft als Arcade (crash_guard)")
	_need(p, str(_settings.call("sound")) == "modern", "der Klang folgt weiter der Wahl")
	var sc := _launch({"autopilot": true, "no_countdown": true})
	_need(p, str(sc.get("gfx")) == "arcade" and _renderer_file(sc) == "road_renderer.gd", "die Etappe startet in Arcade")
	_need(p, _marker_exists(), "der Marker bleibt bis zur Antwort")
	await _free(sc)
	_settings.call("disarm_crash_guard")   # the player's answer on the title: try Modern again
	eff = _settings.call("effective_graphics")
	_need(p, str(eff.get("mode", "")) == "modern" and str(eff.get("reason", "")) == "" and not _marker_exists(), "danach wieder Modern")
	sc = _launch({"autopilot": true, "no_countdown": true})
	_need(p, str(sc.get("gfx")) == "modern", "die nächste Etappe startet in Modern")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) > 0, 200)
	await _free(sc)
	_settings.set("graphics_mode", chosen_before)
	_settings.call("disarm_crash_guard")
	_report("startmarker", p, "Marker des letzten Laufs: Arcade mit Grund crash_guard, nach dem Aufheben wieder Modern")
