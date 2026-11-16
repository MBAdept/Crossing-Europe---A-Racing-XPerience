extends SceneTree
## Probe: which cheap meter of the car bus follows the loudness (LUFS) of the engine? Compares, per phase of a
## drive: broadband RMS (capture), bus peak, and band levels of an AudioEffectSpectrumAnalyzer.

var _am: Node
var _t0 := 0
var _acc := {}
var _n := 0
var _inst: AudioEffectSpectrumAnalyzerInstance
const BANDS := [[20.0, 150.0], [150.0, 600.0], [600.0, 2500.0], [2500.0, 8000.0], [150.0, 8000.0], [300.0, 6000.0]]


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _sample() -> void:
	var mo: ModernAudio = _am.get("_modern")
	_n += 1
	_acc["rms"] = float(_acc.get("rms", 0.0)) + pow(10.0, mo.mix.key_db / 10.0)
	_acc["peak"] = maxf(float(_acc.get("peak", -200.0)), mo.buses.peak_db("MCar"))
	for b: Array in BANDS:
		var v := _inst.get_magnitude_for_frequency_range(float(b[0]), float(b[1]), AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
		var k := "avg_%d_%d" % [int(b[0]), int(b[1])]
		_acc[k] = float(_acc.get(k, 0.0)) + 0.5 * (v.x * v.x + v.y * v.y)
		var w := _inst.get_magnitude_for_frequency_range(float(b[0]), float(b[1]), AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
		var k2 := "max_%d_%d" % [int(b[0]), int(b[1])]
		_acc[k2] = float(_acc.get(k2, 0.0)) + 0.5 * (w.x * w.x + w.y * w.y)


func _report(phase: String) -> void:
	var parts: Array[String] = []
	for k: String in _acc:
		if k == "peak":
			parts.append("peak %.1f" % float(_acc[k]))
		else:
			parts.append("%s %.1f" % [k, 10.0 * log(maxf(float(_acc[k]) / maxf(_n, 1), 1.0e-20)) / log(10.0)])
	print("%-14s %s" % [phase, "  ".join(parts)])
	_acc.clear()
	_n = 0


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("_load_traffic_sounds", cfg)
	_am.call("_build_sounds")
	_am.call("set_profile", "modern")
	var an := AudioEffectSpectrumAnalyzer.new()
	an.buffer_length = 0.1
	an.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	var idx := AudioServer.get_bus_index("MCar")
	AudioServer.add_bus_effect(idx, an)
	_inst = AudioServer.get_bus_effect_instance(idx, AudioServer.get_bus_effect_count(idx) - 1)
	var vehicle := CliArgs.get_string("vehicle", "gran_turismo")
	var spec := VehicleModel.resolve_spec(ConfigLoader.load_merged(), vehicle)
	var vmax := float(spec.get("vmax_kmh", 245.0))
	_am.call("set_vehicle", vehicle)
	_t0 = Time.get_ticks_usec()
	var plan := [["idle", 0.0, 0.0, 4.0, 2.0], ["full_100", 100.0, 1.0, 4.0, 1.0], ["full_200", 200.0, 1.0, 4.0, 1.0],
		["flat_out", vmax * 0.99, 1.0, 4.0, 1.0], ["cruise_130", 130.0, 0.22, 5.0, 2.0], ["cruise_80", 80.0, 0.15, 5.0, 2.0]]
	for p: Array in plan:
		var t0 := _now()
		while _now() - t0 < float(p[3]):
			_am.call("set_engine", float(p[1]), float(p[2]), vmax, true)
			_am.call("set_wind", float(p[1]))
			if _now() - t0 > float(p[4]):
				_sample()
			await process_frame
		_report(str(p[0]))
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	for i in 30:
		await process_frame
	quit(0)
