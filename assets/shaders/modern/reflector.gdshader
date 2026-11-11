// Modern: what a retro-reflector throws back of the player's low beam at night – the glints of guardrail
// reflectors and delineator posts (layer "lights", one MultiMesh for the few inside the beam).
// A quad of 1 × 1 per instance; the instance's scale is the radius of the glow in metres, its colour the colour
// of the reflector, the alpha of that colour the strength (0..1, from the beam at its place – set per frame on the
// CPU with the law of inc/headlight.gdshaderinc). The quad always faces the camera and never gets smaller than
// min_px pixels of a 720 rows high picture (Arcade: _glow_fixture, 2 to 2.5 px): a reflector far down the road
// stays a point of light that leads the eye along the bend. Additive, no depth write; geometry in front hides it.
// Load only through ModernMaterials.shader("reflector") – never with preload().
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float min_px = 2.4;
uniform float core = 0.22;        // radius of the bright core as a part of the glow

varying vec2 v_p;
varying vec4 v_col;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = max(-centre.z, 0.5);
	float px_per_m = PROJECTION_MATRIX[1][1] * 0.5 * VIEWPORT_SIZE.y / dist;
	float radius_m = max(length(MODEL_MATRIX[0].xyz), min_px * (VIEWPORT_SIZE.y / 720.0) / px_per_m);
	v_p = VERTEX.xy * 2.0;
	v_col = COLOR;
	POSITION = PROJECTION_MATRIX * vec4(centre + vec3(v_p * radius_m, 0.0), 1.0);
}

void fragment() {
	float d = length(v_p);
	float halo = 1.0 - smoothstep(0.0, 1.0, d);
	float dot_ = 1.0 - smoothstep(core * 0.5, core, d);
	ALBEDO = v_col.rgb * v_col.a * (halo * halo * 0.55 + dot_ * 0.9);
}
