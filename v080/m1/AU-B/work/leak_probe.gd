extends SceneTree
## Scratch probe: does Godot report leaks when a game quits while an AudioStreamPlayer plays?
##   --mode=plain   player left alone, quit()
##   --mode=stop    player.stop() + queue_free() in the same frame as quit()
##   --mode=wait    player.stop() + queue_free(), three frames, then quit()

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode := "plain"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	await process_frame
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/modern/vehicle/turbo_hiss.wav")
	root.add_child(p)
	p.play()
	for i in 20:
		await process_frame
	if mode == "stop" or mode == "wait" or mode == "wait_long":
		p.stop()
		p.stream = null
		p.queue_free()
	if mode == "wait":
		for i in 3:
			await process_frame
	if mode == "wait_long":
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 300:
			await process_frame
	print("probe ", mode, " quits")
	quit(0)
