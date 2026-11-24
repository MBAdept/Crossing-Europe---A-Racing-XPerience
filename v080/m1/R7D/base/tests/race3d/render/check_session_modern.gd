extends SceneTree
## Render check of the race session in the mode "Modern" after the assembly of M1 (v0.8.0, contract §4.4.2, D34,
## §4.11, A-4) – it needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_session_modern.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   pause      Kiel – Hamburg km 2 at noon with traffic: once the stage runs, the tree is paused – 30 drawn frames
##              of the 3D picture are identical (wind in the leaves, rotors, flares and every other animation run on
##              view.time / ce_time and stand still with the game, §4.4.2 step 7); the picture changes again once
##              the game runs on
##   rueckfall  the same stage with --gfx-debug=fail: the real render self-test reports the failure, the stage starts
##              with the Arcade renderer, gfx = "arcade", gfx_fallback = "selftest:debug" (D34)
##   freigabe   after a Modern stage the Arcade renderer of the next stage releases what Modern loaded
##              (RaceRenderers.leave_modern(): ModelDB without meshes and textures, no shared ModernMaterials, A-4)
## The HUD and the pause menu are hidden for the pictures (canvas layers >= 5). (-s scripts compile before the
## autoloads exist: the scene and the session are reached untyped.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["pause", "rueckfall", "freigabe"]
const FROZEN_FRAMES := 30

var _failed: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK session_modern FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var only := str(CliArgs.all().get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _launch(gfx: String) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": true, "gfx": gfx}
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


func _until(cond: Callable, max_frames: int = 4000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _hide_ui(sc: Node) -> void:
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false        # HUD, pause menu, loading overlay


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


static func _diff(a: Image, b: Image) -> Array:
	var changed := 0
	var maxd := 0.0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if d > 0.0:
				changed += 1
				maxd = maxf(maxd, d)
	return [changed, maxd]


static func _script_name(o: Variant) -> String:
	if not (o is Object) or (o as Object).get_script() == null:
		return ""
	return ((o as Object).get_script() as Script).resource_path.get_file()


# --- pause ------------------------------------------------------------------------------------------------------

func _check_pause() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch("modern")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 90)
	var modern := _script_name(sc.get("renderer")) == "modern_renderer.gd"
	if not modern:
		p.append("die Etappe läuft in Modern (%s)" % _script_name(sc.get("renderer")))
	_hide_ui(sc)
	paused = true
	for i in 3:
		await process_frame
	var a: Image = await _capture()
	for i in FROZEN_FRAMES:
		await process_frame
	var b: Image = await _capture()
	var steps_paused := int(sc.get("_sim_steps"))
	var d: Array = _diff(a, b)
	if int(d[0]) > 0:
		p.append("das Bild bleibt in der Pause stehen (%d Bildpunkte geändert, bis %.3f)" % [int(d[0]), float(d[1])])
	paused = false
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= steps_paused + 30)
	_hide_ui(sc)
	var c: Image = await _capture()
	var d2: Array = _diff(b, c)
	if int(d2[0]) < 1000:
		p.append("nach der Pause bewegt sich das Bild wieder (%d Bildpunkte geändert)" % int(d2[0]))
	_report("pause", p, "Kiel – Hamburg km 2, Verkehr: %d Bilder in der Pause, %d Bildpunkte verschieden (jeder zweite); danach %d verschieden" % [
		FROZEN_FRAMES, int(d[0]), int(d2[0])])
	await _free(sc)


# --- rueckfall ---------------------------------------------------------------------------------------------------

func _check_rueckfall() -> void:
	var p: Array[String] = []
	var cli := CliArgs.all()
	cli["gfx-debug"] = "fail"
	var sc: Node = await _launch("modern")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 30)
	cli.erase("gfx-debug")
	var rname := _script_name(sc.get("renderer"))
	var res: Dictionary = sc.call("build_result")
	if rname != "road_renderer.gd":
		p.append("Arcade-Renderer nach dem Rückfall (%s)" % rname)
	if str(sc.get("gfx")) != "arcade" or str(res.get("gfx", "")) != "arcade":
		p.append("gfx = arcade (%s / %s)" % [str(sc.get("gfx")), str(res.get("gfx", ""))])
	if str(res.get("gfx_fallback", "")) != "selftest:debug":
		p.append("gfx_fallback = selftest:debug (%s)" % str(res.get("gfx_fallback", "")))
	if root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_KEEP:
		p.append("Arcade wieder mit 16:9 und Balken (KEEP)")
	_report("rueckfall", p, "--gfx-debug=fail: Renderer %s, gfx %s, gfx_fallback %s, die Etappe läuft (%d Schritte)" % [
		rname, str(res.get("gfx", "")), str(res.get("gfx_fallback", "")), int(sc.get("_sim_steps"))])
	await _free(sc)


# --- freigabe ----------------------------------------------------------------------------------------------------

func _check_freigabe() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch("modern")
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 30)
	var meshes_modern := (ModelDB._meshes as Dictionary).size()
	var shared_modern := ModernMaterials._shared != null
	if meshes_modern == 0 or not shared_modern:
		p.append("die Modern-Etappe hat Modelle und Materialien geladen (%d Netze, geteilt: %s)" % [meshes_modern, str(shared_modern)])
	await _free(sc)
	var sa: Node = await _launch("arcade")
	await _until(func() -> bool: return int(sa.get("_sim_steps")) >= 30)
	var meshes_after := (ModelDB._meshes as Dictionary).size()
	var tex_after := (ModelDB._textures as Dictionary).size()
	var shared_after := ModernMaterials._shared != null
	if _script_name(sa.get("renderer")) != "road_renderer.gd":
		p.append("die nächste Etappe läuft in Arcade")
	if meshes_after != 0 or tex_after != 0:
		p.append("ModelDB leer (%d Netze, %d Texturen)" % [meshes_after, tex_after])
	if shared_after:
		p.append("keine geteilten Materialien mehr (ModernMaterials.drop_shared)")
	_report("freigabe", p, "Modern-Etappe: %d Netze, Materialien geteilt %s; danach Arcade: %d Netze, %d Texturen, Materialien geteilt %s" % [
		meshes_modern, str(shared_modern), meshes_after, tex_after, str(shared_after)])
	await _free(sa)
