// Modern: the look of open ground – shared by terrain.gdshader (the ribbon beside the road) and far_ground.gdshader
// (the plane beyond it), so that both show the same colours and the same pattern at the same place and the ribbon
// can fade into the plane without a seam (contract D16).
//
// Use:   #include "res://assets/shaders/modern/inc/ground.gdshaderinc"
//        vec2 p = ce_ground_pos(world_pos);                       // pattern position (m)
//        vec3 tone = ce_ground_open(base, accent, amount, nature, p, dist, field);
// Colours are sRGB-encoded display values, as fragment() writes ALBEDO in GL Compatibility (docs/modelle.md §4).
//
//   ground_noise     the detail texture of GroundLook.noise_texture(): r fine grain, g soft blotches (b, a: a cell
//                    pattern no longer used here) – all 0..1, tiling
//   pattern_origin   added to the origin-relative world position: the owner of the material subtracts every shift of
//                    the floating origin (ModernRenderer.rebased), so the pattern stays where it is on the ground
//   far_color …      ground tone, patch colour, patch share and vegetation share of the ground far away
//                    (GroundLook.far_look): what the plane shows and what the outer ring of the ribbon fades into
// Fields: a Voronoi pattern computed here (cells of about 70 x 110 m, every cell its own shade, a share `amount` of
// them in the accent colour, furrows in their own direction, a darker border). It is computed, not read from a
// texture: a filtered cell texture blurs the cell values at a distance and every per-cell value derived from them
// (shade, colour, direction) turned into stripes. Everything finer than a few pixels fades into its mean by the
// footprint of the pixel on the ground (fwidth), never by distance alone: the far rows of a slope seen at a grazing
// angle stay calm.
// Names: everything declared here starts with ce_ground, ground_, pattern_ or far_.

uniform sampler2D ground_noise : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 pattern_origin = vec3(0.0);
uniform vec3 far_color = vec3(0.36, 0.58, 0.25);
uniform vec3 far_accent = vec3(0.71, 0.68, 0.30);
uniform float far_amount = 0.4;
uniform float far_nature = 1.0;

const vec2 CE_GROUND_FIELD_M = vec2(110.0, 72.0);   // size of a field cell along / across its long side
const float CE_GROUND_FIELD_TURN = 0.41;          // the long side of the fields against the world's x axis (rad)
const float CE_GROUND_BLOT_M = 96.0;          // tile of the blotches
const float CE_GROUND_GRAIN_M = 8.0;          // tile of the grain
const vec3 CE_GROUND_SNOW = vec3(0.933, 0.949, 0.965);   // Palette.SNOW_GROUND

// Pattern position (m) of an origin-relative world position.
vec2 ce_ground_pos(vec3 world_pos) {
	return world_pos.xz + pattern_origin.xz;
}

// Hash of an integer cell -> two numbers 0..1 (no sine: the same on every GPU).
vec2 ce_ground_hash2(vec2 c) {
	vec3 q = fract(vec3(c.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// The two nearest fields at pattern position p: their ids (0..1, uniform) and the distance (m) to the border between
// them – the bisector of the two nearest cell sites, exact except near the corners of a field.
void ce_ground_fields(vec2 p, out float id1, out float id2, out float edge_m) {
	float c = cos(CE_GROUND_FIELD_TURN);
	float s = sin(CE_GROUND_FIELD_TURN);
	vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y) / CE_GROUND_FIELD_M;
	vec2 n = floor(q);
	vec2 f = q - n;
	float d1 = 64.0;
	float d2 = 64.0;
	vec2 r1 = vec2(0.0);
	vec2 r2 = vec2(1.0);
	vec2 c1 = n;
	vec2 c2 = n;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (ce_ground_hash2(n + g) - 0.5) * 0.8 - f;
			vec2 rm = r * CE_GROUND_FIELD_M;          // metres: the border is a bisector in the world, not in q
			float d = dot(rm, rm);
			if (d < d1) {
				d2 = d1; r2 = r1; c2 = c1;
				d1 = d; r1 = rm; c1 = n + g;
			} else if (d < d2) {
				d2 = d; r2 = rm; c2 = n + g;
			}
		}
	}
	edge_m = max(dot(0.5 * (r1 + r2), normalize(r2 - r1 + vec2(1.0e-6))), 0.0);
	id1 = ce_ground_hash2(c1 + vec2(71.3, 19.7)).x;
	id2 = ce_ground_hash2(c2 + vec2(71.3, 19.7)).x;
}

