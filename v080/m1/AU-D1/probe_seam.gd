extends SceneTree
## Probe: the Ogg loop of the main race file played by Godot (offline mix, 512-frame steps): output after the loop
## point vs. the first, continuously decoded pass over the same frames.

const MAIN := "res://assets/audio/modern/music/linke_spur.ogg"


func _mix(pb: AudioStreamPlayback, frames: int) -> PackedVector2Array:
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
	var s: AudioStreamOggVorbis = load(MAIN)
	var off := int(s.loop_offset * 44100.0)
	var length := int(round(s.get_length() * 44100.0))
	print("loop %s offset %.9f s = frame %d, length %d frames" % [s.loop, s.loop_offset, off, length])
	var pb := s.instantiate_playback()
	pb.start(0.0)
	var t0 := Time.get_ticks_msec()
	var out := _mix(pb, length + 44100 * 3)
	print("mixed %d frames in %d ms" % [out.size(), Time.get_ticks_msec() - t0])
	# the resampler delays everything by 2 frames: output frame k = file frame k - 2 (and after the loop
	# point the continuation of frame off)
	var worst := 0.0
	var worst_at := -1
	for k in range(2, 44100 * 2):
		var i := length + k
		var j := (off + k) if k >= 0 else (length + k)
		var d := (out[i] - out[j]).length() if k >= 0 else 0.0
		if d > worst:
			worst = d
			worst_at = k
	print("after the loop point: max |looped - first pass| = %.9f at +%d frames" % [worst, worst_at])
	var steps := PackedFloat32Array()
	for k in range(-200, 200):
		steps.append((out[length + k + 1] - out[length + k]).length())
	var mx := 0.0
	var mx_at := 0
	for k in steps.size():
		if steps[k] > mx:
			mx = steps[k]
			mx_at = k - 200
	print("largest sample step within 200 frames of the loop point: %.4f at %+d" % [mx, mx_at])
	quit()
