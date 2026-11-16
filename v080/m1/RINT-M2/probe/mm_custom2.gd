extends SceneTree
## RINT-M2 probe 2: one mesh + one material drawn by several MultiMeshes – rows: 0 custom only, 1 nothing,
## 2 colours only, 3 colours + custom, 4 nothing (own mesh), 5 a plain MeshInstance3D. Prints INSTANCE_CUSTOM per
## instance (rgb, and a as grey in a second pass via the 'show_a' uniform).

var _frames := 0
var _vp: SubViewport
var _mat: ShaderMaterial
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
void vertex() { v_c = INSTANCE_CUSTOM; }
void fragment() { ALBEDO = show_a ? vec3(clamp(v_c.a, 0.0, 1.0)) : clamp(v_c.rgb, 0.0, 1.0); }
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.material = _mat
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.5, 1.5)
	q2.material = _mat
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
				s += " (%.2f %.2f %.2f)" % [c.r, c.g, c.b]
			print("MMC2 ", s)
		_pass += 1
		_mat.set_shader_parameter("show_a", true)
	return _frames >= 16
