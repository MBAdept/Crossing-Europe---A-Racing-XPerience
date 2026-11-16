extends SceneTree
## Probe: does the object count keep growing with profile switches? Four batches of 20 × arcade <-> modern.
## Usage: godot --headless --path . -s <this> [-- --live]

var _am: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _counts() -> String:
	return "Objekte %d, Knoten %d, verwaist %d, Ressourcen %d, Busse %d, gehaltene Streams %d" % [
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		AudioServer.bus_count, ModernAudioContext.kept_count()]


func _run() -> void:
	await _frames(5)
	_am = root.get_node("AudioManager")
	var live := OS.get_cmdline_user_args().has("--live")
	if live:
		ModernAudio.force_live = true
		var cfg: Dictionary = _am.get("_audio_cfg")
		if not bool(_am.get("sounds_ready")):
			_am.call("_load_traffic_sounds", cfg)
			_am.call("_build_sounds")
	_am.call("set_vehicle", "limousine")
	await _frames(5)
	print("Start:      ", _counts())
	for batch in 4:
		for i in 20:
			_am.call("set_profile", "modern")
			_am.call("set_vehicle", "limousine")
			for k in 3:
				_am.call("set_engine", 120.0, 0.8, 245.0, true)
				await process_frame
			_am.call("set_profile", "arcade")
			for k in 2:
				_am.call("set_engine", 120.0, 0.8, 245.0, true)
				await process_frame
		_am.call("stop_all")
		# let the kept generator streams go (2 s) before counting
		var until := Time.get_ticks_msec() + 2600
		while Time.get_ticks_msec() < until:
			await process_frame
		ModernAudioContext.release_kept()
		await _frames(3)
		print("nach %3d:   " % ((batch + 1) * 20), _counts())
	quit(0)
