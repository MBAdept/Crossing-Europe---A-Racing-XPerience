extends SceneTree
## QA: re-measure PIPE's finding on dark tones in GL Compatibility: unshaded ALBEDO value -> display value, with the
## post path off and pinned on (Environment.adjustment_enabled), and the sum of ambient + shadowed sun.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var vals := [0.02, 0.04, 0.06, 0.08, 0.10, 0.15, 0.20, 0.30, 0.50]
	for post: bool in [false, true]:
		var sv := SubViewport.new()
		sv.size = Vector2i(vals.size() * 32, 32)
		sv.own_world_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sv)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0)
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.adjustment_enabled = post
		var we := WorldEnvironment.new()
		we.environment = env
		sv.add_child(we)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1.0
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.position = Vector3(float(vals.size()) * 0.5, 0.5, 5.0)
		sv.add_child(cam)
		for i in vals.size():
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(1, 1)
			q.mesh = qm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(float(vals[i]), float(vals[i]), float(vals[i]))
			q.material_override = m
			q.position = Vector3(float(i) + 0.5, 0.5, 0.0)
			sv.add_child(q)
		for k in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		var out: Array = []
		for i in vals.size():
			out.append(int(round(img.get_pixel(i * 32 + 16, 16).r * 255.0)))
		print("unshaded ALBEDO %s -> display %s  (adjustment_enabled %s)" % [str(vals), str(out), str(post)])
		sv.queue_free()
		await process_frame
	quit(0)
