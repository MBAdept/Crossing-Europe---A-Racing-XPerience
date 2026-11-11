// Modern: the tube of a tunnel (scripts/race3d/builders/tunnel.gd) – walls with their tile band, haunches, ceiling,
// lamp strips, emergency niches and the dark cap that closes the tube for a camera outside. FIX1 after the QA of M1
// (finding QB-01): a minimal tube in Arcade's colours until the tunnel package of M2 (R5) builds the real one.
// Unshaded: the tube shows Arcade's tunnel light whatever the environment does (RoadRenderer._ctx(true), frozen):
//   colour = albedo × the tunnel ambient of the palette (Palette.tunnel(); seen from outside × (0.5 + 0.5 × lights),
//            Arcade's eyes adapted to the daylight), plus the player's low beam on the walls,
//   fog    = towards Palette.TUNNEL_FOG by pow((d - 12) / darkness_m, 0.8) of the camera distance d (Arcade's tunnel
//            law, render.tunnel.darkness_m), lamps by its cube (they shine through the haze).
// Vertex format:
//   COLOR.rgb  albedo (sRGB, display value)
//   UV         (depth into the tunnel from its portal in m, road position z of the portal)
//   UV2.x      kind: 0 tube surface, 1 cap (drawn only for a camera outside this tunnel), 2 lamp, 3 niche sign
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
uniform vec3 lamp_colour = vec3(1.0, 0.89, 0.73);   // Arcade's LAMP_COL lightened by 0.4
uniform vec3 niche_colour = vec3(0.12, 0.62, 0.29); // Arcade's niche green
uniform vec3 headlight_colour = vec3(1.0, 0.95, 0.84);

global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;

varying vec3 v_world;
varying flat float v_kind;

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

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_kind = UV2.x;
}

void fragment() {
	bool own = abs(UV.y - cam_tunnel_z) < 1.0;
	if (v_kind > 0.5 && v_kind < 1.5) {
		if (own) {
			discard;                  // the cap only closes the tube for a camera outside it
		}
	} else if (!own && UV.x > peek_m) {
		discard;
	}
	float dist = length(VERTEX);
	float f = pow(clamp((dist - 12.0) / max(darkness_m, 1.0), 0.0, 1.0), 0.8);
	vec3 d;
	if (v_kind > 0.5 && v_kind < 1.5) {
		d = fog_colour;
	} else if (v_kind > 1.5 && v_kind < 2.5) {
		d = mix(fog_colour, lamp_colour, 1.0 - (own ? f * f * f : f * f));
	} else if (v_kind > 2.5) {
		d = mix(fog_colour, niche_colour * (0.6 + 0.4 * (1.0 - f)), 1.0 - f);
	} else {
		vec3 lit = COLOR.rgb * (own ? ambient_in : ambient_out);
		// the player's low beam on the tube (Arcade lights its tunnel walls in the headlights as well)
		if (ce_headlight.y > 0.0) {
			vec3 to = v_world - ce_headlight_pos;
			float l = max(length(to), 0.001);
			float reach = max(1.0 - l / max(ce_headlight.x, 1.0), 0.0);
			float cone = smoothstep(0.80, 0.97, dot(to / l, normalize(ce_headlight_dir)));
			lit += COLOR.rgb * headlight_colour * (cone * reach * reach * ce_headlight.y * 0.6);
		}
		d = mix(lit, fog_colour, f);
	}
	ALBEDO = albedo_for(unshow(min(d, vec3(1.0))));
}