// Colour of one field: its own shade of the ground tone; the share `amount` of the fields in the accent colour.
vec3 ce_ground_field_tone(float id, vec3 base, vec3 accent, float amount) {
	vec3 tone = base * (1.0 + (fract(id * 7.31) - 0.5) * 0.14);
	vec3 patch_col = accent * (0.9 + 0.2 * fract(id * 13.7));
	return mix(tone, patch_col, step(id, amount) * 0.85);
}

// Mean colour of the fields (what they become far away).
vec3 ce_ground_field_mean(vec3 base, vec3 accent, float amount) {
	return mix(base, accent, clamp(amount, 0.0, 1.0) * 0.85);
}

// Tone of open ground at pattern position p, seen from `dist` metres:
//   base     ground tone (the grass of the scenery)          accent   colour of the patches (grain, heather, rock …)
//   amount   share of the fields that are patches, 0..1      nature   1 vegetation … 0 paved ground of a city centre
//   field    how much of the field structure shows, 0..1 (0 on the verge beside the road)
vec3 ce_ground_open(vec3 base, vec3 accent, float amount, float nature, vec2 p, float dist, float field) {
	vec2 fwm = fwidth(p);
	float foot = max(fwm.x, fwm.y);            // metres of ground under one pixel (the longer side)
	// the field structure fades into its mean once a field is only a few pixels across
	float far = max(smoothstep(9.0, 30.0, foot), smoothstep(800.0, 1400.0, dist));
	float id1;
	float id2;
	float edge_m;
	ce_ground_fields(p, id1, id2, edge_m);
	vec3 t1 = ce_ground_field_tone(id1, base, accent, amount);
	vec3 t2 = ce_ground_field_tone(id2, base, accent, amount);
	// the border between two fields, anti-aliased over a pixel
	float w = max(fwidth(edge_m), 1.0e-3);
	vec3 tone = mix(t2, t1, 0.5 + 0.5 * smoothstep(0.0, w, edge_m));
	tone = mix(tone, ce_ground_field_mean(base, accent, amount), far);
	tone = mix(base, tone, field);             // beside the road: the plain ground tone (verge, ditch)
	// furrows inside a field, each field in its own direction; none on its headland, none once they get thin
	float ang = id1 * 3.14159;
	float line = sin(dot(p, vec2(cos(ang), sin(ang))) * 1.9);
	float near_k = (1.0 - smoothstep(0.25, 0.8, foot)) * field * nature * smoothstep(2.0, 5.0, edge_m);
	tone *= 1.0 + line * 0.045 * near_k * (0.6 + step(id1, amount));
	// border of a field: a darker line (hedge, track); on paved ground the joints between the lots
	float border = (1.0 - smoothstep(0.8 - w, 0.8 + w, edge_m)) * field * (1.0 - smoothstep(1.2, 3.5, foot));
	tone *= 1.0 - 0.13 * border * mix(0.45, 1.0, nature);
	// soft blotches at two scales; they go as the footprint of a pixel outgrows them
	float blot = texture(ground_noise, p / CE_GROUND_BLOT_M).g;
	float big = texture(ground_noise, p / (CE_GROUND_BLOT_M * 5.0) + vec2(0.37, 0.11)).g;
	float blot_k = 1.0 - smoothstep(1.5, 6.0, foot);
	tone *= 1.0 + (blot - 0.5) * 0.14 * blot_k + (big - 0.5) * 0.10 * (1.0 - smoothstep(8.0, 30.0, foot));
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

// Anti-aliased stripes of `period` (in the units of x): +0.5 on [0, period / 2), -0.5 on [period / 2, period) and so
// on, fading to 0 once a stripe is thinner than a pixel or two.
float ce_ground_stripes(float x, float period) {
	float f = x / period;
	float w = max(fwidth(f), 1.0e-4);
	float t = abs(fract(f - 0.25) - 0.5);           // 0.25 on a border, 0.5 / 0 in the middle of the +/- stripe
	float s = smoothstep(0.25 - w, 0.25 + w, t) - 0.5;
	return s * (1.0 - smoothstep(0.18, 0.4, w));
}
