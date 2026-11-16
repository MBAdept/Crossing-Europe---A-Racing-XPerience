extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var st: Node = root.get_node("Settings")
	print("V070-READS ", JSON.stringify(st.call("to_dict")), " chosen=", st.get("fullscreen_chosen"))
	st.call("save_settings")
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	print("V070-WRITES ", f.get_as_text().replace("\n", " "))
	quit(0)
