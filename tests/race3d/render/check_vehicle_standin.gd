extends SceneTree
## Render checks of the stand-ins of the mode "Modern" (R3E: Arcade's own picture of a vehicle set without a model,
## layers/vehicles.gd + VehicleStandIn) against Arcade's own frame of the same moment – they need a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_vehicle_standin.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## Kiel – Hamburg km 2 (S1), noon, a still stage without traffic; the Modern camera without the look into the bend
## (look_gain 0: the exact Arcade projection, A-3) and without contact shadows (the picture alone is measured).
##   spieler   the player's picture for every player car without a model (kombi, sportwagen, gran_turismo): its
##             rectangle (Arcade: RoadRenderer.last_player_pose.rect; Modern: the stand-in quad projected by the
##             camera) and its drawn pixels (frame with the car minus frame without) – position and size within 3 px,
##             mean brightness of the car within 10 %
##   verkehr   a traffic set without a model at 20, 60 and 150 m in the next lane: drawn pixels within 3 px of Arcade's,
##             brightness within 10 %; at 20 m Arcade warps the cell – Modern folds it
##   kasten    a box set without a model (a bus) at 30 m: drawn pixels within 3 px, brightness within 10 %
##   nacht     22:00: the body of the player's picture and of a light-coloured traffic car at 20 and 60 m (top middle
##             of the box the car covers by day: no lamp, glow, shadow or headlight pool) – brightness within 10 %;
##             with the tail lights on the lit area is only reported (the glows are R3's flares, not Arcade's)
##   verdeckt  a traffic picture just behind a crest (Kassel – Würzburg km 61.6, T2), lamps on, by day and at night:
##             0 pixels change (the picture stands at the depth of the car, as a model)
##   laden     no sprite sheet is loaded while driving (SpriteDB.loads), 10 s with traffic and autopilot; while a vehicle
##             set lacks a model its stand-in shows up – with none left (AS2R, M2INT) no stand-in is drawn and no
##             sheet is loaded in prepare()
## A set that has a model by now is skipped (the stand-in leaves it alone) – the check names it.
## "-- --save=<absolute folder>" keeps the pictures (standin_<name>_<mode>.png).
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist; Arcade's
## renderer is extended by a script compiled at run time for the same reason.)

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const CHECKS := ["spieler", "verkehr", "kasten", "nacht", "verdeckt", "laden"]
const PLAYERS: Array[String] = ["kombi", "sportwagen", "gran_turismo"]
const TRAFFIC: Array[String] = ["traffic/sports_red", "traffic/sports_blue", "traffic/van_white", "traffic/suv_grey",
	"traffic/sports_yellow", "traffic/van_red", "traffic/suv_white", "police/de"]
const BOXES: Array[String] = ["traffic/bus_blue", "traffic/bus_red", "traffic/bus_white", "traffic/truck_blue"]
const POS_PX := 3.0            ## position and size against Arcade (px)
const BRIGHT := 0.10           ## mean brightness of the car against Arcade (fraction)
const DIFF := 45               ## a pixel belongs to the car when the frame with it differs by more (sum of RGB, 0..765)
## Arcade's renderer with test cars added to its view and the player hidden on demand (compiled at run time).
const ARCADE_SRC := """extends "res://scripts/race/road_renderer.gd"
static var inject: Array = []
static var hide_player := false
func render(v: Dictionary) -> void:
	if inject.is_empty() and not hide_player:
		super.render(v)
		return
	var w := v.duplicate()
	var cars: Array = (w.get("cars", []) as Array).duplicate()
	cars.append_array(inject)
	w["cars"] = cars
	if hide_player and w.get("player", null) is Dictionary:
		var pl: Dictionary = (w["player"] as Dictionary).duplicate()
		pl["visible"] = false
		w["player"] = pl
	super.render(w)
"""

var _failed: Array[String] = []
var _probe: GDScript
var _renderers: GDScript
var _arcade: GDScript
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK vehicle_standin FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	_arcade = GDScript.new()
	_arcade.source_code = ARCADE_SRC
	_arcade.reload()
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	var had_traffic := cli.has("no-traffic")
	_renderers.set("modern_script", PROBE)
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			cli["no-traffic"] = c != "laden"
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


func _db() -> Node:
	return root.get_node("SpriteDB")


