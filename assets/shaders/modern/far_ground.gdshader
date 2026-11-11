// Modern: the far ground (scripts/race3d/layers/far_ground.gd; contract D16, amendment A-3): a plane below the
// lowest road of the loaded window that follows the camera, and a rim at its far edge that stands up to eye level.
// It closes everything the terrain ribbons leave open – the ground beyond their outer rings, the 12 m gap at a
// medial axis, the hole at the centre of a tight bend – with the same ground the ribbons fade into
// (inc/ground.gdshaderinc: far_color, far_accent …), lit like level ground and fogged by depth like everything else.
// The rim is the picture's "ground at infinity": at 2.4 km it is pure fog colour in every weather – the same colour
// the backdrop shows below the horizon row – and it makes the picture closed without relying on that fill.
//   UV.x   0 = plane, 1 = rim
//   debug_flat   1: flat signal colours instead of the ground (--gfx-debug=far: cyan plane, yellow rim – the terrain
//                cover check counts them)
// Load only after ModernMaterials.ensure_globals() – never with preload().
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://assets/shaders/modern/inc/ground.gdshaderinc"

uniform float debug_flat = 0.0;

global uniform float ce_snow;
global uniform float ce_wet;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = ce_ground_pos(v_world);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	vec3 tone = ce_ground_far(p, dist);
	float snow = ce_ground_snow(ce_snow, p);
	tone = mix(tone, CE_GROUND_SNOW, snow);
	tone *= 1.0 - 0.16 * ce_wet * (1.0 - snow);
	ALBEDO = clamp(tone, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.95, 0.6, max(ce_wet, snow * 0.5));
	SPECULAR = 0.2;
	METALLIC = 0.0;
	// plane and rim are level ground as far as the light is concerned
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	if (debug_flat > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 1.0, 0.0), step(0.5, UV.x));
		SPECULAR = 0.0;
	}
}
