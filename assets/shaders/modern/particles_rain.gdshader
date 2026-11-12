// Modern: rain in the air (layer "weather", contract §6 R4) – stateless GPU particles. One MultiMesh of quads, one
// draw call; every drop's place is a pure function of its instance number, the camera and the game time (ce_time):
// nothing is simulated or stored, so the picture is deterministic (Rule 10: --gfx-sync, --shot-fast, goldens), it
// stands still with the game (pause: ce_time and the camera do not move) and the floating origin cannot make it jump.
//
// The drops live in a box in camera space – like Arcade's (RoadRenderer._draw_weather: drops 3 … 45 m ahead, ±14 m
// beside the camera, up to 9 m high, falling 8.5 m/s, drifting 0.6 m/s): x to the right of the camera's forward
// direction, y up from the camera, z ahead. The box turns with the camera; along z it moves with the camera's
// travel on the road (odo = camera_z modulo the depth of the box): the drops stream past as Arcade's do. Every axis
// wraps – the drops fade in and out near the faces of the box instead of popping.
// Each drop is a streak: the segment from where it was `exposure` seconds ago to where it is (Arcade: 18 ms, the fall
// part stretched 2.5 ×), drawn width_px logical pixels wide; a streak that would reach behind the near plane is cut.
// Brightness: Arcade's law – the drop colour × min(1, ambient + 0.35) (display values, ce_ambient_display) – plus the
// player's low beam where a drop hangs in the cone (ce_headlight*): at night the rain glitters in the headlights.
// Inside a tunnel the layer hides the node (contract: off in tunnels); `fade` dims it on the ramp at the portal.
// Unshaded, alpha mix, depth tested (drops behind a car or the road are hidden), never written to depth, no shadow.
// Colour space: ALBEDO is a display value; the engine linearises it (docs/modelle.md §4).
// Load only through ModernMaterials – never with preload().
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 cam_pos = vec3(0.0);                 // camera position (origin-relative world)
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);      // forward of the box: the camera's direction, level, unit length
uniform float odo = 0.0;                          // fposmod(camera_z, box depth): the camera's travel along the road
uniform vec3 cam_vel = vec3(0.0, 0.0, -1.0);      // camera velocity (world, m/s)
uniform vec3 box_lo = vec3(-14.0, -3.6, 3.0);     // box in camera space: x right, y up from the camera, z ahead
uniform vec3 box_hi = vec3(14.0, 6.0, 45.0);
uniform float fall = 8.5;                         // m/s
uniform float drift = 0.6;                        // m/s along the wind
uniform float exposure = 0.018;                   // s: the streak shows where the drop was this long ago
uniform float fall_stretch = 2.5;                 // the fall part of the streak is drawn this much longer
uniform float width_px = 1.1;                     // logical px
uniform float logical_h = 720.0;                  // rows the logical pixels refer to
uniform vec4 drop_color : source_color = vec4(0.8, 0.84, 0.92, 0.3);
uniform float fade = 1.0;                         // 0..1 (portal ramp of a tunnel)
uniform float near_fade_m = 2.0;                  // drops closer than this fade out (Arcade spawns them from 3 m)

global uniform float ce_time;
global uniform vec4 ce_wind;
global uniform vec4 ce_ambient_display;
global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;

varying float v_alpha;
varying float v_light;
varying float v_across;

