extends SceneTree
## Terrain gate of the mode "Modern" (v0.8.0, contract §4.9.2 "terrain cover", §6 package R2; German docs:
## docs/renderer-modern-gelaende.md) – a render check, it needs a real renderer and a fixed frame rate:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_terrain_cover.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##
## At every reference position of the terrain (T1–T4, S1, C1) the stage is drawn with --gfx-debug=cover,far: the
## canvas behind the 3D picture is magenta, the fog is off, the far-ground plane is cyan and its rim yellow. Then,
## below the horizon row of the picture:
##   magenta  = canvas shows through: nothing covers that pixel. Gate: at most 0.2 % of the pixels below the horizon.
##   cyan     = far-ground plane: where the terrain ribbons end (or leave a gap) – reported
##   yellow   = the rim of the far ground (the picture's ground at infinity) – reported
## and above the horizon row the canvas must be magenta (else the debug view is not active and the gate would pass
## for nothing). The terrain itself is drawn with back-face culling: an underside or a hole in it shows as
## magenta, cyan or yellow, never as ground.
## The check takes the shipped renderer with whatever builders and layers exist (terrain and far ground are needed;
## without them it fails). "-- --only=T3,T4" runs some positions, "-- --save=<absolute folder>" keeps the pictures.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const LIMIT := 0.002               ## magenta share below the horizon row
const SKY_MIN := 0.5               ## magenta share of the sky rows that proves the debug view is on
## Reference positions (contract §4.9.2): the car stands at that kilometre, the camera behind it.
const POSITIONS: Array = [
	{"id": "T1", "stage": "kassel_wuerzburg", "from": "kassel", "km": 46.5, "hour": 15.0, "vehicle": "kombi", "seed": 12},
	{"id": "T2", "stage": "kassel_wuerzburg", "from": "kassel", "km": 61.9, "hour": 15.0, "vehicle": "kombi", "seed": 12},
	{"id": "T3", "stage": "saragossa_pau", "from": "saragossa", "km": 172.8, "hour": 11.0, "vehicle": "kompakt", "seed": 4},
	{"id": "T4", "stage": "saragossa_pau", "from": "saragossa", "km": 198.8, "hour": 11.0, "vehicle": "kompakt", "seed": 4},
	{"id": "S1", "stage": "kiel_hamburg", "from": "kiel", "km": 2.0, "hour": 12.0, "vehicle": "limousine", "seed": 11},
	{"id": "C1", "stage": "dortmund_frankfurt", "from": "dortmund", "km": 221.0, "hour": 19.5, "vehicle": "sportwagen", "seed": 15},
]

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK terrain_cover FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var cli := CliArgs.all()
	var only := str(cli.get("only", ""))
	var before: Variant = cli.get("gfx-debug")
	cli["gfx-debug"] = "cover,far"
	for pos: Dictionary in POSITIONS:
		if only == "" or only.split(",").has(str(pos["id"])):
			await _check(pos)
	if before == null:
		cli.erase("gfx-debug")
	else:
		cli["gfx-debug"] = before
	ModelDB.release_all()
	ModernMaterials.drop_shared()   # what leaving the mode "Modern" does: nothing of it is left at the exit
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-18s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _until(cond: Callable, max_frames: int = 3000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _check(pos: Dictionary) -> void:
	var p: Array[String] = []
	var name := "terrain_cover_%s" % str(pos["id"])
	var setup := {"mode": "single", "race_id": "", "stage_id": str(pos["stage"]), "from_city": str(pos["from"]),
		"vehicle": str(pos["vehicle"]), "start_world_minutes": float(pos["hour"]) * 60.0, "weather": "normal",
		"start_km": float(pos["km"]), "autopilot": false, "seed": int(pos["seed"]), "gfx": "modern", "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	var r: Variant = sc.get("renderer")
	if not (r is Node) or not (r as Node).has_method(&"is_prepared"):
		_report(name, ["die Etappe läuft nicht im Modus Modern"] as Array[String], "")
		sc.queue_free()
		await process_frame
		return
	await _until(func() -> bool: return not is_instance_valid(r) or bool((r as Node).call(&"is_prepared")))
	r = sc.get("renderer")
	if not (r is Node) or not (r as Node).has_method(&"is_prepared") or not bool((r as Node).call(&"healthy")):
		_report(name, ["Modern ist auf Arcade zurückgefallen"] as Array[String], "")
		sc.queue_free()
		await process_frame
		return
	var renderer: Node = r
	if renderer.call(&"builder", "terrain") == null:
		p.append("builders/terrain.gd fehlt")
	if renderer.call(&"layer", "far_ground") == null:
		p.append("layers/far_ground.gd fehlt")
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("%s.png" % name))
	var proj: RoadProjection = renderer.get("proj")
	var w := img.get_width()
	var h := img.get_height()
	var horizon := int(round(proj.horizon_y / maxf(1.0, proj.screen.y) * float(h)))
	var below := 0
	var magenta := 0
	var cyan := 0
	var yellow := 0
	for y in range(horizon + 1, h):
		for x in w:
			var c := img.get_pixel(x, y)
			below += 1
			if c.r > 0.85 and c.b > 0.85 and c.g < 0.15:
				magenta += 1
			elif c.r < 0.15 and c.g > 0.85 and c.b > 0.85:
				cyan += 1
			elif c.r > 0.85 and c.g > 0.85 and c.b < 0.15:
				yellow += 1
	var sky := 0
	var sky_magenta := 0
	for y in range(4, maxi(5, horizon - 60), 2):
		for x in range(0, w, 2):
			var c := img.get_pixel(x, y)
			sky += 1
			if c.r > 0.85 and c.b > 0.85 and c.g < 0.15:
				sky_magenta += 1
	var share := float(magenta) / float(maxi(1, below))
	if float(sky_magenta) / float(maxi(1, sky)) < SKY_MIN:
		p.append("über dem Horizont ist die Leinwand nicht magenta (%.0f %%): die Debug-Ansicht „cover“ ist nicht aktiv" % (100.0 * float(sky_magenta) / float(maxi(1, sky))))
	if share > LIMIT:
		p.append("%.3f %% Magenta unter der Horizontzeile (höchstens %.1f %%)" % [100.0 * share, 100.0 * LIMIT])
	var snap: Dictionary = renderer.call(&"debug_snapshot")
	var fg: Dictionary = snap.get("far_ground", {})
	_report(name, p, "%s km %.1f: unter dem Horizont %.3f %% Magenta (%d von %d Bildpunkten), Fernboden %.2f %%, Kragen %.2f %%; Fernboden %.1f m unter der Kamera, %d Stücke" % [
		str(pos["stage"]), float(pos["km"]), 100.0 * share, magenta, below, 100.0 * float(cyan) / float(maxi(1, below)),
		100.0 * float(yellow) / float(maxi(1, below)), float((snap.get("camera", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0])[1]) - float(fg.get("y", 0.0)),
		(snap.get("chunks", []) as Array).size()])
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
