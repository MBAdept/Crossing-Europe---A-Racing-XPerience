extends SceneTree
## QA-RINT-BILD probe (scratch only, never committed): how much of a test car Modern shows at 20…250 m ahead in three
## lanes at places with new structures (city houses in bends, canopies, border roofs, bridge parts). Pattern of
## tests/race3d/render/check_occlusion.gd: the shipped renderer + tests/race3d/fixtures/vehicle_probe_renderer.gd,
## still scene without traffic, a picture with and without the injected car; changed pixels counted in a box around
## the projected car. A car whose line of sight passes below the road (crest) is marked "road".
##   xvfb-run … godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 \
##     -s res://qa_occl.gd -- --graphics=modern --gfx-sync --gfx-preset=high --pos=<stage>:<from>:<km>:<hour>[;…] \
##     --save=<abs dir>
const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
var _probe: GDScript
var _renderers: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	cli["no-traffic"] = true
	_renderers.set("modern_script", PROBE)
	var save := str(cli.get("save", ""))
	for spec: String in str(cli.get("pos", "")).split(";", false):
		var f := spec.split(":")
		await _probe_pos(f[0], f[1], float(f[2]), float(f[3]), save)
	_probe.call("reset")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, max_frames: int = 3000) -> void:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1


func _shot(cars: Array) -> Image:
	_probe.set("inject", cars)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	if im.get_format() != Image.FORMAT_RGB8:
		im.convert(Image.FORMAT_RGB8)
	return im


func _car(id: int, z: float, x: float, lights: float) -> Dictionary:
	return {"kind": "car", "id": id, "set": "traffic/sedan_silver", "z": z, "x": x,
		"length": float(ModelDB.object_size("traffic/sedan_silver").get("length_m", 4.7)),
		"tail": lights, "brake": 0.0, "speed": 0.0, "blink": 0, "blink_t": 0.0}


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


func _diff_box(a: Image, b: Image, cx: int, cy: int, half: int) -> int:
	var x0 := clampi(cx - half, 0, a.get_width() - 1)
	var y0 := clampi(cy - half, 0, a.get_height() - 1)
	var x1 := clampi(cx + half, 0, a.get_width())
	var y1 := clampi(cy + half, 0, a.get_height())
	if x1 <= x0 or y1 <= y0:
		return -1
	var ra := a.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0)).get_data()
	var rb := b.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0)).get_data()
	var n := 0
	var i := 0
	while i < ra.size():
		if ra[i] != rb[i] or ra[i + 1] != rb[i + 1] or ra[i + 2] != rb[i + 2]:
			n += 1
		i += 3
	return n


func _probe_pos(stage: String, from: String, km: float, hour: float, save: String) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": stage, "from_city": from, "vehicle": "limousine",
		"start_world_minutes": hour * 60.0, "weather": "normal", "start_km": km, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 5)
	Engine.time_scale = 0.0
	await _frames(2)
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var px := float((view["player"] as Dictionary).get("x", 0.0))
	var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
	var cam: Camera3D = r.get("camera")
	var path: RoadPath3D = r.get("path")
	var empty := await _shot([])
	if save != "":
		empty.save_png(save.path_join("occl_%s_%.1f_%02d_leer.png" % [stage, km, int(hour)]))
	var lines: Array[String] = []
	var worst := 1.0
	var id := 9800
	for d in [20, 30, 40, 50, 60, 70, 80, 100, 120, 140, 160, 180, 200, 230, 260]:
		for dx: float in [-3.75, 0.0, 3.75]:
			var z := cam_z + float(d)
			var x := px + dx
			id += 1
			var hid := _below_road(r, z, x, 1.2)
			var w := path.world(z + 2.3, x, 0.75)
			if cam.is_position_behind(w):
				continue
			var sp := cam.unproject_position(w)
			var size_px := 711.0 * 1.8 / float(d)
			var expect := size_px * 711.0 * 1.45 / float(d)
			var img := await _shot([_car(id, z, x, lights)])
			var n := _diff_box(empty, img, int(sp.x), int(sp.y), int(maxf(24.0, size_px * 2.0)))
			var frac := float(n) / maxf(1.0, expect)
			var tag := "road" if hid > 0.2 else ("ok" if frac >= 0.5 else ("PART" if frac >= 0.1 else "HIDDEN"))
			if hid <= 0.2:
				worst = minf(worst, frac)
			lines.append("%s d=%3d dx=%+.2f px=(%4d,%4d) changed=%5d expect=%6.0f frac=%.2f below_road=%+.2f %s" % [
				stage, d, dx, int(sp.x), int(sp.y), n, expect, frac, hid, tag])
			if save != "" and (tag == "HIDDEN" or tag == "PART"):
				img.save_png(save.path_join("occl_%s_%.1f_%02d_d%03d_x%+.0f.png" % [stage, km, int(hour), d, dx]))
	for l in lines:
		print("OCCL ", l)
	print("OCCL-POS %s %s km %.2f %02d h: smallest visible fraction (road not hiding) %.2f" % [stage, from, km, int(hour), worst])
	_probe.call("reset")
	Engine.time_scale = 1.0
	sc.queue_free()
	await process_frame
	await process_frame
