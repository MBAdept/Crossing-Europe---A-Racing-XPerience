extends SceneTree
## FIX-R7b probe: how many pixels the landmarks cover (frame with / without their nodes) at several stage kms.
## Args after --: --stage-id= --from-city= --kms=a,b,c --hour=

func _initialize() -> void:
	_run.call_deferred()


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a := CliArgs.all()
	for km_s: String in str(a.get("kms", "299.4")).split(","):
		var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage-id", "montpellier_lyon")),
			"from_city": str(a.get("from-city", "montpellier")), "vehicle": "limousine",
			"start_world_minutes": float(a.get("hour", 22.0)) * 60.0, "weather": "normal", "start_km": km_s.to_float(),
			"autopilot": true, "autopilot_refuel": "never", "seed": 11, "gfx": "modern", "no_countdown": true,
			"start_speed_kmh": 0.0, "traffic_warmup": false}
		CliArgs.all()["no-traffic"] = true
		CliArgs.all()["gfx-sync"] = true
		var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
		sc.set("setup", setup)
		await physics_frame
		root.add_child(sc)
		var n := 0
		while not bool(sc.call("is_live")) and n < 3000:
			await process_frame
			n += 1
		for i in 30:
			await process_frame
		for c: Node in sc.get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
				(c as CanvasLayer).visible = false
		paused = true
		await process_frame
		var with := await _grab()
		var r: Object = sc.get("renderer")
		var world: Node = r.get("world")
		for c: Node in world.get_children():
			if str(c.name).begins_with("Landmark"):
				(c as Node3D).visible = false
		await process_frame
		var without := await _grab()
		var cnt := 0
		var x0 := 9999
		var x1 := -1
		var dw := with.get_data()
		var dn := without.get_data()
		var w := with.get_width()
		for i in range(0, dw.size(), 3):
			if maxi(absi(dw[i] - dn[i]), maxi(absi(dw[i + 1] - dn[i + 1]), absi(dw[i + 2] - dn[i + 2]))) >= 14:
				cnt += 1
				x0 = mini(x0, (i / 3) % w)
				x1 = maxi(x1, (i / 3) % w)
		print("PROBE km %s: %d Pixel, x %d..%d" % [km_s, cnt, x0, x1])
		paused = false
		sc.queue_free()
		await process_frame
		await process_frame
	quit(0)
