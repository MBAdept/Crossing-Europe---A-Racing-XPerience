extends SceneTree
## Render checks of the mode "Modern" owned by QA1 (v0.8.0, contract §4.9.2 and §6 QA1, docs/qa-v080.md). Needs a real
## renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_modern_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   helligkeit  mean luminance and no black / NaN frame per weather × hour (§4.9.2): S1 (Kiel – Hamburg km 2) dry, in
##               rain and in snow at 12:00, 19:30 and 22:00, and the Gotthard tunnel (U1, Bern – Mailand) at 12:00 –
##               each drawn by Arcade and by Modern („Mittel“) at the same simulation step, without the HUD. Every Modern
##               picture: mean luminance of the whole picture at least MIN_MEAN (never a black frame) and between
##               RATIO_MIN and RATIO_MAX times Arcade's – the same for the ground below the horizon row –, and not more
##               pure-black pixels than Arcade's picture has plus BLACK_EXTRA of the picture (a NaN or an unwritten
##               pass reads back as black on this driver). The band is a plausibility band, not a look criterion: the
##               measured ratios stand in the line and in docs/qa-v080.md (QA1, 28 A/B pictures of the reference
##               positions, Hoch and Niedrig, with HUD: whole picture 0.95–1.05 × Arcade, ground 0.89–1.05 ×).
## Each case of a pair shows the same simulation step: the stage runs without traffic, the HUD is hidden, the session
## is stopped after the step and the frame is drawn again (as tests/race3d/render/check_light_base.gd does).
## Options after "--": --only=helligkeit, --save=<absolute folder> keeps the judged pictures.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["helligkeit"]
const STEPS := 30
const MIN_MEAN := 2.0 / 255.0
const RATIO_MIN := 0.67
const RATIO_MAX := 1.5
const BLACK_EXTRA := 0.02
const SAMPLE := 2                    ## every 2nd pixel in x and y (230,400 of 921,600)

## The cases: id, stage, from, km, hour, weather, start speed
const CASES := [
	["tag", "kiel_hamburg", "kiel", 2.0, 12.0, "normal", 120.0],
	["tag_regen", "kiel_hamburg", "kiel", 2.0, 12.0, "rain", 120.0],
	["tag_schnee", "kiel_hamburg", "kiel", 2.0, 12.0, "snow", 120.0],
	["abend", "kiel_hamburg", "kiel", 2.0, 19.5, "normal", 120.0],
	["abend_regen", "kiel_hamburg", "kiel", 2.0, 19.5, "rain", 120.0],
	["abend_schnee", "kiel_hamburg", "kiel", 2.0, 19.5, "snow", 120.0],
	["nacht", "kiel_hamburg", "kiel", 2.0, 22.0, "normal", 120.0],
	["nacht_regen", "kiel_hamburg", "kiel", 2.0, 22.0, "rain", 120.0],
	["nacht_schnee", "kiel_hamburg", "kiel", 2.0, 22.0, "snow", 120.0],
	["tunnel", "bern_mailand", "bern", 186.0, 12.0, "normal", 100.0],
]

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK modern_render FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var cli := CliArgs.all()
	var had_no_traffic := cli.has("no-traffic")
	cli["no-traffic"] = true
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	if not had_no_traffic:
		cli.erase("no-traffic")
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-11s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false}
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


func _until(cond: Callable, max_frames: int = 6000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save(img: Image, name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir == "" or img == null:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))


## Runs a stage to simulation step STEPS, stops the session there, hides the HUD and returns [scene, picture of that
## step]. Modern draws the frozen view once more (the picture of exactly that step).
func _picture(mode: String, extra: Dictionary) -> Array:
	var setup := {"gfx": mode}
	setup.merge(extra, true)
	var sc: Node = await _launch(setup)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= STEPS)
	sc.set_process(false)
	sc.set_physics_process(false)
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false        # HUD, pause menu, loading overlay
	var r: Variant = sc.get("renderer")
	if r is ModernRenderer:
		(r as ModernRenderer).render((r as ModernRenderer).view)
	await process_frame
	var img: Image = await _capture()
	return [sc, img]


