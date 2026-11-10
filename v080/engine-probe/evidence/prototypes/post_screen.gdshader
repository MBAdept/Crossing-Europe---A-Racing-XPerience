shader_type canvas_item;
// Full-screen post effect on a ColorRect above the 3D picture: radial blur (speed), vignette,
// rain droplets (refraction) – all from the screen texture.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float blur_strength = 0.0;
uniform float vignette = 0.0;
uniform float droplets = 0.0;
uniform float chroma = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.45);
	// droplets: cells with a round lens that offsets the lookup
	if (droplets > 0.0) {
		vec2 g = uv * vec2(16.0, 9.0) * 1.5;
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5;
		float r = hash21(cell);
		vec2 off = (vec2(hash21(cell + 2.3), hash21(cell + 5.1)) - 0.5) * 0.5;
		float d = length(f - off);
		float radius = mix(0.08, 0.22, hash21(cell + 9.7));
		if (r > 1.0 - droplets && d < radius) {
			vec2 n = (f - off) / radius;
			uv -= n * 0.035 * (1.0 - d / radius);
		}
	}
	vec3 col = vec3(0.0);
	if (blur_strength > 0.0) {
		vec2 dir = uv - center;
		float total = 0.0;
		for (int i = 0; i < 12; i++) {
			float t = float(i) / 11.0;
			float w = 1.0 - t * 0.6;
			col += texture(screen_tex, uv - dir * t * blur_strength * length(dir) * 2.0).rgb * w;
			total += w;
		}
		col /= total;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (chroma > 0.0) {
		vec2 dir = (uv - center) * chroma;
		col.r = texture(screen_tex, uv + dir).r;
		col.b = texture(screen_tex, uv - dir).b;
	}
	float v = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.0, 0.9)));
	col *= 1.0 - v * vignette;
	COLOR = vec4(col, 1.0);
}
