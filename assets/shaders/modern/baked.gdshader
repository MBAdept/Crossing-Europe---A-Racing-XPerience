// Modern, material classes "baked" and "baked_cutout": buildings, landmarks, rocks and props with a baked
// atlas (docs/modelle.md). UV = atlas coordinates inside 0..1. Night: emission atlas x ce_night.
// ModernMaterials builds the cut-out variant from this file by defining CE_CUTOUT (alpha scissor, both
// faces drawn: railings, fences, lattice parts). Load only through ModernMaterials - never with preload().
shader_type spatial;
#ifdef CE_CUTOUT
render_mode cull_disabled;
#else
render_mode cull_back;
#endif

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float roughness = 0.9;                // one number per model (manifest "roughness")
uniform float emit_energy = 1.6;              // linear energy of lit windows / floodlight at ce_night = 1

global uniform float ce_night;

void fragment() {
	vec4 a = texture(albedo_tex, UV);
#ifdef CE_CUTOUT
	if (a.a < 0.5) {
		discard;
	}
#endif
	ALBEDO = a.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	// colours are sRGB-encoded here (the engine linearises ALBEDO and EMISSION): energy as pow(e, 1 / 2.2)
	EMISSION = texture(emit_tex, UV).rgb * pow(ce_night * emit_energy, 0.4545);
}
