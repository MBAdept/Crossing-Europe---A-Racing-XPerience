extends SceneTree
## Render checks of tunnels and bridges of the mode "Modern" (v0.8.0, package R5 – lead decisions of wave 3; German
## docs: docs/renderer-modern-tunnel-bruecken.md) – they need a real renderer and a fixed frame rate:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_tunnel_bridge.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## A still stage (no autopilot, no traffic, HUD hidden) at each position:
##   U1_portal       Bern – Mailand, 60 m before the Gotthard portal (km 185), --gfx-debug=cover: portal, frame and hill
##                   close the terrain – magenta (nothing drawn) at most 0.2 % of the pixels below the horizon row
##   U1_innen        300 m inside (km 188), cover: no sky anywhere – magenta at most 0.2 % of the whole picture; the
##                   lamps are lit (bright lamp pixels above the horizon row); the tube is neither black nor white
##   U1_ausfahrt     60 m before the exit (km 201.3), normal picture: the exit opening (projected from the tunnel's end)
##                   is over-exposed like Arcade's (RoadRenderer: ambient × 1.7 + 0.25 – the outside reads L ≈ 227/255
##                   in Arcade, EXIT_ARCADE): its mean luminance at least EXIT_MIN_SHARE of Arcade's (RINT-M2; R5 alone
##                   showed 69/255 there), not blown out (at most EXIT_MAX, less than half pure white); and the exit
##                   frame of the tunnel builder at the true end of the tube does not glow with it (mean of its upper
##                   beam at most FRAME_MAX – the glare quad stood in front of it before, L 244, QR5-03)
##   Somport_portal  Saragossa – Pau, 70 m before the Somport portal (km 177), cover: as U1_portal
##   B1              Frankfurt – Köln, Severinsbrücke from its ramp (km 186.2), --gfx-debug=cover,far: nothing open below
##                   the horizon (magenta ≤ 0.2 %), the far-ground plane does not cover the Rhine (cyan ≤ 2 %), the
##                   bridge builder built water
##   beacon          Kiel – Hamburg km 76.4 at 22:00 (the pylon tops 230 and 350 m ahead, in the picture): the aviation
##                   lights of the Köhlbrandbrücke blink in Arcade's rhythm – over 2.4 s every beacon is lit in some
##                   frames and dark in others (the flare layer's list) and the picture shows its red where it is lit
##   ausfahrt_schnee Prag – Nürnberg, Tunel Valík at 8:00 in snow, the car drives out at 80 km/h (FIX-RINT, QA-RINT-BILD
##                   F-01); ausfahrt_trocken the Gotthard exit at noon at 100 km/h: for 2 s after the camera passed the
##                   exit Modern is not washed out (pure white at most Arcade's + 5 points in every picture) and shows
##                   the snow Arcade shows (no frames of snow-free land) – see exit_after below
## "-- --only=U1_portal,B1" runs some positions, "-- --save=<absolute folder>" keeps the pictures.
## "-- --full" (no picture, --headless is enough; about 3 min): builds EVERY bridge and EVERY tunnel of the network
## – each direction of each stage and of the dev stage – with builders/bridge.gd and builders/tunnel.gd as the unit
## tests do (no renderer) and compares each EXACTLY with Arcade's elements of the same track: pylons, aviation lights,
## 14 cables per pylon, truss portals and bridge lamps = Arcade's events, banks at both ends, water, per type truss /
## arches / piers; a tunnel's portal, exit frame, cap, SOS niches (Arcade's 150-m rule) and lamp rows; nothing of the
## structure or the tube over a lane below 4.5 m, no cable within 1.5 m of a lane, no portal hill in the approach's
## sight corridor (see _full_scan). "-- --only-stage=<ids>" scans some stages, "-- --verbose" prints every element.
## Prints "RENDER-CHECK tunnel_bridge_full OK|FEHLER" and one "MANGEL" line per element with a defect.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const COVER_LIMIT := 0.002          ## magenta share (below the horizon row / of the whole picture inside a tunnel)
const CYAN_LIMIT := 0.02            ## far-ground share below the horizon row at a river (FIX-WASSER, K1)
const LAMP_LUM := 0.8               ## a lamp pixel …
const LAMP_MIN_PX := 40             ## … and at least this many of them above the horizon row inside the tube
const TUBE_MIN := 0.06              ## mean luminance of the picture inside the tube: not black …
const TUBE_MAX := 0.6               ## … and not white
const EXIT_ARCADE := 0.89          ## Arcade's outside seen through the exit at U1, 12:00 (L 227/255, measured by FIX-R5)
const EXIT_MIN_SHARE := 0.6         ## the opening at least this share of it (RINT-M2: measured 0.66 with the glare)
const EXIT_MIN := EXIT_ARCADE * EXIT_MIN_SHARE   ## mean luminance of the exit opening: over-exposed as Arcade's …
const FRAME_MAX := 0.8              ## the exit frame's upper beam: not burnt white by the glare (concrete ~0.53)
const EXIT_MAX := 0.95              ## … not blown out
const EXIT_WHITE_MAX := 0.5         ## share of pure white pixels in the opening
const POSITIONS: Array = [
	{"id": "U1_portal", "stage": "bern_mailand", "from": "bern", "km": 184.4, "hour": 12.0, "seed": 16, "debug": "cover", "kind": "portal"},
	{"id": "U1_innen", "stage": "bern_mailand", "from": "bern", "km": 188.0, "hour": 12.0, "seed": 16, "debug": "cover", "kind": "inside"},
	{"id": "U1_ausfahrt", "stage": "bern_mailand", "from": "bern", "km": 201.3, "hour": 12.0, "seed": 16, "debug": "", "kind": "exit"},
	{"id": "Somport_portal", "stage": "saragossa_pau", "from": "saragossa", "km": 176.3, "hour": 12.0, "seed": 4, "debug": "cover", "kind": "portal"},
	{"id": "B1", "stage": "frankfurt_koeln", "from": "frankfurt", "km": 186.2, "hour": 12.0, "seed": 11, "debug": "cover,far", "kind": "water"},
	{"id": "beacon", "stage": "kiel_hamburg", "from": "kiel", "km": 76.4, "hour": 22.0, "seed": 11, "debug": "", "kind": "beacon"},
	# FIX-RINT (QA-RINT-BILD F-01): driving out of a tube by day, in snow and dry – Arcade and Modern of the same steps
	{"id": "ausfahrt_schnee", "stage": "prag_nuernberg", "from": "prag", "km": 87.7, "hour": 8.0, "seed": 22, "debug": "", "kind": "exit_after",
		"weather": "snow", "speed": 80.0},
	{"id": "ausfahrt_trocken", "stage": "bern_mailand", "from": "bern", "km": 201.0, "hour": 12.0, "seed": 16, "debug": "", "kind": "exit_after",
		"weather": "normal", "speed": 100.0},
]
## exit_after (FIX-RINT, QA-RINT-BILD F-01): the car drives out of the tube at `speed`; from the step the camera passes
## the exit, every AFTER_EVERY steps for AFTER_STEPS steps (2 s), the picture of Arcade and of Modern of the same step.
## In the scene band (rows 25–80 %, below the HUD boxes, above the speedometer) Modern shows at most Arcade's share of
## pure white pixels (≥ 240/255 in every channel) + AFTER_WHITE_PLUS (snow: 65–68 % against Arcade's 0.3 % before),
## and where Arcade shows snow at least AFTER_SNOW_MIN of Arcade's share of snow pixels (bright, nearly grey – 3 frames
## of brown snow-free land after the exit before).
const AFTER_STEPS := 120
const AFTER_EVERY := 6
const AFTER_WHITE_PLUS := 0.05
const AFTER_SNOW_MIN := 0.5

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if CliArgs.all().has("full"):
		_full_scan()
		return
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK tunnel_bridge FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	var only := str(cli.get("only", ""))
	var had_traffic := cli.has("no-traffic")
	var before: Variant = cli.get("gfx-debug")
	cli["no-traffic"] = true
	for pos: Dictionary in POSITIONS:
		if only == "" or only.split(",").has(str(pos["id"])):
			if str(pos["debug"]) == "":
				cli.erase("gfx-debug")
			else:
				cli["gfx-debug"] = str(pos["debug"])
			await _check(pos)
	if before == null:
		cli.erase("gfx-debug")
	else:
		cli["gfx-debug"] = before
	if not had_traffic:
		cli.erase("no-traffic")
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-22s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _until(cond: Callable, max_frames: int = 3000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _keep(img: Image, pic_name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("tunnel_bridge_%s.png" % pic_name))


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _magenta(c: Color) -> bool:
	return c.r > 0.85 and c.b > 0.85 and c.g < 0.15


static func _cyan(c: Color) -> bool:
	return c.r < 0.15 and c.g > 0.85 and c.b > 0.85


func _check(pos: Dictionary) -> void:
	var name := "tunnel_bridge_%s" % str(pos["id"])
	if str(pos["kind"]) == "exit_after":
		await _check_exit_after(name, pos)
		return
	var setup := {"mode": "single", "race_id": "", "stage_id": str(pos["stage"]), "from_city": str(pos["from"]),
		"vehicle": "limousine", "start_world_minutes": float(pos["hour"]) * 60.0, "weather": "normal",
		"start_km": float(pos["km"]), "autopilot": false, "seed": int(pos["seed"]), "gfx": "modern", "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	var r: Variant = sc.get("renderer")
	if not (r is Node) or not (r as Node).has_method(&"is_prepared"):
		_report(name, ["die Etappe läuft nicht im Modus Modern"] as Array[String], "")
		await _free(sc)
		return
	await _until(func() -> bool: return not is_instance_valid(r) or bool((r as Node).call(&"is_prepared")))
	r = sc.get("renderer")
	if not (r is Node) or not bool((r as Node).call(&"healthy")):
		_report(name, ["Modern ist auf Arcade zurückgefallen"] as Array[String], "")
		await _free(sc)
		return
	var renderer: Node = r
	await _frames(8)
	match str(pos["kind"]):
		"portal":
			await _check_portal(name, renderer, pos)
		"inside":
			await _check_inside(name, renderer, pos)
		"exit":
			await _check_exit(name, renderer, pos)
		"water":
			await _check_water(name, renderer, pos)
		"beacon":
			await _check_beacon(name, renderer, pos)
	await _free(sc)


func _free(sc: Node) -> void:
	Engine.time_scale = 1.0
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## Horizon row of the picture (pixels) – the camera's own rule (RoadProjection).
func _horizon(renderer: Node, h: int) -> int:
	var proj: RoadProjection = renderer.get("proj")
	return int(round(proj.horizon_y / maxf(1.0, proj.screen.y) * float(h)))


## Shares of magenta (canvas) and cyan (far ground) pixels in the rows [y0, y1).
static func _shares(img: Image, y0: int, y1: int) -> Vector2:
	var n := 0
	var mag := 0
	var cy := 0
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			n += 1
			if _magenta(c):
				mag += 1
			elif _cyan(c):
				cy += 1
	return Vector2(float(mag), float(cy)) / float(maxi(n, 1))


func _check_portal(name: String, renderer: Node, pos: Dictionary) -> void:
	var p: Array[String] = []
	if renderer.call(&"builder", "tunnel") == null:
		p.append("builders/tunnel.gd fehlt")
	var img := await _capture()
	_keep(img, str(pos["id"]))
	var hz := _horizon(renderer, img.get_height())
	var below := _shares(img, hz + 1, img.get_height())
	var sky := _shares(img, 4, maxi(5, hz - 200))
	if sky.x < 0.2:
		p.append("über dem Hügel ist die Leinwand nicht magenta (%.0f %%): die Debug-Ansicht „cover“ ist nicht aktiv" % (100.0 * sky.x))
	if below.x > COVER_LIMIT:
		p.append("%.3f %% Magenta unter der Horizontzeile (höchstens %.1f %%): Portal und Hügel schließen das Gelände nicht" % [100.0 * below.x, 100.0 * COVER_LIMIT])
	_report(name, p, "%s km %.1f: unter dem Horizont %.3f %% Magenta" % [str(pos["stage"]), float(pos["km"]), 100.0 * below.x])


func _check_inside(name: String, renderer: Node, pos: Dictionary) -> void:
	var p: Array[String] = []
	var img := await _capture()
	_keep(img, str(pos["id"]))
	var hz := _horizon(renderer, img.get_height())
	var all := _shares(img, 0, img.get_height())
	var lamps := 0
	var lum_sum := 0.0
	var n := 0
	for y in img.get_height():
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if _magenta(c):
				continue
			var l := _lum(c)
			lum_sum += l
			n += 1
			if y < hz and l > LAMP_LUM:
				lamps += 1
	var mean := lum_sum / float(maxi(n, 1))
	if all.x > COVER_LIMIT:
		p.append("%.3f %% Magenta im ganzen Bild (höchstens %.1f %%): Himmel in der Röhre" % [100.0 * all.x, 100.0 * COVER_LIMIT])
	if lamps < LAMP_MIN_PX / 2:
		p.append("nur %d helle Leuchtenpunkte über der Horizontzeile (mindestens %d)" % [lamps * 2, LAMP_MIN_PX])
	if mean < TUBE_MIN or mean > TUBE_MAX:
		p.append("mittlere Leuchtdichte %.3f außerhalb %.2f–%.2f" % [mean, TUBE_MIN, TUBE_MAX])
	var st: Dictionary = (renderer.call(&"debug_snapshot") as Dictionary).get("tunnel", {})
	if not bool(st.get("inside", false)):
		p.append("tunnel_state meldet die Kamera nicht im Tunnel")
	_report(name, p, "%s km %.1f: %.3f %% Magenta im Bild, %d Leuchtenpunkte, Leuchtdichte %.3f, Zone %.2f" % [str(pos["stage"]),
		float(pos["km"]), 100.0 * all.x, lamps * 2, mean, float(st.get("zone", -1.0))])


func _check_exit(name: String, renderer: Node, pos: Dictionary) -> void:
	var p: Array[String] = []
	var track: Track = renderer.get("track")
	var path: RoadPath3D = renderer.get("path")
	var cam: Camera3D = renderer.get("camera")
	var t := track.plan.tunnel_at(float(pos["km"]))
	if t.is_empty():
		_report(name, ["kein Tunnel bei km %.1f" % float(pos["km"])] as Array[String], "")
		return
	var z_exit := track.km_to_z(float(t["end_km"]))
	var img := await _capture()
	_keep(img, str(pos["id"]))
	# the opening on the screen: the wall feet and the ceiling at the exit, shrunk by a quarter (frame, walkways)
	var lo := cam.unproject_position(path.world(z_exit, -4.5, 0.4))
	var ro := cam.unproject_position(path.world(z_exit, 4.5, 0.4))
	var top := cam.unproject_position(path.world(z_exit, 0.0, 5.0))
	var rect := Rect2(Vector2(minf(lo.x, ro.x), top.y), Vector2(absf(ro.x - lo.x), maxf(lo.y, ro.y) - top.y)).abs()
	rect = rect.grow_individual(-rect.size.x * 0.15, -rect.size.y * 0.15, -rect.size.x * 0.15, -rect.size.y * 0.15)
	rect = rect.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var n := 0
	var white := 0
	var sum := 0.0
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			var c := img.get_pixel(x, y)
			sum += _lum(c)
			n += 1
			if c.r > 0.98 and c.g > 0.98 and c.b > 0.98:
				white += 1
	# the tube around it: two bands beside the opening, on the walls
	var wall := 0.0
	var wn := 0
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in [int(rect.position.x - rect.size.x * 0.9), int(rect.end.x + rect.size.x * 0.9)]:
			if x >= 0 and x < img.get_width():
				wall += _lum(img.get_pixel(x, y))
				wn += 1
	var mean := sum / float(maxi(n, 1))
	var wall_mean := wall / float(maxi(wn, 1))
	# the exit frame (builders/tunnel.gd: from the true end of the tube − 0.35 m to it; its upper beam above the opening)
	var z_tube := ceilf(z_exit / track.seg_len - 1.0e-6) * track.seg_len
	var fa := cam.unproject_position(path.world(z_tube - 0.2, -2.5, 5.25))
	var fb := cam.unproject_position(path.world(z_tube - 0.2, 2.5, 5.55))
	var frect := Rect2(Vector2(minf(fa.x, fb.x), minf(fa.y, fb.y)), Vector2(absf(fb.x - fa.x), maxf(absf(fb.y - fa.y), 2.0)))
	frect = frect.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var fsum := 0.0
	var fn := 0
	for y in range(int(frect.position.y), int(ceil(frect.end.y))):
		for x in range(int(frect.position.x), int(frect.end.x)):
			fsum += _lum(img.get_pixel(x, y))
			fn += 1
	var frame_mean := fsum / float(maxi(fn, 1))
	if fn >= 10 and frame_mean > FRAME_MAX:
		p.append("der Ausfahrtsrahmen glüht mit (Leuchtdichte %.3f, höchstens %.2f)" % [frame_mean, FRAME_MAX])
	if n < 200:
		p.append("die Ausfahrt ist nicht im Bild (%d Bildpunkte)" % n)
	if mean < EXIT_MIN:
		p.append("Ausfahrt nicht überstrahlt wie bei Arcade (Leuchtdichte %.3f, mindestens %.2f = %.0f %% von Arcades %.2f)" % [mean,
			EXIT_MIN, EXIT_MIN_SHARE * 100.0, EXIT_ARCADE])
	if mean > EXIT_MAX or float(white) / float(maxi(n, 1)) > EXIT_WHITE_MAX:
		p.append("Ausfahrt ausgebrannt (Leuchtdichte %.3f, %.0f %% reines Weiß)" % [mean, 100.0 * float(white) / float(maxi(n, 1))])
	_report(name, p, "%s km %.1f: Ausfahrt %d Bildpunkte, Leuchtdichte %.3f = %.2f × Arcade (Röhre daneben %.3f), %.1f %% reines Weiß; Rahmen %.3f (%d Bildpunkte)" % [
		str(pos["stage"]), float(pos["km"]), n, mean, mean / EXIT_ARCADE, wall_mean, 100.0 * float(white) / float(maxi(n, 1)), frame_mean, fn])


## FIX-RINT (QA-RINT-BILD F-01): Arcade and Modern of the same simulation steps after a tunnel exit (exit_after above).
func _check_exit_after(name: String, pos: Dictionary) -> void:
	var p: Array[String] = []
	var a: Array = await _after_series(pos, "arcade")
	var m: Array = await _after_series(pos, "modern")
	if a.is_empty() or m.is_empty() or a.size() != m.size():
		_report(name, ["keine Bildreihe nach der Ausfahrt (Arcade %d, Modern %d Bilder)" % [a.size(), m.size()]] as Array[String], "")
		return
	var worst_white := -1.0
	var worst_snow := 1.0e9
	var line := PackedStringArray()
	for i in a.size():
		var sa: Vector2 = a[i]
		var sm: Vector2 = m[i]
		worst_white = maxf(worst_white, sm.x - sa.x)
		if sa.y > 0.05:
			worst_snow = minf(worst_snow, sm.y / sa.y)
		line.append("%.2f/%.2f" % [sa.x, sm.x])
		if sm.x > sa.x + AFTER_WHITE_PLUS:
			p.append("Bild %d (%.1f s nach der Ausfahrt): %.1f %% reines Weiß gegen Arcades %.1f %%" % [i, float(i * AFTER_EVERY) / 60.0,
				100.0 * sm.x, 100.0 * sa.x])
		if sa.y > 0.05 and sm.y < AFTER_SNOW_MIN * sa.y:
			p.append("Bild %d (%.1f s nach der Ausfahrt): Schnee %.1f %% gegen Arcades %.1f %%" % [i, float(i * AFTER_EVERY) / 60.0,
				100.0 * sm.y, 100.0 * sa.y])
	_report(name, p, "%s km %.1f, %s: %d Bilder in 2 s nach der Ausfahrt, reines Weiß Arcade/Modern %s; höchstens +%.1f Punkte, Schnee mindestens %.2f × Arcade" % [
		str(pos["stage"]), float(pos["km"]), str(pos["weather"]), a.size(), " ".join(line), 100.0 * worst_white,
		worst_snow if worst_snow < 1.0e8 else -1.0])


## The pictures of one mode after the exit: per picture Vector2(share of pure white, share of snow) of the scene band.
func _after_series(pos: Dictionary, mode: String) -> Array:
	var setup := {"mode": "single", "race_id": "", "stage_id": str(pos["stage"]), "from_city": str(pos["from"]),
		"vehicle": "limousine", "start_world_minutes": float(pos["hour"]) * 60.0, "weather": str(pos["weather"]),
		"start_km": float(pos["km"]), "autopilot": true, "start_speed_kmh": float(pos["speed"]), "seed": int(pos["seed"]),
		"gfx": mode, "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	var out: Array = []
	if mode == "modern":
		var r: Variant = sc.get("renderer")
		if not (r is Node) or not (r as Node).has_method(&"is_prepared"):
			await _free(sc)
			return out
		await _until(func() -> bool: return not is_instance_valid(r) or bool((r as Node).call(&"is_prepared")))
		r = sc.get("renderer")
		if not (r is Node) or not bool((r as Node).call(&"healthy")):
			await _free(sc)
			return out
	var track: Track = sc.get("track")
	var proj: RoadProjection = sc.get("proj")
	var t := track.plan.tunnel_at(float(pos["km"]) + 0.05)
	if t.is_empty():
		for tt: Dictionary in track.plan.tunnels:
			if float(tt["end_km"]) > float(pos["km"]):
				t = tt
				break
	if t.is_empty():
		await _free(sc)
		return out
	var z_exit := track.km_to_z(float(t["end_km"]))
	# until the camera passes the exit (the session's camera stands cam_distance behind the car)
	await _until(func() -> bool: return float(sc.get("pos_z")) - proj.cam_distance >= z_exit, 4000)
	var step0 := int(sc.get("_sim_steps"))
	var next := step0
	while next <= step0 + AFTER_STEPS:
		await _until(func() -> bool: return int(sc.get("_sim_steps")) >= next, 200)
		var img := await _capture()
		if out.is_empty() or next == step0 + AFTER_STEPS / 2:
			_keep(img, "%s_%s_%d" % [str(pos["id"]), mode, next - step0])
		out.append(_after_shares(img))
		next += AFTER_EVERY
	await _free(sc)
	return out


## Shares of pure white (every channel ≥ 240/255) in the scene band, rows 25–80 %, and of snow in the ground band,
## rows 50–80 % (not pure white, luminance ≥ 0.6, saturation below 0.1 – measured on the pictures of F-01: the snowy
## ground of both modes 0.58–0.66, the sand-brown frames 0.000–0.003, Arcade-like snow lit by the warm tunnel light
## 0.000), on a 320-pixel-wide copy (nearest neighbour: no new grey from the scaling).
static func _after_shares(img: Image) -> Vector2:
	var small := img.duplicate() as Image
	small.resize(320, 180, Image.INTERPOLATE_NEAREST)
	var n := 0
	var white := 0
	var ng := 0
	var snow := 0
	for y in range(45, 144):
		for x in 320:
			var c := small.get_pixel(x, y)
			n += 1
			var is_white := c.r >= 240.0 / 255.0 and c.g >= 240.0 / 255.0 and c.b >= 240.0 / 255.0
			if is_white:
				white += 1
			if y < 90:
				continue
			ng += 1
			var hi := maxf(c.r, maxf(c.g, c.b))
			var lo := minf(c.r, minf(c.g, c.b))
			if not is_white and _lum(c) >= 0.6 and hi > 0.0 and (hi - lo) / hi < 0.1:
				snow += 1
	return Vector2(float(white) / float(maxi(n, 1)), float(snow) / float(maxi(ng, 1)))


func _check_water(name: String, renderer: Node, pos: Dictionary) -> void:
	var p: Array[String] = []
	if renderer.call(&"builder", "bridge") == null:
		p.append("builders/bridge.gd fehlt")
	if renderer.call(&"layer", "far_ground") == null:
		p.append("layers/far_ground.gd fehlt")
	var img := await _capture()
	_keep(img, str(pos["id"]))
	var hz := _horizon(renderer, img.get_height())
	var below := _shares(img, hz + 1, img.get_height())
	if below.x > COVER_LIMIT:
		p.append("%.3f %% Magenta unter der Horizontzeile (höchstens %.1f %%)" % [100.0 * below.x, 100.0 * COVER_LIMIT])
	if below.y > CYAN_LIMIT:
		p.append("%.2f %% Fernboden unter der Horizontzeile (höchstens %.0f %%): die Scheibe verdeckt den Fluss" % [100.0 * below.y, 100.0 * CYAN_LIMIT])
	var snap: Dictionary = renderer.call(&"debug_snapshot")
	var br: Dictionary = snap.get("bridges", {})
	if int(br.get("water_quads", 0)) <= 0:
		p.append("der Brücken-Builder hat kein Wasser gebaut")
	var fg: Dictionary = snap.get("far_ground", {})
	_report(name, p, "%s km %.1f: unter dem Horizont %.3f %% Magenta, %.2f %% Fernboden; %d Wasserflächen, %d Fernflüsse" % [
		str(pos["stage"]), float(pos["km"]), 100.0 * below.x, 100.0 * below.y, int(br.get("water_quads", 0)), (fg.get("rivers", []) as Array).size()])


func _check_beacon(name: String, renderer: Node, pos: Dictionary) -> void:
	var p: Array[String] = []
	var fl: Node = renderer.call(&"layer", "flares")
	var cam: Camera3D = renderer.get("camera")
	if fl == null:
		_report(name, ["layers/flares.gd fehlt"] as Array[String], "")
		return
	# 2.4 s (one and a half periods of 1.6 s), every 4th frame: the red flares and the red pixels at their place
	var seen := {}                      # rounded flare position -> frames in which it is lit
	var red_px_lit := 0
	var samples := 0
	var best: Image = null
	var best_n := -1
	for k in 36:
		await _frames(4)
		var img := await _capture()
		samples += 1
		var n_here := 0
		var lit_now := {}
		for f: Dictionary in fl.call("flares"):
			var c: Color = f["color"]
			if bool(f.get("vehicle", false)) or not (c.r > 0.6 and c.g < 0.35 and c.b < 0.35):
				continue
			var wp: Vector3 = f["pos"]
			var key := "%d|%d" % [int(round(wp.x / 4.0)), int(round(wp.z / 4.0))]
			if not seen.has(key):
				seen[key] = 0
			if lit_now.has(key):
				continue                # the beacon's glow: a second flare at the same place
			lit_now[key] = true
			seen[key] = int(seen[key]) + 1
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			n_here += 1
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var x := int(sp.x) + dx
					var y := int(sp.y) + dy
					if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
						var q := img.get_pixel(x, y)
						if q.r > 0.45 and q.r > q.g * 1.8 and q.r > q.b * 1.8:
							red_px_lit += 1
		if n_here > best_n:
			best_n = n_here
			best = img
	if best != null:
		_keep(best, str(pos["id"]))
	var beacons := 0
	var blinking := 0
	for key: String in seen:
		beacons += 1
		var lit := int(seen[key])
		if lit > 0 and lit < samples:
			blinking += 1
	if beacons < 2:
		p.append("nur %d rote Flugbefeuerung(en) in der Flare-Liste (die Köhlbrandbrücke hat 4)" % beacons)
	if blinking < beacons or beacons == 0:
		p.append("%d von %d Feuern blinken nicht (immer an oder nie an in %d Bildern)" % [beacons - blinking, beacons, samples])
	if red_px_lit < 3:
		p.append("an den Feuern zeigt das Bild kein Rot (%d Bildpunkte)" % red_px_lit)
	_report(name, p, "%s km %.1f, %02d Uhr: %d Feuer, %d blinken, %d rote Bildpunkte an ihnen in %d Bildern" % [str(pos["stage"]),
		float(pos["km"]), int(pos["hour"]), beacons, blinking, red_px_lit, samples])


## "-- --full": every bridge and every tunnel of the network (each direction of each stage and of the dev stage) built
## chunk by chunk without a renderer and compared EXACTLY with Arcade's own elements of the same track (FIX-R5, QA-R5
## QR5-06; the method of QA-R5's independent scan):
##   bridge  pylons, truss portals and bridge lamps = Arcade's "pylon" / "truss_portal" / "bridge_lamp" events
##           (Track._build_bridge); one red aviation light per pylon; 2 × 7 stay cables per pylon (RoadRenderer._pylon);
##           water; banks at both ends; per type its truss / arches; no vertex of the structure over a lane
##           between 0.3 and 4.5 m; no cable within 1.5 m of a lane;
##   tunnel  one portal and one exit frame; the cap at peek_m exactly where Arcade closes the tube; SOS niches by
##           Arcade's rule (a green sign in every tunnel segment whose road position mod 150 m < seg_len); at least
##           Arcade's two lamp rows every light_every_m; no point of the tube over a lane between 0.3 and 4.5 m (the cap
##           and the fans above 5.2 m aside); no point of the portal hill above the approach inside the sight corridor
##           (lanes + shoulder + 5.5 m, more than 0.5 m above the road – F7).
const SCAN_CLEAR_H := 4.5          ## nothing over a lane between 0.3 m and this
const SCAN_CABLE_MIN := 1.5        ## a stay cable at least this far beside a lane
const SCAN_CORRIDOR := 5.5         ## the approach's sight corridor beyond the shoulder (F7)


## Road coordinates (z, x, h) of a chunk-local point: the boundary of the path whose cross-section holds it.
static func _scan_road(ctx: ChunkContext, p: Vector3) -> Vector3:
	var w := p + ctx.origin
	var path := ctx.path
	var best := ctx.seg_a
	var bd := INF
	for k in range(maxi(path.first, ctx.seg_a - 60), mini(path.last(), ctx.seg_b + 60) + 1):
		var d := (w - path.point(k)).dot(RoadPath3D.fwd_of(path.heading(k)))
		if absf(d) < bd:
			bd = absf(d)
			best = k
	var rel := w - path.point(best)
	return Vector3(float(best) * ctx.seg_len + rel.dot(RoadPath3D.fwd_of(path.heading(best))), rel.dot(RoadPath3D.right_of(path.heading(best))), rel.y)


static func _scan_lane_edge(ctx: ChunkContext, z: float, x: float) -> float:
	var row := clampi(int(round(ctx.row_of(z))), 0, ctx.row_count() - 1)
	return ctx.rows_edge[row].y if x > 0.0 else -ctx.rows_edge[row].x


func _full_scan() -> void:
	var Fair: GDScript = load("res://tests/race3d/fairness.gd")
	var BridgeB: GDScript = load("res://scripts/race3d/builders/bridge.gd")
	var TunnelB: GDScript = load("res://scripts/race3d/builders/tunnel.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.call("load_network")
	var radius := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var terrain_cfg: Variant = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var tcfg: Variant = ConfigLoader.lookup(cfg, "render.tunnel", {})
	var peek := float((tcfg as Dictionary).get("peek_m", 45.0)) if tcfg is Dictionary else 45.0
	var lamp_every := float((tcfg as Dictionary).get("light_every_m", 12.0)) if tcfg is Dictionary else 12.0
	var cli := CliArgs.all()
	var only: Array = []
	if cli.has("only-stage"):
		only = str(cli["only-stage"]).split(",")
	var dirs: Array = Fair.call("directions", net, only)
	if only.is_empty():
		dirs.append_array(Fair.call("directions", net, ["dev_testetappe"]))
	var bridges := 0
	var tunnels := 0
	var bad: Array[String] = []
	var types := {}
	var totals := {"pylons": 0, "portals": 0, "lamps": 0, "cables": 0, "niches": 0, "caps": 0}
	var verbose := cli.has("verbose")
	for dir: Dictionary in dirs:
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.bridges.is_empty() and plan.tunnels.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, radius)
		var tp := TerrainProfile.new()
		tp.setup(p, t, terrain_cfg, net["scenery"])
		p.set_clear_reach(1842.0)
		# the elements of the direction in the order of the road: [z0, z1, kind, data]
		var items: Array = []
		for br: Dictionary in t.bridges:
			items.append([float(br["z0"]), float(br["z1"]), "bridge", br])
		for tu: Dictionary in plan.tunnels:
			items.append([t.km_to_z(float(tu["start_km"])), t.km_to_z(float(tu["end_km"])), "tunnel", tu])
		items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var bb: Object = BridgeB.new()
		var tb: Object = TunnelB.new()
		var last_chunk := floori(float(t.segment_count - 1) / 32.0) - 1     # its rows stay inside the track
		for item: Array in items:
			var is_bridge := str(item[2]) == "bridge"
			var z0 := float(item[0])
			var z1 := float(item[1])
			var d: Dictionary = item[3]
			var c0 := maxi(int(floor(z0 / t.seg_len / 32.0)) - 1, 0)
			var c1 := mini(int(floor(z1 / t.seg_len / 32.0)) + 1, last_chunk)
			var what := "%s %s (%s %s, km %.2f–%.2f)" % [str(dir["name"]), str(d.get("name", "?")), str(item[2]), str(d.get("type", "")),
				t.z_to_km(z0), t.z_to_km(z1)]
			var sums := {}
			var in_lane := 0
			var lane_ex := ""
			var cable_min := INF
			var hill_bad := 0
			var hill_ex := ""
			var bank_near := 0
			var bank_far := 0
			var z_mid := (z0 + z1) * 0.5
			var zp := float(ceili(z0 / t.seg_len - 1.0e-6)) * t.seg_len
			var seg_lo := c0 * 32
			var seg_hi := (c1 + 1) * 32
			for ci in range(c0, c1 + 1):
				p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
				var ctx := ChunkContext.new()
				ctx.cfg = cfg
				ctx.scenery_db = net["scenery"]
				ctx.levels = {"shadow_casters": 2, "details": 1}
				ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
				var b: Object = bb if is_bridge else tb
				var inp: Variant = b.call("collect", ctx)
				var part: Dictionary = b.call("build", ctx, inp)
				var dbg: Dictionary = b.call("debug", part)
				for k: String in dbg:
					sums[k] = int(sums.get(k, 0)) + int(dbg[k])
				var beacons := 0
				for l: Dictionary in part.get("lamps", []):
					if l.has("blink"):
						beacons += 1
				sums["beacons"] = int(sums.get("beacons", 0)) + beacons
				# geometry over the lanes (triangles sampled), banks per end, cables, the hill in the approach corridor
				var meshes: Array = [["struct", part.get("struct", [])]] if is_bridge else [["tube", part.get("tube", [])], ["portal", part.get("portal", [])], ["portal", part.get("hill", [])]]
				for m: Array in meshes:
					var arr: Array = m[1]
					if arr.is_empty():
						continue
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
					var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
					for k in range(0, idx.size(), 3):
						if str(m[0]) == "tube":
							var kind := uv2[idx[k]].x
							if absf(kind - 1.0) < 0.01:
								continue     # the cap (K_CAP): closes the tube for a camera outside only
						var a := v[idx[k]]
						var bv := v[idx[k + 1]]
						var cv := v[idx[k + 2]]
						for s: Vector2 in [Vector2(0.33, 0.33), Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5)]:
							var rc := _scan_road(ctx, a + (bv - a) * s.x + (cv - a) * s.y)
							if str(m[0]) == "portal":
								if rc.x < zp - 2.0 and rc.z > 0.5 and absf(rc.y) < _scan_lane_edge(ctx, rc.x, rc.y) + t.shoulder_w + SCAN_CORRIDOR:
									hill_bad += 1
									hill_ex = "z%+.1f x %.1f h %.1f" % [rc.x - zp, rc.y, rc.z]
								continue
							if rc.z > 0.3 and rc.z < SCAN_CLEAR_H and absf(rc.y) < _scan_lane_edge(ctx, rc.x, rc.y) and rc.x >= z0 - 3.0 and rc.x <= z1 + 3.0:
								in_lane += 1
								lane_ex = "%s km %.3f x %.2f h %.2f" % [str(m[0]), t.z_to_km(rc.x), rc.y, rc.z]
				if is_bridge:
					var w: Array = part.get("water", [])
					if not w.is_empty():
						var wv: PackedVector3Array = w[Mesh.ARRAY_VERTEX]
						var wuv2: PackedVector2Array = w[Mesh.ARRAY_TEX_UV2]
						for k in range(0, wv.size(), 4):
							if absf(wuv2[k].x) < 0.01:
								continue          # water (K_WATER); every other kind is a bank
							if _scan_road(ctx, wv[k]).x < z_mid:
								bank_near += 1
							else:
								bank_far += 1
					var cin: Dictionary = inp if inp is Dictionary else {}
					for c: Array in cin.get("cables", []):
						for q in 11:
							var rc := _scan_road(ctx, (c[0] as Vector3).lerp(c[1], float(q) / 10.0))
							cable_min = minf(cable_min, absf(rc.y) - _scan_lane_edge(ctx, rc.x, rc.y))
			var miss: Array[String] = []
			if is_bridge:
				bridges += 1
				var typ := str(d.get("type", "river"))
				types[typ] = int(types.get(typ, 0)) + 1
				# Arcade's events in the segments these chunks built (other bridges there count on both sides)
				var ev := {}
				for k in range(seg_lo, seg_hi):
					if k >= t.segment_count:
						break
					for e: Dictionary in t.events_for_segment(k):
						if e.has("bridge"):
							ev[str(e.get("proc", ""))] = int(ev.get(str(e.get("proc", "")), 0)) + 1
				var exp_py := int(ev.get("pylon", 0))
				var exp_po := int(ev.get("truss_portal", 0))
				var exp_la := int(ev.get("bridge_lamp", 0))
				if int(sums.get("pylons", 0)) != exp_py:
					miss.append("Pylone %d statt %d (Arcade)" % [int(sums.get("pylons", 0)), exp_py])
				if int(sums.get("beacons", 0)) != exp_py:
					miss.append("Flugfeuer %d statt %d" % [int(sums.get("beacons", 0)), exp_py])
				if int(sums.get("cables", 0)) != exp_py * 2 * 7:
					miss.append("Seile %d statt %d (Arcade: 7 je Richtung)" % [int(sums.get("cables", 0)), exp_py * 14])
				if int(sums.get("portals", 0)) != exp_po:
					miss.append("Fachwerkportale %d statt %d (Arcade)" % [int(sums.get("portals", 0)), exp_po])
				if int(sums.get("lamps", 0)) != exp_la:
					miss.append("Brückenlampen %d statt %d (Arcade)" % [int(sums.get("lamps", 0)), exp_la])
				if typ == "cable_stayed" and exp_py < 2:
					miss.append("Schrägseilbrücke ohne Pylone in Arcades Ereignissen")
				if int(sums.get("water_quads", 0)) <= 0:
					miss.append("Wasser")
				if bank_near <= 0 or bank_far <= 0:
					miss.append("Ufer an beiden Enden (vorn %d, hinten %d)" % [bank_near, bank_far])
				match typ:
					"truss_arch":
						if int(sums.get("truss", 0)) <= 0:
							miss.append("Fachwerkträger")
					"stone_arch", "canal", "causeway":
						if int(sums.get("arches", 0)) <= 0:
							miss.append("Bögen")
				# (piers are Modern's own: Arcade draws none; a short river bridge spans its water without one)
				if in_lane > 0:
					miss.append("%d Tragwerkspunkte über den Spuren unter %.1f m (%s)" % [in_lane, SCAN_CLEAR_H, lane_ex])
				if exp_py > 0 and cable_min < SCAN_CABLE_MIN:
					miss.append("Seil %.2f m neben der Spur" % cable_min)
				totals["pylons"] += int(sums.get("pylons", 0))
				totals["portals"] += int(sums.get("portals", 0))
				totals["lamps"] += int(sums.get("lamps", 0))
				totals["cables"] += int(sums.get("cables", 0))
				if verbose:
					print("BRIDGE %s: Pylone %d/%d Portale %d/%d Lampen %d/%d Seile %d Feuer %d Ufer %d|%d Pfeiler %d Bögen %d Fachwerk %d Seil-Abstand %.2f" % [
						what, int(sums.get("pylons", 0)), exp_py, int(sums.get("portals", 0)), exp_po, int(sums.get("lamps", 0)), exp_la,
						int(sums.get("cables", 0)), int(sums.get("beacons", 0)), bank_near, bank_far, int(sums.get("piers", 0)),
						int(sums.get("arches", 0)), int(sums.get("truss", 0)), cable_min if cable_min < INF else -1.0])
			else:
				tunnels += 1
				var ze := float(ceili(z1 / t.seg_len - 1.0e-6)) * t.seg_len
				var first := int(round(zp / t.seg_len))
				var end := int(round(ze / t.seg_len))
				var exp_cap := 1 if zp + peek < ze - t.seg_len else 0
				var exp_niche := 0
				for k in range(first, end):
					if t.get_segment(k).tunnel and fposmod(float(k) * t.seg_len, 150.0) < t.seg_len:
						exp_niche += 1
				var exp_lamps := 0
				var zl := ceilf(zp / lamp_every) * lamp_every
				while zl < ze:
					exp_lamps += 2
					zl += lamp_every
				if int(sums.get("portals", 0)) != 1:
					miss.append("Portale %d statt 1" % int(sums.get("portals", 0)))
				if int(sums.get("exits", 0)) != 1:
					miss.append("Ausfahrtsrahmen %d statt 1" % int(sums.get("exits", 0)))
				if int(sums.get("caps", 0)) != exp_cap:
					miss.append("Kappe %d statt %d" % [int(sums.get("caps", 0)), exp_cap])
				if int(sums.get("niches", 0)) != exp_niche:
					miss.append("Nischen %d statt %d (Arcades grüne Schilder)" % [int(sums.get("niches", 0)), exp_niche])
				if int(sums.get("lamps", 0)) < exp_lamps:
					miss.append("Leuchten %d, Arcade %d" % [int(sums.get("lamps", 0)), exp_lamps])
				if int(sums.get("segments", 0)) != end - first or int(sums.get("tube_triangles", 0)) <= 0:
					miss.append("Röhre %d von %d Segmenten" % [int(sums.get("segments", 0)), end - first])
				if in_lane > 0:
					miss.append("%d Röhrenpunkte über den Spuren unter %.1f m (%s)" % [in_lane, SCAN_CLEAR_H, lane_ex])
				if hill_bad > 0:
					miss.append("%d Hügelpunkte über der Anfahrt im Sichtkorridor (%s)" % [hill_bad, hill_ex])
				totals["niches"] += int(sums.get("niches", 0))
				totals["caps"] += int(sums.get("caps", 0))
				if verbose:
					print("TUNNEL %s: %.0f m Portale %d Ausfahrten %d Kappe %d/%d Nischen %d/%d Leuchten %d (Arcade %d)" % [what, ze - zp,
						int(sums.get("portals", 0)), int(sums.get("exits", 0)), int(sums.get("caps", 0)), exp_cap, int(sums.get("niches", 0)),
						exp_niche, int(sums.get("lamps", 0)), exp_lamps])
			if not miss.is_empty():
				bad.append("%s: %s" % [what, "; ".join(miss)])
	ModernMaterials.drop_shared()
	for b: String in bad:
		print("MANGEL " + b)
	var problems: Array[String] = []
	problems.assign(bad.slice(0, 12))
	if bridges == 0 or tunnels == 0:
		problems.append("keine Brücke oder kein Tunnel gefunden")
	if only.is_empty():
		for typ: String in CityData.BRIDGE_TYPES:
			if not types.has(typ):
				problems.append("kein Brückentyp %s im Netz" % typ)
	_report("tunnel_bridge_full", problems, "%d Brücken %s, %d Tunnel exakt gegen Arcade geprüft (%s), %d mit Mängeln, %.0f s" % [bridges,
		JSON.stringify(types), tunnels, JSON.stringify(totals), bad.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(),
		(Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)