## A still stage (no autopilot, no countdown, HUD hidden) in `mode` – Kiel – Hamburg km 2 at noon unless `extra` says
## otherwise. Arcade: the renderer of the session is replaced by the injecting one before it draws; Modern: the probe
## renderer, the camera without the look into the bend, no contact shadows (`shipped`: both as shipped).
func _launch(mode: String, extra: Dictionary = {}, shipped: bool = false) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": mode, "no_countdown": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	if mode == "arcade":
		var old: Node = sc.get("renderer")
		var nr: Node = _arcade.new()
		sc.set("renderer", nr)
		sc.add_child(nr)
		sc.move_child(nr, 0)
		nr.call("setup", sc.get("track"), sc.get("proj"), sc.get("cfg"), root.get_node("GameData").get("scenery"))
		old.queue_free()
	(sc.get("hud") as Control).visible = false
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5, 3000)
	if not bool(setup.get("autopilot", false)):
		Engine.time_scale = 0.0
	if mode == "modern" and not shipped:
		var r: Node = sc.get("renderer")
		var chase: Variant = r.get("chase")
		if chase is Object:
			(chase as Object).set("look_gain", 0.0)
		var vl: Node = r.call("layer", "vehicles")
		if vl != null:
			vl.set("debug_contact_shadows", false)
	await _frames(3)
	return sc


func _free(sc: Node) -> void:
	_probe.call("reset")
	_arcade.set("inject", [])
	_arcade.set("hide_player", false)
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


## The picture once the test cars `cars` are shown (and the player hidden or not) in the running stage of `mode`.
func _shot(mode: String, cars: Array, hide_player: bool) -> Image:
	if mode == "arcade":
		_arcade.set("inject", cars)
		_arcade.set("hide_player", hide_player)
	else:
		_probe.set("inject", cars)
		_probe.set("hide_player", hide_player)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _keep(img: Image, pic_name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir.path_join("standin_%s.png" % pic_name))


func _car(id: int, set_id: String, z: float, x: float) -> Dictionary:
	var o: Dictionary = _db().call("object_size", set_id)
	return {"kind": "car", "id": id, "set": set_id, "z": z, "x": x, "length": float(o.get("length_m", 4.6)), "tail": 0.0,
		"brake": 0.0, "speed": 0.0, "blink": 0, "blink_t": 0.0, "heavy": float(o.get("length_m", 4.6)) > 7.0}


## The pixels of a car: where the frame with it (`a`) differs from the frame without (`b`) by more than DIFF.
## {"box": Rect2i (bounding box), "n": pixels, "lum": mean luminance of `a` over the inner half of the box (the body,
## not the edges where the backgrounds of the two modes differ)}.
static func _car_pixels(a: Image, b: Image) -> Dictionary:
	var w := a.get_width()
	var h := a.get_height()
	var da := a.get_data()
	var db := b.get_data()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	var n := 0
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		var row := y * w
		for x in w:
			var o := (row + x) * 4
			var d := absi(da[o] - db[o]) + absi(da[o + 1] - db[o + 1]) + absi(da[o + 2] - db[o + 2])
			if d > DIFF:
				mask[row + x] = 1
				n += 1
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if n == 0:
		return {"box": Rect2i(), "n": 0, "lum": 0.0}
	var box := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	var inner := Rect2i(box.position + box.size / 4, box.size / 2)
	var sum := 0.0
	var cnt := 0
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			if mask[y * w + x] == 1:
				var o := (y * w + x) * 4
				sum += (0.2126 * float(da[o]) + 0.7152 * float(da[o + 1]) + 0.0722 * float(da[o + 2])) / 255.0
				cnt += 1
	return {"box": box, "n": n, "lum": sum / maxf(1.0, float(cnt))}


## Largest deviation (px) of the edges of two boxes.
static func _box_dev(a: Rect2i, b: Rect2i) -> float:
	return maxf(maxf(absf(a.position.x - b.position.x), absf(a.end.x - b.end.x)), maxf(absf(a.position.y - b.position.y), absf(a.end.y - b.end.y)))


static func _rect_dev(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(absf(a.position.x - b.position.x), absf(a.end.x - b.end.x)), maxf(absf(a.position.y - b.position.y), absf(a.end.y - b.end.y)))


