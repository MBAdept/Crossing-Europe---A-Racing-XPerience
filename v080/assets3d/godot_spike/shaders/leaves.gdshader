// Leaf cards: alpha-tested, double sided, spherical normals from the mesh, wind in the vertex shader.
// COLOR.r = tint, COLOR.g = phase, COLOR.a = sway weight (height^2)
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float wind_strength = 0.25;
uniform float wind_time = 0.0;
varying float v_tint;

void vertex() {
	float ph = COLOR.g * 6.2831;
	float sway = COLOR.a;
	float t = wind_time;
	VERTEX.x += sin(t * 1.3 + ph * 0.2) * wind_strength * sway;
	VERTEX.z += cos(t * 1.1 + ph * 0.3) * wind_strength * 0.6 * sway;
	VERTEX.y += sin(t * 4.0 + ph) * 0.03;
	v_tint = COLOR.r;
}

void fragment() {
	vec4 a = texture(leaf_tex, UV);
	ALBEDO = a.rgb * v_tint;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
