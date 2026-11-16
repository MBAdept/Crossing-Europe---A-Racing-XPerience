extends SceneTree
## Scratch (R1a): does a shadow caster darken the UNSHADED debug road? One box above the bare road, the picture with
## and without it, compared where its shadow would fall. Run under Xvfb with --fixed-fps 60.
## -- --shot=<abs prefix> keeps the two pictures.

const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe: GDScript = load("res://tests/race3d/fixtures/facade_probe_renderer.gd")
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	probe.call("reset")
	probe.set("bare", true)
	renderers.set("modern_script", "res://tests/race3d/fixtures/facade_probe_renderer.gd")
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11, "gfx": "modern",
		"no_countdown": true})
	await physics_frame
	root.add_child(sc)
	(sc.get("hud") as Control).visible = false
	var n := 0
	while int(sc.get("_sim_steps")) < 5 and n < 2000:
		await process_frame
		n += 1
	var r: ModernRenderer = sc.get("renderer")
	var env_node: Node = r.get("_environment")
	var to_sun: Vector3 = (env_node.get("state") as Dictionary)["to_sun"]
	var cam_z := float(r.view["camera_z"])
	# where the shadow of the box falls: on the bare road, 22 m ahead on the camera's axis
	var ground := r.path.frame_at(cam_z + 22.0, float(r.view["camera_x"]), 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.38, 0.38)
	var box := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(1.8, 1.8, 1.8)
	box.mesh = cube
	box.material_override = mat
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	r.world.add_child(box)
	box.global_transform = Transform3D(ground.basis, ground.origin + to_sun * (2.6 / to_sun.y))
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var with_box: Image = root.get_texture().get_image()
	box.queue_free()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var without: Image = root.get_texture().get_image()
	var px := r.camera.unproject_position(ground.origin)
	var x := int(px.x)
	var y := int(px.y)
	var a := with_box.get_pixel(x, y)
	var b := without.get_pixel(x, y)
	# the box itself is beyond the shadow point as the camera sees it: count differing pixels in a window around the
	# shadow point that stays clear of the box (rows below the point = nearer road)
	var diff := 0
	var total := 0
	for dy in range(0, 16):
		for dx in range(-40, 41):
			total += 1
			if with_box.get_pixel(x + dx, y + dy) != without.get_pixel(x + dx, y + dy):
				diff += 1
	print("SCHATTEN Punkt %d,%d: mit Kasten %s, ohne %s; Fenster 81x16 darunter: %d von %d Pixeln verschieden; Sonne %s, shadow_enabled %s" % [
		x, y, a.to_html(false), b.to_html(false), diff, total, str(to_sun), str((env_node.get("sun") as DirectionalLight3D).shadow_enabled)])
	var shot := str(CliArgs.all().get("shot", ""))
	if shot != "":
		with_box.save_png(shot + "_mit.png")
		without.save_png(shot + "_ohne.png")
	sc.queue_free()
	await process_frame
	await process_frame
	ModernMaterials.drop_shared()
	quit(0)
