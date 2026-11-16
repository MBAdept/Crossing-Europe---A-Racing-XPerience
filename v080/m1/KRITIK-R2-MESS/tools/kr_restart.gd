extends SceneTree
## KRITIK-R2-MESS: what Godot 4.7.2 does at the moments the slab and drift code relies on – a looping
## AudioStreamWAV (a 441-Hz sine, 100 samples per period, 1-s loop, built in code) on its own bus with an
## AudioEffectCapture at the bus end:
##   start    play(0.37) on a stopped player at full volume (a start in the middle of a period)
##   restart  play(pos + 27 samples) on the PLAYING player (= the slab realignment: restart(0, share))
##   restart2 play(pos + 3.1 ms) on the playing player
##   steps    volume_db alternating 0 / -3 dB every frame for 60 frames (a hard case of the per-side drift)
##   drift    volume_db as the road slot's drift (Ornstein-Uhlenbeck, 1.5 dB spread, 0.8 s, every frame) for 3 s
##   stop     stop() on the playing player
## The same once more with an AudioStreamPlayer2D (the panned players of the road layers). Writes <out>_plain.f32,
## <out>_2d.f32 (raw float32 stereo at the bus end) and <out>.json (capture frame index at each action).
##   godot --headless --path <tree> --audio-driver Dummy -s <this> -- --graphics=arcade --out=/abs/restart

var _cap: AudioEffectCapture
var _buf := PackedVector2Array()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_pull()
	return false


func _pull() -> void:
	if _cap != null:
		var n := _cap.get_frames_available()
		if n > 0:
			_buf.append_array(_cap.get_buffer(n))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _sine() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(44100 * 2)
	for i in 44100:
		data.encode_s16(2 * i, int(round(sin(TAU * float(i) / 100.0) * 16000.0)))
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = 44100
	return wav


func _one(p: Node, marks: Dictionary) -> void:
	_pull()
	_buf = PackedVector2Array()
	await _frames(20)
	_pull()
	marks["start"] = _buf.size()
	p.call("play", 0.37)
	await _frames(60)
	_pull()
	var pos := float(p.call("get_playback_position"))
	marks["restart"] = _buf.size()
	marks["restart_pos"] = pos
	p.call("play", pos + 27.0 / 44100.0)
	await _frames(60)
	_pull()
	pos = float(p.call("get_playback_position"))
	marks["restart2"] = _buf.size()
	p.call("play", pos + 0.0031)
	await _frames(60)
	_pull()
	marks["steps"] = _buf.size()
	for i in 60:
		p.set("volume_db", -3.0 if i % 2 == 0 else 0.0)
		await process_frame
	p.set("volume_db", 0.0)
	await _frames(30)
	_pull()
	marks["drift"] = _buf.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var d := 0.0
	var last := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		var a := minf((now - last) / 1.0e6, 0.1) / 0.8
		last = now
		d += -d * a + sqrt(2.0 * a) * rng.randfn(0.0, 1.0)
		var db := 1.5 * d
		if absf(float(p.get("volume_db")) - db) > 0.02:
			p.set("volume_db", db)
	marks["drift_end"] = _buf.size()
	p.set("volume_db", 0.0)
	await _frames(30)
	_pull()
	marks["stop"] = _buf.size()
	p.call("stop")
	await _frames(30)
	_pull()
	marks["end"] = _buf.size()


func _write(path: String) -> void:
	var flat := PackedFloat32Array()
	flat.resize(_buf.size() * 2)
	for i in _buf.size():
		flat[2 * i] = _buf[i].x
		flat[2 * i + 1] = _buf[i].y
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(flat.to_byte_array())
	f.close()


func _run() -> void:
	await _frames(3)
	Engine.max_fps = 60
	var out := CliArgs.get_string("out", "")
	AudioServer.add_bus()
	var bi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bi, "KRestart")
	AudioServer.set_bus_send(bi, "Master")
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 10.0
	AudioServer.add_bus_effect(bi, _cap)
	var wav := _sine()
	var meta := {}
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.bus = "KRestart"
	root.add_child(p)
	var m1 := {}
	await _one(p, m1)
	_write(out + "_plain.f32")
	meta["plain"] = m1
	p.queue_free()
	var p2 := AudioStreamPlayer2D.new()
	p2.stream = wav
	p2.bus = "KRestart"
	p2.max_distance = 100000.0
	p2.attenuation = 0.0
	p2.panning_strength = 0.0
	root.add_child(p2)
	var m2 := {}
	_buf = PackedVector2Array()
	await _one(p2, m2)
	_write(out + "_2d.f32")
	meta["2d"] = m2
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t") + "\n")
	f.close()
	print("kr_restart: %s %s" % [out, JSON.stringify(meta)])
	p2.queue_free()
	await _frames(10)
	quit(0)
