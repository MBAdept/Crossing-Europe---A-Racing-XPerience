extends SceneTree
## Quitting the game through GameFlow.quit_game() with either sound profile leaves nothing behind (RINT-B; AU-D1 found
## that an immediate quit() reported the stopped playbacks as "ObjectDB instances leaked at exit" in both profiles).
## Render check (Xvfb: the sounds are built only with a display; tools/run_render_checks.sh runs every
## tests/race3d/render/check_*.gd):
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tests/race3d/render/check_quit_sound.gd
## Per profile (arcade, modern) RUNS child processes of this file start the game (main scene: the title with its music),
## let it run 2.5 s and call GameFlow.quit_game(). A child fails on any "leaked", "still in use", "SCRIPT ERROR" or
## "ERROR:" line of its output and when it does not end by itself within its time limit.
## Prints "RENDER-CHECK quit_<profile> OK|FEHLER …"; exit code 0 when all pass.

const RUNS := 3
const BAD: Array[String] = ["leaked", "still in use", "SCRIPT ERROR", "Parse Error", "ERROR:"]
const CHILD_FRAMES := 150          ## 2.5 s at 60 fps before the child quits

var _child := ""
var _frames := 0
var _asked := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--child="):
			_child = a.substr(8)
	if _child != "":
		# a child: the real game – autoloads, the main scene (title), its music – then GameFlow.quit_game()
		change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))
		return
	_run.call_deferred()


func _process(_dt: float) -> bool:
	if _child == "" or _asked:
		return false
	_frames += 1
	if _frames >= CHILD_FRAMES:
		_asked = true
		var gf := root.get_node_or_null(^"GameFlow")
		if gf == null:
			print("KIND ohne GameFlow")
			quit(3)
		else:
			gf.call(&"quit_game")
	return false


func _run() -> void:
	var failed := 0
	var exe := OS.get_executable_path()
	for profile: String in ["arcade", "modern"]:
		var bad_runs: Array[String] = []
		var t0 := Time.get_ticks_msec()
		for i in RUNS:
			var out: Array = []
			var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
				"--resolution", "640x360", "-s", "res://tests/race3d/render/check_quit_sound.gd", "--",
				"--child=" + profile, "--sound=" + profile, "--graphics=arcade", "--no-chooser"]
			var code := OS.execute("timeout", ["60", exe] + args, out, true)
			var text := "\n".join(out)
			var hits: Array[String] = []
			for line in text.split("\n"):
				for b in BAD:
					if line.contains(b):
						hits.append(line.strip_edges().substr(0, 120))
						break
			if code != 0 or not hits.is_empty():
				bad_runs.append("Lauf %d: Exit %d%s" % [i + 1, code, (", " + "; ".join(hits.slice(0, 3))) if not hits.is_empty() else ""])
		var ok := bad_runs.is_empty()
		if not ok:
			failed += 1
		print("RENDER-CHECK quit_%-7s %s  Klang „%s“: %d Spielstarts, Beenden über GameFlow.quit_game() – kein „leaked at exit“ (%.0f s)%s" % [
			profile, "OK    " if ok else "FEHLER", profile, RUNS, (Time.get_ticks_msec() - t0) / 1000.0,
			"" if ok else "  –  " + " | ".join(bad_runs)])
	quit(0 if failed == 0 else 1)
