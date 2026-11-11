// Modern: the terrain ribbon beside the road (scripts/race3d/builders/terrain.gd; docs/renderer-modern-gelaende.md).
// A lit surface (sun with shadows, ambient light, the player's headlights, fog – all from the environment) whose
// colour is painted here instead of being one flat tone:
//   beside the road   gravel strip at the shoulder, mown verge with mowing stripes, the ditch with darker, earthier
//                     ground – only where the ground is vegetation (COLOR.a)
//   beyond 16–34 m    the open ground of inc/ground.gdshaderinc: fields in their own shades, patches in the accent
//                     colour of the scenery, furrows, borders, soft blotches
//   everywhere        fine grain near the camera (it fades with the distance: no shimmer far away)
//   ce_snow           snow cover (Arcade: 94 % Palette.SNOW_GROUND), thinner on the gravel strip
//   ce_wet            darker and smoother (it glints towards the sun)
//   outer ring        fades into the far ground (colour and normal), so the plane of layers/far_ground.gd continues
//                     the ribbon without a seam; the skirt below the outer edge shows the same tone
//   water             (bridges) a smooth surface in the water colour of the scenery
//   light pools       lamps and the traffic's headlights on the ground: inc/pools.gdshaderinc
// Vertex data (builders/terrain.gd):
//   COLOR.rgb   ground tone, sRGB (the two grass tones of the scenery as bands near the road, their mean farther out;
//               the water colour on a bridge)          COLOR.a   nature: 1 vegetation … 0 paved (city centre)
//   UV          x = metres beyond the shoulder, y = road position (m, wrapped at 3,072 m per chunk)
//   UV2         x = metres from the centreline (signed), y = fade into the far ground (0 … 1 at the outer edge)
//   CUSTOM0     rgb = accent colour of the patches, a = share of the patches (0..1); a = -1 marks water
// Load only after ModernMaterials.ensure_globals() – never with preload().
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
#include "res://assets/shaders/modern/inc/ground.gdshaderinc"

uniform float detail = 1.0;                   // strength of everything painted here (0 = the flat vertex tones)
uniform float field_from_m = 16.0;            // the field structure fades in between these distances beyond the shoulder
uniform float field_full_m = 34.0;

global uniform float ce_snow;
global uniform float ce_wet;

varying vec3 v_world;                         // origin-relative world position
varying vec4 v_style;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_style = CUSTOM0;
}

void fragment() {
	vec2 p = ce_ground_pos(v_world);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float lat = UV.x;
	float nature = COLOR.a;
	float fade_far = clamp(UV2.y, 0.0, 1.0);
	float water = smoothstep(-0.25, -0.75, v_style.a);
	float amount = max(v_style.a, 0.0);
	float field = smoothstep(field_from_m, field_full_m, lat);
	vec3 tone = ce_ground_open(COLOR.rgb, v_style.rgb, amount, nature, p, dist, field);
	// fine grain at two scales, near the camera only
	float g1 = texture(ground_noise, p / CE_GROUND_GRAIN_M).r;
	float g2 = texture(ground_noise, p / (CE_GROUND_GRAIN_M * 0.23) + vec2(0.31, 0.57)).r;
	float blot = texture(ground_noise, p / (CE_GROUND_BLOT_M * 0.25) + vec2(0.61, 0.23)).g;
	float near_k = 1.0 - smoothstep(10.0, 85.0, dist);
	// the strips beside the road (vegetation only)
	float jitter = (g1 - 0.5) * 0.6 + (blot - 0.5) * 0.5;
	float gravel = (1.0 - smoothstep(0.45, 1.25, lat + jitter)) * nature;
	float verge = smoothstep(0.9, 1.7, lat + jitter * 0.4) * (1.0 - smoothstep(4.2, 6.0, lat)) * nature;
	float ditch = smoothstep(4.6, 6.4, lat + jitter) * (1.0 - smoothstep(8.5, 12.5, lat + jitter)) * nature;
	float mow = step(0.5, fract(lat / 1.45)) - 0.5;
	tone = mix(tone, tone * vec3(1.07, 1.06, 0.92), verge * 0.55);
	tone *= 1.0 + mow * 0.05 * verge * (1.0 - smoothstep(60.0, 160.0, dist));
	tone = mix(tone, tone * vec3(0.74, 0.76, 0.62), ditch * 0.6);
	tone = mix(tone, vec3(0.37, 0.31, 0.23), ditch * ditch * 0.32 * smoothstep(0.42, 0.7, blot));
	vec3 grav = vec3(0.60, 0.57, 0.50) * (0.82 + 0.36 * g2);
	tone = mix(tone, grav, gravel * 0.9);
	// paved ground: slabs (2 m) with thin joints
	vec2 slab = abs(fract(p / 2.0) - 0.5);
	float joint = smoothstep(0.47, 0.495, max(slab.x, slab.y)) * (1.0 - nature) * (1.0 - smoothstep(25.0, 70.0, dist));
	tone *= 1.0 - 0.10 * joint;
	tone *= 1.0 + ((g1 - 0.5) * 0.20 + (g2 - 0.5) * 0.16) * near_k * mix(0.45, 1.0, nature);
	tone = mix(COLOR.rgb, tone, detail);
	// snow: on everything but the water, thin and dirty on the gravel strip
	float snow = ce_ground_snow(ce_snow, p) * (1.0 - 0.45 * gravel);
	vec3 snow_col = CE_GROUND_SNOW * (0.955 + 0.045 * blot + (g1 - 0.5) * 0.03 * near_k);
	tone = mix(tone, snow_col, snow);
	// wet ground is darker
	tone *= 1.0 - 0.16 * ce_wet * (1.0 - snow);
	// the outer ring becomes the far ground
	vec3 far_tone = ce_ground_far(p, dist);
	far_tone = mix(far_tone, CE_GROUND_SNOW, ce_ground_snow(ce_snow, p));
	far_tone *= 1.0 - 0.16 * ce_wet * (1.0 - ce_ground_snow(ce_snow, p));
	tone = mix(tone, far_tone, fade_far);
	// water under a bridge
	float ripple = texture(ground_noise, p / 23.0 + vec2(0.17, 0.43)).g;
	vec3 water_col = COLOR.rgb * (0.92 + 0.16 * ripple);
	tone = mix(tone, water_col, water);
	ALBEDO = clamp(tone, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(mix(0.95, 0.6, max(ce_wet, snow * 0.5)), 0.5, water);
	SPECULAR = mix(0.2, 0.3, water);
	METALLIC = 0.0;
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, fade_far * 0.85));
	EMISSION = ce_pools_emission(ALBEDO, v_world);
}
