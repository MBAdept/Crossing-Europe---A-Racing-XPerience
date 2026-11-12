extends SceneTree
## Render check of the structures of the mode "Modern" (R6, contract §6 wave 3: fuel station, border, city, start /
## finish, radar). Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_structures.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## Every scene: the real race scene, Modern on "Mittel", without the HUD; positions in the picture through
## ModernRenderer.world_to_screen() of the structures' own debug data:
##   countdown   Kiel – Hamburg km 0: 1 s into the countdown the first two lamps of the start gantry are red, the third
##               dark; just after "LOS!" all three green; 2 s later all dark (Arcade's rule)
##   tankstelle  Kiel – Hamburg at the fuel stop, 12:00: the front of a canopy shows its panel (white fascia, blue
##               lettering, red band) – no Label3D anywhere; 21:00: the fascia glows and the light pools light the lane
##   zieltor     Kiel – Hamburg before the finish: the banner shows red, black and white (the checker strips)
##   grenze      the test stage at its border, 12:00: the fascia shows white and the European blue; 21:00: the light
##               bars under the roof are lit
##   blitz       the test stage through its radar zone at 150 km/h (autopilot speeding): in the frame of the flash the
##               camera head glows white – luminance around it at least 0.25 higher than in the frame before
##   stadt       the test stage in its City Limits at 21:00: the road under the street lights in Modern is not darker
##               than in Arcade (mean luminance of the road region at least 0.9 × Arcade's)
##   schatten    at the fuel stop with „Schatten: Aus“ no node of the structure builders casts a shadow, with „Mittel“
##               the station does
## -- --save=<absolute folder> keeps the judged pictures. -- --only=<names> runs some of them.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["countdown", "tankstelle", "zieltor", "grenze", "blitz", "stadt", "schatten"]
const BUILDERS := ["station", "border", "city", "gantry", "radar"]

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK structures FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var cli := CliArgs.all()
	var only := str(cli.get("only", ""))
	var preset0: Variant = cli.get("gfx-preset")
	cli["gfx-preset"] = "medium"
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	if preset0 == null:
		cli.erase("gfx-preset")
	else:
		cli["gfx-preset"] = preset0
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(mode: String, extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 0.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": mode, "no_countdown": true, "start_speed_kmh": 0.0, "traffic_warmup": false}
	setup.merge(extra, true)
	CliArgs.all()["no-traffic"] = true
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	CliArgs.all().erase("no-traffic")
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _hide_hud(sc: Node) -> void:
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false


## Waits until the stage is live and `steps` more simulation steps have run; the picture of that frame (HUD hidden).
func _picture_after(sc: Node, steps: int) -> Image:
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		_hide_hud(sc)
		await process_frame
		n += 1
	var s0 := int(sc.get("_sim_steps"))
	n = 0
	while int(sc.get("_sim_steps")) < s0 + steps and n < 6000:
		_hide_hud(sc)
		await process_frame
		n += 1
	_hide_hud(sc)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save(img: Image, name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir == "" or img == null:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))


## The debug parts of one builder over the loaded chunks: [part Dictionary, …].
func _parts(r: Object, builder_id: String) -> Array:
	var out: Array = []
	for c: Dictionary in (r.call("debug_snapshot") as Dictionary).get("chunks", []):
		var p: Variant = (c.get("parts", {}) as Dictionary).get(builder_id)
		if p is Dictionary and not (p as Dictionary).is_empty():
			out.append(p)
	return out


## Pixel statistics of a rectangle: mean luminance and the counts of pixels matching each predicate of `kinds`.
static func region(img: Image, r: Rect2i, kinds: Dictionary = {}) -> Dictionary:
	var rr := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var lum := 0.0
	var top := 0.0
	var n := 0
	var counts := {}
	for k: String in kinds:
		counts[k] = 0
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			lum += l
			top = maxf(top, l)
			n += 1
			for k: String in kinds:
				if (kinds[k] as Callable).call(c):
					counts[k] += 1
	return {"lum": lum / float(maxi(n, 1)), "max": top, "n": n, "counts": counts}


## Screen point (px x, px y, depth) of road coordinates in either mode: Modern's camera (world_to_screen) or Arcade's
## projection of the frame's view (RoadProjection.project, as check_start_km0).
func _screen(sc: Node, z: float, x: float, h: float) -> Vector3:
	var r: Object = sc.get("renderer")
	if r is ModernRenderer:
		return (r as ModernRenderer).world_to_screen(z, x, h)
	var view: Dictionary = r.get("view") if r != null and r.get("view") is Dictionary else {}
	var proj: Object = sc.get("proj")
	var trk: Object = sc.get("track")
	var p: Vector3 = proj.call("project", x - float(view.get("camera_x", 0.0)), float(trk.call("height_at", z)) + h - float(view.get("camera_y", 0.0)),
		z - float(view.get("camera_z", 0.0)))
	return Vector3(p.x, p.y, z - float(view.get("camera_z", 0.0)))


