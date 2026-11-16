extends SceneTree
## QA-M2-BILD probe: is a car seen later / smaller in Modern than in Arcade? (fairness, trees and terrain at bends)
## A still stage (no traffic, HUD hidden, clock stopped, the session's own render calls off); a test car (red hatch)
## is put on the road d metres ahead of the camera in each lane, the picture with the car is compared with the picture
## without it: visible pixels = pixels that change by more than 24/255 in one channel. Same script, same view, same
## cars for --graphics=arcade and --graphics=modern.
##   … -s <this> -- --graphics=modern --gfx-preset=high --gfx-sync --stage=saragossa_pau --from=saragossa --km=198.8
##       --hour=11 --vehicle=kompakt --out=<dir> --tag=<name> [--dists=40,70,100,150,200,270] [--lanes=-1,0,1]
## Prints "QA-OCC <tag> d=<m> lane=<k> px=<n> bbox=[x0,y0,x1,y1]" and saves <tag>_none.png / <tag>_d<m>_l<k>.png.

const RACE := "res://scenes/race/race.tscn"
const THR := 24.0 / 255.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := CliArgs.all()
	var mode := str(a.get("graphics", "modern"))
	var out := str(a.get("out", "/tmp"))
	var tag := str(a.get("tag", mode))
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("Settings").call("disarm_crash_guard")
	a["no-traffic"] = true
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "")), "vehicle": str(a.get("vehicle", "limousine")),
		"start_world_minutes": float(a.get("hour", 12.0)) * 60.0, "weather": str(a.get("weather", "normal")),
		"start_km": float(a.get("km", 2.0)), "autopilot": false, "seed": int(a.get("seed", 11)), "gfx": mode,
		"no_countdown": true}
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
	var base: Dictionary = (r.get("view") as Dictionary).duplicate(true)
	sc.set_process(false)
	var pl: Dictionary = base["player"]
	var cam_z := float(base["camera_z"])
	var px := float(pl.get("x", 0.0))
	var lane := 3.75
	var tr: Variant = sc.get("track")
	if tr is Object and (tr as Object).get("lane_w") != null:
		lane = float((tr as Object).get("lane_w"))
	var vis := float(base.get("visibility", -1.0))
	print("QA-OCC-BASE %s mode=%s cam_z=%.2f player_x=%.2f lane=%.2f vis=%s" % [tag, mode, cam_z, px, lane, str(vis)])
	var v0: Dictionary = base.duplicate(true)
	v0["cars"] = []
	var p0: Dictionary = (v0["player"] as Dictionary).duplicate()
	p0["visible"] = false
	v0["player"] = p0
	var none := await _shot(r, v0)
	none.save_png(out.path_join("%s_none.png" % tag))
	var dists: Array = []
	for s: String in str(a.get("dists", "40,70,100,150,200,270")).split(",", false):
		dists.append(float(s))
	var lanes: Array = []
	for s: String in str(a.get("lanes", "-1,0,1")).split(",", false):
		lanes.append(int(s))
	for d: float in dists:
		for k: int in lanes:
			var v: Dictionary = v0.duplicate(true)
			v["cars"] = [{"kind": "car", "id": 9500, "set": "traffic/hatch_red", "z": cam_z + d, "x": px + float(k) * lane,
				"length": 4.05, "tail": float(pl.get("tail", 0.0)), "brake": 0.0, "speed": 0.0, "heavy": false, "blink": 0, "blink_t": 0.0}]
			var img := await _shot(r, v)
			# counted afterwards with numpy (sh/occl_count.py): GDScript pixel loops are too slow under load
			img.save_png(out.path_join("%s_d%03d_l%d.png" % [tag, int(d), k]))
			var w: Vector3 = Vector3(-1, -1, -1)
			if r.has_method("world_to_screen"):
				w = r.call("world_to_screen", cam_z + d + 2.0, px + float(k) * lane, 0.7)
			print("QA-OCC %s d=%d lane=%d screen=[%.1f,%.1f,%.1f]" % [tag, int(d), k, w.x, w.y, w.z])
	print("QA-OCC-END")
	Engine.time_scale = 1.0
	quit(0)


func _shot(r: Node, v: Dictionary) -> Image:
	for i in 8:
		r.call("render", v)
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
