extends SceneTree
## QA lens 3: how long an Arcade stage takes to build (the synchronous part: scene load + _ready), first and second
## time in one process, plus the time of the first 30 frames. Works on v0.7.0 and the integrated tree.
const RACE := "res://scenes/race/race.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _process(_d: float) -> bool:
	return false

func _run() -> void:
	for i in 5:
		await process_frame
	var boot_us := Time.get_ticks_usec()
	var out: Array = []
	for k in 2:
		var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
			"start_world_minutes": 720.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11, "traffic_warmup": true,
			"gfx": "arcade"}
		var t0 := Time.get_ticks_usec()
		var packed: PackedScene = load(RACE)
		var sc: Node = packed.instantiate()
		sc.set("setup", setup)
		var t1 := Time.get_ticks_usec()
		await physics_frame
		var t2 := Time.get_ticks_usec()
		root.add_child(sc)
		var t3 := Time.get_ticks_usec()
		for i in 30:
			await process_frame
		var t4 := Time.get_ticks_usec()
		out.append("load+instantiate %.1f ms, add_child (_ready/_build) %.1f ms, 30 frames %.1f ms" % [(t1 - t0) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0])
		print("STAGE-TIME %d %.3f %.3f %.3f" % [k, (t1 - t0) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0])
		sc.queue_free()
		for i in 5:
			await process_frame
	print("STAGE-BOOT %.3f" % (boot_us / 1000.0))
	quit(0)
