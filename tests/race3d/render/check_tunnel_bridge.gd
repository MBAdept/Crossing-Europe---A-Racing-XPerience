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
##                   is neither black nor blown out – its mean luminance between EXIT_MIN and EXIT_MAX, less than half
##                   of its pixels pure white (the tube beside it is reported: Arcade over-exposes the outside seen from
##                   a tunnel, RoadRenderer: ambient × 1.7 + 0.25 – an exposure of the environment, not of the tube)
##   Somport_portal  Saragossa – Pau, 70 m before the Somport portal (km 177), cover: as U1_portal
##   B1              Frankfurt – Köln, Severinsbrücke from its ramp (km 186.2), --gfx-debug=cover,far: nothing open below
##                   the horizon (magenta ≤ 0.2 %), the far-ground plane does not cover the Rhine (cyan ≤ 2 %), the
##                   bridge builder built water
##   beacon          Kiel – Hamburg km 76.4 at 22:00 (the pylon tops 230 and 350 m ahead, in the picture): the aviation
##                   lights of the Köhlbrandbrücke blink in Arcade's rhythm – over 2.4 s every beacon is lit in some
##                   frames and dark in others (the flare layer's list) and the picture shows its red where it is lit
## "-- --only=U1_portal,B1" runs some positions, "-- --save=<absolute folder>" keeps the pictures.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const COVER_LIMIT := 0.002          ## magenta share (below the horizon row / of the whole picture inside a tunnel)
const CYAN_LIMIT := 0.02            ## far-ground share below the horizon row at a river (FIX-WASSER, K1)
const LAMP_LUM := 0.8               ## a lamp pixel …
const LAMP_MIN_PX := 40             ## … and at least this many of them above the horizon row inside the tube
const TUBE_MIN := 0.06              ## mean luminance of the picture inside the tube: not black …
const TUBE_MAX := 0.6               ## … and not white
const EXIT_MIN := 0.15              ## mean luminance of the exit opening: not black (the tube's darkness is ~0.05) …
const EXIT_MAX := 0.95              ## … not blown out
const EXIT_WHITE_MAX := 0.5         ## share of pure white pixels in the opening
const POSITIONS: Array = [
	{"id": "U1_portal", "stage": "bern_mailand", "from": "bern", "km": 184.4, "hour": 12.0, "seed": 16, "debug": "cover", "kind": "portal"},
	{"id": "U1_innen", "stage": "bern_mailand", "from": "bern", "km": 188.0, "hour": 12.0, "seed": 16, "debug": "cover", "kind": "inside"},
	{"id": "U1_ausfahrt", "stage": "bern_mailand", "from": "bern", "km": 201.3, "hour": 12.0, "seed": 16, "debug": "", "kind": "exit"},
	{"id": "Somport_portal", "stage": "saragossa_pau", "from": "saragossa", "km": 176.3, "hour": 12.0, "seed": 4, "debug": "cover", "kind": "portal"},
	{"id": "B1", "stage": "frankfurt_koeln", "from": "frankfurt", "km": 186.2, "hour": 12.0, "seed": 11, "debug": "cover,far", "kind": "water"},
	{"id": "beacon", "stage": "kiel_hamburg", "from": "kiel", "km": 76.4, "hour": 22.0, "seed": 11, "debug": "", "kind": "beacon"},
]

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
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
	if n < 200:
		p.append("die Ausfahrt ist nicht im Bild (%d Bildpunkte)" % n)
	if mean < EXIT_MIN:
		p.append("Ausfahrt zu dunkel (Leuchtdichte %.3f, mindestens %.2f)" % [mean, EXIT_MIN])
	if mean > EXIT_MAX or float(white) / float(maxi(n, 1)) > EXIT_WHITE_MAX:
		p.append("Ausfahrt ausgebrannt (Leuchtdichte %.3f, %.0f %% reines Weiß)" % [mean, 100.0 * float(white) / float(maxi(n, 1))])
	_report(name, p, "%s km %.1f: Ausfahrt %d Bildpunkte, Leuchtdichte %.3f (Röhre daneben %.3f), %.1f %% reines Weiß" % [
		str(pos["stage"]), float(pos["km"]), n, mean, wall_mean, 100.0 * float(white) / float(maxi(n, 1))])


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
