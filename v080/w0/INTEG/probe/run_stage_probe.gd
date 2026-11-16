extends "res://tests/race/run_stage.gd"
## Scratch runner of the wave-0 integration (NOT part of the repository): tests/race/run_stage.gd, with the Modern
## renderer replaced by the script named in --probe=<absolute path> (RaceRenderers.modern_script, the hook the seam
## checks use). Everything else – stage, autopilot, output lines – is run_stage.gd.
##   godot --headless --path . -s <this file> -- --stage=… --graphics=modern --probe=<kernel_probe_renderer.gd>
## RaceRenderers is reached untyped at run time: this script compiles before the autoloads exist, and the factory
## depends on scripts that name autoloads.


func _initialize() -> void:
	var probe := CliArgs.get_string("probe", "")
	if probe != "":
		var renderers: Variant = load("res://scripts/race/race_renderers.gd")
		(renderers as Object).set("modern_script", probe)
		print("PROBE ", probe, " (vorhanden: ", ResourceLoader.exists(probe), ", gesetzt: ", (renderers as Object).get("modern_script") == probe, ")")
	super._initialize()
