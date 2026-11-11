extends SceneTree
## Render checks of the seam between the race session and the Modern renderer (v0.8.0) – they need a real
## renderer and a fixed frame rate:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_seam_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   selbsttest    GfxSelfTest on this renderer: lit sphere, shader quad and background are judged as good
##   modern_bild   a Modern stage draws. (1) The renderer skeleton alone (the probe renderer in its bare mode: no
##                 layer, builder or rig file of the renderer packages): the sky gradient of the palette above the
##                 horizon row (through the canvas layer), below it the debug road – asphalt, edge lines and shoulder
##                 at the pixels the camera model predicts – and its terrain, the HUD on top; the Camera3D maps like
##                 ChaseCamera3D; render counters; the self-test and the warm-up frames ran before the start.
##                 (2) The shipped renderer with whatever content exists: sky above the horizon, ground below, no
##                 empty frame, camera = ChaseCamera3D, HUD on top
##   gleiche_zeit  the same stage in Arcade and in Modern with a Screenshotter: at the shot the simulation has made
##                 the same number of steps and stands at the same place (equal shot times = equal states) – for a
##                 scene that enters the tree between two frames and for one that enters after the physics callbacks
##                 of a frame, as GameFlow starts a stage at boot (--stage, the only start of an exported build)
##   rueckfall     a renderer that is not healthy(): the picture is the Arcade picture of the same moment, pixel for
##                 pixel below the message line
##   arcade_gleich Arcade frame, then a Modern stage, then the Arcade frame again in the same process: identical
##                 (Modern changes no project-wide render state)
##   fenster_16_10 a 16:10 window: Modern fills it (1280×800 logical, no bars; the skeleton alone with the horizon
##                 at 45 % of the window height, the shipped renderer without a black row), Arcade keeps 16:9 with bars
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/facade_probe_renderer.gd"
const CHECKS := ["selbsttest", "modern_bild", "gleiche_zeit", "rueckfall", "arcade_gleich", "fenster_16_10"]
const SHOT_PREFIX := "user://test_seam_render/shot"

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK seam_render FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var only := str(CliArgs.all().get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_use_skeleton(false)
	ModernMaterials.drop_shared()   # what leaving the mode "Modern" does: nothing of it is left at the exit
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-14s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


## Starts a stage the way the game does. Default: the scene enters the tree between two frames, so its first frame
## begins with a simulation step and then draws – as when the race scene is the main scene (tools/golden.sh,
## screenshots) and when a menu starts a stage.
## late: the scene enters the tree after the physics callbacks of a frame and before its drawing, so it is drawn once
## before its first simulation step – as when GameFlow starts a stage at boot ("-- --stage=…": boot.gd defers
## GameFlow.boot(), the message queue runs it after the physics callbacks of the first frame). An Arcade stage is
## then one step behind at every shot time; a Modern stage must be exactly as far (race_session._lead_s).
func _launch(extra: Dictionary, late: bool = false) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11, "traffic_warmup": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	if late:
		root.add_child.call_deferred(sc)   # runs after the physics callbacks of this frame
		await process_frame
	else:
		root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_frames: int = 2000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


## The picture of the window after the next drawn frame.
func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Runs the stage until exactly `steps` simulation steps are done and returns the picture of that state.
func _picture_at_step(sc: Node, steps: int) -> Image:
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= steps, 4000)
	return await _capture()


func _renderer_file(sc: Node) -> String:
	var r: Variant = sc.get("renderer")
	if r == null or not (r is Object) or (r as Object).get_script() == null:
		return ""
	return str(((r as Object).get_script() as Script).resource_path).get_file()


