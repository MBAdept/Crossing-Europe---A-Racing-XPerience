// Modern: water and banks at bridges – scripts/race3d/builders/bridge.gd (the water beside and under the deck, quay
// walls, embankments, the paved top of a quay) and scripts/race3d/layers/far_ground.gd (the river beyond the terrain
// ribbons and its far banks). Package R5 (contract §6 wave 3; docs/renderer-modern-tunnel-bruecken.md).
// A lit surface like the terrain: the ground law of inc/ground_law.gdshaderinc (the engine's ambient pass is off, the
// base pass is written as EMISSION, so level ground in the light shows Arcade's colour, albedo × palette ambient); the
// directional light (sun or moon) is added in light() – Lambert like the ground law assumes, with the shadows of the
// deck, the pylons and the ships. Painted here per vertex kind (UV2.x):
//   0 water   Arcade's water (RoadRenderer.water_tint: the lit water towards the sky by 0.16 + dz / 600, at most 0.7;
//             dz = the depth along the view, as Arcade's per-row distance)
//             and what Arcade cannot show: ripples that drift with the current (view time ce_time, never TIME), the
//             sky mirrored along them (horizon colour towards the zenith), the sun glittering in them (shadowed),
//             the lamp pools where they reach the water at night, a darker band and a light seam where the water meets
//             a wall
//   1 stone   quay wall or revetment of cut stone: courses of blocks with joints, every block its own shade, a dark
//             wet band with algae above the waterline, streaks
//   2 brick   quay wall of brick (canals): bricks in running bond
//   3 grass   embankment in the bank colour with patches, rip-rap stones at the waterline
//   4 paving  the paved top of a quay, coping stones along its edge
// Vertex data: COLOR.rgb base colour (sRGB display value); UV = surface position in metres (water: along the river,
//   across it; walls: along the bank, up; flat banks: along the bank, across); UV2.x = kind, UV2.y = height above the
//   water (m) – for the water itself the distance to the nearest bank wall (m; large where there is none);
//   CUSTOM0.xy = world xz direction of the UV.x axis (the river's direction: the ripples turn with it).
// The mesh is on render layer 2 like road and terrain: the real spots and omni lights leave it out, lamp pools and the
// low beam come from inc/pools.gdshaderinc and inc/headlight.gdshaderinc (Arcade's reflection: stone and grass 0.45,
// paving 0.8, water none – Arcade lights no water).
// Fog: Arcade's law for what lies beside the road (at most 70 % towards the brightened fog colour), as the terrain and
// the far ground – never more fog than Arcade (F4).
// Load only through ModernMaterials (after ensure_globals) – never with preload().
shader_type spatial;
render_mode cull_back, depth_draw_opaque, ambient_light_disabled;

#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
#include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
#include "res://assets/shaders/modern/inc/ground_law.gdshaderinc"

uniform vec3 sky_horizon = vec3(0.78, 0.86, 0.93);   // palette sky_bottom (set by the bridge builder every frame)
uniform vec3 sky_zenith = vec3(0.36, 0.58, 0.88);    // palette sky_top
uniform float glint = 1.0;                           // glitter of the directional light: 1 sun, ~0.25 moon, 0 overcast
uniform float night = 0.0;                           // palette lights
uniform float detail = 1.0;                          // "Details": strength of ripples and patterns (never of colours)
uniform float flow_speed = 0.35;                     // m/s of the ripples along the river

global uniform float ce_time;
global uniform float ce_wet;
global uniform float ce_snow;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;

varying vec3 v_world;
varying vec2 v_axis;
varying flat float v_kind;
varying float v_above;
varying float v_glint;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 a = CUSTOM0.xy;
	v_axis = dot(a, a) > 1.0e-4 ? normalize(a) : vec2(1.0, 0.0);
	v_kind = UV2.x;
	v_above = UV2.y;
}

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// value noise 0..1
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// One wave train: slope (gradient of the height) at p, faded out once its wavelength is only a few pixels.
vec2 wave(vec2 p, vec2 dir, float len, float slope, float speed, float t, float foot) {
	float k = 6.2831853 / len;
	float ph = (dot(dir, p) - t * speed) * k;
	float fade = 1.0 - smoothstep(len * 0.12, len * 0.45, foot);
	return dir * (slope * cos(ph) * fade);
}

