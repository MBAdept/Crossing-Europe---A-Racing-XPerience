// Modern, material class "vpbr": everything untextured - vehicles incl. wheels and lamps, road furniture,
// trunks, lattice landmarks. One vertex format ("VPBR-L", docs/modelle.md):
//   COLOR.rgb  albedo as sRGB bytes; for the lamp channels the LIT colour of the lamp (not 8 and 14: their own
//              albedo)
//   COLOR.a    paint code: 1.0 fixed colour, 0.0 paint, 0.25 paint2, 0.5 paint3; 0.875 a rotor part (fixed colour
//              that turns about the hub: UV2.y = hub height / 128 m, docs/modelle.md §14 – wind turbine, windmill)
//   UV         (roughness, metallic)
//   UV2        (lamp channel + 0.5, weight 0..1) or (-1, 0) for "no lamp"
// Lamp channels: 0 tail, 1 brake, 2 tail + brake, 3 indicator left, 4 indicator right, 5 head, 6 daytime
// running, 7 reverse, 9 marker, 10 beacon A, 11 beacon B, 12 lights of props (ce_night), 13 always on.
// Unlit lamps: vehicle channels 0–11 at lamp_off, props at lamp_off_props (RINT-B: the race sets 0.28 for vehicles –
// at 0.5 an unlit tail lamp read as switched on by day, art review B1); channel 2 shows the tail at tail_level of the
// lamp (race 0.5, brake stays ≥ 2× tail).
// Lit surfaces - they keep their albedo and roughness and get light added: 8 number plate (albedo * weight *
// tail level * plate_energy; drawn as an unlit lamp it was grey by day), 14 flood-lit surface (albedo * weight *
// ce_night * flood_energy).
// Lamp light: the lit colour times the linear factor of its channel (lamp_factor: level * weight * energy). The
// energies keep a tail light clearly below white (0.35 * lamp_energy), so braking is a big step (lamp_gain.x);
// a lamp driven above 1 keeps its hue - it is washed towards white instead of clipping channel by channel
// (an amber indicator at three times white came out lemon yellow, a blue beacon pale blue).
// Paint (codes 0 / 0.25 / 0.5) is a base coat under a clear coat (wave 1, R3): the base is a little darker
// (paint_base), the coat mirrors the environment with Fresnel and has its own sharp sun lobe (light()); metallic
// paints sparkle a little near the camera (flakes). Metals (metallic >= 0.5: chrome, rims) and glossy dielectric
// parts mirror the environment as well. The environment is analytic - a sky dome from the uniforms env_zenith /
// env_horizon / env_ground (sRGB colours, set once per frame by the vehicle layer from the palette; inside a tunnel
// - instance uniform sun = 0 - env_tunnel) - so the paint reflects the sky in every preset and with or without a
// Sky resource on the Environment. Reflections go into EMISSION (not shadowed, fogged like the rest).
// ONE reflection source (assembly of M1, measured with the player car at noon and at dusk, docs/renderer-modern.md
// §12): while the analytic sky is on (env_energy > 0 – the race), the engine's own reflection of the Environment's
// Sky is kept out: SPECULAR 0 and METALLIC 0 for the engine, the diffuse share of a metal taken out of ALBEDO
// (exact in linear light), and light() keeps the true f0 through varyings. Without it (env_energy 0: showroom,
// contact sheet, the neutral checks) the engine reflects its Sky as before.
// Colour space (measured, GL Compatibility of Godot 4.7): fragment() works with sRGB-encoded colours - the
// engine linearises ALBEDO and EMISSION after this code, and neither vertex colours nor source_color
// uniforms are converted before. So COLOR.rgb and the paint uniforms go to ALBEDO as they are; light values are
// summed linear (to_lin) and encoded once (encode) with the renderer's own conversions.
// Load only through ModernMaterials (it registers the ce_* globals first) - never with preload().
shader_type spatial;
render_mode cull_back;

