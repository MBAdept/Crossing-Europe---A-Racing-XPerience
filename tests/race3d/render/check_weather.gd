extends SceneTree
## Render checks of the weather of the mode "Modern" (R4; contract §6 R4, §4.9.2, §4.10). Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_weather.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## Every picture: Kiel – Hamburg km 2 (S1) without traffic, HUD hidden, the session stopped after STEPS simulation
## steps and the frozen view drawn again – the same frame with and without a part of the weather (the layers' debug
## switches), so a difference is that part alone.
##   teilchen   rain and snow in the air at every „Effekte“ level (presets „Niedrig“ 0, „Steam Deck“ 1, „Hoch“ 2):
##              the precipitation changes at least MIN_RAIN_PX / MIN_SNOW_PX pixels, more with every level; two
##              pictures of the same frame are identical (stateless particles, Rule 10)
##   gischt     rain, 120 km/h: spray behind the player's car – puffs in the snapshot and pixels that change; at
##              „Effekte: Aus“ one puff per car (Arcade's ellipse)
##   nass       rain at 22:00: the reflections of the player's rear lights lie on the wet road below the car (red
##              pixels that change); rain at noon: the wet road mirrors the sky – the asphalt far ahead is brighter
##              than near the car, more than on a dry road (Fresnel)
##   tunnel     inside a tunnel (test stage km 51.5, rain) nothing falls: the precipitation is hidden
##   tabelle    weather (clear, rain, snow) × hour (6:36, 12:00, 19:12, 22:00): mean luminance and contrast (standard
##              deviation) of the ground below the horizon in Modern against Arcade at the same simulation step – no
##              black frame (mean ≥ 0.02), the mean within LUM_LO … LUM_HI of Arcade's and the contrast at least
##              CONTRAST_LO of Arcade's
##   schneewall N1 (Hamburg – Hannover km 71, 22:00, snow): snow banks along the shoulders in the chunks, at most
##              0.45 m high (they can never hide a car)
## "-- --save=<absolute folder>" keeps the judged pictures; "-- --only=<check>[,…]" runs a subset.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["teilchen", "gischt", "nass", "tunnel", "schneewall", "tabelle"]
const STEPS := 30
const MIN_RAIN_PX := 600
const MIN_SNOW_PX := 300
const LUM_LO := 0.8
const LUM_HI := 1.35
const CONTRAST_LO := 0.5
const PIXEL_STEP := 1.5 / 255.0      ## a pixel counts as changed above this luminance difference

