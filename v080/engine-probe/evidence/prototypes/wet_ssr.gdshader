shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;
// Probe: screen-space reflections for a wet road as a transparent overlay (the Compatibility renderer has
// no built-in SSR). Marches the reflected view ray against the depth texture and reads the screen texture.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float strength = 0.85;
uniform float max_dist = 70.0;
uniform float streak = 0.35;

float view_z_at(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return v.z / v.w;
}

void fragment() {
	vec3 P = VERTEX;
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(P);
	float jitter = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	// rough wet asphalt: jitter the normal a little along the view direction -> vertical streaks
	N = normalize(N + vec3(0.0, 0.0, (jitter - 0.5) * streak * 0.2));
	vec3 R = reflect(V, N);
	float fres = 0.04 + 0.96 * pow(1.0 - max(dot(-V, N), 0.0), 4.0);
	const int STEPS = 20;
	vec3 hit = vec3(0.0);
	float found = 0.0;
	float t = 0.0;
	float step_len = 0.35;
	for (int i = 0; i < STEPS; i++) {
		t += step_len * (0.6 + 0.8 * jitter);
		step_len *= 1.32;
		if (t > max_dist) {
			break;
		}
		vec3 S = P + R * t;
		vec4 clip = PROJECTION_MATRIX * vec4(S, 1.0);
		vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			break;
		}
		float scene_z = view_z_at(uv, INV_PROJECTION_MATRIX);
		float diff = scene_z - S.z; // > 0: the scene surface is in front of the ray sample
		if (diff > 0.0 && diff < step_len * 2.0 + 1.0) {
			hit = texture(screen_tex, uv).rgb;
			found = 1.0 - smoothstep(max_dist * 0.6, max_dist, t);
			// fade at the screen border
			vec2 b = smoothstep(vec2(0.0), vec2(0.08), uv) * (1.0 - smoothstep(vec2(0.92), vec2(1.0), uv));
			found *= b.x * b.y;
			break;
		}
	}
	ALBEDO = hit;
	ALPHA = found * fres * strength;
}
