// Modern: the tube of a tunnel (scripts/race3d/builders/tunnel.gd; package R5, docs/renderer-modern-tunnel-bruecken.md) –
// walls with their tile band, walkways, haunches, ceiling, cable trays, luminaires, SOS niches, exit doors, jet fans,
// the frame of the exit and the dark cap that closes the tube for a camera outside. FIX1 laid the first, flat tube.
// Unshaded: the tube shows Arcade's tunnel light whatever the environment does (RoadRenderer._ctx(true), frozen):
//   colour = albedo × the tunnel ambient of the palette (Palette.tunnel(); seen from outside × (0.5 + 0.5 × lights),
//            Arcade's eyes adapted to the daylight), plus the player's low beam on the walls,
//   fog    = towards Palette.TUNNEL_FOG by pow((d - 12) / darkness_m, 0.8) of the camera distance d (Arcade's tunnel
//            law, render.tunnel.darkness_m), lamps by its cube (they shine through the haze).
// On top of Arcade's flat bands (what makes the tube read as a real one; each pattern fades into its mean once it is
// finer than a pixel – fwidth –, nothing reads the wall clock):
//   tile band  enamel panels 1.2 × 0.6 m with dark joints, every panel its own shade, grime of the spray towards the
//              walkway; upper wall and vault: concrete with ring joints every 12 m, soot towards the crown;
//   lamps      the walls are lighter beside every luminaire (lamp_every along the road: a rhythm when driving);
//   signs      the orange SOS plate with its letters, green emergency signs with a white arrow (sign-local u, v);
//   niches     lit from inside, independent of the tube's light; doors in green steel with a handle.
// Vertex format:
//   COLOR.rgb  albedo (sRGB, display value)
//   UV         (depth into the tunnel from its portal in m, road position z of the portal)
//   UV2        x = kind: 0 plain, 1 cap (drawn only for a camera outside this tunnel), 2 lamp lens, 3 green sign,
//              4 tile band, 5 wall / concrete, 6 haunch and ceiling, 7 walkway and kerb, 8 lit niche, 9 SOS plate,
//              10 metal (trays, housings, fans), 11 door; y = height above the road (m)
//   CUSTOM0    xy = sign-local u (from the viewer's left), v (from the top), 0..1
// From outside (the camera is not in this tunnel) only the first peek_m metres are drawn and the cap closes the tube
// there (Arcade: render.tunnel.peek_m) – the tube deeper inside could curve out of the portal hill.
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform vec3 ambient_in = vec3(0.91, 0.71, 0.49);   // tunnel ambient (display factor) for a camera inside the tunnel
uniform vec3 ambient_out = vec3(0.46, 0.36, 0.24);  // … and for a camera outside it
uniform vec3 fog_colour = vec3(0.07, 0.05, 0.03);   // Palette.TUNNEL_FOG
uniform float darkness_m = 260.0;                   // render.tunnel.darkness_m
uniform float peek_m = 45.0;                        // render.tunnel.peek_m
uniform float cam_tunnel_z = -1.0e9;                // portal z of the tunnel the camera is in (-1e9: outside)
uniform float lamp_every = 12.0;                    // render.tunnel.light_every_m
uniform vec3 lamp_colour = vec3(1.0, 0.89, 0.73);   // Arcade's LAMP_COL lightened by 0.4
uniform vec3 niche_colour = vec3(0.12, 0.62, 0.29); // Arcade's niche green
uniform vec3 headlight_colour = vec3(1.0, 0.95, 0.84);

global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;

varying vec3 v_world;
varying flat float v_kind;
varying float v_h;
varying vec2 v_sign;

