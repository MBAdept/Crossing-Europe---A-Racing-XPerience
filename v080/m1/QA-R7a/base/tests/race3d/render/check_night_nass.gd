extends "res://tests/race3d/render/check_night.gd"
## FIX-R4: the wet night of check_night.gd as a file of its own – "nass_kegel" (the low beam on the wet road against
## Arcade, QA-R4 B2) and "spiegelung" (the reflections of a far car's lamps lie on a climbing road, QA-R4 B1), so that
## check_night.gd stays inside tools/run_render_checks.sh's time per file. RINT-M2: "laternen" (the static lamps'
## reflections follow the road on a real climb, Kassel – Würzburg km 61.6, NACH-R4 N2). Same call and arguments as check_night.gd:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_night_nass.gd -- --graphics=modern --gfx-sync --audio-sync


func _initialize() -> void:
	if not CliArgs.all().has("only"):
		CliArgs.all()["only"] = "nass_kegel,spiegelung,laternen"
	super._initialize()
