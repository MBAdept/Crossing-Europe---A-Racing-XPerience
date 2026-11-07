extends SceneTree
## Render check (needs a real renderer, not --headless): glow occlusion (v0.5.1, docs/renn-modul.md §2). A light only
## glows where its source is visible – vehicles hidden behind a crest or a truck add nothing to the picture (v0.5.0:
## their indicator, tail and brake glows shone through the road), visible lights look exactly as with the old
## additive layer. Freezes the race scene on the test stage, places vehicles and captures each case in variants:
##   on  = render.glow_occlusion on, all vehicles          on_ref  = on, without the vehicles the case hides
##   off = glow occlusion off (v0.5.0 path), all vehicles  off_ref = off, without the hidden vehicles
##   off_dark = off_ref without the additive layer (no glows at all)
## Checks per case: "leak" (hidden vehicles): on = on_ref (they add nothing, also no halo cap above the crest) while
## off ≠ off_ref (the scene shows the v0.5.0 bug); "same": on_ref = off_ref (visible lights unchanged, ≤ 2/255) and
## off_ref ≠ off_dark (the scene has glows); "layer_sources": no glow of the additive layer starts inside the truck
## deeper than its bright core (tunnel lamps behind it; on the edge they fade), while v0.5.0 had some. A region
## restricts a check to the truck's box body (the hidden car
## may legitimately light the road beside the truck). First of all: the atlas of the painter's-order glows holds the
## gradient of the layer's GradientTexture2D byte for byte.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --resolution 1280x720 -s res://tests/race/check_glow_occlusion.gd [-- --only=crest_day,truck_day --out=/tmp/g]
## --out saves every capture as <out>_<case>_<variant>.png. Prints "GLOW-CHECK <case> OK|FEHLER …" and a summary;
## exit code 0 = all OK. (Untyped access to the race scene: -s scripts compile before the autoloads it uses.)

