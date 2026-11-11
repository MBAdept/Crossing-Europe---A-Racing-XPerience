// Modern: soft contact shadow under every vehicle (layer "vehicles"), in every preset – the darkening of the road
// right under a car that the sun's shadow map cannot give (ambient occlusion of the underbody), and the only
// shadow of a vehicle when the shadow casters are off ("Schatten: Aus", contract §4.10: blob shadows).
// MultiMesh: instance transform = the vehicle's pose on the road, scaled to the quad (x: width + 2 margins, z:
// length + 2 margins; the mesh is a unit quad in the XZ plane, corners -0.5 .. 0.5); INSTANCE_CUSTOM = (strength
// 0..1, half width m, half length m, margin m). The shape is a rounded rectangle of the footprint: darkest under the
// body, falling off within the margin. Unshaded alpha blend, no depth write; pulled a little towards the camera so
// it never fights with the road surface (depth precision at 900 m is ~5 cm per step). The haze of the depth fog
// (ce_fog_range) takes it away like the fog would.
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float pull = 0.0004;          // fraction of the view distance the quad is pulled towards the camera

global uniform vec2 ce_fog_range;

varying vec2 v_p;                     // position on the footprint in metres (x lateral, y along)
varying vec4 v_custom;
varying float v_fog;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float hw = INSTANCE_CUSTOM.y + INSTANCE_CUSTOM.w;
	float hl = INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.w;
	v_p = vec2(VERTEX.x * 2.0 * hw, VERTEX.z * 2.0 * hl);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = length(vp.xyz);
	vp.xyz *= 1.0 - pull;
	POSITION = PROJECTION_MATRIX * vp;
	v_fog = clamp((d - ce_fog_range.x) / max(ce_fog_range.y - ce_fog_range.x, 1.0), 0.0, 1.0);
}

void fragment() {
	// signed distance to the footprint shrunk by 0.15 m with rounded corners (radius 0.35 m)
	vec2 half_size = max(v_custom.yz - vec2(0.15), vec2(0.05));
	vec2 q = abs(v_p) - half_size + vec2(0.35);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.35;
	float m = max(v_custom.w, 0.05);
	float a = 1.0 - smoothstep(-0.4 * m, m, sd);
	// a little darker towards the middle (the underbody), softer at the ends
	a *= 0.8 + 0.2 * (1.0 - smoothstep(0.0, 1.0, abs(v_p.y) / max(v_custom.z, 0.1)));
	ALBEDO = vec3(0.0);
	ALPHA = clamp(a * v_custom.x * (1.0 - v_fog), 0.0, 1.0);
}
