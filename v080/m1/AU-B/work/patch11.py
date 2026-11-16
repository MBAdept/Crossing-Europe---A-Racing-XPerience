import sys
root = sys.argv[1]


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        if s.count(a) != 1:
            raise SystemExit('NICHT GENAU EINMAL (%d) in %s: %s' % (s.count(a), path, a[:100].replace('\n', ' | ')))
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8').write(s)


patch(root + '/scripts/audio/modern/engine_mix_thread.gd', [
    ('''## The worker keeps `latency` seconds queued (more when the audio driver takes larger blocks) in chunks of CHUNK
## frames and fades the engine out when the game thread sent nothing for WATCHDOG_S (a frozen window, a long load).''',
     '''## The worker keeps `latency` seconds queued (more when the audio driver takes larger blocks) in chunks of CHUNK
## frames and fades the engine out when the game thread sent nothing for WATCHDOG_S (a frozen window, a long load).
## A playback never starts empty: pump() renders the first `latency` seconds before the player starts and pushes
## them right after; the size of the driver's blocks is remembered for the whole process (known_burst_s), so a later
## engine (next stage, preview, resume after the pause) starts with the right queue length.'''),
    ('''var bank: EngineBank2
var rng := RandomNumberGenerator.new()''', '''## Largest block the audio driver took from a generator between two fills, in seconds (decaying maximum of the
## mixer that played last) – the Dummy driver of headless runs takes about 93 ms at once, sound servers 10–25 ms.
static var known_burst_s := 0.0

var bank: EngineBank2
var rng := RandomNumberGenerator.new()'''),
    ('''var _frames := PackedVector2Array()
var _tail := PackedVector2Array()''', '''var _frames := PackedVector2Array()
var _tail := PackedVector2Array()
var _pre := PackedVector2Array()
var _buffer_frames := 0'''),
    ('''	gen.buffer_length = buffer_s
	p_player.stream = gen
	player = p_player''', '''	gen.buffer_length = buffer_s
	p_player.stream = gen
	player = p_player
	_buffer_frames = int(buffer_s * _sr)'''),
    ('''	_silent_s = 0.0
	if not player.playing or _playback == null:
		stop_thread()
		player.play()
		_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return 0
		_capacity = _playback.get_frames_available()
		_queued = 0
		_burst = 0.0
		_pump_usec = Time.get_ticks_usec()''', '''	_silent_s = 0.0
	if not player.playing or _playback == null:
		stop_thread()
		# the first block is rendered before the player starts and pushed right after: the driver never finds an
		# empty generator, however its blocks fall
		_burst = known_burst_s * _sr
		var pre := clampi(maxi(int(latency_s * _sr), int(_burst * 1.25)), CHUNK, maxi(int(_buffer_frames * 0.85), CHUNK))
		if _pre.size() != pre:
			_pre.resize(pre)
		var t0 := Time.get_ticks_usec()
		render(_pre, 0, pre)
		var us := Time.get_ticks_usec() - t0
		player.play()
		_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return 0
		_capacity = _playback.get_frames_available()
		_queued = 0
		if pre <= _capacity:
			_playback.push_buffer(_pre)
			_queued = pre
		_pump_usec = Time.get_ticks_usec()
		_mutex.lock()
		_s_calls += 1
		_s_us_sum += us
		_s_us_max = maxi(_s_us_max, us)
		_s_samples += pre
		_mutex.unlock()'''),
    ('''	_burst = maxf(float(_queued - queued), _burst * exp(-float(now - _pump_usec) / 3.3e6))
	_pump_usec = now''', '''	_burst = maxf(float(_queued - queued), _burst * exp(-float(now - _pump_usec) / 3.3e6))
	known_burst_s = _burst / _sr
	_pump_usec = now'''),
])
patch(root + '/scripts/audio/modern/engine_audio3.gd', [
    ('''const START_WINDOW_S := 1.0      ## synchronous mode: after the engine start the generator queue is start_latency_s long''',
     '''const START_WINDOW_S := 1.0      ## after the engine start of a stage the generator queue is start_latency_s long'''),
    ('''func _pump(u: Unit, dt: float, node_name: String, latency_sync: float) -> void:
	if not ctx.live:
		return
	if u.mix.player == null and not u.mix.is_silent():
		u.mix.attach(ctx.player(BUS, node_name), _buffer)
	u.mix.pump(latency_sync if ctx.sync else _latency, dt, not ctx.sync)''', '''## Keeps the generator of a unit fed. starting: the first second of a stage – long frames (shaders, textures) and a
## driver whose block size is not known yet: the longer queue.
func _pump(u: Unit, dt: float, node_name: String, starting: bool) -> void:
	if not ctx.live:
		return
	if u.mix.player == null and not u.mix.is_silent():
		u.mix.attach(ctx.player(BUS, node_name), _buffer)
	var latency := _sync_latency if ctx.sync else _latency
	u.mix.pump(_start_latency if starting else latency, dt, not ctx.sync)'''),
    ('''		_pump(_unit, frame.dt, "EngineV3", _sync_latency if _time - _started_at > START_WINDOW_S else _start_latency)''',
     '''		_pump(_unit, frame.dt, "EngineV3", _time - _started_at <= START_WINDOW_S)'''),
    ('''	_pump(_preview, dt, "EnginePreview", _sync_latency)''', '''	_pump(_preview, dt, "EnginePreview", false)'''),
])
print('ok')
