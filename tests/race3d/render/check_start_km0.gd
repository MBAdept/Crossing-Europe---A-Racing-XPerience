extends SceneTree
## Render check "Start bei km 0" (v0.8.0, FIX-ZS1 – finding QA1-B1 of the first test build: at the start of every
## stage the Modern camera stood 9 m too far ahead, the player's car was missing in the countdown and too big and too
## low after "LOS!"). Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_start_km0.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## Kiel – Hamburg from km 0 with the countdown (standing start, limousine, 12:00, no traffic, Modern on "Mittel"),
## the same stage in Arcade and in Modern; pictures after the same number of simulation steps, without the HUD:
##   kamera   1 s into the countdown and 1.5 s after "LOS!": the road centre at z = 0 / 14 (start line) / 30 / 60 m,
##            where it is inside the picture, lies within 1.5 px of Arcade's projection (RoadProjection) of the same
##            view – the camera stands camera_distance_m behind the car, on the road before the start line
##   auto     the same two moments: the player's car is in the picture and its paint (the limousine's blue) covers
##            the same box as in Arcade's picture – every edge within 5 % of the car's width / height
##   boden    in the countdown: the bottom 50 rows left and right of the car are road and verge like Arcade's – mean
##            colour within 0.08 per channel (no void, no seam under the camera)
## -- --save=<absolute folder> keeps the judged pictures (start_<mode>_<moment>.png).
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const MOMENTS := [[60, "countdown_1s"], [270, "los_plus_1_5s"]]   ## simulation steps (1/60 s) after the stage went live
const AHEAD_M := [0.0, 14.0, 30.0, 60.0]
const CAMERA_PX := 1.5
const BOX_TOLERANCE := 0.05
const GROUND_TOLERANCE := 0.08
const MIN_EDGE_PX := 3

var _failed: Array[String] = []
var _wall0 := 0
var _report_ground_msg := ""


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK start_km0 FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var cli := CliArgs.all()
	var had_no_traffic := cli.has("no-traffic")
	var preset0: Variant = cli.get("gfx-preset")
	cli["no-traffic"] = true
	cli["gfx-preset"] = "medium"
	var arcade := await _drive("arcade")
	var modern := await _drive("modern")
	if not had_no_traffic:
		cli.erase("no-traffic")
	if preset0 == null:
		cli.erase("gfx-preset")
	else:
		cli["gfx-preset"] = preset0
	_judge(arcade, modern)
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-8s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(mode: String) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 0.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": mode, "no_countdown": false, "start_speed_kmh": 0.0, "traffic_warmup": false}
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


func _hide_hud(sc: Node) -> void:
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false        # HUD, pause menu, loading overlay


func _save(img: Image, name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir == "" or img == null:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))


## Runs the stage in one mode and takes, at each moment, the picture (HUD hidden) and the projection of the road
## centre ahead (Arcade: RoadProjection of the view; Modern: the renderer's camera, ModernRenderer.world_to_screen()).
## Returns {"ok": bool, "why": String, moment name: {"img", "view", "road": [Vector2 per AHEAD_M], "arcade_road": …}}.
func _drive(mode: String) -> Dictionary:
	var out := {"ok": false, "why": ""}
	var sc: Node = await _launch(mode)
	for m: Array in MOMENTS:
		var steps := int(m[0])
		var n := 0
		while int(sc.get("_sim_steps")) < steps and n < 6000:
			_hide_hud(sc)
			await process_frame
			n += 1
		if int(sc.get("_sim_steps")) < steps:
			out["why"] = "%s: Schritt %d nicht erreicht" % [mode, steps]
			await _free(sc)
			return out
		_hide_hud(sc)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var r: Object = sc.get("renderer")
		var view: Dictionary = (r.get("view") as Dictionary).duplicate(true) if r != null and r.get("view") is Dictionary else {}
		var proj: Object = sc.get("proj")
		var track: Object = sc.get("track")
		var cz := float(view.get("camera_z", 0.0))
		var cx := float(view.get("camera_x", 0.0))
		var cy := float(view.get("camera_y", 0.0))
		var arcade_road: Array = []
		for z: float in AHEAD_M:
			var p: Vector3 = proj.call("project", -cx, float(track.call("height_at", z)) - cy, z - cz)
			arcade_road.append(Vector2(p.x, p.y))
		var road: Array = []
		if mode == "modern":
			if not (r is ModernRenderer):
				out["why"] = "Modern ist nicht gelaufen (Renderer %s)" % (str((r.get_script() as Script).resource_path.get_file()) if r != null and r.get_script() != null else "keiner")
				await _free(sc)
				return out
			for z: float in AHEAD_M:
				var s: Vector3 = (r as ModernRenderer).world_to_screen(z, 0.0, 0.0)
				road.append(Vector2(s.x, s.y) if s.z > 0.0 else Vector2(INF, INF))
		out[m[1]] = {"img": img, "view": view, "road": road, "arcade_road": arcade_road, "player_z": float(sc.get("pos_z"))}
		_save(img, "start_%s_%s" % [mode, m[1]])
	out["ok"] = true
	await _free(sc)
	return out