## {"mean", "ground", "black"}: mean luminance (Rec. 709 of the sRGB values) of the whole picture and of the rows below
## `horizon`, share of pure-black pixels – over every SAMPLE-th pixel in x and y.
static func _stats(img: Image, horizon: int) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var sum := 0.0
	var n := 0
	var gsum := 0.0
	var gn := 0
	var black := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			sum += l
			n += 1
			if y > horizon:
				gsum += l
				gn += 1
			if c.r8 == 0 and c.g8 == 0 and c.b8 == 0:
				black += 1
			x += SAMPLE
		y += SAMPLE
	return {"mean": sum / float(maxi(n, 1)), "ground": gsum / float(maxi(gn, 1)), "black": float(black) / float(maxi(n, 1))}


# --- helligkeit -------------------------------------------------------------------------------------------------

func _check_helligkeit() -> void:
	var p: Array[String] = []
	var lines: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	for cs: Array in CASES:
		var id := str(cs[0])
		var extra := {"stage_id": str(cs[1]), "from_city": str(cs[2]), "start_km": float(cs[3]),
			"start_world_minutes": float(cs[4]) * 60.0, "weather": str(cs[5]), "start_speed_kmh": float(cs[6])}
		var got_a: Array = await _picture("arcade", extra)
		var arcade: Image = got_a[1]
		var horizon := 324
		var proj: Variant = (got_a[0] as Node).get("proj")
		if proj != null:
			horizon = int(proj.get("horizon_y"))
		await _free(got_a[0])
		var got_m: Array = await _picture("modern", extra)
		var sc: Node = got_m[0]
		var modern: Image = got_m[1]
		var r: Variant = sc.get("renderer")
		var is_modern := r is ModernRenderer
		var in_tunnel := false
		if is_modern:
			in_tunnel = bool((r as ModernRenderer).view.get("camera_in_tunnel", false))
		await _free(sc)
		_save(arcade, "helligkeit_%s_arcade" % id)
		_save(modern, "helligkeit_%s_modern" % id)
		if not is_modern:
			p.append("%s: Etappe läuft nicht in Modern" % id)
			continue
		var sa := _stats(arcade, horizon)
		var sm := _stats(modern, horizon)
		var ratio := float(sm["mean"]) / maxf(float(sa["mean"]), 1.0e-4)
		var gratio := float(sm["ground"]) / maxf(float(sa["ground"]), 1.0e-4)
		lines.append("%s %.3f/%.3f (×%.2f, Boden ×%.2f, schwarz %.1f/%.1f %%)" % [id, float(sm["mean"]), float(sa["mean"]), ratio, gratio,
			100.0 * float(sm["black"]), 100.0 * float(sa["black"])])
		_need(p, float(sm["mean"]) >= MIN_MEAN, "%s: kein schwarzes Bild (Mittel %.4f)" % [id, float(sm["mean"])])
		_need(p, ratio >= RATIO_MIN and ratio <= RATIO_MAX, "%s: Helligkeit %.2f × Arcade (%.1f … %.1f)" % [id, ratio, RATIO_MIN, RATIO_MAX])
		_need(p, gratio >= RATIO_MIN and gratio <= RATIO_MAX, "%s: Boden %.2f × Arcade (%.1f … %.1f)" % [id, gratio, RATIO_MIN, RATIO_MAX])
		_need(p, float(sm["black"]) <= float(sa["black"]) + BLACK_EXTRA, "%s: höchstens %.0f %% mehr schwarze Pixel als Arcade (%.1f %% / %.1f %%)" % [
			id, 100.0 * BLACK_EXTRA, 100.0 * float(sm["black"]), 100.0 * float(sa["black"])])
		if id == "tunnel":
			_need(p, in_tunnel, "tunnel: die Kamera steht im Tunnel (camera_in_tunnel)")
	CliArgs.all().erase("gfx-preset")
	_report("helligkeit", p, "Modern/Arcade, Mittel, ohne HUD, Schritt %d: %s" % [STEPS, "; ".join(lines)])
