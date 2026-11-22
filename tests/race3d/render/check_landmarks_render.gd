extends SceneTree
## render-check-timeout: 1500
## Render check of the landmarks of the mode "Modern" (package R7b, builders/landmarks.gd, landmark.gdshader) – it
## needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_landmarks_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## A landmark's pixels are found by drawing the same paused frame twice – with the landmark nodes and without them.
##   wahrzeichen_stelle  Kiel – Hamburg km 85.6, 12:00 (the Elbphilharmonie about 600 m ahead): its pixels in the
##                       Modern picture are found in Arcade's picture of the same simulation state (the best match of
##                       the Modern pixels, shifted across the Arcade frame) no further than 5 % of the frame width
##                       away (contract §6 wave 5, acceptance of R7)
##   wahrzeichen_weich   km 76 (the Elbphilharmonie about 1,560 m ahead, in the last 28 % of its range): it fades
##                       softly – its difference picture has no dither pattern (the change between neighbouring pixels
##                       stays well below the change itself; an ordered dither changes from pixel to pixel)
##   wahrzeichen_nacht   km 77.4, 22:00: beyond the night's sight its illumination stays (bright pixels)
##   flugfeuer           Bremen – Dortmund km 225, 22:00: the Florianturm (3D shape of Arcade's TV tower) shows its red
##                       aviation lights as small glows – some red pixels, and the landmark changes only a small part
##                       of the picture (the first glows covered the whole sky in red: VIEWPORT_SIZE reads 0 in the
##                       vertex stage of the Compatibility renderer)
## "-- --save=<absolute folder>" keeps the pictures. (Scripts started with -s compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const STEPS := 30
const DIFF_MIN := 14                  ## a pixel belongs to the landmark when a channel changes by this much (0..255)
const MAX_SHIFT_SHARE := 0.05
const MAX_HF := 0.6                   ## dither: about 1 or more; a soft fade: far below

var _failed: Array[String] = []
var _save := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK wahrzeichen_stelle FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	root.get_node("Settings").call("disarm_crash_guard")
	_save = str(CliArgs.all().get("save", ""))
	CliArgs.all().erase("graphics")
	await _check_stelle()
	await _check_weich()
	await _check_nacht()
	await _check_flugfeuer()
	root.get_node("Settings").call("disarm_crash_guard")
	print("RENDER-CHECKS %s  (%d fehlgeschlagen)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-18s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _launch(mode: String, extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 85.6, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": mode, "no_countdown": true, "start_speed_kmh": 0.0, "traffic_warmup": false}
	setup.merge(extra, true)
	CliArgs.all()["no-traffic"] = true
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	paused = false
	sc.queue_free()
	await process_frame
	await process_frame
	CliArgs.all().erase("no-traffic")
	CliArgs.all().erase("gfx-sync")
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _hide_hud(sc: Node) -> void:
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false


## Waits until the stage is live and STEPS simulation steps have run (HUD hidden).
func _settle(sc: Node) -> void:
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		_hide_hud(sc)
		await process_frame
		n += 1
	var s0 := int(sc.get("_sim_steps"))
	n = 0
	while int(sc.get("_sim_steps")) < s0 + STEPS and n < 6000:
		_hide_hud(sc)
		await process_frame
		n += 1
	_hide_hud(sc)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## The paused Modern frame with and without the landmark nodes: [with, without, live landmarks of the snapshot].
func _modern_pair(extra: Dictionary) -> Array:
	var sc: Node = await _launch("modern", extra)
	await _settle(sc)
	var r: Object = sc.get("renderer")
	paused = true
	for i in 2:
		await process_frame
	var with := await _grab()
	var nodes: Array = []
	var world: Node = r.get("world")
	for c: Node in world.get_children():
		if str(c.name).begins_with("Landmark") and (c as Node3D).visible:
			(c as Node3D).visible = false
			nodes.append(c)
	await process_frame
	var without := await _grab()
	var b: Object = r.call("builder", "landmarks")
	var live: Array = ((b.call("snapshot") as Dictionary).get("landmarks", []) as Array) if b != null else []
	await _free(sc)
	return [with, without, live, nodes.size()]


