extends SceneTree
## Render checks of the vehicle lights of the mode "Modern" (R3; contract D14 F6, §6 R3) – they need a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_vehicle_lights.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## The shipped renderer with every layer that exists; a still stage without traffic, test cars placed into the view
## (tests/race3d/fixtures/vehicle_probe_renderer.gd); two pictures of the same moment, the lamp on and off, compared.
##   blinker        an indicator of a car 300 m ahead (Kiel – Hamburg, day and night): its lamp core is at least
##                  RoadRenderer.INDICATOR_MIN_PX (2.4 x 2.0 px: >= 2 x 2 bright amber pixels) and its glow reaches
##                  at least the radius INDICATOR_MIN_GLOW_PX around it; the other side stays dark
##   ruecklicht_n1  N1 (Hamburg – Hannover km 71, snow, 22:00): the tail lights of a car at 0.839 x visibility (where
##                  the simulation counts it as seen) lift the picture above the luminance threshold of this check
##                  (peak + 0.02 luminance and + 0.10 red against the same picture without the car)
##   bremslicht     brake light by day at 50, 150 and 300 m: braking lights the rear (more red than the tail lamp
##                  alone, Arcade's glow strength 0.35) at every distance
## "-- --save=<absolute folder>" keeps the pictures (vehicle_lights_<name>.png).
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const CHECKS := ["blinker", "ruecklicht_n1", "bremslicht"]
const INDICATOR_MIN_PX := Vector2(2.4, 2.0)     ## RoadRenderer.INDICATOR_MIN_PX (copied: -s script)
const INDICATOR_MIN_GLOW_PX := 4.5              ## RoadRenderer.INDICATOR_MIN_GLOW_PX
const N1_LUM := 0.02                            ## threshold of the tail light at 0.839 x visibility …
const N1_RED := 0.10                            ## … and of its red channel
## Kiel – Hamburg: start positions tried for the distance checks until the road ahead hides nothing (no crest)
const CLEAR_KMS: Array = [2.0, 10.0, 20.0, 30.0, 45.0, 60.0, 70.0]

var _failed: Array[String] = []
var _probe: GDScript
var _renderers: GDScript
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK vehicle_lights FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
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


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-14s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


## A still Modern stage (no autopilot, no traffic, HUD hidden) – Kiel – Hamburg km 2 unless `extra` says otherwise.
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


## True when the camera sees the point (z, x, h) of the road over the road itself (no crest in between, sampled
## every 3 m along the road, 0.3 m margin) – the distance checks need a car that is not hidden by the terrain.
func _clear(r: Node, z: float, x: float, h: float) -> bool:
	var path: RoadPath3D = r.get("path")
	var cam: Camera3D = r.get("camera")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var cam_x := float(view["camera_x"])
	var c := cam.global_transform.origin
	var target := path.world(z, x, h)
	var zi := cam_z + 10.0
	while zi < z - 3.0:
		var t := (zi - cam_z) / (z - cam_z)
		var line := c.lerp(target, t)
		var road := path.world(zi, lerpf(cam_x, x, t), 0.0)
		if line.y < road.y + 0.3:
			return false
		zi += 3.0
	return true


## A still stage at the first of `kms` where every distance of `dists` (m ahead of the camera, in the lane x offset
## `lane` from the player) can be seen over the road (see _clear()).
func _launch_clear(extra: Dictionary, kms: Array, dists: Array, lane: float) -> Node:
	for km: float in kms:
		var e := extra.duplicate()
		e["start_km"] = km
		var sc: Node = await _launch(e)
		var r: Node = sc.get("renderer")
		var view: Dictionary = r.get("view")
		var x := float((view["player"] as Dictionary).get("x", 0.0)) + lane
		var ok := true
		for d: float in dists:
			ok = ok and _clear(r, float(view["camera_z"]) + d, x, 0.6)
		if ok:
			return sc
		await _free(sc)
	return await _launch(extra)


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


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Shows `cars` (or nothing) and returns the picture once it is drawn (a few frames: nodes are built on first use).
func _shot(cars: Array) -> Image:
	_probe.set("inject", cars)
	await _frames(4)
	return await _capture()


