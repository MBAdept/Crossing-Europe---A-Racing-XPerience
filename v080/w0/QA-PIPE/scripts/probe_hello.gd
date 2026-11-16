extends SceneTree
func _initialize() -> void:
	print("hello ", ModelDB.available(), " models=", ModelDB.model_ids())
	quit(0)
