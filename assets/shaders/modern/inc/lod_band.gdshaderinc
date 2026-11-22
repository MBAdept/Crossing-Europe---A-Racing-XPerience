// Modern (R7c, amendments A-16 and A-22): the level of detail of a prop model chosen PER INSTANCE by its distance from
// the camera, with a dither cross-fade between neighbouring levels – the static models' counterpart of the vehicles'
// xfade, without instance uniforms (A-19).
// Every level of a model draws through a material of its own (ModernMaterials: one material per mesh of a static
// model); builders/props.gd puts the level's distance band on it:
//   lod_band = (in0, in1, out0, out1) in metres from the main camera to the instance's origin (the sprite anchor):
//   the level fades in from in0 to in1 and out from out0 to out1 (ordered dither, the same pattern as the F5 fade);
//   the neighbouring level uses the same band the other way round, so the two share the pixels without a hole and
//   without drawing one pixel twice. Default: always visible (every model that props.gd does not set).
// An instance outside its band is collapsed to one point in vertex() (no fragments at all); the shadow pass decides
// at the middle of the band without dither, so exactly one level casts.
// The main camera is MAIN_CAM_INV_VIEW_MATRIX (in the shadow pass VIEW_MATRIX belongs to the light).
// Also here: the far light (lead decision 2 of R7c) – beyond the reach of the real-time shadows the directional light
// on a model is lowered to its mean shadowed share far_sun (set per model by props.gd; 1 = unchanged), fading in with
// the engine's own shadow fade (shadow_far = (fade start, end) of the view depth, metres; y <= 0: off).

uniform vec4 lod_band = vec4(-2.0, -1.0, 1.0e9, 2.0e9);
uniform vec2 shadow_far = vec2(0.0, 0.0);
uniform float far_sun = 1.0;

varying float v_lod_d;      // distance of the instance from the main camera (vertex)
varying float v_lod_depth;  // view depth of the vertex (m): the far light

// distance of the instance (MODEL_MATRIX includes the MultiMesh instance) from the main camera
float ce_lod_distance(mat4 model, mat4 main_inv_view) {
	return distance(model[3].xyz, main_inv_view[3].xyz);
}

// the instance lies outside its band: collapse it (VERTEX = vec3(0.0) for every vertex of it)
bool ce_lod_hidden(float d) {
	return d < lod_band.x || d > lod_band.w;
}

// fragment(): true = discard this pixel. cam = CAMERA_POSITION_WORLD, main = MAIN_CAM_INV_VIEW_MATRIX[3].xyz: they
// differ in the shadow pass, which keeps a whole level per instance (threshold 0.5, no dither)
bool ce_lod_discard(float d, vec2 frag, vec3 cam, vec3 main) {
	float fin = clamp((d - lod_band.x) / max(lod_band.y - lod_band.x, 0.001), 0.0, 1.0);
	float fout = clamp((lod_band.w - d) / max(lod_band.w - lod_band.z, 0.001), 0.0, 1.0);
	if (fin >= 1.0 && fout >= 1.0) {
		return false;
	}
	float t = distance(cam, main) > 0.5 ? 0.5 : fract(dot(floor(frag), vec2(0.7548776662, 0.5698402910)));
	return t < 1.0 - fin || t >= fout;
}

// light(): the directional light's attenuation with the far light law (depth = view depth of the pixel, metres)
float ce_far_attenuation(float att, bool directional, float depth) {
	if (!directional || shadow_far.y <= 0.0) {
		return att;
	}
	return mix(att, min(att, far_sun), smoothstep(shadow_far.x, shadow_far.y, depth));
}
