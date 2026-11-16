extends SceneTree
## Probe: which playback APIs exist in this engine build (offline mixing of AudioStreamInteractive).


func _initialize() -> void:
	for m in ["mix_audio", "start", "stop", "is_playing", "get_playback_position", "seek"]:
		print("AudioStreamPlayback.%s: %s" % [m, ClassDB.class_has_method("AudioStreamPlayback", m)])
	for m in ["switch_to_clip_by_name", "switch_to_clip", "get_current_clip_index"]:
		print("AudioStreamPlaybackInteractive.%s: %s" % [m, ClassDB.class_has_method("AudioStreamPlaybackInteractive", m)])
	print("mix rate: ", AudioServer.get_mix_rate())
	print("AudioStreamOggVorbis props: ", ClassDB.class_has_method("AudioStreamOggVorbis", "set_bpm"), " ", ClassDB.class_has_method("AudioStreamOggVorbis", "set_beat_count"), " ", ClassDB.class_has_method("AudioStreamOggVorbis", "set_bar_beats"))
	quit()
