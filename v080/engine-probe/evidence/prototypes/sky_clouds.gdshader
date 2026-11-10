shader_type sky;
// Probe: custom sky with gradient, sun/moon disc, animated fbm clouds, stars and dithering.
uniform vec3 top_color : source_color = vec3(0.10, 0.32, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.76, 0.90);
uniform vec3 ground_color : source_color = vec3(0.25, 0.27, 0.25);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_cover = 0.5;
uniform float cloud_speed = 0.02;
uniform float night = 0.0;
uniform float use_time = 1.0;
uniform float dither = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.55));
	col = mix(col, ground_color, smoothstep(0.0, -0.08, dir.y));
	col *= mix(1.0, 0.03, night);
	// stars (only on the screen pass, not in the radiance cubemap)
	if (night > 0.0 && dir.y > 0.0 && !AT_CUBEMAP_PASS) {
		vec2 suv = dir.xz / (abs(dir.y) + 0.35) * 60.0;
		vec2 cell = floor(suv);
		float r = hash21(cell);
		vec2 off = vec2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5;
		float d = length(fract(suv) - 0.5 - off * 0.6);
		float star = step(0.93, r) * smoothstep(0.09, 0.0, d);
		col += vec3(star) * night * (0.5 + 2.5 * hash21(cell + 1.3)) * smoothstep(0.0, 0.2, dir.y);
	}
	// sun or moon disc + halo from the first directional light
	if (LIGHT0_ENABLED) {
		float mu = dot(dir, LIGHT0_DIRECTION);
		float disc = smoothstep(0.9993, 0.9997, mu);
		float halo = pow(max(mu, 0.0), 180.0) * 0.6 + pow(max(mu, 0.0), 12.0) * 0.12;
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (disc * 6.0 + halo);
	}
	// clouds on a virtual plane
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.12);
		uv += vec2(1.0, 0.35) * TIME * cloud_speed * use_time;
		float c = fbm(uv * 0.9);
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, c);
		float shade = fbm(uv * 0.9 + vec2(0.15, 0.1));
		vec3 ccol = cloud_color * mix(0.55, 1.05, smoothstep(0.3, 0.8, shade)) * mix(1.0, 0.06, night);
		col = mix(col, ccol, cov * smoothstep(0.0, 0.12, dir.y) * 0.92);
	}
	// dithering against banding (the Compatibility renderer has no debanding)
	if (!AT_CUBEMAP_PASS) {
		float n = hash21(FRAGCOORD.xy + fract(TIME) * 61.0 * use_time);
		col += (n - 0.5) / 255.0 * 1.5 * dither;
	}
	COLOR = col;
}