// the renderer's sRGB -> linear for albedo values
vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// ALBEDO value the renderer turns into the linear value x: inverse of to_lin (two Newton steps)
vec3 albedo_for(vec3 x) {
	vec3 c = pow(max(x, vec3(0.0)), vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

// display value -> linear value (exact sRGB curve)
vec3 unshow(vec3 d) {
	return pow((max(d, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
}

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 on the joints of a grid of `size` metres (anti-aliased, fading once the joints are thinner than a pixel)
float grid(vec2 p, vec2 size, float width) {
	vec2 q = p / size;
	vec2 edge = (0.5 - abs(fract(q) - 0.5)) * size;
	vec2 w = max(fwidth(p), vec2(1.0e-4));
	float jx = 1.0 - smoothstep(width * 0.5 - w.x, width * 0.5 + w.x, edge.x);
	float jy = 1.0 - smoothstep(width * 0.5 - w.y, width * 0.5 + w.y, edge.y);
	return max(jx, jy) * (1.0 - smoothstep(width * 0.7, width * 2.5, max(w.x, w.y)));
}

// The letters S and O in a 3 × 5 pixel font: 1 inside a pixel of the letter
float sos_mask(vec2 uv) {
	// 13 × 7 cells: margin, S (1-3), gap, O (5-7), gap, S (9-11), margin; rows 1-5 the letters
	vec2 c = floor(uv * vec2(13.0, 7.0));
	int col = int(c.x);
	int row = int(c.y) - 1;
	if (row < 0 || row > 4) {
		return 0.0;
	}
	int lx = -1;
	bool is_o = false;
	if (col >= 1 && col <= 3) { lx = col - 1; }
	else if (col >= 5 && col <= 7) { lx = col - 5; is_o = true; }
	else if (col >= 9 && col <= 11) { lx = col - 9; }
	if (lx < 0) {
		return 0.0;
	}
	int bits;
	if (is_o) {
		bits = (row == 0 || row == 4) ? 7 : 5;
	} else {
		bits = (row == 0 || row == 2 || row == 4) ? 7 : (row == 1 ? 4 : 1);
	}
	return float((bits >> (2 - lx)) & 1);
}

// A white arrow pointing to the viewer's right with a door frame left of it (green emergency signs)
float exit_mask(vec2 uv) {
	vec2 p = uv * vec2(2.2, 1.0);
	float frame = step(0.18, p.x) * step(p.x, 0.78) * step(0.18, p.y) * step(p.y, 0.86);
	float inner = step(0.28, p.x) * step(p.x, 0.68) * step(0.28, p.y) * step(p.y, 0.86);
	float shaft = step(1.0, p.x) * step(p.x, 1.6) * step(0.42, p.y) * step(p.y, 0.58);
	float head = step(1.55, p.x) * step(abs(p.y - 0.5), (2.0 - p.x) * 0.9);
	return max(frame - inner, max(shaft, head));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_kind = UV2.x;
	v_h = UV2.y;
	v_sign = CUSTOM0.xy;
}

void fragment() {
	bool own = abs(UV.y - cam_tunnel_z) < 1.0;
	bool cap = v_kind > 0.5 && v_kind < 1.5;
	if (cap) {
		if (own) {
			discard;                  // the cap only closes the tube for a camera outside it
		}
	} else if (!own && UV.x > peek_m) {
		discard;
	}
	float dist = length(VERTEX);
	float f = pow(clamp((dist - 12.0) / max(darkness_m, 1.0), 0.0, 1.0), 0.8);
	vec3 amb = own ? ambient_in : ambient_out;
	vec2 p = vec2(UV.x, v_h);                    // along the tube (m), up the wall (m)
	float zw = UV.x + UV.y;                      // the road position (m): lamps stand on multiples of lamp_every
	float lz = mod(zw, lamp_every);
	float dl = min(lz, lamp_every - lz);
	float lamp_bump = exp(-dl * dl / 8.0);
	vec3 d;
	if (cap) {
		d = fog_colour;
	} else if (v_kind > 1.5 && v_kind < 2.5) {
		d = mix(fog_colour, lamp_colour, 1.0 - (own ? f * f * f : f * f));
	} else if (v_kind > 2.5 && v_kind < 3.5) {
		// green sign with a white arrow and door (Arcade's green sign, lit)
		vec3 s = mix(niche_colour, vec3(0.94), exit_mask(v_sign) * (1.0 - smoothstep(0.0, 0.5, max(fwidth(v_sign.x), fwidth(v_sign.y)) * 4.0)));
		d = mix(fog_colour, s * (0.6 + 0.4 * (1.0 - f)), 1.0 - f);
	} else if (v_kind > 7.5 && v_kind < 8.5) {
		// the lit niche: its own light, a little warmer at the top
		vec3 s = COLOR.rgb * mix(0.85, 1.05, clamp(v_h / 2.6, 0.0, 1.0));
		d = mix(fog_colour, s, 1.0 - f * f);
	} else if (v_kind > 8.5 && v_kind < 9.5) {
		// the orange SOS plate with white letters (lit from behind)
		float soft = 1.0 - smoothstep(0.0, 0.5, max(fwidth(v_sign.x), fwidth(v_sign.y)) * 6.0);
		vec3 s = mix(COLOR.rgb, vec3(0.97), sos_mask(v_sign) * soft);
		d = mix(fog_colour, s, 1.0 - f * f);
	} else {
		vec3 base = COLOR.rgb;
		float k = 1.0;
		if (v_kind > 3.5 && v_kind < 4.5) {
			// tile band: enamel panels, every panel its own shade, joints, grime of the spray near the walkway
			vec2 cell = floor(p / vec2(1.2, 0.6));
			base *= 0.95 + 0.08 * hash12(cell + vec2(UV.y * 0.01, 3.0));
			base *= 1.0 - 0.32 * grid(p, vec2(1.2, 0.6), 0.03);
			float grime = (1.0 - smoothstep(0.2, 1.4, v_h)) * (0.55 + 0.45 * vnoise(vec2(zw * 0.35, 1.7)));
			base *= 1.0 - 0.28 * grime;
			k = 1.0 + 0.10 * lamp_bump * smoothstep(0.8, 2.9, v_h);
		} else if (v_kind > 4.5 && v_kind < 5.5) {
			// concrete: ring joints every 12 m (half way between the lamps), faint stains
			float ring = grid(vec2(zw + lamp_every * 0.5, 0.5), vec2(lamp_every, 100.0), 0.05);
			base *= (1.0 - 0.25 * ring) * (0.93 + 0.1 * vnoise(p * vec2(0.4, 1.3)));
			k = 1.0 + 0.16 * lamp_bump;
		} else if (v_kind > 5.5 && v_kind < 6.5) {
			// haunch and ceiling: ring joints, soot getting darker towards the crown
			float ring = grid(vec2(zw + lamp_every * 0.5, 0.5), vec2(lamp_every, 100.0), 0.06);
			base *= (1.0 - 0.3 * ring) * (0.9 + 0.12 * vnoise(vec2(zw * 0.2, v_h * 2.0)));
			base *= 1.0 - 0.18 * smoothstep(4.6, 6.2, v_h);
			k = 1.0 + 0.22 * lamp_bump;
		} else if (v_kind > 6.5 && v_kind < 7.5) {
			// walkway: concrete slabs, the kerb's edge lighter
			base *= (1.0 - 0.25 * grid(vec2(zw, 0.5), vec2(2.0, 100.0), 0.03)) * (0.92 + 0.12 * vnoise(vec2(zw, v_h) * 1.5));
		} else if (v_kind > 9.5 && v_kind < 10.5) {
			// metal: a little sheen on the upper side of whatever it is
			vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
			base *= 0.85 + 0.25 * clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
		} else if (v_kind > 10.5) {
			// a steel door: its panel edges and a handle
			float edge = 1.0 - smoothstep(0.03, 0.06, min(min(v_sign.x, 1.0 - v_sign.x), min(v_sign.y, 1.0 - v_sign.y)));
			float handle = step(0.78, v_sign.x) * step(v_sign.x, 0.9) * step(0.47, v_sign.y) * step(v_sign.y, 0.52);
			base = mix(base, base * 0.7, edge);
			base = mix(base, vec3(0.75), handle);
		}
		vec3 lit = base * amb * k;
		// the player's low beam on the tube (Arcade lights its tunnel walls in the headlights as well)
		if (ce_headlight.y > 0.0) {
			vec3 to = v_world - ce_headlight_pos;
			float l = max(length(to), 0.001);
			float reach = max(1.0 - l / max(ce_headlight.x, 1.0), 0.0);
			float cone = smoothstep(0.80, 0.97, dot(to / l, normalize(ce_headlight_dir)));
			lit += base * headlight_colour * (cone * reach * reach * ce_headlight.y * 0.6);
		}
		d = mix(lit, fog_colour, f);
	}
	ALBEDO = albedo_for(unshow(min(d, vec3(1.0))));
}
