shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Full-screen quad in 3D: reads the depth and screen textures (heat haze / depth tint / edge outline).
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float mode = 0.0; // 0: depth visualisation, 1: depth-based tint (distance haze), 2: outlines

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float depth = texture(depth_tex, uv).r;
	vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0); // OpenGL: z in -1..1
	vec4 view = inv_proj * ndc;
	return -view.z / view.w;
}

void fragment() {
	float z = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	if (mode < 0.5) {
		ALBEDO = vec3(clamp(z / 150.0, 0.0, 1.0));
	} else if (mode < 1.5) {
		float f = 1.0 - exp(-z * 0.012);
		ALBEDO = mix(scene, vec3(0.75, 0.55, 0.9), f * 0.8);
	} else {
		vec2 px = 1.0 / VIEWPORT_SIZE;
		float zx = linear_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		float zy = linear_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
		float e = clamp((abs(zx - z) + abs(zy - z)) / (z * 0.08), 0.0, 1.0);
		ALBEDO = mix(scene, vec3(0.0), e);
	}
}
