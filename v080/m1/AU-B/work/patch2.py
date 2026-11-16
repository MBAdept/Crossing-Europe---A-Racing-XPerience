import sys


def patch(p, pairs):
    s = open(p, encoding='utf-8').read()
    for a, b in pairs:
        if a not in s:
            print('NICHT GEFUNDEN in', p, ':', a[:80].replace('\n', ' | '))
            sys.exit(1)
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)


patch('scripts/audio/modern/engine_mix_thread.gd', [
    ('''	var g := clampf(gain, 0.0, 1.0)
	_mutex.lock()
	if g == _c_gain_goal and _c_events.is_empty():
		_mutex.unlock()
		return
	_mutex.unlock()
	_event(["fade", g, seconds], g)''', '''	var g := clampf(gain, 0.0, 1.0)
	_mutex.lock()
	var same := g == _c_gain_goal
	_mutex.unlock()
	if not same:
		_event(["fade", g, seconds], g)'''),
    ('''	_mutex.lock()
	_c_events.append(e)
	if gain_goal >= 0.0:''', '''	_mutex.lock()
	if _c_events.size() >= MAX_EVENTS:
		_c_events.pop_front()      # nobody renders (headless): the queue must not grow
	_c_events.append(e)
	if gain_goal >= 0.0:'''),
    ('''const MAX_CLIPS := 10
''', '''const MAX_CLIPS := 10
const MAX_EVENTS := 32           ## pending control events (they are taken with every rendered chunk)
'''),
    ('''			_load_s = load
			_thr_s = thr
			_boost_s = boost
			_e_l = clampf(maxf(load, _idle_share()) * _gate_s, 0.0, 1.0)''', '''			_load_s = maxf(load, _idle_share())
			_thr_s = thr
			_boost_s = boost
			_e_l = clampf(_load_s * _gate_s, 0.0, 1.0)'''),
])
patch('scripts/audio/modern/engine_audio3.gd', [
    ('''	if _preview_wanted != "" and (_preview == null or _preview.mix.is_silent()) and _bank_ready(_preview_wanted):''',
     '''	if _preview_wanted != "" and (_preview == null or not ctx.live or _preview.mix.is_silent()) and _bank_ready(_preview_wanted):'''),
    ('''	if _preview_wanted == "" and _preview.mix.is_silent() and _preview_t > EngineAudio.PREVIEW_S + 0.5:''',
     '''	if _preview_wanted == "" and (not ctx.live or _preview.mix.is_silent()) and _preview_t > EngineAudio.PREVIEW_S + 0.5:'''),
])
print('ok')