func _near(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


## Number of pixels that differ between two pictures inside `rect` (-1: different sizes).
func _diff_pixels(a: Image, b: Image, rect: Rect2i) -> int:
	if a.get_size() != b.get_size():
		return -1
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


# --- selbsttest --------------------------------------------------------------------------------------------------

func _check_selbsttest() -> void:
	var p: Array[String] = []
	var script: GDScript = load("res://scripts/core/gfx_self_test.gd")
	var first: Dictionary = await script.call("run", root)
	var second: Dictionary = await script.call("run", root)
	_need(p, bool(first.get("ok", false)) and str(first.get("reason", "x")) == "" and not first.has("skipped"), "erster Lauf gut (%s)" % str(first))
	_need(p, bool(second.get("ok", false)), "zweiter Lauf gut (%s)" % str(second))
	_need(p, float(first.get("lit", 0.0)) > 0.5 and float(first.get("dark", 1.0)) < 0.05, "Kugel beleuchtet, Hintergrund schwarz")
	_need(p, float(first.get("ms", 0.0)) > 0.0, "Dauer gemessen")
	# the node the test hangs on is freed in the middle of it (a stage left during its first frames): no verdict
	var holder := Node.new()
	root.add_child(holder)
	var cut := [{}]
	var runner := func() -> void:
		cut[0] = await script.call("run", holder, 6)
	runner.call()
	await _frames(2)
	holder.queue_free()
	await _frames(10)
	var cut_res: Dictionary = cut[0]
	_need(p, bool(cut_res.get("aborted", false)) and not bool(cut_res.get("ok", true)), "abgebrochener Selbsttest ohne Urteil (%s)" % str(cut_res))
	var third: Dictionary = await script.call("run", root)
	_need(p, bool(third.get("ok", false)), "danach wieder ein gültiger Lauf")
	_report("selbsttest", p, "Selbsttest %s: Kugel %.2f, Hintergrund %.2f, Shader-Fläche %s, %.0f ms beim ersten und %.0f ms beim zweiten Mal; abgebrochen ohne Urteil" % [
		"bestanden" if bool(first.get("ok", false)) else "NICHT bestanden", float(first.get("lit", 0.0)), float(first.get("dark", 0.0)),
		str(first.get("quad", "")), float(first.get("ms", 0.0)), float(second.get("ms", 0.0))])


# --- modern_bild -----------------------------------------------------------------------------------------------

## The skeleton alone: the probe renderer in its bare mode is the shipped renderer without any layer, builder or rig
## file of the renderer packages (tests/race3d/fixtures/facade_probe_renderer.gd).
func _use_skeleton(on: bool) -> void:
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	var probe: GDScript = load(PROBE)
	probe.call("reset")
	probe.set("bare", on)
	renderers.set("modern_script", PROBE if on else str(renderers.get("MODERN_SCRIPT")))


## Colour of the built-in sky (scripts/race3d/plain_sky.gd) at a row of a picture `height` rows high: Arcade's
## gradient above the horizon row (45 % of the height), the fog colour below.
func _sky_at(pal: Dictionary, row: float, height: float) -> Color:
	var hy := 0.45 * height
	var my := hy * 0.52
	if row >= hy:
		return pal["fog"]
	if row < my:
		return (pal["sky_top"] as Color).lerp(pal["sky_mid"], (row + 40.0) / (my + 40.0))
	return (pal["sky_mid"] as Color).lerp(pal["sky_bottom"], (row - my) / (hy + 3.0 - my))


func _greenish(c: Color) -> bool:
	return c.g > c.r + 0.05 and c.g > c.b + 0.05


## Mean colour of the picture inside `rect`, every 8th pixel.
func _mean(img: Image, rect: Rect2i) -> Color:
	var sum := Color(0.0, 0.0, 0.0)
	var n := 0
	for y in range(rect.position.y, rect.end.y, 8):
		for x in range(rect.position.x, rect.end.x, 8):
			var c := img.get_pixel(x, y)
			sum.r += c.r
			sum.g += c.g
			sum.b += c.b
			n += 1
	return Color(sum.r / float(n), sum.g / float(n), sum.b / float(n))


## Largest distance (px) between Camera3D.unproject_position() and the renderer's world_to_screen() for points on
## and beside the road: the camera of the picture is the ChaseCamera3D model.
func _camera_error(r: ModernRenderer) -> float:
	var cam_z := float(r.view["camera_z"])
	var worst := 0.0
	for d: float in [10.0, 60.0, 300.0]:
		for x: float in [-9.0, 0.0, 5.0]:
			var a := r.camera.unproject_position(r.road_to_world(cam_z + d, x, 0.3))
			var b := r.world_to_screen(cam_z + d, x, 0.3)
			worst = maxf(worst, Vector2(a.x - b.x, a.y - b.y).length())
	if not r.camera.global_transform.is_equal_approx(r.chase.transform(r.view, r.path)):
		worst = 999.0
	return worst


func _check_modern_bild() -> void:
	var p: Array[String] = []
	# 1. the skeleton alone (no file of the renderer packages): its picture is known exactly
	_use_skeleton(true)
	var sc: Node = await _launch({"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0})
	_need(p, _renderer_file(sc) == "facade_probe_renderer.gd" and sc.get("renderer") is ModernRenderer, "der Renderer als Gerüst allein")
	var waited: int = await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 30, 2000)
	var img: Image = await _capture()
	var r: ModernRenderer = sc.get("renderer")
	var pal: Dictionary = Palette.compute(12.0, "normal", ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	var w := img.get_width()
	var h := img.get_height()
	_need(p, w == 1280 and h == 720, "Bild 1280×720 (%d×%d)" % [w, h])
	# sky: the palette's gradient above the horizon row (45 % of the height = row 324), at places free of the HUD
	var sky_bad: Array[String] = []
	for at: Vector2i in [Vector2i(400, 40), Vector2i(400, 250), Vector2i(900, 250), Vector2i(400, 316), Vector2i(1000, 316)]:
		var got := img.get_pixel(at.x, at.y)
		var want := _sky_at(pal, float(at.y) + 0.5, 720.0)
		if not _near(got, want, 3.0 / 255.0):
			sky_bad.append("%s: %s statt %s" % [str(at), got.to_html(false), want.to_html(false)])
	_need(p, sky_bad.is_empty(), "Himmelsverlauf der Palette über der Horizontzeile (%s)" % "; ".join(sky_bad))
	# below it the debug road: asphalt, the two edge lines and the shoulder stand where the camera model says
	var view: Dictionary = r.view
	var cam_z := float(view["camera_z"])
	var track: Track = sc.get("track")
	var asphalt_a := Color(0.30, 0.31, 0.34)
	var asphalt_b := Color(0.33, 0.34, 0.37)
	var line := Color(0.92, 0.92, 0.88)
	var shoulder := Color(0.47, 0.46, 0.42)
	var paint_bad: Array[String] = []
	var probes := 0
	for d: float in [14.0, 20.0, 45.0]:
		var edges := track.road_edges_at(cam_z + d)
		for probe: Array in [[edges.x + 0.3, line, line, "linke Randlinie"], [edges.y - 0.3, line, line, "rechte Randlinie"],
				[0.0, asphalt_a, asphalt_b, "Asphalt"], [edges.y - 1.5, asphalt_a, asphalt_b, "Asphalt neben der Linie"],
				[edges.y + 1.25, shoulder, shoulder, "Bankett"]]:
			var px := r.world_to_screen(cam_z + d, float(probe[0]), 0.02)
			if px.x < 2.0 or px.x > 1277.0 or px.y > 580.0:
				continue   # outside the picture or under the HUD
			probes += 1
			var got := img.get_pixel(int(px.x), int(px.y))
			if px.z <= 0.0 or not (_near(got, probe[1], 4.0 / 255.0) or _near(got, probe[2], 4.0 / 255.0)):
				paint_bad.append("%s %d m voraus bei %d,%d: %s" % [str(probe[3]), int(d), int(px.x), int(px.y), got.to_html(false)])
	_need(p, paint_bad.is_empty() and probes >= 12, "Debug-Straße mit Markierung an den Bildpunkten der Kamera (%d Proben; %s)" % [probes, "; ".join(paint_bad)])
	var grass := img.get_pixel(400, 345)
	_need(p, _greenish(grass), "Gelände unter dem Horizont (%s)" % grass.to_html(false))
	# camera = ChaseCamera3D: the Camera3D of the picture maps as the camera model does
	var worst := _camera_error(r)
	_need(p, worst < 0.02, "Kamera = ChaseCamera3D (%.4f px)" % worst)
	# the HUD is drawn over the 3D picture: the speedometer's dark dial in the lower right corner
	var dial := img.get_pixel(1140, 660)
	_need(p, dial.get_luminance() < 0.2, "HUD über dem 3D-Bild (Tacho %s)" % dial.to_html(false))
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Seitenverhältnis expand")
	var snap := r.debug_snapshot()
	var cam: Dictionary = snap.get("camera", {})
	_need(p, cam.has("z") and cam.has("frustum") and (snap.get("chunks", []) as Array).size() >= 8 and (snap.get("quality", {}) as Dictionary).has("msaa"),
		"debug_snapshot mit Kamera, Stücken, Qualität")
	var skeleton_builders: Array = snap.get("builders", [])
	_need(p, (snap.get("layers", [0]) as Array).is_empty() and skeleton_builders.size() == 1 and str(skeleton_builders[0]) == "debug_road"
		and bool((snap.get("environment", {}) as Dictionary).get("plain", false)) and bool((snap.get("backdrop", {}) as Dictionary).get("plain", false)),
		"das Gerüst allein: Debug-Straße, eingebaute Umgebung, eingebauter Himmel (%s / %s)" % [str(snap.get("builders", [])), str(snap.get("layers", []))])
	var perf: Dictionary = sc.call("perf_stats")
	_need(p, str(perf.get("mode", "")) == "modern" and int(perf.get("sim_steps", 0)) >= 30, "perf_stats mode modern")
	_need(p, int(perf.get("draw_calls", 0)) >= 5 and int(perf.get("primitives", 0)) > 1000 and float(perf.get("tex_mem_mb", 0.0)) > 0.0,
		"Zähler des Renderers (%d Zeichenaufrufe, %d Dreiecke)" % [int(perf.get("draw_calls", 0)), int(perf.get("primitives", 0))])
	# the first Modern stage of this run: the self-test ran inside prepare(), the start view was drawn before the start
	var st: Dictionary = ModernRenderer.selftest
	_need(p, bool(st.get("ok", false)) and float(st.get("ms", 0.0)) > 0.0 and not st.has("skipped"), "Selbsttest in prepare() (%s)" % str(st))
	_need(p, float(perf.get("prewarm_ms", 0.0)) > 0.0 and float(perf.get("prepare_ms", 0.0)) >= float(perf.get("prewarm_ms", 0.0)),
		"Aufwärmbilder vor dem Start (%.0f ms von %.0f ms Vorbereitung)" % [float(perf.get("prewarm_ms", 0.0)), float(perf.get("prepare_ms", 0.0))])
	var skeleton_calls := int(perf.get("draw_calls", 0))
	var skeleton_tris := int(perf.get("primitives", 0))
	await _free(sc)
	_use_skeleton(false)
	# 2. the shipped renderer with whatever the renderer packages have added: what holds for any content
	sc = await _launch({"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0})
	_need(p, _renderer_file(sc) == "modern_renderer.gd", "Modern-Renderer")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 30, 4000)
	var full: Image = await _capture()
	r = sc.get("renderer")
	_need(p, r.is_prepared() and r.healthy() and int(sc.get("_sim_steps")) >= 30, "ausgelieferter Renderer: vorbereitet, gesund, die Etappe läuft")
	var above := _mean(full, Rect2i(340, 224, 600, 80))    # sky between the HUD panels and the horizon row
	var below := _mean(full, Rect2i(340, 350, 600, 200))   # ground and road
	_need(p, full.get_size() == Vector2i(1280, 720) and above.get_luminance() > 0.25 and above.b > above.r + 0.05,
		"ausgelieferter Renderer: Himmel über dem Horizont (%s)" % above.to_html(false))
	_need(p, below.get_luminance() > 0.08 and below.get_luminance() < 0.8 and absf(above.b - below.b) > 0.1,
		"ausgelieferter Renderer: Boden unter dem Horizont, kein leeres Bild (%s)" % below.to_html(false))
	var worst_full := _camera_error(r)
	_need(p, worst_full < 0.02, "ausgelieferter Renderer: Kamera = ChaseCamera3D (%.4f px)" % worst_full)
	_need(p, full.get_pixel(1140, 660).get_luminance() < 0.2 and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "ausgelieferter Renderer: HUD darüber, Seitenverhältnis expand")
	var full_snap := r.debug_snapshot()
	_report("modern_bild", p, "Gerüst allein: Himmelsverlauf, Debug-Straße an %d vorhergesagten Bildpunkten, Kamera gegen ChaseCamera3D %.4f px, HUD darüber, %d Zeichenaufrufe / %d Dreiecke; Vorbereitung %.0f ms (Selbsttest %.0f ms), %d Bilder bis Schritt 30. Ausgeliefert (Builder %s, Ebenen %s): Himmel %s, Boden %s, Kamera %.4f px" % [
		probes, worst, skeleton_calls, skeleton_tris, float(perf.get("prepare_ms", 0.0)), float(st.get("ms", 0.0)), waited,
		str(full_snap.get("builders", [])), str(full_snap.get("layers", [])), above.to_html(false), below.to_html(false), worst_full])
	await _free(sc)


# --- gleiche_zeit ----------------------------------------------------------------------------------------------

## Runs the stage with a Screenshotter (one shot at 2.5 s) and returns the simulation state at the shot.
## late: started as GameFlow starts a stage at boot (_launch).
func _state_at_shot(mode: String, extra: Dictionary = {}, late: bool = false) -> Dictionary:
	var cli := CliArgs.all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_PREFIX.get_base_dir()))
	var prefix := ProjectSettings.globalize_path(SHOT_PREFIX) + "_" + mode + str(extra.size()) + ("_spaet" if late else "")
	cli["screenshot"] = prefix
	cli["shot-times"] = "2.5"
	var setup := {"gfx": mode}
	setup.merge(extra, true)
	var sc: Node = await _launch(setup, late)
	cli.erase("screenshot")
	cli.erase("shot-times")
	var shot: Node = null
	for c in sc.get_children():
		if c is Screenshotter:
			shot = c
	if shot == null:
		await _free(sc)
		return {}
	shot.set("quit_when_done", false)
	var out := {"held_at_start": bool(shot.get("hold")), "file": prefix + "_00.png", "renderer": _renderer_file(sc)}
	var hud: Object = sc.get("hud")
	# the state at the very moment the shot is saved
	shot.connect("all_done", func() -> void:
		var texts: Array[String] = []
		for m: Dictionary in hud.get("_messages"):
			texts.append("%s %.4f" % [str(m["text"]).left(12), float(m["t"])])
		out.merge({"done": true, "steps": int(sc.get("_sim_steps")), "pos_z": float(sc.get("pos_z")), "real_time": float(sc.get("_real_time")),
			"countdown": float(sc.get("countdown")), "hud_countdown": int((hud.get("state") as Dictionary).get("countdown", -9)),
			"hud_messages": " | ".join(texts)}))
	var frames: int = await _until(func() -> bool: return out.has("done"), 3000)
	out["frames"] = frames
	await _free(sc)
	return out if out.has("done") else {}


func _check_gleiche_zeit() -> void:
	var p: Array[String] = []
	# rain: the weather hint's remaining time shows whether the HUD timers started with the stage
	var a: Dictionary = await _state_at_shot("arcade", {"weather": "rain"})
	var m: Dictionary = await _state_at_shot("modern", {"weather": "rain"})
	_need(p, not a.is_empty() and not m.is_empty(), "beide Läufe mit Screenshotter")
	if p.is_empty():
		_need(p, str(a["renderer"]) == "road_renderer.gd" and str(m["renderer"]) == "modern_renderer.gd", "je ein Renderer")
		_need(p, not bool(a["held_at_start"]) and bool(m["held_at_start"]), "die Uhr des Screenshotters steht nur in Modern während der Vorbereitung")
		_need(p, int(a["steps"]) == int(m["steps"]) and int(a["steps"]) > 100, "gleiche Zahl von Simulationsschritten (%d / %d)" % [int(a["steps"]), int(m["steps"])])
		_need(p, float(a["pos_z"]) == float(m["pos_z"]) and float(a["real_time"]) == float(m["real_time"]) and float(a["countdown"]) == float(m["countdown"]),
			"gleicher Ort, gleiche Zeit, gleicher Countdown")
		_need(p, int(a["hud_countdown"]) == int(m["hud_countdown"]) and str(a["hud_messages"]) == str(m["hud_messages"]) and str(a["hud_messages"]) != "",
			"gleicher HUD-Zustand (%s / %s)" % [str(a["hud_messages"]), str(m["hud_messages"])])
		_need(p, int(m["frames"]) > int(a["frames"]), "Modern braucht zusätzliche Bilder für die Vorbereitung (%d / %d)" % [int(m["frames"]), int(a["frames"])])
		var ia := Image.load_from_file(str(a["file"]))
		var im := Image.load_from_file(str(m["file"]))
		_need(p, ia != null and im != null and ia.get_size() == Vector2i(1280, 720) and im.get_size() == Vector2i(1280, 720), "beide Bilder gespeichert")
		if ia != null and im != null:
			# the same HUD code over both pictures: the opaque white digits of the stage time (top centre) and of the
			# speed inside the speedometer's dial stand on the same pixels
			# (the panels are slightly translucent: a pixel counts as different only where one picture is clearly white
			# and the other clearly not – the smoothed glyph edges take a little of the picture behind them)
			for r: Rect2i in [Rect2i(556, 28, 170, 38), Rect2i(1108, 618, 64, 46)]:
				var different := 0
				var white := 0
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						var la := ia.get_pixel(x, y).get_luminance()
						var lm := im.get_pixel(x, y).get_luminance()
						white += 1 if lm > 0.97 else 0
						different += 1 if (la > 0.97 and lm < 0.6) or (lm > 0.97 and la < 0.6) else 0
				_need(p, different == 0 and white > 100, "HUD-Ziffern in %s auf denselben Pixeln (%d verschieden, %d weiß)" % [str(r), different, white])
		for f: String in [str(a["file"]), str(m["file"])]:
			DirAccess.remove_absolute(f)
	# the same pair started as GameFlow starts a stage at boot: the scene is drawn once before its first step, so the
	# Arcade stage is one step behind the pair above at the shot – and the Modern stage with it
	var al: Dictionary = await _state_at_shot("arcade", {"weather": "rain"}, true)
	var ml: Dictionary = await _state_at_shot("modern", {"weather": "rain"}, true)
	_need(p, not al.is_empty() and not ml.is_empty(), "beide Läufe mit spätem Start")
	if not al.is_empty() and not ml.is_empty():
		_need(p, not a.is_empty() and int(al["steps"]) == int(a["steps"]) - 1, "später Start: Arcade einen Schritt zurück (%d statt %d)" % [int(al["steps"]), int(a.get("steps", -1))])
		_need(p, int(al["steps"]) == int(ml["steps"]), "später Start: gleiche Zahl von Simulationsschritten (%d / %d)" % [int(al["steps"]), int(ml["steps"])])
		_need(p, float(al["pos_z"]) == float(ml["pos_z"]) and float(al["real_time"]) == float(ml["real_time"]) and float(al["countdown"]) == float(ml["countdown"]),
			"später Start: gleicher Ort, gleiche Zeit, gleicher Countdown")
		_need(p, int(al["hud_countdown"]) == int(ml["hud_countdown"]) and str(al["hud_messages"]) == str(ml["hud_messages"]) and str(al["hud_messages"]) != "",
			"später Start: gleicher HUD-Zustand (%s / %s)" % [str(al["hud_messages"]), str(ml["hud_messages"])])
		for f: String in [str(al["file"]), str(ml["file"])]:
			DirAccess.remove_absolute(f)
	_report("gleiche_zeit", p, "Aufnahme bei 2,5 s: Arcade nach %d Bildern, Modern nach %d Bildern – beide nach %d Simulationsschritten, HUD %s; Start nach den Physik-Rückrufen (wie GameFlow mit --stage): beide nach %d Schritten" % [
		int(a.get("frames", -1)), int(m.get("frames", -1)), int(m.get("steps", -1)), str(m.get("hud_messages", "")), int(ml.get("steps", -1))])


# --- rueckfall -------------------------------------------------------------------------------------------------

func _check_rueckfall() -> void:
	var p: Array[String] = []
	var ref_sc: Node = await _launch({"gfx": "arcade"})
	var ref: Image = await _picture_at_step(ref_sc, 130)
	await _free(ref_sc)
	CliArgs.all()["gfx-debug"] = "fail"
	var sc: Node = await _launch({"gfx": "modern"})
	CliArgs.all().erase("gfx-debug")
	var img: Image = await _picture_at_step(sc, 130)
	_need(p, _renderer_file(sc) == "road_renderer.gd" and str(sc.get("gfx_fallback")) == "selftest:debug", "Arcade-Renderer nach dem Ausfall")
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Seitenverhältnis keep")
	var hud: Object = sc.get("hud")
	var told := false
	for m: Dictionary in hud.get("_messages"):
		told = told or str(m["text"]).begins_with("Der Modus „Modern“ lässt sich")
	_need(p, told, "Meldung im HUD")
	# below the message line the picture is the Arcade picture of the same simulation step
	var below := _diff_pixels(ref, img, Rect2i(0, 230, 1280, 490))
	var line := _diff_pixels(ref, img, Rect2i(0, 160, 1280, 70))
	_need(p, below == 0, "unter der Meldungszeile bildgleich mit Arcade (%d Pixel verschieden)" % below)
	_need(p, line > 500, "die Meldung steht im Bild (%d Pixel)" % line)
	_report("rueckfall", p, "erzwungener Ausfall: Arcade-Bild des gleichen Schritts, %d Pixel Abweichung unter der Meldung, Meldung %d Pixel" % [below, line])
	await _free(sc)


# --- arcade_gleich ---------------------------------------------------------------------------------------------

func _check_arcade_gleich() -> void:
	var p: Array[String] = []
	var first: Node = await _launch({"gfx": "arcade", "weather": "rain", "start_world_minutes": 21.5 * 60.0})
	var a: Image = await _picture_at_step(first, 150)
	await _free(first)
	var modern: Node = await _launch({"gfx": "modern", "weather": "rain", "start_world_minutes": 21.5 * 60.0})
	await _picture_at_step(modern, 150)
	_need(p, _renderer_file(modern) == "modern_renderer.gd", "dazwischen eine Modern-Etappe")
	await _free(modern)
	var second: Node = await _launch({"gfx": "arcade", "weather": "rain", "start_world_minutes": 21.5 * 60.0})
	var b: Image = await _picture_at_step(second, 150)
	await _free(second)
	var diff := _diff_pixels(a, b, Rect2i(0, 0, 1280, 720))
	_need(p, diff == 0, "Arcade-Bild vor und nach Modern identisch (%d Pixel verschieden)" % diff)
	_report("arcade_gleich", p, "Arcade (Nacht, Regen) – Modern – Arcade im selben Prozess: %d Pixel verschieden" % diff)


# --- fenster_16_10 ---------------------------------------------------------------------------------------------

func _check_fenster_16_10() -> void:
	var p: Array[String] = []
	var size0 := root.size
	# 16:10 inside the 1280×720 screen. Through the root window: without a window manager (Xvfb) a size set at the
	# DisplayServer alone does not reach the viewport.
	root.size = Vector2i(1152, 720)
	await _frames(5)
	# the skeleton alone: its sky and terrain are known exactly
	_use_skeleton(true)
	var modern: Node = await _launch({"gfx": "modern", "no_countdown": true})
	await _until(func() -> bool: return int(modern.get("_sim_steps")) >= 20, 2000)
	var im: Image = await _capture()
	var logical := root.get_visible_rect().size
	_need(p, im.get_size() == Vector2i(1152, 720), "Fensterbild 1152×720 (%s)" % str(im.get_size()))
	_need(p, is_equal_approx(logical.x, 1280.0) and is_equal_approx(logical.y, 800.0), "Modern: logisch 1280×800 (%s)" % str(logical))
	var pal: Dictionary = Palette.compute(12.0, "normal", ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	# no bars: the rows at the very top (between the HUD panels) show the sky, the very bottom the ground
	# (row y of the 720 rows of the window shows row y * 800 / 720 of the logical picture)
	_need(p, _near(im.get_pixel(380, 2), _sky_at(pal, 2.5 * 800.0 / 720.0, 800.0), 3.0 / 255.0) and im.get_pixel(480, 717).get_luminance() > 0.15,
		"Modern füllt das Fenster bis an den Rand (%s oben, %s unten)" % [im.get_pixel(380, 2).to_html(false), im.get_pixel(480, 717).to_html(false)])
	# horizon at 45 % of the window height (row 324 of 720): the sky right above it, the terrain below
	_need(p, _near(im.get_pixel(380, 316), _sky_at(pal, 316.5 * 800.0 / 720.0, 800.0), 3.0 / 255.0) and _greenish(im.get_pixel(380, 345)),
		"Horizont bei 45 %% der Fensterhöhe (%s darüber, %s darunter)" % [im.get_pixel(380, 316).to_html(false), im.get_pixel(380, 345).to_html(false)])
	var cam_px: float = _camera_error(modern.get("renderer"))
	_need(p, cam_px < 0.02, "Kamera = ChaseCamera3D auch bei 1280×800 (%.4f px)" % cam_px)
	await _free(modern)
	_use_skeleton(false)
	# the shipped renderer with whatever content exists: it fills the window, too
	modern = await _launch({"gfx": "modern", "no_countdown": true})
	await _until(func() -> bool: return int(modern.get("_sim_steps")) >= 20, 4000)
	var im_full: Image = await _capture()
	var logical_full := root.get_visible_rect().size
	_need(p, is_equal_approx(logical_full.x, 1280.0) and is_equal_approx(logical_full.y, 800.0) and im_full.get_size() == Vector2i(1152, 720),
		"ausgelieferter Renderer: logisch 1280×800 (%s)" % str(logical_full))
	_need(p, im_full.get_pixel(380, 2).get_luminance() > 0.1 and im_full.get_pixel(480, 717).get_luminance() > 0.1,
		"ausgelieferter Renderer: füllt das Fenster bis an den Rand (%s oben, %s unten)" % [im_full.get_pixel(380, 2).to_html(false), im_full.get_pixel(480, 717).to_html(false)])
	await _free(modern)
	var arcade: Node = await _launch({"gfx": "arcade", "no_countdown": true})
	await _until(func() -> bool: return int(arcade.get("_sim_steps")) >= 20, 2000)
	var ia: Image = Screenshotter.window_image(await _capture())   # with "keep" the picture is smaller than the window
	var logical_a := root.get_visible_rect().size
	_need(p, is_equal_approx(logical_a.x, 1280.0) and is_equal_approx(logical_a.y, 720.0), "Arcade: logisch 1280×720 (%s)" % str(logical_a))
	_need(p, ia.get_pixel(380, 2).get_luminance() < 0.01 and ia.get_pixel(480, 717).get_luminance() < 0.01 and ia.get_pixel(380, 100).get_luminance() > 0.1,
		"Arcade: 16:9 mit schwarzen Balken oben und unten")
	await _free(arcade)
	root.size = size0
	await _frames(3)
	_report("fenster_16_10", p, "16:10-Fenster: Modern %s ohne Balken (Kamera gegen ChaseCamera3D %.4f px), Arcade %s mit Balken" % [str(logical), cam_px, str(logical_a)])
