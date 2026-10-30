extends SceneTree
## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd [-- --filter=fuel]
## Runs every test_* method of every script in res://tests/unit (and subfolders). Exit code 1 on failure.


var _watchdog := 0.0


func _process(delta: float) -> bool:
	_watchdog += delta
	if _watchdog > 300.0:
		print("FEHLER: Tests hängen – Abbruch")
		quit(2)
	return false


func _initialize() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var files: Array[String] = []
	_collect("res://tests/unit", files)
	files.sort()
	var total := 0
	var failed := 0
	for path in files:
		if filter != "" and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL  %s :: Skript kann nicht geladen werden (Parse-Fehler?)" % path.get_file())
			failed += 1
			continue
		var inst: Object = script.new()
		var methods: Array[String] = []
		for m in inst.get_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not methods.has(n):
				methods.append(n)
		for n in methods:
			inst.call("_reset", n)
			inst.call(n)
			total += 1
			var fails: Array = inst.get("_failures")
			if fails.size() > 0:
				failed += 1
				print("FAIL  %s :: %s" % [path.get_file(), n])
				for f in fails:
					print("      ", f)
			else:
				print("ok    %s :: %s" % [path.get_file(), n])
	print("\n%d Tests, %d fehlgeschlagen" % [total, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)
