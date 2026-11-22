extends SceneTree
## The landmarks of the mode "Modern" (package R7b, builders/landmarks.gd), checked headless in the real race scene
## with the shipped renderer:
##   godot --headless --path . -s res://tests/race3d/check_landmarks.gd [-- --only=reichweite,position]
## tools/run_tests.sh runs it through its generic hook (tests/race3d/check_*.gd).
##   reichweite  Kiel – Hamburg km 80, 12:00: every landmark of the track ahead up to Arcade's landmark range stands on
##               the path, none beyond it, none twice; the props builder leaves them to the landmarks builder
##   nacht       km 77.4, 22:00: up to render.landmark_far_m – further than the night's sight alone allows – with its
##               illumination on (RoadRenderer._draw_far_landmarks)
##   position    the straight approaches to landmarks (the only three of the network that run straight for 640 m before
##               the landmark – every city arrival bends; STRAIGHT): the landmark's anchor 600 m ahead stands on the
##               screen where Arcade draws it (its anchor from Arcade's own code, RoadRenderer._prep_prop) – within 5 %
##               of the frame width (contract §6 wave 5, acceptance of R7); a picture and a model
##   prozedural  Belgrad: Arcade's procedural landmark (no sprite, no model) stands as its 3D shape (domed_church)
##   weich       far away (beyond 0.70 of the landmark range) the landmark draws with its translucent material
##   skyline     Paris, City Limits km 376: the backdrop shows the skyline of cities.json (Sacré-Cœur at full strength,
##               the Eiffel tower – a landmark on the road 1.85 km ahead, just beyond its range – faint, fading out as
##               the 3D landmark comes into range: no double); outside the City Limits (km 300) none
## Prints "CHECK <name> OK|FEHLER …" per check; exit code 0 when all pass.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["reichweite", "nacht", "position", "prozedural", "weich", "skyline"]
const Fair := preload("res://tests/race3d/fairness.gd")
## Landmarks with a straight approach of 640 m: [stage, from, landmark set] (a scan of every stage direction; the city
## arrivals of the ten A/B cities all bend, |curve| 0.11–0.29, within the last 640 m)
const STRAIGHT := [["san_sebastian_burgos", "san_sebastian", "landmarks/kathedrale_burgos"],
	["ljubljana_slavonski_brod", "ljubljana", "props/church"], ["slavonski_brod_belgrad", "belgrad", "props/church"]]
const APPROACH_M := 600.0
const STRAIGHT_CURVE := 0.004        ## |curve| below this on every segment from the camera to the landmark = straight
const MAX_POSITION_RUNS := 3

var _failed: Array[String] = []
var _settings: Node
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_settings = root.get_node("Settings")
	_settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var only := str(cli.get("only", ""))
	cli.erase("graphics")
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_settings.call("disarm_crash_guard")
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-11s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


## A Modern stage, prepared (synchronous chunk builds), standing still at its start view.
func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
	setup.merge(extra, true)
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	CliArgs.all().erase("gfx-sync")
	var n := 0
	while n < 600 and not bool(sc.call("is_live")):
		await process_frame
		n += 1
	for i in 3:
		await process_frame
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## The live landmarks of the landmarks builder (its snapshot) by index into Track.landmarks.
func _live(r: Object) -> Dictionary:
	var b: Object = r.call("builder", "landmarks")
	var out := {}
	if b == null:
		return out
	for e: Dictionary in ((b.call("snapshot") as Dictionary).get("landmarks", []) as Array):
		out[int(e["index"])] = e
	return out


## Checks that exactly the landmarks ahead up to `reach` are live (and visible). Returns [count, reach].
func _check_ahead(r: Object, trk: Object, reach: float, p: Array[String], what: String) -> int:
	var view: Dictionary = r.get("view")
	var cam_z := float(view.get("camera_z", 0.0))
	var live := _live(r)
	var lms: Array = trk.get("landmarks")
	var expected := 0
	for li in lms.size():
		var d := float((lms[li] as Dictionary)["z"]) - cam_z
		var name := str((lms[li] as Dictionary).get("set"))
		if d > 0.0 and d <= reach:
			expected += 1
			_need(p, live.has(li), "%s: %s (%.0f m) steht auf dem Pfad" % [what, name, d])
			if live.has(li):
				_need(p, bool((live[li] as Dictionary).get("visible", false)), "%s: %s (%.0f m) ist sichtbar" % [what, name, d])
		elif d > reach + 2.0:
			_need(p, not live.has(li), "%s: %s (%.0f m) jenseits der Reichweite %.0f m nicht gezeichnet" % [what, name, d, reach])
	var nodes := 0
	var world: Node = r.get("world")
	var names := {}
	for c: Node in world.get_children():
		if str(c.name).begins_with("Landmark"):
			nodes += 1
			_need(p, not names.has(str(c.name)), "%s: %s nur einmal" % [what, str(c.name)])
			names[str(c.name)] = true
	_need(p, nodes == live.size(), "%s: ein Knoten je lebendem Wahrzeichen (%d / %d)" % [what, nodes, live.size()])
	return expected


