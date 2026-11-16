import sys
root = sys.argv[1]


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        if s.count(a) < 1:
            raise SystemExit('NICHT GEFUNDEN in %s: %s' % (path, a[:100].replace('\n', ' | ')))
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8').write(s)


patch(root + '/scripts/audio/modern/engine_audio3.gd', [
    ('''const SYNC_SEED := 20261111      ## seed of the mixers in synchronous mode (sample-identical runs)
''', '''const SYNC_SEED := 20261111      ## seed of the mixers in synchronous mode (sample-identical runs)
const HITCH_S := 0.25            ## a frame at least this long may be a hitch and not a session that is gone


## The car is driven in this frame. ModernAudio counts a session as gone when it did not call for ALIVE_S (0.35 s) –
## and a single frame that took that long looks just the same: frame.alive is false for it, although the session
## calls again right after. The mixer thread plays through such a hitch; fading the engine out for one frame would
## put a dip where there was none. So a long frame that follows a driven one still counts (the pause does not).
## A session that is really gone is seen one frame later.
static func driven(frame: ModernAudioFrame, was_driven: bool) -> bool:
	return frame.alive or (was_driven and not frame.paused and frame.dt >= HITCH_S)
'''),
    ('''var _unit: Unit = null
var _start_pending := false''', '''var _unit: Unit = null
var _driven := false
var _start_pending := false'''),
    ('''	_time = frame.time
	if _unit == null:
		if _fallback != null and frame.alive:
			_fallback.update(frame.dt, frame.speed, frame.throttle, frame.vmax, frame.active)
	else:
		if frame.alive:
			if _start_pending:''', '''	_time = frame.time
	_driven = driven(frame, _driven)
	if _unit == null:
		if _fallback != null and _driven:
			_fallback.update(frame.dt, frame.speed, frame.throttle, frame.vmax, frame.active)
	else:
		if _driven:
			if _start_pending:'''),
    ('''func stop_all() -> void:
	if _unit != null:''', '''func stop_all() -> void:
	_driven = false
	if _unit != null:'''),
])
patch(root + '/scripts/audio/modern/vehicle_layers.gd', [
    ('''var _has_car := false
''', '''var _has_car := false
var _driven := false
'''),
    ('''	var on := _has_car and frame.alive and not frame.effects_muted and not e.is_empty()''',
     '''	_driven = EngineAudio3.driven(frame, _driven)      # a single long frame is not a session that is gone
	var on := _has_car and _driven and not frame.effects_muted and not e.is_empty()'''),
    ('''	var k := 1.0 - exp(-dt / (SMOOTH_S if on else FADE_S))''', '''	var k := 1.0 - exp(-minf(dt, 0.1) / (SMOOTH_S if on else FADE_S))'''),
    ('''func stop_all() -> void:
	turbo.silence()''', '''func stop_all() -> void:
	_driven = false
	turbo.silence()'''),
])
print('ok')
