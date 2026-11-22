extends TestCase
## Runs check_engine3.gd – the engine v3 with playback in a running game (contract §6 AU-B: thread bench, shutdown)
## – in child processes, so tools/run_tests.sh covers it: a unit test runs before the scene tree starts and cannot
## play anything itself. One full run (worker thread through six main-thread hitches without an underrun, the same
## drive on the main thread with underruns, ten profile switches with a running worker, quitting with a running
## worker) and two more quits. The children get a data folder of their own.
## Each run: exit code 0, every scenario OK, no engine error or warning in the output – but for the two notices the
## engine prints whenever a process ends while any sound is still playing (measured with a single plain
## AudioStreamPlayer: "ObjectDB instances were leaked at exit", "resources still in use at exit"); they belong to
## quitting mid-sound, not to the mixer thread.

const CHECK := "res://tests/unit/audio_modern/check_engine3.gd"
const ALL: Array[String] = ["thread", "sync", "switch", "quit"]
const BAD: Array[String] = ["SCRIPT ERROR", "ERROR:", "Parse Error", "WARNING:", "leaked", "still in use", "FEHLER"]
const AT_EXIT: Array[String] = ["ObjectDB instances were leaked at exit", "resources still in use at exit"]
const TIMEOUT_S := 120


func _run(extra: Array[String], expect: Array[String], label: String) -> void:
	var home := OS.get_user_data_dir().path_join("engine3_check")
	DirAccess.make_dir_recursive_absolute(home)
	var had := OS.has_environment("XDG_DATA_HOME")
	var old := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", home)
	var args: Array[String] = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CHECK, "--", "--graphics=arcade"]
	args.append_array(extra)
	var exe := OS.get_executable_path()
	if FileAccess.file_exists("/usr/bin/timeout"):
		# a hung child must not hang the whole test run
		args = (["-s", "KILL", str(TIMEOUT_S), exe] as Array[String]) + args
		exe = "/usr/bin/timeout"
	var out: Array = []
	var t0 := Time.get_ticks_msec()
	var code := OS.execute(exe, args, out, true)
	if had:
		OS.set_environment("XDG_DATA_HOME", old)
	else:
		OS.unset_environment("XDG_DATA_HOME")
	var text := "\n".join(out)
	var seen := {}
	for line in text.split("\n"):
		if line.begins_with("CHECK "):
			print("      ", label, " ", line.left(420))
			var parts := line.substr(6).strip_edges().split(" ", false)
			if parts.size() >= 2:
				seen[parts[0]] = parts[1]
	print("      %s: %.1f s, Exit %d" % [label, (Time.get_ticks_msec() - t0) / 1000.0, code])
	assert_eq(code, 0, "%s: Exit-Code" % label)
	for n in expect:
		assert_eq(str(seen.get(n, "fehlt")), "OK", "%s: Szenario %s" % [label, n])
	assert_eq(seen.size(), expect.size(), "%s: genau diese Szenarien" % label)
	for line in text.split("\n"):
		var at_exit := false
		for known in AT_EXIT:
			at_exit = at_exit or line.contains(known)
		if at_exit:
			continue
		for bad in BAD:
			if line.contains(bad):
				fail("%s: %s" % [label, line.strip_edges().left(300)])
				break


func test_engine_thread_in_a_running_game() -> void:
	_run([], ALL, "Motor v3 mit Wiedergabe")


func test_quitting_with_a_running_engine_thread() -> void:
	for i in 2:
		_run(["--only=quit"], ["quit"], "Spielende %d" % (i + 1))
