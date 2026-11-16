extends SceneTree
## AU-R: how two WAV loops at different pitches keep their relative position in Godot 4.7.2 (Dummy driver).
## Two plain AudioStreamPlayers (slab_slow at 130/90, slab_fast at 130/180), started under AudioServer.lock at the
## same share; every 0.2 s both positions under the lock. Then the fast one is restarted at the slow one's share.
##   godot --headless --path <tree> -s <this>

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer


func _initialize() -> void:
	_run.call_deferred()


func _share(p: AudioStreamPlayer, length: float) -> float:
	return fposmod(p.get_playback_position() / length, 1.0)


func _log(tag: String, la: float, lb: float, period: float) -> void:
	AudioServer.lock()
	var sa := _share(_a, la)
	var sb := _share(_b, lb)
	var pa := _a.get_playback_position()
	var pb := _b.get_playback_position()
	AudioServer.unlock()
	var d := fposmod(sb - sa + 0.5, 1.0) - 0.5
	print("%s t=%d ms sa=%.6f sb=%.6f diff=%.3f ms (pos %.5f / %.5f) mix_rate=%d" % [tag, Time.get_ticks_msec(), sa, sb, d * period * 1000.0, pa, pb, int(AudioServer.get_mix_rate())])


func _run() -> void:
	await process_frame
	var sa: AudioStream = load("res://assets/audio/modern/vehicle/slab_slow.wav")
	var sb: AudioStream = load("res://assets/audio/modern/vehicle/slab_fast.wav")
	var la := 282240.0 / 44100.0
	var lb := 141120.0 / 44100.0
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	root.add_child(_a)
	root.add_child(_b)
	_a.stream = sa
	_b.stream = sb
	_a.volume_db = -30.0
	_b.volume_db = -30.0
	_a.pitch_scale = 130.0 / 90.0
	_b.pitch_scale = 130.0 / 180.0
	print("max_polyphony ", _a.max_polyphony, " ", _b.max_polyphony)
	var period := la / _a.pitch_scale
	AudioServer.lock()
	_a.play(0.25 * la)
	_b.play(0.25 * lb)
	AudioServer.unlock()
	for i in 50:
		await create_timer(0.2).timeout
		_log("A", la, lb, period)
	AudioServer.lock()
	_b.play(_share(_a, la) * lb)
	AudioServer.unlock()
	print("restart")
	for i in 25:
		await create_timer(0.2).timeout
		_log("B", la, lb, period)
	_a.stop()
	_b.stop()
	await create_timer(0.5).timeout
	quit(0)
