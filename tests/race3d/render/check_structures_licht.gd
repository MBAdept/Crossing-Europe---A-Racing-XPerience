extends "res://tests/race3d/render/check_structures.gd"
## Render check of the structures of the mode "Modern", second part (R6): the checks with light and shadow – the fuel
## stop by day and at night against Arcade, the street lights of the City Limits at night against Arcade, the shadow
## rule of the structure builders. Same helpers, arguments and output as check_structures.gd (which this file
## extends); split off so that each file stays within RENDER_CHECK_TIMEOUT on a busy llvmpipe machine:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_structures_licht.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Owner: R6 (wave 3).


func checks() -> Array:
	return ["tankstelle", "stadt", "schatten"]
