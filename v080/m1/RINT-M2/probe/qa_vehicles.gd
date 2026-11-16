extends SceneTree
## QA-M2-BILD probe: vehicles of both graphics modes in the SAME view. A still stage (no traffic, no autopilot, HUD
## hidden, world clock stopped); the session's own render calls are switched off and this script hands the renderer
## the session's last view plus injected test cars (dictionaries as the session builds them). Same script, same
## view, same cars for --graphics=arcade and --graphics=modern.
##   xvfb-run … godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -s <this> -- \
##       --graphics=modern --gfx-preset=medium --gfx-sync --out=<dir> --tag=<name> [--hour=12] [--weather=normal]
##       [--vehicle=limousine] [--km=2] [--only=player,player30,d20,d60,d150]
## Pictures <out>/<tag>_<scene>.png; prints "QA-VEH <scene> {cam_z, x, cars:[…]}" per picture.

const RACE := "res://scenes/race/race.tscn"

var _args := {}
var _sizes := {}


func _initialize() -> void:
	_run.call_deferred()


func _len(set_id: String) -> float:
	var e: Variant = _sizes.get(set_id, {})
	if e is Dictionary:
		return float(((e as Dictionary).get("object", {}) as Dictionary).get("length_m", 4.7))
	return 4.7


func _run() -> void:
	_args = CliArgs.all()
	var mode := str(_args.get("graphics", "modern"))
	var out := str(_args.get("out", "/tmp"))
	var tag := str(_args.get("tag", mode))
	var hour := float(_args.get("hour", 12.0))
	var only := str(_args.get("only", ""))
	DirAccess.make_dir_recursive_absolute(out)
	var mf := FileAccess.open("res://assets/sprites/manifest.json", FileAccess.READ)
	_sizes = (JSON.parse_string(mf.get_as_text()) as Dictionary).get("sets", {})
	root.get_node("Settings").call("disarm_crash_guard")
	_args["no-traffic"] = true
	var setup := {"mode": "single", "race_id": "", "stage_id": str(_args.get("stage", "kiel_hamburg")),
		"from_city": str(_args.get("from", "kiel")), "vehicle": str(_args.get("vehicle", "limousine")),
		"start_world_minutes": hour * 60.0, "weather": str(_args.get("weather", "normal")),
		"start_km": float(_args.get("km", 2.0)), "autopilot": false, "seed": 11, "gfx": mode, "no_countdown": true}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	var n := 0
	while int(sc.get("_sim_steps")) < 5 and n < 6000:
		await process_frame
		n += 1
	Engine.time_scale = 0.0
	for i in 3:
		await process_frame
	var r: Node = sc.get("renderer")
	if _args.has("depth_eps"):
		var fm: Object = (r.get("materials") as Object).call("material", "flare")
		fm.set("shader_parameter/depth_eps", float(_args["depth_eps"]))
		print("QA-DBG depth_eps=", fm.get("shader_parameter/depth_eps"))
	if _args.has("flare_strength"):
		var fm2: Object = (r.get("materials") as Object).call("material", "flare")
		fm2.set("shader_parameter/strength", float(_args["flare_strength"]))
		print("QA-DBG flare strength=", fm2.get("shader_parameter/strength"))
	var base: Dictionary = (r.get("view") as Dictionary).duplicate(true)
	sc.set_process(false)
	var pl: Dictionary = base["player"]
	var cam_z := float(base["camera_z"])
	var px := float(pl.get("x", 0.0))
	var lane := 3.75
	var tr: Variant = sc.get("track")
	if tr is Object and (tr as Object).get("lane_w") != null:
		lane = float((tr as Object).get("lane_w"))
	var lights := float(pl.get("tail", 0.0))
	print("QA-VEH-BASE mode=%s cam_z=%.2f player_x=%.2f lane=%.2f lights=%.2f set=%s" % [mode, cam_z, px, lane, lights, str(pl.get("set", ""))])
	var scenes := {}
	# the player car as the chase camera sees it (rear about 6.6 m ahead), braking
	scenes["player"] = {"cars": [], "player": {"brake": 1.0}}
	scenes["player_nobrake"] = {"cars": [], "player": {}}
	# the player's own model 30 m ahead (player hidden)
	scenes["player30"] = {"cars": [_car(9001, str(pl.get("set", "player/limousine")), cam_z + 30.0, px, lights, {"brake": 1.0})],
		"player": {"visible": false}}
	# traffic: three cars side by side (left lane blinks left, own lane brakes, right lane tail only)
	var rows := {"a": ["traffic/hatch_red", "traffic/sedan_silver", "traffic/suv_white"],
		"b": ["traffic/van_white", "traffic/truck_red", "traffic/bus_blue"],
		"c": ["police/de", "traffic/sports_yellow", "traffic/wagon_darkblue"]}
	for d: float in [20.0, 60.0, 150.0]:
		for k: String in rows:
			var sets: Array = rows[k]
			var cars: Array = []
			cars.append(_car(9100, sets[0], cam_z + d, px - lane, lights, {"blink": -1, "blink_t": 0.1, "beacon": "a" if str(sets[0]).begins_with("police/") else ""}))
			cars.append(_car(9101, sets[1], cam_z + d, px, lights, {"brake": 1.0}))
			cars.append(_car(9102, sets[2], cam_z + d, px + lane, lights, {}))
			scenes["d%d%s" % [int(d), k]] = {"cars": cars, "player": {"visible": false}}
	# QA-M2-BILD: the lod0 <-> lod1 swap of the "Mittel" preset at 40 m (hysteresis ±5 %): white and light cars just
	# inside (37 m: lod0) and just outside (43 m: lod1) – what a car hovering at 40 m flips between
	var rows_w := {"w": ["traffic/hatch_white", "traffic/wagon_white", "traffic/suv_white"],
		"v": ["traffic/van_white", "traffic/sedan_silver", "traffic/wagon_silver"]}
	for d: float in [37.0, 43.0]:
		for k: String in rows_w:
			var sets_w: Array = rows_w[k]
			var cars_w: Array = []
			cars_w.append(_car(9200, sets_w[0], cam_z + d, px - lane, lights, {}))
			cars_w.append(_car(9201, sets_w[1], cam_z + d, px, lights, {}))
			cars_w.append(_car(9202, sets_w[2], cam_z + d, px + lane, lights, {}))
			scenes["d%d%s" % [int(d), k]] = {"cars": cars_w, "player": {"visible": false}}
	if _args.has("eye_spec"):
		var mats: Object = r.get("materials")
		mats.call("set_class_parameter", "vpbr", "eye_lamp_spec", float(_args["eye_spec"]))
		mats.call("set_class_parameter", "glass", "eye_lamp_spec", float(_args["eye_spec"]))
		print("QA-DBG eye_spec=", _args["eye_spec"])
	if _args.has("spot_spec") or _args.has("spot_k"):
		var ll: Object = r.call("layer", "lights")
		for sp: SpotLight3D in ll.get("spots"):
			if _args.has("spot_spec"):
				sp.light_specular = float(_args["spot_spec"])
		print("QA-DBG spot_spec=", _args.get("spot_spec", "-"))
	for name: String in scenes:
		if only != "" and not only.split(",").has(name.rstrip("abc")) and not only.split(",").has(name):
			continue
		var sd: Dictionary = scenes[name]
		var v: Dictionary = base.duplicate(true)
		v["cars"] = sd["cars"]
		var p2: Dictionary = (v["player"] as Dictionary).duplicate()
		p2.merge(sd["player"], true)
		v["player"] = p2
		for i in 8:
			r.call("render", v)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("%s_%s.png" % [tag, name]))
		var info := []
		for c: Dictionary in sd["cars"]:
			var s := {"set": c["set"], "z": c["z"] - cam_z, "x": c["x"] - px}
			if mode == "modern" and r.has_method("world_to_screen"):
				var w: Vector3 = r.call("world_to_screen", float(c["z"]) + float(c["length"]) * 0.5, float(c["x"]), 0.7)
				s["screen"] = [snappedf(w.x, 0.1), snappedf(w.y, 0.1), snappedf(w.z, 0.1)]
			info.append(s)
		print("QA-VEH %s %s" % [name, JSON.stringify(info)])
		if mode == "modern" and _args.has("flaredump"):
			var vl: Object = r.call("layer", "vehicles")
			var fn := int(vl.get("_flare_n"))
			var fb: PackedFloat32Array = vl.get("_flares")
			var lines := []
			for fi in fn:
				var o := fi * 20
				var wp := Vector3(fb[o + 3], fb[o + 7], fb[o + 11])
				lines.append("pos=(%.2f,%.2f,%.2f) col=(%.2f,%.2f,%.2f) s=%.3f k=%.3f min=%.1f kind=%.0f r=%.3f" % [wp.x, wp.y, wp.z,
					fb[o + 12], fb[o + 13], fb[o + 14], fb[o + 15], fb[o + 16], fb[o + 17], fb[o + 18], fb[o + 19]])
			print("QA-FLARES %s n=%d\n  %s" % [name, fn, "\n  ".join(lines)])
	if mode == "modern" and r.has_method("debug_snapshot"):
		var snap: Dictionary = r.call("debug_snapshot")
		print("QA-VEH-SNAP ", JSON.stringify(snap.get("vehicles", [])).left(3000))
	print("QA-VEH-END")
	Engine.time_scale = 1.0
	quit(0)


func _car(id: int, set_id: String, z: float, x: float, lights: float, extra: Dictionary) -> Dictionary:
	var c := {"kind": "car", "id": id, "set": set_id, "z": z, "x": x, "length": _len(set_id), "tail": lights,
		"brake": 0.0, "speed": 0.0, "heavy": set_id.contains("truck") or set_id.contains("bus"), "blink": 0, "blink_t": 0.0}
	c.merge(extra, true)
	if str(c.get("beacon", "")) == "":
		c.erase("beacon")
	return c
