P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/scripts/audio/modern/engine_audio3.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new, count=1):
    global s
    assert s.count(old) == count, (s.count(old), old)
    s = s.replace(old, new)


rep('''	if _eng != null:
		_eng.detach()
	_eng = null
	_start_pending = false
	var bank := _bank(id)''', '''	_detach(_eng)
	_eng = null
	_start_pending = false
	var bank := _bank(id)''')
rep('''	if _preview_next != null and _preview.is_silent():
		_preview_next.take_output(_preview, ctx.host, BUS, _buffer)''', '''	if _preview_next != null and _preview.is_silent():
		_keep_stream(_preview)
		_preview_next.take_output(_preview, ctx.host, BUS, _buffer)''')
rep('''func _stop_preview() -> void:
	if _preview != null:
		_preview.detach()
	_preview = null
	_preview_next = null
''', '''func _stop_preview() -> void:
	_detach(_preview)
	_preview = null
	_preview_next = null


## Detaches an engine from its player. The generator stream is kept alive a little longer than the player (see
## ModernAudioContext.keep_alive: the audio thread still mixes a fade-out block of it).
func _detach(e: EngineAudio) -> void:
	if e == null:
		return
	_keep_stream(e)
	e.detach()


func _keep_stream(e: EngineAudio) -> void:
	if e != null and e.player != null and is_instance_valid(e.player):
		ModernAudioContext.keep_alive(e.player.stream)
''')
rep('''func stop_all() -> void:
	if _eng != null:
		_eng.detach()
		_eng.reset()
	_stop_preview()''', '''func stop_all() -> void:
	if _eng != null:
		_detach(_eng)
		_eng.reset()
	_stop_preview()''')
rep('''func teardown() -> void:
	if _eng != null:
		_eng.detach()
	_eng = null
	_stop_preview()''', '''func teardown() -> void:
	_detach(_eng)
	_eng = null
	_stop_preview()''')
open(P, "w", encoding="utf-8").write(s)

P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/scripts/audio/modern/modern_audio.gd"
s = open(P, encoding="utf-8").read()
rep('''	if not started or delta <= 0.0:
		return
	_time += delta
	_paused = paused
''', '''	if not started or delta <= 0.0:
		return
	ModernAudioContext.release_kept()
	_time += delta
	_paused = paused
''')
open(P, "w", encoding="utf-8").write(s)
print("ok")
