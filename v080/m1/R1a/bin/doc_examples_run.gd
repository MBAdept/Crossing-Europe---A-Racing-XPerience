extends SceneTree
## Scratch (R1a): runs the two examples of docs/renderer-modern.md §9.5 inside the real renderer (bare probe) and
## prints what they did. With --shot=<abs png> under Xvfb it also saves a picture.

const DIR := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a/doc_examples/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe: GDScript = load("res://tests/race3d/fixtures/facade_probe_renderer.gd")
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	probe.call("reset")
	probe.set("bare", true)
	probe.set("layer_scripts", {"overlay": DIR + "overlay.gd"})
	var builders: Array[String] = [DIR + "roadside.gd"]
	probe.set("builder_scripts", builders)
	renderers.set("modern_script", "res://tests/race3d/fixtures/facade_probe_renderer.gd")
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11, "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": 120.0})
	root.add_child(sc)
	for i in 90:
		await process_frame
	var r: Node = sc.get("renderer")
	var snap: Dictionary = r.call("debug_snapshot")
	var perf: Dictionary = r.call("perf_stats")
	print("BEISPIEL healthy=", r.call("healthy"), " prepared=", r.call("is_prepared"), " fail=", r.call("fail_reason"),
		" layers=", snap.get("layers"), " builders=", snap.get("builders"), " props=", snap.get("props"), " lamps=", snap.get("lamps"),
		" instances=", perf.get("instances"), " warmup_nodes=", perf.get("warmup_nodes"))
	var chunks: Array = snap.get("chunks", [])
	if not chunks.is_empty():
		print("BEISPIEL parts=", (chunks[0] as Dictionary).get("parts", {}).get("roadside", {}))
	var shot := str(CliArgs.all().get("shot", ""))
	if shot != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shot)
		print("BEISPIEL Bild ", shot)
	sc.queue_free()
	await process_frame
	await process_frame
	quit(0)
