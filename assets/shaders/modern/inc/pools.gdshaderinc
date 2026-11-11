// Modern: analytical light pools of the road and terrain materials (contract D8, §4.5.6, amendment A-7) –
// first version. The light of street, tunnel and canopy lamps and of the traffic's headlights on the ground is
// not a real light but a sum in the shader of the ground itself: at most 22 pools (16 lamps + 6 traffic cones).
//
// Use:   #include "res://assets/shaders/modern/inc/pools.gdshaderinc"
//        varying vec3 v_world;                    // origin-relative world position
//        void vertex()   { v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
//        void fragment() { vec3 extra = ce_pools(v_world); … }   // LINEAR light, add it to the lit albedo
// A material whose shader includes this file is registered with ModernRenderer.add_pool_material(); the layer
// "lights" then sets the three uniforms on it once per frame (ModernRenderer.pool_materials()). Without that
// layer pool_count stays 0 and ce_pools() returns black.
//
//   pool_pos_r[i]  xyz = centre of the pool on the ground, origin-relative world position (the space of
//                  ModernRenderer.road_to_world() – it moves with the floating origin, so it is set every frame);
//                  w = radius in metres (<= 0: the entry is skipped)
//   pool_col[i]    rgb = LINEAR light value at the centre (ModernMaterials.light_value(colour, energy));
//                  a = kind – 0 lamp pool, 1 headlight pool of a traffic car. This version draws every kind as a
//                  round pool; the layer "lights" may give kind 1 its own shape later.
//   pool_count     number of entries in use (0 .. 22)
// Law of a pool (Arcade's lamp pools, RoadRenderer._light): e = 1 - d² / r², light = colour * e² inside the radius –
// full at the centre, value and slope 0 at the radius, nothing beyond. d is the distance in space, so ground far
// below the pool gets less.
// Colour space: the result is linear light. In GL Compatibility fragment() works with sRGB-encoded ALBEDO and
// EMISSION (docs/modelle.md §4) – the including shader converts where it applies the light.

uniform vec4 pool_pos_r[22];
uniform vec4 pool_col[22];
uniform int pool_count = 0;

vec3 ce_pools(vec3 world_pos) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 22; i++) {
		if (i >= pool_count) {
			break;
		}
		float r = pool_pos_r[i].w;
		if (r <= 0.0) {
			continue;
		}
		vec3 d = world_pos - pool_pos_r[i].xyz;
		float e = 1.0 - dot(d, d) / (r * r);
		if (e > 0.0) {
			sum += pool_col[i].rgb * (e * e);
		}
	}
	return sum;
}