// per instance (set_instance_shader_parameter on the MeshInstance3D / MultiMeshInstance3D node).
// The indices are fixed: a body carries a vpbr and a glass surface, and the uniforms both shaders know
// (fade, sun) must sit at the same index in both.
instance uniform vec4 paint : source_color, instance_index(0) = vec4(0.5, 0.5, 0.52, 0.3);   // rgb + metallic
instance uniform vec4 paint2 : source_color, instance_index(1) = vec4(0.9, 0.9, 0.9, 0.1);
instance uniform vec4 paint3 : source_color, instance_index(2) = vec4(0.1, 0.2, 0.6, 0.1);
instance uniform vec4 lamp_a : instance_index(3) = vec4(0.0);   // tail, brake, indicator left, indicator right
instance uniform vec4 lamp_b : instance_index(4) = vec4(0.0);   // head, reverse, beacon A, beacon B (0..1)
instance uniform float fade : instance_index(5) = 1.0;          // path-distance fade: dither discard, opaque
instance uniform float sun : instance_index(6) = 1.0;           // 0 inside tunnels: masks the directional light
// R3 (wave 1), only in vpbr: fill = extra ambient light on this instance, as a share of ce_ambient (the player car
// gets some, like the brightened player sprite of Arcade: it stays readable in its own shade and at night);
// gloss = factor on the clear coat (the flat panels of the box stand-in would mirror the horizon like glass)
instance uniform float fill : instance_index(7) = 0.0;
instance uniform float gloss : instance_index(8) = 1.0;
// RINT-B: cross-fade of two levels of detail (layers/vehicles.gd: lod1 <-> lod2) with complementary dither masks:
// 0 off; t > 0 the level fading IN keeps the pixels whose dither value is below t; -t the level fading OUT keeps the
// others. Both together cover exactly what one level covers.
instance uniform float xfade : instance_index(9) = 0.0;

