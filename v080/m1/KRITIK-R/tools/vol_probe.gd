extends SceneTree
## KRITIK-R: does an AudioEffectRecord appended to Master record before or after Master's bus volume?
## Plays a 1-kHz sine at 0 dBFS*0.25 through Master, records 1.5 s at Master volume 0 dB and 1.5 s at -20 dB.
##   godot --headless --path <tree> --audio-driver Dummy -s <this>

var _done := false


func _initialize() -> void:
	_run.call_deferred()


func _sine() -> AudioStreamWAV:
	var sr := 44100
	var n := sr * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := int(round(0.25 * 32767.0 * sin(TAU * 1000.0 * float(i) / float(sr))))
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _rms(w: AudioStreamWAV) -> float:
	var d := w.data
	var n := d.size() / 2
	var s := 0.0
	var c := 0
	for i in range(n / 4, n):     # skip the start
		var v := float(d.decode_s16(i * 2)) / 32768.0
		s += v * v
		c += 1
	return sqrt(s / maxf(float(c), 1.0))


func _run() -> void:
	for i in 3:
		await process_frame
	var master := AudioServer.get_bus_index("Master")
	var nfx := AudioServer.get_bus_effect_count(master)
	print("vol_probe: Master effects before = %d, volume_db = %.2f" % [nfx, AudioServer.get_bus_volume_db(master)])
	var rec := AudioEffectRecord.new()
	rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(master, rec)
	var p := AudioStreamPlayer.new()
	p.stream = _sine()
	p.bus = "Master"
	root.add_child(p)
	p.play()
	for vol in [0.0, -20.0]:
		AudioServer.set_bus_volume_db(master, vol)
		await create_timer(0.3).timeout
		rec.set_recording_active(true)
		await create_timer(1.5).timeout
		rec.set_recording_active(false)
		var w := rec.get_recording()
		var r := _rms(w)
		print("vol_probe: Master volume %.1f dB -> recorded RMS %.2f dBFS (sine 0.25 = %.2f dBFS RMS)" % [vol, linear_to_db(r), linear_to_db(0.25 / sqrt(2.0))])
	quit(0)
