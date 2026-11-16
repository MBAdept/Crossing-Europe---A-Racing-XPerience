extends SceneTree
## QA-M2-BILD probe (headless is enough): which props that Arcade draws near the camera does Modern leave out, and why?
## Launches a still Modern stage, then compares the items of TrackSegment.sprites of the chunks ahead of the camera
## with the props builder's placed list (debug_snapshot chunks[].parts.props.list) and prints every missing item with
## its foot (z ahead of the camera, x), set, side, the ribbon width and corridor test at its foot.
##   godot --headless --path . -s <this> -- --graphics=modern --gfx-preset=high --stage=… --from=… --km=… [--ahead=150]

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := CliArgs.all()
	root.get_node("Settings").call("disarm_crash_guard")
	a["no-traffic"] = true
	var ahead := float(a.get("ahead", 150.0))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "")), "vehicle": str(a.get("vehicle", "limousine")),
		"start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": "normal",
		"start_km": float(a.get("km", 0.0)), "autopilot": false, "seed": int(a.get("seed", 11)), "gfx": "modern",
		"no_countdown": not a.has("countdown")}
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
	var streamer: Object = r.get("streamer")
	var chunks_obj: Dictionary = streamer.get("_chunks")
	var track: Object = sc.get("track")
	print("QA-PROPS cam_z=%.1f km=%s" % [cam_z, str(a.get("km", 0))])
	for ch: Dictionary in snap["chunks"]:
		var parts: Dictionary = ch.get("parts", {})
		if not parts.has("props"):
			continue
		var pp: Dictionary = parts["props"]
		var z0 := float(int(ch["seg_a"])) * 3.0
		if z0 > cam_z + ahead or z0 + 96.0 < cam_z - 10.0:
			continue
		var placed := {}
		for e: Array in pp.get("list", []):
			placed["%d:%d" % [int(e[0]), int(e[1])]] = e
		print("QA-CHUNK index=%d seg %d..%d dropped=%s props=%d" % [int(ch["index"]), int(ch["seg_a"]), int(ch["seg_b"]),
			JSON.stringify(pp.get("dropped", {})), int(pp.get("props", 0))])
		var cobj: Object = chunks_obj.get(int(ch["index"]))
		var ctx: Object = cobj.get("ctx") if cobj != null else null
		for si in range(int(ch["seg_a"]), int(ch["seg_b"])):
			var seg: Variant = track.call("get_segment", si)
			if seg == null:
				continue
			var sprites: Array = (seg as Object).get("sprites")
			for j in sprites.size():
				var it: Dictionary = sprites[j]
				if str(it.get("kind", "prop")) != "prop":
					continue
				var z := float(it.get("z", float(si) * 3.0))
				var x := float(it.get("x", 0.0))
				if z < cam_z - 5.0 or z > cam_z + ahead:
					continue
				var key := "%d:%d" % [si, j]
				var side := int(it.get("side", 1))
				var info := ""
				if ctx != null and side != 0:
					var row := clampi(int(floor(float(ctx.call("row_of", z)))), 0, int(ctx.call("row_count")) - 1)
					var beyond := absf(x) - float(ctx.call("shoulder_edge", row, side))
					info = "beyond_shoulder=%.1f ribbon=%.1f corridor=%s" % [beyond, float(ctx.call("ribbon_width", z, side)),
						str(ctx.call("in_bend_corridor", z, x))]
				print("  %s seg=%d j=%d z=%+.1f x=%+.1f side=%d set=%s scale=%.2f %s %s" % ["OK  " if placed.has(key) else "FEHLT",
					si, j, z - cam_z, x, side, str(it.get("set", "")), float(it.get("scale", 1.0)),
					"deco" if not it.has("offset") else "event", info])
	print("QA-PROPS-END")
	Engine.time_scale = 1.0
	quit(0)
