extends SceneTree
## Render checks of the occlusion of vehicles and their lights in the mode "Modern" (R3; contract §4.9.2, §6 R3):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_occlusion.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## The shipped renderer with every layer that exists, a still stage without traffic, test cars placed into the view
## (tests/race3d/fixtures/vehicle_probe_renderer.gd). Two pictures of the same moment – with and without the hidden
## car – must be identical to the last pixel: neither the body nor a glow of its lamps (brake, tail, indicator at
## night: the strongest flares) shows through. Each check also shows the same car where it can be seen (the test is
## not empty).
##   kuppe   a car just behind a crest (Kassel – Würzburg km 61.9, T2): 0 pixels change, by day and at night
##   lkw     a braking car right behind a semitrailer in the same lane, at night: 0 pixels change
## "-- --save=<absolute folder>" keeps the pictures (occlusion_<name>.png).
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const CHECKS := ["kuppe", "lkw"]

var _failed: Array[String] = []
var _probe: GDScript
var _renderers: GDScript
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK occlusion FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	var had_traffic := cli.has("no-traffic")
	cli["no-traffic"] = true
	_renderers.set("modern_script", PROBE)
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_probe.call("reset")
	_renderers.set("modern_script", str(_renderers.get("MODERN_SCRIPT")))
	if not had_traffic:
		cli.erase("no-traffic")
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-8s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(extra: Dictionary = {}) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5, 3000)
	# the world clock stands still from here on (the sun moves with it: by day two pictures of the same scene
	# differed by 1/255 in a few dozen pixels) – the session keeps drawing every frame with dt = 0
	Engine.time_scale = 0.0
	await _frames(2)
	return sc


func _free(sc: Node) -> void:
	_probe.call("reset")
	Engine.time_scale = 1.0
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


func _shot(cars: Array) -> Image:
	_probe.set("inject", cars)
	await _frames(4)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _keep(img: Image, pic_name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("occlusion_%s.png" % pic_name))


func _car(id: int, set_id: String, z: float, x: float, extra: Dictionary = {}) -> Dictionary:
	var c := {"kind": "car", "id": id, "set": set_id, "z": z, "x": x, "length": float(ModelDB.object_size(set_id).get("length_m", 4.7)),
		"tail": 0.0, "brake": 0.0, "speed": 0.0, "blink": 0, "blink_t": 0.0}
	c.merge(extra, true)
	return c


## Number of pixels that differ between two pictures (and the largest difference of a channel).
static func _diff(a: Image, b: Image) -> Vector2:
	var n := 0
	var worst := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if p != q:
				n += 1
				worst = maxf(worst, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))))
	return Vector2(n, worst)


## Height (m) by which the line of sight from the camera to the point (z, x, h) passes below the road between them
## (positive: hidden by the road by this much; negative: the view is free by this much). Sampled every 1.5 m.
func _below_road(r: Node, z: float, x: float, h: float) -> float:
	var path: RoadPath3D = r.get("path")
	var cam: Camera3D = r.get("camera")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var cam_x := float(view["camera_x"])
	var c := cam.global_transform.origin
	var target := path.world(z, x, h)
	var worst := -INF
	var zi := cam_z + 10.0
	while zi < z - 1.0:
		var t := (zi - cam_z) / (z - cam_z)
		var line := c.lerp(target, t)
		var road := path.world(zi, lerpf(cam_x, x, t), 0.0)
		worst = maxf(worst, road.y - line.y)
		zi += 1.5
	return worst


# --- kuppe ----------------------------------------------------------------------------------------------------------

