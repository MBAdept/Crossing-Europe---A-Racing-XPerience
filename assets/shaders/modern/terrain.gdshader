// Modern: the terrain ribbon beside the road (scripts/race3d/builders/terrain.gd; docs/renderer-modern-gelaende.md).
// A lit surface (sun with shadows, ambient light, the player's headlights, fog – all from the environment) whose
// colour is painted here instead of being one flat tone:
//   near the road     Arcade's two grass tones of the scenery in bands across the road (render.stripes.grass
//                     segments each), fading into their mean from 6 to 40 m beyond the shoulder
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
//   low beam          the player's headlight cone on the ground (inc/headlight.gdshaderinc), like the road: the
//                     mesh is on render layer 2 (builders/road.gd GROUND_LAYERS), the real spots of the lights
//                     layer leave it out. Arcade's reflection factors: grass 0.45, the gravel strip 0.6, paved
//                     ground 0.8 (RoadRenderer._draw_ground / _shade)
// Every pattern is anti-aliased by the footprint of the pixel (inc/ground.gdshaderinc).
// Light (RINT-B): the ground law of inc/ground_law.gdshaderinc – the engine's ambient pass is off, the base pass is
// written as EMISSION so that level ground in the light shows Arcade's colour (albedo × palette ambient) at every
// albedo and hour; shadows take the sun's part away, slopes towards the sun get more. Fog: Arcade's law for things
// beside the road (at most 70 % towards the brightened fog colour), like layers/far_ground.gd – see the end of
// fragment().
// Vertex data (builders/terrain.gd):
//   COLOR.rgb   mean ground tone, sRGB (the mean of the scenery's two grass tones, the outskirts -> centre blend of
//               the City Limits; the water colour on a bridge)          COLOR.a   nature: 1 vegetation … 0 paved
//   CUSTOM1     rgb = half the difference of the two grass tones (tone 0 = COLOR + it, tone 1 = COLOR - it),
//               a = how much of the bands shows (1 near the road … 0 from 40 m beyond the shoulder)
//   UV          x = metres beyond the shoulder, y = band phase (floor even: tone 0, odd: tone 1)
//   UV2         x = metres from the centreline (signed), y = fade into the far ground (0 … 1 at the outer edge)
//   CUSTOM0     rgb = accent colour of the patches, a = share of the patches (0..1); a = -1 marks water
// Load only after ModernMaterials.ensure_globals() – never with preload().
shader_type spatial;
render_mode cull_back, depth_draw_opaque, ambient_light_disabled;

#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
#include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
#include "res://assets/shaders/modern/inc/ground.gdshaderinc"

uniform float detail = 1.0;                   // strength of everything painted here (0 = the flat vertex tones)
uniform float field_from_m = 16.0;            // the field structure fades in between these distances beyond the shoulder
uniform float field_full_m = 34.0;
uniform float band_contrast = 1.0;            // strength of Arcade's two grass tones near the road

global uniform float ce_snow;
global uniform float ce_wet;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;

varying vec3 v_world;                         // origin-relative world position
varying vec4 v_style;
varying vec4 v_band;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_style = CUSTOM0;
	v_band = CUSTOM1;
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
	// Arcade's bands: +1 on even bands (tone 0), -1 on odd ones; the mean once they are thinner than a pixel
	float band = ce_ground_stripes(UV.y, 2.0) * 2.0;
	vec3 base = COLOR.rgb + v_band.rgb * (v_band.a * band * band_contrast);
	vec3 tone = ce_ground_open(base, v_style.rgb, amount, nature, p, dist, field);
	// fine grain at two scales, near the camera only
	float g1 = texture(ground_noise, p / CE_GROUND_GRAIN_M).r;
	float g2 = texture(ground_noise, p / (CE_GROUND_GRAIN_M * 0.23) + vec2(0.31, 0.57)).r;
	float blot = texture(ground_noise, p / (CE_GROUND_BLOT_M * 0.25) + vec2(0.61, 0.23)).g;
	float near_k = 1.0 - smoothstep(10.0, 85.0, dist);
	vec2 fwm = fwidth(p);
	float foot = max(fwm.x, fwm.y);
	// the strips beside the road (vegetation only)
	float jitter = (g1 - 0.5) * 0.6 + (blot - 0.5) * 0.5;
	float gravel = (1.0 - smoothstep(0.45, 1.25, lat + jitter)) * nature;
	float verge = smoothstep(0.9, 1.7, lat + jitter * 0.4) * (1.0 - smoothstep(4.2, 6.0, lat)) * nature;
	float ditch = smoothstep(4.6, 6.4, lat + jitter) * (1.0 - smoothstep(8.5, 12.5, lat + jitter)) * nature;
	tone = mix(tone, tone * vec3(1.06, 1.05, 0.93), verge * 0.5);
	tone *= 1.0 + ce_ground_stripes(lat, 2.9) * 0.08 * verge;          // mowing stripes along the road
	tone = mix(tone, tone * vec3(0.80, 0.82, 0.70), ditch * 0.55);
	tone = mix(tone, vec3(0.40, 0.34, 0.26), ditch * ditch * 0.2 * smoothstep(0.5, 0.75, blot) * near_k);
	vec3 grav = vec3(0.60, 0.57, 0.50) * (0.82 + 0.36 * g2);
	tone = mix(tone, grav, gravel * 0.9);
	// paved ground: slabs (2 m) with thin joints, near only
	vec2 slab = abs(fract(p / 2.0) - 0.5);
	float joint = smoothstep(0.47, 0.495, max(slab.x, slab.y)) * (1.0 - nature) * (1.0 - smoothstep(0.02, 0.06, foot));
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
	// the base pass of the ground law, the light pools and the low beam on top (Arcade adds them in display values)
	float reflect = mix(mix(0.8, 0.45, nature) + 0.15 * gravel, 0.45, water);
	vec3 extra = ce_pools(v_world) * reflect + ce_headlight_light(v_world, reflect);
	EMISSION = ce_pools_encode(ce_ground_base_lin(ALBEDO) + ce_pools_to_lin(ALBEDO) * extra);
	// fog (RINT-B, lead decision): Arcade's law for what lies beside the road at the end of the sight, as on the far
	// ground – towards the brightened fog colour by 0.7 × the fog amount of the distance (RoadRenderer._modulate), never
	// more fog than Arcade (F4). The engine's depth fog turned valley ground beyond the sight into pure fog colour – a
	// pale band that read as a lake (T4). FOG replaces the engine fog for this material and is mixed in linear light.
	float fog_t = clamp((dist - ce_fog_range.x) / max(ce_fog_range.y - ce_fog_range.x, 1.0), 0.0, 1.0);
	FOG = vec4(ce_ground_unshow(min(ALBEDO * ce_fog_color.rgb * 1.25, vec3(1.0))), 0.7 * fog_t);
}
