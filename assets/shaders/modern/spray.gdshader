// Modern: spray behind the cars on a wet road (layer "weather", contract §6 R4) – Arcade draws one soft ellipse of
// spray behind a car above 40 km/h (RoadRenderer._draw_car: (speed − 40) / 120 × 0.28 × wet, the fog colour washed
// half towards light grey); here every car throws a plume behind each rear wheel and a trailing mist, trucks and
// buses larger ones, the player's car too.
// One MultiMesh of camera-facing quads, one draw call. Instance: origin = centre of the puff (origin-relative world),
// COLOR = colour (display value, lit on the CPU: ambient, the player's low beam, the red of the car's own rear lights
// at night) and strength in alpha, INSTANCE_CUSTOM = (half width m, half height m, seed, rise: how fast the noise
// climbs – the car's speed). The puff is a soft blob of value noise that drifts with ce_time (frozen in the pause);
// where it meets the road or a car it fades out (soft particles: the depth texture), so no hard line shows.
// Unshaded, alpha mix, depth tested, never written to depth, no shadow, no fog (its strength carries the car's fade).
// Load only through ModernMaterials – never with preload().
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float soft_m = 0.7;                 // the puff fades over this depth in front of what it meets

global uniform float ce_time;

varying vec4 v_col;
varying vec2 v_uv;
varying float v_seed;
varying float v_rise;
varying float v_depth;

float h21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vp.xy += VERTEX.xy * INSTANCE_CUSTOM.xy;
	POSITION = PROJECTION_MATRIX * vp;
	v_depth = -vp.z;
	v_uv = VERTEX.xy;
	v_col = COLOR;
	v_seed = INSTANCE_CUSTOM.z;
	v_rise = INSTANCE_CUSTOM.w;
}

void fragment() {
	// soft round blob, flatter at the bottom (it rises from the road), torn by two octaves of drifting noise
	vec2 q = v_uv;
	float r = length(vec2(q.x, q.y * (q.y < 0.0 ? 1.25 : 0.9)));
	float blob = 1.0 - smoothstep(0.25, 1.0, r);
	vec2 flow = vec2(v_seed * 17.0, v_seed * 5.0 - ce_time * v_rise);
	float n = vnoise(q * 2.2 + flow) * 0.65 + vnoise(q * 5.1 + flow * 1.9 + vec2(3.1, 7.7)) * 0.35;
	float dens = blob * smoothstep(0.18, 0.62, n * (0.6 + 0.4 * blob));
	// soft particles: fade where the puff meets the road, a car or a wall
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw * 2.0 - 1.0, 1.0);
	float scene = -v.z / v.w;
	float soft = clamp((scene - v_depth) / soft_m, 0.0, 1.0);
	ALBEDO = v_col.rgb;
	ALPHA = clamp(v_col.a * dens * soft, 0.0, 1.0);
}
