extends SceneTree
## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd [-- --filter=fuel]
## Runs every test_* method of every script in res://tests/unit (and subfolders). Exit code 1 on failure.
## A test that stops on a script error (GDScript aborts the method: no assertion fails, _failures stays empty) counts
## as FAILED with the error line – a Logger watches every test (FIX-M2, QA-M2-SYSTEM M2S-04: a single run of
## test_props with a broken rule reported "ok"; only the SCRIPT ERROR grep of tools/run_tests.sh caught it).


## Counts the script errors (runtime errors of GDScript) reported while a test runs.
class ScriptErrorCatch extends Logger:
	var hits := 0
	var first := ""
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_lock.lock()
		hits += 1
		if first == "":
			first = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		_lock.unlock()

	func take() -> Array:
		_lock.lock()
		var out := [hits, first]
		hits = 0
		first = ""
		_lock.unlock()
		return out


var _watchdog := 0.0
var _errors := ScriptErrorCatch.new()


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
	OS.add_logger(_errors)
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
			_errors.take()
			inst.call(n)
			total += 1
			var fails: Array = (inst.get("_failures") as Array).duplicate()
			var err: Array = _errors.take()
			if int(err[0]) > 0:
				fails.append("Skriptfehler im Test (%d×), Test abgebrochen: %s" % [int(err[0]), str(err[1])])
			if fails.size() > 0:
				failed += 1
				print("FAIL  %s :: %s" % [path.get_file(), n])
				for f in fails:
					print("      ", f)
			else:
				print("ok    %s :: %s" % [path.get_file(), n])
	print("\n%d Tests, %d fehlgeschlagen" % [total, failed])
	OS.remove_logger(_errors)
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
