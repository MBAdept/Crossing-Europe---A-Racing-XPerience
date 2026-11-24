// Modern (v0.8.0, package R7d "Freie Strecke", contract A-27): the CLOUD LAYER of the sky – drawn at half the canvas'
// resolution into a viewport of its own (layers/backdrop.gd: the clouds are soft, and a view ray through them costs
// more than everything else of the sky), which sky2d.gdshader lays over its gradient, stars, moon and sun. In Modern
// only; Arcade keeps its 16 cloud sprites. German docs: docs/renderer-modern.md §20.
//
// CloudField's cumulus: heaps on a flat base at HEIGHT_M, domed up to THICK_M above it – a heap's height follows the
// field's excess over the threshold (ce_heap) – seen in perspective (row → elevation angle → distance). The view ray
// is followed from where it meets the base up through the slab in `steps` samples at fixed heights (the same in every
// row, so neighbouring rows sample neighbouring points: no streaks); the first sample below a heap's surface marks
// the hit, the surface itself lies between it and the sample before (regula falsi). The hit is lit by its height in
// the heap (the flat base grey, the tops bright) and by the heap's slope towards the engine's light (to_sun: the side
// facing it bright, the side away from it grey); a ray that misses keeps its closest approach – a soft rim around
// every heap. A thin edge with the sun behind it shines, the far heaps are hazed towards the horizon colour and melt
// into a band of the expected cover. Rain and snow (cover 1): a closed deck, its underside lighter where it is thin.
// Everything is a function of the uniforms – view time and the positions of the simulation, never TIME (Rule 10).
// Output: premultiplied colour and coverage (display values), written as they are (blend_disabled).
// Pixels: v_pos = canvas-local position of the backdrop (x 0 … screen.x, y rows); the viewport's pixel (0, 0) lies at
// `origin`, one of its pixels covers px_scale canvas pixels.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 px_scale = vec2(2.0);              // canvas pixels per pixel of the cloud viewport
uniform vec2 origin = vec2(0.0, -48.0);         // canvas position of the viewport's pixel (0, 0)
uniform vec2 screen = vec2(1376.0, 720.0);      // backdrop projection: logical picture + margins
uniform float horizon_y = 324.0;                // row of the infinitely distant ground
uniform float focal = 711.0;                    // pixels per radian
uniform float cam_heading = 0.0;                // world heading of the camera axis (forward = (sin, -cos))
uniform vec2 cam_field = vec2(0.0);             // field position of the camera (CloudField.field_pos, metres)
uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);      // world direction to the engine's light (sun by day, moon at night)
uniform vec4 sky_top = vec4(0.11, 0.36, 0.79, 1.0);
uniform vec4 sky_bottom = vec4(0.73, 0.87, 0.96, 1.0);
uniform vec3 sun_disc = vec3(0.0, -1000.0, 0.0);  // x, y of the disc (canvas px), z = 1 visible
uniform vec4 cloud_lit = vec4(1.0);             // palette "cloud"
uniform vec4 cloud_shade = vec4(0.79, 0.83, 0.89, 1.0);  // palette "cloud_dark"
uniform vec4 field = vec4(18000.0, 1600.0, 2.3, 0.37);   // CloudField TILE_M, HEIGHT_M, DETAIL (billows, groups)
uniform vec3 weights = vec3(0.55, 0.18, 0.27);           // CloudField.W
uniform float threshold = 0.6;                  // CloudField.threshold(cover)
uniform float cover = 0.12;                     // share of the field that is heap
uniform float overcast = 0.0;                   // palette "overcast" (rain, snow)
uniform float night = 0.0;                      // palette "night"
uniform float thick = 450.0;                    // CloudField.THICK_M: from the flat base to the highest tops
uniform float column_k = 1.6;                   // CloudField.COLUMN_K: heap height² per excess of n over the threshold
uniform float n_max = 0.89;                     // CloudField.n_max(): the field's highest n
uniform int steps = 16;                         // samples of a view ray through the slab, at fixed heights (graphics "sky_steps")
uniform float edge_k = 0.06;                    // soft rim of a heap: closest approach of a ray that misses it (share of the slab)
uniform float base_dark = 0.88;                 // the flat undersides against the palette's cloud_dark
uniform float sun_off = 260.0;                  // metres towards the light where a heap's slope is read (its lit side)
uniform float far_m = 34000.0;                  // beyond, the heaps melt into a band of the expected cover

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX * px_scale + origin;
}

// The domes and the billows of CloudField at field uv q (tiles of the domes), where a pixel covers tpp texels of the
// domes – the billows fade to their mean where a pixel covers more than a texel of them (they would only flicker),
// and are not even read beyond. textureLod: the samples lie in a loop with an early exit (no derivatives there).
float ce_cloud_rg(vec2 q, float tpp) {
	float r = textureLod(cloud_tex, q, log2(max(tpp, 1.0))).r;
	float tg = tpp * field.z;
	float g = tg < 2.0 ? mix(textureLod(cloud_tex, q * field.z, log2(max(tg, 1.0))).g, 0.5, smoothstep(0.6, 2.0, tg)) : 0.5;
	return weights.x * r + weights.y * g;
}

// Height of the heap at q, as a share of thick, with the groups b of this ray: a dome over the field's excess above
// the threshold (the square root rounds it) – flatter heaps where the groups thin out, the tallest in a dense group –,
// negative outside a heap (the soft edge of its foot). n: the field's value there.
float ce_heap(vec2 q, float tpp, float b, out float n) {
	n = ce_cloud_rg(q, tpp) + weights.z * b;
	float e = (n - threshold) / max(n_max - threshold, 0.02);
	return e > 0.0 ? sqrt(min(e * column_k, 1.0)) * mix(0.5, 1.0, smoothstep(0.35, 0.75, b)) : e * column_k * 2.0;
}

