extends TestCase
## Runs check_modern_audio.gd – the two sound profiles in a running game (contract §6 AU-A, acceptance) – in child
## processes, so tools/run_tests.sh covers it without a new hook: once as a plain headless game, once with playback
## forced (--live: the Arcade sounds built as on a display, Modern players, the placeholders). A unit test cannot
## do this itself: it runs before the scene tree starts. The children get a data folder of their own.
## Each run: exit code 0, every scenario reported OK, no engine error, warning or leak in the output.

const CHECK := "res://tests/unit/audio_modern/check_modern_audio.gd"
const PLAIN: Array[String] = ["arcade_boot", "new_api", "modern_buses", "switch_20", "delegation", "race", "arcade_after"]
const LIVE: Array[String] = ["arcade_boot", "new_api", "modern_buses", "switch_20", "delegation", "mix", "race", "arcade_after"]
const BAD: Array[String] = ["SCRIPT ERROR", "ERROR:", "Parse Error", "WARNING:", "leaked", "still in use", "FEHLER"]
const TIMEOUT_S := 150


func _run(extra: Array[String], expect: Array[String], label: String) -> void:
	var home := OS.get_user_data_dir().path_join("audio_modern_check")
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
			print("      ", label, " ", line.left(240))
			var parts := line.substr(6).strip_edges().split(" ", false)
			if parts.size() >= 2:
				seen[parts[0]] = parts[1]
	print("      %s: %.1f s, Exit %d" % [label, (Time.get_ticks_msec() - t0) / 1000.0, code])
	assert_eq(code, 0, "%s: Exit-Code" % label)
	for n in expect:
		assert_eq(str(seen.get(n, "fehlt")), "OK", "%s: Szenario %s" % [label, n])
	assert_eq(seen.size(), expect.size(), "%s: genau diese Szenarien" % label)
	for line in text.split("\n"):
		for bad in BAD:
			if line.contains(bad):
				fail("%s: %s" % [label, line.strip_edges().left(300)])
				break


func test_profiles_in_a_running_game() -> void:
	_run([], PLAIN, "ohne Wiedergabe")


func test_profiles_in_a_running_game_with_playback() -> void:
	_run(["--live"], LIVE, "mit Wiedergabe")
