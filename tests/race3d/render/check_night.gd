extends SceneTree
## Render checks of the night of the mode "Modern" (R4; contract §6 R4, D8, D14, §4.9.2). Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_night.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   fahrbahn    N1 (Hamburg – Hannover km 71, 22:00, snow) in Arcade and in Modern at the same simulation step
##               („Mittel“ and „Steam Deck“, no traffic, HUD hidden, the precipitation of both left in – a trimmed
##               mean drops single flakes): the mean luminance of the road (lane interiors 12–70 m ahead, outside the
##               player's car) lies within +15 % of Arcade's and is never darker (contract §6 R4)
##   spielerauto the player's car at night (N1 Kompakt in the snow, Dortmund – Frankfurt km 121 Gran Turismo in the rain,
##               S1 Limousine, 22:00, „Mittel“): its body – the pixels that change when the car is not drawn, without
##               lamps, glows and the plate – at the 75th percentile of luminance at most CAR_MAX × and at least CAR_MIN ×
##               Arcade's sprite at the same step (lead decision 8 of wave 3: never brighter than Arcade where it is dark)
##   verdeckung  night in the RAIN – the wet road mirrors lamps: a braking car behind a crest (Kassel – Würzburg km
##               61.6, T2) and a braking car right behind a semitrailer change 0 pixels (neither body, glow nor the
##               reflection of its lamps on the wet road shows through), and the same car is seen in front of them
##   blaulicht   a police car with its beacon at night: the beacon lights the ground around the car blue (light pool
##               and one omni of the pool – snapshot "beacon"), off by day
## Test cars come from tests/race3d/fixtures/vehicle_probe_renderer.gd (the shipped renderer, cars added to the view).
## "-- --save=<absolute folder>" keeps the pictures (night_<name>.png).
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const CHECKS := ["fahrbahn", "spielerauto", "verdeckung", "blaulicht"]
const CAR_MAX := 1.10                ## the player's car at night at most this much brighter than Arcade's sprite …
const CAR_MIN := 0.6                 ## … and at least this bright (it must stay readable)
const STEPS := 30
const ROAD_MAX := 0.15               ## Modern's night road at most this much brighter than Arcade's (never darker)
const TRIM := 0.05                   ## share of the brightest and darkest probes left out (flakes, lines)

var _failed: Array[String] = []
var _probe: GDScript
var _renderers: GDScript
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK night FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	var had_no_traffic := cli.has("no-traffic")
	cli["no-traffic"] = true
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_probe.call("reset")
	_renderers.set("modern_script", str(_renderers.get("MODERN_SCRIPT")))
	if not had_no_traffic:
		cli.erase("no-traffic")
	ModernMaterials.drop_shared()
	Engine.time_scale = 1.0
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_frames: int = 4000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _keep(img: Image, pic: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path() and img != null:
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("night_%s.png" % pic))


func _free(sc: Node) -> void:
	_probe.call("reset")
	Engine.time_scale = 1.0
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# --- fahrbahn ------------------------------------------------------------------------------------------------------

