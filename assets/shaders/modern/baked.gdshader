// Modern, material classes "baked" and "baked_cutout": buildings, landmarks, rocks and props with a baked
// atlas (docs/modelle.md). UV = atlas coordinates inside 0..1. Night: emission atlas x ce_night.
// ModernMaterials builds the cut-out variant from this file by defining CE_CUTOUT (alpha scissor, both
// faces drawn: railings, fences, lattice parts). Load only through ModernMaterials - never with preload().
// Fog: Arcade's law for things in the landscape (inc/fog_law.gdshaderinc, FIX1) instead of the engine's depth fog.
// R7c: the level of detail per instance with a dither cross-fade (inc/lod_band.gdshaderinc, A-22) and the far light
// beyond the reach of the real-time shadows (light() below: the engine's own model – Lambert + Schlick-GGX – with the
// directional light lowered to the model's mean shadowed share there, lead decision 2 of R7c).
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
// R7c: share of the facade's lit colour a lit window pixel gives up for its light (fragment(), lead decision 4).
// The defaults of the R7c uniforms below keep the earlier picture; builders/props.gd sets them on the materials of its
// models (PROP_LOOK) – the panels of stations, borders and gantries (lettering) stay as they were
uniform float window_cover = 0.0;
// R7c: the night atlas reaches its full light at ce_night = window_ramp (Arcade: palette lights 0.65 at 19:30, 1 from 21:00)
uniform float window_ramp = 1.0;
// R7c: mip bias of the alpha test of the cut-out variant (fragment(), lead decision 3)
uniform float cutout_bias = 0.0;
// R7c: mip bias of the colour, growing from albedo_bias_m.x to albedo_bias_m.y metres (lead decision 3: the painted beams
// and bars of far facades shimmer less; near the camera the atlas stays as sharp as it was)
uniform float albedo_bias = 0.0;
uniform vec2 albedo_bias_m = vec2(30.0, 120.0);
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
#include "res://assets/shaders/modern/inc/lod_band.gdshaderinc"
global uniform vec3 ce_sun_dir;
#include "res://assets/shaders/modern/inc/cloud_shadow.gdshaderinc"
varying float v_cloud;     // R7d: the cloud shadow on this object's direct light (ce_cloud_sun_v, its origin)

// RINT-M2 (A-19): the placement tint of the model (MultiMesh custom data r, g, b, 1 – builders/props.gd); white without
varying vec3 v_tint;
varying float v_spec;      // R7c: 0 for the lit pixels of a far landmark (SPECULAR 0 there), 1 elsewhere

void vertex() {
	v_tint = INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0);
	v_lod_d = ce_lod_distance(MODEL_MATRIX, MAIN_CAM_INV_VIEW_MATRIX);
	v_lod_shadow = ce_lod_shadow_pass(CAMERA_POSITION_WORLD, MAIN_CAM_INV_VIEW_MATRIX);
	if (ce_lod_hidden(v_lod_d)) {
		VERTEX = vec3(0.0);
	}
	v_lod_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	v_cloud = ce_cloud_sun_v((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, ce_sun_dir);
}

void fragment() {
	if (ce_lod_discard(v_lod_d, v_lod_shadow, FRAGCOORD.xy)) {
		discard;
	}
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
	vec4 a = texture(albedo_tex, UV, albedo_bias * smoothstep(albedo_bias_m.x, albedo_bias_m.y, dist));
	a.rgb *= v_tint;    // Arcade multiplies the sprite by the placement tint (sRGB, as the sprite)
#ifdef CE_CUTOUT
	// R7c (lead decision 3): the alpha test reads the cut-out from a mip level cutout_bias coarser than the colour – the
	// bake keeps the coverage of every mip level (cut_fill, A-22), and the coarser level holds the thin railings, bars and
	// leaf cards steady from pixel to pixel instead of letting them flicker while the camera moves. The test stays at 0.5.
	if (texture(albedo_tex, UV, cutout_bias).a < 0.5) {
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
	// R7c (lead decision 4, windows at dusk): a lit pixel of the night atlas REPLACES the facade's lit colour by its
	// light as the night comes, as Arcade lays the light layer of a sprite over it (mix by alpha x lights) – added on top
	// of a facade still lit by the dusk sky the windows hardly showed at 19:30. Not where the night atlas is off
	// (emit_energy 0: the pylons of the cable-stayed bridges keep their concrete)
	float night_k = clamp(ce_night / max(window_ramp, 0.01), 0.0, 1.0);
	float cover_k = window_cover * step(0.001, emit_energy) * clamp(max(e.r, max(e.g, e.b)) * 3.0, 0.0, 1.0) * night_k;
	ALBEDO = lights_only ? vec3(0.0) : alb * (1.0 - cover_k);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = lights_only ? 0.0 : 0.35;
	v_spec = lights_only ? 0.0 : 1.0;
	// colours are sRGB-encoded here (the engine linearises ALBEDO and EMISSION): energy as pow(e, 1 / 2.2)
	EMISSION = e * pow(night_k * emit_energy, 0.4545);
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

// R7c: the engine's lighting model for this material (GL Compatibility 4.7: Lambert diffuse, Schlick-GGX specular with
// f0 = 0.16 x SPECULAR^2 and f90 = clamp(50 f0, 0, 1)) – unchanged near the camera – with the attenuation of the
// directional light taken through the far light law of inc/lod_band.gdshaderinc (ce_far_attenuation).
float ce_d_ggx(float ndh, float a) {
	float t = ndh * a;
	float k = a / (1.0 - ndh * ndh + t * t);
	return k * k * (1.0 / PI);
}

float ce_v_ggx(float ndl, float ndv, float a) {
	return 0.5 / mix(2.0 * ndl * ndv, ndl + ndv, a);
}

void light() {
	float att = ce_far_attenuation(ATTENUATION, LIGHT_IS_DIRECTIONAL, v_lod_depth);
	att *= LIGHT_IS_DIRECTIONAL ? v_cloud : 1.0;          // R7d: under a cloud
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * att * ndl * (1.0 / PI);
	if (ROUGHNESS > 0.0 && v_spec > 0.5) {
		vec3 h = normalize(VIEW + LIGHT);
		float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
		float ndv = max(dot(NORMAL, VIEW), 1e-4);
		float ldh = clamp(dot(LIGHT, h), 0.0, 1.0);
		float a = ROUGHNESS * ROUGHNESS;
		float f0 = 0.16 * 0.35 * 0.35;
		float f90 = clamp(50.0 * f0, 0.0, 1.0);
		float f = f0 + (f90 - f0) * pow(1.0 - ldh, 5.0);
		SPECULAR_LIGHT += LIGHT_COLOR * att * SPECULAR_AMOUNT * ndl * ce_d_ggx(ndh, a) * ce_v_ggx(ndl, ndv, a) * f;
	}
}