void fragment() {
	vec2 p = v_pos;
	float up = horizon_y - p.y;
	vec4 outc = vec4(0.0);
	if (up > 0.25 && cover > 0.001) {
		float tan_t = up / focal;
		float phi = cam_heading + (p.x - screen.x * 0.5) / focal;
		vec2 dir = vec2(sin(phi), -cos(phi));
		float d0 = field.y / tan_t;
		vec2 sh = to_sun.xz;
		sh = length(sh) > 1.0e-4 ? normalize(sh) : vec2(0.0, -1.0);
		vec3 shade_c = mix(cloud_shade.rgb * base_dark, sky_top.rgb, 0.12);
		float a_near = 0.0;
		vec3 c_near = cloud_lit.rgb;
		float melt = smoothstep(far_m * 0.65, far_m, d0);
		if (melt < 0.999) {
			// samples at fixed heights of the slab, from the base up; dstep = their spacing along this ray
			float dh = thick / float(steps);
			float dstep = dh / tan_t;
			// texels of the domes per pixel: a pixel's width at the base, or the spacing of the samples
			float tpp = max(d0 / focal * px_scale.x, dstep * 0.4) / field.x * 256.0;
			// the groups change over tens of kilometres: one value for the whole ray, read where it crosses the slab
			float d_mid = min(d0 + 0.5 * dstep * float(steps), far_m * 1.5);
			float tb = tpp * field.w;
			float b = textureLod(cloud_tex, (cam_field + dir * d_mid) / field.x * field.w, log2(max(tb, 1.0))).b;
			bool hit = false;
			float best = -1.0e3;
			float d_l = d0;
			float prev_diff = 0.0;
			float n;
			for (int i = 0; i < steps; i++) {
				float hr = float(i) / float(steps);              // height of the sample in the slab, 0 … 1
				float d = d0 + dstep * float(i);
				if (d > far_m * 1.5) {
					break;
				}
				float diff = ce_heap((cam_field + dir * d) / field.x, tpp, b, n) - hr;
				if (diff > 0.0) {
					d_l = d;
					if (i > 0) {
						// the surface between the two samples: three steps of regula falsi
						float lo = d - dstep;
						float f_lo = prev_diff;
						float hi = d;
						float f_hi = diff;
						for (int k = 0; k < 3; k++) {
							float m = hi - f_hi * (hi - lo) / (f_hi - f_lo);
							float f_m = ce_heap((cam_field + dir * m) / field.x, tpp, b, n) - (m * tan_t - field.y) / thick;
							if (f_m > 0.0) {
								hi = m;
								f_hi = f_m;
							} else {
								lo = m;
								f_lo = f_m;
							}
						}
						d_l = hi - f_hi * (hi - lo) / (f_hi - f_lo);
					}
					hit = true;
					break;
				}
				if (diff > best) {
					best = diff;
					d_l = d;
				}
				prev_diff = diff;
			}
			// light at the surface (or at the closest approach): its height in the heap (tops bright, the flat base
			// grey) and the heap's slope towards the light (the side facing the light bright, the side away grey)
			float hr = max((d_l * tan_t - field.y) / thick, 0.0);
			vec2 q = (cam_field + dir * d_l) / field.x;
			float heap = max(ce_heap(q, tpp, b, n), 0.0);
			float ns;
			float heap_s = max(ce_heap(q + sh * (sun_off / field.x), tpp, b, ns), 0.0);
			float rel = clamp(hr / max(heap, 0.05), 0.0, 1.0);
			float facing = clamp(0.55 + (heap - heap_s) * 2.2, 0.0, 1.0);
			float lightness = (0.18 + 0.82 * pow(rel, 0.75)) * mix(0.55, 1.0, facing);
			// a closed deck: its underside, lighter where it is thinner
			lightness = mix(lightness, 0.2 + 0.55 * (1.0 - smoothstep(0.35, 0.8, n)), overcast);
			c_near = mix(shade_c, cloud_lit.rgb, clamp(lightness, 0.0, 1.0));
			float edge = max(edge_k, 1.2 / float(steps));
			a_near = hit ? 1.0 : smoothstep(-edge, 0.0, best);
		}
		vec3 acc = c_near * a_near;
		float trans = 1.0 - a_near;
		// far away: a band of the expected cover, its undersides towards the horizon
		float band = cover * smoothstep(0.0, 0.25, tan_t * 6.0) * 0.9;
		vec3 band_c = mix(shade_c, cloud_lit.rgb, mix(0.55, 0.35, overcast));
		acc = mix(acc, band * band_c, melt);
		trans = mix(trans, 1.0 - band, melt);
		float a = 1.0 - trans;
		vec3 col = a > 1.0e-4 ? acc / a : cloud_lit.rgb;
		// a thin edge with the sun behind it shines (forward scattering), by day only
		if (sun_disc.z > 0.5) {
			float near_sun = exp(-dot(p - sun_disc.xy, p - sun_disc.xy) / (2.0 * 200.0 * 200.0));
			col = mix(col, vec3(1.0, 0.99, 0.95), near_sun * (1.0 - a) * 0.9 * (1.0 - overcast));
		}
		// haze towards the horizon colour with distance
		float hz = pow(clamp(d0 / 45000.0, 0.0, 1.0), 0.7);
		col = mix(col, sky_bottom.rgb, hz * 0.7 * (1.0 - overcast * 0.6));
		a *= mix(0.97, 0.62, night) * mix(1.0, 0.8, hz * (1.0 - overcast));
		outc = vec4(col * a, a);
	}
	COLOR = outc;
}