static func is_red(c: Color) -> bool:
	return c.r > 0.45 and c.r > c.g * 2.0 and c.r > c.b * 2.0


static func is_green(c: Color) -> bool:
	return c.g > 0.45 and c.g > c.r * 1.6 and c.g > c.b * 1.4


static func is_white(c: Color) -> bool:
	return c.r > 0.72 and c.g > 0.72 and c.b > 0.7


static func is_blue(c: Color) -> bool:
	return c.b > 0.3 and c.b > c.r * 1.8 and c.b > c.g * 1.2


static func is_dark(c: Color) -> bool:
	return c.get_luminance() < 0.12


## A screen rectangle round a projected point: half size in metres at its depth (logical px = 711 / depth per metre).
static func box_at(p: Vector3, half_w_m: float, half_h_m: float) -> Rect2i:
	var k := 711.0 / maxf(p.z, 0.5)
	return Rect2i(int(p.x - half_w_m * k), int(p.y - half_h_m * k), maxi(1, int(half_w_m * k * 2.0)), maxi(1, int(half_h_m * k * 2.0)))


# --- countdown ---------------------------------------------------------------------------------------------------

func _check_countdown() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch("modern", {"no_countdown": false})
	var msgs: Array = []
	# [simulation steps after the stage went live, wanted per lamp: 1 red, 2 green, 0 dark] – the countdown is 3 s
	for m: Array in [[70, [1, 1, 0]], [205, [2, 2, 2]], [330, [0, 0, 0]]]:
		var n := 0
		while int(sc.get("_sim_steps")) < int(m[0]) and n < 6000:
			_hide_hud(sc)
			await process_frame
			n += 1
		_hide_hud(sc)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var r: Object = sc.get("renderer")
		if not (r is ModernRenderer):
			_need(p, false, "Modern ist nicht gelaufen")
			break
		_save(img, "countdown_%d" % int(m[0]))
		var states: Array = []
		for i in 3:
			var s: Vector3 = (r as ModernRenderer).world_to_screen(14.0, 1.4 + float(i) * 1.15, 6.2)
			var reg := region(img, box_at(s, 0.22, 0.22), {"red": is_red, "green": is_green})
			var nn := maxi(1, int(reg["n"]))
			var red := float(reg["counts"]["red"]) / float(nn)
			var green := float(reg["counts"]["green"]) / float(nn)
			var got := 1 if red > 0.3 else (2 if green > 0.3 else 0)
			states.append(got)
			_need(p, got == int((m[1] as Array)[i]), "Schritt %d: Lampe %d %s (rot %.0f %%, grün %.0f %%)" % [int(m[0]), i,
				["dunkel", "rot", "grün"][int((m[1] as Array)[i])], red * 100.0, green * 100.0])
		msgs.append("Schritt %d: %s" % [int(m[0]), str(states)])
	await _free(sc)
	_report("countdown", p, "Starttor-Lampen (0 dunkel, 1 rot, 2 grün) %s" % ", ".join(msgs))


# --- fuel station ------------------------------------------------------------------------------------------------

