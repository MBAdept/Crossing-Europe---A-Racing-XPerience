// Modern, material class "glass": vehicle glazing at lod0 / show and clear lamp lenses (docs/modelle.md).
//   COLOR.rgb  tint as sRGB bytes        COLOR.a  opacity        UV  (roughness, metallic)
// Alpha blended, no depth write; the opacity rises towards grazing angles (Fresnel), so glass mirrors the
// sky at the edges. Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

instance uniform float fade = 1.0;            // path-distance fade (dither discard, as class vpbr)
instance uniform float sun = 1.0;             // 0 inside tunnels: masks the directional light

uniform float fresnel_boost = 0.85;

void fragment() {
	if (fade < 0.999) {
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (d >= fade) {
			discard;
		}
	}
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALBEDO = COLOR.rgb;         // sRGB as stored: the Compatibility renderer linearises ALBEDO itself
	ROUGHNESS = max(UV.x, 0.02);
	METALLIC = UV.y;
	SPECULAR = 0.9;
	ALPHA = mix(COLOR.a, 1.0, f * fresnel_boost);
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
