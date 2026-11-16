extends SceneTree
## QA lens 1: pause in a running Modern stage (under Xvfb): the picture stands, nothing of the stage runs.

const RACE := "res://scenes/race/race.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key) -> void:
	for pr: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pr
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		for i in 3:
			await process_frame

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n

func _run() -> void:
	for mode: String in ["modern", "arcade"]:
		var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "", "vehicle": "limousine",
			"start_world_minutes": 21.0 * 60.0, "weather": "rain", "start_km": 30.0, "autopilot": false, "seed": 3, "no_countdown": true, "gfx": mode}
		var sc: Node = (load(RACE) as PackedScene).instantiate()
		sc.set("setup", setup)
		root.add_child(sc)
		var f := 0
		while not bool(sc.call("is_live")) and f < 600:
			await process_frame
			f += 1
		for i in 90:
			Input.action_press("accelerate")
			await process_frame
		var before_steps := int(sc.get("_sim_steps"))
		await _key(KEY_P)
		var paused_now := paused
		var steps_a := int(sc.get("_sim_steps"))
		var frames_a := int((sc.call("perf_stats") as Dictionary).get("frames", -1))
		var a := await _grab()
		for i in 30:
			await process_frame
		var b := await _grab()
		var steps_b := int(sc.get("_sim_steps"))
		var frames_b := int((sc.call("perf_stats") as Dictionary).get("frames", -1))
		var menu: Control = sc.get("pause_menu")
		print("QA-PAUSE %s: paused=%s, pause menu visible=%s, sim steps %d -> %d over 30 frames, renderer frames %d -> %d, pixels different between the two paused pictures: %d of %d, speed %.0f km/h" % [
			mode, paused_now, menu.visible, steps_a, steps_b, frames_a, frames_b, _diff(a, b), a.get_width() * a.get_height(), float((sc.get("vehicle") as Object).get("speed"))])
		a.save_png("%s/pause_%s.png" % [CliArgs.get_string("out", "/tmp"), mode])
		await _key(KEY_P)
		for i in 10:
			await process_frame
		print("QA-PAUSE %s: after the second key: paused=%s, menu visible=%s, steps now %d (were %d before the pause)" % [mode, paused, menu.visible, int(sc.get("_sim_steps")), before_steps])
		paused = false
		Input.action_release("accelerate")
		sc.queue_free()
		for i in 5:
			await process_frame
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	quit(0)
