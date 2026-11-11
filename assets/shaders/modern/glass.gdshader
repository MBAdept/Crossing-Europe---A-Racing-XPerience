// Modern, material class "glass": vehicle glazing at lod0 / show and clear lamp lenses (docs/modelle.md).
//   COLOR.rgb  tint as sRGB bytes        COLOR.a  opacity        UV  (roughness, metallic)
// Look (asset side): a pane is its tint weighted with its opacity PLUS the full mirror reflection of sky and
// sun - premultiplied blending, so a clear pane (opacity 0.3) still mirrors as brightly as a dark one; towards
// grazing angles it becomes opaque and mirror-like (Fresnel). No depth write.
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_never, cull_back;

// same indices as in vpbr.gdshader: both surfaces of a body share the instance
instance uniform float fade : instance_index(5) = 1.0;          // path-distance fade (dither discard)
instance uniform float sun : instance_index(6) = 1.0;           // 0 inside tunnels: masks the directional light

uniform float fresnel_boost = 0.85;           // how far the opacity rises towards grazing angles
uniform float mirror = 0.75;                  // strength of the mirror reflection (SPECULAR of the engine)
uniform float tint_gain = 1.0;                // brightness of the tint seen through the pane's own colour

// --- R3 (wave 1): the mirror image of the environment for the reflection above. The Environment of the race has
// no Sky in every preset (the reflection source of D7 is optional), so the sky the pane mirrors is the analytic
// one of vpbr.gdshader (same uniforms, set by the vehicle layer from the palette), weighted with the look's own
// Fresnel term and `mirror`, added in EMISSION (premultiplied: in full, whatever the opacity). env_energy 0 = only
// the engine's reflection, as before.
uniform vec4 env_zenith = vec4(0.11, 0.36, 0.79, 1.0);
uniform vec4 env_horizon = vec4(0.73, 0.87, 0.96, 1.0);
uniform vec4 env_ground = vec4(0.27, 0.28, 0.29, 1.0);
uniform vec4 env_tunnel = vec4(0.30, 0.24, 0.16, 1.0);
uniform float env_energy = 2.2;

vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 encode(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 c = pow(x, vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

// the environment of vpbr.gdshader (ground, landscape band, sky), sharp: glass is smooth
vec3 env_light(vec3 r) {
	vec3 zen = to_lin(env_zenith.rgb);
	vec3 hor = to_lin(env_horizon.rgb);
	vec3 gnd = to_lin(env_ground.rgb);
	vec3 land = mix(gnd * 1.4, hor, 0.3);
	vec3 sky = mix(hor, zen, smoothstep(0.1, 0.7, r.y));
	vec3 c = mix(land, sky, smoothstep(0.04, 0.14, r.y));
	c = mix(gnd, c, smoothstep(-0.1, 0.0, r.y));
	return mix(to_lin(env_tunnel.rgb) * mix(0.6, 1.0, max(r.y, 0.0)), c, clamp(sun, 0.0, 1.0));
}
// --- end R3

void fragment() {
	if (fade < 0.999) {
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (d >= fade) {
			discard;
		}
	}
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	float a = mix(COLOR.a, 1.0, f * fresnel_boost);
	// premultiplied: the tint counts with the opacity of the pane, the reflection in full
	ALBEDO = COLOR.rgb * tint_gain * a;         // sRGB as stored: the Compatibility renderer linearises ALBEDO itself
	ROUGHNESS = max(UV.x, 0.02);
	METALLIC = UV.y;
	// thin clear lamp lenses (low opacity) mirror less than panes: a full sky reflection over a lamp is a milky veil
	SPECULAR = mirror * mix(0.25, 1.0, smoothstep(0.08, 0.3, COLOR.a));
	ALPHA = a;
	// (PREMUL_ALPHA_FACTOR is not written: the Compatibility scene shader of Godot 4.7 does not declare it, and
	// without it the lit colour goes out unscaled - which is what is wanted here)
	// R3: the environment's mirror image (see the uniforms above), same Fresnel as the opacity
	if (env_energy > 0.0) {
		vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		float fr = min(mix(0.04, 1.0, f), 0.45) * mirror * mix(0.25, 1.0, smoothstep(0.08, 0.3, COLOR.a));
		EMISSION = encode(env_light(reflect(-v_w, n_w)) * fr * env_energy);
	}
}

float d_ggx(float ndh, float a) {
	float t = ndh * a;
	float k = a / (1.0 - ndh * ndh + t * t);
	return k * k * (1.0 / PI);
}

float v_ggx(float ndl, float ndv, float a) {
	return 0.5 / mix(2.0 * ndl * ndv, ndl + ndv, a);
}

void light() {
	float k = LIGHT_IS_DIRECTIONAL ? sun : 1.0;
	vec3 lc = LIGHT_COLOR * ATTENUATION * k;
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += lc * ndl * (1.0 / PI);
	vec3 h = normalize(VIEW + LIGHT);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float ndv = max(dot(NORMAL, VIEW), 1e-4);
	float ldh = clamp(dot(LIGHT, h), 0.0, 1.0);
	float a = max(ROUGHNESS * ROUGHNESS, 0.002);
	float fr = mix(0.08, 1.0, pow(1.0 - ldh, 5.0));
	SPECULAR_LIGHT += lc * SPECULAR_AMOUNT * ndl * d_ggx(ndh, a) * v_ggx(ndl, ndv, a) * fr;
}