uniform float lamp_energy = 1.0;              // linear emission of a lamp at level 1, weight 1 (tail, marker, on)
// factors on lamp_energy: x brake, y indicators, z head / daytime running / reverse, w beacons
uniform vec4 lamp_gain = vec4(2.2, 1.6, 2.0, 2.0);
uniform float lamp_whiten = 0.04;             // wash of an over-driven lamp towards white per unit above 1
uniform float lights_energy = 4.0;            // lamps of props at night (channel 12)
uniform float flood_energy = 1.0;             // flood-lit surfaces (channel 14)
uniform float plate_energy = 0.45;            // number plate under its lamp (channel 8)
uniform float lamp_off = 0.5;                 // unlit VEHICLE lamp (channels 0–11): sRGB factor on its lit colour (0.5 = 22 % linear)
uniform float lamp_off_props = 0.5;           // unlit lamp of a prop (channels 12, 13: lanterns, windows by day)
uniform float tail_level = 0.35;              // channel 2 (one lamp for tail and brake): the tail light's share of the brake
// channel 15 (RINT-B): retro-reflective tape and reflectors light up in the player's low beam – albedo × weight ×
// retro_energy × the cone of inc/headlight.gdshaderinc at the surface (globals of the layer "lights"; 0 without them)
uniform float retro_energy = 2.0;
uniform float coat_roughness = 0.06;
// environment mirrored by the clear coat, metals and glossy parts (sRGB colours, set by the vehicle layer)
uniform vec4 env_zenith = vec4(0.11, 0.36, 0.79, 1.0);
uniform vec4 env_horizon = vec4(0.73, 0.87, 0.96, 1.0);
uniform vec4 env_ground = vec4(0.27, 0.28, 0.29, 1.0);
uniform vec4 env_tunnel = vec4(0.30, 0.24, 0.16, 1.0);
// strength of every environment reflection (0 = off). Above 1: the palette's sky colours are display values,
// clipped – the real sky is several times brighter than a lit paint, so its mirror image is scaled up.
// The defaults of env_energy, paint_base and flake_strength are NEUTRAL (the look of the vertex format alone, as the
// contact sheet and tests/race3d/render/check_models.gd measure it); the vehicle layer sets the race look on the
// shared material (layers/vehicles.gd LOOK: env_energy 1.6, paint_base 0.9, flake_strength 0.6).
uniform float env_energy = 0.0;
// RINT-B: at night (ce_night) the mirrored palette sky and the player's fill light fall to these shares – the palette's
// night sky is a painted, brightened one, and Arcade's brightening of its player sprite is additive (+0.08), not a
// factor: the metallic player car showed +44 % against its sprite at 22:00 (measured). Neutral by default (1.0).
uniform float env_night = 1.0;
uniform float fill_night = 1.0;
uniform float coat_fresnel_max = 0.25;        // the coat's Fresnel term is capped here (grazing angles)
uniform float coat_strength = 1.0;            // clear coat on paint (environment and sun lobe)
uniform float paint_base = 1.0;               // sRGB factor of the base coat under the clear coat
// RINT-B: exposure of paint (art review A1/B8/C2). The ambient and the sun pass are shown separately and added, so a
// bright paint ran past 1.0 – 62 % of the yellow kompakt's paint pixels at 255, lemon instead of amber, white trucks
// without form. A soft knee on the brightest channel of a paint colour (hue-preserving: the colour is scaled) and a
// little desaturation bring hue and value within 10 % of the Cycles sprites (measured in the game camera, noon, dusk,
// night). Neutral by default (knee 1.0, slope 1.0, desaturation 0); the vehicle layer sets the race look.
uniform float paint_knee = 1.0;               // brightest channel of a paint colour above which it is compressed …
uniform float paint_knee_slope = 1.0;         // … with this slope (1 = no compression)
uniform float paint_desat = 0.0;              // share of the paint colour taken towards its luminance
uniform float flake_strength = 0.0;           // sparkle of metallic paint (0 = off)
uniform float flake_scale = 260.0;            // flake cells per metre
uniform float flake_near_m = 14.0;            // flakes fade out towards this distance (they would only shimmer)
// rotors (paint code 0.875): they turn about the model's Z axis through the hub, angle = ce_time x rotor_speed plus a
// phase from the position of the instance – every turbine of a wind farm at its own angle. ce_time is view time:
// the rotors stand still with the paused game.
uniform float rotor_speed = 1.35;             // rad/s

global uniform float ce_night;
global uniform vec4 ce_ambient;               // linear ambient light (ModernMaterials.light_value), for `fill`
global uniform float ce_time;
global uniform vec3 ce_headlight_pos;         // the player's low beam (layer "lights"): channel 15
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;

varying flat float v_code;
varying flat vec2 v_lamp;
varying float v_coat;
varying float v_metal_paint;
varying vec3 v_obj;
varying float v_flake_k;
varying vec3 v_f0;                    // f0 of the engine's lighting model for light() (linear), whatever ALBEDO says
varying float v_metal;
varying vec3 v_alb_lin;               // linear albedo for the flakes
varying vec3 v_world;                 // origin-relative world position (channel 15: the low beam at the surface)

// The cone of the player's low beam, 0..1 – the law of inc/headlight.gdshaderinc (ce_headlight_shape), here without
// that file's light conversion (it needs the pool uniforms of the ground materials).
float retro_cone(vec3 world_pos) {
	vec3 rel = world_pos - ce_headlight_pos;
	float d = dot(rel.xz, ce_headlight_dir.xz);
	float range = ce_headlight.x;
	if (ce_headlight.y <= 0.0 || d <= -2.0 || d >= range) {
		return 0.0;
	}
	vec2 side = rel.xz - ce_headlight_dir.xz * d;
	float q = length(side) / (0.9 + max(d, 0.0) * 0.13);
	float q2 = q * q;
	return smoothstep(-2.0, 5.0, d) * (1.0 - smoothstep(range * 0.3, range, d)) / (1.0 + q2 * q2);
}

// linear factor -> factor on an sRGB-encoded colour
float enc(float linear_factor) {
	return pow(max(linear_factor, 0.0), 0.4545);
}

