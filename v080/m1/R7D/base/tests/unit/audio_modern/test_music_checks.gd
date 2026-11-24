extends TestCase
## Runs check_music.gd – the music of the Modern sound in a running game (contract §6 AU-D1: gapless loop and
## bar-synced ending of the race piece, the count-in landing on "LOS!", the ducking under full throttle and its
## recovery, nothing new with the Arcade profile, quitting while music plays) – in child processes, so
## tools/run_tests.sh covers it: a unit test runs before the scene tree starts and cannot play anything itself. One run
## with the scenarios interactive, race, arcade; two more that quit while the music plays (menu, race).
## Each run: exit code 0, every scenario OK, and no engine error or warning in the output – also not the notices the
## engine prints when a process ends while a player still plays ("leaked at exit", "still in use at exit"): the
## director's players stop with the profile (ModernAudio._exit_tree), so quitting with music must stay clean.

const CHECK := "res://tests/unit/audio_modern/check_music.gd"
const BAD: Array[String] = ["SCRIPT ERROR", "ERROR:", "Parse Error", "WARNING:", "leaked", "still in use", "FEHLER"]
const TIMEOUT_S := 150


func _run(extra: Array[String], expect: Array[String], label: String) -> void:
	var home := OS.get_user_data_dir().path_join("music_check")
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
			print("      ", label, " ", line.left(600))
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


func test_music_in_a_running_game() -> void:
	_run([], ["interactive", "race", "arcade"], "Musik im laufenden Spiel")


func test_quitting_while_music_plays() -> void:
	_run(["--only=quit_menu"], ["quit_menu"], "Beenden im Menü")
	_run(["--only=quit_race"], ["quit_race"], "Beenden im Rennen")
