extends "res://tests/race3d/render/check_landmarks_render.gd"
## scratch: near views of procedural landmarks (Leipzig km 106.5, Belgrade km 200.0) by day – the Modern frame, then
## only the landmark nodes (rest of the world hidden), the anchors on screen (Arcade's _prep_prop and Modern's
## world_to_screen) and the screen box of each landmark node; then the Arcade frame of the same state.

const OUT := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b/shots/"


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	CliArgs.all().erase("graphics")
	for c: Array in [["leipzig", {"stage_id": "dresden_leipzig", "from_city": "dresden", "start_km": 106.5}],
			["belgrad", {"stage_id": "slavonski_brod_belgrad", "from_city": "slavonski_brod", "start_km": 200.0}]]:
		await _case(str(c[0]), c[1])
	quit(0)


func _case(tag: String, extra: Dictionary) -> void:
	var sc: Node = await _launch("modern", extra)
	await _settle(sc)
	var r: Object = sc.get("renderer")
	paused = true
	for i in 2:
		await process_frame
	(await _grab()).save_png(OUT + "%s_modern_all.png" % tag)
	var view: Dictionary = r.get("view")
	var cam_z := float(view.get("camera_z", 0.0))
	var cam_x := float(view.get("camera_x", 0.0))
	var proj: Object = r.get("proj")
	var trk: Object = sc.get("track")
	var b: Object = r.call("builder", "landmarks")
	var plans: Array = b.get("_plans")
	var lms: Array = trk.get("landmarks")
	var focal := float(proj.get("focal"))
	var w := float((proj.get("screen") as Vector2).x)
	for li in lms.size():
		var it: Dictionary = lms[li]
		var d := float(it["z"]) - cam_z
		if d < 50.0 or d > 900.0:
			continue
		var rr: Node = (load("res://scripts/race/road_renderer.gd") as GDScript).new()
		rr.set("proj", proj)
		var pc: Array = rr.call("_prep_prop", it.duplicate())
		rr.free()
		var ax := w * 0.5 + (float(pc[3]) - cam_x) * focal / d
		var plan: Dictionary = plans[li]
		var ms: Vector3 = r.call("world_to_screen", float(it["z"]), float(plan["x"]), 0.0)
		print("ANCHOR %s %s d %.1f m: Arcade x %.1f (pc %s), Modern x %.1f y %.1f, plan x %.2f rep %s kind %s" % [tag,
			str(it["set"]), d, ax, str(pc.slice(0, 5)), ms.x, ms.y, float(plan["x"]), str(plan.get("rep")), str(plan.get("kind", ""))])
	var world: Node = r.get("world")
	for c: Node in world.get_children():
		if c is Node3D and not str(c.name).begins_with("Landmark"):
			(c as Node3D).visible = false
	await process_frame
	await process_frame
	var only := await _grab()
	only.save_png(OUT + "%s_modern_only.png" % tag)
	for c: Node in world.get_children():
		if c is Node3D and str(c.name).begins_with("Landmark"):
			(c as Node3D).visible = false
	await process_frame
	await process_frame
	var none := await _grab()
	var dd: Array = _diff(only, none)
	print("ONLY %s landmark pixels %d box %s" % [tag, int(dd[2]), str(dd[1])])
	print("LIVE %s %s" % [tag, str((b.call("snapshot") as Dictionary).get("landmarks", []))])
	await _free(sc)
	var sa: Node = await _launch("arcade", extra)
	await _settle(sa)
	paused = true
	for i in 2:
		await process_frame
	(await _grab()).save_png(OUT + "%s_arcade.png" % tag)
	await _free(sa)
