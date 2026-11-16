extends SceneTree
## R3 scratch (not in the repo): one picture of a still race scene with placed vehicles, in either mode – the halves
## of A/B pictures of situations traffic does not produce on demand (lamps at fixed distances, trucks side by side,
## signs just ahead). Same stage, start, hour and cars in both runs; the world clock stands still.
##   xvfb-run … godot --path . --fixed-fps 60 -s <this> -- --mode=arcade|modern --out=<png> --stage=kiel_hamburg
##       --from=kiel --km=2 --hour=12 --weather=normal --vehicle=limousine --cars=<json file> [--gfx-preset=medium]
## cars json: [{"set", "dist" (m ahead of the camera, rear), "lane" (m beside the player), "tail", "brake",
## "blink", "blink_t", "beacon", "speed"}]; "tail": -1 = the lights of the palette.

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"
const ARCADE_INJECT := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3/probe/arcade_inject.gd"


func _initialize() -> void:
	_run.call_deferred()


func _arg(n: String, d: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--" + n + "="):
			return a.substr(n.length() + 3)
	return d


func _run() -> void:
	var mode := _arg("mode", "modern")
	var out := _arg("out", "/tmp/x.png")
	var cars_spec: Array = []
	var cf := _arg("cars", "")
	if cf != "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cf))
		if parsed is Array:
			cars_spec = parsed
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	cli["no-traffic"] = true
	cli.erase("graphics")
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	var probe: GDScript = load(PROBE)
	renderers.set("modern_script", PROBE)
	var setup := {"mode": "single", "race_id": "", "stage_id": _arg("stage", "kiel_hamburg"), "from_city": _arg("from", "kiel"),
		"vehicle": _arg("vehicle", "limousine"), "start_world_minutes": float(_arg("hour", "12")) * 60.0, "weather": _arg("weather", "normal"),
		"start_km": float(_arg("km", "2")), "autopilot": false, "seed": int(_arg("seed", "11")), "gfx": mode, "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	if mode == "arcade":
		var old: Node = sc.get("renderer")
		var nr: Node = (load(ARCADE_INJECT) as GDScript).new()
		sc.set("renderer", nr)
		sc.add_child(nr)
		sc.move_child(nr, 0)
		nr.call("setup", sc.get("track"), sc.get("proj"), sc.get("cfg"), root.get_node("GameData").get("scenery"))
		old.queue_free()
	var n := 0
	while int(sc.get("_sim_steps")) < 5 and n < 3000:
		await process_frame
		n += 1
	if _arg("hud", "0") != "1":
		(sc.get("hud") as Control).visible = false   # "LOS!" and the start lights would cover the middle
	Engine.time_scale = 0.0
	await process_frame
	# camera position of the frame: the session's own numbers (the same in both modes)
	var vs: Dictionary = sc.call("view_state")
	var proj: RoadProjection = sc.get("proj")
	var vz := float(vs["pos_z"])
	var cam_z := vz - proj.cam_distance
	var px := float(vs["x"])
	var pal := Palette.compute(float(_arg("hour", "12")), _arg("weather", "normal"), ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	var lights := float(pal.get("lights", 0.0))
	var cars: Array = []
	var i := 0
	for c: Dictionary in cars_spec:
		var sid := str(c["set"])
		var len_m := float(ModelDB.object_size(sid).get("length_m", 4.6)) if ModelDB.object_size(sid).has("length_m") else 4.6
		var sp: Variant = (root.get_node("SpriteDB").get("sets") as Dictionary).get(sid, {})
		if sp is Dictionary and (sp as Dictionary).has("object"):
			len_m = float(((sp as Dictionary)["object"] as Dictionary).get("length_m", len_m))
		var tail := float(c.get("tail", 0.0))
		cars.append({"kind": "car", "id": 8000 + i, "set": sid, "z": cam_z + float(c["dist"]), "x": px + float(c.get("lane", 0.0)),
			"length": len_m, "tail": lights if tail < 0.0 else tail, "brake": float(c.get("brake", 0.0)), "speed": float(c.get("speed", 0.0)),
			"blink": int(c.get("blink", 0)), "blink_t": float(c.get("blink_t", 0.1)), "beacon": str(c.get("beacon", "")),
			"heavy": len_m > 7.0})
		i += 1
	if mode == "arcade":
		var s: GDScript = load(ARCADE_INJECT)
		s.set("inject", cars)
	else:
		probe.set("inject", cars)
	for f in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("gespeichert ", out, "  (", mode, ", ", cars.size(), " Autos)")
	Engine.time_scale = 1.0
	probe.call("reset")
	renderers.set("modern_script", str(renderers.get("MODERN_SCRIPT")))
	quit(0)
