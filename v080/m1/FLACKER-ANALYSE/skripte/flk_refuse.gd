extends SceneTree
## FLACKER-ANALYSE (scratch only): what does Godot 4.7 GL Compatibility draw for a geometry instance whose instance
## uniforms were refused ("Too many instances using shader instance variables")? 300 quads with a two-colour shader:
## left half = instance uniform index 0, right half = index 1. Every quad sets unique colours; the global uniforms
## g0..g3 occupy the first slots of the buffer with known colours. Read back and decode.
## usage: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://flk_refuse.gd

const N := 300
const COLS := 20

var _frames := 0
var _quads: Array = []
var _cam: Camera3D


func _initialize() -> void:
	root.size = Vector2i(1280, 960)
	# known globals in the first slots of the buffer
	RenderingServer.global_shader_parameter_add(&"g0", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(1, 0, 0, 1))
	RenderingServer.global_shader_parameter_add(&"g1", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0, 1, 0, 1))
	RenderingServer.global_shader_parameter_add(&"g2", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0, 0, 1, 1))
	RenderingServer.global_shader_parameter_add(&"g3", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(1, 1, 0, 1))
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
global uniform vec4 g0;
global uniform vec4 g1;
global uniform vec4 g2;
global uniform vec4 g3;
instance uniform vec4 c0 : instance_index(0) = vec4(0.5, 0.5, 0.52, 1.0);
instance uniform vec4 c1 : instance_index(1) = vec4(0.25, 0.25, 0.25, 1.0);
varying vec3 v_obj;
void vertex() { v_obj = VERTEX; }
void fragment() {
	// keep the globals alive in the shader (unused otherwise)
	vec3 keep = (g0.rgb + g1.rgb + g2.rgb + g3.rgb) * 0.0;
	ALBEDO = (v_obj.x < 0.0 ? c0.rgb : c1.rgb) + keep;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	qm.material = mat
	var world := Node3D.new()
	root.add_child(world)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 15.0 * 1.0
	_cam.position = Vector3(9.5, -7.0, 10.0)
	world.add_child(_cam)
	_cam.current = true
	for i in N:
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.position = Vector3(float(i % COLS), -float(i / COLS), 0.0)
		mi.set_instance_shader_parameter(&"c0", _code_col(i, 0))
		mi.set_instance_shader_parameter(&"c1", _code_col(i, 1))
		world.add_child(mi)
		_quads.append(mi)


static func _code_col(i: int, k: int) -> Color:
	# unique per quad and index: r = i % 16, g = i / 16 (0..18), b = 0.25 + 0.5 k
	return Color(float(i % 16) / 15.0, float(i / 16) / 19.0, 0.25 + 0.5 * float(k), 1.0)


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var img := root.get_texture().get_image()
	img.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/refuse.png")
	var bad := 0
	var lines: Array[String] = []
	for i in N:
		var mi: MeshInstance3D = _quads[i]
		var left := _cam.unproject_position(mi.global_position + Vector3(-0.25, 0.0, 0.0))
		var right := _cam.unproject_position(mi.global_position + Vector3(0.25, 0.0, 0.0))
		var cl := img.get_pixelv(Vector2i(left))
		var cr := img.get_pixelv(Vector2i(right))
		var ok := _near(cl, _code_col(i, 0)) and _near(cr, _code_col(i, 1))
		if not ok:
			bad += 1
			lines.append("quad %d: c0 shows %s (%s) | c1 shows %s (%s)" % [i, _hex(cl), _decode(cl), _hex(cr), _decode(cr)])
	print("FLK refuse: %d of %d quads wrong" % [bad, N])
	for l in lines.slice(0, 60):
		print("FLK ", l)
	quit(0)
	return true


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


static func _hex(c: Color) -> String:
	return "#%02x%02x%02x" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]


static func _decode(c: Color) -> String:
	if _near(c, Color(1, 0, 0)):
		return "global g0"
	if _near(c, Color(0, 1, 0)):
		return "global g1"
	if _near(c, Color(0, 0, 1)):
		return "global g2"
	if _near(c, Color(1, 1, 0)):
		return "global g3"
	if _near(c, Color(0, 0, 0)):
		return "zero"
	if _near(c, Color(0.5, 0.5, 0.52)):
		return "default c0"
	if _near(c, Color(0.25, 0.25, 0.25)):
		return "default c1"
	var i := roundi(c.r * 15.0) + 16 * roundi(c.g * 19.0)
	var k := 0 if c.b < 0.5 else 1
	return "quad %d index %d" % [i, k]
