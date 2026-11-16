extends SceneTree
## R5 scratch (not committed): draw calls and primitives of the Modern renderer at a few positions of R5's elements
## (HUD hidden, no traffic, still stage), averaged over 30 frames after the stage is prepared – for the base copy and
## the worktree alike. Run under Xvfb with --rendering-driver opengl3 … -s res://r5_scratch_counters.gd -- --gfx-preset=medium

const RACE := "res://scenes/race/race.tscn"
const POS: Array = [
	{"id": "koehlbrand_deck", "stage": "kiel_hamburg", "from": "kiel", "km": 78.2, "hour": 12.0, "seed": 11},
	{"id": "koehlbrand_rampe", "stage": "kiel_hamburg", "from": "kiel", "km": 77.4, "hour": 12.0, "seed": 11},
	{"id": "u1_portal", "stage": "bern_mailand", "from": "bern", "km": 184.4, "hour": 12.0, "seed": 16},
	{"id": "u1_innen", "stage": "bern_mailand", "from": "bern", "km": 188.0, "hour": 12.0, "seed": 16},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var cli: Dictionary = CliArgs.all()
	cli["no-traffic"] = true
	for pos: Dictionary in POS:
		await _measure(pos)
	quit(0)


func _measure(pos: Dictionary) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": str(pos["stage"]), "from_city": str(pos["from"]),
		"vehicle": "limousine", "start_world_minutes": float(pos["hour"]) * 60.0, "weather": "normal",
		"start_km": float(pos["km"]), "autopilot": false, "seed": int(pos["seed"]), "gfx": "modern", "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	var r: Variant = sc.get("renderer")
	var n := 0
	while n < 4000 and is_instance_valid(r) and not bool((r as Node).call(&"is_prepared")):
		await process_frame
		n += 1
	for i in 60:
		await process_frame
	var dc := 0.0
	var prim := 0.0
	var objs := 0.0
	for i in 30:
		await RenderingServer.frame_post_draw
		dc += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prim += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objs += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	print("COUNTERS %s draw_calls %.0f primitives %.0f objects %.0f" % [str(pos["id"]), dc / 30.0, prim / 30.0, objs / 30.0])
	sc.queue_free()
	await process_frame
	await process_frame
