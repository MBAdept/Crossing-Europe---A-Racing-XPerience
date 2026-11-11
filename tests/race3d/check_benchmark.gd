extends SceneTree
## v0.8.0 (UI1): the Leistungstest end to end, headless (~25 s), through the generic hook of tools/run_tests.sh:
##   godot --headless --path . -s res://tests/race3d/check_benchmark.gd
## GameFlow.start_benchmark() drives the scenes of graphics.benchmark.scenes with the Modern renderer of the build
## (whatever it is – the wave-0 stub or the real one): the result has the format of contract §4.8, is written to the
## result file and to --bench-out, the screen "LEISTUNGSTEST" shows it, frame cap and V-Sync are restored. A Modern
## renderer that cannot start (--gfx-debug=fail) ends the test with "fallback" and the suggestion Arcade – and that
## result is written too; an aborted test writes nothing; a list of unknown scenes ends with "no_scene".
## The runner is loaded at run time (a -s script compiles before the autoloads exist, A-1).
## Prints "CHECK <name> OK|FEHLER" lines; exit code 1 on a failure.

const BENCH := "res://scripts/race3d/benchmark.gd"
const OUT := "user://test_check_benchmark_out.json"
const FILE := "user://leistungstest.json"
const SECONDS := 0.4
const CONTRACT_KEYS: Array[String] = ["version", "date", "adapter", "api", "tier", "preset", "quality", "resolution",
	"scenes", "suggested_preset"]
const SCENE_KEYS: Array[String] = ["id", "avg_fps", "low1_fps", "frame_ms_p95", "frame_ms_p99", "script_ms",
	"draw_calls", "primitives"]

