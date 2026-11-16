extends SceneTree
## Probe: AudioStreamInteractive auto-advance join (clip 0 -> clip 1 at its end), mixed offline in 512-frame steps
## like the AudioServer. Compares the output with clip 0 followed by clip 1, both mixed alone the same way.

const DIR := "res://assets/audio/modern/music/"


func _mix_alone(s: AudioStream, frames: int) -> PackedVector2Array:
	var pb := s.instantiate_playback()
	pb.start(0.0)
	var out := PackedVector2Array()
	while out.size() < frames:
		var blk := pb.mix_audio(1.0, 512)
		out.append_array(blk)
		if blk.size() < 512:
			var pad := PackedVector2Array()
			pad.resize(512 - blk.size())
			out.append_array(pad)
	return out


func _initialize() -> void:
	var a: AudioStreamOggVorbis = load(DIR + "linke_spur_anlauf.ogg")
	var b: AudioStreamOggVorbis = load(DIR + "linke_spur_schleife.ogg")
	print("anlauf: bpm %s beats %d loop %s len %.6f s | schleife: bpm %s beats %d loop %s len %.6f s" % [a.bpm, a.beat_count,
		a.loop, a.get_length(), b.bpm, b.beat_count, b.loop, b.get_length()])
	for order in [[0, 1], [1, 0]]:
		var s := AudioStreamInteractive.new()
		s.clip_count = 2
		var ia: int = order[0]
		var ib: int = order[1]
		s.set_clip_name(ia, &"anlauf")
		s.set_clip_stream(ia, a)
		s.set_clip_auto_advance(ia, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
		s.set_clip_auto_advance_next_clip(ia, ib)
		s.set_clip_name(ib, &"schleife")
		s.set_clip_stream(ib, b)
		s.initial_clip = ia
		s.add_transition(ia, ib, AudioStreamInteractive.TRANSITION_FROM_TIME_END, AudioStreamInteractive.TRANSITION_TO_TIME_START,
			AudioStreamInteractive.FADE_DISABLED, 1.0)
		var pb := s.instantiate_playback()
		pb.start(0.0)
		var t0 := Time.get_ticks_msec()
		var probe := pb.mix_audio(1.0, 512)
		print("first block: %d frames in %d ms" % [probe.size(), Time.get_ticks_msec() - t0])
		var n_a := int(round(a.get_length() * 44100.0))
		var out := PackedVector2Array()
		out.append_array(probe)
		while out.size() < n_a + 4096:
			out.append_array(pb.mix_audio(1.0, 512))
		print("mixed %d frames in %d ms" % [out.size(), Time.get_ticks_msec() - t0])
		var ref_a := _mix_alone(a, n_a + 4096)
		var ref_b := _mix_alone(b, 8192)
		# where does clip b begin in the output? best offset of ref_b against out - ref_a around n_a
		var best := 0
		var best_err := INF
		for off in range(-1200, 200):
			var err := 0.0
			for k in range(0, 2048, 4):
				var i := n_a + off + k
				var r := out[i] - ref_a[i] if i < ref_a.size() else out[i]
				err += (r - ref_b[k]).length_squared()
			if err < best_err:
				best_err = err
				best = off
		var max_join := 0.0
		for i in range(n_a - 2000, n_a + 2000):
			var want := ref_a[i] if i < ref_a.size() else Vector2.ZERO
			var j := i - n_a
			if j >= 0:
				want += ref_b[j]
			max_join = maxf(max_join, (out[i] - want).length())
		print("clip order %s: clip 2 starts %d frames %s the end of clip 1 (best match err %.6f); max deviation from the gapless join %.4f" % [
			str(order), absi(best), "before" if best < 0 else "after", best_err, max_join])
	quit()