func _check_tankstelle() -> void:
	var p: Array[String] = []
	var msgs: Array = []
	for hour: float in [12.0, 21.0]:
		var sc: Node = await _launch("modern", {"start_km": 13.95, "start_world_minutes": hour * 60.0})
		var img: Image = await _picture_after(sc, 30)
		var r: Object = sc.get("renderer")
		if not (r is ModernRenderer):
			_need(p, false, "Modern ist nicht gelaufen")
			await _free(sc)
			break
		_save(img, "tankstelle_%02d" % int(hour))
		var cam_z := float(((r as ModernRenderer).view as Dictionary).get("camera_z", 0.0))
		var trk: Object = sc.get("track")
		var front := INF
		for part: Dictionary in _parts(r, "station"):
			for z: Variant in part.get("front_z", []):
				if float(z) - cam_z > 25.0 and float(z) < front:
					front = float(z)
		_need(p, front < INF, "%02d Uhr: eine Dachfront vor der Kamera" % int(hour))
		var labels := root.find_children("*", "Label3D", true, false).size()
		_need(p, labels == 0, "kein Label3D (%d)" % labels)
		if front < INF:
			var e := float((trk.call("road_edges_at", front) as Vector2).y)
			var c: Vector3 = (r as ModernRenderer).world_to_screen(front, e + 2.05, 6.02)
			var reg := region(img, box_at(c, 2.3, 0.4), {"white": is_white, "blue": is_blue, "red": is_red})
			var nn := float(maxi(1, int(reg["n"])))
			var white := float(reg["counts"]["white"]) / nn
			var blue := float(reg["counts"]["blue"]) / nn
			if hour < 18.0:
				_need(p, white > 0.2 and blue > 0.01, "12 Uhr: Stirnblende weiß mit blauer Schrift (weiß %.0f %%, blau %.1f %%)" % [white * 100.0, blue * 100.0])
				msgs.append("12 Uhr: Stirnblende %.0f m voraus, weiß %.0f %%, blau %.1f %%" % [front - cam_z, white * 100.0, blue * 100.0])
			else:
				_need(p, float(reg["lum"]) > 0.25, "21 Uhr: die Stirnblende leuchtet (Leuchtdichte %.2f)" % float(reg["lum"]))
				# the fuel lane under that canopy: lit by the canopy's pools at least like Arcade's (the same spot in the
				# same simulation state, Arcade's own projection)
				var lane_m: Vector3 = _screen(sc, front + 6.0, e - 1.9, 0.0)
				var lr := region(img, box_at(lane_m, 0.8, 0.3))
				await _free(sc)
				var sa: Node = await _launch("arcade", {"start_km": 13.95, "start_world_minutes": hour * 60.0})
				var img_a: Image = await _picture_after(sa, 30)
				_save(img_a, "tankstelle_%02d_arcade" % int(hour))
				var lane_a: Vector3 = _screen(sa, front + 6.0, e - 1.9, 0.0)
				var la := region(img_a, box_at(lane_a, 0.8, 0.3))
				sc = sa
				_need(p, float(lr["lum"]) >= 0.85 * float(la["lum"]), "21 Uhr: Tankspur unter dem Dach mindestens so hell wie in Arcade (%.3f gegen %.3f)" % [
					float(lr["lum"]), float(la["lum"])])
				msgs.append("21 Uhr: Stirnblende %.2f, Tankspur Modern %.3f, Arcade %.3f" % [float(reg["lum"]), float(lr["lum"]), float(la["lum"])])
		await _free(sc)
	_report("tankstelle", p, "; ".join(msgs))


# --- finish gantry -----------------------------------------------------------------------------------------------

func _check_zieltor() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch("modern", {"start_km": 94.6})
	var img: Image = await _picture_after(sc, 20)
	var r: Object = sc.get("renderer")
	var msg := ""
	if r is ModernRenderer:
		_save(img, "zieltor")
		var trk: Object = sc.get("track")
		var lz := float(trk.get("length_z"))
		var c: Vector3 = (r as ModernRenderer).world_to_screen(lz, 0.0, 6.2)
		var reg := region(img, box_at(c, 6.0, 0.75), {"red": is_red, "white": is_white, "dark": is_dark})
		var nn := float(maxi(1, int(reg["n"])))
		var red := float(reg["counts"]["red"]) / nn
		var white := float(reg["counts"]["white"]) / nn
		var dark := float(reg["counts"]["dark"]) / nn
		_need(p, c.z > 10.0, "Zieltor vor der Kamera (%.0f m)" % c.z)
		_need(p, red > 0.25 and white > 0.04 and dark > 0.04, "Banner rot mit Schachbrett (rot %.0f %%, weiß %.0f %%, schwarz %.0f %%)" % [
			red * 100.0, white * 100.0, dark * 100.0])
		msg = "Zieltor %.0f m voraus: rot %.0f %%, weiß %.0f %%, schwarz %.0f %%" % [c.z, red * 100.0, white * 100.0, dark * 100.0]
	else:
		_need(p, false, "Modern ist nicht gelaufen")
	await _free(sc)
	_report("zieltor", p, msg)


# --- border ------------------------------------------------------------------------------------------------------

