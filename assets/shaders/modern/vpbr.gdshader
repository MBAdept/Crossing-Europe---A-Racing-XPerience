// Modern, material class "vpbr": everything untextured - vehicles incl. wheels and lamps, road furniture,
// trunks, lattice landmarks. One vertex format ("VPBR-L", docs/modelle.md):
//   COLOR.rgb  albedo as sRGB bytes; for the lamp channels the LIT colour of the lamp (not 8 and 14: their own
//              albedo)
//   COLOR.a    paint code: 1.0 fixed colour, 0.0 paint, 0.25 paint2, 0.5 paint3
//   UV         (roughness, metallic)
//   UV2        (lamp channel + 0.5, weight 0..1) or (-1, 0) for "no lamp"
// Lamp channels: 0 tail, 1 brake, 2 tail + brake, 3 indicator left, 4 indicator right, 5 head, 6 daytime
// running, 7 reverse, 9 marker, 10 beacon A, 11 beacon B, 12 lights of props (ce_night), 13 always on.
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

uniform float lamp_energy = 1.0;              // linear emission of a lamp at level 1, weight 1 (tail, marker, on)
// factors on lamp_energy: x brake, y indicators, z head / daytime running / reverse, w beacons
uniform vec4 lamp_gain = vec4(2.2, 1.6, 2.0, 2.0);
uniform float lamp_whiten = 0.04;             // wash of an over-driven lamp towards white per unit above 1
uniform float lights_energy = 4.0;            // lamps of props at night (channel 12)
uniform float flood_energy = 1.0;             // flood-lit surfaces (channel 14)
uniform float plate_energy = 0.45;            // number plate under its lamp (channel 8)
uniform float lamp_off = 0.5;                 // unlit lamp: sRGB factor on its lit colour (0.5 = 22 % linear)
uniform float coat_roughness = 0.06;
// environment mirrored by the clear coat, metals and glossy parts (sRGB colours, set by the vehicle layer)
uniform vec4 env_zenith = vec4(0.11, 0.36, 0.79, 1.0);
uniform vec4 env_horizon = vec4(0.73, 0.87, 0.96, 1.0);
uniform vec4 env_ground = vec4(0.27, 0.28, 0.29, 1.0);
uniform vec4 env_tunnel = vec4(0.30, 0.24, 0.16, 1.0);
// strength of every environment reflection (0 = off). Above 1: the palette's sky colours are display values,
// clipped – the real sky is several times brighter than a lit paint, so its mirror image is scaled up.
uniform float env_energy = 1.6;
uniform float coat_fresnel_max = 0.25;        // the coat's Fresnel term is capped here (grazing angles)
uniform float coat_strength = 1.0;            // clear coat on paint (environment and sun lobe)
uniform float paint_base = 0.9;               // sRGB factor of the base coat under the clear coat
uniform float flake_strength = 0.6;           // sparkle of metallic paint (0 = off)
uniform float flake_scale = 260.0;            // flake cells per metre
uniform float flake_near_m = 14.0;            // flakes fade out towards this distance (they would only shimmer)

global uniform float ce_night;

varying flat float v_code;
varying flat vec2 v_lamp;
varying float v_coat;
varying float v_metal_paint;
varying vec3 v_obj;
varying float v_flake_k;

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
	if (ch < 2.5) { return max(a.x * 0.35, a.y * lamp_gain.x) * lamp_energy; }   // tail at 35 %, brake at full gain
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
	v_code = COLOR.a;
	v_lamp = UV2;
	v_obj = VERTEX;
	// flakes only near the camera: farther away a cell is smaller than a pixel and would only shimmer
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	v_flake_k = 1.0 - smoothstep(flake_near_m * 0.45, flake_near_m, dist);
}

void fragment() {
	// path-distance fade (same law as the simulation's visibility): ordered dither, stays opaque
	if (fade < 0.999) {
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (d >= fade) {
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
		if (ch > 13.5) {
			emit = alb * enc(v_lamp.y * ce_night * flood_energy);
		} else if (ch > 7.5 && ch < 8.5) {
			// number plate: a lit surface - its own white by day, the plate lamp's light with the tail lights
			emit = alb * enc(v_lamp.y * clamp(lamp_a.x, 0.0, 1.0) * plate_energy);
		} else {
			emit = lamp_light(alb, lamp_factor(ch) * v_lamp.y);
			alb *= lamp_off;        // unlit: dark lamp behind a glossy lens
			rough = 0.12;
			metal = 0.0;
			lamp = true;
		}
	}
	coat *= coat_strength;
	if (coat > 0.0) {
		alb *= paint_base;          // the base coat under the clear coat
	}
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
		refl *= env_energy;
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
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
	vec3 f0 = mix(vec3(0.04), ALBEDO, METALLIC);
	float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), METALLIC, 1.0);
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
			SPECULAR_LIGHT += lc * ndl * glint * flake_strength * v_flake_k * (v_metal_paint - 0.3) * ALBEDO;
		}
	}
}
