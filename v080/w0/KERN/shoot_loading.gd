extends SceneTree
## Scratch (not part of the repo): picture of the session's loading overlay while a Modern renderer prepares the
## stage (probe renderer with a long preparation), at 16:9 and in a 16:10 window.
##   xvfb-run … godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -s <this> -- --out=<prefix>

func _initialize() -> void:
	_run.call_deferred()


func _shoot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("gespeichert ", path, " ", img.get_size())


func _run() -> void:
	var out := str(CliArgs.all().get("out", "/tmp/loading"))
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	var probe: GDScript = load("res://tests/race3d/fixtures/seam_probe_renderer.gd")
	renderers.set("modern_script", "res://tests/race3d/fixtures/seam_probe_renderer.gd")
	probe.call("reset")
	probe.set("prepare_frames", 100000)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1152, 720)]:
		root.size = size
		for i in 5:
			await process_frame
		var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
		sc.set("setup", {"mode": "single", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
			"start_world_minutes": 720.0, "weather": "rain", "start_km": 2.0, "autopilot": true, "gfx": "modern"})
		await physics_frame
		root.add_child(sc)
		for i in 20:
			await process_frame
		await _shoot("%s_%dx%d.png" % [out, size.x, size.y])
		print("sim_steps ", sc.get("_sim_steps"), " logical ", root.get_visible_rect().size)
		sc.queue_free()
		for i in 3:
			await process_frame
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	quit(0)