func _keep(img: Image, pic_name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("vehicle_lights_%s.png" % pic_name))


func _car(id: int, set_id: String, z: float, x: float, extra: Dictionary = {}) -> Dictionary:
	var c := {"kind": "car", "id": id, "set": set_id, "z": z, "x": x, "length": float(ModelDB.object_size(set_id).get("length_m", 4.7)),
		"tail": 0.0, "brake": 0.0, "speed": 0.0, "blink": 0, "blink_t": 0.0}
	c.merge(extra, true)
	return c


## Screen pixels of the flares of one kind role of the injected car (from the flare layer's data of the last frame).
func _flare_px(r: Node, kind_indicator: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var fl: Node = r.call("layer", "flares")
	if fl == null:
		return out
	var cam: Camera3D = r.get("camera")
	for f: Dictionary in fl.call("flares"):
		if not bool(f["vehicle"]):
			continue
		if kind_indicator != (float(f["kind"]) > 0.5):
			continue
		out.append(cam.unproject_position(f["pos"]))
	return out


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


# --- blinker ------------------------------------------------------------------------------------------------------

func _check_blinker() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	for hour: float in [12.0, 22.0]:
		var sc: Node = await _launch_clear({"start_world_minutes": hour * 60.0}, CLEAR_KMS, [300.0], 0.0)
		var r: Node = sc.get("renderer")
		var view: Dictionary = r.get("view")
		var cam_z := float(view["camera_z"])
		var x := float((view["player"] as Dictionary).get("x", 0.0))
		_need(p, _clear(r, cam_z + 300.0, x, 0.6), "%.0f Uhr: freie Sicht auf 300 m (keine Kuppe)" % hour)
		var on := await _shot([_car(9301, "traffic/sedan_silver", cam_z + 300.0, x, {"blink": 1, "blink_t": 0.1})])
		var pts := _flare_px(r, true)
		var off := await _shot([_car(9301, "traffic/sedan_silver", cam_z + 300.0, x, {"blink": 1, "blink_t": 0.5})])
		_keep(on, "blinker_%02d" % int(hour))
		_need(p, pts.size() >= 1, "%.0f Uhr: Lichtpunkt des rechten Blinkers in der Flare-Ebene" % hour)
		if pts.is_empty():
			await _free(sc)
			continue
		var c := pts[0]
		var x0 := 1000000
		var x1 := -1
		var y0 := 1000000
		var y1 := -1
		var core := 0
		var glow := 0
		var far := 0.0
		for dy in range(-14, 15):
			for dx in range(-14, 15):
				var px := int(c.x) + dx
				var py := int(c.y) + dy
				if px < 0 or py < 0 or px >= on.get_width() or py >= on.get_height():
					continue
				var a := on.get_pixel(px, py)
				var b := off.get_pixel(px, py)
				var d := Color(a.r - b.r, a.g - b.g, a.b - b.b)
				if d.r > 2.0 / 255.0 or d.g > 2.0 / 255.0:
					glow += 1
					far = maxf(far, Vector2(dx, dy).length())
				# a lit core pixel: bright and amber (red above green above blue), clearly lifted
				if a.r >= 0.6 and a.r >= a.g and a.g > a.b + 0.1 and d.r + d.g > 0.25:
					core += 1
					x0 = mini(x0, px)
					x1 = maxi(x1, px)
					y0 = mini(y0, py)
					y1 = maxi(y1, py)
		var w := x1 - x0 + 1 if x1 >= 0 else 0
		var h := y1 - y0 + 1 if y1 >= 0 else 0
		_need(p, w >= int(ceil(INDICATOR_MIN_PX.x - 0.5)) and h >= int(INDICATOR_MIN_PX.y) and core >= 4,
			"%.0f Uhr: Blinkerkern bei 300 m mindestens %s px (gemessen %d × %d, %d Pixel)" % [hour, str(INDICATOR_MIN_PX), w, h, core])
		_need(p, far >= INDICATOR_MIN_GLOW_PX - 1.0, "%.0f Uhr: Schein reicht mindestens %.1f px weit (%.1f px)" % [hour, INDICATOR_MIN_GLOW_PX, far])
		msgs.append("%.0f Uhr: Kern %d × %d px (%d Pixel), Schein bis %.1f px, %d Pixel heller" % [hour, w, h, core, far, glow])
		await _free(sc)
	_report("blinker", p, "Blinker bei 300 m – " + "; ".join(msgs))


# --- ruecklicht_n1 ------------------------------------------------------------------------------------------------

func _check_ruecklicht_n1() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"stage_id": "hamburg_hannover", "from_city": "hamburg", "start_km": 71.0,
		"start_world_minutes": 22.0 * 60.0, "weather": "snow", "vehicle": "kompakt", "seed": 13})
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var vis := float(r.get("visibility_m"))
	var cam_z := float(view["camera_z"])
	var x := float((view["player"] as Dictionary).get("x", 0.0))
	var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
	var d := 0.839 * vis
	var with_car := await _shot([_car(9401, "traffic/sedan_red", cam_z + d, x, {"tail": lights})])
	var pts := _flare_px(r, false)
	var without := await _shot([])
	_keep(with_car, "ruecklicht_n1")
	_need(p, lights > 0.9, "Nacht (Lichter der Palette %.2f)" % lights)
	_need(p, pts.size() >= 2, "Rückleuchten als Lichtpunkte (%d)" % pts.size())
	var best_lum := 0.0
	var best_red := 0.0
	for c: Vector2 in pts:
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				var px := clampi(int(c.x) + dx, 0, with_car.get_width() - 1)
				var py := clampi(int(c.y) + dy, 0, with_car.get_height() - 1)
				var a := with_car.get_pixel(px, py)
				var b := without.get_pixel(px, py)
				best_lum = maxf(best_lum, _lum(a) - _lum(b))
				best_red = maxf(best_red, a.r - b.r)
	_need(p, best_lum >= N1_LUM and best_red >= N1_RED, "Rücklicht bei 0,839 × Sichtweite über der Schwelle (Leuchtdichte +%.3f ≥ %.2f, Rot +%.3f ≥ %.2f)" % [best_lum, N1_LUM, best_red, N1_RED])
	await _free(sc)
	_report("ruecklicht_n1", p, "N1 (Hamburg – Hannover km 71, Schnee, 22 Uhr), Sichtweite %.0f m: Auto bei %.0f m, Rücklicht hebt das Bild um %.3f Leuchtdichte, %.3f Rot" % [
		vis, d, best_lum, best_red])


