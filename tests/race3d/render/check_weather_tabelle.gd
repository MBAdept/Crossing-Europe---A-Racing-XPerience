extends "res://tests/race3d/render/check_weather.gd"
## The weather table of check_weather.gd as files of its own (R4): weather × hour (6:36, 12:00, 19:12, 22:00), mean
## luminance and contrast of the ground in Modern against Arcade – this file clear and rain (16 stage starts),
## check_weather_tabelle_schnee.gd snow (8): all 24 took 933 s at load 20, more than tools/run_render_checks.sh gives
## one file (900 s). Same call and arguments as check_weather.gd:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_weather_tabelle.gd -- --graphics=modern --gfx-sync --audio-sync


func _initialize() -> void:
	CliArgs.all()["only"] = "tabelle"
	CliArgs.all()["tabelle-wetter"] = "normal,rain"
	super._initialize()
