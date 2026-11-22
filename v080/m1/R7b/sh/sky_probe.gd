extends "res://tests/race3d/render/check_landmarks_render.gd"
## scratch: the backdrop alone (3D world hidden) at Kassel (Herkules skyline) and Paris (Sacré-Cœur, Eiffel)

func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	CliArgs.all().erase("graphics")
	var out := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b/shots/"
	for c: Array in [["kassel", {"stage_id": "hannover_kassel", "from_city": "hannover", "start_km": 148.5}],
			["paris", {"stage_id": "luettich_paris", "from_city": "luettich", "start_km": 376.0}],
			["kassel22", {"stage_id": "hannover_kassel", "from_city": "hannover", "start_km": 148.5, "start_world_minutes": 22.0 * 60.0}]]:
		var sc: Node = await _launch("modern", c[1])
		await _settle(sc)
		var r: Object = sc.get("renderer")
		paused = true
		(r.get("world") as Node3D).visible = false
		for i in 3:
			await process_frame
		var img := await _grab()
		img.save_png(out + "sky_%s.png" % c[0])
		var bd: Object = r.call("layer", "backdrop")
		print("SKY %s %s" % [c[0], str(((bd.call("snapshot") as Dictionary).get("backdrop", {}) as Dictionary).get("skyline"))])
		await _free(sc)
	quit(0)
