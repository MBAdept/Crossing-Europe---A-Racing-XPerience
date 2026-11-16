extends SceneTree
## QA lens 3: stress of the Arcade engine player life cycle on tag v0.7.0 (frozen EngineAudio.detach()): engine and
## preview players are stopped and freed while they play. Prints a line every 50 cycles; a hang shows as a timeout.
func _initialize() -> void:
	_run.call_deferred()

func _process(_d: float) -> bool:
	return false

func _run() -> void:
	for i in 5:
		await process_frame
	var am: Node = root.get_node("AudioManager")
	var cars := ["limousine", "kombi", "kompakt", "gran_turismo", "sportwagen"]
	var n := 400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cycles="):
			n = int(a.substr(9))
	for c in n:
		am.call("set_vehicle", cars[c % 5])
		am.call("preview_engine", cars[(c + 1) % 5])
		for i in 3 + c % 4:
			am.call("set_engine", 80.0 + c % 100, 1.0, 245.0, true)
			await process_frame
		am.call("preview_engine", cars[(c + 2) % 5])
		if c % 3 == 0:
			await process_frame
		am.call("stop_all")           # stage change: engine and preview detached while playing
		if c % 2 == 0:
			await process_frame
		if c % 50 == 49:
			print("STRESS %d cycles" % (c + 1))
	print("STRESS done %d cycles, players %d" % [n, am.get_child_count()])
	quit(0)