## Compares the drawn pixels of one car of the two modes: problems appended, a line of numbers returned.
func _compare(p: Array[String], what: String, ar: Dictionary, mo: Dictionary) -> String:
	if int(ar["n"]) == 0 or int(mo["n"]) == 0:
		_need(p, false, "%s: gezeichnet (Arcade %d, Modern %d Pixel)" % [what, int(ar["n"]), int(mo["n"])])
		return "%s: nicht gezeichnet" % what
	var dev := _box_dev(ar["box"], mo["box"])
	var la := float(ar["lum"])
	var lm := float(mo["lum"])
	var rel := absf(lm - la) / maxf(la, 0.01)
	_need(p, dev <= POS_PX, "%s: Lage und Größe ≤ %.0f px (%.0f px: Arcade %s, Modern %s)" % [what, POS_PX, dev, str(ar["box"]), str(mo["box"])])
	_need(p, rel <= BRIGHT, "%s: Helligkeit ± %.0f %% (Arcade %.3f, Modern %.3f)" % [what, BRIGHT * 100.0, la, lm])
	return "%s %.0f px, Helligkeit %+.1f %%" % [what, dev, (lm - la) / maxf(la, 0.01) * 100.0]


# --- spieler ------------------------------------------------------------------------------------------------------

func _check_spieler() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	for veh: String in PLAYERS:
		var sid := "player/" + veh
		if ModelDB.has_model(sid):
			msgs.append("%s hat ein Modell (übersprungen)" % veh)
			continue
		var res := {}
		for mode: String in ["arcade", "modern"]:
			var sc: Node = await _launch(mode, {"vehicle": veh})
			var with_car := await _shot(mode, [], false)
			var without := await _shot(mode, [], true)
			var px := _car_pixels(with_car, without)
			var rect := Rect2()
			var r: Node = sc.get("renderer")
			await _shot(mode, [], false)
			if mode == "arcade":
				rect = (r.get("last_player_pose") as Dictionary).get("rect", Rect2())
			else:
				rect = _modern_player_rect(r, sid)
			res[mode] = {"px": px, "rect": rect}
			_keep(with_car, "%s_%s" % [veh, mode])
			await _free(sc)
		var a: Dictionary = res["arcade"]
		var m: Dictionary = res["modern"]
		var rdev := _rect_dev(a["rect"], m["rect"])
		_need(p, rdev <= POS_PX, "%s: Bildrechteck ≤ %.0f px (%.1f px: Arcade %s, Modern %s)" % [veh, POS_PX, rdev, str(a["rect"]), str(m["rect"])])
		msgs.append("%s: Rechteck %.1f px, Pixel %s" % [veh, rdev, _compare(p, veh, a["px"], m["px"])])
	_report("spieler", p, "; ".join(msgs))


## The screen rectangle (logical px) of the player's stand-in quad: the anchor (the road under the car centre) and the
## quad's corners in the camera plane (VehicleStandIn: width image_width_m, anchor of the cell) projected by the
## camera – the same rectangle RoadRenderer reports as last_player_pose.rect (before the body roll).
func _modern_player_rect(r: Node, sid: String) -> Rect2:
	var info := VehicleStandIn.sheet_info(sid, _db())
	if info.is_empty():
		return Rect2()
	var view: Dictionary = r.get("view")
	var pl: Dictionary = view.get("player", {})
	var path: RoadPath3D = r.get("path")
	var cam: Camera3D = r.get("camera")
	var anchor := path.world(float(pl.get("z", 0.0)) + float(pl.get("length", 4.6)) * 0.5, float(pl.get("x", 0.0)), 0.0)
	var ct := cam.global_transform
	var a := ct.affine_inverse() * anchor
	var size: Vector2 = info["size_m"]
	var an: Vector2 = info["anchor"]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for cx: float in [-an.x * size.x, (1.0 - an.x) * size.x]:
		for cy: float in [(an.y - 1.0) * size.y, an.y * size.y]:
			var s := cam.unproject_position(ct * (a + Vector3(cx, cy, 0.0)))
			lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
			hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	return Rect2(lo, hi - lo)


# --- verkehr, kasten ----------------------------------------------------------------------------------------------

## The first of `candidates` that has no model and whose stand-in is of `kind` ("" = none left).
func _standin_set(candidates: Array[String], kind: String) -> String:
	for sid in candidates:
		if not ModelDB.has_model(sid) and VehicleStandIn.kind_of(sid, _db()) == kind:
			return sid
	return ""


