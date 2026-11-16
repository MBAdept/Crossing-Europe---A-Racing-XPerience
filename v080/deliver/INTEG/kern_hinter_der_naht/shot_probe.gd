extends SceneTree
## Scratch (wave-0 integration, NOT part of the repository): starts the race scene as the command line describes it
## (standalone, like "godot res://scenes/race/race.tscn -- …"), but with the Modern renderer replaced by the script
## named in --probe=<absolute path> (RaceRenderers.modern_script). For pictures of the geometry kernel behind the
## real renderer seam: --graphics=modern --screenshot=<prefix> --shot-times=… work as in every race run.


func _initialize() -> void:
	var probe := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe="):
			probe = a.substr(8)
	_start.call_deferred(probe)


func _start(probe: String) -> void:
	await physics_frame
	if probe != "":
		var renderers: Variant = load("res://scripts/race/race_renderers.gd")
		(renderers as Object).set("modern_script", probe)
	root.add_child((load("res://scenes/race/race.tscn") as PackedScene).instantiate())
