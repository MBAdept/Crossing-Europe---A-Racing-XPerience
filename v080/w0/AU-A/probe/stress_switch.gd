extends SceneTree
## Stress: arcade <-> modern switches with playback, to reproduce the audio-thread hang.
## Flags after --: --iters=N --no-music --no-engine --no-traffic --no-preview --no-plays --no-loops --frames=3 --arcade-only

var _am: Node
var _i := 0
var _beat := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(3)
	_am = root.get_node("AudioManager")
	ModernAudio.force_live = true
	var cfg: Dictionary = _am.get("_audio_cfg")
	(cfg["audio"]["modern"] as Dictionary)["placeholders"] = not CliArgs.has("no-placeholders")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
		await _frames(2)
	var iters := int(CliArgs.get_float("iters", 300.0))
	var nframes := int(CliArgs.get_float("frames", 3.0))
	var music := not CliArgs.has("no-music")
	var engine := not CliArgs.has("no-engine")
	var traffic := not CliArgs.has("no-traffic")
	var preview := not CliArgs.has("no-preview")
	var plays := not CliArgs.has("no-plays")
	var loops := not CliArgs.has("no-loops")
	var arcade_only := CliArgs.has("arcade-only")
	for i in iters:
		_i = i
		if i % 10 == 0:
			print("iter ", i)
		if not arcade_only:
			_am.call("set_profile", "modern")
		if engine:
			_am.call("set_vehicle", ["limousine", "kompakt", "gran_turismo", "kombi", "sportwagen"][i % 5])
		if music:
			_am.call("set_music", i % 2 == 0)
			_am.call("set_music_context", "race" if i % 3 == 0 else "menu")
		for k in nframes:
			if engine:
				_am.call("set_engine", 90.0 + 5.0 * (i % 20), 1.0, 240.0, true)
			if loops:
				_am.call("set_wind", 150.0)
				_am.call("set_rain", 1.0)
				_am.call("set_siren", true, 0.6)
			if traffic:
				_am.call("set_traffic", [{"id": 1, "set": "traffic/sedan_blue", "z": 12.0, "x": 3.75, "length": 4.7, "speed": 100.0},
					{"id": -2, "set": "police/de", "z": -30.0, "x": 0.0, "length": 4.8, "speed": 160.0}], {"z": 0.0, "x": 0.0, "speed": 120.0})
			_am.call("set_environment", {"tunnel": k % 2 == 0})
			if k == 1:
				if plays:
					_am.call("play", "crash")
					_am.call("play", "ui_move")
				if preview:
					_am.call("preview_engine", "sportwagen")
			await process_frame
		if arcade_only:
			_am.call("stop_all")
		else:
			_am.call("set_profile", "arcade")
		await _frames(2)
	_am.call("set_music", false)
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	await _frames(20)
	print("STRESS OK ", iters)
	quit(0)
