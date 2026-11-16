extends SceneTree
## RINT-M2 probe 2: one mesh + one material drawn by several MultiMeshes – rows: 0 custom only, 1 nothing,
## 2 colours only, 3 colours + custom, 4 nothing (own mesh), 5 a plain MeshInstance3D. Prints INSTANCE_CUSTOM per
## instance (rgb, and a as grey in a second pass via the 'show_a' uniform).

var _frames := 0
var _vp: SubViewport
var _mat: ShaderMaterial
var _mat2: ShaderMaterial
var _pass := 0
var _lines: Array[String] = []


func _init() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(320, 400)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20.0
	cam.position = Vector3(0, 0, 10)
	_vp.add_child(cam)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool show_a = false;
varying vec4 v_c;
varying float v_code;
void vertex() { v_c = INSTANCE_CUSTOM; v_code = COLOR.a; }
void fragment() { ALBEDO = show_a ? vec3(clamp(v_c.a, 0.0, 1.0)) : clamp(v_c.rgb, 0.0, 1.0) * (v_code > 0.5 ? 1.0 : 0.5); }
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat2 = ShaderMaterial.new()
	_mat2.shader = sh
	var q := _cmesh()
	var q2 := _cmesh()
	for row in 6:
		var y := 7.5 - 3.0 * row
		if row == 5:
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.position = Vector3(-5, y, 0)
			_vp.add_child(mi)
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = row == 2 or row == 3
		mm.use_custom_data = row == 0 or row == 3
		mm.mesh = q2 if row == 4 else q
		mm.instance_count = 3
		var buf := PackedFloat32Array()
		for i in 3:
			var o := Vector3(-5.0 + 5.0 * i, y, 0)
			buf.append_array([1.0, 0.0, 0.0, o.x, 0.0, 1.0, 0.0, o.y, 0.0, 0.0, 1.0, o.z])
			if mm.use_colors:
				buf.append_array([1.0, 0.5, 0.25, 1.0])
			if mm.use_custom_data:
				buf.append_array([0.2, 0.4, 0.6, 1.0])
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		_vp.add_child(mmi)


func _cmesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.75, -0.75, 0), Vector3(0.75, -0.75, 0), Vector3(0.75, 0.75, 0), Vector3(-0.75, 0.75, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([Color(0.3, 0.3, 0.3, 1), Color(0.3, 0.3, 0.3, 1), Color(0.3, 0.3, 0.3, 1), Color(0.3, 0.3, 0.3, 1)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arr[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(-1, 0), Vector2(-1, 0), Vector2(-1, 0), Vector2(-1, 0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _mat)
	var arr2 := arr.duplicate(true)
	arr2[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.75, -0.75, 0), Vector3(0.75, -0.75, 0), Vector3(0.75, 0.75, 0), Vector3(-0.75, 0.75, 0)]) if false else PackedVector3Array([Vector3(-0.75, -0.75 - 1.5, 0), Vector3(0.75, -0.75 - 1.5, 0), Vector3(0.75, 0.75 - 1.5, 0), Vector3(-0.75, 0.75 - 1.5, 0)])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	m.surface_set_material(1, _mat2)
	return m


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8 or _frames == 16:
		var img := _vp.get_texture().get_image()
		for row in 6:
			var s := "pass%d row%d:" % [_pass, row]
			for i in 3:
				if row == 5 and i > 0:
					break
				var px := Vector2i(int(160 + (-5.0 + 5.0 * i) * 20), int(200 - (7.5 - 3.0 * row) * 20))
				var c := img.get_pixelv(px)
				var c2 := img.get_pixelv(px + Vector2i(0, 30))
				s += " s0(%.2f %.2f %.2f) s1(%.2f %.2f %.2f)" % [c.r, c.g, c.b, c2.r, c2.g, c2.b]
			print("MMC4 ", s)
		_pass += 1
		_mat.set_shader_parameter("show_a", true)
		_mat2.set_shader_parameter("show_a", true)
	return _frames >= 16
