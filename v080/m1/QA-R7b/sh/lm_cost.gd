extends SceneTree
## QA-R7b: what the landmarks cost at a few city arrivals (Xvfb, real renderer): the paused frame with and without the
## landmark nodes (draw calls, primitives incl. shadow passes), the live landmarks, and the main-thread time of the
## landmarks builder / backdrop over a short drive (hooks of perf_stats()).
##   xvfb-run … godot --path . --rendering-driver opengl3 … -s <this> -- --gfx-preset=deck|high

const RACE := "res://scenes/race/race.tscn"
const PLACES := [
	["hamburg_85.6_12", "kiel_hamburg", "kiel", 85.6, 12.0],
	["hamburg_77.4_22", "kiel_hamburg", "kiel", 77.4, 22.0],
	["dortmund_225_22", "bremen_dortmund", "bremen", 225.0, 22.0],
	["madrid_228_22", "burgos_madrid", "burgos", 228.0, 22.0],
	["leipzig_106.5_12", "dresden_leipzig", "dresden", 106.5, 12.0],
	["belgrad_200_22", "slavonski_brod_belgrad", "slavonski_brod", 200.0, 22.0],
	["calais_209.5_22", "bruessel_calais", "bruessel", 209.5, 22.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _info() -> Vector2i:
	return Vector2i(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	CliArgs.all().erase("graphics")
	for pl: Array in PLACES:
		var setup := {"mode": "single", "race_id": "", "stage_id": pl[1], "from_city": pl[2], "vehicle": "limousine",
			"start_world_minutes": float(pl[4]) * 60.0, "weather": "normal", "start_km": float(pl[3]), "autopilot": true,
			"autopilot_refuel": "never", "seed": 11, "gfx": "modern", "no_countdown": true, "start_speed_kmh": 50.0,
			"traffic_warmup": true}
		CliArgs.all()["gfx-sync"] = true
		var sc: Node = (load(RACE) as PackedScene).instantiate()
		sc.set("setup", setup)
		await physics_frame
		root.add_child(sc)
		var n := 0
		while not bool(sc.call("is_live")) and n < 3000:
			await process_frame
			n += 1
		for i in 20:
			await process_frame
		var r: Object = sc.get("renderer")
		paused = true
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var with := _info()
		var world: Node = r.get("world")
		var hidden: Array = []
		for c: Node in world.get_children():
			if str(c.name).begins_with("Landmark") and (c as Node3D).visible:
				(c as Node3D).visible = false
				hidden.append(c)
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		var without := _info()
		for c: Node in hidden:
			(c as Node3D).visible = true
		var b: Object = r.call("builder", "landmarks")
		var live: Array = ((b.call("snapshot") as Dictionary).get("landmarks", []) as Array) if b != null else []
		var desc: Array = []
		for e: Dictionary in live:
			desc.append("%s %s d=%.0f %s%s" % [str(e["landmark"]).get_file(), str(e["rep"]), float(e["d"]),
				"blend" if bool(e["blend"]) else "opaque", "" if bool(e["visible"]) else " unsichtbar"])
		paused = false
		# a short drive: hooks of the landmarks builder and the backdrop
		for i in 240:
			await process_frame
		var perf: Dictionary = sc.call("perf_stats")
		var ha: Dictionary = perf.get("hooks_ms_avg", {})
		var hm: Dictionary = perf.get("hooks_ms_max", {})
		print("COST %-18s draw %d -> %d (+%d)  prim %d -> %d (+%d)  live %d [%s]  landmarks %.3f/%.2f ms  backdrop %.3f/%.2f ms  render %.2f/%.1f ms" % [
			pl[0], without.x, with.x, with.x - without.x, without.y, with.y, with.y - without.y, live.size(), "; ".join(desc),
			float(ha.get("landmarks", -1.0)), float(hm.get("landmarks", -1.0)), float(ha.get("backdrop", -1.0)), float(hm.get("backdrop", -1.0)),
			float(perf.get("render_ms_avg", -1.0)), float(perf.get("render_ms_max", -1.0))])
		sc.queue_free()
		await process_frame
		await process_frame
		CliArgs.all().erase("gfx-sync")
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.get_node("Settings").call("disarm_crash_guard")
	print("COST_DONE")
	quit(0)
