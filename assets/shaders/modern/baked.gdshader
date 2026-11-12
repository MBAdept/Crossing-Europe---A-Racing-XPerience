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
// M2ZS1: albedo factor at ce_night = 1 (1 = unchanged, every material but the one below). builders/props.gd sets it
// on its copy for the pylons of the cable-stayed bridges ("prefer_proc"): Arcade draws them procedurally as concrete ×
// the ambient light at night, while the moon lights the light-concrete faces of the model (the Köhlbrandbrücke's
// pylons were far brighter than Arcade's at 22:00).
uniform float night_albedo = 1.0;
// FIX1 (QA QB-03): a landmark model keeps Arcade's landmark law (RoadRenderer.landmark_fade) – visible up to
// L = clamp(visibility × x, min(visibility, 600), max(y, visibility)), fading out over its last 28 % (ordered dither),
// its colour going towards the fog colour × 1.15 by 0.85 × the haze; x <= 0: an ordinary prop (builders/props.gd sets
// it on a duplicate of the model's material).
uniform vec2 landmark_law = vec2(0.0, 1900.0);

// R4: snow on the faces that look up (roofs, ledges, rocks) on a snow stage – display albedo, darker at night
uniform vec3 snow_albedo = vec3(0.86, 0.88, 0.91);
uniform float snow_night = 0.3;

global uniform float ce_night;
global uniform float ce_snow;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;

#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

void fragment() {
	float dist = length(VERTEX);
	float lm_l = 0.0;
	bool lights_only = false;
	vec3 e = texture(emit_tex, UV).rgb;
	// how much of the pixel is lit at night (the emission atlas is black where nothing shines)
	float light_cover = clamp(max(e.r, max(e.g, e.b)) * 3.0, 0.0, 1.0) * clamp(ce_night, 0.0, 1.0);
	if (landmark_law.x > 0.0) {
		float vis = ce_fog_range.y;
		lm_l = clamp(vis * landmark_law.x, min(vis, 600.0), max(landmark_law.y, vis));
		float keep = 1.0 - smoothstep(lm_l * 0.72, lm_l, dist);
		float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (keep < 0.999 && dither >= keep) {
			// M2INT (Arcade's RoadRenderer._draw_landmark): at night a landmark's illumination stays visible up to
			// landmark_law.y (render.landmark_far_m) when the model itself has faded with the night's short sight –
			// only its lit pixels, unfogged, fading over the last 20 % of that range
			float lights_keep = 1.0 - smoothstep(landmark_law.y * 0.8, landmark_law.y, dist);
			if (dither >= light_cover * lights_keep) {
				discard;
			}
			lights_only = true;
		}
	}
	vec4 a = texture(albedo_tex, UV);
#ifdef CE_CUTOUT
	if (a.a < 0.5) {
		discard;
	}
#endif
	// night_albedo = 1: a factor of exactly 1.0 – the picture of every other material stays as it was
	vec3 alb = a.rgb * (1.0 - (1.0 - night_albedo) * clamp(ce_night, 0.0, 1.0));
	if (ce_snow > 0.0) {
		float up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
		float k = clamp(ce_snow, 0.0, 1.0) * smoothstep(0.5, 0.82, up) * (1.0 - light_cover);
		alb = mix(alb, snow_albedo * (1.0 - snow_night * clamp(ce_night, 0.0, 1.0)), k);
	}
	ALBEDO = lights_only ? vec3(0.0) : alb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = lights_only ? 0.0 : 0.35;
	// colours are sRGB-encoded here (the engine linearises ALBEDO and EMISSION): energy as pow(e, 1 / 2.2)
	EMISSION = e * pow(ce_night * emit_energy, 0.4545);
	if (lights_only) {
		FOG = vec4(0.0);
	} else if (lm_l > 0.0) {
		// Arcade hazes the picture of a landmark but lays its illumination over it unhazed
		float haze = clamp((dist - ce_fog_range.x) / max(lm_l - ce_fog_range.x, 1.0), 0.0, 1.0) * 0.85;
		haze *= 1.0 - light_cover;
		FOG = vec4(ce_fog_unshow(min(a.rgb * ce_fog_color.rgb * 1.15, vec3(1.0))), haze);
	} else {
		FOG = ce_arcade_fog(alb, dist, ce_fog_color, ce_fog_range);
	}
}