# --- checks ----------------------------------------------------------------------------------------------------

func _check_reichweite() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_km": 80.0})
	var r: Object = sc.get("renderer")
	var trk: Object = sc.get("track")
	var b: Object = r.call("builder", "landmarks")
	_need(p, b != null, "der Builder landmarks ist registriert")
	var props: Object = r.call("builder", "props")
	_need(p, props != null and bool(props.get("_skip_landmarks")), "builders/props.gd überlässt die Wahrzeichen dem Builder landmarks")
	_need(p, props != null and (props.get("_far") as Dictionary).is_empty(), "builders/props.gd stellt keine fernen Wahrzeichen auf")
	var view: Dictionary = r.get("view")
	var vis := float(view.get("visibility_m", 900.0))
	var reach := clampf(vis * 2.0, minf(vis, 600.0), maxf(1900.0, vis))
	var n := _check_ahead(r, trk, reach, p, "12 Uhr km 80")
	_need(p, n >= 2, "Elbphilharmonie und Michel voraus (%d)" % n)
	await _free(sc)
	_report("reichweite", p, "Kiel – Hamburg km 80: %d Wahrzeichen bis %.0f m (Sicht %.0f m), keines doppelt" % [n, reach, vis])


func _check_nacht() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_km": 77.4, "start_world_minutes": 22.0 * 60.0})
	var r: Object = sc.get("renderer")
	var trk: Object = sc.get("track")
	var view: Dictionary = r.get("view")
	var vis := float(view.get("visibility_m", 900.0))
	var by_sight := clampf(vis * 2.0, minf(vis, 600.0), maxf(1900.0, vis))
	var reach := maxf(by_sight, 1900.0)
	var n := _check_ahead(r, trk, reach, p, "22 Uhr km 77,4")
	var lit := 0
	for e: Dictionary in _live(r).values():
		if float(e.get("d", 0.0)) > 0.0 and float(e.get("lights", 0.0)) > 0.1:
			lit += 1
	_need(p, lit >= 1, "Beleuchtung der Wahrzeichen an (%d)" % lit)
	await _free(sc)
	_report("nacht", p, "22 Uhr km 77,4: %d Wahrzeichen bis %.0f m (Sicht allein %.0f m), %d beleuchtet" % [n, reach, by_sight, lit])


## The approaches of STRAIGHT: [stage, from, set, km of the landmark, straight] (from the stage's track).
func _straight_arrivals() -> Array:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var out: Array = []
	for a: Array in STRAIGHT:
		for dir: Dictionary in Fair.directions(net, [str(a[0])]):
			if str(dir["from"]) != str(a[1]):
				continue
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg, net["scenery"])
			for it: Dictionary in t.landmarks:
				if str(it["set"]) != str(a[2]):
					continue
				var z := float(it["z"])
				var straight := true
				var k0 := int(floor((z - APPROACH_M - 40.0) / t.seg_len))
				for k in range(maxi(k0, 0), int(floor(z / t.seg_len)) + 1):
					if absf(t.get_segment(k).curve) > STRAIGHT_CURVE:
						straight = false
						break
				out.append([str(a[0]), str(a[1]), str(a[2]), t.z_to_km(z), straight])
	return out


func _check_position() -> void:
	var p: Array[String] = []
	var rows: Array[String] = []
	var runs := 0
	var straight_n := 0
	for a: Array in _straight_arrivals():
		if not bool(a[4]):
			rows.append("%s: Anfahrt nicht gerade" % str(a[2]).get_file())
			continue
		straight_n += 1
		if runs >= MAX_POSITION_RUNS:
			continue
		runs += 1
		# the camera 600 m before the landmark: the car stands cam_distance ahead of the camera
		var km := float(a[3]) - (APPROACH_M - 9.0) / 100.0
		var sc: Node = await _launch({"stage_id": a[0], "from_city": a[1], "start_km": km})
		var r: Object = sc.get("renderer")
		var trk: Object = sc.get("track")
		var view: Dictionary = r.get("view")
		var cam_z := float(view.get("camera_z", 0.0))
		var cam_x := float(view.get("camera_x", 0.0))
		var proj: Object = r.get("proj")
		var b: Object = r.call("builder", "landmarks")
		var plans: Array = b.get("_plans")
		var lms: Array = trk.get("landmarks")
		for li in lms.size():
			var it: Dictionary = lms[li]
			if str(it["set"]) != str(a[2]):
				continue
			var d := float(it["z"]) - cam_z
			# Arcade's anchor: RoadRenderer._prep_prop of the same item (a renderer that is never in the tree)
			var rr: Node = (load("res://scripts/race/road_renderer.gd") as GDScript).new()
			rr.set("proj", proj)
			var pc: Array = rr.call("_prep_prop", it.duplicate())
			rr.free()
			var focal := float(proj.get("focal"))
			var w := float((proj.get("screen") as Vector2).x)
			var ax := w * 0.5 + (float(pc[3]) - cam_x) * focal / d
			var plan: Dictionary = plans[li]
			var ms: Vector3 = r.call("world_to_screen", float(it["z"]), float(plan["x"]), 0.0)
			var dx := absf(ms.x - ax)
			_need(p, dx <= 0.05 * w, "%s: %.0f px neben Arcades Stelle bei %.0f m (höchstens %.0f)" % [str(a[2]).get_file(), dx, d, 0.05 * w])
			rows.append("%s %.0f m: Arcade x %.0f, Modern x %.0f (%.1f px, %s)" % [str(a[2]).get_file(), d, ax, ms.x, dx,
				["–", "Modell", "Bild", "Form"][int(plan["rep"])]])
		await _free(sc)
	_need(p, runs == STRAIGHT.size(), "alle geraden Anfahrten gerade und geprüft (%d von %d)" % [runs, STRAIGHT.size()])
	_report("position", p, "; ".join(rows))


