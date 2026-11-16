extends SceneTree
## v0.8.0 audio study (scratch): AudioStreamInteractive - switch to another clip at the next bar line, auto-advance
## from a short clip (count-in) into a looping body. Measures the switch times from the captured output.

var _cap: AudioEffectCapture
var _p: AudioStreamPlayer
var _t := 0.0
var _setup := false
var _log: Array = []
var _switched := false
var _acc := PackedVector2Array()
var _t_first := -1.0


func _initialize() -> void:
	Engine.max_fps = 120
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 1.0
	AudioServer.add_bus_effect(0, _cap)
	var a: AudioStreamOggVorbis = load("res://scratch_music/a.ogg")
	var b: AudioStreamOggVorbis = load("res://scratch_music/b.ogg")
	var c: AudioStreamOggVorbis = load("res://scratch_music/c.ogg")
	for s: AudioStreamOggVorbis in [a, b]:
		s.loop = true
		s.bpm = 120.0
		s.beat_count = 16
		s.bar_beats = 4
	c.loop = false
	c.bpm = 120.0
	c.beat_count = 4
	c.bar_beats = 4
	var inter := AudioStreamInteractive.new()
	inter.clip_count = 3
	inter.set_clip_name(0, &"countin")
	inter.set_clip_stream(0, c)
	inter.set_clip_auto_advance(0, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	inter.set_clip_auto_advance_next_clip(0, 1)
	inter.set_clip_name(1, &"body")
	inter.set_clip_stream(1, a)
	inter.set_clip_name(2, &"ending")
	inter.set_clip_stream(2, b)
	inter.initial_clip = 0
	inter.add_transition(0, 1, AudioStreamInteractive.TRANSITION_FROM_TIME_END, AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_DISABLED, 0.0)
	inter.add_transition(1, 2, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_CROSS, 0.25)
	_p = AudioStreamPlayer.new()
	_p.stream = inter
	root.add_child(_p)


func _process(delta: float) -> bool:
	if not _setup:
		_setup = true
		_p.play()
		return false
	_t += delta
	var fr := _cap.get_buffer(_cap.get_frames_available())
	_acc.append_array(fr)
	if not _switched and _acc.size() >= int(44100 * 3.3):       # 2 s count-in + 1.3 s of the body: ask for the ending
		_switched = true
		var pb := _p.get_stream_playback() as AudioStreamPlaybackInteractive
		pb.switch_to_clip_by_name(&"ending")
		print("switch requested at %.3f s of audio" % (_acc.size() / 44100.0))
	if _acc.size() >= int(44100 * 6.0):
		# dominant frequency per 20 ms window from zero crossings
		var w := 882
		var last := 0.0
		var i := 0
		while i + w < _acc.size():
			var z := 0
			var e := 0.0
			for k in range(i + 1, i + w):
				if (_acc[k - 1].x < 0.0) != (_acc[k].x < 0.0):
					z += 1
				e += _acc[k].x * _acc[k].x
			var f := z * 0.5 / 0.02
			if e / w > 1.0e-5 and absf(f - last) > 60.0:
				print("ab %.2f s: ~%d Hz" % [i / 44100.0, int(f)])
				last = f
			i += w
		return true
	return false
