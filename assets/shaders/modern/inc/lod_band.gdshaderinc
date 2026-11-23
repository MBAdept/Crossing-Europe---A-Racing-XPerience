// Modern (R7c, amendments A-16 and A-22): the level of detail of a prop model chosen PER INSTANCE by its distance from
// the camera, with a dither cross-fade between neighbouring levels – the static models' counterpart of the vehicles'
// xfade, without instance uniforms (A-19).
// Every level of a model draws through a material of its own (ModernMaterials: one material per mesh of a static
// model); builders/props.gd puts the level's distance band on it:
//   lod_band = (in0, in1, out0, out1) in metres from the main camera to the instance's origin (the sprite anchor):
//   the level fades in from in0 to in1 and out from out0 to out1 (ordered dither, the same pattern as the F5 fade);
//   the neighbouring level uses the same band the other way round, so the two share the pixels without a hole and
//   without drawing one pixel twice. Default: always visible (every model that props.gd does not set).
// An instance outside its band is collapsed to one point in vertex() (no fragments at all); in the shadow pass the
// finer level casts through the whole band, without dither (ce_lod_discard), so exactly one level casts.
// The main camera is MAIN_CAM_INV_VIEW_MATRIX (in the shadow pass VIEW_MATRIX belongs to the light).
// Also here: the far light (lead decision 2 of R7c) – beyond the reach of the real-time shadows the directional light
// on a model is lowered to its mean shadowed share far_sun (set per model by props.gd; 1 = unchanged), fading in with
// the engine's own shadow fade (shadow_far = (fade start, end) of the view depth, metres; y <= 0: off).
// FIX-R7c (QR7c-06): the band hangs on the distance, so an instance inside it would stay in the dither of two levels
// while the camera stands (countdown, traffic jam, police stop). ce_lod_still (0..1, builders/props.gd from the camera's
// speed, ramped over 0.4 s) narrows every band to its middle: a standing camera sees one level per instance, hard, and
// the narrowing over time is itself a cross-fade (the threshold sweeps through the same ordered dither). 0 = the band.

uniform vec4 lod_band = vec4(-2.0, -1.0, 1.0e9, 2.0e9);
uniform vec2 shadow_far = vec2(0.0, 0.0);
uniform float far_sun = 1.0;
global uniform float ce_lod_still;

varying float v_lod_d;      // distance of the instance from the main camera (vertex)
varying float v_lod_depth;  // view depth of the vertex (m): the far light
varying float v_lod_shadow; // 1 in the shadow pass (the camera of the pass is not the main camera), 0 else

// distance of the instance (MODEL_MATRIX includes the MultiMesh instance) from the main camera
float ce_lod_distance(mat4 model, mat4 main_inv_view) {
	return distance(model[3].xyz, main_inv_view[3].xyz);
}

// the instance lies outside its band: collapse it (VERTEX = vec3(0.0) for every vertex of it)
bool ce_lod_hidden(float d) {
	return d < lod_band.x || d > lod_band.w;
}

// vertex(): 1 in the shadow pass – the pass's camera (CAMERA_POSITION_WORLD) is not the main camera; MAIN_CAM_INV_VIEW_MATRIX
// exists in vertex() only
float ce_lod_shadow_pass(vec3 cam, mat4 main_inv_view) {
	return distance(cam, main_inv_view[3].xyz) > 0.5 ? 1.0 : 0.0;
}

// fragment(): true = discard this pixel (d = v_lod_d, shadow = v_lod_shadow). In the shadow pass exactly one level of
// an instance casts, without dither: the finer one through the whole band (a level casts once it has faded in
// completely and until it has faded out completely) – the coarse shell of a far level would otherwise shadow the
// recessed windows and doors of the finer level while the two share the pixels (render check check_lod_band: the
// middle of the band changed 9.3 % of a house's pixels at once, more than the hard swap's 7.1 %)
bool ce_lod_discard(float d, float shadow, vec2 frag) {
	// the band narrowed towards its middle by ce_lod_still (both neighbours narrow the same shared band: still
	// complementary); the shadow pass follows the narrowed band, so a standing camera's caster is the level it shows
	// (at least ±0.5 mm wide: the two shares stay complementary – a narrower band than the 0.001 below would leave a hole)
	vec4 b = lod_band;
	float still = clamp(ce_lod_still, 0.0, 1.0);
	if (still > 0.0) {
		vec2 mid = vec2(b.x + b.y, b.z + b.w) * 0.5;
		vec2 hw = max(vec2(b.y - b.x, b.w - b.z) * 0.5 * (1.0 - still), vec2(0.0005));
		b = vec4(mid.x - hw.x, mid.x + hw.x, mid.y - hw.y, mid.y + hw.y);
	}
	float fin = clamp((d - b.x) / max(b.y - b.x, 0.001), 0.0, 1.0);
	float fout = clamp((b.w - d) / max(b.w - b.z, 0.001), 0.0, 1.0);
	if (fin >= 1.0 && fout >= 1.0) {
		return false;
	}
	if (shadow > 0.5) {
		return fin < 1.0 || fout <= 0.0;
	}
	float t = fract(dot(floor(frag), vec2(0.7548776662, 0.5698402910)));
	return t < 1.0 - fin || t >= fout;
}

// light(): the directional light's attenuation with the far light law (depth = view depth of the pixel, metres)
float ce_far_attenuation(float att, bool directional, float depth) {
	if (!directional || shadow_far.y <= 0.0) {
		return att;
	}
	return mix(att, min(att, far_sun), smoothstep(shadow_far.x, shadow_far.y, depth));
}
