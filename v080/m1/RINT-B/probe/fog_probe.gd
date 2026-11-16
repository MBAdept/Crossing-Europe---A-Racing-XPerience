extends SceneTree
## Probe: does a lit spatial shader's FOG output work in GL Compatibility (with the Environment's depth fog on)?

const SHADER := """
shader_type spatial;
uniform int mode = 0;
void fragment() {
	ALBEDO = vec3(0.5);
	if (mode == 1) { FOG = vec4(1.0, 0.0, 0.0, 0.5); }
	if (mode == 2) { FOG = vec4(0.0, 0.0, 1.0, 0.0); }
}
"""

var frames := 0
var quads: Array = []
var cam: Camera3D


func _initialize() -> void:
	var root := get_root()
	root.size = Vector2i(320, 180)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.0, 1.0, 0.0)
	env.fog_density = 1.0
	env.fog_depth_begin = 0.0
	env.fog_depth_end = 40.0
	we.environment = env
	root.add_child(we)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0, 10)
	root.add_child(cam)
	var sh := Shader.new()
	sh.code = SHADER
	for i in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("mode", i)
		mi.material_override = m
		mi.position = Vector3(-3.0 + 3.0 * i, 0, 0)
		root.add_child(mi)
		quads.append(mi)


func _process(_dt: float) -> bool:
	frames += 1
	if frames < 6:
		return false
	var img := get_root().get_texture().get_image()
	for i in 3:
		var p := cam.unproject_position((quads[i] as Node3D).position)
		var c := img.get_pixelv(Vector2i(p))
		print("mode %d: %d/%d/%d" % [i, int(c.r * 255), int(c.g * 255), int(c.b * 255)])
	return true
