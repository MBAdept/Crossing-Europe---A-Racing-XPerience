// Modern: falling snow (layer "weather", contract §6 R4) – stateless GPU particles like particles_rain.gdshader (read
// its header: one MultiMesh, places a pure function of instance, camera and ce_time; deterministic, frozen in the
// pause, no jump at a rebase of the floating origin).
// Arcade's snow (RoadRenderer._draw_weather): flakes 2 … 38 m ahead, ±14 m beside the camera, up to 9 m high, falling
// 1.2 m/s, swaying ±0.7 m/s, white at 0.85 × min(1, ambient + 0.35), 1.2 … 5.5 px (0.045 m at the flake); above
// 25 m/s the flakes are drawn as streaks of their motion. Here the same: a round soft flake of flake_m (never smaller
// than min_px logical pixels), stretched along its motion on the screen while the camera is fast (the segment from
// where it was `exposure` ago), and lit by the player's low beam where it drifts through the cone – at night the
// snow glitters in front of the car instead of being a grey veil.
// Unshaded, alpha mix, depth tested, never written to depth, no shadow; ALBEDO is a display value.
// Load only through ModernMaterials – never with preload().
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 cam_pos = vec3(0.0);
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);
uniform float odo = 0.0;
uniform vec3 cam_vel = vec3(0.0, 0.0, -1.0);
uniform vec3 box_lo = vec3(-14.0, -3.6, 2.0);
uniform vec3 box_hi = vec3(14.0, 6.0, 38.0);
uniform float fall = 1.2;
uniform float sway = 0.7;                         // m/s of the sideways sway (Arcade: sin(t × 0.9 + i) × 0.7)
uniform float flake_m = 0.045;
uniform float min_px = 1.2;
uniform float max_px = 5.5;
uniform float exposure = 0.012;                   // s: motion blur of a fast camera (none below a few px of travel)
uniform float logical_h = 720.0;
uniform vec4 flake_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float fade = 1.0;
uniform float near_fade_m = 1.6;

global uniform float ce_time;
global uniform vec4 ce_wind;
global uniform vec4 ce_ambient_display;
global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;

varying float v_alpha;
varying float v_light;
varying vec2 v_q;                                  // the quad's corner coordinates, scaled: round flake in the middle
varying float v_stretch;

float hash11(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

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
	float wind_x = dot(vec3(wind_dir.x, 0.0, wind_dir.y), right) * (0.2 + 0.5 * ce_wind.z);
	float phase = hash11(id * 5.3) * 6.2832;
	float t = ce_time + hash11(id * 3.7) * 11.0;
	vec3 q;
	q.x = box_lo.x + mod(seed.x + wind_x * t + sway / 0.9 * sin(t * 0.9 + phase), size.x);
	q.y = box_hi.y - mod(seed.y + fall * t * (0.8 + 0.4 * hash11(id * 0.31)), size.y);
	q.z = box_lo.z + mod(seed.z - odo, size.z);
	vec3 p = cam_pos + right * q.x + vec3(0.0, q.y, 0.0) + cam_fwd * q.z;
	vec3 v_flake = right * (wind_x + sway * cos(t * 0.9 + phase)) + vec3(0.0, -fall, 0.0);
	vec3 p_prev = p - (v_flake - cam_vel) * exposure;
	vec4 c0 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p, 1.0));
	vec4 c1 = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(p_prev, 1.0));
	if (c1.w < 0.5) {
		c1 = mix(c0, c1, clamp((c0.w - 0.5) / max(c0.w - c1.w, 1.0e-4), 0.0, 1.0));
	}
	float aspect = VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0);
	vec2 px_ndc = vec2(2.0 / (logical_h * aspect), 2.0 / logical_h);
	vec2 s0 = c0.xy / max(c0.w, 1.0e-3);
	vec2 s1 = c1.xy / max(c1.w, 1.0e-3);
	vec2 dir = (s0 - s1) / px_ndc;
	float len = length(dir);
	dir = len > 1.0e-4 ? dir / len : vec2(0.0, -1.0);
	vec2 perp = vec2(-dir.y, dir.x);
	// flake size in logical px at its depth (Arcade: 0.045 m, 1.2 … 5.5 px)
	float d_px = clamp(flake_m * (logical_h * 0.9875) / max(c0.w, 0.05), min_px, max_px);
	// a round flake of d_px plus the streak of its motion
	float along = VERTEX.y * 0.5 + 0.5;
	vec4 c = mix(c1, c0, along);
	c.xy += (dir * VERTEX.y * d_px * 0.5 + perp * VERTEX.x * d_px * 0.5) * px_ndc * c.w;
	POSITION = c;
	v_stretch = len / max(d_px, 0.5);
	v_q = vec2(VERTEX.x, VERTEX.y);
	float a = smoothstep(near_fade_m, near_fade_m + 1.2, q.z) * (1.0 - smoothstep(box_hi.z - 7.0, box_hi.z, q.z));
	a *= 1.0 - smoothstep(0.8, 1.0, abs(q.x - (box_lo.x + box_hi.x) * 0.5) / (size.x * 0.5));
	a *= smoothstep(box_hi.y, box_hi.y - 1.5, q.y);
	v_alpha = flake_color.a * a * fade * (c0.w > 0.2 ? 1.0 : 0.0);
	v_light = beam_at(p) * (1.0 - smoothstep(16.0, 42.0, q.z));
}

void fragment() {
	// round and soft across; along a streak the core runs its whole length and fades at both ends
	float across = abs(v_q.x);
	float ends = v_stretch > 1.0 ? smoothstep(1.0, 1.0 - 1.0 / (1.0 + v_stretch), abs(v_q.y)) : 1.0 - smoothstep(0.55, 1.0, length(v_q));
	float shape = (1.0 - smoothstep(0.45, 1.0, across)) * ends;
	vec3 amb = min(ce_ambient_display.rgb + vec3(0.35), vec3(1.0));
	vec3 col = flake_color.rgb * amb + vec3(1.0, 0.95, 0.85) * v_light * 0.8;
	ALBEDO = min(col, vec3(1.0));
	// a streak spreads the flake's light over its length (dimmer per pixel, as a moving flake on film)
	ALPHA = clamp(v_alpha * shape * (1.0 + v_light) / max(1.0, sqrt(v_stretch)), 0.0, 1.0);
}