var _gf: Node
var _failed: Array[String] = []
var _n := 0
var _t0 := 0
var _result: Dictionary = {}
var _done := false


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _check(check_name: String, ok: bool, msg: String = "") -> void:
	_n += 1
	print("CHECK %-16s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Waits until GameFlow's test has ended (its runner is gone) or `max_s` passed; the result comes from the runner's
## `finished` (connected in _start).
func _wait_done(max_s: float) -> bool:
	var t := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - t < int(max_s * 1000.0):
		await process_frame
	await _frames(3)
	return _done


func _start(ids: Array, opts: Dictionary) -> bool:
	_done = false
	_result = {}
	var ok := bool(_gf.call("start_benchmark", ids, opts))
	var bench: Variant = _gf.get("benchmark")
	if bench is Node and is_instance_valid(bench):
		(bench as Node).connect("finished", func(r: Dictionary) -> void:
			_result = r
			_done = true)
	elif ok:
		_done = true   # ended at once (no runner script)
	return ok


func _run() -> void:
	_gf = root.get_node_or_null("GameFlow")
	(_gf.get("attract") as Node).set("enabled", false)
	var bench_script := load(BENCH) as GDScript
	_check("laeufer", bench_script != null and bench_script.can_instantiate(), BENCH)
	if bench_script == null:
		_finish()
		return
	var cli: Dictionary = CliArgs.all()
	cli.erase("gfx-debug")
	_remove(FILE)
	_remove(OUT)
	var max_fps_before := Engine.max_fps
	# 1 – the whole test with every scene (short), in Modern, result screen afterwards
	var started := await _start([], {"seconds": SECONDS, "out": OUT})
	var finished := await _wait_done(120.0)
	var scenes: Array = _result.get("scenes", [])
	var ids: Array[String] = []
	for s: Variant in scenes:
		ids.append(str((s as Dictionary).get("id", "")))
	_check("lauf", started and finished and ids == ["autobahn", "stadt_nacht_regen", "berg_tunnel"]
		and str(_result.get("fallback", "x")) == "" and not bool(_result.get("aborted", true)) and str(_result.get("error", "x")) == "",
		"Szenen %s, Rückfall '%s', Fehler '%s', Gerüst %s" % [ids, _result.get("fallback", ""), _result.get("error", ""),
			_result.get("renderer_stub", "?")])
	# 2 – format of contract §4.8, plausible numbers
	var missing: Array[String] = []
	for k in CONTRACT_KEYS:
		if not _result.has(k):
			missing.append(k)
	for s: Variant in scenes:
		for k in SCENE_KEYS:
			if not (s as Dictionary).has(k):
				missing.append("scenes." + k)
	var q: Variant = _result.get("quality", {})
	var q_ok := q is Dictionary and (q as Dictionary).size() == 5
	for k in Gfx.QUALITY_KEYS:
		q_ok = q_ok and q is Dictionary and (q as Dictionary).has(k)
	var nums_ok := not scenes.is_empty()
	for s: Variant in scenes:
		var d: Dictionary = s
		nums_ok = nums_ok and float(d["avg_fps"]) > 0.0 and float(d["low1_fps"]) > 0.0 and float(d["low1_fps"]) <= float(d["avg_fps"]) + 0.05 \
			and float(d["frame_ms_p99"]) >= float(d["frame_ms_p95"]) and int(d.get("frames", 0)) > 0 and float(d["script_ms"]) >= 0.0
	var res: Variant = _result.get("resolution", [])
	_check("format", missing.is_empty() and q_ok and nums_ok and int(_result.get("version", 0)) == 1
		and res is Array and (res as Array).size() == 2 and Gfx.PRESET_ORDER.has(str(_result.get("suggested_preset", ""))),
		"fehlt %s, Qualität %s, Zahlen %s, Vorschlag %s/%s" % [missing, JSON.stringify(q), nums_ok,
			_result.get("suggested_preset", ""), _result.get("suggested_mode", "")])
	# 3 – written: user://leistungstest.json and --bench-out, the same content
	var f1: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	var f2: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT)) if FileAccess.file_exists(OUT) else null
	_check("datei", f1 is Dictionary and f2 is Dictionary and JSON.stringify(f1) == JSON.stringify(f2)
		and ((f1 as Dictionary).get("scenes", []) as Array).size() == 3 and bool(_result.get("written", false)),
		"%s: %s, --bench-out: %s" % [FILE, f1 is Dictionary, f2 is Dictionary])
	# 4 – the result screen, the frame cap restored, nothing left over
	await _frames(4)
	var screen_name := str(_gf.call("current_screen_name"))
	var shell: Node = _gf.get("shell")
	var screen: Node = shell.get("current_screen") if shell != null else null
	var shown: Variant = screen.get("result") if screen != null else null
	_check("bildschirm", screen_name == "benchmark" and shown is Dictionary and ((shown as Dictionary).get("scenes", []) as Array).size() == 3
		and Engine.max_fps == max_fps_before and _gf.get("benchmark") == null,
		"Bildschirm %s, Bildrate begrenzt %d (vorher %d)" % [screen_name, Engine.max_fps, max_fps_before])
	# 5 – Modern cannot start: fallback, suggestion Arcade, written
	_remove(FILE)
	cli["gfx-debug"] = "fail"
	await _start(["autobahn"], {"seconds": SECONDS})
	await _wait_done(60.0)
	cli.erase("gfx-debug")
	_check("rueckfall", str(_result.get("fallback", "")) != "" and str(_result.get("suggested_mode", "")) == "arcade"
		and (_result.get("scenes", [1]) as Array).is_empty() and bool(_result.get("written", false)) and FileAccess.file_exists(FILE),
		"Rückfall '%s', Vorschlag %s, geschrieben %s" % [_result.get("fallback", ""), _result.get("suggested_mode", ""),
			_result.get("written", false)])
	# 6 – aborted: nothing written, the start page comes back
	_remove(FILE)
	await _start(["berg_tunnel"], {"seconds": 5.0})
	await _frames(20)
	var bench: Variant = _gf.get("benchmark")
	if bench is Node and is_instance_valid(bench):
		(bench as Node).call("abort", "user")
	await _wait_done(20.0)
	await _frames(4)
	_check("abbruch", bool(_result.get("aborted", false)) and not bool(_result.get("written", true)) and not FileAccess.file_exists(FILE)
		and str(_gf.call("current_screen_name")) == "benchmark",
		"abgebrochen %s, geschrieben %s, Bildschirm %s" % [_result.get("aborted", false), _result.get("written", false),
			_gf.call("current_screen_name")])
	# 7 – scene selection: one scene by id; unknown ids end at once with "no_scene"
	var sel: Array = bench_script.call("select_scenes", ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics.benchmark.scenes", []), ["berg_tunnel"])
	await _start(["gibt_es_nicht"], {"seconds": SECONDS, "quit": false})
	await _wait_done(10.0)
	var setup: Dictionary = bench_script.call("scene_setup", sel[0] if not sel.is_empty() else {}, ConfigLoader.load_merged())
	_check("auswahl", sel.size() == 1 and str(_result.get("error", "")) == "no_scene" and str(setup.get("gfx", "")) == "modern"
		and bool(setup.get("autopilot", false)) and int(setup.get("seed", -1)) == 23,
		"%d Szene(n), Fehler '%s', setup.gfx %s, Seed %d" % [sel.size(), _result.get("error", ""), setup.get("gfx", ""),
			int(setup.get("seed", -1))])
	_remove(OUT)
	_remove(FILE)
	_finish()


func _finish() -> void:
	print("CHECKS %s  (%d von %d bestanden, %d s)" % ["OK" if _failed.is_empty() else "FEHLER", _n - _failed.size(), _n,
		(Time.get_ticks_msec() - _t0) / 1000])
	quit(0 if _failed.is_empty() else 1)