## A stage at N1 in `mode` stopped at simulation step STEPS with the HUD hidden; [scene, picture of that step].
func _n1(mode: String) -> Array:
	_renderers.set("modern_script", str(_renderers.get("MODERN_SCRIPT")))
	var setup := {"mode": "single", "race_id": "", "stage_id": "hamburg_hannover", "from_city": "hamburg", "vehicle": "kompakt",
		"start_world_minutes": 22.0 * 60.0, "weather": "snow", "start_km": 71.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 13, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": mode}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= STEPS)
	sc.set_process(false)
	sc.set_physics_process(false)
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false
	var r: Variant = sc.get("renderer")
	if r is ModernRenderer:
		(r as ModernRenderer).render((r as ModernRenderer).view)
	await process_frame
	await RenderingServer.frame_post_draw
	return [sc, root.get_texture().get_image()]


## Probe points on the lane interiors 12–70 m ahead (the camera model), without those inside the player's car.
func _road_points(r: ModernRenderer) -> Array[Vector2]:
	var cam_z := float(r.view["camera_z"])
	var pl: Dictionary = r.view.get("player", {})
	var pz := float(pl.get("z", 0.0))
	var px := float(pl.get("x", 0.0))
	var pl_len := float(pl.get("length", 4.5))
	var pw := float(pl.get("width", 1.8))
	var box := Rect2()
	var first := true
	for zz: float in [pz - 0.3, pz + pl_len + 0.3]:
		for xx: float in [px - pw * 0.5 - 0.3, px + pw * 0.5 + 0.3]:
			for hh: float in [0.0, 1.7]:
				var q := r.world_to_screen(zz, xx, hh)
				if q.z <= 0.0:
					continue
				if first:
					box = Rect2(Vector2(q.x, q.y), Vector2.ZERO)
					first = false
				else:
					box = box.expand(Vector2(q.x, q.y))
	box = box.grow(6.0)
	var out: Array[Vector2] = []
	var lw := r.track.lane_w
	var d := 12.0
	while d <= 70.0:
		var seg := r.track.get_segment(int((cam_z + d) / r.track.seg_len))
		var la := -seg.lanes * lw * 0.5
		for i in int(ceil(seg.lanes - 0.01)):
			for off: float in [-0.9, -0.5, 0.5, 0.9]:
				var q := r.world_to_screen(cam_z + d, la + (float(i) + 0.5) * lw + off, 0.0)
				if q.z > 0.0 and not box.has_point(Vector2(q.x, q.y)):
					out.append(Vector2(q.x, q.y))
		d += 1.0
	return out


## Trimmed mean luminance of the picture at the points (TRIM of the brightest and darkest left out).
static func _trimmed(img: Image, pts: Array[Vector2]) -> float:
	var v: Array[float] = []
	for p: Vector2 in pts:
		var x := int(p.x)
		var y := int(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			v.append(img.get_pixel(x, y).get_luminance())
	if v.is_empty():
		return 0.0
	v.sort()
	var cut := int(float(v.size()) * TRIM)
	var s := 0.0
	var n := 0
	for i in range(cut, v.size() - cut):
		s += v[i]
		n += 1
	return s / float(maxi(n, 1))


func _check_fahrbahn() -> void:
	var p: Array[String] = []
	var parts: Array[String] = []
	for preset: String in ["medium", "deck"]:
		CliArgs.all()["gfx-preset"] = preset
		var got_a: Array = await _n1("arcade")
		var arcade: Image = got_a[1]
		await _free(got_a[0])
		var got_m: Array = await _n1("modern")
		var sc: Node = got_m[0]
		var modern: Image = got_m[1]
		var r: Variant = sc.get("renderer")
		if not (r is ModernRenderer):
			_need(p, false, "%s: Modern-Etappe läuft" % preset)
			await _free(sc)
			continue
		var pts := _road_points(r)
		var la := _trimmed(arcade, pts)
		var lm := _trimmed(modern, pts)
		var dev := (lm - la) / maxf(la, 1.0e-4)
		_keep(arcade, "fahrbahn_%s_arcade" % preset)
		_keep(modern, "fahrbahn_%s_modern" % preset)
		_need(p, pts.size() >= 100, "%s: genug Proben auf der Fahrbahn (%d)" % [preset, pts.size()])
		_need(p, dev >= 0.0, "%s: nie dunkler als Arcade (%+.1f %%)" % [preset, dev * 100.0])
		_need(p, dev <= ROAD_MAX, "%s: höchstens +15 %% (%+.1f %%)" % [preset, dev * 100.0])
		parts.append("%s: Modern %.4f, Arcade %.4f (%+.1f %%, %d Proben)" % [preset, lm, la, dev * 100.0, pts.size()])
		await _free(sc)
	CliArgs.all().erase("gfx-preset")
	_report("fahrbahn", p, "N1 22 Uhr Schnee, mittlere Leuchtdichte der Fahrbahn 12–70 m: " + "; ".join(parts))


# --- spielerauto ---------------------------------------------------------------------------------------------------

## A stage in `mode` stopped at step STEPS, HUD hidden: [scene, picture with the player's car, picture without it].
func _with_without(mode: String, setup_extra: Dictionary) -> Array:
	_renderers.set("modern_script", str(_renderers.get("MODERN_SCRIPT")))
	var setup := {"mode": "single", "race_id": "", "autopilot": true, "autopilot_refuel": "never", "no_countdown": true,
		"start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": mode}
	setup.merge(setup_extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= STEPS)
	sc.set_process(false)
	sc.set_physics_process(false)
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	if r is ModernRenderer:
		var wl: Object = (r as ModernRenderer).layer("weather")
		if wl != null:
			wl.set("debug_particles", false)
			wl.set("debug_spray", false)
		var fl: Object = (r as ModernRenderer).layer("flares")
		if fl != null:
			fl.set("debug_streaks", false)
	r.call("render", view)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var with_car := root.get_texture().get_image()
	var v2 := view.duplicate()
	var pl: Dictionary = (v2.get("player", {}) as Dictionary).duplicate()
	pl["visible"] = false
	v2["player"] = pl
	r.call("render", v2)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var without := root.get_texture().get_image()
	return [sc, with_car, without]


## 75th percentile of the luminance of the car's body: pixels that change when the car is not drawn, without lamps and
## glows (red-dominant) and the plate (very bright, grey). Returns [percentile, pixel count].
static func _car_body(with_car: Image, without: Image) -> Array:
	var v: Array[float] = []
	for y in range(int(with_car.get_height() * 0.55), with_car.get_height()):
		for x in range(int(with_car.get_width() * 0.3), int(with_car.get_width() * 0.7)):
			var a := with_car.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			if absf(a.get_luminance() - b.get_luminance()) < 0.03:
				continue
			if a.r > 0.25 and a.r > a.g * 1.5 and a.r > a.b * 1.5:
				continue                    # lamp, glow
			if a.get_luminance() > 0.8 and maxf(a.r, maxf(a.g, a.b)) - minf(a.r, minf(a.g, a.b)) < 0.12:
				continue                    # number plate
			v.append(a.get_luminance())
	if v.size() < 50:
		return [0.0, v.size()]
	v.sort()
	return [v[int(float(v.size()) * 0.75)], v.size()]


func _check_spielerauto() -> void:
	var p: Array[String] = []
	var parts: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	var cases: Array = [
		["N1 Kompakt Schnee", {"stage_id": "hamburg_hannover", "from_city": "hamburg", "start_km": 71.0, "weather": "snow", "vehicle": "kompakt", "seed": 13}],
		["Dortmund – Frankfurt km 121 Gran Turismo Regen", {"stage_id": "dortmund_frankfurt", "from_city": "dortmund", "start_km": 121.0, "weather": "rain", "vehicle": "gran_turismo", "seed": 14}],
		["S1 Limousine klar", {"stage_id": "kiel_hamburg", "from_city": "kiel", "start_km": 2.0, "weather": "normal", "vehicle": "limousine", "seed": 11}]]
	for cs: Array in cases:
		var extra: Dictionary = (cs[1] as Dictionary).duplicate()
		extra["start_world_minutes"] = 22.0 * 60.0
		var got_a: Array = await _with_without("arcade", extra)
		var a: Array = _car_body(got_a[1], got_a[2])
		_keep(got_a[1], "spielerauto_%s_arcade" % str(extra["vehicle"]))
		await _free(got_a[0])
		var got_m: Array = await _with_without("modern", extra)
		var m: Array = _car_body(got_m[1], got_m[2])
		_keep(got_m[1], "spielerauto_%s_modern" % str(extra["vehicle"]))
		await _free(got_m[0])
		var ratio := float(m[0]) / maxf(float(a[0]), 1.0e-3)
		_need(p, int(a[1]) >= 50 and int(m[1]) >= 50, "%s: das Auto ist in beiden Bildern (%d / %d Pixel)" % [cs[0], int(a[1]), int(m[1])])
		_need(p, ratio <= CAR_MAX, "%s: höchstens %.0f %% heller als Arcades Bild (%.2f×)" % [cs[0], (CAR_MAX - 1.0) * 100.0, ratio])
		_need(p, ratio >= CAR_MIN, "%s: mindestens %.1f× Arcades Bild (%.2f×)" % [cs[0], CAR_MIN, ratio])
		parts.append("%s: Modern %.3f, Arcade %.3f (%.2f×)" % [cs[0], float(m[0]), float(a[0]), ratio])
	CliArgs.all().erase("gfx-preset")
	_report("spielerauto", p, "22 Uhr, Karosserie (75. Perzentil der Leuchtdichte): " + "; ".join(parts))


# --- verdeckung (wet night) -----------------------------------------------------------------------------------------

func _launch_probe(extra: Dictionary) -> Node:
	_renderers.set("modern_script", PROBE)
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 22.0 * 60.0, "weather": "rain", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5, 3000)
	Engine.time_scale = 0.0          # the world clock stands: the rain and its reflections are the same in every shot
	await _frames(2)
	return sc


func _shot(cars: Array) -> Image:
	_probe.set("inject", cars)
	await _frames(4)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _car(id: int, set_id: String, z: float, x: float, extra: Dictionary = {}) -> Dictionary:
	var c := {"kind": "car", "id": id, "set": set_id, "z": z, "x": x, "length": float(ModelDB.object_size(set_id).get("length_m", 4.7)),
		"tail": 0.0, "brake": 0.0, "speed": 0.0, "blink": 0, "blink_t": 0.0}
	c.merge(extra, true)
	return c


static func _diff(a: Image, b: Image) -> Vector3:
	var n := 0
	var worst := 0.0
	var blue := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if p != q:
				n += 1
				worst = maxf(worst, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))))
				if q.b - p.b > 0.02 and q.b - p.b > q.r - p.r + 0.01:
					blue += 1
	return Vector3(n, worst, blue)


