extends SceneTree
## RINT-M3 probe (note 7): the one-time spike of the hook "landmarks" (8–14 ms in every head run of Kiel – Hamburg at
## km 73.7). --mode=drive: drive from --km at time scale --ts and print every frame whose landmarks part took over
## 1 ms, with what became live; --mode=cold: before driving, time the steps of _make() for the next landmark that is
## not live yet (cold), then _make() again (warm).

var _r: Object
var _b: Object
var _li := -1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var a: Dictionary = CliArgs.all()
	var setup := {"mode": "single", "race_id": "", "stage_id": str(a.get("stage", "kiel_hamburg")),
		"from_city": str(a.get("from", "kiel")), "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": float(a.get("km", 70.0)),
		"autopilot": true, "autopilot_refuel": "never", "seed": 7, "gfx": "modern", "no_countdown": true,
		"start_speed_kmh": 120.0, "traffic_warmup": false}
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 6000:
		await process_frame
		n += 1
	_r = sc.get("renderer")
	_b = _r.call("builder", "landmarks")
	var ids: Array = _r.get("_part_ids")
	_li = ids.find("landmarks")
	var plans: Array = _b.get("_plans")
	var cam_z := float((_r.get("view") as Dictionary).get("camera_z", 0.0))
	var tr: Object = _r.get("track")
	print("PROBE live after %d frames, camera km %.2f, landmarks part index %d" % [n, float(tr.call("z_to_km", cam_z)), _li])
	for i in plans.size():
		var p: Dictionary = plans[i]
		print("PROBE plan %d %s rep %d model %s km %.2f live %s" % [i, str(p["landmark"]), int(p["rep"]), str(p.get("model", "")),
			float(tr.call("z_to_km", float(p["z"]))), str((_b.get("_live") as Dictionary).has(i))])
	if str(a.get("mode", "drive")) == "cold":
		_cold(plans, cam_z)
	Engine.time_scale = float(a.get("ts", 4.0))
	var t_end := Time.get_ticks_msec() + int(float(a.get("secs", 150.0)) * 1000.0)
	var frames := 0
	var live_before: Array = (_b.get("_live") as Dictionary).keys()
	while Time.get_ticks_msec() < t_end:
		await process_frame
		frames += 1
		var mx: PackedInt64Array = _r.get("_part_us_max")
		var us := mx[_li] if _li >= 0 else 0
		var live_now: Array = (_b.get("_live") as Dictionary).keys()
		var added := live_now.filter(func(k: Variant) -> bool: return not live_before.has(k))
		if us > 1000 or not added.is_empty():
			var v: Dictionary = _r.get("view")
			print("PROBE frame %d km %.2f landmarks %.2f ms new %s" % [frames, float(tr.call("z_to_km", float(v.get("camera_z", 0.0)))),
				float(us) / 1000.0, str(added)])
		live_before = live_now
		if _li >= 0:
			mx[_li] = 0
			_r.set("_part_us_max", mx)
	Engine.time_scale = 1.0
	quit(0)


func _cold(plans: Array, cam_z: float) -> void:
	var lib: Object = _b.call("_lib")
	var world: Node3D = _r.get("world")
	for i in plans.size():
		var p: Dictionary = plans[i]
		if float(p["z"]) <= cam_z or (_b.get("_live") as Dictionary).has(i) or int(p["rep"]) == 0:
			continue
		var rep := int(p["rep"])
		var t0 := Time.get_ticks_usec()
		var box := AABB()
		var nsurf := 0
		if rep == 1:
			var md: Dictionary = (lib.get("models") as Dictionary).get(str(p["model"]), {})
			var reps: Array = md.get("reps", [])
			var parts: Array = lib.call("mesh_parts", str(p["model"]), str(reps[0]))
			var t1 := Time.get_ticks_usec()
			box = _b.call("parts_box", parts)
			var mats := 0
			for pv: Variant in parts:
				var part: Dictionary = pv
				if bool(part.get("shadow", false)) or bool(part.get("billboard", false)):
					continue
				var mesh: Mesh = part["mesh"]
				for si in mesh.get_surface_count():
					nsurf += 1
					var pair: Array = _b.call("model_materials", _b.call("surface_class", mesh, si), mesh.surface_get_material(si), Color.WHITE, md)
					mats += pair.size()
			var t2 := Time.get_ticks_usec()
			print("PROBE cold %d %s: mesh_parts %.3f ms (%d parts), materials %.3f ms (%d surfaces, %d mats)" % [i,
				str(p["landmark"]), float(t1 - t0) / 1000.0, parts.size(), float(t2 - t1) / 1000.0, nsurf, mats])
		var t3 := Time.get_ticks_usec()
		var tf: Transform3D = _b.call("_place", p, rep, box)
		var t4 := Time.get_ticks_usec()
		var e1: Variant = _b.call("_make", 900 + i, p, world)
		var t5 := Time.get_ticks_usec()
		var e2: Variant = _b.call("_make", 950 + i, p, world)
		var t6 := Time.get_ticks_usec()
		print("PROBE cold %d %s rep %d: _place %.3f ms, _make first %.3f ms, again %.3f ms (origin %s)" % [i, str(p["landmark"]),
			rep, float(t4 - t3) / 1000.0, float(t5 - t4) / 1000.0, float(t6 - t5) / 1000.0, str(tf.origin.round())])
		for e: Variant in [e1, e2]:
			if e != null:
				((e as Dictionary)["node"] as Node).free()
		(_b.get("_live") as Dictionary).erase(900 + i)
		(_b.get("_live") as Dictionary).erase(950 + i)
