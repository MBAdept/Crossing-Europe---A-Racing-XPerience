extends SceneTree
## R3 probe (not in the repo): what the Compatibility renderer of this Godot build offers for the vehicle and flare
## shaders – CLEARCOAT with sky radiance, hint_depth_texture in vertex()/fragment() of a transparent material,
## render_mode fog_disabled, POSITION in vertex().

var _vp: SubViewport
var _out := ""

const SPHERE_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float use_cc = 0.0;
uniform float metal = 0.0;
uniform float rough = 0.5;
void fragment() {
	ALBEDO = vec3(0.1, 0.1, 0.5);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	if (use_cc > 0.5) {
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.05;
	}
}
"""

const DEPTH_V_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying float v_vis;
void vertex() {
	vec4 c = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0));
	vec2 ndc = c.xy / c.w;
	vec2 uv = ndc * 0.5 + 0.5;
	float d = textureLod(depth_tex, uv, 0.0).r;
	float mine = c.z / c.w;
	v_vis = d;
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}
void fragment() {
	ALBEDO = vec3(v_vis, 0.0, 0.0);
}
"""

const DEPTH_F_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	ALBEDO = vec3(0.0, d, 0.0);
}
"""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 256)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	_vp.add_child(cam)
	cam.make_current()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.1)
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(1.0, 0.2, 0.2)
	sm.sky_horizon_color = Color(1.0, 0.2, 0.2)
	sm.ground_bottom_color = Color(1.0, 0.2, 0.2)
	sm.ground_horizon_color = Color(1.0, 0.2, 0.2)
	sky.sky_material = sm
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.2)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sphere := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sphere.mesh = sm2
	var sh := Shader.new()
	sh.code = SPHERE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	sphere.material_override = mat
	_vp.add_child(sphere)
	for i in 4:
		await process_frame
	var img0 := _vp.get_texture().get_image()
	mat.set_shader_parameter("use_cc", 1.0)
	for i in 4:
		await process_frame
	var img1 := _vp.get_texture().get_image()
	_out += "sphere centre no cc %s / with cc %s\n" % [str(img0.get_pixel(128, 128)), str(img1.get_pixel(128, 128))]
	_out += "sphere edge  no cc %s / with cc %s\n" % [str(img0.get_pixel(128 + 60, 128)), str(img1.get_pixel(128 + 60, 128))]
	# metallic, smooth: does the engine reflect the (red) sky at all?
	mat.set_shader_parameter("use_cc", 0.0)
	mat.set_shader_parameter("metal", 1.0)
	mat.set_shader_parameter("rough", 0.1)
	for i in 4:
		await process_frame
	var img2 := _vp.get_texture().get_image()
	_out += "metal smooth centre %s edge %s\n" % [str(img2.get_pixel(128, 128)), str(img2.get_pixel(128 + 60, 128))]
	env.background_mode = Environment.BG_CANVAS
	for i in 4:
		await process_frame
	var img3 := _vp.get_texture().get_image()
	_out += "BG_CANVAS metal smooth centre %s edge %s\n" % [str(img3.get_pixel(128, 128)), str(img3.get_pixel(128 + 60, 128))]
	env.background_mode = Environment.BG_COLOR
	# depth texture probes: a quad in front of the sphere
	for code: String in [DEPTH_V_SHADER, DEPTH_F_SHADER]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.5)
		q.mesh = qm
		q.position = Vector3(0.0, 0.0, 1.5)
		var s2 := Shader.new()
		s2.code = code
		var m2 := ShaderMaterial.new()
		m2.shader = s2
		q.material_override = m2
		_vp.add_child(q)
		for i in 4:
			await process_frame
		var im := _vp.get_texture().get_image()
		_out += "depth probe %s: centre %s\n" % ["vertex" if code == DEPTH_V_SHADER else "fragment", str(im.get_pixel(128, 128))]
		q.queue_free()
		await process_frame
	print(_out)
	quit(0)
