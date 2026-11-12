extends "res://tests/race3d/render/check_weather.gd"
## The weather table of check_weather.gd as a file of its own (R4): weather (clear, rain, snow) × hour (6:36, 12:00,
## 19:12, 22:00), mean luminance and contrast of the ground in Modern against Arcade – 24 stage starts, too many for
## one file of tools/run_render_checks.sh next to the other weather checks (900 s per file). Same call and arguments
## as check_weather.gd:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_weather_tabelle.gd -- --graphics=modern --gfx-sync --audio-sync


func _initialize() -> void:
	CliArgs.all()["only"] = "tabelle"
	super._initialize()
