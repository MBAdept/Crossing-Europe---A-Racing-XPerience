extends SceneTree
# What does the Compatibility renderer show for dark ALBEDO values of an unshaded material, and for a lit
# white-ambient surface? Compared with show(to_lin(c)): to_lin = polynomial, show = max(1.055 x^(1/2.4) - 0.055, 0).
const VALS: Array[float] = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.08, 0.1, 0.15, 0.2, 0.3, 0.5, 0.8, 1.0]

func _initialize() -> void:
	_run.call_deferred()

func _quad(x: float) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x, 0, 0), Vector3(x + 1, 0, 0), Vector3(x + 1, 1, 0), Vector3(x, 1, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi

func _to_lin(c: float) -> float:
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)

func _show(x: float) -> float:
	return maxf(1.055 * pow(maxf(x, 0.0), 0.416666667) - 0.055, 0.0)

func _strip(post: bool, lit: bool) -> Array:
	var sv := SubViewport.new()
	sv.size = Vector2i(VALS.size() * 40, 40)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = post
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 1.0
	cam.position = Vector3(float(VALS.size()) * 0.5, 0.5, 5.0)
	sv.add_child(cam)
	for i in VALS.size():
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode cull_disabled%s;\nuniform float v;\nvoid fragment() { ALBEDO = vec3(v); ROUGHNESS = 1.0; SPECULAR = 0.0; }\n" % ("" if lit else ", unshaded")
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("v", VALS[i])
		var q := _quad(float(i))
		q.material_override = m
		sv.add_child(q)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var out: Array = []
	for i in VALS.size():
		out.append(roundi(img.get_pixel(20 + i * 40, 20).r * 255.0))
	sv.queue_free()
	return out

func _run() -> void:
	var rows := {}
	rows["unshaded, no post"] = await _strip(false, false)
	rows["unshaded, post path on"] = await _strip(true, false)
	rows["lit by white ambient 1.0, post on"] = await _strip(true, true)
	var head := "%-36s" % "ALBEDO value"
	var ident := "%-36s" % "identity (value x 255)"
	var model := "%-36s" % "show(to_lin(value)) x 255"
	for v in VALS:
		head += "%6.2f" % v
		ident += "%6.1f" % (v * 255.0)
		model += "%6.1f" % (_show(_to_lin(v)) * 255.0)
	print(head)
	print(ident)
	print(model)
	for k: String in rows:
		var line := "%-36s" % k
		for x: int in rows[k]:
			line += "%6d" % x
		print(line)
	quit(0)
