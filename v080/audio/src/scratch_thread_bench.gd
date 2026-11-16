extends SceneTree
## v0.8.0 audio study (scratch): cost of a stereo 48 kHz engine mix in GDScript and feeding the AudioStreamGenerator
## from a worker thread (robust against frame hitches) vs. from the main thread (as today).
##   --mode=main|thread  --seconds=12

const RATE := 48000
var _bank: EngineBank
var _el: EngineAudio
var _er: EngineAudio
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _thread: Thread
var _run := true
var _mode := "thread"
var _t := 0.0
var _secs := 12.0
var _frames := 0
var _l := PackedFloat32Array()
var _r := PackedFloat32Array()
var _out := PackedVector2Array()
var _render_us := 0
var _render_calls := 0
var _render_max := 0
var _samples := 0
var _mutex := Mutex.new()
var _rpm := 5200.0
var _load := 1.0
var _capacity := 0
var _hitches := 0


func _initialize() -> void:
	_mode = CliArgs.get_string("mode", "thread")
	Engine.max_fps = 60
	_secs = CliArgs.get_float("seconds", 12.0)
	_bank = EngineBank.load_file("res://assets/audio/engines/gran_turismo.json")
	_el = EngineAudio.new(_bank, 1)
	_er = EngineAudio.new(_bank, 2)
	for e: EngineAudio in [_el, _er]:
		e.set_manual(5200.0, 1.0)
		e.start(false)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	gen.mix_rate = float(RATE)
	gen.buffer_length = 0.25
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	root.add_child(_player)


func _setup() -> void:
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_capacity = _pb.get_frames_available()
	print("mode %s, mix rate %d, generator capacity %d frames, bank rate %d" % [_mode, int(AudioServer.get_mix_rate()), _capacity, _bank.sample_rate])
	if _mode == "thread":
		_thread = Thread.new()
		_thread.start(_thread_loop)


## Renders `need` stereo frames: two mono engines stand in for the two channels of a stereo bank (same cost).
func _fill(need: int) -> void:
	var t0 := Time.get_ticks_usec()
	if _l.size() != need:
		_l.resize(need)
		_r.resize(need)
		_out.resize(need)
	_mutex.lock()
	var rpm := _rpm
	var ld := _load
	_mutex.unlock()
	_el.set_manual(rpm, ld, false, float(need) / RATE)
	_er.set_manual(rpm, ld, false, float(need) / RATE)
	_el.render(_l, 0, need)
	_er.render(_r, 0, need)
	for k in need:
		_out[k] = Vector2(_l[k], _r[k])
	_pb.push_buffer(_out)
	var us := Time.get_ticks_usec() - t0
	_render_us += us
	_render_calls += 1
	_render_max = maxi(_render_max, us)
	_samples += need


func _pump(target_s: float) -> void:
	var free := _pb.get_frames_available()
	var queued := _capacity - free
	var need := mini(int(target_s * RATE) - queued, free)
	if need > 0:
		_fill(need)


func _thread_loop() -> void:
	while _run:
		_pump(0.15)
		OS.delay_usec(4000)


func _process(delta: float) -> bool:
	if _pb == null:
		_setup()
		return false
	_t += delta
	_frames += 1
	# control from the "game": rpm sweeps, read by the mixer under a mutex
	_mutex.lock()
	_rpm = 3000.0 + 2500.0 * (0.5 + 0.5 * sin(_t * 0.8))
	_load = 1.0 if fmod(_t, 4.0) < 3.0 else 0.0
	_mutex.unlock()
	if _mode == "main":
		_pump(0.15)
	# frame hitch every 2 s: the main thread is busy for 180 ms (shader compilation, loading)
	if _frames % 120 == 60:
		_hitches += 1
		var t0 := Time.get_ticks_msec()
		var x := 0.0
		while Time.get_ticks_msec() - t0 < 400:
			x += sqrt(float(_frames))
	if _t >= _secs:
		_run = false
		if _thread != null:
			_thread.wait_to_finish()
		print("audio rendered %.2f s in %.2f s wall, output latency %.1f ms, time to next mix %.1f ms" % [_samples / float(RATE), _t, AudioServer.get_output_latency() * 1000.0, AudioServer.get_time_to_next_mix() * 1000.0])
		print("RESULT mode=%s frames=%d hitches=%d skips=%d  render: %.3f ms per call (max %.3f), %.2f %% of real time, %.3f ms per 1/60 s of stereo 48 kHz audio" % [
			_mode, _frames, _hitches, _pb.get_skips(), _render_us / 1000.0 / maxi(_render_calls, 1), _render_max / 1000.0,
			100.0 * _render_us / 1.0e6 / (_samples / float(RATE)), _render_us / 1000.0 / (_samples / float(RATE)) / 60.0])
		_player.stop()
		return true
	return false
