// Modern, material class "vpbr": everything untextured - vehicles incl. wheels and lamps, road furniture,
// trunks, lattice landmarks. One vertex format ("VPBR-L", docs/modelle.md):
//   COLOR.rgb  albedo as sRGB bytes; for the lamp channels 0-13 the LIT colour of the lamp
//   COLOR.a    paint code: 1.0 fixed colour, 0.0 paint, 0.25 paint2, 0.5 paint3
//   UV         (roughness, metallic)
//   UV2        (lamp channel + 0.5, weight 0..1) or (-1, 0) for "no lamp"
// Lamp channels: 0 tail, 1 brake, 2 tail + brake, 3 indicator left, 4 indicator right, 5 head, 6 daytime
// running, 7 reverse, 8 plate, 9 marker, 10 beacon A, 11 beacon B, 12 lights of props (ce_night),
// 13 always on, 14 flood-lit surface (keeps its albedo, adds albedo * weight * ce_night).
// Colour space (measured, GL Compatibility of Godot 4.7): fragment() works with sRGB-encoded colours - the
// engine linearises ALBEDO and EMISSION after this code, and neither vertex colours nor source_color
// uniforms are converted before. So COLOR.rgb and the paint uniforms go to ALBEDO as they are, and energies
// are applied as pow(energy, 1 / 2.2).
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

uniform float lamp_energy = 3.0;              // linear emission of a lamp at level 1, weight 1
uniform float lights_energy = 4.0;            // lamps of props at night (channel 12)
uniform float flood_energy = 1.0;             // flood-lit surfaces (channel 14)
uniform float lamp_off = 0.5;                 // unlit lamp: sRGB factor on its lit colour (0.5 = 22 % linear)
uniform float coat_roughness = 0.06;

global uniform float ce_night;

varying flat float v_code;
varying flat vec2 v_lamp;
varying float v_coat;

// linear factor -> factor on an sRGB-encoded colour
float enc(float linear_factor) {
	return pow(max(linear_factor, 0.0), 0.4545);
}

float lamp_level(float ch) {
	if (ch < 0.5) { return lamp_a.x; }
	if (ch < 1.5) { return lamp_a.y; }
	if (ch < 2.5) { return max(lamp_a.x * 0.35, lamp_a.y); }
	if (ch < 3.5) { return lamp_a.z; }
	if (ch < 4.5) { return lamp_a.w; }
	if (ch < 5.5) { return lamp_b.x; }
	if (ch < 6.5) { return max(1.0 - lamp_b.x, 0.35); }   // daytime running light: dimmed with the low beam
	if (ch < 7.5) { return lamp_b.y; }
	if (ch < 9.5) { return lamp_a.x; }                    // plate light and markers follow the tail lights
	if (ch < 10.5) { return lamp_b.z; }
	if (ch < 11.5) { return lamp_b.w; }
	if (ch < 12.5) { return ce_night; }
	return 1.0;
}

void vertex() {
	v_code = COLOR.a;
	v_lamp = UV2;
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
	if (v_lamp.x >= 0.0) {
		float ch = floor(v_lamp.x);
		if (ch > 13.5) {
			emit = alb * enc(v_lamp.y * ce_night * flood_energy);
		} else {
			float on = clamp(lamp_level(ch), 0.0, 1.0) * v_lamp.y;
			emit = alb * enc(on * (ch > 11.5 && ch < 12.5 ? lights_energy : lamp_energy));
			alb *= lamp_off;        // unlit: dark lamp behind a glossy lens
			rough = 0.12;
			metal = 0.0;
		}
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = emit;
	v_coat = coat;
}

float d_ggx(float ndh, float a) {
	float t = ndh * a;
	float k = a / (1.0 - ndh * ndh + t * t);
	return k * k * (1.0 / PI);
}

float v_ggx(float ndl, float ndv, float a) {
	return 0.5 / mix(2.0 * ndl * ndv, ndl + ndv, a);
}

// The engine's lighting model (Lambert + GGX), plus the sun mask and the clear coat of paint.
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
	}
}
