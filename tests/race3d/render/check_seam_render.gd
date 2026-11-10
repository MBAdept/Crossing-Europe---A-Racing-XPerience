extends SceneTree
## Render checks of the seam between the race session and the Modern renderer (v0.8.0, wave 0) – they need a real
## renderer and a fixed frame rate:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_seam_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   selbsttest    GfxSelfTest on this renderer: lit sphere, shader quad and background are judged as good
##   modern_bild   a Modern stage draws: sky colour of the palette above the horizon (through the canvas layer),
##                 the ground plane below, the horizon at 45 % of the height, the HUD on top – no black frame
##   gleiche_zeit  the same stage in Arcade and in Modern with a Screenshotter: at the shot the simulation has made
##                 the same number of steps and stands at the same place (equal shot times = equal states)
##   rueckfall     a renderer that is not healthy(): the picture is the Arcade picture of the same moment, pixel for
##                 pixel below the message line
##   arcade_gleich Arcade frame, then a Modern stage, then the Arcade frame again in the same process: identical
##                 (Modern changes no project-wide render state)
##   fenster_16_10 a 16:10 window: Modern fills it (1280×800 logical, no bars), Arcade keeps 16:9 with bars
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
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


## Starts a stage the way the game does: the scene enters the tree between two frames, so its first frame begins
## with a simulation step and then draws – as when the race scene is the main scene (tools/golden.sh, screenshots)
## and when GameFlow starts a stage. (Added at the "process_frame" signal instead, the first frame would draw
## before any step: the Arcade stage would be one step behind at every shot time.)
func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11, "traffic_warmup": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
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
	_report("selbsttest", p, "Selbsttest %s: Kugel %.2f, Hintergrund %.2f, Shader-Fläche %s, %.0f ms beim ersten und %.0f ms beim zweiten Mal" % [
		"bestanden" if bool(first.get("ok", false)) else "NICHT bestanden", float(first.get("lit", 0.0)), float(first.get("dark", 0.0)),
		str(first.get("quad", "")), float(first.get("ms", 0.0)), float(second.get("ms", 0.0))])


# --- modern_bild -----------------------------------------------------------------------------------------------

func _check_modern_bild() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0})
	_need(p, _renderer_file(sc) == "modern_renderer.gd", "Modern-Renderer")
	var waited: int = await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 30, 2000)
	var img: Image = await _capture()
	var pal: Dictionary = Palette.compute(12.0, "normal", ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	var sky: Color = pal["sky_mid"]
	var amb: Color = pal["ambient"]
	var ground := Color(Palette.ROAD.r * amb.r, Palette.ROAD.g * amb.g, Palette.ROAD.b * amb.b)
	var w := img.get_width()
	var h := img.get_height()
	_need(p, w == 1280 and h == 720, "Bild 1280×720 (%d×%d)" % [w, h])
	# free of the HUD: x = 400, above and below the horizon (45 % of the height = row 324)
	var above := img.get_pixel(400, 300)
	var below := img.get_pixel(400, 500)
	_need(p, _near(above, sky, 2.5 / 255.0), "Himmelsfarbe der Palette über dem Horizont (%s statt %s)" % [above.to_html(false), sky.to_html(false)])
	_need(p, _near(below, ground, 4.5 / 255.0), "graue Ebene unter dem Horizont (%s statt %s)" % [below.to_html(false), ground.to_html(false)])
	_need(p, _near(img.get_pixel(400, 318), sky, 2.5 / 255.0) and _near(img.get_pixel(400, 330), ground, 4.5 / 255.0), "Horizont in Zeile 324")
	# the HUD is drawn over the 3D picture: the speedometer's dark dial in the lower right corner
	var dial := img.get_pixel(1140, 660)
	_need(p, not _near(dial, ground, 6.0 / 255.0), "HUD über dem 3D-Bild (Tacho)")
	_need(p, root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Seitenverhältnis expand")
	var snap: Dictionary = sc.get("renderer").call("debug_snapshot")
	var cam: Dictionary = snap.get("camera", {})
	_need(p, cam.has("z") and (snap.get("vehicles", []) as Array).size() >= 1 and (snap.get("quality", {}) as Dictionary).has("msaa"), "debug_snapshot mit Kamera, Fahrzeugen, Qualität")
	var perf: Dictionary = sc.call("perf_stats")
	_need(p, str(perf.get("mode", "")) == "modern" and int(perf.get("sim_steps", 0)) >= 30, "perf_stats mode modern")
	_report("modern_bild", p, "Modern (Gerüst): Himmel %s, Ebene %s, Horizont in Zeile 324, HUD darüber; Vorbereitung und 30 Schritte in %d Bildern" % [
		above.to_html(false), below.to_html(false), waited])
	await _free(sc)


# --- gleiche_zeit ----------------------------------------------------------------------------------------------

## Runs the stage with a Screenshotter (one shot at 2.5 s) and returns the simulation state at the shot.
func _state_at_shot(mode: String, extra: Dictionary = {}) -> Dictionary:
	var cli := CliArgs.all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_PREFIX.get_base_dir()))
	var prefix := ProjectSettings.globalize_path(SHOT_PREFIX) + "_" + mode + str(extra.size())
	cli["screenshot"] = prefix
	cli["shot-times"] = "2.5"
	var setup := {"gfx": mode}
	setup.merge(extra, true)
	var sc: Node = await _launch(setup)
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
	_report("gleiche_zeit", p, "Aufnahme bei 2,5 s: Arcade nach %d Bildern, Modern nach %d Bildern – beide nach %d Simulationsschritten, HUD %s" % [
		int(a.get("frames", -1)), int(m.get("frames", -1)), int(m.get("steps", -1)), str(m.get("hud_messages", ""))])


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
	var modern: Node = await _launch({"gfx": "modern", "no_countdown": true})
	await _until(func() -> bool: return int(modern.get("_sim_steps")) >= 20, 2000)
	var im: Image = await _capture()
	var logical := root.get_visible_rect().size
	_need(p, im.get_size() == Vector2i(1152, 720), "Fensterbild 1152×720 (%s)" % str(im.get_size()))
	_need(p, is_equal_approx(logical.x, 1280.0) and is_equal_approx(logical.y, 800.0), "Modern: logisch 1280×800 (%s)" % str(logical))
	var pal: Dictionary = Palette.compute(12.0, "normal", ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	var sky: Color = pal["sky_mid"]
	# no bars: the rows at the very top (between the HUD panels) show the sky, the very bottom the ground
	_need(p, _near(im.get_pixel(380, 2), sky, 2.5 / 255.0) and im.get_pixel(480, 717).get_luminance() > 0.15, "Modern füllt das Fenster bis an den Rand")
	# horizon at 45 % of the window height
	_need(p, _near(im.get_pixel(380, 318), sky, 2.5 / 255.0) and not _near(im.get_pixel(380, 330), sky, 8.0 / 255.0), "Horizont bei 45 % der Fensterhöhe")
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
	_report("fenster_16_10", p, "16:10-Fenster: Modern %s ohne Balken, Arcade %s mit Balken" % [str(logical), str(logical_a)])