## Height (m) by which the line of sight from the camera to (z, x, h) passes below the road (positive: hidden).
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
		worst = maxf(worst, path.world(zi, lerpf(cam_x, x, t), 0.0).y - c.lerp(target, t).y)
		zi += 1.5
	return worst


func _check_verdeckung() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	# behind a crest
	var sc: Node = await _launch_probe({"stage_id": "kassel_wuerzburg", "from_city": "kassel", "start_km": 61.6, "vehicle": "kombi", "seed": 12})
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var x := float((view["player"] as Dictionary).get("x", 0.0))
	var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
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
	_need(p, hidden_z > 0.0, "eine Kuppe mit verdeckter Stelle dahinter")
	if hidden_z > 0.0:
		var lit := {"tail": lights, "brake": 1.0, "blink": 1, "blink_t": 0.1}
		var ref := _car(9600, "traffic/hatch_red", cam_z + 16.0, x - 3.75, {"tail": lights, "brake": 1.0})
		var empty := await _shot([ref])
		var hidden := await _shot([ref, _car(9601, "traffic/sedan_silver", hidden_z, x, lit)])
		var d := _diff(empty, hidden)
		var shown := await _shot([ref, _car(9601, "traffic/sedan_silver", seen_z, x, lit)])
		var s := _diff(empty, shown)
		var streaks := int(((r.call("layer", "flares").call("snapshot") as Dictionary).get("lights", {}) as Dictionary).get("wet_streaks", 0))
		_keep(hidden, "verdeckung_kuppe")
		_keep(shown, "verdeckung_kuppe_davor")
		_need(p, int(d.x) == 0, "Kuppe: Auto mit Spiegelung auf nasser Fahrbahn ändert 0 Pixel (%d, größte Differenz %.3f)" % [int(d.x), d.y])
		_need(p, int(s.x) > 30, "Kuppe: dasselbe Auto davor zu sehen (%d Pixel)" % int(s.x))
		_need(p, streaks >= 2, "nasse Fahrbahn: Spiegelungen der Rückleuchten werden gezeichnet (%d)" % streaks)
		msgs.append("Kuppe bei %.0f m: %d Pixel (davor bei %.0f m: %d)" % [hidden_z - cam_z, int(d.x), seen_z - cam_z, int(s.x)])
	await _free(sc)
	# behind a semitrailer
	sc = await _launch_probe({})
	r = sc.get("renderer")
	view = r.get("view")
	cam_z = float(view["camera_z"])
	x = float((view["player"] as Dictionary).get("x", 0.0))
	lights = float((view["palette"] as Dictionary).get("lights", 0.0))
	var lt: Variant = r.call("layer", "lights")
	if lt is Object:
		(lt as Object).set("_max_traffic", 0)   # the hidden car's headlight cone lights the road ahead of it (rightly visible)
	var truck := _car(9701, "traffic/truck_white", cam_z + 30.0, x, {"tail": lights})
	var car := _car(9702, "traffic/sedan_red", cam_z + 50.0, x, {"tail": lights, "brake": 1.0, "blink": -1, "blink_t": 0.1})
	var only_truck := await _shot([truck])
	var both := await _shot([truck, car])
	var d2 := _diff(only_truck, both)
	var empty2 := await _shot([])
	var only_car := await _shot([car])
	var s2 := _diff(empty2, only_car)
	_keep(both, "verdeckung_lkw")
	_need(p, int(d2.x) == 0, "Lkw: bremsendes Auto dahinter ändert auf nasser Fahrbahn 0 Pixel (%d, größte Differenz %.3f)" % [int(d2.x), d2.y])
	_need(p, int(s2.x) > 30, "Lkw: ohne den Sattelzug ist das Auto zu sehen (%d Pixel)" % int(s2.x))
	msgs.append("Sattelzug 30 m, Auto 50 m: %d Pixel (ohne Lkw %d)" % [int(d2.x), int(s2.x)])
	await _free(sc)
	_report("verdeckung", p, "Nacht, Regen: " + "; ".join(msgs))


