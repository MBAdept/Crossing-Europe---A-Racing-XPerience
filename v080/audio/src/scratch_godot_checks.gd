extends SceneTree
## v0.8.0 audio study (scratch): engine features the audio plan relies on.

var _t := 0.0
var _cap: AudioEffectCapture
var _tone: AudioStreamPlayer
var _burst: AudioStreamPlayer
var _levels: Array = []
var _setup := false


func _initialize() -> void:
	Engine.max_fps = 60
	for c in ["AudioStreamInteractive", "AudioStreamSynchronized", "AudioStreamPlaylist", "AudioStreamPolyphonic", "AudioStreamRandomizer",
			"AudioEffectCompressor", "AudioEffectHardLimiter", "AudioEffectEQ6", "AudioEffectEQ10", "AudioEffectStereoEnhance",
			"AudioEffectLowShelfFilter", "AudioEffectHighShelfFilter", "AudioEffectBandPassFilter", "AudioEffectChorus", "AudioEffectDistortion",
			"AudioEffectCapture", "AudioEffectSpectrumAnalyzer", "AudioEffectPitchShift", "AudioEffectPanner", "AudioEffectReverb", "AudioEffectDelay"]:
		print("class %-28s %s" % [c, "ja" if ClassDB.class_exists(c) else "NEIN"])
	var comp := AudioEffectCompressor.new()
	var props := []
	for p in comp.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_EDITOR:
			props.append(str(p["name"]))
	print("AudioEffectCompressor: ", props)
	var inter := AudioStreamInteractive.new()
	var ip := []
	for m in ClassDB.class_get_method_list("AudioStreamInteractive", true):
		ip.append(str(m["name"]))
	print("AudioStreamInteractive methods: ", ip)
	var en := ClassDB.class_get_enum_list("AudioStreamInteractive", true)
	for e in en:
		print("  enum ", e, " ", ClassDB.class_get_enum_constants("AudioStreamInteractive", e, true))
	print("mix rate %d Hz (project setting audio/driver/mix_rate = %s), output latency setting %s ms" % [int(AudioServer.get_mix_rate()),
		str(ProjectSettings.get_setting("audio/driver/mix_rate")), str(ProjectSettings.get_setting("audio/driver/output_latency"))])
	# int16 -> float conversion cost (bank loading): 3.2 million samples
	var n := 3243640 / 2
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(0, n * 2, 2):
		bytes.encode_s16(i, (i * 7919) % 65536 - 32768)
	var t0 := Time.get_ticks_msec()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = bytes.decode_s16(i * 2) * (1.0 / 32768.0)
	print("int16 -> float32, %d Samples in GDScript: %d ms" % [n, Time.get_ticks_msec() - t0])
	t0 = Time.get_ticks_msec()
	var f32 := bytes.to_float32_array()
	print("to_float32_array (heutiger Weg, %d Werte): %d ms" % [f32.size(), Time.get_ticks_msec() - t0])
	# buses for the sidechain test
	for bn in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bn) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bn)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var mi := AudioServer.get_bus_index("Music")
	comp.threshold = -30.0
	comp.ratio = 4.0
	comp.attack_us = 20000.0
	comp.release_ms = 250.0
	comp.sidechain = &"SFX"
	AudioServer.add_bus_effect(mi, comp)
	_cap = AudioEffectCapture.new()
	AudioServer.add_bus_effect(mi, _cap)
	_tone = AudioStreamPlayer.new()
	_tone.stream = _sine(440.0, 3.0, 0.25)
	_tone.bus = "Music"
	root.add_child(_tone)
	_burst = AudioStreamPlayer.new()
	_burst.stream = _sine(150.0, 0.8, 0.8)
	_burst.bus = "SFX"
	root.add_child(_burst)


func _sine(f: float, seconds: float, amp: float) -> AudioStreamWAV:
	var rate := 48000
	var n := int(seconds * rate)
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		b.encode_s16(i * 2, int(sin(TAU * f * i / rate) * amp * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	return w


func _process(delta: float) -> bool:
	if not _setup:
		_setup = true
		_tone.play()
		return false
	_t += delta
	if _t > 1.0 and _t < 1.0 + delta * 1.5:
		_burst.play()
	var fr := _cap.get_buffer(_cap.get_frames_available())
	if fr.size() > 0:
		var s := 0.0
		for v in fr:
			s += v.x * v.x
		_levels.append([_t, 10.0 * log(maxf(s / fr.size(), 1.0e-12)) / log(10.0)])
	if _t >= 2.8:
		var a := []
		var b := []
		var c := []
		for e in _levels:
			if e[0] > 0.4 and e[0] < 0.95:
				a.append(e[1])
			elif e[0] > 1.3 and e[0] < 1.75:
				b.append(e[1])
			elif e[0] > 2.4 and e[0] < 2.75:
				c.append(e[1])
		print("Seitenkette: Ton auf Music vor dem SFX-Stoß %.1f dB, während %.1f dB, danach %.1f dB" % [_avg(a), _avg(b), _avg(c)])
		return true
	return false


func _avg(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += x
	return s / maxf(v.size(), 1.0)