## One car of `sid` at each of `dists` (m ahead of the camera, rear) in the lane `lane` m beside the player: the drawn
## pixels in both modes compared.
func _compare_cars(p: Array[String], sid: String, dists: Array, lane: float, tag: String) -> Array[String]:
	var msgs: Array[String] = []
	var res := {}
	for mode: String in ["arcade", "modern"]:
		var sc: Node = await _launch(mode)
		var r: Node = sc.get("renderer")
		var view: Dictionary = r.get("view")
		var cam_z := float(view.get("camera_z", 0.0))
		var x := float((view.get("player", {}) as Dictionary).get("x", 0.0)) + lane
		var empty := await _shot(mode, [], true)
		for d: float in dists:
			var img := await _shot(mode, [_car(9900, sid, cam_z + d, x)], true)
			res["%s_%d" % [mode, int(d)]] = _car_pixels(img, empty)
			_keep(img, "%s_%dm_%s" % [tag, int(d), mode])
		await _free(sc)
	for d: float in dists:
		msgs.append(_compare(p, "%s %.0f m" % [sid, d], res["arcade_%d" % int(d)], res["modern_%d" % int(d)]))
	return msgs


func _check_verkehr() -> void:
	var p: Array[String] = []
	var sid := _standin_set(TRAFFIC, VehicleStandIn.KIND_SPRITE)
	if sid == "":
		_report("verkehr", p, "kein Verkehrs-Set mehr ohne Modell – nichts zu vergleichen")
		return
	var msgs := await _compare_cars(p, sid, [20.0, 60.0, 150.0], -3.75, "verkehr")
	_report("verkehr", p, "; ".join(msgs))


func _check_kasten() -> void:
	var p: Array[String] = []
	var sid := _standin_set(BOXES, VehicleStandIn.KIND_BOX)
	if sid == "":
		_report("kasten", p, "kein Kasten-Set mehr ohne Modell – nichts zu vergleichen")
		return
	var msgs := await _compare_cars(p, sid, [30.5], -3.75, "kasten")
	_report("kasten", p, "; ".join(msgs))


# --- nacht --------------------------------------------------------------------------------------------------------

## Mean luminance of the body of a car in a picture: the top middle of the box its pixels cover by day (roof and rear
## window – no lamp, no glow, no baked shadow, no headlight pool on the road; at night the dark parts of a body hardly
## differ from the dark road, so a mask of the night frame would keep only its bright parts). The boxes of the two
## modes agree within 3 px by day (spieler, verkehr).
static func _body_lum(img: Image, day_box: Rect2i) -> float:
	var r := Rect2i(day_box.position.x + day_box.size.x * 3 / 10, day_box.position.y + day_box.size.y / 10,
		maxi(1, day_box.size.x * 2 / 5), maxi(1, day_box.size.y / 4))
	var d := img.get_data()
	var w := img.get_width()
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var o := (y * w + x) * 4
			sum += (0.2126 * float(d[o]) + 0.7152 * float(d[o + 1]) + 0.0722 * float(d[o + 2])) / 255.0
			n += 1
	return sum / maxf(1.0, float(n))


