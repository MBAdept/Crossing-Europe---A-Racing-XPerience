extends SceneTree
func _initialize() -> void:
	var r: Variant = ProbeThing.reload("x.json")
	print("RESULT ", r, " | ", ProbeThing.loaded)
	quit(0)
