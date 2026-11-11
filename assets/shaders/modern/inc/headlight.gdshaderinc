// Modern: the low beam of the player's car on the GROUND (contract D8, §4.5.6) – the analytical cone of the road
// and terrain shaders. The two real SpotLight3D of the lights layer light everything that stands on the ground
// (vehicles, guardrails, signs, props); the ground itself is on render layer 2, which those lights leave out, and
// takes the beam from here: at the grazing angle of a headlight a real spot gives a short hot patch, while the eye
// (and Arcade) sees a long cone – what the texture of the road throws back towards the driver.
//
// Use:   #include "res://assets/shaders/modern/inc/headlight.gdshaderinc"
//        … EMISSION = ce_pools_encode(ce_pools_to_lin(ALBEDO) * (ce_pools(v_world) + ce_headlight_light(v_world, 1.0)));
// (ce_pools_encode / ce_pools_to_lin: inc/pools.gdshaderinc.) v_world = origin-relative world position.
//
// Globals (set by the layer "lights" every frame; this file declares them – do not declare them again):
//   ce_headlight_pos   origin-relative world position between the two lamps, on the nose of the car
//   ce_headlight_dir   unit vector the car points along (the road direction at its nose, level)
//   ce_headlight       x = range in metres, y = intensity: the DISPLAY value Arcade adds at the hot spot
//                      (render.headlight_intensity × the palette's lights; 0 = off)
//   ce_ambient         linear ambient light value (environment rig)
// Law (RoadRenderer._light, the player's cone): d = metres ahead of the lamps, q = metres beside the axis divided
// by the width 0.9 + 0.13 d: l = intensity × smoothstep(-2, 5, d) × (1 - smoothstep(0.3 range, range, d)) / (1 + q⁴),
// tinted with Arcade's lamp colour (1, 0.93, 0.8). Arcade adds l to the display value of the surface
// (albedo × (ambient + l)); here the linear light that does the same on top of ce_ambient is returned, so the cone
// has Arcade's size and falloff at every hour. `reflect` scales l: 1 for asphalt, more for retro-reflective paint,
// less for grass.

global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;
global uniform vec4 ce_ambient;

// Shape of the cone, 0..1 (1 at the hot spot a few metres ahead of the car).
float ce_headlight_shape(vec3 world_pos) {
	vec3 rel = world_pos - ce_headlight_pos;
	float d = dot(rel.xz, ce_headlight_dir.xz);
	float range = ce_headlight.x;
	if (d <= -2.0 || d >= range) {
		return 0.0;
	}
	vec2 side = rel.xz - ce_headlight_dir.xz * d;
	float q = length(side) / (0.9 + max(d, 0.0) * 0.13);
	float q2 = q * q;
	return smoothstep(-2.0, 5.0, d) * (1.0 - smoothstep(range * 0.3, range, d)) / (1.0 + q2 * q2);
}

// Linear light of the cone at an origin-relative world position.
vec3 ce_headlight_light(vec3 world_pos, float reflect) {
	if (ce_headlight.y <= 0.0) {
		return vec3(0.0);
	}
	float l = ce_headlight.y * ce_headlight_shape(world_pos) * reflect;
	if (l <= 0.0) {
		return vec3(0.0);
	}
	vec3 a = pow(max(ce_ambient.rgb, vec3(0.0)), vec3(0.4545));
	return pow(a + l * vec3(1.0, 0.93, 0.8), vec3(2.2)) - ce_ambient.rgb;
}
