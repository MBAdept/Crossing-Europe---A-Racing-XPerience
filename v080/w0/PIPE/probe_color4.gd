extends SceneTree
# Do global colour uniforms / instance colour uniforms arrive raw (sRGB) or linearised in GL Compatibility?
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

func _sh(decl: String, body: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode cull_disabled, unshaded;\n%s\nvoid fragment() { %s }\n" % [decl, body]
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _run() -> void:
	RenderingServer.global_shader_parameter_add(&"tg_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.62, 0.3, 0.1))
	RenderingServer.global_shader_parameter_add(&"tg_vec", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.62, 0.3, 0.1))
	var sv: Window = root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.position = Vector3(3, 0.5, 5)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	sv.add_child(cam)
	var mats := [
		_sh("global uniform vec4 tg_color : source_color;", "ALBEDO = tg_color.rgb;"),
		_sh("global uniform vec4 tg_color;", "ALBEDO = tg_color.rgb;"),
		_sh("global uniform vec3 tg_vec;", "ALBEDO = tg_vec;"),
		_sh("instance uniform vec4 ic : source_color = vec4(0.62, 0.3, 0.1, 1.0);", "ALBEDO = ic.rgb;"),
		_sh("instance uniform vec4 ic : source_color = vec4(0.1, 0.1, 0.1, 1.0);", "ALBEDO = ic.rgb;"),
		_sh("uniform vec4 uc : source_color;", "ALBEDO = uc.rgb;"),
	]
	var names := ["global color + source_color hint", "global color, no hint", "global vec3", "instance source_color default", "instance source_color set from script", "uniform source_color set from script"]
	for i in mats.size():
		var q := _quad(float(i))
		q.material_override = mats[i]
		sv.add_child(q)
		if i == 4:
			q.set_instance_shader_parameter("ic", Color(0.62, 0.3, 0.1))
		if i == 5:
			(mats[i] as ShaderMaterial).set_shader_parameter("uc", Color(0.62, 0.3, 0.1))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	print("reference: raw 158,77,26 (screen shows the raw ALBEDO value) | linearised would show 87,19,3")
	for k in mats.size():
		var c := img.get_pixel(50 + k * 100, 50)
		print("%-44s -> %d,%d,%d" % [names[k], roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)])
	quit(0)
