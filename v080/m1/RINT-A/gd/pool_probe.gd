extends SceneTree
## RINT-A: where are the light pools of the lamps? S4 at 22:00, headless. Prints the first pools, the camera and the
## pool uniforms of the registered materials.

const RACE := "res://scenes/race/race.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 22.0 * 60.0, "weather": "normal", "start_km": 80.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 50.0, "traffic_warmup": true, "gfx": "modern"}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) < 60 and n < 3000:
		await process_frame
		n += 1
	var r: Object = sc.get("renderer")
	var cam: Camera3D = r.get("camera")
	print("RINT camera ", cam.global_position)
	var lights: Object = r.call("layer", "lights")
	var pos: PackedVector4Array = lights.get("_pool_pos")
	var col: PackedVector4Array = lights.get("_pool_col")
	var cnt := int(lights.get("_pool_count"))
	for i in mini(cnt, 6):
		print("RINT pool %d pos %s col %s" % [i, str(pos[i]), str(col[i])])
	print("RINT ambient ", lights.get("_ambient"))
	var statics: Array = lights.get("_statics")
	var parents := {}
	for pair: Array in statics:
		var p: Object = pair[0]
		parents[p.get_instance_id()] = int(parents.get(p.get_instance_id(), 0)) + (pair[1] as Array).size()
	print("RINT statics groups %d, distinct parents %d" % [statics.size(), parents.size()])
	for m: Variant in r.call("pool_materials"):
		var sm := m as ShaderMaterial
		print("RINT material %s pool_count %s pool_ambient %s" % [sm.shader.resource_path.get_file(), str(sm.get_shader_parameter("pool_count")),
			str(sm.get_shader_parameter("pool_ambient"))])
	quit(0)