var _failed: Array[String] = []
var _wall0 := 0
var _table: Array[String] = []


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK weather FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	root.get_node("Settings").call("disarm_crash_guard")
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
	print("RENDER-CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _until(cond: Callable, max_frames: int = 4000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _save(img: Image, pic: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir == "" or img == null:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join("weather_" + pic + ".png"))


## Starts a stage (S1 unless `extra` says otherwise) in `mode`, runs it to simulation step STEPS, stops it there and
## hides the HUD. Returns the scene.
func _stage(mode: String, extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": mode}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= STEPS)
	sc.set_process(false)
	sc.set_physics_process(false)
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false        # HUD, pause menu, loading overlay
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## The frozen view drawn again and captured (Modern: render() once more; Arcade draws on its own).
func _shot(sc: Node) -> Image:
	var r: Variant = sc.get("renderer")
	if r is ModernRenderer:
		(r as ModernRenderer).render((r as ModernRenderer).view)
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Pixels whose luminance differs by more than PIXEL_STEP, and of those the ones where `b` is redder than `a`.
static func _diff(a: Image, b: Image, y0: int = 0) -> Vector2i:
	var n := 0
	var red := 0
	for y in range(y0, a.get_height()):
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.get_luminance() - q.get_luminance()) > PIXEL_STEP:
				n += 1
				if q.r - p.r > 0.02 and q.r - p.r > (q.g - p.g) + 0.01:
					red += 1
	return Vector2i(n, red)


## Mean luminance and its standard deviation over the rows below `y0`.
static func _stats(img: Image, y0: int) -> Vector2:
	var s := 0.0
	var s2 := 0.0
	var n := 0
	for y in range(y0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var l := img.get_pixel(x, y).get_luminance()
			s += l
			s2 += l * l
			n += 1
	var m := s / float(maxi(n, 1))
	return Vector2(m, sqrt(maxf(s2 / float(maxi(n, 1)) - m * m, 0.0)))


func _weather_layer(sc: Node) -> Object:
	var r: Variant = sc.get("renderer")
	return (r as ModernRenderer).layer("weather") if r is ModernRenderer else null


# --- teilchen ----------------------------------------------------------------------------------------------------

func _check_teilchen() -> void:
	var p: Array[String] = []
	var parts: Array[String] = []
	for kind: String in ["rain", "snow"]:
		var last := 0
		for preset: String in ["low", "deck", "high"]:
			CliArgs.all()["gfx-preset"] = preset
			var sc: Node = await _stage("modern", {"weather": kind})
			var wl: Object = _weather_layer(sc)
			if wl == null:
				_need(p, false, "%s/%s: Ebene weather" % [kind, preset])
				await _free(sc)
				continue
			var on: Image = await _shot(sc)
			var on2: Image = await _shot(sc)
			wl.set("debug_particles", false)
			var off: Image = await _shot(sc)
			wl.set("debug_particles", true)
			var snap: Dictionary = (wl.call("snapshot") as Dictionary).get("weather", {})
			var d := _diff(off, on)
			var same := _diff(on, on2)
			var need_px := MIN_RAIN_PX if kind == "rain" else MIN_SNOW_PX
			_save(on, "teilchen_%s_%s" % [kind, preset])
			_need(p, bool(snap.get("shown", false)), "%s/%s: Niederschlag gezeigt" % [kind, preset])
			_need(p, d.x >= need_px, "%s/%s: mindestens %d Bildpunkte (%d)" % [kind, preset, need_px, d.x])
			_need(p, d.x > last, "%s/%s: mehr als auf der Stufe davor (%d gegen %d)" % [kind, preset, d.x, last])
			_need(p, same.x == 0, "%s/%s: zweimal dasselbe Bild (%d Bildpunkte verschieden)" % [kind, preset, same.x])
			parts.append("%s %s: %d Teilchen, %d Bildpunkte" % ["Regen" if kind == "rain" else "Schnee", preset, int(snap.get("particles", 0)), d.x])
			last = d.x
			await _free(sc)
	CliArgs.all().erase("gfx-preset")
	_report("teilchen", p, "; ".join(parts))


# --- gischt ------------------------------------------------------------------------------------------------------

func _check_gischt() -> void:
	var p: Array[String] = []
	var parts: Array[String] = []
	for preset: String in ["low", "medium"]:
		CliArgs.all()["gfx-preset"] = preset
		var sc: Node = await _stage("modern", {"weather": "rain"})
		var wl: Object = _weather_layer(sc)
		if wl == null:
			_need(p, false, "Ebene weather")
			await _free(sc)
			continue
		wl.set("debug_particles", false)
		var on: Image = await _shot(sc)
		wl.set("debug_spray", false)
		var off: Image = await _shot(sc)
		wl.set("debug_spray", true)
		wl.set("debug_particles", true)
		var snap: Dictionary = (wl.call("snapshot") as Dictionary).get("weather", {})
		var d := _diff(off, on, 300)
		var puffs := int(snap.get("spray_puffs", 0))
		var sources := int(snap.get("spray_sources", 0))
		_save(on, "gischt_" + preset)
		_need(p, sources >= 1, "%s: das Spielerauto ist eine Quelle (%d)" % [preset, sources])
		if preset == "low":
			_need(p, puffs == sources, "%s: eine Wolke je Auto (%d Wolken, %d Autos)" % [preset, puffs, sources])
		else:
			_need(p, puffs == 3 * sources, "%s: drei Wolken je Auto (%d Wolken, %d Autos)" % [preset, puffs, sources])
		_need(p, d.x >= 150, "%s: die Gischt ist zu sehen (%d Bildpunkte)" % [preset, d.x])
		parts.append("%s: %d Wolken, %d Bildpunkte" % [preset, puffs, d.x])
		await _free(sc)
	CliArgs.all().erase("gfx-preset")
	_report("gischt", p, "S1 Regen, 120 km/h, Spielerauto: " + "; ".join(parts))


# --- nass --------------------------------------------------------------------------------------------------------

func _check_nass() -> void:
	var p: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	# night: the reflections of the player's rear lights
	var sc: Node = await _stage("modern", {"weather": "rain", "start_world_minutes": 22.0 * 60.0})
	var r: ModernRenderer = sc.get("renderer")
	var fl: Object = r.layer("flares")
	var wl: Object = r.layer("weather")
	wl.set("debug_particles", false)
	wl.set("debug_spray", false)
	var on: Image = await _shot(sc)
	fl.set("debug_streaks", false)
	var off: Image = await _shot(sc)
	fl.set("debug_streaks", true)
	var streaks := int(((fl.call("snapshot") as Dictionary).get("lights", {}) as Dictionary).get("wet_streaks", 0))
	var d := _diff(off, on, 360)
	_save(on, "nass_nacht")
	_need(p, streaks >= 2, "nachts: Spiegelungen der Rückleuchten (%d)" % streaks)
	_need(p, d.y >= 80, "nachts: rote Spiegelung auf der Fahrbahn (%d rote von %d Bildpunkten)" % [d.y, d.x])
	await _free(sc)
	# noon: Fresnel – far asphalt brighter than near, more than on the dry road
	var ratio := {}
	for kind: String in ["normal", "rain"]:
		var sd: Node = await _stage("modern", {"weather": kind})
		var rd: ModernRenderer = sd.get("renderer")
		var w2: Object = rd.layer("weather")
		if w2 != null:
			w2.set("debug_particles", false)
			w2.set("debug_spray", false)
		var img: Image = await _shot(sd)
		var near := _lane_mean(rd, img, 14.0, 24.0)
		var far := _lane_mean(rd, img, 150.0, 260.0)
		ratio[kind] = far / maxf(near, 1.0e-3)
		_save(img, "nass_tag_" + kind)
		await _free(sd)
	_need(p, float(ratio.get("rain", 0.0)) > float(ratio.get("normal", 1.0)) * 1.15,
		"Regen am Tag: die Fahrbahn spiegelt zum Horizont hin (fern/nah %.2f gegen trocken %.2f)" % [float(ratio.get("rain", 0.0)), float(ratio.get("normal", 0.0))])
	CliArgs.all().erase("gfx-preset")
	_report("nass", p, "Regen 22 Uhr: %d Spiegelungen, %d rote Bildpunkte; Regen 12 Uhr: Fahrbahn fern/nah %.2f (trocken %.2f)" % [
		streaks, d.y, float(ratio.get("rain", 0.0)), float(ratio.get("normal", 0.0))])


## Mean luminance of the lane interiors between d0 and d1 metres ahead of the camera (the camera model's points).
func _lane_mean(r: ModernRenderer, img: Image, d0: float, d1: float) -> float:
	var cam_z := float(r.view["camera_z"])
	var lw := r.track.lane_w
	var s := 0.0
	var n := 0
	var d := d0
	while d <= d1:
		var seg := r.track.get_segment(int((cam_z + d) / r.track.seg_len))
		var la := -seg.lanes * lw * 0.5
		for i in int(ceil(seg.lanes - 0.01)):
			for off: float in [-0.9, -0.5, 0.5, 0.9]:
				var q := r.world_to_screen(cam_z + d, la + (float(i) + 0.5) * lw + off, 0.0)
				var x := int(q.x)
				var y := int(q.y)
				if q.z > 0.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					s += img.get_pixel(x, y).get_luminance()
					n += 1
		d += maxf(1.5, d * 0.05)
	return s / float(maxi(n, 1))


# --- tunnel ------------------------------------------------------------------------------------------------------

func _check_tunnel() -> void:
	var p: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	var sc: Node = await _stage("modern", {"stage_id": "dev_testetappe", "from_city": "dev_start", "start_km": 51.5, "weather": "rain",
		"vehicle": "limousine", "seed": 17})
	var wl: Object = _weather_layer(sc)
	var snap: Dictionary = (wl.call("snapshot") as Dictionary).get("weather", {}) if wl != null else {}
	var r: Variant = sc.get("renderer")
	var in_tunnel := bool((r as ModernRenderer).view.get("camera_in_tunnel", false)) if r is ModernRenderer else false
	_need(p, in_tunnel, "die Kamera steht im Tunnel")
	_need(p, not bool(snap.get("shown", true)) and float(snap.get("fade", 1.0)) <= 0.001, "im Tunnel fällt nichts (%s)" % str(snap))
	_need(p, int(snap.get("spray_puffs", -1)) == 0, "im Tunnel keine Gischt")
	await _free(sc)
	CliArgs.all().erase("gfx-preset")
	_report("tunnel", p, "Teststrecke km 51,5, Regen: Niederschlag aus, Ausblendung %.3f" % float(snap.get("fade", -1.0)))


# --- schneewall --------------------------------------------------------------------------------------------------

func _check_schneewall() -> void:
	var p: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	var sc: Node = await _stage("modern", {"stage_id": "hamburg_hannover", "from_city": "hamburg", "start_km": 71.0, "weather": "snow",
		"vehicle": "kompakt", "seed": 13, "start_world_minutes": 22.0 * 60.0})
	var r: ModernRenderer = sc.get("renderer")
	var banks := 0
	var chunks := 0
	for c: Dictionary in r.debug_snapshot().get("chunks", []):
		var t: Dictionary = (c.get("parts", {}) as Dictionary).get("terrain", {})
		if not t.is_empty():
			chunks += 1
			banks += int(t.get("bank_tris", 0))
	var tb: Object = r.builder("terrain")
	var hmax := 0.0
	if tb != null:
		for k in 2000:
			hmax = maxf(hmax, float(tb.call("bank_height", k)))
	_need(p, banks > 0, "Schneewälle in den Stücken (%d Dreiecke in %d Stücken)" % [banks, chunks])
	_need(p, hmax <= 0.45 + 1.0e-4, "höchstens 0,45 m hoch (%.3f m)" % hmax)
	var img: Image = await _shot(sc)
	_save(img, "schneewall_n1")
	await _free(sc)
	CliArgs.all().erase("gfx-preset")
	_report("schneewall", p, "N1: %d Dreiecke Schneewall in %d Stücken, höchstens %.2f m" % [banks, chunks, hmax])


# --- tabelle -----------------------------------------------------------------------------------------------------

func _check_tabelle() -> void:
	var p: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	for kind: String in ["normal", "rain", "snow"]:
		for hour: float in [6.6, 12.0, 19.2, 22.0]:
			var extra := {"weather": kind, "start_world_minutes": hour * 60.0}
			var sa: Node = await _stage("arcade", extra)
			var ia: Image = await _shot(sa)
			await _free(sa)
			var sm: Node = await _stage("modern", extra)
			var rm: Variant = sm.get("renderer")
			var hy := int((rm as ModernRenderer).proj.horizon_y) + 4 if rm is ModernRenderer else 330
			var wl: Object = _weather_layer(sm)
			if wl != null:
				wl.set("debug_particles", false)     # the table compares the ground; the particles are "teilchen"
			var im: Image = await _shot(sm)
			await _free(sm)
			var a := _stats(ia, hy)
			var m := _stats(im, hy)
			var ratio := m.x / maxf(a.x, 1.0e-3)
			var con := m.y / maxf(a.y, 1.0e-3)
			var tag := "%s %05.2f" % [kind, hour]
			_save(im, "tabelle_%s_%02d_modern" % [kind, int(hour * 10.0)])
			_save(ia, "tabelle_%s_%02d_arcade" % [kind, int(hour * 10.0)])
			_table.append("%s: Modern %.3f ± %.3f, Arcade %.3f ± %.3f (%.2f×, Kontrast %.2f×)" % [tag, m.x, m.y, a.x, a.y, ratio, con])
			_need(p, m.x >= 0.02, "%s: kein schwarzes Bild (%.3f)" % [tag, m.x])
			_need(p, ratio >= LUM_LO and ratio <= LUM_HI, "%s: Helligkeit %.2f× Arcade (%.2f … %.2f)" % [tag, ratio, LUM_LO, LUM_HI])
			_need(p, con >= CONTRAST_LO, "%s: Kontrast %.2f× Arcade (mindestens %.2f)" % [tag, con, CONTRAST_LO])
	CliArgs.all().erase("gfx-preset")
	_report("tabelle", p, "Boden unter dem Horizont, S1 „Mittel“: " + "; ".join(_table))