# --- blaulicht ------------------------------------------------------------------------------------------------------

func _check_blaulicht() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	for hour: float in [22.0, 12.0]:
		var sc: Node = await _launch_probe({"start_world_minutes": hour * 60.0, "weather": "normal"})
		var r: Node = sc.get("renderer")
		var view: Dictionary = r.get("view")
		var cam_z := float(view["camera_z"])
		var x := float((view["player"] as Dictionary).get("x", 0.0))
		var police_set := "police/de"
		var off := await _shot([_car(9801, police_set, cam_z + 34.0, x + 3.75, {"beacon": ""})])
		var on := await _shot([_car(9801, police_set, cam_z + 34.0, x + 3.75, {"beacon": "a"})])
		var snap: Dictionary = (r.call("layer", "lights").call("snapshot") as Dictionary).get("lights", {})
		var d := _diff(off, on)
		_keep(on, "blaulicht_%02d" % int(hour))
		if hour > 20.0:
			_need(p, bool(snap.get("beacon", false)), "nachts: das Blaulicht hat ein Punktlicht und einen Kegel")
			_need(p, int(d.z) >= 400, "nachts: blaues Licht um das Polizeiauto (%d blaue von %d Pixeln)" % [int(d.z), int(d.x)])
		else:
			_need(p, not bool(snap.get("beacon", true)), "bei Tag: kein Licht des Blaulichts")
		msgs.append("%.0f Uhr: %d Pixel, davon %d blauer, Punktlicht %s" % [hour, int(d.x), int(d.z), "an" if bool(snap.get("beacon", false)) else "aus"])
		await _free(sc)
	_report("blaulicht", p, "Polizeiauto 34 m voraus, Nachbarspur: " + "; ".join(msgs))
