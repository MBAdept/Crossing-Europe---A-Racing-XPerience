extends SceneTree
## Probe: frequency response of AudioEffectEQ10 – all bands 0 dB, and with -3 dB at 500 Hz / -1 dB at 62 Hz.

var _cap: AudioEffectCapture
var _p: AudioStreamPlayer
var _eq: AudioEffectEQ10


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _tone(hz: float) -> AudioStreamWAV:
	var rate := 44100
	var n := 44100
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		b.encode_s16(i * 2, int(sin(TAU * hz * i / rate) * 0.1 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _level() -> float:
	var until := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < until:
		await process_frame
	_cap.clear_buffer()
	until = Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < until:
		await process_frame
	var fr := _cap.get_buffer(_cap.get_frames_available())
	var s := 0.0
	for v in fr:
		s += v.x * v.x
	return 10.0 * log(maxf(s / maxf(fr.size(), 1.0), 1.0e-20)) / log(10.0)


func _run() -> void:
	Engine.max_fps = 120
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "X")
	_eq = AudioEffectEQ10.new()
	AudioServer.add_bus_effect(1, _eq)
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 1.0
	AudioServer.add_bus_effect(1, _cap)
	_p = AudioStreamPlayer.new()
	_p.bus = "X"
	root.add_child(_p)
	var freqs := [31.0, 62.0, 90.0, 125.0, 250.0, 350.0, 500.0, 700.0, 1000.0, 2000.0, 4000.0, 8000.0, 12000.0]
	var rows := {}
	for mode in 3:
		if mode == 0:
			AudioServer.set_bus_effect_enabled(1, 0, false)
		else:
			AudioServer.set_bus_effect_enabled(1, 0, true)
			for i in 10:
				_eq.set_band_gain_db(i, 0.0)
			if mode == 2:
				_eq.set_band_gain_db(1, -1.0)
				_eq.set_band_gain_db(4, -3.0)
		for f: float in freqs:
			_p.stream = _tone(f)
			_p.play()
			var l: float = await _level()
			if not rows.has(f):
				rows[f] = []
			(rows[f] as Array).append(l)
	print("Hz      aus      EQ flach (Abw.)   EQ 62:-1 500:-3 (Abw. gegen aus)")
	for f: float in freqs:
		var r: Array = rows[f]
		print("%6d  %6.2f   %6.2f (%+.2f)     %6.2f (%+.2f)" % [int(f), float(r[0]), float(r[1]), float(r[1]) - float(r[0]), float(r[2]), float(r[2]) - float(r[0])])
	quit(0)
