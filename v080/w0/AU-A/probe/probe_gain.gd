extends SceneTree
## Probe: is a bus volume change ramped by the mixer, and an AudioEffectAmplify change? (100 Hz sine, -6 dB step)
## Also: peak meter of a bus, static curve of AudioEffectCompressor without a sidechain.

var _cap: AudioEffectCapture
var _p: AudioStreamPlayer
var _t := 0.0
var _acc := PackedVector2Array()
var _phase := 0
var _amp: AudioEffectAmplify
var _comp: AudioEffectCompressor
var _marks: Array = []
var _levels := [-30.0, -24.0, -18.0, -12.0, -6.0, -3.0, 0.0]
var _li := 0
var _peaks: Array = []


func _sine(f: float, seconds: float, amp: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(seconds * rate)
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		b.encode_s16(i * 2, int(sin(TAU * f * i / rate) * amp * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _initialize() -> void:
	Engine.max_fps = 60
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "X")
	AudioServer.set_bus_send(1, "Master")
	_amp = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(1, _amp)
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 2.0
	AudioServer.add_bus_effect(0, _cap)
	_p = AudioStreamPlayer.new()
	_p.stream = _sine(100.0, 1.0, 0.25)
	_p.bus = "X"
	root.add_child(_p)
	print("mix rate ", AudioServer.get_mix_rate(), " latency ", AudioServer.get_output_latency())


func _grab() -> void:
	var fr := _cap.get_buffer(_cap.get_frames_available())
	_acc.append_array(fr)


func _max_step(a: int, b: int) -> float:
	var m := 0.0
	for i in range(maxi(a, 1), mini(b, _acc.size())):
		m = maxf(m, absf(_acc[i].x - _acc[i - 1].x))
	return m


func _rms_db(a: int, b: int) -> float:
	var s := 0.0
	var n := 0
	for i in range(maxi(a, 0), mini(b, _acc.size())):
		s += _acc[i].x * _acc[i].x
		n += 1
	return 10.0 * log(maxf(s / maxf(n, 1), 1.0e-12)) / log(10.0)


func _process(delta: float) -> bool:
	if _phase == 0:
		_p.play()
		_phase = 1
		return false
	_t += delta
	_grab()
	if _phase == 1 and _t > 0.6:
		_marks.append(_acc.size())
		AudioServer.set_bus_volume_db(1, -6.0)
		_phase = 2
	elif _phase == 2 and _t > 1.2:
		_marks.append(_acc.size())
		AudioServer.set_bus_volume_db(1, 0.0)
		_phase = 3
	elif _phase == 3 and _t > 1.8:
		_marks.append(_acc.size())
		_amp.volume_db = -6.0
		_phase = 4
	elif _phase == 4 and _t > 2.4:
		_marks.append(_acc.size())
		_amp.volume_db = 0.0
		_phase = 5
	elif _phase == 5 and _t > 3.0:
		var normal := _max_step(4410, int(_marks[0]) - 2000)
		print("normal max step of the sine: %.5f" % normal)
		var names := ["bus volume 0 -> -6 dB", "bus volume -6 -> 0 dB", "amplify 0 -> -6 dB", "amplify -6 -> 0 dB"]
		for k in 4:
			var m := int(_marks[k])
			print("%-24s max step in the 0.25 s after the change: %.5f (x%.2f of normal)" % [names[k], _max_step(m - 600, m + 11025), _max_step(m - 600, m + 11025) / normal])
			var bi := m - 600
			var bm := 0.0
			for i in range(m - 600, m + 11025):
				var st := absf(_acc[i].x - _acc[i - 1].x)
				if st > bm:
					bm = st
					bi = i
			var around := []
			for i in range(bi - 3, bi + 4):
				around.append("%.4f" % _acc[i].x)
			print("    at index %d (mark %+d): %s" % [bi, bi - m, " ".join(around)])
		print("levels: before %.2f dB, bus -6: %.2f dB, amplify -6: %.2f dB" % [_rms_db(8820, int(_marks[0]) - 2000), _rms_db(int(_marks[0]) + 8820, int(_marks[1]) - 2000), _rms_db(int(_marks[2]) + 8820, int(_marks[3]) - 2000)])
		# compressor static curve: sine at several levels through threshold -12 dB, ratio 2
		_comp = AudioEffectCompressor.new()
		_comp.threshold = -12.0
		_comp.ratio = 2.0
		_comp.attack_us = 30000.0
		_comp.release_ms = 300.0
		_comp.gain = 0.0
		_comp.mix = 1.0
		AudioServer.add_bus_effect(1, _comp)
		_p.stream = _sine(1000.0, 1.0, 1.0)
		_p.play()
		_p.volume_db = float(_levels[0])
		_acc.clear()
		_t = 0.0
		_phase = 6
	elif _phase == 6:
		_peaks.append(AudioServer.get_bus_peak_volume_left_db(1, 0))
		if _t > 1.0:
			var n := _acc.size()
			print("compressor thr -12 ratio 2: input sine peak %.1f dBFS (rms %.1f) -> output rms %.2f dB (peak meter of the bus %.2f dB)" % [float(_levels[_li]), float(_levels[_li]) - 3.01, _rms_db(n - 13230, n), float(_peaks[_peaks.size() - 1])])
			_li += 1
			if _li >= _levels.size():
				return true
			_p.volume_db = float(_levels[_li])
			_acc.clear()
			_peaks.clear()
			_t = 0.0
	return false
