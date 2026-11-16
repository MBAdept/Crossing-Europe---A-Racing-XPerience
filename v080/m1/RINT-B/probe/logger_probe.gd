extends SceneTree
## Does this engine have Logger / OS.add_logger (engine errors seen by a script)?


class Catch extends Logger:
	var hits: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		hits.append("%s|%s" % [code, rationale])

	func _log_message(message: String, error: bool) -> void:
		pass


func _initialize() -> void:
	print("Logger exists: ", ClassDB.class_exists("Logger"), " add_logger: ", OS.has_method("add_logger"))
	var c := Catch.new()
	OS.add_logger(c)
	push_error("probe error")
	var img := Image.new()
	img.get_pixel(5, 5)   # engine error
	print("caught: ", c.hits)
	OS.remove_logger(c)
	quit()
