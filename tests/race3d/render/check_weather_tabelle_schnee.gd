extends "res://tests/race3d/render/check_weather.gd"
## The snow rows of the weather table (R4; check_weather.gd "tabelle", check_weather_tabelle.gd has clear and rain):
## snow × hour (6:36, 12:00, 19:12, 22:00), mean luminance and contrast of the ground in Modern against Arcade.
## Same call and arguments as check_weather.gd:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_weather_tabelle_schnee.gd -- --graphics=modern --gfx-sync \
##       --audio-sync


func _initialize() -> void:
	CliArgs.all()["only"] = "tabelle"
	CliArgs.all()["tabelle-wetter"] = "snow"
	super._initialize()
