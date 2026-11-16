extends SceneTree
func _initialize() -> void:
	print("ARGS ", OS.get_cmdline_args())
	print("USER ", OS.get_cmdline_user_args())
	quit(0)
