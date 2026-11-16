extends SceneTree
## Scratch probe of AU-B: what does Godot play at the seam of a looping AudioStreamWAV whose loop ends at the end of
## its data? A loop of a constant value (0.5) is played with a pitch below 1 and captured on the Master bus: every
## deviation from the constant is the seam. Variant "guard": the same loop with 16 more frames of data behind the
## loop end.

func _initialize() -> void:
	_run.call_deferred()


func _wav(n: int, guard: int, value: float) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize((n + guard) * 2)
	for i in n + guard:
		b.encode_s16(i * 2, int(value * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	w.stereo = false
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _measure(stream: AudioStream, label: String, pitch: float) -> void:
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 4.0
	AudioServer.add_bus_effect(0, cap)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch
	root.add_child(p)
	p.play()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
	var fr := cap.get_buffer(cap.get_frames_available())
	p.stop()
	p.queue_free()
	AudioServer.remove_bus_effect(0, 0)
	# skip the fade-in of the first block, find the steady value and what deviates from it
	var from := 4096
	var vals := {}
	var lo := 10.0
	var hi := -10.0
	var odd := 0
	var first_odd := -1
	var steady := 0.0
	for i in range(from, fr.size() - 2048):
		steady += fr[i].x
	steady /= maxf(float(fr.size() - 2048 - from), 1.0)
	for i in range(from, fr.size() - 2048):
		var x := fr[i].x
		lo = minf(lo, x)
		hi = maxf(hi, x)
		if absf(x - steady) > 0.002:
			odd += 1
			if first_odd < 0:
				first_odd = i
	var sample := []
	if first_odd >= 0:
		for i in range(first_odd - 2, first_odd + 8):
			sample.append(snappedf(fr[i].x, 0.0001))
	print("%s: %d Frames, Mittel %.4f, kleinster %.4f, größter %.4f, abweichend %d%s" % [label, fr.size(), steady, lo, hi, odd,
		(" – erste Stelle " + str(sample)) if first_odd >= 0 else ""])
	await process_frame


## A sine loop (period 441 samples, n a whole number of periods), `guard` frames of continuation behind the loop
## end; loop_end = n + end_shift. Returns the largest second difference of the captured output relative to the one
## of a clean sine of that level (1 = clean).
func _sine(n: int, guard: int, end_shift: int, pitch: float, label: String) -> void:
	var b := PackedByteArray()
	b.resize((n + guard) * 2)
	for i in n + guard:
		b.encode_s16(i * 2, int(0.5 * sin(TAU * float(i) / 441.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n + end_shift
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 4.0
	AudioServer.add_bus_effect(0, cap)
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.pitch_scale = pitch
	root.add_child(p)
	p.play()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	var fr := cap.get_buffer(cap.get_frames_available())
	p.stop()
	p.queue_free()
	AudioServer.remove_bus_effect(0, 0)
	var worst := 0.0
	var count := 0
	var clean := 0.5 * pow(TAU / 441.0 * pitch, 2.0)
	for i in range(4098, fr.size() - 2048):
		var d2 := absf(fr[i + 1].x - 2.0 * fr[i].x + fr[i - 1].x)
		worst = maxf(worst, d2)
		if d2 > 4.0 * clean:
			count += 1
	print("%s: größte 2. Differenz %.5f = %.1f × die eines sauberen Sinus, %d auffällige Stellen" % [label, worst, worst / clean, count])
	await process_frame


func _run() -> void:
	for i in 3:
		await process_frame
	var n := 4410        # 0.1 s loop: about 19 seams in the measured 2 s at pitch 0.77
	await _measure(_wav(n, 0, 0.5), "Schleife bis zum Datenende", 0.77)
	await _measure(_wav(n, 0, 0.5), "Schleife bis zum Datenende, zweiter Lauf", 0.77)
	await _measure(_wav(n, 16, 0.5), "Schleife mit 16 Frames dahinter", 0.77)
	await _measure(_wav(n, 0, 0.5), "Schleife bis zum Datenende, Tonhöhe 1", 1.0)
	await _sine(4410, 0, 0, 1.0, "Sinus, Schleife bis zum Datenende, Tonhöhe 1")
	await _sine(4410, 16, 0, 1.0, "Sinus, 16 Frames Fortsetzung dahinter, loop_end = n, Tonhöhe 1")
	await _sine(4410, 16, -1, 1.0, "Sinus, 16 Frames Fortsetzung, loop_end = n − 1, Tonhöhe 1")
	await _sine(4410, 16, 0, 0.77, "Sinus, 16 Frames Fortsetzung, loop_end = n, Tonhöhe 0,77")
	await _sine(4410, 16, 0, 1.63, "Sinus, 16 Frames Fortsetzung, loop_end = n, Tonhöhe 1,63")
	await _sine(4410, 0, 0, 0.77, "Sinus, Schleife bis zum Datenende, Tonhöhe 0,77")
	var imp: AudioStream = load("res://assets/audio/modern/vehicle/platzhalter_loop.wav")
	print("Import-Beispiel: ", imp, " loop_end ", imp.get("loop_end"), " Datenbytes ", (imp.get("data") as PackedByteArray).size())
	quit(0)
