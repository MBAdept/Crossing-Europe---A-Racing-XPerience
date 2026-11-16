extends SceneTree
## Probe (RINT-B): what the pinned post path (Environment.adjustment_enabled) does to dark display values in GL
## Compatibility, and whether a colour-correction LUT can undo it. Run under Xvfb with opengl3.
## Quads (unshaded) write ALBEDO such that one pass shows display value d exactly (to_lin / show inverse).

const VALUES := [2, 4, 6, 8, 10, 12, 14, 16, 19, 22, 26, 30, 36, 44, 56, 70, 90, 128, 180, 230]
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float d = 0.0;
vec3 to_lin(vec3 c) { return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878); }
vec3 albedo_for(vec3 x) {
	vec3 c = pow(max(x, vec3(0.0)), vec3(0.4545));
	for (int i = 0; i < 3; i++) { c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878); }
	return max(c, vec3(0.0));
}
void fragment() {
	float x = d > 0.0 ? pow((d + 0.055) / 1.055, 2.4) : 0.0;
	ALBEDO = albedo_for(vec3(x));
}
"""

var env: Environment
var cam: Camera3D
var frames := 0
var phase := 0
var results := {}


func _initialize() -> void:
	var root := get_root()
	root.size = Vector2i(640, 360)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	we.environment = env
	root.add_child(we)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	cam.position = Vector3(0, 0, 10)
	root.add_child(cam)
	var sh := Shader.new()
	sh.code = SHADER
	for i in VALUES.size():
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.8, 0.8)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("d", float(VALUES[i]) / 255.0)
		mi.material_override = m
		mi.position = Vector3(-8.0 + float(i % 10) * 1.0 + 3.5, 1.0 - float(i / 10) * 1.5, 0.0)
		root.add_child(mi)


func _lut(kind: String, n: int = 256, fmt: int = Image.FORMAT_RGB8) -> Texture2D:
	# 1D LUT: texel j holds the wanted output for the input at its centre, (j + 0.5) / n
	var img := Image.create(n, 1, false, fmt)
	for i in n:
		var y := (float(i) + 0.5) / float(n)
		var o := y
		if kind == "inverse":
			o = _post_inverse(y)
		img.set_pixel(i, 0, Color(o, o, o))
	return ImageTexture.create_from_image(img)


static func _to_lin(c: float) -> float:
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


static func _show(x: float) -> float:
	return maxf(1.055 * pow(maxf(x, 0.0), 0.416666667) - 0.055, 0.0)


static func _post_inverse(shown: float) -> float:
	if shown <= 0.0:
		return 0.0
	var lo := 0.0
	var hi := 1.5
	for i in 30:
		var mid := (lo + hi) * 0.5
		if _show(_to_lin(mid)) < shown:
			lo = mid
		else:
			hi = mid
	return minf((lo + hi) * 0.5, 1.0)


func _process(_dt: float) -> bool:
	frames += 1
	if frames % 6 != 0:
		return false
	var img := get_root().get_texture().get_image()
	var row := []
	for i in VALUES.size():
		var p := cam.unproject_position(Vector3(-8.0 + float(i % 10) * 1.0 + 3.5, 1.0 - float(i / 10) * 1.5, 0.0))
		var c := img.get_pixelv(Vector2i(p))
		row.append(int(round(c.r * 255.0)))
	var names := ["no_post", "post", "post_lut_identity", "post_lut_inverse", "inverse_1024_f16", "inverse_256_f16"]
	results[names[phase]] = row
	phase += 1
	match phase:
		1:
			env.adjustment_enabled = true
		2:
			env.adjustment_color_correction = _lut("identity")
		3:
			env.adjustment_color_correction = _lut("inverse")
		4:
			env.adjustment_color_correction = _lut("inverse", 1024, Image.FORMAT_RGBH)
		5:
			env.adjustment_color_correction = _lut("inverse", 256, Image.FORMAT_RGBH)
		_:
			print("values             ", VALUES)
			for k in names:
				if results.has(k):
					print("%-19s" % k, results[k])
			var exp := []
			for v in VALUES:
				exp.append(int(round(_show(_to_lin(v / 255.0)) * 255.0)))
			print("%-19s" % "model post_shown", exp)
			return true
	return false