## cars: [set, lane, gap (m from the player's front to the vehicle's rear), blink (-1/0/1), brake (0/1)]
const CASES := [
	# the user's case (v0.5.1): blinking cars behind the crest of the test stage at km 34.6 by day; the wagon in front
	# of the crest blinks visibly
	{"name": "crest_day", "km": 34.6, "hour": 12.0, "lane": 1,
		"cars": [["traffic/wagon_white", 0, 60, -1, 0], ["traffic/sedan_blue", 1, 150, 1, 0], ["traffic/suv_white", 0, 190, -1, 1],
			["traffic/hatch_red", 1, 240, 1, 0]],
		"hidden": [1, 2, 3], "checks": ["leak", "same"]},
	# the same at night: indicators, tail and brake lights, a truck's rear lights behind the crest
	{"name": "crest_night", "km": 34.6, "hour": 22.0, "lane": 1,
		"cars": [["traffic/wagon_white", 0, 60, -1, 0], ["traffic/sedan_blue", 1, 150, 1, 0], ["traffic/truck_white", 0, 190, 0, 1],
			["traffic/hatch_red", 1, 240, 0, 0]],
		"hidden": [1, 2, 3], "checks": ["leak", "same"]},
	# a car directly in front of a truck (hidden by the 4 m box from the 3.4 m camera), blinking and braking by day;
	# a car in the next lane blinks visibly
	{"name": "truck_day", "km": 30.0, "hour": 12.0, "lane": 1,
		"cars": [["traffic/truck_white", 1, 25, 0, 0], ["traffic/sedan_red", 1, 44, 1, 1], ["traffic/hatch_yellow", 0, 70, -1, 0]],
		"hidden": [1], "checks": ["leak", "same"]},
	# the same at night. The hidden car still lights the road beside the truck and, through the gap under the
	# trailer, the road just behind it (light on the road, not a glow through the truck) – checked on the trailer box
	{"name": "truck_night", "km": 30.0, "hour": 22.0, "lane": 1,
		"cars": [["traffic/truck_white", 1, 25, 0, 0], ["traffic/sedan_red", 1, 44, 1, 1]],
		"hidden": [1], "checks": ["leak"], "region": "trailer"},
	# tunnel lamps beyond a truck in the tunnel: no glow of the additive layer starts inside the truck (lamps just
	# beside it keep their halo, which may reach over its edge)
	{"name": "tunnel_truck", "km": 51.5, "hour": 12.0, "lane": 1,
		"cars": [["traffic/truck_white", 1, 12, 0, 0]],
		"hidden": [], "checks": ["layer_sources"]},
	# nothing hidden: visible lights look as before
	{"name": "night_road", "km": 30.0, "hour": 22.0, "lane": 1,
		"cars": [["traffic/sedan_red", 0, 40, 1, 1], ["traffic/suv_black", 2, 70, -1, 0], ["traffic/hatch_yellow", 1, 110, 0, 1],
			["traffic/wagon_white", 0, 160, 1, 0]],
		"hidden": [], "checks": ["same"]},
	{"name": "tunnel_in", "km": TUNNEL_IN_KM, "hour": 12.0, "lane": 1,
		"cars": [["traffic/sedan_blue", 0, 80, 0, 0], ["traffic/hatch_red", 0, 180, 0, 1]],
		"hidden": [], "checks": ["same"]},
	{"name": "portal_out", "km": 49.93, "hour": 22.0, "lane": 1, "cars": [], "hidden": [], "checks": ["same"]},
	{"name": "fuel_night", "km": 19.33, "hour": 22.0, "lane": 2, "cars": [], "hidden": [], "checks": ["same"]},
	# start lights during the countdown
	{"name": "start_lights", "km": 0.0, "hour": 21.0, "lane": 1, "cars": [], "hidden": [], "checks": ["same"], "countdown": true},
	# review v0.5.1: a car right in front of the player car (5.1 m gap, its rear 16.5 m from the camera) on the flat A7,
	# braking and blinking – its lamps are visible above the player car, their halo lies over its roof as in v0.5.0
	# (v0.5.1 before the review cut it at the roof: 300–1500 px)
	{"name": "ahead_day", "stage": "kassel_wuerzburg", "km": 3.0, "hour": 12.0, "lane": 1,
		"cars": [["traffic/sedan_red", 1, 5.1, 1, 1]], "hidden": [], "checks": ["same"]},
	{"name": "ahead_night", "stage": "kassel_wuerzburg", "km": 3.0, "hour": 22.0, "lane": 1,
		"cars": [["traffic/sedan_red", 1, 5.1, 1, 1]], "hidden": [], "checks": ["same"]},
	# review v0.5.1: a blinking, braking car right in front of a bus 190 m ahead on the A7 – both in the same merged
	# slice (20–72 m deep there, asserted): the bus covers its glow too (glows follow their own item, not the slice;
	# drawn at the end of the slice, v0.5.1 before the review let it shine over the bus: 9/18 px). A bus, as that far
	# a car's lamps show through the gap under a trailer; checked on its body above the gap under it (the hidden car's
	# underside and the lower edge of its halo show there, its right edge peeks out beside the bus in the curve)
	{"name": "far_bus_day", "stage": "kassel_wuerzburg", "km": 2.0, "hour": 12.0, "lane": 2,
		"cars": [["traffic/bus_white", 2, 178.6, 0, 0], ["traffic/sedan_red", 2, 193.6, -1, 1]],
		"hidden": [1], "checks": ["leak"], "region": "body", "same_slice": [0, 1]},
	{"name": "far_bus_night", "stage": "kassel_wuerzburg", "km": 2.0, "hour": 22.0, "lane": 2,
		"cars": [["traffic/bus_white", 2, 178.6, 0, 0], ["traffic/sedan_red", 2, 193.6, -1, 1]],
		"hidden": [1], "checks": ["leak"], "region": "body", "same_slice": [0, 1]},
	# review v0.5.1: the exit of the test tunnel by day from inside – the over-exposed outside (vertex colours above 1
	# with alpha below 1 at fog-faded and sprite edges) keeps its brightness (GLOW_SHADER clamps before premultiplying)
	{"name": "tunnel_exit_day", "km": 53.85, "hour": 12.0, "lane": 1,
		"cars": [["traffic/sedan_blue", 0, 60, 0, 1], ["traffic/hatch_red", 1, 230, 0, 0]], "hidden": [], "checks": ["same"]},
]
const TUNNEL_IN_KM := 50.3    ## straight part of the test tunnel (from km 50.45 on lamps behind the inner wall of the bend are hidden)
const SAME_TOL := 2           ## max channel difference (1/255) for "unchanged"
const LEAK_MIN_PX := 8        ## the v0.5.0 path must show at least this many leak pixels (> 8/255)

var _cases: Array = []
var _ci := -1
var _sc: Node
var _frame := 0
var _plan: Array[String] = []
var _pi := 0
var _wait := 0
var _capture := false
var _imgs: Dictionary = {}
var _cars: Array = []
var _occ_rect := Rect2()
var _out := ""
var _errors := 0
var _ok := 0
var _rr: GDScript
var _occ_quads := PackedVector2Array()
var _sources: Dictionary = {}      ## variant -> layer glow sources inside the occluder outline
var _slice_msg := ""               ## same_slice: "" or why the scene does not show the case


