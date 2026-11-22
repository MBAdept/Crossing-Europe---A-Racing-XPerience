extends "res://tests/race3d/render/check_landmarks_render.gd"
## scratch: Paris km 388.7 day – the Modern frame with and without the landmark nodes, plus the live landmarks

func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	CliArgs.all().erase("graphics")
	var pair: Array = await _modern_pair({"stage_id": "luettich_paris", "from_city": "luettich", "start_km": 388.7})
	var out := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b/shots/"
	(pair[0] as Image).save_png(out + "paris_with.png")
	(pair[1] as Image).save_png(out + "paris_without.png")
	print("LIVE ", pair[2])
	quit(0)
