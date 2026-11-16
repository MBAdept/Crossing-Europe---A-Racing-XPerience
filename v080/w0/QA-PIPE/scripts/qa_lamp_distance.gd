extends SceneTree
## QA: does the lit head of the street light survive Godot's automatic mesh levels at distance? Game camera
## (focal 711 px at 1280x720), night, one street light per picture at increasing distances.
## --auto-lod=0 uses the same mesh with its automatic levels removed (control).
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var control := OS.get_cmdline_user_args().has("--auto-lod=0")
	var mats := ModernMaterials.new()
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	var near := 1.0
	var fsize := near * 720.0 / 711.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.set_frustum(fsize, Vector2(0.0, -0.05 * fsize), near, 2600.0)
	cam.position = Vector3(0.0, 3.4, 0.0)
	sv.add_child(cam)
	ModernMaterials.set_global("ce_night", 1.0)
	var node := ModelFactory.build("props/streetlight", "lod0", mats)
	sv.add_child(node)
	var mi := node.get_node("body") as MeshInstance3D
	if control:
		# the same vertices and LOD0 indices without the automatic levels
		var src: ArrayMesh = mi.mesh
		var plain := ArrayMesh.new()
		plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(0), [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		plain.surface_set_material(0, mats.material("vpbr"))
		mi.mesh = plain
	print("mesh_lod_threshold of the viewport: %.2f px, automatic levels: %s" % [sv.mesh_lod_threshold, "removed (control)" if control else "as baked"])
	for dist: float in [100.0, 200.0, 300.0, 400.0, 425.0, 445.0, 500.0, 600.0, 800.0]:
		node.position = Vector3(6.0, 0.0, -dist)
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		# predicted position of the lamp head (model point -1.97, 9.24, 0)
		var px := 640.0 + 711.0 * (6.0 - 1.97) / dist
		var py := 324.0 - 711.0 * (9.24 - 3.4) / dist
		var lit := 0
		var peak := 0.0
		for y in range(int(py) - 6, int(py) + 7):
			for x in range(int(px) - 8, int(px) + 9):
				var c := img.get_pixel(clampi(x, 0, 1279), clampi(y, 0, 719))
				var l := c.get_luminance()
				peak = maxf(peak, l)
				if l > 0.5:
					lit += 1
		print("street light at %4.0f m: lamp head expected at (%.0f, %.0f), about %.1f px wide: bright pixels %3d, peak luminance %.2f" % [dist, px, py, 711.0 * 0.57 / dist, lit, peak])
	quit(0)