func _initialize() -> void:
	_out = CliArgs.get_string("out", "")
	var only := CliArgs.get_string("only", "")
	for c: Dictionary in CASES:
		if only == "" or only.split(",").has(str(c["name"])):
			var cc := c.duplicate(true)
			# exploration aids: another camera position / hour for the selected cases
			if CliArgs.has("km"):
				cc["km"] = CliArgs.get_float("km", float(c["km"]))
			if CliArgs.has("hour"):
				cc["hour"] = CliArgs.get_float("hour", float(c["hour"]))
			_cases.append(cc)
	_rr = load("res://scripts/race/road_renderer.gd")
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_next_case()


func _next_case() -> void:
	if _sc != null:
		_sc.queue_free()
		_sc = null
	_ci += 1
	if _ci >= _cases.size():
		print("GLOW-CHECK %d OK, %d FEHLER" % [_ok, _errors])
		quit(1 if _errors > 0 or _ok == 0 else 0)
		return
	var c: Dictionary = _cases[_ci]
	var setup := {"mode": "single", "race_id": "", "stage_id": str(c.get("stage", "dev_testetappe")), "from_city": "", "vehicle": "limousine",
		"start_world_minutes": float(c["hour"]) * 60.0, "weather": "normal", "start_km": float(c["km"]), "autopilot": false,
		"no_countdown": not bool(c.get("countdown", false)), "seed": 5}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	_frame = 0
	_imgs.clear()
	_sources.clear()
	_occ_quads = PackedVector2Array()
	_plan.clear()
	for v in ["on", "on_ref", "off", "off_ref", "off_dark"]:
		_plan.append(v)
	_pi = 0


func _process(_d: float) -> bool:
	if _sc == null:
		return false
	_frame += 1
	if _frame == 3:
		if _ci == 0:
			_check_atlas()
		_freeze()
		_apply(_plan[0])
		_wait = 4
	elif _frame > 3 and _wait > 0:
		_wait -= 1
		if _wait == 0:
			_capture = true
	return false


## The atlas of the painter's-order glows holds byte for byte the gradient of the layer's GradientTexture2D (which
## only a real renderer can read back), so both paths draw the same glow.
func _check_atlas() -> void:
	var r: Object = _sc.get("renderer")
	var tex: GradientTexture2D = r.get("_glow_tex")
	var ref := tex.get_image()
	if ref == null or ref.is_empty():
		_fail("atlas", "GradientTexture2D nicht lesbar")
		return
	ref.convert(Image.FORMAT_RGBA8)
	var atlas: Image = _rr.call("glow_atlas_image", tex.gradient)
	var part := atlas.get_region(Rect2i(0, 0, 64, 64))
	if part.get_data() == ref.get_data():
		_ok += 1
		print("GLOW-CHECK atlas OK: Verlauf byte-genau wie die GradientTexture2D der Leuchtebene")
	else:
		var m: Dictionary = part.compute_image_metrics(ref, false)
		_fail("atlas", "Verlauf weicht ab (max %s)" % str(m.get("max", "?")))
		if _out != "":
			ref.save_png(_out + "_atlas_ref.png")
			part.save_png(_out + "_atlas_own.png")


## Physics off (the frozen view stays identical between the variants), random traffic off, the case's vehicles placed
## relative to the player (lane, gap), indicators lit (age 0.1 s).
func _freeze() -> void:
	var c: Dictionary = _cases[_ci]
	_sc.set_physics_process(false)
	# render interpolation (v0.6.0) draws between the last two simulation steps at Engine's fraction, which varies
	# with the frame timing: the frozen view must show the placed state itself in every variant
	_sc.set("_view_alpha", 1.0)
	_sc.set("running", not bool(c.get("countdown", false)))
	(_sc.get("hud") as CanvasItem).visible = false
	var traffic: Object = _sc.get("traffic")
	var track: Object = _sc.get("track")
	var veh: Object = _sc.get("vehicle")
	var empty: Array[String] = []
	traffic.set("car_sets", empty)
	traffic.set("heavy_sets", empty)
	(traffic.get("cars") as Array).clear()
	var pz: float = _sc.get("pos_z")
	track.call("update_window", pz - 9.0, 960.0)
	veh.set("x", float(track.call("lane_center_x", pz, int(c["lane"]))))
	_sc.set("cam_x", veh.get("x"))
	veh.set("speed", 0.0)
	var plen: float = veh.get("length_m")
	var db: Node = root.get_node("SpriteDB")
	_cars.clear()
	var i := 0
	for spec: Array in c["cars"]:
		var car := TrafficSystem.Car.new()
		car.id = 9000 + i
		car.set_id = str(spec[0])
		var dims: Dictionary = db.call("object_size", car.set_id)
		car.length = float(dims.get("length_m", 4.5))
		car.width = float(dims.get("width_m", 1.8))
		car.height = float(dims.get("height_m", 1.5))
		car.heavy = car.set_id.contains("truck") or car.set_id.contains("bus")
		car.z = pz + plen * 0.5 + float(spec[2]) + car.length * 0.5
		car.lane = int(spec[1])
		car.x = float(track.call("lane_center_x", car.z, car.lane))
		car.speed = 80.0
		car.cruise_speed = 80.0
		car.lane_cooldown = 1.0e9
		car.signal_dir = int(spec[3])
		car.signal_age = 0.1
		car.braking = int(spec[4]) == 1
		_cars.append(car)
		i += 1