func _check_kuppe() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	for hour: float in [12.0, 22.0]:
		var sc: Node = await _launch({"stage_id": "kassel_wuerzburg", "from_city": "kassel", "start_km": 61.6, "vehicle": "kombi",
			"seed": 12, "start_world_minutes": hour * 60.0})
		var r: Node = sc.get("renderer")
		var view: Dictionary = r.get("view")
		var cam_z := float(view["camera_z"])
		var x := float((view["player"] as Dictionary).get("x", 0.0))
		var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
		# the first place beyond a crest where a car (and 0.5 m above its roof) is hidden by at least 0.4 m
		var hidden_z := -1.0
		var seen_z := -1.0
		var z := cam_z + 20.0
		while z < cam_z + 700.0:
			var h0 := _below_road(r, z, x, 2.0)
			var h1 := _below_road(r, z + 4.8, x, 2.0)
			if seen_z < 0.0 and h0 < -0.5 and h1 < -0.5:
				seen_z = z
			if seen_z > 0.0 and h0 > 0.4 and h1 > 0.4:
				hidden_z = z
				break
			z += 2.0
		_need(p, hidden_z > 0.0, "%.0f Uhr: eine Kuppe voraus mit einer Stelle dahinter, die verdeckt ist" % hour)
		if hidden_z < 0.0:
			await _free(sc)
			continue
		var lit := {"tail": lights, "brake": 1.0, "blink": 1, "blink_t": 0.1}
		# a braking car beside the player in both pictures: lamps are on screen in both, so both are drawn the same
		# way (the flare layer reads the depth texture; whether the renderer copies it must not differ)
		var ref := _car(9600, "traffic/hatch_red", cam_z + 16.0, x - 3.75, {"tail": lights, "brake": 1.0})
		var empty := await _shot([ref])
		var hidden := await _shot([ref, _car(9601, "traffic/sedan_silver", hidden_z, x, lit)])
		var d := _diff(empty, hidden)
		var empty2 := await _shot([ref])
		var noise := _diff(empty, empty2)
		_need(p, int(noise.x) == 0, "%.0f Uhr: zwei Bilder derselben Szene gleich (%d Pixel verschieden)" % [hour, int(noise.x)])
		if int(d.x) > 0:
			_keep(empty, "kuppe_%02d_leer" % int(hour))
		var shown := await _shot([ref, _car(9601, "traffic/sedan_silver", seen_z, x, lit)])
		var s := _diff(empty, shown)
		_keep(hidden, "kuppe_%02d" % int(hour))
		_keep(shown, "kuppe_%02d_davor" % int(hour))
		_need(p, int(d.x) == 0, "%.0f Uhr: Auto hinter der Kuppe (%.0f m) ändert 0 Pixel (geändert: %d, größte Differenz %.3f)" % [hour, hidden_z - cam_z, int(d.x), d.y])
		_need(p, int(s.x) > 30, "%.0f Uhr: dasselbe Auto vor der Kuppe (%.0f m) ist zu sehen (%d Pixel)" % [hour, seen_z - cam_z, int(s.x)])
		msgs.append("%.0f Uhr: hinter der Kuppe bei %.0f m %d von %d Pixeln geändert (sichtbar bei %.0f m: %d Pixel)" % [
			hour, hidden_z - cam_z, int(d.x), empty.get_width() * empty.get_height(), seen_z - cam_z, int(s.x)])
		await _free(sc)
	_report("kuppe", p, "Kassel – Würzburg km 61,6 (T2): " + "; ".join(msgs))


# --- lkw --------------------------------------------------------------------------------------------------------------

func _check_lkw() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_world_minutes": 22.0 * 60.0})
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var x := float((view["player"] as Dictionary).get("x", 0.0))
	var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
	var truck := _car(9701, "traffic/truck_white", cam_z + 30.0, x, {"tail": lights})
	var car := _car(9702, "traffic/sedan_red", cam_z + 50.0, x, {"tail": lights, "brake": 1.0, "blink": -1, "blink_t": 0.1})
	var only_truck := await _shot([truck])
	var both := await _shot([truck, car])
	var d := _diff(only_truck, both)
	var only_car := await _shot([car])
	var empty := await _shot([])
	var s := _diff(empty, only_car)
	_keep(both, "lkw")
	_need(p, int(d.x) == 0, "bremsendes Auto direkt hinter dem Sattelzug ändert 0 Pixel (geändert: %d, größte Differenz %.3f)" % [int(d.x), d.y])
	_need(p, int(s.x) > 30, "ohne den Sattelzug ist das Auto zu sehen (%d Pixel)" % int(s.x))
	await _free(sc)
	_report("lkw", p, "Nacht, Sattelzug bei 30 m, bremsendes Auto mit Blinker bei 50 m in derselben Spur: %d Pixel geändert (ohne Lkw: %d Pixel)" % [int(d.x), int(s.x)])