func _check_nacht() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	var veh := ""
	for v: String in PLAYERS:
		if not ModelDB.has_model("player/" + v):
			veh = v
			break
	# a light-coloured car first: its body stays above the dark end, where the 3D path of the Compatibility renderer
	# shows values below ~0.2 a few steps darker than the canvas (measured with the player's picture, by day as at
	# night: 11 -> 7, 19 -> 16, 28 -> 26.5 of 255, exact from about 56 on) – that is the renderer, not the light
	var light_first: Array[String] = ["traffic/van_white", "traffic/suv_white", "traffic/van_silver", "traffic/sports_yellow"]
	light_first.append_array(TRAFFIC)
	var sid := _standin_set(light_first, VehicleStandIn.KIND_SPRITE)
	var res := {}
	for mode: String in ["arcade", "modern"]:
		for hour: float in [12.0, 22.0]:
			var tag := "%s_%d" % [mode, int(hour)]
			var sc: Node = await _launch(mode, {"vehicle": veh if veh != "" else "limousine", "start_world_minutes": hour * 60.0})
			var r: Node = sc.get("renderer")
			var view: Dictionary = r.get("view")
			var cam_z := float(view.get("camera_z", 0.0))
			var x := float((view.get("player", {}) as Dictionary).get("x", 0.0)) - 3.75
			var without := await _shot(mode, [], true)
			var with_car := await _shot(mode, [], false)
			res[tag + "_spieler"] = {"img": with_car, "px": _car_pixels(with_car, without)}
			_keep(with_car, "nacht_%d_spieler_%s" % [int(hour), mode])
			_keep(without, "nacht_%d_leer_%s" % [int(hour), mode])
			if sid != "":
				for d: float in [20.0, 60.0]:
					var img := await _shot(mode, [_car(9901, sid, cam_z + d, x)], true)
					res["%s_%d" % [tag, int(d)]] = {"img": img, "px": _car_pixels(img, without)}
					_keep(img, "nacht_%d_%dm_%s" % [int(hour), int(d), mode])
					if hour > 12.0:
						# the same car with its tail lights on: the lit area is reported (glows: R3's flares, not Arcade's)
						var lit := _car(9901, sid, cam_z + d, x)
						lit["tail"] = 1.0
						var img_l := await _shot(mode, [lit], true)
						res["%s_%d_lit" % [tag, int(d)]] = _car_pixels(img_l, without)
						_keep(img_l, "nacht_%d_%dm_licht_%s" % [int(hour), int(d), mode])
			await _free(sc)
	var keys: Array[String] = []
	if veh != "":
		keys.append("spieler")
	if sid != "":
		keys.append_array(["20", "60"])
	for k: String in keys:
		var what := ("Spieler %s" % veh) if k == "spieler" else ("%s %s m" % [sid, k])
		var day: Dictionary = (res["arcade_12_" + k] as Dictionary)["px"]
		var day_m: Dictionary = (res["modern_12_" + k] as Dictionary)["px"]
		if int(day["n"]) == 0 or int(day_m["n"]) == 0:
			_need(p, false, "%s: gezeichnet (Arcade %d, Modern %d Pixel)" % [what, int(day["n"]), int(day_m["n"])])
			continue
		var box: Rect2i = day["box"]
		var la := _body_lum((res["arcade_22_" + k] as Dictionary)["img"], box)
		var lm := _body_lum((res["modern_22_" + k] as Dictionary)["img"], box)
		_need(p, absf(lm - la) / maxf(la, 0.01) <= BRIGHT, "%s: Helligkeit ± %.0f %% (Arcade %.3f, Modern %.3f)" % [what, BRIGHT * 100.0, la, lm])
		var line := "%s: Helligkeit %+.1f %% (%.3f / %.3f)" % [what, (lm - la) / maxf(la, 0.01) * 100.0, la, lm]
		if res.has("arcade_22_%s_lit" % k):
			line += ", mit Rücklicht %d px gegen %d px" % [int((res["modern_22_%s_lit" % k] as Dictionary)["n"]), int((res["arcade_22_%s_lit" % k] as Dictionary)["n"])]
		msgs.append(line)
	_report("nacht", p, "; ".join(msgs))


# --- verdeckt -----------------------------------------------------------------------------------------------------

## Height (m) by which the line of sight from the camera to the point (z, x, h) passes below the road between them
## (positive: hidden by the road by this much; negative: the view is free by this much). Sampled every 1.5 m – as in
## tests/race3d/render/check_occlusion.gd.
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


