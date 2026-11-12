// Modern: the road surface (contract §6 R1) – asphalt per road type, shoulders, median strip, gravel verge,
// sidewalks and curbs, and ALL paint: edge lines, lane lines with their dashes, the separator and the hatched wedge
// of the fuel lane, the start / finish checker, crosswalks. Nothing is a decal or a floating strip: every fragment
// knows where it lies in road coordinates and decides what it is.
//
// Mesh (scripts/race3d/builders/road.gd), one surface per chunk, vertices never shared between segments:
//   UV        x = metres from the centreline (+ right; on a curb face: height above the road), y = metres along
//             the road modulo z_period (dash cycles, post spacing and every noise lattice divide it)
//   UV2       x = metres from the near edge of the segment (0 .. 3), y = kind: 0 road band (asphalt and what lies
//             beside it at road level), 1 sidewalk, 2 curb top, 3 curb face
//   CUSTOM0   left asphalt edge, right edge of the regular lanes, right asphalt edge incl. fuel lane (m from the
//             centreline, of the vertex' row), fuel-lane edge of the far row minus that of the near row
//   CUSTOM1   number of lane lines, road type (0 Autobahn, 1 Landstraße, 2 city), flag bits, wear 0..1
//   COLOR     rgb = ground colour of the verge / median of the segment (the scenery's grass, display values)
// Flag bits: 1 edge lines · 2 wide separator (fuel lane beside this segment) · 4 edge line of the fuel lane ·
// 8 hatch stripe of the opening fuel lane · 16 checker · 32 crosswalk · 64 tunnel · 128 bridge deck ·
// 256 guardrail left · 512 guardrail right · 1024 City Limits (curbs)
//
// Paint geometry is Arcade's (RoadRenderer._draw_markings) to the centimetre, so both modes show the same road;
// the edges are anti-aliased analytically: the footprint of a pixel in road metres comes from the screen-space
// derivatives, a line covers the part of that footprint that lies on it (box filter). A line thinner than a
// pixel fades by its coverage instead of flickering, far dashes melt into their duty cycle.
// Detail that only exists here: aggregate grain, streaks and batches of the asphalt, polished wheel tracks, oil
// in the lane centre, sealed joints, repair patches, tyre marks, worn paint, dirt at the edges, paving slabs –
// each faded out before it gets smaller than a pixel. All of it is a function of road coordinates (no TIME, no
// world position: the picture of a place never changes, Rule 10).
// Light: the one shadowed sun of the engine, the ground law for the rest (inc/ground_law.gdshaderinc, RINT-B: the
// engine's ambient pass is off, the base pass is written as EMISSION so that level road in the light shows Arcade's
// colour – albedo × palette ambient – at every hour; at night the road had been up to 59 % brighter than Arcade), the
// analytical pools of lamps and traffic (inc/pools.gdshaderinc) and the player's low beam (inc/headlight.gdshaderinc)
// – paint and the checker throw more of it back than asphalt (retro-reflection), grass less. The mesh is on render
// layer 2: the real spot and omni lights leave it out.
// Colour space: ALBEDO and EMISSION are sRGB-encoded here; the engine linearises them (docs/modelle.md §4).
// Load only through ModernMaterials.shader("road") – never with preload().
shader_type spatial;
render_mode cull_back, ambient_light_disabled;

#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
#include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
#include "res://assets/shaders/modern/inc/ground_law.gdshaderinc"

