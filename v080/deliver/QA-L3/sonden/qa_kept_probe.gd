extends SceneTree
## QA lens 3: generator streams ModernAudioContext keeps alive – are they released once the profile is Arcade again?
func _initialize() -> void:
	_run.call_deferred()

func _process(_d: float) -> bool:
	return false

func _wait(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _run() -> void:
	for i in 5:
		await process_frame
	var am: Node = root.get_node("AudioManager")
	var ctx: GDScript = load("res://scripts/audio/modern/modern_audio_context.gd")
	var res0 := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for n in int(OS.get_cmdline_user_args()[0].trim_prefix("--n=")) if OS.get_cmdline_user_args().size() > 0 and OS.get_cmdline_user_args()[0].begins_with("--n=") else 1:
		am.call("set_profile", "modern")
		am.call("set_vehicle", "limousine")
		am.call("preview_engine", "kombi")
		for i in 40:
			am.call("set_engine", 120.0, 1.0, 245.0, true)
			await process_frame
		am.call("set_profile", "arcade")
		await process_frame
	print("KEPT right after the last switch back to Arcade: %d streams" % int(ctx.call("kept_count")))
	for s in [1, 3, 6, 10]:
		await _wait(float(s) if s == 1 else float(s) - float([1, 3, 6, 10][[1, 3, 6, 10].find(s) - 1]))
		print("KEPT %2d s later (profile %s): %d streams held, resources %+d, objects %+d against the start" % [s, str(am.call("profile")),
			int(ctx.call("kept_count")), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) - res0,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)) - obj0])
	ctx.call("release_kept")
	await process_frame
	print("KEPT after one call of ModernAudioContext.release_kept(): %d streams held, resources %+d, objects %+d" % [int(ctx.call("kept_count")),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) - res0, int(Performance.get_monitor(Performance.OBJECT_COUNT)) - obj0])
	quit(0)
