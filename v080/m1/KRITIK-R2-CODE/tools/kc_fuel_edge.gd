extends SceneTree
## KRITIK-R2-CODE: the right wheel at offsets around the right road edge, inside the first fuel lane of Kiel – Hamburg
## and 300 m before it (real Track, the feed of the tree). Prints the feed's surface_r per offset.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var gd: Node = root.get_node("GameData")
	var cfg := ConfigLoader.load_merged()
	var modern: Dictionary = ConfigLoader.lookup(cfg, "audio.modern", {})
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var plan: StagePlan = gd.call("get_stage_plan", "kiel_hamburg", "kiel")
	var l: Dictionary = plan.fuel_lanes[0]
	for where: String in ["before", "lane"]:
		var t := Track.new()
		t.setup(plan, cfg, (sc as Dictionary).get("scenery", {}))
		var z := t.km_to_z(float(l["start_km"])) + (-300.0 if where == "before" else 60.0)
		var out := {}
		for off: float in [-0.4, -0.1, 0.1, 0.3, 0.45, 0.6, 1.5]:
			var f := AudioFeed.new()
			f.setup(modern)
			f.set_vehicle_width(1.85)
			f.set_track(t, plan)
			var e: Vector2 = t.road_edges_at(z)
			var x := e.y + off - f.track_half_m
			var st := {"z": z, "x": x, "speed": 60.0, "road_left": e.x, "road_right": e.y, "shoulder_m": t.shoulder_w, "off_road": 0,
				"rail_contact": false, "weather": "normal"}
			f.update(st)
			out[str(off)] = [f.surface_r, snappedf(f.fuel_lane, 0.01), f.rumble_road, f.city, f.bridge]
		print("EDGE ", where, " ", JSON.stringify(out))
	quit(0)
