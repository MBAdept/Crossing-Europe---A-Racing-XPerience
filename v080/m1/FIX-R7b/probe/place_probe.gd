extends SceneTree
## FIX-R7b probe: placement of the live landmarks (snapshot, screen position of the node origin) at a stage point.
## Args after --: --stage-id= --from-city= --km= --hour=

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a := CliArgs.all()
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage-id", "slavonski_brod_belgrad")),
		"from_city": str(a.get("from-city", "slavonski_brod")), "vehicle": "limousine",
		"start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": "normal", "start_km": float(a.get("km", 200.0)),
		"autopilot": true, "autopilot_refuel": "never", "seed": 11, "gfx": str(a.get("mode", "modern")), "no_countdown": true,
		"start_speed_kmh": 0.0, "traffic_warmup": false}
	CliArgs.all()["no-traffic"] = true
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		await process_frame
		n += 1
	for i in 30:
		await process_frame
	var r: Object = sc.get("renderer")
	var cam: Camera3D = r.get("camera")
	var b: Object = r.call("builder", "landmarks")
	var snap: Array = (b.call("snapshot") as Dictionary).get("landmarks", [])
	var world: Node = r.get("world")
	for e: Dictionary in snap:
		var node: Node3D = world.get_node_or_null("Landmark%d" % int(e["index"]))
		var scr := cam.unproject_position(node.global_position) if node != null and not cam.is_position_behind(node.global_position) else Vector2(-1, -1)
		var top := node.global_transform * Vector3(0.0, 56.0, 0.0) if node != null else Vector3.ZERO
		var scr_top := cam.unproject_position(top) if node != null and not cam.is_position_behind(top) else Vector2(-1, -1)
		print("PROBE ", e, " screen origin ", scr, " screen axis 56 m ", scr_top, " basis det ", node.global_transform.basis.determinant() if node != null else 0.0)
	quit(0)