// the renderer's sRGB -> linear for ALBEDO and EMISSION values …
vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// … and its inverse (two Newton steps): the value fragment() writes so that the renderer arrives at linear x
vec3 encode(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 c = pow(x, vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

// Linear emission factor of a lamp channel at weight 1: its level (instance uniforms, ce_night) times its energy.
float lamp_factor(float ch) {
	vec4 a = clamp(lamp_a, 0.0, 1.0);
	vec4 b = clamp(lamp_b, 0.0, 1.0);
	if (ch < 0.5) { return a.x * lamp_energy; }
	if (ch < 1.5) { return a.y * lamp_energy * lamp_gain.x; }
	if (ch < 2.5) { return max(a.x * tail_level, a.y * lamp_gain.x) * lamp_energy; }   // tail at tail_level, brake at full gain
	if (ch < 3.5) { return a.z * lamp_energy * lamp_gain.y; }
	if (ch < 4.5) { return a.w * lamp_energy * lamp_gain.y; }
	if (ch < 5.5) { return b.x * lamp_energy * lamp_gain.z; }
	if (ch < 6.5) { return max(1.0 - b.x, 0.35) * lamp_energy * lamp_gain.z * 0.6; }   // dimmed with the low beam
	if (ch < 7.5) { return b.y * lamp_energy * lamp_gain.z * 0.6; }
	if (ch < 9.5) { return a.x * lamp_energy; }                    // markers follow the tail lights
	if (ch < 10.5) { return b.z * lamp_energy * lamp_gain.w; }
	if (ch < 11.5) { return b.w * lamp_energy * lamp_gain.w; }
	if (ch < 12.5) { return clamp(ce_night, 0.0, 1.0) * lights_energy; }
	return lamp_energy;
}

// Emission of a lamp: lit colour (sRGB-encoded) times the linear factor e, sRGB-encoded again. Above white the
// hue stays: the colour is normalised to its largest channel and washed towards white by lamp_whiten per unit of
// overdrive (at most 35 %) - that is what the screen shows. The overdrive itself stays in the channels that
// carry the lamp's colour (exponent t^4: all of it in the largest channel, next to none in a small one), so a
// glow pass still finds the lamp brighter than white without the small channels being lifted with it.
vec3 lamp_light(vec3 lit, float e) {
	vec3 c = pow(lit, vec3(2.2)) * e;
	float m = max(c.r, max(c.g, c.b));
	if (m > 1.0) {
		vec3 t = mix(c / m, vec3(1.0), clamp((m - 1.0) * lamp_whiten, 0.0, 0.35));
		c = t * pow(vec3(m), t * t * t * t);
	}
	return pow(c, vec3(0.4545));
}

// The environment in direction r (world), blurred towards its mean with the roughness: linear light. Below the
// horizon the road and the ground, just above it a band of landscape (trees, hills, buildings: the ground colour
// lifted towards the haze), then the sky up to the zenith.
vec3 env_light(vec3 r, float rough) {
	vec3 zen = to_lin(env_zenith.rgb);
	vec3 hor = to_lin(env_horizon.rgb);
	vec3 gnd = to_lin(env_ground.rgb);
	vec3 land = mix(gnd * 1.4, hor, 0.3);
	float soft = 0.04 + rough * 0.5;
	vec3 sky = mix(hor, zen, smoothstep(0.1, 0.7, r.y));
	vec3 c = mix(land, sky, smoothstep(0.06 - soft * 0.5, 0.12 + soft, r.y));
	c = mix(gnd, c, smoothstep(-0.06 - soft, 0.0, r.y));
	vec3 mean = zen * 0.25 + hor * 0.3 + land * 0.2 + gnd * 0.25;
	vec3 e = mix(c, mean, clamp(rough * 1.8, 0.0, 1.0));
	// inside a tunnel (sun = 0) the dim, warm tube instead of the sky
	return mix(to_lin(env_tunnel.rgb) * mix(0.6, 1.0, max(r.y, 0.0)), e, clamp(sun, 0.0, 1.0));
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	if (COLOR.a > 0.8 && COLOR.a < 0.95) {
		// rotor part: turn VERTEX and NORMAL about the hub (0, UV2.y x 128 m) in the model's XY plane
		float hub = UV2.y * 128.0;
		vec3 wp0 = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		// negative: clockwise as seen from +Z, the side that faces the road – as real turbines turn seen from upwind
		float ang = -ce_time * rotor_speed + wp0.x * 0.37 + wp0.z * 0.23;
		float c = cos(ang);
		float s = sin(ang);
		vec2 q = VERTEX.xy - vec2(0.0, hub);
		VERTEX.xy = vec2(c * q.x - s * q.y, s * q.x + c * q.y) + vec2(0.0, hub);
		NORMAL.xy = vec2(c * NORMAL.x - s * NORMAL.y, s * NORMAL.x + c * NORMAL.y);
	}
	v_code = COLOR.a;
	v_lamp = UV2;
	v_obj = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// flakes only near the camera: farther away a cell is smaller than a pixel and would only shimmer
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	v_flake_k = 1.0 - smoothstep(flake_near_m * 0.45, flake_near_m, dist);
}

void fragment() {
	// path-distance fade (same law as the simulation's visibility): ordered dither, stays opaque; the same dither
	// value splits the pixels between two levels while they cross-fade (xfade)
	if (fade < 0.999 || xfade != 0.0) {
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (d >= fade || (xfade > 0.0 && d >= xfade) || (xfade < 0.0 && d < -xfade)) {
			discard;
		}
	}
	vec3 alb = COLOR.rgb;
	float rough = UV.x;
	float metal = UV.y;
	float coat = 0.0;
	if (v_code < 0.125) {
		alb = paint.rgb; metal = paint.a; coat = 1.0;
	} else if (v_code < 0.375) {
		alb = paint2.rgb; metal = paint2.a; coat = 1.0;
	} else if (v_code < 0.75) {
		alb = paint3.rgb; metal = paint3.a; coat = 1.0;
	}
	vec3 emit = vec3(0.0);
	bool lamp = false;
	if (v_lamp.x >= 0.0) {
		float ch = floor(v_lamp.x);
		if (ch > 14.5) {
			// retro-reflective surface: lit by the player's low beam, not by the night (RINT-B)
			emit = alb * enc(v_lamp.y * retro_energy * ce_headlight.y * retro_cone(v_world));
		} else if (ch > 13.5) {
			emit = alb * enc(v_lamp.y * ce_night * flood_energy);
		} else if (ch > 7.5 && ch < 8.5) {
			// number plate: a lit surface - its own white by day, the plate lamp's light with the tail lights
			emit = alb * enc(v_lamp.y * clamp(lamp_a.x, 0.0, 1.0) * plate_energy);
		} else {
			emit = lamp_light(alb, lamp_factor(ch) * v_lamp.y);
			alb *= ch < 11.5 ? lamp_off : lamp_off_props;   // unlit: dark lamp behind a glossy lens
			rough = 0.12;
			metal = 0.0;
			lamp = true;
		}
	}
	coat *= coat_strength * gloss;
	if (coat > 0.0) {
		// exposure of the paint: soft knee on its brightest channel, a little desaturation, the base coat factor
		float pm = max(alb.r, max(alb.g, alb.b));
		if (pm > paint_knee) {
			alb *= (paint_knee + (pm - paint_knee) * paint_knee_slope) / pm;
		}
		alb = mix(alb, vec3(dot(alb, vec3(0.2126, 0.7152, 0.0722))), paint_desat);
		alb *= paint_base;          // the base coat under the clear coat
	}
	float night = clamp(ce_night, 0.0, 1.0);
	vec3 fill_light = fill > 0.0 ? to_lin(alb) * ce_ambient.rgb * fill * mix(1.0, fill_night, night) : vec3(0.0);
	// mirrored environment: clear coat (Fresnel of a 1.5 coat), metals (tinted by their colour), glossy parts
	vec3 refl = vec3(0.0);
	if (env_energy > 0.0) {
		vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 r = reflect(-v_w, n_w);
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float f5 = pow(1.0 - ndv, 5.0);
		if (coat > 0.0) {
			// (capped towards grazing angles: there the coat of a curved body mirrors a smeared landscape, not a mirror)
			refl += env_light(r, coat_roughness) * min(0.04 + 0.96 * f5, coat_fresnel_max) * coat;
		}
		if (metal >= 0.5 && !lamp) {
			vec3 f0 = to_lin(alb);
			refl += env_light(r, rough) * mix(f0, vec3(1.0), f5) * (metal - 0.5) * 2.0 * (1.0 - coat * 0.5);
		} else if (coat <= 0.0 && rough < 0.3) {
			refl += env_light(r, rough) * (0.04 + 0.96 * f5) * (1.0 - rough / 0.3) * 0.6;
		}
		refl *= env_energy * mix(1.0, env_night, night);
	}
	v_alb_lin = to_lin(alb);
	v_f0 = mix(vec3(0.04), v_alb_lin, metal);
	v_metal = metal;
	ROUGHNESS = rough;
	if (env_energy > 0.0) {
		// the analytic sky is the only reflection: no engine reflection (F0 0), a metal's missing diffuse share
		// taken out of ALBEDO in linear light (the engine multiplies the diffuse light by albedo x (1 - metallic))
		ALBEDO = encode(v_alb_lin * (1.0 - metal));
		METALLIC = 0.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = alb;
		METALLIC = metal;
		SPECULAR = 0.5;
	}
	refl += fill_light;
	EMISSION = (refl.r + refl.g + refl.b > 0.0) ? encode(to_lin(emit) + refl) : emit;
	v_coat = coat;
	v_metal_paint = coat > 0.0 ? metal : 0.0;
}

float d_ggx(float ndh, float a) {
	float t = ndh * a;
	float k = a / (1.0 - ndh * ndh + t * t);
	return k * k * (1.0 / PI);
}

float v_ggx(float ndl, float ndv, float a) {
	return 0.5 / mix(2.0 * ndl * ndv, ndl + ndv, a);
}

// The engine's lighting model (Lambert + GGX), plus the sun mask, the clear coat of paint and its flakes.
void light() {
	float k = LIGHT_IS_DIRECTIONAL ? sun : 1.0;
	vec3 lc = LIGHT_COLOR * ATTENUATION * k;
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += lc * ndl * (1.0 / PI);
	vec3 h = normalize(VIEW + LIGHT);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float ndv = max(dot(NORMAL, VIEW), 1e-4);
	float ldh = clamp(dot(LIGHT, h), 0.0, 1.0);
	float f5 = pow(1.0 - ldh, 5.0);
	float a = max(ROUGHNESS * ROUGHNESS, 0.002);
	vec3 f0 = v_f0;
	float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), v_metal, 1.0);
	vec3 fr = f0 + (f90 - f0) * f5;
	SPECULAR_LIGHT += lc * SPECULAR_AMOUNT * ndl * d_ggx(ndh, a) * v_ggx(ndl, ndv, a) * fr;
	if (v_coat > 0.0) {
		float dr = d_ggx(ndh, mix(0.001, 0.1, coat_roughness));
		float gr = 0.25 / max(ldh * ldh, 1e-4);
		SPECULAR_LIGHT += lc * SPECULAR_AMOUNT * v_coat * gr * mix(0.04, 1.0, f5) * dr * ndl;
		// metallic flakes: single cells catch the sun in a broad lobe around the highlight
		if (v_metal_paint > 0.3 && v_flake_k > 0.0 && flake_strength > 0.0) {
			float n = hash13(floor(v_obj * flake_scale));
			float glint = step(0.93, n) * pow(ndh, 24.0);
			SPECULAR_LIGHT += lc * ndl * glint * flake_strength * v_flake_k * (v_metal_paint - 0.3) * v_alb_lin;
		}
	}
}
