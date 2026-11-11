// Modern, material classes "baked" and "baked_cutout": buildings, landmarks, rocks and props with a baked
// atlas (docs/modelle.md). UV = atlas coordinates inside 0..1. Night: emission atlas x ce_night.
// ModernMaterials builds the cut-out variant from this file by defining CE_CUTOUT (alpha scissor, both
// faces drawn: railings, fences, lattice parts). Load only through ModernMaterials - never with preload().
// Fog: Arcade's law for things in the landscape (inc/fog_law.gdshaderinc, FIX1) instead of the engine's depth fog.
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
// FIX1 (QA QB-03): a landmark model keeps Arcade's landmark law (RoadRenderer.landmark_fade) – visible up to
// L = clamp(visibility × x, min(visibility, 600), max(y, visibility)), fading out over its last 28 % (ordered dither),
// its colour going towards the fog colour × 1.15 by 0.85 × the haze; x <= 0: an ordinary prop (builders/props.gd sets
// it on a duplicate of the model's material).
uniform vec2 landmark_law = vec2(0.0, 1900.0);

global uniform float ce_night;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;

#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

void fragment() {
	float dist = length(VERTEX);
	float lm_l = 0.0;
	if (landmark_law.x > 0.0) {
		float vis = ce_fog_range.y;
		lm_l = clamp(vis * landmark_law.x, min(vis, 600.0), max(landmark_law.y, vis));
		float keep = 1.0 - smoothstep(lm_l * 0.72, lm_l, dist);
		if (keep < 0.999 && fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910))) >= keep) {
			discard;
		}
	}
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
	if (lm_l > 0.0) {
		float haze = clamp((dist - ce_fog_range.x) / max(lm_l - ce_fog_range.x, 1.0), 0.0, 1.0) * 0.85;
		FOG = vec4(ce_fog_unshow(min(a.rgb * ce_fog_color.rgb * 1.15, vec3(1.0))), haze);
	} else {
		FOG = ce_arcade_fog(a.rgb, dist, ce_fog_color, ce_fog_range);
	}
}