func _apply(variant: String) -> void:
	var c: Dictionary = _cases[_ci]
	var r: Object = _sc.get("renderer")
	r.call("set_glow_occlusion", variant.begins_with("on"))
	RenderingServer.canvas_item_set_visible(r.get("_glow_ci"), variant != "off_dark")
	var arr: Array = (_sc.get("traffic") as Object).get("cars")
	arr.clear()
	var hidden: Array = c["hidden"]
	for i in _cars.size():
		if variant.ends_with("_ref") or variant == "off_dark":
			if hidden.has(i):
				continue
		arr.append(_cars[i])


func _on_post_draw() -> void:
	if not _capture:
		return
	_capture = false
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("GLOW-CHECK FEHLER: kein Bild (läuft der Check mit --headless? Er braucht einen echten Renderer)")
		quit(1)
		return
	var variant := _plan[_pi]
	_imgs[variant] = img
	var c: Dictionary = _cases[_ci]
	var r: Object = _sc.get("renderer")
	if variant == "on":
		_occ_quads = r.call("vehicle_outlines")
		_occ_rect = _occluder_rect(r, str(c.get("region", "")))
		_slice_msg = _check_same_slice(r, c)
	_sources[variant] = _sources_inside(r.get("_gp"), r.get("_gr"))
	if _out != "":
		img.save_png("%s_%s_%s.png" % [_out, str(c["name"]), variant])
	_pi += 1
	if _pi >= _plan.size():
		_evaluate()
		_next_case()
		return
	_apply(_plan[_pi])
	_wait = 4


## Screen rect of the trucks and buses drawn as occluders (bounding box of their drawn faces; a car hidden behind
## one may peek out beside it), shrunk by 2 px (a tenth of a small one); empty without one. mode "trailer": its upper
## 60 % only (the box body of a truck seen from behind, above its rear bumper and the open space under the trailer);
## "body": its upper 80 % (a bus above the gap under it).
func _occluder_rect(r: Object, mode: String) -> Rect2:
	var pts := PackedVector2Array()
	for q: PackedVector2Array in r.get("_occ_b"):
		pts.append_array(q)
	if pts.is_empty():
		return Rect2()
	var out := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		out = out.expand(q)
	if mode == "trailer":
		out.size.y *= 0.6
	elif mode == "body":
		out.size.y *= 0.8
	out = out.grow(-clampf(minf(out.size.x, out.size.y) * 0.1, 0.5, 2.0)).intersection(Rect2(0, 0, 1280, 720))
	return out


## same_slice [i, j]: the rears of vehicles i and j lie in the same scene slice of the renderer ("" if so).
func _check_same_slice(r: Object, c: Dictionary) -> String:
	if not c.has("same_slice"):
		return ""
	var sa: PackedInt32Array = r.get("_sl_a")
	var sb: PackedInt32Array = r.get("_sl_b")
	var base := int(r.get("_base"))
	var seg := float(r.get("_seg_len"))
	var sl: Array[int] = []
	for i: int in c["same_slice"]:
		var car: TrafficSystem.Car = _cars[i]
		var k := int(floor((car.z - car.length * 0.5) / seg)) - base
		var idx := -1
		for si in sa.size():
			if k >= sa[si] and k < sb[si]:
				idx = si
				break
		sl.append(idx)
	if sl[0] < 0 or sl[0] != sl[1]:
		return "Fahrzeuge nicht in derselben Scheibe (%s) – Szene anpassen" % str(sl)
	return ""