## Box of the player's paint: the pixels of the limousine's blue in the lower middle of the picture (below the horizon
## + 40 px, x 30 % .. 70 % – the blue fuel sign on the right stays outside), bounded by the first and last row / column
## with at least MIN_EDGE_PX of them. Rect2() when there are none.
static func paint_box(img: Image, horizon_y: float) -> Rect2:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := int(w * 0.3)
	var x1 := int(w * 0.7)
	var y0 := int(horizon_y) + 40
	var rows := PackedInt32Array()
	var cols := PackedInt32Array()
	rows.resize(h)
	cols.resize(w)
	var any := false
	for y in range(y0, h):
		for x in range(x0, x1):
			var c := img.get_pixel(x, y)
			if c.b > 0.35 and c.b - c.r > 0.18 and c.b - c.g > 0.08:
				rows[y] += 1
				cols[x] += 1
				any = true
	if not any:
		return Rect2()
	var top := -1
	var bottom := -1
	for y in range(y0, h):
		if rows[y] >= MIN_EDGE_PX:
			if top < 0:
				top = y
			bottom = y
	var left := -1
	var right := -1
	for x in range(x0, x1):
		if cols[x] >= MIN_EDGE_PX:
			if left < 0:
				left = x
			right = x
	if top < 0 or left < 0:
		return Rect2()
	return Rect2(float(left), float(top), float(right - left + 1), float(bottom - top + 1))


