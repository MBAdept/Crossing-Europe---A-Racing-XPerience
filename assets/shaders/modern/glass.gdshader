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