## Number of pixels whose colour differs between two pictures (RGBA8).
static func _diff_count(a: Image, b: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	var n := 0
	for o in range(0, da.size(), 4):
		if da[o] != db[o] or da[o + 1] != db[o + 1] or da[o + 2] != db[o + 2]:
			n += 1
	return n


## Occlusion as for models (contract §4.9.2): the picture of a car without a model stands at the depth of the car –
## behind a crest (Kassel – Würzburg km 61.6, T2), by day and at night, with its lamps on, two frames of the same
## moment with and without the hidden car are identical to the last pixel (body, glows, contact shadow); the same car
## where it can be seen draws pixels (the test is not empty). The shipped renderer: the look into the bend, contact
## shadows.
func _check_verdeckt() -> void:
	var p: Array[String] = []
	var msgs: Array[String] = []
	var sid := _standin_set(TRAFFIC, VehicleStandIn.KIND_SPRITE)
	if sid == "":
		_report("verdeckt", p, "kein Verkehrs-Set mehr ohne Modell – nichts zu prüfen")
		return
	for hour: float in [12.0, 22.0]:
		var sc: Node = await _launch("modern", {"stage_id": "kassel_wuerzburg", "from_city": "kassel", "start_km": 61.6,
			"vehicle": "kombi", "seed": 12, "start_world_minutes": hour * 60.0}, true)
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
		_need(p, hidden_z > 0.0, "%.0f Uhr: eine Kuppe voraus mit einer Stelle dahinter, die verdeckt ist" % hour)
		if hidden_z < 0.0:
			await _free(sc)
			continue
		var lit := {"tail": lights, "brake": 1.0, "blink": 1, "blink_t": 0.1}
		# a braking car of the same set beside the player in every picture: lamps are on screen in all of them
		var ref := _car(9600, sid, cam_z + 16.0, x - 3.75)
		ref.merge({"tail": lights, "brake": 1.0}, true)
		var empty := await _shot("modern", [ref], false)
		var hid := _car(9601, sid, hidden_z, x)
		hid.merge(lit, true)
		var hidden := await _shot("modern", [ref, hid], false)
		var n_hidden := _diff_count(empty, hidden)
		var noise := _diff_count(empty, await _shot("modern", [ref], false))
		var seen := _car(9601, sid, seen_z, x)
		seen.merge(lit, true)
		var shown := await _shot("modern", [ref, seen], false)
		var n_shown := _diff_count(empty, shown)
		_keep(hidden, "verdeckt_kuppe_%02d" % int(hour))
		_need(p, noise == 0, "%.0f Uhr: zwei Bilder derselben Szene gleich (%d Pixel verschieden)" % [hour, noise])
		_need(p, n_hidden == 0, "%.0f Uhr: Ersatzbild hinter der Kuppe (%.0f m) ändert 0 Pixel (geändert: %d)" % [hour, hidden_z - cam_z, n_hidden])
		_need(p, n_shown > 30, "%.0f Uhr: dasselbe Bild vor der Kuppe (%.0f m) ist zu sehen (%d Pixel)" % [hour, seen_z - cam_z, n_shown])
		msgs.append("%.0f Uhr hinter der Kuppe bei %.0f m: %d von %d Pixeln geändert (sichtbar bei %.0f m: %d Pixel)" % [hour,
			hidden_z - cam_z, n_hidden, empty.get_width() * empty.get_height(), seen_z - cam_z, n_shown])
		await _free(sc)
	_report("verdeckt", p, "Kassel – Würzburg km 61,6 (T2), %s: " % sid + "; ".join(msgs))


# --- laden --------------------------------------------------------------------------------------------------------

func _check_laden() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch("modern", {"autopilot": true, "start_speed_kmh": 120.0, "vehicle": "kombi", "traffic_warmup": true})
	var r: Node = sc.get("renderer")
	var vl: Node = r.call("layer", "vehicles")
	var db := _db()
	var loads0 := int(db.get("loads"))
	var seen := {}
	for f in 600:
		await process_frame
		if vl != null and f % 30 == 0:
			var st: Dictionary = vl.call("standin_state")
			for sid: String in st["drawn"]:
				if int((st["drawn"] as Dictionary)[sid]) > 0:
					seen[sid] = true
	var loads1 := int(db.get("loads"))
	var st2: Dictionary = vl.call("standin_state") if vl != null else {}
	_need(p, loads1 == loads0, "kein Blatt während der Fahrt geladen (SpriteDB.loads %d → %d)" % [loads0, loads1])
	# M2INT: since AS2R every vehicle set of the shipped manifest has a model – then no stand-in is drawn and no sheet
	# is loaded in prepare(); while one set still lacks a model, its stand-in must show up in the traffic
	var without := 0
	for sid: String in ModelDB.set_ids():
		if (sid.begins_with("traffic/") or sid.begins_with("police/") or sid.begins_with("player/")) and not ModelDB.has_model(sid):
			without += 1
	if without > 0:
		_need(p, not seen.is_empty(), "Ersatzbilder während der Fahrt gezeigt (%d Fahrzeug-Sets ohne Modell)" % without)
	else:
		_need(p, seen.is_empty() and float(st2.get("sheets_mb", 0.0)) == 0.0, "alle Fahrzeug-Sets haben ein Modell: kein Ersatzbild, kein Blatt (gezeigt %d, %.1f MB)" % [seen.size(), float(st2.get("sheets_mb", 0.0))])
	await _free(sc)
	_report("laden", p, "10 s mit Verkehr: SpriteDB.loads %d → %d, %d Blätter in prepare() (%.1f MB), Fahrzeug-Sets ohne Modell %d, gezeigt: %s" % [loads0, loads1,
		(st2.get("kinds", {}) as Dictionary).size(), float(st2.get("sheets_mb", 0.0)), without, ", ".join(PackedStringArray(seen.keys()))])