## Mean colour of the bottom `rows` rows outside [x_from, x_to] (the car).
static func bottom_mean(img: Image, rows: int, x_from: int, x_to: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(h - rows, h):
		for x in w:
			if x >= x_from and x <= x_to:
				continue
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	return Color(r / maxf(1.0, float(n)), g / maxf(1.0, float(n)), b / maxf(1.0, float(n)))


func _judge(arcade: Dictionary, modern: Dictionary) -> void:
	var cam_p: Array[String] = []
	var car_p: Array[String] = []
	var ground_p: Array[String] = []
	if not bool(arcade["ok"]) or not bool(modern["ok"]):
		var why := "; ".join([str(arcade["why"]), str(modern["why"])]).strip_edges()
		for c: String in ["kamera", "auto", "boden"]:
			_report(c, [why] as Array[String], "Lauf unvollständig")
		return
	var cam_worst := 0.0
	var car_msgs: Array[String] = []
	for m: Array in MOMENTS:
		var key := str(m[1])
		var a: Dictionary = arcade[key]
		var md: Dictionary = modern[key]
		# kamera: the same view in both runs, Modern's camera projects the road where Arcade draws it
		var va: Dictionary = a["view"]
		var vm: Dictionary = md["view"]
		_need(cam_p, absf(float(va.get("camera_z", 0.0)) - float(vm.get("camera_z", 1.0))) < 1.0e-4,
			"%s: gleiche Kamera-z in beiden Läufen (%.3f / %.3f)" % [key, float(va.get("camera_z", 0.0)), float(vm.get("camera_z", 0.0))])
		var road: Array = md["road"]
		var ar: Array = md["arcade_road"]
		var parts: Array[String] = []
		var size := Vector2((a["img"] as Image).get_size())
		for i in AHEAD_M.size():
			var pa := ar[i] as Vector2
			if pa.x < 0.0 or pa.y < 0.0 or pa.x > size.x or pa.y > size.y:
				continue        # outside the picture (after the start the start line passes under the camera)
			var d := (road[i] as Vector2).distance_to(pa) if i < road.size() else INF
			cam_worst = maxf(cam_worst, d)
			parts.append("%.0f m: %s / %s" % [AHEAD_M[i], str((road[i] as Vector2).snapped(Vector2(0.01, 0.01))) if i < road.size() else "-",
				str((ar[i] as Vector2).snapped(Vector2(0.01, 0.01)))])
			_need(cam_p, d <= CAMERA_PX, "%s: Straßenmitte %.0f m voraus %.1f px neben Arcade" % [key, AHEAD_M[i], d])
		print("  %s: Kamera z %.3f x %.3f y %.3f, Spieler z %.3f; Modern / Arcade: %s" % [key, float(vm.get("camera_z", 0.0)),
			float(vm.get("camera_x", 0.0)), float(vm.get("camera_y", 0.0)), float(md["player_z"]), "; ".join(parts)])
		# auto: the box of the paint (the horizon lies on render.horizon_y_frac = 0.45 of the picture height)
		var horizon := 0.45 * float((a["img"] as Image).get_height())
		var ba := paint_box(a["img"], horizon)
		var bm := paint_box(md["img"], horizon)
		if ba.size.x < 60.0 or ba.size.y < 40.0:
			_need(car_p, false, "%s: Arcades Auto nicht gefunden (%s)" % [key, str(ba)])
			continue
		# boden: in the countdown, the bottom rows beside the car (Arcade's box, a margin for Modern's)
		if int(m[0]) < 180:
			var x_from := int(ba.position.x - 0.15 * ba.size.x)
			var x_to := int(ba.end.x + 0.15 * ba.size.x)
			var ga := bottom_mean(a["img"], 50, x_from, x_to)
			var gm := bottom_mean(md["img"], 50, x_from, x_to)
			var gd := maxf(absf(ga.r - gm.r), maxf(absf(ga.g - gm.g), absf(ga.b - gm.b)))
			_need(ground_p, gd <= GROUND_TOLERANCE, "%s: unterste Zeilen %.3f vom Arcade-Mittel (Arcade #%s, Modern #%s)" % [key, gd, ga.to_html(false), gm.to_html(false)])
			_report_ground_msg = "unterste 50 Zeilen neben dem Auto: größte Abweichung %.3f je Kanal (Arcade #%s, Modern #%s)" % [gd, ga.to_html(false), gm.to_html(false)]
		if bm.size.x <= 0.0:
			_need(car_p, false, "%s: kein Spielerauto im Modern-Bild" % key)
			continue
		var tw := BOX_TOLERANCE * ba.size.x
		var th := BOX_TOLERANCE * ba.size.y
		var dl := bm.position.x - ba.position.x
		var dr := bm.end.x - ba.end.x
		var dt := bm.position.y - ba.position.y
		var db := bm.end.y - ba.end.y
		car_msgs.append("%s: Arcade %d×%d bei (%d, %d), Modern %d×%d bei (%d, %d), Kanten %+.0f/%+.0f/%+.0f/%+.0f px" % [key,
			int(ba.size.x), int(ba.size.y), int(ba.position.x), int(ba.position.y), int(bm.size.x), int(bm.size.y), int(bm.position.x),
			int(bm.position.y), dl, dr, dt, db])
		_need(car_p, absf(dl) <= tw and absf(dr) <= tw, "%s: linke/rechte Kante %+.0f/%+.0f px (≤ %.1f)" % [key, dl, dr, tw])
		_need(car_p, absf(dt) <= th and absf(db) <= th, "%s: obere/untere Kante %+.0f/%+.0f px (≤ %.1f)" % [key, dt, db, th])
	_report("kamera", cam_p, "Countdown und 1,5 s nach „LOS!“: Straßenmitte 0–60 m voraus höchstens %.2f px neben Arcade" % cam_worst)
	_report("auto", car_p, " | ".join(car_msgs))
	_report("boden", ground_p, _report_ground_msg)