// Gradient of the water surface in the river frame (x along the current).
vec2 ripples(vec2 p, float t, float foot) {
	vec2 g = vec2(0.0);
	g += wave(p, normalize(vec2(1.0, 0.18)), 9.0, 0.035, flow_speed, t, foot);
	g += wave(p, normalize(vec2(0.82, -0.57)), 4.1, 0.045, flow_speed * 0.9, t, foot);
	g += wave(p, normalize(vec2(0.35, 0.94)), 2.3, 0.05, flow_speed * 0.6, t, foot);
	g += wave(p, normalize(vec2(-0.6, 0.8)), 1.3, 0.055, flow_speed * 0.5, t, foot);
	g += wave(p, normalize(vec2(0.97, 0.25)), 0.71, 0.06, flow_speed * 1.1, t, foot);
	// calm and rough stretches drift with the current
	float calm = vnoise((p - vec2(t * flow_speed, 0.0)) / 37.0);
	return g * mix(0.45, 1.25, calm) * detail;
}

// Anti-aliased joints of a grid of blocks `size` (metres; every second course shifted by row_shift of a block): 1 on
// a joint, fading once the joints are thinner than a pixel.
float joints(vec2 p, vec2 size, float width_m, float row_shift) {
	vec2 q = p / size;
	q.x += row_shift * floor(q.y);
	vec2 f = abs(fract(q) - 0.5) * size;
	vec2 edge = 0.5 * size - f;
	vec2 w = max(fwidth(p), vec2(1.0e-4));
	float jx = 1.0 - smoothstep(width_m * 0.5 - w.x, width_m * 0.5 + w.x, edge.x);
	float jy = 1.0 - smoothstep(width_m * 0.5 - w.y, width_m * 0.5 + w.y, edge.y);
	float fade = 1.0 - smoothstep(width_m * 0.6, width_m * 2.2, max(w.x, w.y));
	return max(jx, jy) * fade;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec2 p = UV;
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	vec2 fw = fwidth(p);
	float foot = max(fw.x, fw.y);
	vec3 tone = base;
	float refl_k = 0.45;
	float rough = 0.95;
	float mirror = 0.0;
	vec3 mirror_col = vec3(0.0);
	vec3 extra_lin = vec3(0.0);
	float snow = 0.0;
	vec3 pools = ce_pools(v_world);
	v_glint = 0.0;
	if (v_kind < 0.5) {
		// --- water ---
		float t = ce_time;
		vec2 g = ripples(p, t, foot);
		vec3 ax = vec3(v_axis.x, 0.0, v_axis.y);
		vec3 ay = vec3(v_axis.y, 0.0, -v_axis.x);
		vec3 n_world = normalize(vec3(0.0, 1.0, 0.0) - ax * g.x - ay * g.y);
		NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
		vec3 view = normalize(CAMERA_POSITION_WORLD - v_world);
		vec3 r = reflect(-view, n_world);
		// Arcade's share of the mirrored sky – by the depth along the view (Arcade: per screen row, by the row's
		// distance dz along the road; water far to the side keeps the share of its row) – varied by the ripples: a
		// ripple turned towards the eye shows more of the water, one turned away more of the sky
		float flat_f = clamp(0.16 + max(-VERTEX.z, 0.0) / 600.0, 0.16, 0.7);
		float tilt = dot(n_world.xz, view.xz);
		mirror = clamp(flat_f * (1.0 - clamp(tilt * 7.0, -0.55, 0.55)), 0.05, 0.85);
		// mostly Arcade's horizon colour (water_tint mirrors sky_bottom), a little of the zenith where the ripples look up
		mirror_col = mix(sky_horizon, sky_zenith, 0.4 * smoothstep(0.03, 0.6, clamp(r.y, 0.0, 1.0)));
		// the water body: Arcade's colour, a little darker in places
		tone = base * (0.93 + 0.14 * vnoise(p / 23.0 + vec2(0.17, 0.43)));
		// at a wall: the water lies in the wall's shade, a thin light seam rides on it
		float wall = 1.0 - smoothstep(0.0, 3.5, v_above);
		tone *= 1.0 - 0.25 * wall;
		float seam = (1.0 - smoothstep(0.05, 0.35, v_above)) * (0.6 + 0.4 * vnoise(vec2(p.x * 1.7, t * 1.3)));
		tone = mix(tone, vec3(0.86, 0.9, 0.9), seam * 0.35 * (1.0 - night * 0.8));
		// glitter of the sun (or the moon) in light(): only where the ripples are, near enough to resolve them
		v_glint = glint * detail * (1.0 - smoothstep(250.0, 700.0, dist));
		// the lamps of the deck and the quays on the water (Arcade: a warm reflection below each lamp at night) – the
		// lamp pools of the lights layer where they reach the water, faint
		extra_lin += pools * 0.25 * night;
		refl_k = 0.0;
		rough = 0.12;
	} else if (v_kind < 1.5) {
		// --- quay wall / revetment of cut stone ---
		float j = joints(p, vec2(1.25, 0.5), 0.045, 0.5);
		vec2 cell = floor(vec2(p.x / 1.25 + 0.5 * floor(p.y / 0.5), p.y / 0.5));
		tone = base * (0.88 + 0.22 * hash12(cell)) * (1.0 - 0.35 * j * detail);
		tone *= 0.92 + 0.12 * vnoise(p * vec2(0.6, 2.2));
		float wet = 1.0 - smoothstep(0.0, 0.9 + 0.5 * vnoise(vec2(p.x * 0.5, 3.1)), v_above);
		tone = mix(tone, tone * vec3(0.42, 0.48, 0.38), wet * 0.85);
		float streak = smoothstep(0.62, 0.9, vnoise(vec2(p.x * 1.9, p.y * 0.12))) * (1.0 - smoothstep(0.5, 4.0, v_above));
		tone *= 1.0 - 0.18 * streak * detail;
	} else if (v_kind < 2.5) {
		// --- brick ---
		float j = joints(p, vec2(0.5, 0.16), 0.03, 0.5);
		vec2 cell = floor(vec2(p.x / 0.5 + 0.5 * floor(p.y / 0.16), p.y / 0.16));
		tone = base * (0.84 + 0.3 * hash12(cell)) * (1.0 - 0.3 * j * detail);
		float wet = 1.0 - smoothstep(0.0, 0.7, v_above);
		tone = mix(tone, tone * vec3(0.45, 0.47, 0.36), wet * 0.8);
	} else if (v_kind < 3.5) {
		// --- embankment: grass in the bank colour, rip-rap stones at the waterline ---
		float n1 = vnoise(p / 6.0);
		float n2 = vnoise(p / 1.3 + vec2(3.7, 1.9));
		tone = base * (0.86 + 0.18 * n1 + 0.08 * (n2 - 0.5) * detail);
		float rip = 1.0 - smoothstep(0.9, 1.6 + 0.6 * n1, v_above);
		vec2 cell = floor(p / 0.7);
		vec3 stone = vec3(0.47, 0.46, 0.43) * (0.8 + 0.4 * hash12(cell));
		stone *= 1.0 - 0.3 * joints(p, vec2(0.7, 0.7), 0.08, 0.37) * detail;
		stone = mix(stone, stone * vec3(0.55, 0.6, 0.48), 1.0 - smoothstep(0.0, 0.5, v_above));
		tone = mix(tone, stone, rip);
		snow = (1.0 - rip) * smoothstep(0.15, 0.55, ce_snow * (0.7 + 0.6 * n1)) * 0.94;
	} else {
		// --- paving: the top of a quay, coping stones ---
		float j = joints(p, vec2(1.0, 0.6), 0.03, 0.5);
		vec2 cell = floor(vec2(p.x + 0.5 * floor(p.y / 0.6), p.y / 0.6));
		tone = base * (0.9 + 0.16 * hash12(cell)) * (1.0 - 0.22 * j * detail);
		snow = smoothstep(0.15, 0.55, ce_snow * (0.7 + 0.6 * vnoise(p / 5.0))) * 0.9;
		refl_k = 0.8;
	}
	tone = mix(tone, vec3(0.933, 0.949, 0.965), snow);
	if (v_kind > 0.5) {
		tone *= 1.0 - 0.16 * ce_wet * (1.0 - snow);
		rough = mix(0.95, 0.6, ce_wet);
	}
	tone = clamp(tone, vec3(0.0), vec3(1.0));
	ALBEDO = tone * (1.0 - mirror);
	ROUGHNESS = rough;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	vec3 light_l = pools * refl_k + ce_headlight_light(v_world, refl_k);
	EMISSION = ce_pools_encode(ce_ground_base_lin(ALBEDO) + ce_pools_to_lin(ALBEDO) * light_l
		+ ce_ground_unshow(mirror_col) * mirror + extra_lin);
	float fog_t = clamp((dist - ce_fog_range.x) / max(ce_fog_range.y - ce_fog_range.x, 1.0), 0.0, 1.0);
	vec3 shown = mix(tone, mirror_col, mirror);
	FOG = vec4(ce_ground_unshow(min(shown * ce_fog_color.rgb * 1.25, vec3(1.0))), 0.7 * fog_t);
}

// The directional light only (the mesh is on render layer 2): Lambert like the ground law assumes, and the glitter of
// the sun (or moon) on the water's ripples – shadowed like everything the light does.
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 lc = LIGHT_COLOR * ATTENUATION;
		float ndl = max(dot(NORMAL, LIGHT), 0.0);
		DIFFUSE_LIGHT += lc * ndl * (1.0 / PI);
		if (v_glint > 0.0) {
			vec3 r = reflect(-LIGHT, NORMAL);
			SPECULAR_LIGHT += lc * pow(max(dot(r, VIEW), 0.0), 700.0) * v_glint * 2.5;
		}
	}
}