# --- bremslicht ---------------------------------------------------------------------------------------------------

func _check_bremslicht() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	var sc: Node = await _launch_clear({}, CLEAR_KMS, [50.0, 150.0, 300.0], -3.75)
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var x := float((view["player"] as Dictionary).get("x", 0.0)) - 3.75
	for dist: float in [50.0, 150.0, 300.0]:
		var on := await _shot([_car(9501, "traffic/wagon_white", cam_z + dist, x, {"brake": 1.0})])
		var pts := _flare_px(r, false)
		var off := await _shot([_car(9501, "traffic/wagon_white", cam_z + dist, x, {"brake": 0.0})])
		_keep(on, "bremslicht_%03d" % int(dist))
		var red := 0.0
		var lifted := 0
		for c: Vector2 in pts:
			for dy in range(-8, 9):
				for dx in range(-8, 9):
					var px := clampi(int(c.x) + dx, 0, on.get_width() - 1)
					var py := clampi(int(c.y) + dy, 0, on.get_height() - 1)
					var dr := on.get_pixel(px, py).r - off.get_pixel(px, py).r
					red = maxf(red, dr)
					lifted += 1 if dr > 0.03 else 0
		_need(p, pts.size() >= 2 and red >= 0.08, "%.0f m: Bremslicht sichtbar (Rot +%.3f ≥ 0,08, %d Lichtpunkte)" % [dist, red, pts.size()])
		msgs.append("%.0f m: Rot +%.2f an %d Pixeln" % [dist, red, lifted])
	await _free(sc)
	_report("bremslicht", p, "Bremslicht bei Tag – " + "; ".join(msgs))
