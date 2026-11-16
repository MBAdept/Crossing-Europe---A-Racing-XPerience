extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _process(_d: float) -> bool:
	return false
func _run() -> void:
	for i in 4:
		await process_frame
	var s: Node = root.get_node("Settings")
	var am: Node = root.get_node("AudioManager")
	var d := {}
	for k in ["master_volume", "sfx_volume", "music_volume", "fullscreen", "fullscreen_chosen", "vibration", "player_name", "language", "leaderboard_filter"]:
		d[k] = s.get(k)
	var extra := {}
	if s.has_method("effective_graphics"):
		extra = {"graphics_mode": s.get("graphics_mode"), "effective": s.call("effective_graphics"), "sound()": s.call("sound"),
			"audio_profile": am.call("profile"), "sound_profile": s.get("sound_profile"), "race_music": s.get("race_music")}
	print("SETTINGS ", JSON.stringify(d, "", true))
	print("SETTINGS-NEW ", JSON.stringify(extra, "", true))
	if OS.get_cmdline_user_args().has("--save"):
		s.set("master_volume", 0.55)
		s.call("save_settings")
	quit(0)
