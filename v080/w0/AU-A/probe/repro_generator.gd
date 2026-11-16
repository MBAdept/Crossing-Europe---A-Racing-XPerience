extends SceneTree
## Repro in the pristine v0.7.0 tree: the Arcade AudioManager as on a display (its own functions build the sounds),
## then stage changes as the game does them – set_vehicle(), a few frames of set_engine(), stop_all() – each followed
## by a burst of bus work and allocations (what loading the next scene does). The engine's generator stream is
## freed with its player in the frame of stop_all() while the audio thread may still fade its playback out.
## Flags: --iters=N --burst=N

func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _run() -> void:
	for i in 3:
		await process_frame
	var iters := 1500
	var burst := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--iters="):
			iters = int(a.substr(8))
		if a.begins_with("--burst="):
			burst = int(a.substr(8))
	var am: Node = root.get_node("AudioManager")
	var cfg := ConfigLoader.load_merged()
	if not bool(am.get("sounds_ready")):
		am.call("_load_traffic_sounds", cfg)
		am.call("_build_sounds")
	var cars := ["limousine", "kompakt", "gran_turismo", "kombi", "sportwagen"]
	var junk: Array = []
	for i in iters:
		if i % 100 == 0:
			print("iter ", i)
		am.call("set_vehicle", cars[i % 5])
		for k in 3:
			am.call("set_engine", 120.0, 1.0, 245.0, true)
			await process_frame
		am.call("stop_all")
		await process_frame
		await process_frame
		junk.clear()
		for k in burst:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.add_bus_effect(idx, AudioEffectReverb.new())
			AudioServer.add_bus_effect(idx, AudioEffectDelay.new())
			junk.append(AudioStreamPlayer.new())
			junk.append(PackedInt32Array([-1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16]))
		for k in burst:
			AudioServer.remove_bus(AudioServer.bus_count - 1)
		for o: Variant in junk:
			if o is Node:
				(o as Node).free()
	print("REPRO OK ", iters)
	quit(0)