## Number of glow sources of the additive layer (positions, radii) inside the occluder outline of the "on" frame –
## deeper than the bright core of their glow (a lamp on the edge of the truck fades in and out over its core,
## RoadRenderer.edge_visibility, review v0.5.1).
func _sources_inside(gp: PackedVector2Array, gr: PackedFloat32Array) -> int:
	var hull := Geometry2D.convex_hull(_occ_quads)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.resize(hull.size() - 1)
	var n := 0
	for i in gp.size():
		var p := gp[i]
		for q in range(0, _occ_quads.size() - 3, 4):
			if bool(_rr.call("point_in_quad", p, _occ_quads[q], _occ_quads[q + 1], _occ_quads[q + 2], _occ_quads[q + 3])):
				var sd: float = _rr.call("convex_signed_distance", p, hull)
				if sd < -maxf(0.75, 0.25 * gr[i]):
					n += 1
				break
	return n


func _evaluate() -> void:
	var c: Dictionary = _cases[_ci]
	var name := str(c["name"])
	var region := Rect2(0, 0, (_imgs["on"] as Image).get_width(), (_imgs["on"] as Image).get_height())
	if str(c.get("region", "")) != "":
		region = _occ_rect
		if region.size.x < 4.0 or region.size.y < 4.0:
			_fail(name, "kein Fahrzeug als Verdecker gezeichnet")
			return
	var msgs: Array[String] = []
	var ok := true
	if _slice_msg != "":
		ok = false
		msgs.append(_slice_msg)
	for check: String in c["checks"]:
		match check:
			"leak":
				var leak := _count(_imgs["on"], _imgs["on_ref"], region, SAME_TOL)
				var old := _count(_imgs["off"], _imgs["off_ref"], region, 8)
				msgs.append("Leck %d px (v0.5.0: %d px)" % [leak, old])
				if leak > 0:
					ok = false
					msgs.append("verdeckte Fahrzeuge leuchten durch")
				if old < LEAK_MIN_PX:
					ok = false
					msgs.append("die Szene zeigt das Leck von v0.5.0 nicht mehr – Szene anpassen")
			"same":
				var diff := _count(_imgs["on_ref"], _imgs["off_ref"], region, SAME_TOL)
				var glow := _count(_imgs["off_ref"], _imgs["off_dark"], region, 8)
				msgs.append("sichtbare Lichter: %d px Glühen, %d px verändert" % [glow, diff])
				if diff > 0:
					ok = false
					msgs.append("sichtbare Lichter sehen anders aus als in v0.5.0")
				if glow < 20:
					ok = false
					msgs.append("die Szene hat kaum sichtbare Lichter")
			"layer_sources":
				var on_n := int(_sources.get("on", 0))
				var off_n := int(_sources.get("off", 0))
				msgs.append("Lampen hinter dem Lkw mit Leuchten: %d (v0.5.0: %d)" % [on_n, off_n])
				if _occ_quads.is_empty():
					ok = false
					msgs.append("kein Fahrzeug als Verdecker gezeichnet")
				if on_n > 0:
					ok = false
					msgs.append("Lampen hinter dem Lkw leuchten durch")
				if off_n < 1:
					ok = false
					msgs.append("die Szene zeigt das Leck von v0.5.0 nicht mehr – Szene anpassen")
	if ok:
		_ok += 1
		print("GLOW-CHECK %s OK: %s" % [name, ", ".join(msgs)])
	else:
		_fail(name, ", ".join(msgs))


func _fail(name: String, msg: String) -> void:
	_errors += 1
	print("GLOW-CHECK %s FEHLER: %s" % [name, msg])


## Pixels inside region whose largest channel difference between a and b exceeds tol (in 1/255).
func _count(a: Image, b: Image, region: Rect2, tol: int) -> int:
	var r := Rect2i(region)
	var ra := a.get_region(r)
	var rb := b.get_region(r)
	ra.convert(Image.FORMAT_RGB8)
	rb.convert(Image.FORMAT_RGB8)
	var m: Dictionary = ra.compute_image_metrics(rb, false)
	if float(m.get("max", 0.0)) <= float(tol):
		return 0
	var da := ra.get_data()
	var db := rb.get_data()
	var n := 0
	for i in range(0, da.size(), 3):
		var d := maxi(absi(da[i] - db[i]), maxi(absi(da[i + 1] - db[i + 1]), absi(da[i + 2] - db[i + 2])))
		if d > tol:
			n += 1
	return n
