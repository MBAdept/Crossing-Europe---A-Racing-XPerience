extends SceneTree
## QA lens 1: prints what the real Settings autoload made of user://settings.json (and the marker, the command line,
## a config override). --qa-save: change the volume and save, then print the file.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var s: Node = root.get_node("Settings")
	var out := {
		"graphics_mode": s.get("graphics_mode"), "sound_profile": s.get("sound_profile"), "sound_profile_chosen": s.get("sound_profile_chosen"),
		"gfx_preset": s.get("gfx_preset"), "gfx_custom": s.get("gfx_custom"), "race_music": s.get("race_music"),
		"race_music_chosen": s.get("race_music_chosen"), "fullscreen": s.get("fullscreen"), "fullscreen_chosen": s.get("fullscreen_chosen"),
		"crash_guard": s.get("crash_guard"), "effective": s.call("effective_graphics"), "is_modern": s.call("is_modern"),
		"sound": s.call("sound"), "quality": s.call("quality"), "tier": s.call("adapter_tier"), "unsaved": s.call("has_unsaved_changes"),
		"master_volume": s.get("master_volume"), "player_name": s.get("player_name"), "extra": s.get("_extra"),
	}
	print("PROBE ", JSON.stringify(out))
	if CliArgs.has("qa-levels"):
		print("LEVELS ", JSON.stringify(s.call("quality_levels")))
	if CliArgs.has("qa-save"):
		s.set("master_volume", 0.33)
		print("SAVED ", s.call("save_settings"))
		print("FILE ", FileAccess.get_file_as_string("user://settings.json").replace("\n", " "))
	quit(0)
