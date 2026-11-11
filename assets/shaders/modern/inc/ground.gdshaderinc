// Modern: the look of open ground – shared by terrain.gdshader (the ribbon beside the road) and far_ground.gdshader
// (the plane beyond it), so that both show the same colours and the same pattern at the same place and the ribbon
// can fade into the plane without a seam (contract D16).
//
// Use:   #include "res://assets/shaders/modern/inc/ground.gdshaderinc"
//        vec2 p = ce_ground_pos(world_pos);                       // pattern position (m)
//        vec3 tone = ce_ground_open(base, accent, amount, nature, p, dist, field);
// Colours are sRGB-encoded display values, as fragment() writes ALBEDO in GL Compatibility (docs/modelle.md §4).
//
//   ground_noise     the detail texture of GroundLook.noise_texture(): r fine grain, g soft blotches, b cell value of
//                    a Voronoi pattern ("fields"), a distance to the border of that cell – all 0..1, tiling
//   pattern_origin   added to the origin-relative world position: the owner of the material subtracts every shift of
//                    the floating origin (ModernRenderer.rebased), so the pattern stays where it is on the ground
//   far_color …      ground tone, patch colour, patch share and vegetation share of the ground far away
//                    (GroundLook.far_look): what the plane shows and what the outer ring of the ribbon fades into
// Tile sizes divide 3,072 m (the wrap of the road coordinate in UV.y of the terrain), should the pattern ever have
// to follow road coordinates instead of the world (the sheared fallback mapping of the contract, §8).
// Names: everything declared here starts with ce_ground, ground_, pattern_ or far_.

uniform sampler2D ground_noise : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 pattern_origin = vec3(0.0);
uniform vec3 far_color = vec3(0.36, 0.58, 0.25);
uniform vec3 far_accent = vec3(0.71, 0.68, 0.30);
uniform float far_amount = 0.4;
uniform float far_nature = 1.0;

const float CE_GROUND_FIELD_M = 768.0;        // tile of the field pattern (3 m per texel)
const float CE_GROUND_BLOT_M = 96.0;          // tile of the blotches
const float CE_GROUND_GRAIN_M = 8.0;          // tile of the grain
const vec3 CE_GROUND_SNOW = vec3(0.933, 0.949, 0.965);   // Palette.SNOW_GROUND

// Pattern position (m) of an origin-relative world position.
vec2 ce_ground_pos(vec3 world_pos) {
	return world_pos.xz + pattern_origin.xz;
}

// Tone of open ground at pattern position p, seen from `dist` metres:
//   base     ground tone (the grass of the scenery)          accent   colour of the patches (grain, heather, rock …)
//   amount   share of the fields that are patches, 0..1      nature   1 vegetation … 0 paved ground of a city centre
//   field    how much of the field structure shows, 0..1 (0 on the verge beside the road)
vec3 ce_ground_open(vec3 base, vec3 accent, float amount, float nature, vec2 p, float dist, float field) {
	vec4 cell = texture(ground_noise, p / CE_GROUND_FIELD_M);
	float blot = texture(ground_noise, p / CE_GROUND_BLOT_M).g;
	float big = texture(ground_noise, p / (CE_GROUND_BLOT_M * 5.0) + vec2(0.37, 0.11)).g;
	// far away a field is smaller than a pixel: the texture filter blurs the cell values, so the pattern is faded
	// into its mean as the footprint of a pixel grows beyond a few texels (3 m each)
	vec2 fwm = fwidth(p);
	float foot = max(fwm.x, fwm.y);            // metres of ground under one pixel (the longer side)
	float far = max(smoothstep(7.5, 42.0, foot), smoothstep(700.0, 1300.0, dist));
	// every field has its own shade of the ground tone
	float shade = fract(cell.b * 5.3);
	vec3 tone = base * (1.0 + (shade - 0.5) * 0.15 * field * (1.0 - far));
	// patches: the share `amount` of the fields; far away only their mean is left
	float m = 1.0 - smoothstep(amount - 0.05, amount + 0.05, cell.b);
	m = mix(m, amount * 0.8, far) * field;
	vec3 patch_col = accent * (0.9 + 0.2 * fract(cell.b * 11.7));
	tone = mix(tone, patch_col, m * 0.85);
	// lines inside a field (furrows, mowing), each field in its own direction; none at its border, none far away
	float inside = smoothstep(0.03, 0.12, cell.a);
	float ang = cell.b * 19.0;
	float line = sin(dot(p, vec2(cos(ang), sin(ang))) * 1.4);
	float near_k = (1.0 - smoothstep(0.7, 2.2, foot)) * field * nature;
	tone *= 1.0 + line * 0.035 * inside * near_k * (0.5 + m);
	// field borders: a darker line (hedge, track); on paved ground the joints between the slabs
	float border = (1.0 - smoothstep(0.015, 0.05, cell.a)) * field * (1.0 - smoothstep(180.0, 420.0, dist));
	tone *= 1.0 - 0.14 * border * mix(0.45, 1.0, nature);
	// soft blotches at two scales; seen at a grazing angle the smaller ones would smear into streaks: they go as
	// the footprint of a pixel outgrows them
	float blot_k = 1.0 - smoothstep(1.2, 5.0, foot);
	tone *= 1.0 + (blot - 0.5) * 0.16 * blot_k + (big - 0.5) * 0.10 * (1.0 - smoothstep(6.0, 25.0, foot));
	return tone;
}

// The ground far away at pattern position p (what far_ground.gdshader shows).
vec3 ce_ground_far(vec2 p, float dist) {
	return ce_ground_open(far_color, far_accent, far_amount, far_nature, p, dist, 1.0);
}

// Snow cover (0..1) of open ground for the global snow amount: a little patchy while it is thin.
float ce_ground_snow(float snow, vec2 p) {
	float blot = texture(ground_noise, p / (CE_GROUND_BLOT_M * 0.5) + vec2(0.13, 0.71)).g;
	return smoothstep(0.15, 0.55, snow * (0.7 + 0.6 * blot)) * 0.94;
}
