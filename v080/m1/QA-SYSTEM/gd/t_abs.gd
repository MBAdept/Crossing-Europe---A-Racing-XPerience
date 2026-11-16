extends SceneTree
func _initialize() -> void:
	print("ABS OK ", root.get_node_or_null("Settings") != null)
	quit(0)