float hash11(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

// Light of the player's low beam on a drop in the air: the cone of inc/headlight.gdshaderinc in 3D (a drop above the
// beam's axis gets less), 0..1 × the intensity.
float beam_at(vec3 p) {
	if (ce_headlight.y <= 0.0) {
		return 0.0;
	}
	vec3 rel = p - ce_headlight_pos;
	float d = dot(rel, ce_headlight_dir);
	if (d <= 0.0 || d >= ce_headlight.x) {
		return 0.0;
	}
	vec3 side = rel - ce_headlight_dir * d;
	float q = length(side) / (0.9 + d * 0.13);
	float q2 = q * q;
	return ce_headlight.y * smoothstep(0.0, 4.0, d) * (1.0 - smoothstep(ce_headlight.x * 0.3, ce_headlight.x, d)) / (1.0 + q2 * q2);
}

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 size = box_hi - box_lo;
	vec3 seed = vec3(hash11(id * 1.37 + 0.11), hash11(id * 2.11 + 0.73), hash11(id * 0.97 + 2.31)) * size;
	vec3 right = normalize(cross(cam_fwd, vec3(0.0, 1.0, 0.0)));
	vec2 wind_dir = normalize(ce_wind.xy + vec2(1.0e-4, 0.0));
	float wind_x = dot(vec3(wind_dir.x, 0.0, wind_dir.y), right) * drift * (0.6 + ce_wind.z);
	float t = ce_time + hash11(id * 3.7) * 7.0;
	// place in the box: x drifts with the wind, y falls, z comes towards the camera with its travel
	vec3 q;
	q.x = box_lo.x + mod(seed.x + wind_x * t, size.x);
	q.y = box_hi.y - mod(seed.y + fall * t, size.y);
	q.z = box_lo.z + mod(seed.z - odo, size.z);
	vec3 p = cam_pos + right * q.x + vec3(0.0, q.y, 0.0) + cam_fwd * q.z;
	// where it was `exposure` ago (the fall stretched like Arcade's streak); the camera's own motion is in the view
	vec3 v_drop = right * wind_x + vec3(0.0, -fall * fall_stretch, 0.0);
	vec3 p_prev = p - (v_drop - cam_vel) * exposure;
	vec4 c0 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p, 1.0));
	vec4 c1 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p_prev, 1.0));
	// cut the tail of a streak that would reach behind the near plane
	if (c1.w < 0.5) {
		c1 = mix(c0, c1, clamp((c0.w - 0.5) / max(c0.w - c1.w, 1.0e-4), 0.0, 1.0));
	}
	vec2 s0 = c0.xy / max(c0.w, 1.0e-3);
	vec2 s1 = c1.xy / max(c1.w, 1.0e-3);
	float aspect = VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0);
	vec2 px_ndc = vec2(2.0 / (logical_h * aspect), 2.0 / logical_h);
	vec2 dir = (s0 - s1) / px_ndc;
	float len = length(dir);
	dir = len > 1.0e-4 ? dir / len : vec2(0.0, -1.0);
	vec2 perp = vec2(-dir.y, dir.x);
	// VERTEX: x -1..1 across, y -1 (tail) .. 1 (head); a streak is at least one pixel long
	float along = VERTEX.y * 0.5 + 0.5;
	vec4 c = mix(c1, c0, along);
	vec2 ext = dir * (VERTEX.y * 0.5) * max(0.0, 1.0 - len) + perp * VERTEX.x * width_px * 0.5;
	c.xy += ext * px_ndc * c.w;
	POSITION = c;
	v_across = VERTEX.x;
	// fades: near the camera, at the faces of the box (no popping where the drops wrap), the portal ramp
	float a = smoothstep(near_fade_m, near_fade_m + 1.5, q.z) * (1.0 - smoothstep(box_hi.z - 8.0, box_hi.z, q.z));
	a *= 1.0 - smoothstep(0.8, 1.0, abs(q.x - (box_lo.x + box_hi.x) * 0.5) / (size.x * 0.5));
	a *= smoothstep(box_hi.y, box_hi.y - 1.5, q.y);
	// a drop whose streak is shorter than two pixels is far away: dimmer (many of them melt into a haze)
	a *= clamp(len * 0.5, 0.35, 1.0);
	v_alpha = drop_color.a * a * fade * (c0.w > 0.2 ? 1.0 : 0.0);
	// the low beam lights the drops it passes through – mostly the near ones (far in the cone they would pile up into
	// a bright cloud at the vanishing point)
	v_light = beam_at(p) * (1.0 - smoothstep(22.0, 55.0, q.z));
}

void fragment() {
	vec3 amb = min(ce_ambient_display.rgb + vec3(0.35), vec3(1.0));
	vec3 col = drop_color.rgb * amb + vec3(1.0, 0.93, 0.8) * v_light * 0.9;
	ALBEDO = min(col, vec3(1.0));
	ALPHA = clamp(v_alpha * (1.0 - abs(v_across) * 0.5) * (1.0 + v_light), 0.0, 1.0);
}
