extends SceneTree
## Scratch (GEO): renders the kernel's debug road (asphalt, shoulders, edge lines, terrain rings) through the real
## Camera3D set up from ChaseCamera3D, plus a top view – to look at the geometry, and to compare
## Camera3D.unproject_position() with ChaseCamera3D.project() in the live engine.
##   xvfb-run … godot --path . --rendering-driver opengl3 -s render_debug.gd -- --stage=saragossa_pau --km=198.8 --out=<prefix>
##   [--from=<city>] [--threaded] [--top-size=1600] [--details=1000]

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	var args := CliArgs.all()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND   # what the race session sets in Modern
	await process_frame
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var stage_id := str(args.get("stage", "saragossa_pau"))
	var km := float(args.get("km", 198.8))
	var out := str(args.get("out", "/tmp/debug"))
	var track: Track = null
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if args.has("from") and str(dir["from"]) != str(args["from"]):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		track = Track.new()
		track.setup(plan, cfg, net["scenery"])
		break
	if track == null:
		print("unknown stage")
		quit(1)
		return
	var proj := Fair.make_projection(cfg)
	var cam_model := Fair.make_camera(cfg, proj)
	var path := RoadPath3D.new()
	var terrain := TerrainProfile.new()
	terrain.setup(path, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
	var levels := {}
	if args.has("details"):
		levels["terrain_outer_m"] = float(args["details"])
	var st := ChunkStreamer.new()
	st.setup(path, terrain, track, cfg, levels, not args.has("threaded"))
	st.register(BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD))
	root.add_child(st)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.72, 0.8, 0.88)
	env.fog_depth_begin = 405.0
	env.fog_depth_end = 900.0
	env.fog_density = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.make_current()
	# far ground stand-in: a big plane at the lowest road of the loaded window - 4 m
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	far.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.24, 0.38, 0.2)
	far.material_override = fm
	root.add_child(far)
	var cam_z := track.km_to_z(km) - proj.cam_distance
	track.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	var cam_y := track.height_at(cam_z + proj.cam_distance) + proj.cam_height
	var view := {"camera_z": cam_z, "camera_x": float(args.get("cam-x", 0.0)), "camera_y": cam_y}
	var size := root.get_visible_rect().size      # logical pixels, like the HUD sees them
	var fr := cam_model.frustum(size)
	cam.set_frustum(float(fr["size"]), fr["offset"], float(fr["near"]), float(fr["far"]))
	cam.global_transform = cam_model.transform(view, path)
	var lo := INF
	for k in range(int(cam_z / 3.0) - 50, int(cam_z / 3.0) + 500, 8):
		lo = minf(lo, path.height(k))
	far.position = Vector3(cam.global_position.x, lo - 4.0, cam.global_position.z)
	await process_frame
	await process_frame
	# camera maths in the live engine
	var worst := 0.0
	for d: float in [12.0, 40.0, 100.0, 250.0, 600.0]:
		for x: float in [-9.0, 0.0, 5.6]:
			var w := path.world(cam_z + d, x, 0.5)
			var p := ChaseCamera3D.project(cam.global_transform, fr, size, w)
			if p.z > 1.0:
				worst = maxf(worst, Vector2(p.x, p.y).distance_to(cam.unproject_position(w)))
	# and against Arcade's formula with the constant focal length (horizon on 45 % of the height) on the road ahead
	var arcade := RoadProjection.new()
	arcade.setup(ConfigLoader.lookup(cfg, "render", {}), size)
	arcade.focal = proj.focal
	print("CAMERA3D %s km %.1f window %dx%d logical %dx%d: Camera3D.unproject_position vs ChaseCamera3D.project max %.4f px; yaw %.2f deg; horizon row %.1f; chunks %d" % [
		stage_id, km, root.size.x, root.size.y, int(size.x), int(size.y), worst, rad_to_deg(cam_model.look_yaw(path, cam_z)), arcade.horizon_y, st.chunk_count()])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "_chase.png")
	# top view: orthographic, road direction at the camera pointing up
	var a := path.heading_at(cam_z)
	var centre := path.centre_at(cam_z + 300.0)
	var top := Camera3D.new()
	root.add_child(top)
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = float(args.get("top-size", 1600.0))
	top.near = 1.0
	top.far = 4000.0
	var up := RoadPath3D.fwd_of(a)
	top.global_transform = Transform3D(Basis(RoadPath3D.right_of(a), up, Vector3.UP), Vector3(centre.x, centre.y + 1500.0, centre.z))
	top.make_current()
	env.fog_enabled = false
	far.visible = false
	env.background_color = Color(0.1, 0.1, 0.12)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "_top.png")
	print("SAVED ", out)
	st.clear()
	quit(0)