func _check_grenze() -> void:
	var p: Array[String] = []
	var msgs: Array = []
	for hour: float in [12.0, 21.0]:
		var sc: Node = await _launch("modern", {"stage_id": "dev_testetappe", "from_city": "dev_start", "start_km": 64.55,
			"start_world_minutes": hour * 60.0})
		var img: Image = await _picture_after(sc, 20)
		var r: Object = sc.get("renderer")
		if not (r is ModernRenderer):
			_need(p, false, "Modern ist nicht gelaufen")
			await _free(sc)
			break
		_save(img, "grenze_%02d" % int(hour))
		var trk: Object = sc.get("track")
		var plan: Object = trk.get("plan")
		var bz := float(trk.call("km_to_z", float(((plan.get("borders") as Array)[0] as Dictionary)["km"])))
		var c: Vector3 = (r as ModernRenderer).world_to_screen(bz, 0.0, 6.8)
		if hour < 18.0:
			var reg := region(img, box_at(c, 6.0, 0.8), {"white": is_white, "blue": is_blue})
			var nn := float(maxi(1, int(reg["n"])))
			_need(p, float(reg["counts"]["white"]) / nn > 0.15 and float(reg["counts"]["blue"]) / nn > 0.04,
				"12 Uhr: Stirnblende weiß und europablau (weiß %.0f %%, blau %.0f %%)" % [float(reg["counts"]["white"]) / nn * 100.0,
				float(reg["counts"]["blue"]) / nn * 100.0])
			msgs.append("12 Uhr: Stirnblende %.0f m voraus, weiß %.0f %%, blau %.0f %%" % [c.z, float(reg["counts"]["white"]) / nn * 100.0,
				float(reg["counts"]["blue"]) / nn * 100.0])
		else:
			# a row of light bars under the roof (the second row with bars: every second segment): the brightest pixel
			# round its middle bar is near white, the soffit beside it dark
			var seg_len := float(trk.get("seg_len"))
			var k := int(ceil(bz / seg_len))
			while k % 2 != 0:
				k += 1
			var bar: Vector3 = (r as ModernRenderer).world_to_screen(float(k + 2) * seg_len + seg_len * 0.5, 0.0, 5.97)
			var reg2 := region(img, box_at(bar, 1.2, 0.35))
			_need(p, float(reg2["max"]) > 0.8, "21 Uhr: Lichtbänder unter dem Dach leuchten (hellster Bildpunkt %.2f)" % float(reg2["max"]))
			msgs.append("21 Uhr: Lichtband hellster Bildpunkt %.2f, Mittel %.2f" % [float(reg2["max"]), float(reg2["lum"])])
		await _free(sc)
	_report("grenze", p, "; ".join(msgs))


# --- radar flash -------------------------------------------------------------------------------------------------

func _check_blitz() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch("modern", {"stage_id": "dev_testetappe", "from_city": "dev_start", "start_km": 11.85,
		"start_speed_kmh": 150.0, "autopilot_speeding": true})
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		_hide_hud(sc)
		await process_frame
		n += 1
	var before: Image = null
	var at: Image = null
	var cam_pt := Vector3.ZERO
	var msg := ""
	n = 0
	while n < 900:
		_hide_hud(sc)
		await RenderingServer.frame_post_draw
		var f := float(sc.get("_flash"))
		var img := root.get_texture().get_image()
		if f > 0.85:
			at = img
			break
		before = img
		n += 1
	var r: Object = sc.get("renderer")
	if at != null and before != null and r is ModernRenderer:
		_save(before, "blitz_vorher")
		_save(at, "blitz")
		var cam_z := float(((r as ModernRenderer).view as Dictionary).get("camera_z", 0.0))
		var best := INF
		var bx := 0.0
		for part: Dictionary in _parts(r, "radar"):
			for c: Array in part.get("cameras", []):
				var d := float(c[0]) - cam_z
				if d > 5.0 and d < best:
					best = d
					bx = float(c[1])
		_need(p, best < INF, "ein Blitzer vor der Kamera")
		if best < INF:
			cam_pt = (r as ModernRenderer).world_to_screen(cam_z + best, bx, 2.85)
			var bright := func(c: Color) -> bool: return c.r > 0.92 and c.g > 0.92 and c.b > 0.92
			var a := region(at, box_at(cam_pt, 1.0, 1.0), {"white": bright})
			var b := region(before, box_at(cam_pt, 1.0, 1.0), {"white": bright})
			var wa := float(a["counts"]["white"]) / float(maxi(1, int(a["n"])))
			var wb := float(b["counts"]["white"]) / float(maxi(1, int(b["n"])))
			_need(p, wa > wb + 0.2 and float(a["lum"]) > float(b["lum"]) + 0.08,
				"der Blitz leuchtet am Kamerakopf (weiße Bildpunkte %.0f %% gegen %.0f %% davor, Leuchtdichte %.2f gegen %.2f)" % [wa * 100.0,
				wb * 100.0, float(a["lum"]), float(b["lum"])])
			msg = "Blitzer %.0f m voraus: am Kopf %.0f %% weiß im Blitz (davor %.0f %%), Leuchtdichte %.2f (davor %.2f)" % [best, wa * 100.0,
				wb * 100.0, float(a["lum"]), float(b["lum"])]
	else:
		_need(p, false, "kein Blitz in %d Bildern (Autopilot zu langsam oder Modern nicht gelaufen)" % n)
	await _free(sc)
	_report("blitz", p, msg)


