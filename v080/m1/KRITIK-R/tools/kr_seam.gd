extends SceneTree
## KRITIK-R: in-game loop seams of imported loops. Each file plays from 0 at pitch 1 and 0 dB on its own bus
## (AudioEffectCapture at the end of that bus) for --seconds; the captures are written raw (float32 stereo) as
## <out-dir>/<id>.f32 for the comparison with the decoded file (tiled) in Python.
##   godot --headless --path <tree> --audio-driver Dummy -s <this> -- --graphics=arcade --out-dir=/abs \
##       --files=res://a.ogg,res://b.ogg [--seconds=16]

var _caps: Array[AudioEffectCapture] = []
var _bufs: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	_pull()
	return false


func _pull() -> void:
	for i in _caps.size():
		var n := _caps[i].get_frames_available()
		if n > 0:
			var b: PackedVector2Array = _bufs[i]
			b.append_array(_caps[i].get_buffer(n))
			_bufs[i] = b


func _run() -> void:
	for i in 3:
		await process_frame
	var out_dir := CliArgs.get_string("out-dir", "")
	var files := CliArgs.get_string("files", "").split(",", false)
	var seconds := CliArgs.get_float("seconds", 16.0)
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioServer.set_bus_volume_db(0, -60.0)
	var players: Array[AudioStreamPlayer] = []
	for f: String in files:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, "KSeam%d" % bi)
		AudioServer.set_bus_send(bi, "Master")
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 4.0
		AudioServer.add_bus_effect(bi, cap)
		_caps.append(cap)
		_bufs.append(PackedVector2Array())
		var p := AudioStreamPlayer.new()
		p.stream = load(f)
		p.bus = "KSeam%d" % bi
		root.add_child(p)
		players.append(p)
	await process_frame
	_pull()
	for i in _bufs.size():
		_bufs[i] = PackedVector2Array()
	for p in players:
		p.play(0.0)
	var t0 := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t0) / 1.0e6 < seconds:
		await process_frame
	_pull()
	for p in players:
		p.stop()
	for i in files.size():
		var arr: PackedVector2Array = _bufs[i]
		var flat := PackedFloat32Array()
		flat.resize(arr.size() * 2)
		for j in arr.size():
			flat[2 * j] = arr[j].x
			flat[2 * j + 1] = arr[j].y
		var fa := FileAccess.open(out_dir.path_join(files[i].get_file().get_basename() + ".f32"), FileAccess.WRITE)
		fa.store_buffer(flat.to_byte_array())
		fa.close()
		print("kr_seam: %s %d frames" % [files[i], arr.size()])
	for p in players:
		p.stream = null
		p.queue_free()
	for i in 10:
		await process_frame
	quit(0)
