extends SceneTree
func _initialize() -> void:
	var r: Variant = ThingDB.reload("res://x.json")
	print("returned: ", r, "  calls=", ThingDB.calls)
	var r2: Variant = ThingDB.reload()
	print("returned without argument: ", r2, "  calls=", ThingDB.calls)
	quit(0)
