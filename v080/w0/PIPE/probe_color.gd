extends SceneTree
# Is the vertex COLOR raw or converted to linear when it reaches a spatial shader (Compatibility)?
func _initialize() -> void:
	_run.call_deferred()

func _quad(col: Color, x: float, compress: bool) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x, 0, 0), Vector3(x + 1, 0, 0), Vector3(x + 1, 1, 0), Vector3(x, 1, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([col, col, col, col])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.3, 0.1), Vector2(0.3, 0.1), Vector2(0.3, 0.1), Vector2(0.3, 0.1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if compress else 0)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	return mi

func _run() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(400, 100)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.position = Vector3(2, 0.5, 5)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	sv.add_child(cam)
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() { ALBEDO = vec3(COLOR.a); }\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	var sh2 := Shader.new()
	sh2.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvarying vec3 c;\nvoid vertex() { c = COLOR.rgb; }\nvoid fragment() { ALBEDO = c; }\n"
	var m2 := ShaderMaterial.new()
	m2.shader = sh2
	var shb := Shader.new()
	shb.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() { ALBEDO = vec3(0.62, 0.3, 0.1); }\n"
	var mb := ShaderMaterial.new(); mb.shader = shb
	var she := Shader.new()
	she.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvarying flat float a;\nvoid vertex() { a = COLOR.a; }\nvoid fragment() { ALBEDO = vec3(a); }\n"
	var me := ShaderMaterial.new(); me.shader = she
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.albedo_color = Color(0.62, 0.3, 0.1); sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q0 := _quad(Color(0.62, 0.3, 0.1, 0.25), 0.0, false); q0.material_override = m; sv.add_child(q0)
	var q1 := _quad(Color(0.62, 0.3, 0.1, 0.25), 1.0, true); q1.material_override = me; sv.add_child(q1)
	var q2 := _quad(Color(0.62, 0.3, 0.1, 0.25), 2.0, false); q2.material_override = mb; sv.add_child(q2)
	var q3 := _quad(Color(0.62, 0.3, 0.1, 0.25), 3.0, true); q3.material_override = sm; sv.add_child(q3)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	for k in 4:
		var c := img.get_pixel(50 + k * 100, 50)
		print("quad ", k, " pixel ", roundi(c.r * 255), ",", roundi(c.g * 255), ",", roundi(c.b * 255), "  (raw input 158,77,26; srgb(raw)= 206,148,89)")
	quit(0)