// display colours (Palette), set by the builder
uniform vec3 col_road_a = vec3(0.337, 0.345, 0.369);
uniform vec3 col_road_l = vec3(0.373, 0.376, 0.4);
uniform vec3 col_road_c = vec3(0.31, 0.318, 0.337);
uniform vec3 col_paved = vec3(0.42, 0.424, 0.439);
uniform vec3 col_gravel = vec3(0.541, 0.502, 0.392);
uniform vec3 col_sidewalk = vec3(0.639, 0.631, 0.604);
uniform vec3 col_curb = vec3(0.784, 0.776, 0.753);
uniform vec3 col_line = vec3(0.949, 0.949, 0.925);
uniform vec3 col_snow = vec3(0.933, 0.949, 0.965);
uniform vec3 col_road_snow = vec3(0.624, 0.643, 0.671);
uniform vec3 col_line_snow = vec3(0.788, 0.804, 0.827);
// geometry of the paint (config render.* / road.*)
uniform float lane_w = 3.75;
uniform float shoulder_w = 2.5;
uniform float edge_line_w = 0.3;
uniform float lane_line_w = 0.15;
uniform vec3 dash_on = vec3(6.0, 6.0, 3.0);        // metres of paint per cycle: Autobahn, Landstraße, city
uniform vec3 dash_cycle = vec3(18.0, 18.0, 9.0);   // metres per cycle
uniform float seg_len = 3.0;
uniform float post_every = 6.0;                    // guardrail posts (contact shadow)
uniform float detail = 1.0;                        // strength of the fine detail (0 = plain colours)
uniform float asphalt_reflect = 0.9;               // how much of the low beam and the light pools a surface throws back
uniform float paint_reflect = 1.6;                 // (Arcade's factors: asphalt 0.9, lines 1.6, hatch and crosswalk 1.4, checker 1.2)

uniform float wet_mirror = 0.42;                   // R4: share of the Fresnel reflection of the sky on wet asphalt
// R4 night calibration (contract §6 R4: the mean road luminance at N1 within +15 % of Arcade and never darker): the
// fine detail of the asphalt (polished tracks, oil, joints, patches) darkens its mean by a few per cent – measured at
// N1 3–4 % below Arcade before; at night (outside tunnels, which have their own light) the base is lifted by this
uniform float night_lift = 0.08;

global uniform float ce_wet;
global uniform float ce_snow;
global uniform float ce_night;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;
global uniform vec4 ce_sky_top;
global uniform vec4 ce_sky_horizon;

varying vec2 v_xz;
varying float v_seg;
varying flat float v_kind;
varying vec3 v_edge;
varying flat float v_dra;
varying flat vec4 v_data;
varying flat vec3 v_ground;
varying vec3 v_world;

