extends SceneTree
## QA-M2-BILD probe (headless): which placed props of the Modern props builder project into a screen rectangle?
##   godot --headless --path . -s <this> -- --graphics=modern --gfx-preset=high --stage=… --from=… --km=…
##       --rect=x0,y0,x1,y1 [--ahead=2000]
## Prints "QA-SCREEN set=… z=… x=… dist=… foot=[px,py] top10=[px,py]" for every placed prop whose foot or the point
## 10 m above it falls into the rectangle (logical 1280x720 pixels).

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := CliArgs.all()
	root.get_node("Settings").call("disarm_crash_guard")
	a["no-traffic"] = true
	var ahead := float(a.get("ahead", 2000.0))
	var rc := str(a.get("rect", "0,0,1280,720")).split(",")
	var rect := Rect2(float(rc[0]), float(rc[1]), float(rc[2]) - float(rc[0]), float(rc[3]) - float(rc[1]))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "")), "vehicle": str(a.get("vehicle", "limousine")),
		"start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": "normal",
		"start_km": float(a.get("km", 0.0)), "autopilot": false, "seed": int(a.get("seed", 11)), "gfx": "modern",
		"no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 3 and n < 6000:
		await process_frame
		n += 1
	Engine.time_scale = 0.0
	for i in 5:
		await process_frame
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view["camera_z"])
	var snap: Dictionary = r.call("debug_snapshot")
	print("QA-SCREEN-BASE cam_z=%.1f rect=%s chunks=%d" % [cam_z, str(rect), (snap["chunks"] as Array).size()])
	for ch: Dictionary in snap["chunks"]:
		var parts: Dictionary = ch.get("parts", {})
		for bid: String in parts:
			var pp: Dictionary = parts[bid]
			if not pp.has("list"):
				continue
			for e: Array in pp.get("list", []):
				if e.size() < 5:
					continue
				var x := float(e[3])
				var z := float(e[4])
				if z < cam_z or z > cam_z + ahead:
					continue
				var f: Vector3 = r.call("world_to_screen", z, x, 0.0)
				var t: Vector3 = r.call("world_to_screen", z, x, 10.0)
				if rect.has_point(Vector2(f.x, f.y)) or rect.has_point(Vector2(t.x, t.y)):
					print("QA-SCREEN %s set=%s z=%.1f x=%.1f dist=%.0f foot=[%.0f,%.0f] top10=[%.0f,%.0f] scale=%s" % [bid, str(e[2]),
						z, x, z - cam_z, f.x, f.y, t.x, t.y, str(e[5])])
	print("QA-SCREEN-END")
	Engine.time_scale = 1.0
	quit(0)
