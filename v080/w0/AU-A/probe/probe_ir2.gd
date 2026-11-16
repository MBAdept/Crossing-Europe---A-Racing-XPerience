extends SceneTree
## Probe: impulse responses of effect chains given as JSON (--cases=<file>, --out=<dir>): [{"name":…, "fx":[{"cls":…, <property>: <value>}]}]

var _cap: AudioEffectCapture
var _p: AudioStreamPlayer


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _impulse() -> AudioStreamWAV:
	var rate := int(AudioServer.get_mix_rate())
	var b := PackedByteArray()
	b.resize(rate * 2)
	b.encode_s16(2000 * 2, 16384)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	return w


func _wait(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return fallback


func _run() -> void:
	Engine.max_fps = 120
	var out := _arg("out", "")
	DirAccess.make_dir_recursive_absolute(out)
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(_arg("cases", "")))
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "X")
	_p = AudioStreamPlayer.new()
	_p.bus = "X"
	root.add_child(_p)
	_p.stream = _impulse()
	for c: Dictionary in cases:
		while AudioServer.get_bus_effect_count(1) > 0:
			AudioServer.remove_bus_effect(1, 0)
		for spec: Dictionary in c["fx"]:
			var e: AudioEffect = ClassDB.instantiate(str(spec["cls"]))
			for k: String in spec:
				if k != "cls":
					e.set(k, spec[k])
			AudioServer.add_bus_effect(1, e)
		_cap = AudioEffectCapture.new()
		_cap.buffer_length = 2.0
		AudioServer.add_bus_effect(1, _cap)
		await _wait(200)
		_cap.clear_buffer()
		_p.play()
		await _wait(1300)
		var fr := _cap.get_buffer(_cap.get_frames_available())
		var b := PackedFloat32Array()
		b.resize(fr.size())
		for i in fr.size():
			b[i] = fr[i].x
		var f := FileAccess.open(out.path_join(str(c["name"]) + ".f32"), FileAccess.WRITE)
		f.store_buffer(b.to_byte_array())
		f.close()
		print(c["name"], " frames ", fr.size())
		_p.stop()
	quit(0)
