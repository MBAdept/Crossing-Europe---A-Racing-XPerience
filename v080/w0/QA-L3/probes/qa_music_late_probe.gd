extends SceneTree
## QA lens 3: Modern menu music when the Arcade title stream only arrives after the context was set (the
## synthesised fallback music is generated in a thread when audio.music_file is missing).
func _initialize() -> void:
	_run.call_deferred()
func _process(_d: float) -> bool:
	return false
func _run() -> void:
	for i in 4:
		await process_frame
	ModernAudio.force_live = true
	var streams := {}
	var m := ModernAudio.new()
	root.add_child(m)
	m.start(ConfigLoader.load_merged(), {"streams": streams, "quiet": true})
	m.set_music(true)                      # GameFlow at the title: menu music on – the stream is not there yet
	for i in 30:
		await process_frame
	var before: Dictionary = m.music.debug_state()
	var w := AudioStreamWAV.new()          # … and now it arrives (AudioManager._on_music_ready sets _streams["music"])
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	var b := PackedByteArray()
	b.resize(44100 * 2)
	for i in 44100:
		b.encode_s16(i * 2, int(sin(TAU * 440.0 * i / 44100.0) * 8000.0))
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = 44100
	streams["music"] = w
	for i in 120:
		await process_frame
	var after: Dictionary = m.music.debug_state()
	print("MUSIC-LATE before the stream exists: key '%s', playing %s" % [before["key"], str(before["playing"])])
	print("MUSIC-LATE 120 frames after the stream arrived: key '%s', playing %s  -> %s" % [after["key"], str(after["playing"]),
		"plays" if after["playing"] else "STAYS SILENT (the piece was started with no stream and is never started again)"])
	m.set_music(false)
	m.set_music(true)
	for i in 60:
		await process_frame
	print("MUSIC-LATE after set_music(false) + set_music(true): playing %s" % str(m.music.debug_state()["playing"]))
	m.shutdown()
	m.queue_free()
	await process_frame
	quit(0)
