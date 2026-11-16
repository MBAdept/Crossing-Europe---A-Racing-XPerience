extends SceneTree
## RINT-M2 probe: what does INSTANCE_CUSTOM read in the Compatibility renderer for a MultiMesh with custom data only
## (use_colors = false) against one with colours and custom data? Three instances each, custom = (0.2, 0.4, 0.6, 1).

var _frames := 0
var _vp: SubViewport


func _init() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(240, 160)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.0
	cam.position = Vector3(0, 0, 10)
	_vp.add_child(cam)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
varying vec4 v_c;
void vertex() { v_c = INSTANCE_CUSTOM; }
void fragment() { ALBEDO = clamp(v_c.rgb, 0.0, 1.0); }
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for row in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = row == 1
		mm.use_custom_data = true
		var q := QuadMesh.new()
		q.size = Vector2(1.5, 1.5)
		q.material = mat
		mm.mesh = q
		mm.instance_count = 3
		var buf := PackedFloat32Array()
		for i in 3:
			var b := Basis(Vector3.UP, 0.3 * i)
			var o := Vector3(-2.5 + 2.5 * i, 1.5 - 3.0 * row, 0)
			buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z])
			if row == 1:
				buf.append_array([1.0, 1.0, 1.0, 1.0])
			buf.append_array([0.2, 0.4, 0.6, 1.0])
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		_vp.add_child(mmi)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		var img := _vp.get_texture().get_image()
		for row in 2:
			var s := "use_colors=%s:" % (row == 1)
			for i in 3:
				var px := Vector2i(int(120 + (-2.5 + 2.5 * i) * 20), int(80 - (1.5 - 3.0 * row) * 20))
				var c := img.get_pixelv(px)
				s += " (%.2f %.2f %.2f)" % [c.r, c.g, c.b]
			print("MMCUSTOM ", s)
		img.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/look/mm_custom.png")
		return true
	return false
