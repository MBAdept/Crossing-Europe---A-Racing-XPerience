extends SceneTree
## RINT-A measurement (not part of the repo): the player car at S1 in three reflection variants –
##   both     as merged: the rig's Sky reflection (Environment.reflected_light_source = SKY) + R3's analytic sky (env_energy)
##   engine   only the rig's Sky (env_energy 0 on vpbr and glass)
##   analytic only R3's analytic sky (the rig's reflections switched off for the whole picture)
## Pictures: <out>/<tag>_<variant>.png, crop of the car <out>/<tag>_<variant>_car.png. Args: --out=<abs dir> --hour=<h>
## --tag=<name> [--gfx-preset=...]

const RACE := "res://scenes/race/race.tscn"

var _out := ""
var _hour := 12.0
var _tag := "s1"


func _initialize() -> void:
	var cli: Dictionary = (load("res://scripts/core/cli_args.gd") as GDScript).call("all") if false else {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--hour="):
			_hour = float(a.substr(7))
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
	_run.call_deferred()


func _launch() -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": _hour * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false, "gfx": "modern"}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	return sc


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var cliargs: Variant = root.get_node_or_null("/root/CliArgs")
	if cliargs != null:
		(cliargs.call("all") as Dictionary)["no-traffic"] = true
	for variant: String in ["both", "engine", "analytic"]:
		var sc: Node = await _launch()
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
		var mats: Object = r.get("materials")
		var env: Object = r.get("env")
		var environment: Environment = env.get("environment")
		match variant:
			"engine":
				mats.call("set_class_parameter", "vpbr", "env_energy", 0.0)
				mats.call("set_class_parameter", "glass", "env_energy", 0.0)
			"analytic":
				environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		r.call("render", r.get("view"))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(_out.path_join("%s_%s.png" % [_tag, variant]))
		var p: Vector3 = r.call("world_to_screen", float(r.get("view")["player"]["z"]) + 2.3, float(r.get("view")["player"]["x"]), 0.75)
		var crop := img.get_region(Rect2i(clampi(int(p.x) - 150, 0, img.get_width() - 300), clampi(int(p.y) - 130, 0, img.get_height() - 220), 300, 220))
		crop.save_png(_out.path_join("%s_%s_car.png" % [_tag, variant]))
		# undo the variant on the shared material (it outlives the scene)
		mats.call("set_class_parameter", "vpbr", "env_energy", 1.6)
		mats.call("set_class_parameter", "glass", "env_energy", 2.2)
		sc.queue_free()
		await process_frame
		await process_frame
	print("REFL done")
	quit(0)
