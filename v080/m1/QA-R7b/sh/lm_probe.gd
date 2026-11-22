extends SceneTree
## QA-R7b probe: one Modern frame with and without the landmark nodes (and with only them), plus the live landmarks of
## the builder's snapshot and the camera. Args after --: --stage= --from= --start-km= --hour= --out=<abs prefix>
##   [--speed=50] [--steps=60]

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _grab() -> Image:
	if DisplayServer.get_name() == "headless":
		return Image.create(4, 4, false, Image.FORMAT_RGB8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a := CliArgs.all()
	a.erase("graphics")
	var out := str(a.get("out", "/tmp/lm_probe"))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")), "from_city": str(a.get("from", "kiel")),
		"vehicle": "limousine", "start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": "normal",
		"start_km": float(a.get("start-km", 85.6)), "autopilot": true, "autopilot_refuel": "never", "seed": 11, "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": float(a.get("speed", 50.0)), "traffic_warmup": true}
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		await process_frame
		n += 1
	for i in int(a.get("steps", 60)):
		await process_frame
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false
	var r: Object = sc.get("renderer")
	paused = true
	for i in 3:
		await process_frame
	var with := await _grab()
	with.save_png(out + "_mit.png")
	var world: Node = r.get("world")
	var lms: Array = []
	var others: Array = []
	for c: Node in world.get_children():
		if str(c.name).begins_with("Landmark"):
			lms.append(c)
		elif c is Node3D and (c as Node3D).visible:
			others.append(c)
	for c: Node in lms:
		(c as Node3D).visible = false
	for i in 2:
		await process_frame
	var without := await _grab()
	without.save_png(out + "_ohne.png")
	var b: Object = r.call("builder", "landmarks")
	var view: Dictionary = r.get("view")
	print("PROBE cam_z %.1f cam_x %.2f vis %.0f" % [float(view.get("camera_z", 0.0)), float(view.get("camera_x", 0.0)), float(view.get("visibility_m", 0.0))])
	for e: Dictionary in ((b.call("snapshot") as Dictionary).get("landmarks", []) as Array):
		print("PROBE LM ", JSON.stringify(e))
	for c: Node in lms:
		var nd := c as Node3D
		var aabb := AABB()
		for m: Node in nd.get_children():
			if m is MeshInstance3D:
				aabb = aabb.merge((m as MeshInstance3D).get_aabb())
		print("PROBE NODE %s pos %s scale %s aabb %s" % [nd.name, str(nd.global_position), str(nd.scale), str(aabb)])
	paused = false
	sc.queue_free()
	await process_frame
	await process_frame
	quit(0)
