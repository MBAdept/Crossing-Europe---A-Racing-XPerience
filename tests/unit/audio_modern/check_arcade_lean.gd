extends SceneTree
## Guard of the start-up cost of the mode "Arcade" (v0.8.0, contract D25, Rules 1 and 4; QA of wave 0): a game that
## starts with the Arcade sound profile and drives an Arcade stage loads NOTHING of the Modern sound
## (scripts/audio/modern), of the Modern renderer (scripts/race3d) or of the model database (scripts/core/model_db.gd).
## A single typed reference in a file every start loads – "var _modern: ModernAudio" in the AudioManager did it –
## makes the engine compile the whole folder at every start.
##   godot --headless --path . -s res://tests/unit/audio_modern/check_arcade_lean.gd -- --graphics=arcade
## Started by tests/unit/audio_modern/test_modern_checks.gd in a child process (a unit test runs before the scene
## tree starts). Prints "CHECK arcade_lean OK|FEHLER …"; exit code 0 when it passes.
## This script must not name any class of those folders – naming one would load it. Scene and autoloads are accessed
## untyped (a -s script compiles before the autoloads exist).

const WATCHED: Array[String] = ["res://scripts/audio/modern", "res://scripts/race3d"]
const WATCHED_FILES: Array[String] = ["res://scripts/core/model_db.gd"]
const MODERN_AUDIO := "res://scripts/audio/modern/modern_audio.gd"
const RACE_SCENE := "res://scenes/race/race.tscn"

var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _wall0 > 60000:
		print("CHECK arcade_lean    FEHLER  nach 60 s abgebrochen")
		quit(2)
		return true
	return false


func _scripts(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_scripts(dir_path.path_join(d), out)


func _loaded(files: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for f in files:
		if ResourceLoader.has_cached(f):
			out.append(f.trim_prefix("res://scripts/"))
	return out


func _run() -> void:
	var files: Array[String] = []
	for d in WATCHED:
		_scripts(d, files)
	files.append_array(WATCHED_FILES)
	var am: Node = root.get_node_or_null("AudioManager")
	var problems: Array[String] = []
	if am == null or files.size() < 20:
		problems.append("AudioManager oder Skriptliste fehlt (%d Dateien)" % files.size())
		am = null
	# 1. after the autoloads of a start with the Arcade profile
	var at_boot: Array[String] = _loaded(files)
	if am != null and str(am.call("profile")) != "arcade":
		problems.append("Start nicht mit dem Profil Arcade (%s)" % str(am.call("profile")))
	if not at_boot.is_empty():
		problems.append("nach dem Start geladen: " + ", ".join(at_boot))
	# 2. an Arcade stage: the race scene with its renderer, HUD and sound for a few frames
	var after_stage: Array[String] = []
	var steps := 0
	if am != null:
		var sc: Node = (load(RACE_SCENE) as PackedScene).instantiate()
		sc.set("setup", {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": "limousine",
			"start_world_minutes": 720.0, "weather": "normal", "start_km": 3.0, "autopilot": true, "seed": 3, "gfx": "arcade",
			"no_countdown": true})
		root.add_child(sc)
		for i in 12:
			await process_frame
		steps = int(sc.get("_sim_steps"))
		after_stage = _loaded(files)
		if str(sc.get("gfx")) != "arcade" or steps <= 0:
			problems.append("die Arcade-Etappe lief nicht (gfx %s, %d Schritte)" % [str(sc.get("gfx")), steps])
		if not after_stage.is_empty():
			problems.append("nach einer Arcade-Etappe geladen: " + ", ".join(after_stage))
		sc.queue_free()
		await process_frame
		await process_frame
		# 3. the probe sees what it looks for: the Modern profile loads its scripts, back in Arcade nothing is left behind
		am.call("set_profile", "modern")
		await process_frame
		if not ResourceLoader.has_cached(MODERN_AUDIO) or str(am.call("profile")) != "modern":
			problems.append("mit dem Profil Modern ist modern_audio.gd nicht geladen – die Prüfung sähe nichts")
		am.call("set_profile", "arcade")
		await process_frame
	var ok := problems.is_empty()
	print("CHECK arcade_lean    %s  Start und eine Etappe (%d Schritte) mit Bild und Klang Arcade: %d von %d Skripten des Modern-Klangs, des Modern-Renderers und der Modell-Datenbank geladen%s" % [
		"OK    " if ok else "FEHLER", steps, maxi(at_boot.size(), after_stage.size()), files.size(), "" if ok else "  –  " + "; ".join(problems)])
	quit(0 if ok else 1)
