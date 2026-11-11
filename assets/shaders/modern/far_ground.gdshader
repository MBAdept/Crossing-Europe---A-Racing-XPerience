// Modern: the far ground (scripts/race3d/layers/far_ground.gd; contract D16, amendment A-3): a plane below the
// lowest road of the loaded window that follows the camera, and a rim at its far edge.
// It closes everything the terrain ribbons leave open – the ground beyond their outer rings, the 12 m gap at a
// medial axis, the hole at the centre of a tight bend – with the same ground the ribbons fade into
// (inc/ground.gdshaderinc: far_color, far_accent …).
// The picture below the silhouettes reads as distant land, as in Arcade (lead decision for the assembly RINT-B):
//  - colour: level ground as the ground law shows it – Arcade's colour, tone × palette ambient (display values; the
//    plane lies far beyond the reach of the shadows, so it is drawn unshaded with that value);
//  - fog: Arcade's law for what stands on the ground at the end of the sight (RoadRenderer._modulate): towards the
//    brightened fog colour by 0.7 × the fog amount of the distance – never more fog than Arcade (F4). The engine's
//    depth fog is off for this material (it would turn everything beyond the sight into pure fog colour: a pale
//    strip between the terrain and the silhouettes, at T4 like a lake);
//  - the rim: its top edge stands on the row the backdrop's silhouettes stand on (rim_rows above the horizon row,
//    Arcade's crest rule – layers/backdrop.gd lift_rows), at every angle of view; below it the backdrop's canvas
//    never shows.
//   UV.x   0 = plane, 1 = rim (UV.y 1 = the rim's top edge)
//   debug_flat   1: flat signal colours instead of the ground (--gfx-debug=far: cyan plane, yellow rim – the terrain
//                cover check counts them)
// Light pools and the player's low beam as on the terrain (inc/pools.gdshaderinc, inc/headlight.gdshaderinc, grass
// reflection 0.45): where the plane shows through a gap of the ribbons near the car it is lit like the ground
// around it. The sectors are on render layer 2 like road and terrain; the material is registered with
// ModernRenderer.add_pool_material().
// Load only after ModernMaterials.ensure_globals() – never with preload().
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
#include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
#include "res://assets/shaders/modern/inc/ground.gdshaderinc"

uniform float debug_flat = 0.0;
uniform float rim_rows = 0.0;          // logical rows above the horizon row the rim's top edge stands on
uniform float focal_px = 711.0;        // focal length of the camera in logical pixels (D12)

global uniform float ce_snow;
global uniform float ce_wet;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;

varying vec3 v_world;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (UV.x > 0.5 && UV.y > 0.5) {
		// the rim's top edge: rim_rows above the horizon row for a pitch-free camera – height grows with the depth
		// along the axis of view, so the edge is a straight line on the screen
		vec3 fwd = -INV_VIEW_MATRIX[2].xyz;
		fwd = normalize(vec3(fwd.x, 0.0, fwd.z) + vec3(1.0e-6, 0.0, 0.0));
		float depth = max(dot(w - CAMERA_POSITION_WORLD, fwd), 1.0);
		w.y = CAMERA_POSITION_WORLD.y + rim_rows * depth / focal_px;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	}
	v_world = w;
}

void fragment() {
	vec2 p = ce_ground_pos(v_world);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	vec3 tone = ce_ground_far(p, dist);
	float snow = ce_ground_snow(ce_snow, p);
	tone = mix(tone, CE_GROUND_SNOW, snow);
	tone *= 1.0 - 0.16 * ce_wet * (1.0 - snow);
	tone = clamp(tone, vec3(0.0), vec3(1.0));
	// Arcade's colour of level ground, then Arcade's fog of things on the ground (at most 70 % of the way)
	vec3 shown = tone * ce_ambient_display.rgb;
	float t = clamp((dist - ce_fog_range.x) / max(ce_fog_range.y - ce_fog_range.x, 1.0), 0.0, 1.0);
	shown = mix(shown, tone * ce_fog_color.rgb * 1.25, 0.7 * t);
	vec3 x = ce_ground_unshow(min(shown, vec3(1.0)))
		+ ce_pools_to_lin(tone) * (ce_pools(v_world) * 0.45 + ce_headlight_light(v_world, 0.45));
	ALBEDO = ce_pools_encode(x);
	if (debug_flat > 0.5) {
		ALBEDO = mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 1.0, 0.0), step(0.5, UV.x));
	}
}