func _check_prozedural() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"stage_id": "slavonski_brod_belgrad", "from_city": "slavonski_brod", "start_km": 196.0})
	var r: Object = sc.get("renderer")
	var found := false
	for e: Dictionary in _live(r).values():
		if str(e.get("landmark", "")) == "landmarks/hram_svetog_save":
			found = true
			_need(p, str(e.get("rep", "")) == "proc" and str(e.get("kind", "")) == "domed_church",
				"die Kirche des Heiligen Sava als Kuppelkirche in 3D (%s %s)" % [str(e.get("rep")), str(e.get("kind"))])
			_need(p, bool(e.get("visible", false)), "sichtbar bei %.0f m" % float(e.get("d", 0.0)))
	_need(p, found, "das Wahrzeichen von Belgrad steht auf dem Pfad")
	await _free(sc)
	_report("prozedural", p, "Belgrad: Arcades prozedurale Kuppelkirche als 3D-Form")


func _check_weich() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_km": 76.0})
	var r: Object = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var vis := float(view.get("visibility_m", 900.0))
	var l := clampf(vis * 2.0, minf(vis, 600.0), maxf(1900.0, vis))
	var far := 0
	var near := 0
	for e: Dictionary in _live(r).values():
		var d := float(e.get("d", 0.0))
		if d >= 0.70 * l:
			far += 1
			_need(p, bool(e.get("blend", false)), "%s bei %.0f m: durchscheinendes Material (weiches Ausblenden)" % [str(e.get("landmark")), d])
		elif d > 0.0:
			near += 1
			_need(p, not bool(e.get("blend", true)), "%s bei %.0f m: deckendes Material" % [str(e.get("landmark")), d])
	_need(p, far >= 1, "ein Wahrzeichen im Ausblendbereich (%d)" % far)
	await _free(sc)
	_report("weich", p, "km 76: %d Wahrzeichen jenseits von 0,70 L = %.0f m durchscheinend, %d näher deckend" % [far, 0.70 * l, near])


func _check_skyline() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"stage_id": "luettich_paris", "from_city": "luettich", "start_km": 376.0})
	var r: Object = sc.get("renderer")
	var bd: Object = r.call("layer", "backdrop")
	var sky: Array = (((bd.call("snapshot") as Dictionary).get("backdrop", {}) as Dictionary).get("skyline", []) as Array)
	var by_set := {}
	for e: Dictionary in sky:
		by_set[str(e["set"])] = e
	_need(p, by_set.has("landmarks/sacre_coeur") and float((by_set.get("landmarks/sacre_coeur", {}) as Dictionary).get("alpha", 0.0)) > 0.99,
		"Sacré-Cœur in der Skyline (%s)" % str(by_set.get("landmarks/sacre_coeur")))
	var eiffel: Dictionary = by_set.get("landmarks/eiffel_tower", {})
	_need(p, not eiffel.is_empty() and float(eiffel.get("alpha", 1.0)) < 0.5, "Eiffelturm in der Skyline schwach, das Wahrzeichen kommt in Reichweite (%s)" % str(eiffel))
	await _free(sc)
	sc = await _launch({"stage_id": "luettich_paris", "from_city": "luettich", "start_km": 300.0})
	r = sc.get("renderer")
	bd = r.call("layer", "backdrop")
	var outside: Array = (((bd.call("snapshot") as Dictionary).get("backdrop", {}) as Dictionary).get("skyline", []) as Array)
	_need(p, outside.is_empty(), "außerhalb der City Limits keine Skyline (%d)" % outside.size())
	await _free(sc)
	_report("skyline", p, "Paris km 376: %s; km 300: keine" % ", ".join(sky.map(func(e: Dictionary) -> String: return "%s %.2f bei x %.0f" % [str(e["set"]).get_file(), float(e["alpha"]), float(e["x"])])))