void vertex() {
	v_xz = UV;
	v_seg = UV2.x;
	v_kind = UV2.y;
	v_edge = CUSTOM0.xyz;
	v_dra = CUSTOM0.w;
	v_data = CUSTOM1;
	v_ground = COLOR.rgb;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Part of a pixel footprint of width w centred at x that lies inside [a, b].
float cover(float x, float a, float b, float w) {
	return clamp((min(x + 0.5 * w, b) - max(x - 0.5 * w, a)) / w, 0.0, 1.0);
}

// Integral from 0 to x of the periodic indicator "inside [0, on) of every period".
float dash_int(float x, float on, float period) {
	float n = floor(x / period);
	return n * on + min(x - n * period, on);
}

// Part of a footprint of width w centred at x that lies on the periodic dash.
float dash_cover(float x, float on, float period, float w) {
	return clamp((dash_int(x + 0.5 * w, on, period) - dash_int(x - 0.5 * w, on, period)) / w, 0.0, 1.0);
}

// Anti-aliased square wave: +1 on [0, 1), -1 on [1, 2) …, w = footprint in the same unit.
float square(float t, float w) {
	return clamp(sin(PI * t) / (PI * max(w, 1.0e-4)), -1.0, 1.0);
}

void fragment() {
	float x = v_xz.x;
	float z = v_xz.y;
	float wx = max(length(vec2(dFdx(x), dFdy(x))), 1.0e-4);
	float wz = max(length(vec2(dFdx(z), dFdy(z))), 1.0e-4);
	float foot = max(wx, wz);
	float la = v_edge.x;
	float ma = v_edge.y;
	float ra = v_edge.z;
	int flags = int(v_data.z + 0.5);
	int road = int(v_data.y + 0.5);
	int kind = int(v_kind + 0.5);
	bool tunnel = (flags & 64) != 0;
	float snow = tunnel ? 0.0 : ce_snow;
	float wet = tunnel ? 0.0 : ce_wet;
	vec2 p = vec2(x, z);
	// noise octaves, each gone before it is smaller than a pixel
	float f_grain = detail * (1.0 - smoothstep(0.012, 0.05, foot));
	float grain = f_grain > 0.0 ? (vnoise(p * 41.0) - 0.5) * f_grain : 0.0;
	float f_streak = detail * (1.0 - smoothstep(0.2, 0.9, wx)) * (1.0 - smoothstep(1.5, 7.0, wz));
	float streak = f_streak > 0.0 ? (vnoise(vec2(x * 2.3, z * 0.27)) - 0.5) * f_streak : 0.0;
	float f_batch = detail * (1.0 - smoothstep(12.0, 60.0, wz));
	float batch = f_batch > 0.0 ? (vnoise(vec2(x * 0.13 + 5.0, z * 0.024)) - 0.5) * f_batch : 0.0;

	vec3 base = vec3(0.5);
	float rough = 0.92;
	float spec = 0.3;
	float reflect = 1.0;

	if (kind == 0) {
		// ---------------------------------------------------------------- asphalt
		if (road == 1) {
			la += (vnoise(vec2(z * 0.9, 3.0)) - 0.5) * 0.07 * detail;      // a country road has no clean edge
			ra -= (vnoise(vec2(z * 0.9, 9.0)) - 0.5) * 0.07 * detail;
		}
		float in_road = cover(x, la, ra, wx);
		vec3 asph = road == 0 ? col_road_a : (road == 1 ? col_road_l : col_road_c);
		float tone = 1.0 + grain * 0.11 + streak * 0.07 + batch * 0.08;
		float polish = 0.0;
		float lane_u = (x - la) / lane_w;
		float lu = fract(lane_u);
		float li = floor(lane_u);
		bool in_lane = x > la && x < ma;
		if (in_lane && detail > 0.0) {
			// wheel tracks: polished and a little darker; oil in the middle of the lane
			float f_lane = 1.0 - smoothstep(0.12, 0.6, wx);
			float t1 = (lu - 0.28) / 0.085;
			float t2 = (lu - 0.72) / 0.085;
			float tracks = exp(-t1 * t1) + exp(-t2 * t2);
			float along = 0.75 + 0.5 * vnoise(vec2(li * 7.0 + 1.0, z * 0.045));
			polish = tracks * along * f_lane * detail;
			tone -= polish * 0.045;
			float o = (lu - 0.5) / 0.05;
			tone -= exp(-o * o) * 0.03 * f_lane * detail * (0.5 + vnoise(vec2(li * 3.0, z * 0.11)));
			// sealed joint beside a lane boundary: a thin meandering tar line, here and there
			if (li >= 1.0) {
				float jc = (li + 0.055) * lane_w + la + sin(z * 0.71 + li * 2.0) * 0.018;
				float on = smoothstep(0.42, 0.5, vnoise(vec2(li * 5.0 + 2.0, z * 0.021)));
				tone -= cover(x, jc - 0.017, jc + 0.017, wx) * on * 0.22 * detail;
			}
			// repair patch: a rectangle of younger asphalt with a tar border (one in a few cells of 72 m)
			float pc = floor(z / 72.0);
			float ph = h21(vec2(li + 11.0, pc));
			if (ph < 0.23) {
				float pz0 = pc * 72.0 + 6.0 + h21(vec2(pc, li + 3.0)) * 36.0;
				float pz1 = pz0 + 6.0 + h21(vec2(li + 5.0, pc)) * 14.0;
				float px0 = la + (li + 0.05) * lane_w;
				float px1 = la + (li + (ph < 0.1 ? 0.52 : 0.95)) * lane_w;
				float inside = cover(x, px0, px1, wx) * cover(z, pz0, pz1, wz);
				float core = cover(x, px0 + 0.035, px1 - 0.035, wx) * cover(z, pz0 + 0.035, pz1 - 0.035, wz);
				tone += (core * (ph < 0.12 ? -0.07 : 0.045) - (inside - core) * 0.2) * detail;
			}
			// tyre marks: two dark streaks in the wheel tracks, more of them where the road is worn (bends, city)
			float tc = floor(z / 36.0);
			float th = h21(vec2(li + 17.0, tc));
			if (th < 0.08 + 0.45 * v_data.w) {
				float zz = z - tc * 36.0;
				float s0 = 3.0 + 14.0 * h21(vec2(tc, li + 23.0));
				float len = 7.0 + 12.0 * h21(vec2(li + 29.0, tc));
				float a = smoothstep(s0, s0 + 1.5, zz) * (1.0 - smoothstep(s0 + len * 0.55, s0 + len, zz));
				float drift = (h21(vec2(tc + 3.0, li)) - 0.5) * 0.1 + (zz - s0) * (h21(vec2(li, tc + 5.0)) - 0.5) * 0.004;
				float m1 = (lu - 0.28 - drift) / 0.03;
				float m2 = (lu - 0.72 - drift) / 0.03;
				float marks = (exp(-m1 * m1) + exp(-m2 * m2)) * (1.0 - smoothstep(0.05, 0.25, wx));
				tone -= marks * a * (0.1 + 0.08 * vnoise(vec2(x * 3.0, z * 0.6))) * detail;
			}
		}
		if ((flags & 1024) != 0 && detail > 0.0) {
			// gutter along the curbs
			float gd = min(x - la, ra - x);
			tone -= (1.0 - smoothstep(0.0, 0.4, gd)) * (0.07 + 0.05 * vnoise(vec2(x * 4.0, z * 0.5))) * detail;
		}
		asph *= tone;
		// ---------------------------------------------------------------- paint
		float paint = 0.0;
		float el = edge_line_w;
		if ((flags & 1) != 0) {
			paint = max(paint, cover(x, la + 0.15, la + 0.15 + el, wx));
			float sep = el * ((flags & 2) != 0 ? 1.6 : 1.0);
			paint = max(paint, cover(x, ma - 0.15 - 0.5 * sep, ma - 0.15 + 0.5 * sep, wx));
			if ((flags & 4) != 0) {
				paint = max(paint, cover(x, ra - 0.15 - el, ra - 0.15, wx));
			}
		}
		if (v_data.x > 0.5) {
			float n = clamp(floor(lane_u + 0.5), 1.0, v_data.x);
			float lc = la + n * lane_w;
			float across = cover(x, lc - 0.5 * lane_line_w, lc + 0.5 * lane_line_w, wx);
			if (across > 0.0) {
				float don = road == 0 ? dash_on.x : (road == 1 ? dash_on.y : dash_on.z);
				float dcy = road == 0 ? dash_cycle.x : (road == 1 ? dash_cycle.y : dash_cycle.z);
				paint = max(paint, across * dash_cover(z, don, dcy, wz));
			}
		}
		float t = clamp(v_seg / seg_len, 0.0, 1.0);
		if ((flags & 8) != 0) {
			// hatch stripe across the opening fuel lane: from the separator at the near edge of the segment to the
			// outer edge at its far edge
			float far_edge = ra + v_dra * (1.0 - t);
			float hc = mix(ma + 0.3, far_edge - 0.6, t);
			paint = max(paint, cover(x, hc - 0.15, hc + 0.15, wx) * 0.9);
		}
		float along_seg = cover(v_seg, 0.0, seg_len, wz);
		if ((flags & 32) != 0) {
			// crosswalk: bars of 0.5 m every metre, from 0.3 m inside the left edge to the right edge of the lanes
			float bars = floor(ma - la);
			float bx = x - la - 0.3;
			float across = bx > -0.5 * wx && bx < bars ? dash_cover(max(bx, 0.0) + 1000.0, 0.5, 1.0, wx) : 0.0;
			paint = max(paint, across * along_seg);
		}
		// worn paint: thinner where the grain shows through, chipped here and there
		float worn = 1.0 - detail * (0.1 * (1.0 - smoothstep(0.02, 0.2, foot)) * smoothstep(0.35, 0.75, vnoise(p * vec2(9.0, 2.2)))
			+ 0.12 * (0.5 - streak) * f_streak);
		vec3 line = mix(col_line, col_line_snow, 0.5 * snow) * (1.0 + grain * 0.04);
		// ---------------------------------------------------------------- weather on the asphalt
		asph *= 1.0 - 0.32 * wet;
		if (wet > 0.0) {
			// R4: the water film mirrors the sky – Fresnel of water at the angle under which the camera sees the road
			// (strong at grazing angles far ahead, weak below the car), the palette's sky between horizon and zenith
			// along the mirrored ray (ce_sky_horizon / ce_sky_top, display values). The mirrored light is the sky's own:
			// divided by the ambient factor the ground law multiplies with, as Arcade does. Never less than Arcade's
			// sheen (28 % of the fog colour at the end of the sight); paint mirrors a little less (its beads scatter).
			vec3 vdir = normalize(v_world - CAMERA_POSITION_WORLD);
			float cos_i = clamp(-vdir.y, 0.0, 1.0);
			float fres = 0.02 + 0.98 * pow(1.0 - cos_i, 5.0);
			vec3 sky = mix(ce_sky_horizon.rgb, ce_sky_top.rgb, smoothstep(0.0, 0.45, cos_i));
			vec3 sky_k = sky / max(ce_ambient_display.rgb, vec3(0.2));
			float sheen = clamp(-VERTEX.z / max(80.0, ce_fog_range.y), 0.0, 1.0);
			float mirror = max(fres * wet_mirror, 0.28 * sheen) * wet;
			asph = mix(asph, sky_k, mirror);
			line = mix(line * (1.0 - 0.07 * wet), sky_k, mirror * 0.35);
		}
		asph = mix(asph, col_road_snow, 0.3 * snow);
		if (snow > 0.0) {
			// snow pushed to the edges of the lanes, with a frayed inner edge
			float fray = (vnoise(vec2(z * 1.3, 4.0)) - 0.5) * 0.18;
			float band = max(cover(x, la, la + 0.7 + fray, wx), cover(x, ma - 0.55 - fray, ma, wx));
			asph = mix(asph, col_snow * (0.96 + grain * 0.1), band * 0.7 * snow);
		}
		vec3 surf = mix(asph, line, paint * worn);
		float gloss = paint * worn;
		reflect = mix(asphalt_reflect, paint_reflect, gloss);
		if ((flags & 16) != 0) {
			// start / finish: two rows of squares across the whole asphalt
			float cells = max(4.0, floor(ra - la));
			float cw = (ra - la) / cells;
			float cx = (x - la) / cw;
			float cz = v_seg / (0.5 * seg_len);
			float chk = 0.5 + 0.5 * square(cx, wx / cw) * square(cz, wz / (0.5 * seg_len));
			float on = along_seg;
			surf = mix(surf, mix(vec3(0.08), vec3(1.0), chk) * (1.0 + grain * 0.05), on);
			reflect = mix(reflect, 1.2, on);
			gloss = max(gloss, on);
		}
		rough = mix(0.93 - polish * 0.14, 0.62, gloss);
		rough = mix(rough, 0.34 - polish * 0.1, wet * 0.9);
		spec = mix(0.3, 0.55, max(gloss * 0.6, wet));
		// ---------------------------------------------------------------- beside the asphalt
		float d_out = max(la - x, x - ra);          // metres beyond the asphalt edge
		bool left = x < 0.5 * (la + ra);
		vec3 side = col_paved;
		float side_reflect = 1.0;
		float side_rough = 0.95;
		float f_coarse = detail * (1.0 - smoothstep(0.03, 0.14, foot));
		float coarse = f_coarse > 0.0 ? (vnoise(p * 17.0) - 0.5) * f_coarse : 0.0;
		vec3 grass = v_ground * (1.0 + coarse * 0.2 + streak * 0.12 + batch * 0.14);
		if (tunnel) {
			side = col_paved * 0.9 * (1.0 + coarse * 0.07 + batch * 0.06);
		} else if ((flags & 128) != 0) {
			side = col_paved * 0.95 * (1.0 + coarse * 0.07 + batch * 0.06);
			side = mix(side, col_snow, 0.6 * snow);
		} else if (road == 1) {
			// gravel verge that grows into the grass
			float mixv = clamp(0.65 + (vnoise(vec2(x * 1.7, z * 0.45)) - 0.5) * 0.5 * detail - smoothstep(1.2, 2.4, d_out) * 0.3, 0.0, 1.0);
			side = mix(grass, col_gravel * (1.0 + coarse * 0.3), mixv);
			side = mix(side, col_snow, 0.9 * snow);
			side_reflect = left ? 0.6 : 0.8;
			side_rough = 1.0;
		} else {
			// Autobahn: paved shoulder on the right; on the left a paved strip, then the grass of the median
			float paved = left ? cover(d_out, -1.0, 0.8, wx) : 1.0;
			vec3 pv = col_paved * (1.0 + coarse * 0.08 + streak * 0.05 + batch * 0.06);
			pv *= 1.0 - (left ? 0.0 : smoothstep(1.6, 2.5, d_out) * 0.1 * detail);     // dirt towards the verge
			pv *= 1.0 - 0.2 * wet;
			pv = mix(pv, col_snow, 0.75 * snow);
			vec3 gr = mix(grass * 0.92, col_snow, 0.94 * snow);
			side = mix(gr, pv, paved);
			side_reflect = left ? mix(0.45, 1.0, paved) : 0.8;
			side_rough = mix(1.0, 0.95, paved);
		}
		// contact shadow of a guardrail and its posts on the strip below it
		bool rail = left ? (flags & 256) != 0 : (flags & 512) != 0;
		if (rail && detail > 0.0) {
			float d_edge = shoulder_w - d_out;             // metres inside the outer edge, where the beam hangs
			float under = exp(-max(d_edge, 0.0) / 0.17) * (1.0 - smoothstep(0.1, 0.5, wx));
			float pz = abs(mod(z + 0.5 * post_every, post_every) - 0.5 * post_every);
			float dl = d_edge + 0.08;
			float post = exp(-(pz * pz + dl * dl) / 0.035) * (1.0 - smoothstep(0.08, 0.35, foot));
			side *= 1.0 - (under * 0.22 + post * 0.38) * detail;
		}
		base = mix(side, surf, in_road);
		reflect = mix(side_reflect, reflect, in_road);
		rough = mix(side_rough, rough, in_road);
		spec = mix(0.25, spec, in_road);
	} else if (kind == 1) {
		// ---------------------------------------------------------------- sidewalk: paving slabs
		float f_slab = detail * (1.0 - smoothstep(0.04, 0.3, foot));
		vec2 cell = vec2(x * 2.0, z * 2.0 + floor(x * 2.0) * 0.5);
		float slab = h21(floor(cell));
		vec2 jf = abs(fract(cell) - 0.5);
		float joint = max(smoothstep(0.47, 0.5, jf.x), smoothstep(0.47, 0.5, jf.y)) * f_slab;
		base = col_sidewalk * (1.0 + (slab - 0.5) * 0.07 * f_slab + grain * 0.08 + batch * 0.05 - joint * 0.2);
		base = mix(base, col_snow, 0.7 * snow);
		base *= 1.0 - 0.15 * wet;
		reflect = 1.0;
	} else {
		// ---------------------------------------------------------------- curb: stones of one metre
		float f_stone = detail * (1.0 - smoothstep(0.03, 0.25, wz));
		float joint = (1.0 - cover(fract(z) - 0.5, -0.487, 0.487, wz)) * f_stone;
		float stone = h21(vec2(floor(z), 5.0));
		base = col_curb * (1.0 + (stone - 0.5) * 0.06 * f_stone + grain * 0.07 - joint * 0.25);
		if (kind == 3) {
			base *= 0.85 - 0.12 * (1.0 - smoothstep(0.0, 0.1, x)) * detail;   // the face: darker, dirty at the foot
		}
		base = mix(base, col_snow, (kind == 2 ? 0.6 : 0.2) * snow);
		reflect = 1.0;
	}
	if (!tunnel) {
		base *= 1.0 + night_lift * clamp(ce_night, 0.0, 1.0);
	}
	base = clamp(base, vec3(0.0), vec3(1.0));
	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = 0.0;
	vec3 extra = ce_pools(v_world) * reflect + ce_headlight_light(v_world, reflect);
	EMISSION = ce_pools_encode(ce_ground_base_lin(base) + ce_pools_to_lin(base) * extra);
}