## Pixels where `a` and `b` differ: [mask (PackedByteArray), bbox Rect2i, count, per-pixel difference (PackedFloat32Array)].
static func _diff(a: Image, b: Image) -> Array:
	var w := a.get_width()
	var h := a.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	var d := PackedFloat32Array()
	d.resize(w * h)
	var da := a.get_data()
	var db := b.get_data()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	var n := 0
	for y in h:
		for x in w:
			var i := (y * w + x) * 3
			var m := maxi(absi(da[i] - db[i]), maxi(absi(da[i + 1] - db[i + 1]), absi(da[i + 2] - db[i + 2])))
			d[y * w + x] = float(m)
			if m >= DIFF_MIN:
				mask[y * w + x] = 1
				n += 1
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return [mask, Rect2i(x0, y0, maxi(0, x1 - x0 + 1), maxi(0, y1 - y0 + 1)), n, d]


func _save_img(img: Image, name: String) -> void:
	if _save != "":
		DirAccess.make_dir_recursive_absolute(_save)
		img.save_png(_save.path_join(name + ".png"))


func _check_stelle() -> void:
	var p: Array[String] = []
	var pair: Array = await _modern_pair({})
	var with: Image = pair[0]
	var dm: Array = _diff(with, pair[1])
	var box: Rect2i = dm[1]
	_need(p, int(dm[2]) >= 200, "Elbphilharmonie im Bild (%d Pixel)" % int(dm[2]))
	# Arcade, same simulation state
	var sc: Node = await _launch("arcade", {})
	await _settle(sc)
	var arc := await _grab()
	await _free(sc)
	_save_img(with, "stelle_modern")
	_save_img(arc, "stelle_arcade")
	var w := with.get_width()
	var best := Vector2i.ZERO
	var best_e := INF
	if int(dm[2]) >= 200:
		var mask: PackedByteArray = dm[0]
		var dm_w := with.get_data()
		var da := arc.get_data()
		var pts := PackedInt32Array()
		for y in range(box.position.y, box.end.y, 2):
			for x in range(box.position.x, box.end.x, 2):
				if mask[y * w + x] == 1:
					pts.append(x)
					pts.append(y)
		var h := with.get_height()
		for dy in range(-8, 9, 2):
			for dx in range(-96, 97, 2):
				var e := 0.0
				var cnt := 0
				for k in range(0, pts.size(), 2):
					var x := pts[k] + dx
					var y := pts[k + 1] + dy
					if x < 0 or x >= w or y < 0 or y >= h:
						continue
					var i := (pts[k + 1] * w + pts[k]) * 3
					var j := (y * w + x) * 3
					e += absf(float(dm_w[i]) - float(da[j])) + absf(float(dm_w[i + 1]) - float(da[j + 1])) + absf(float(dm_w[i + 2]) - float(da[j + 2]))
					cnt += 1
				if cnt > 0 and e / float(cnt) < best_e:
					best_e = e / float(cnt)
					best = Vector2i(dx, dy)
	_need(p, absf(float(best.x)) <= MAX_SHIFT_SHARE * float(w), "an Arcades Stelle (Versatz %d px, höchstens %.0f)" % [best.x, MAX_SHIFT_SHARE * float(w)])
	_report("wahrzeichen_stelle", p, "km 85,6: %d Pixel um %s, in Arcades Bild bei Versatz (%d, %d) px (mittlere Abweichung %.1f)" % [
		int(dm[2]), str(box), best.x, best.y, best_e])


