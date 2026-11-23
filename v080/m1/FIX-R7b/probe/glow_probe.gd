extends SceneTree
## FIX-R7b probe: the glow material of the Florianturm (viewport_h, camera projection) at Dortmund 22:00.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": "bremen_dortmund", "from_city": "bremen", "vehicle": "limousine",
		"start_world_minutes": 22.0 * 60.0, "weather": "normal", "start_km": 225.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0, "traffic_warmup": false}
	CliArgs.all()["no-traffic"] = true
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		await process_frame
		n += 1
	for i in 30:
		await process_frame
	var r: Object = sc.get("renderer")
	var cam: Camera3D = r.get("camera")
	print("PROBE cam fov ", cam.fov, " keep_aspect ", cam.keep_aspect, " vp ", root.get_visible_rect().size, " proj11 ",
		cam.get_camera_projection().y.y)
	var world: Node = r.get("world")
	for c: Node in world.get_children():
		if str(c.name).begins_with("Landmark"):
			for gi: Node in c.get_children():
				var mi := gi as MeshInstance3D
				if mi != null and mi.material_override is ShaderMaterial:
					var m := mi.material_override as ShaderMaterial
					var code := m.shader.code
					var kind := "glow" if code.contains("#define CE_GLOW") else ("vcol" if code.contains("#define CE_VCOL") else "other")
					print("PROBE ", c.name, " ", kind, " viewport_h=", m.get_shader_parameter("viewport_h"),
						" dist ", cam.global_position.distance_to((c as Node3D).global_position), " scale ", (c as Node3D).scale)
					if kind == "glow":
						var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
						print("PROBE uv2 ", (arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).slice(0, 12))
	quit(0)
