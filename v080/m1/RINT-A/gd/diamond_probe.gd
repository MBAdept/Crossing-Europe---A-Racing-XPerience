extends SceneTree
## RINT-A measurement: what are the bright patches at the horizon of S1? Renders the frozen frame of step 30 three
## times: as is, with the props' contact shadows hidden, with the impostor nodes hidden. --out=<abs dir> --km=<km>

const RACE := "res://scenes/race/race.tscn"

var _out := ""
var _km := 2.0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--km="):
			_km = float(a.substr(5))
	_run.call_deferred()


func _walk(n: Node, cb: Callable) -> void:
	cb.call(n)
	for c: Node in n.get_children():
		_walk(c, cb)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var cliargs: Variant = root.get_node_or_null("/root/CliArgs")
	if cliargs != null:
		(cliargs.call("all") as Dictionary)["no-traffic"] = true
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": _km, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": "modern"}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 30 and n < 4000:
		await process_frame
		n += 1
	sc.set_process(false)
	sc.set_physics_process(false)
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false
	var r: Object = sc.get("renderer")
	var world: Node = r.get("world")
	var counts := {"contact": 0, "impostor": 0}
	for variant: String in ["as_is", "no_contact", "no_impostor"]:
		_walk(world, func(x: Node) -> void:
			if x is GeometryInstance3D:
				var g := x as GeometryInstance3D
				if x.name == &"Contact":
					g.set_meta(&"keep_vis", g.visible) if not g.has_meta(&"keep_vis") else null
					g.visible = variant != "no_contact" and bool(g.get_meta(&"keep_vis", true))
					if variant == "as_is":
						counts["contact"] += 1
				elif str(x.get_meta(&"rep", "")) == "impostor":
					g.set_meta(&"keep_vis2", g.visible) if not g.has_meta(&"keep_vis2") else null
					g.visible = variant != "no_impostor" and bool(g.get_meta(&"keep_vis2", true))
					if variant == "as_is":
						counts["impostor"] += 1)
		r.call("render", r.get("view"))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(_out.path_join("km%s_%s.png" % [str(_km), variant]))
	print("RINT diamonds: contact nodes %d, impostor nodes %d" % [counts["contact"], counts["impostor"]])
	quit(0)