func _check_weich() -> void:
	var p: Array[String] = []
	var pair: Array = await _modern_pair({"start_km": 76.0})
	var dm: Array = _diff(pair[0], pair[1])
	_save_img(pair[0], "weich_modern")
	var live: Array = pair[2]
	var blend := 0
	for e: Dictionary in live:
		if bool(e.get("blend", false)) and bool(e.get("visible", false)):
			blend += 1
	_need(p, blend >= 1, "ein Wahrzeichen im Ausblendbereich mit durchscheinendem Material (%d)" % blend)
	var box: Rect2i = dm[1]
	var d: PackedFloat32Array = dm[3]
	var w := (pair[0] as Image).get_width()
	var sum := 0.0
	var hf := 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x - 1):
			var v := d[y * w + x]
			sum += v
			hf += absf(v - d[y * w + x + 1])
	var ratio := hf / maxf(sum, 1.0)
	_need(p, int(dm[2]) >= 30, "das ausblendende Wahrzeichen ist noch zu sehen (%d Pixel)" % int(dm[2]))
	_need(p, ratio <= MAX_HF, "weich statt gerastert (Wechsel zwischen Nachbarpixeln %.2f der Änderung, höchstens %.2f)" % [ratio, MAX_HF])
	_report("wahrzeichen_weich", p, "km 76: %d Pixel, Nachbarwechsel %.2f der Änderung (geordnetes Raster ≈ 1)" % [int(dm[2]), ratio])


func _check_nacht() -> void:
	var p: Array[String] = []
	var pair: Array = await _modern_pair({"start_km": 77.4, "start_world_minutes": 22.0 * 60.0})
	_save_img(pair[0], "nacht_modern")
	var dm: Array = _diff(pair[0], pair[1])
	var img: Image = pair[0]
	var mask: PackedByteArray = dm[0]
	var w := img.get_width()
	var data := img.get_data()
	var bright := 0
	for i in mask.size():
		if mask[i] == 1:
			var lum := 0.2126 * float(data[i * 3]) + 0.7152 * float(data[i * 3 + 1]) + 0.0722 * float(data[i * 3 + 2])
			if lum >= 140.0:
				bright += 1
	var far := 0
	for e: Dictionary in (pair[2] as Array):
		if float(e.get("keep", 1.0)) < 0.01 and float(e.get("lights", 0.0)) > 0.1:
			far += 1
	_need(p, far >= 1, "ein Wahrzeichen jenseits der Sicht nur mit seiner Beleuchtung (%d)" % far)
	_need(p, bright >= 12, "seine Beleuchtung leuchtet (%d helle Pixel)" % bright)
	_report("wahrzeichen_nacht", p, "22 Uhr km 77,4: %d Wahrzeichen nur beleuchtet, %d helle Pixel von %d (Bild %d breit)" % [far, bright, int(dm[2]), w])


func _check_flugfeuer() -> void:
	var p: Array[String] = []
	var pair: Array = await _modern_pair({"stage_id": "bremen_dortmund", "from_city": "bremen", "start_km": 225.0,
		"start_world_minutes": 22.0 * 60.0})
	_save_img(pair[0], "flugfeuer_modern")
	var dm: Array = _diff(pair[0], pair[1])
	var img: Image = pair[0]
	var total := img.get_width() * img.get_height()
	var mask: PackedByteArray = dm[0]
	var data := img.get_data()
	var red := 0
	for i in mask.size():
		if mask[i] == 1 and data[i * 3] >= 150 and data[i * 3] > 2 * data[i * 3 + 1] and data[i * 3] > 2 * data[i * 3 + 2]:
			red += 1
	var share := float(int(dm[2])) / float(total)
	_need(p, red >= 3, "rote Flugwarnlichter zu sehen (%d rote Pixel)" % red)
	_need(p, share <= 0.03, "das Wahrzeichen ändert nur einen kleinen Teil des Bildes (%.2f %%)" % (share * 100.0))
	_report("flugfeuer", p, "Florianturm 22 Uhr: %d rote Pixel, Wahrzeichen %.2f %% des Bildes (%d Pixel, um %s)" % [red, share * 100.0, int(dm[2]), str(dm[1])])


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)