# --- city at night -----------------------------------------------------------------------------------------------

func _check_stadt() -> void:
	var p: Array[String] = []
	var lum := {}
	var spot := Vector2.ZERO        ## (z, x) of the pool centre measured: the first street light 25 m or more ahead
	for mode: String in ["modern", "arcade"]:
		var sc: Node = await _launch(mode, {"stage_id": "dev_testetappe", "from_city": "dev_start", "start_km": 111.0,
			"start_world_minutes": 21.0 * 60.0})
		var img: Image = await _picture_after(sc, 20)
		_save(img, "stadt_nacht_%s" % mode)
		if mode == "modern":
			var r: Object = sc.get("renderer")
			var lights: Array = []
			if r is ModernRenderer:
				for part: Dictionary in _parts(r, "city"):
					lights.append_array(part.get("lights", []))
			_need(p, lights.size() >= 10, "Laternen in den geladenen Stücken (%d)" % lights.size())
			var cam_z := float(((r as ModernRenderer).view as Dictionary).get("camera_z", 0.0)) if r is ModernRenderer else 0.0
			var best := INF
			var trk: Object = sc.get("track")
			for l: Array in lights:
				var d := float(l[0]) - cam_z
				if d >= 25.0 and d < best:
					best = d
					# Arcade's pool centre of that light: on the road 0.6 m inside the paved edge, at the light's segment
					var ed: Vector2 = trk.call("road_edges_at", float(l[0]))
					spot = Vector2(float(l[0]) + 1.5, (ed.y - 0.6) if int(l[1]) > 0 else (ed.x + 0.6))
			_need(p, best < INF, "eine Laterne vor der Kamera")
		var s: Vector3 = _screen(sc, spot.x, spot.y, 0.0)
		lum[mode] = float(region(img, box_at(s, 0.9, 0.35))["lum"])
		await _free(sc)
	_need(p, float(lum.get("modern", 0.0)) >= 0.85 * float(lum.get("arcade", 1.0)), "Lichtkegel einer Laterne mindestens so hell wie in Arcade (%.3f gegen %.3f)" % [
		float(lum.get("modern", 0.0)), float(lum.get("arcade", 0.0))])
	_report("stadt", p, "21 Uhr, City Limits, Kegel der ersten Laterne ab 25 m (z %.0f, x %.1f): Leuchtdichte Modern %.3f, Arcade %.3f" % [spot.x, spot.y,
		float(lum.get("modern", 0.0)), float(lum.get("arcade", 0.0))])


# --- shadows -----------------------------------------------------------------------------------------------------

func _check_schatten() -> void:
	var p: Array[String] = []
	var counts := {}
	for setting: String in ["medium", "off"]:
		if setting == "off":
			CliArgs.all()["gfx"] = "shadows=0"
		var sc: Node = await _launch("modern", {"start_km": 13.95})
		await _picture_after(sc, 5)
		var r: Object = sc.get("renderer")
		var casting := 0
		var total := 0
		if r is ModernRenderer:
			for n: Node in (r as ModernRenderer).world.find_children("*", "GeometryInstance3D", true, false):
				var nm := String(n.name)
				if nm.begins_with("Station") or nm.begins_with("Gantry") or nm.begins_with("Border") or nm in ["Fences", "StreetLights"]:
					total += 1
					if (n as GeometryInstance3D).visible and (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
						casting += 1
		counts[setting] = [casting, total]
		CliArgs.all().erase("gfx")
		await _free(sc)
	_need(p, int(counts["off"][1]) > 0 and int(counts["off"][0]) == 0, "mit „Aus“ wirft kein Bau-Knoten (%d von %d)" % [int(counts["off"][0]), int(counts["off"][1])])
	_need(p, int(counts["medium"][0]) > 0, "mit „Mittel“ werfen die Bauten (%d von %d)" % [int(counts["medium"][0]), int(counts["medium"][1])])
	_report("schatten", p, "Tankstelle: „Mittel“ %d von %d Knoten werfen, „Aus“ %d von %d" % [int(counts["medium"][0]), int(counts["medium"][1]),
		int(counts["off"][0]), int(counts["off"][1])])
