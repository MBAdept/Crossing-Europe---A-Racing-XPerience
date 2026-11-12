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
	var n := 0
	var counts := {}
	for k: String in kinds:
		counts[k] = 0
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var c := img.get_pixel(x, y)
			lum += c.get_luminance()
			n += 1
			for k: String in kinds:
				if (kinds[k] as Callable).call(c):
					counts[k] += 1
	return {"lum": lum / float(maxi(n, 1)), "n": n, "counts": counts}


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
				# the lane under the canopy against the road beside it (the light pools of the canopy lamps)
				var lane: Vector3 = (r as ModernRenderer).world_to_screen(front + 6.0, e - 1.9, 0.0)
				var road: Vector3 = (r as ModernRenderer).world_to_screen(front + 6.0, e - 9.4, 0.0)
				var lr := region(img, box_at(lane, 0.8, 0.3))
				var rr := region(img, box_at(road, 0.8, 0.3))
				_need(p, float(lr["lum"]) > float(rr["lum"]) + 0.03, "21 Uhr: die Tankspur unter dem Dach heller als die Fahrbahn daneben (%.3f / %.3f)" % [
					float(lr["lum"]), float(rr["lum"])])
				msgs.append("21 Uhr: Stirnblende %.2f, Tankspur %.3f, Fahrbahn %.3f" % [float(reg["lum"]), float(lr["lum"]), float(rr["lum"])])
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
			# the light bars under the roof (a row 9 m into the station): the brightest pixels round them
			var bar: Vector3 = (r as ModernRenderer).world_to_screen(bz + 7.5, 0.0, 5.97)
			var reg2 := region(img, box_at(bar, 4.0, 0.5), {"white": is_white})
			_need(p, int(reg2["counts"]["white"]) >= 6, "21 Uhr: Lichtbänder unter dem Dach leuchten (%d helle Bildpunkte)" % int(reg2["counts"]["white"]))
			msgs.append("21 Uhr: %d helle Bildpunkte an den Lichtbändern" % int(reg2["counts"]["white"]))
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
			var a := region(at, box_at(cam_pt, 1.2, 1.2))
			var b := region(before, box_at(cam_pt, 1.2, 1.2))
			_need(p, float(a["lum"]) > float(b["lum"]) + 0.25, "der Blitz leuchtet am Kamerakopf (Leuchtdichte %.2f gegen %.2f davor)" % [
				float(a["lum"]), float(b["lum"])])
			msg = "Blitzer %.0f m voraus: Leuchtdichte am Kopf %.2f im Blitz, %.2f davor" % [best, float(a["lum"]), float(b["lum"])]
	else:
		_need(p, false, "kein Blitz in %d Bildern (Autopilot zu langsam oder Modern nicht gelaufen)" % n)
	await _free(sc)
	_report("blitz", p, msg)


# --- city at night -----------------------------------------------------------------------------------------------

func _check_stadt() -> void:
	var p: Array[String] = []
	var lum := {}
	for mode: String in ["arcade", "modern"]:
		var sc: Node = await _launch(mode, {"stage_id": "dev_testetappe", "from_city": "dev_start", "start_km": 111.0,
			"start_world_minutes": 21.0 * 60.0})
		var img: Image = await _picture_after(sc, 20)
		_save(img, "stadt_nacht_%s" % mode)
		var w := img.get_width()
		var h := img.get_height()
		var hy := 0.45 * float(h)
		var reg := region(img, Rect2i(int(w * 0.2), int(hy) + 60, int(w * 0.6), int(h * 0.92) - int(hy) - 60))
		lum[mode] = float(reg["lum"])
		if mode == "modern":
			var r: Object = sc.get("renderer")
			var lights := 0
			if r is ModernRenderer:
				for part: Dictionary in _parts(r, "city"):
					lights += (part.get("lights", []) as Array).size()
			_need(p, lights >= 10, "Laternen in den geladenen Stücken (%d)" % lights)
		await _free(sc)
	_need(p, float(lum.get("modern", 0.0)) >= 0.9 * float(lum.get("arcade", 1.0)), "Straße in Modern nicht dunkler als in Arcade (%.3f gegen %.3f)" % [
		float(lum.get("modern", 0.0)), float(lum.get("arcade", 0.0))])
	_report("stadt", p, "21 Uhr, City Limits: mittlere Leuchtdichte der Straße Modern %.3f, Arcade %.3f" % [float(lum.get("modern", 0.0)),
		float(lum.get("arcade", 0.0))])


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
