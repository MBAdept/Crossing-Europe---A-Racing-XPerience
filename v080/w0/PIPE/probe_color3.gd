extends SceneTree
# Colour space truth table for the Compatibility renderer: constants, vertex colours, vertex alpha; lit by white ambient 1.0
func _initialize() -> void:
	_run.call_deferred()

func _quad(col: Color, x: float) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x, 0, 0), Vector3(x + 1, 0, 0), Vector3(x + 1, 1, 0), Vector3(x, 1, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([col, col, col, col])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi

func _sh(body: String, unshaded: bool) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode cull_disabled%s;\nuniform vec3 uc : source_color = vec3(0.62, 0.3, 0.1);\nvoid fragment() { %s ROUGHNESS = 1.0; SPECULAR = 0.0; METALLIC = 0.0; }\n" % [", unshaded" if unshaded else "", body]
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _run() -> void:
	var with_env := OS.get_cmdline_user_args().has("--env")
	var sv: Window = root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = with_env
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(8, 0.5, 5)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	sv.add_child(cam)
	var names := []
	var mats := []
	for unsh in [false, true]:
		var tag := "U " if unsh else "L "
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.62, 0.3, 0.1); sm.roughness = 1.0; sm.metallic_specular = 0.0; sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		if unsh: sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mats.append(sm); names.append(tag + "standard albedo_color (0.62,0.3,0.1)")
		mats.append(_sh("ALBEDO = vec3(0.62, 0.3, 0.1);", unsh)); names.append(tag + "shader const vec3(0.62,0.3,0.1)")
		mats.append(_sh("ALBEDO = uc;", unsh)); names.append(tag + "shader source_color uniform default")
		mats.append(_sh("ALBEDO = COLOR.rgb;", unsh)); names.append(tag + "shader COLOR.rgb (vertex 0.62,0.3,0.1)")
		mats.append(_sh("ALBEDO = vec3(COLOR.a);", unsh)); names.append(tag + "shader COLOR.a (vertex 0.25)")
		mats.append(_sh("ALBEDO = vec3(0.5);", unsh)); names.append(tag + "shader const vec3(0.5)  [128 raw, 188 srgb]")
		mats.append(_sh("ALBEDO = vec3(0.5, 0.25, 0.75) * vec3(0.5);", unsh)); names.append(tag + "shader const product (0.25,0.125,0.375) [64,32,96 raw]")
		mats.append(_sh("ALBEDO = vec3(1.0); EMISSION = vec3(0.0); ALBEDO *= 0.5;", unsh)); names.append(tag + "shader ALBEDO 1.0*0.5")
	for i in mats.size():
		var q := _quad(Color(0.62, 0.3, 0.1, 0.25), float(i))
		q.material_override = mats[i]
		sv.add_child(q)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	print("window size ", root.size)
	print("adjustment_enabled=", with_env, "  reference: raw bytes 158,77,26 | srgb(raw) 206,148,89 | alpha raw 64 | srgb(0.25) 137")
	for k in mats.size():
		var c := img.get_pixel(50 + k * 100, 50)
		print("%-48s -> %d,%d,%d" % [names[k], roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)])
	await create_timer(6.0).timeout
	quit(0)
