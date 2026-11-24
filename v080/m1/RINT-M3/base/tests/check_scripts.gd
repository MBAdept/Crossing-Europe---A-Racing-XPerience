extends SceneTree
## Compiles every GDScript under res://scripts and res://tests and reports parse/compile errors.
##   godot --headless --path . -s res://tests/check_scripts.gd


func _initialize() -> void:
	var files: Array[String] = []
	for root in ["res://scripts", "res://tests"]:
		_collect(root, files)
	var bad := 0
	for f in files:
		var s: GDScript = load(f)
		if s == null or not s.can_instantiate():
			bad += 1
			print("KAPUTT  ", f)
	print("%d Skripte geprüft, %d fehlerhaft" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)
