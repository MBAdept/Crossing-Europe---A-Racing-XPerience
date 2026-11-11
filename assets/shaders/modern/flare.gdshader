// Modern: lamp flares (layer "flares", contract D14 F6) - the glow of tail, brake and indicator lights, beacons
// and static lamps, drawn like Arcade's lamp glows: an additive radial glow (Arcade's glow texture: full in the
// middle, 55 % at a quarter of the radius, nothing at the radius) whose radius is k x (pixels per metre at the
// lamp) but never below the minimum size of Arcade (RoadRenderer.INDICATOR_MIN_GLOW_PX for indicators, 2 px for
// rear lights), at most 70 px; an indicator also gets a lamp core of Arcade's minimum size (INDICATOR_MIN_PX,
// 2.4 x 2.0 px). Sizes are LOGICAL pixels (720 rows, the focal length of the game camera: 711 px per metre at
// 1 m, D12) - at any window size a lamp keeps the size it has in Arcade.
// Occlusion by the depth buffer: a flare shows only as much as its lamp is visible - five taps of the depth
// texture around the lamp's own screen position against the lamp's depth (the anchor sits a little in front of the
// lens). A lamp behind a crest, a truck or a wall gives 0 pixels; one half hidden gives half a glow. The quad itself
// is not depth tested (the glow may spread over the vehicle's own body, as in Arcade).
// The full strength of the middle covers at least half a pixel diagonal of the 3D picture (the glow keeps its radius
// and never gets weaker anywhere): a lamp of a few pixels keeps its full strength in the pixel that holds it,
// wherever it falls between pixels - also in a 3D picture drawn below the window's resolution (3D scale of the
// presets, 75 % on "Niedrig"), where a brake light at 150 m otherwise faded to +0.07 red once the picture was scaled
// up (assembly of M1: no preset dims a lamp).
// MultiMesh (layer "flares"): instance transform = position of the lamp (origin; basis z = the lamp's direction,
// unused here), COLOR = lamp colour (sRGB) and strength in alpha, INSTANCE_CUSTOM = (radius factor k in metres,
// smallest radius px, kind: 0 glow / 1 indicator with core, lamp radius in metres for the depth taps).
// Mesh: a quad with corners (-1..1, -1..1) in x / y. Unshaded, additive, no fog (lamps shine through the haze;
// their strength already carries the path-distance fade of their vehicle).
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float focal_px = 711.0;     // logical px per metre at 1 m (RoadProjection.focal)
uniform float logical_h = 720.0;    // logical rows of the picture (the focal length refers to them)
uniform float max_px = 70.0;        // Arcade's largest glow radius
uniform float depth_eps = 0.12;     // m: the lamp counts as hidden only behind something this much nearer
uniform float strength = 1.0;       // overall factor (tuning)

varying vec4 v_col;
varying vec2 v_quad;                // the quad's corner coordinates (-1..1) …
varying vec2 v_px;                  // … in px: (half size of the quad, unused)
varying vec2 v_core;                // half size of the lamp core in px (0 = none)
varying float v_r;                  // glow radius in px
varying vec2 v_src;                 // screen uv of the lamp
varying vec2 v_tap;                 // uv offset of the four outer depth taps
varying float v_depth;              // view depth of the lamp (m)

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float d = max(-vp.z, 0.05);
	float s = focal_px / d;                                    // logical px per metre at the lamp
	float r = clamp(INSTANCE_CUSTOM.x * s, INSTANCE_CUSTOM.y, max(INSTANCE_CUSTOM.y, max_px));
	vec2 core = vec2(0.0);
	if (INSTANCE_CUSTOM.z > 0.5) {
		core = vec2(clamp(0.2 * s, 2.4, 30.0), clamp(0.13 * s, 2.0, 20.0)) * 0.5;
	}
	float half_px = max(r, max(core.x, core.y) + 1.0);
	vec4 clip = PROJECTION_MATRIX * vp;
	float aspect = VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0);
	vec2 px_ndc = vec2(2.0 / (logical_h * aspect), 2.0 / logical_h);
	v_src = (clip.xy / clip.w) * 0.5 + 0.5;
	v_tap = max(INSTANCE_CUSTOM.w * s, 0.6) * px_ndc * 0.5;
	v_depth = d;
	clip.xy += VERTEX.xy * half_px * px_ndc * clip.w;
	POSITION = clip;
	v_quad = VERTEX.xy * half_px;
	v_px = vec2(half_px);
	v_core = core;
	v_r = r;
	v_col = COLOR;
}

// linear view depth of the depth texture at uv (GL Compatibility: reverse Z, window depth 0..1 -> NDC -1..1)
float scene_depth(vec2 uv, mat4 inv_proj) {
	float raw = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}

void fragment() {
	// how much of the lamp is visible: five taps around its own screen position
	float vis = 0.0;
	vec2 taps[5] = vec2[](vec2(0.0), vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	for (int i = 0; i < 5; i++) {
		vec2 uv = v_src + taps[i] * v_tap;
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			vis += 0.2;          // off screen: nothing there that could hide it
			continue;
		}
		vis += scene_depth(uv, INV_PROJECTION_MATRIX) >= v_depth - depth_eps ? 0.2 : 0.0;
	}
	if (vis <= 0.0) {
		discard;
	}
	// Arcade's glow: 1 -> 0.55 over the first quarter of the radius, then linearly to 0 at the radius - full strength
	// up to half a pixel diagonal of the 3D picture (px = logical px per pixel of the 3D picture)
	float px = logical_h / max(VIEWPORT_SIZE.y, 1.0);
	float o = min(0.7071 * px, 0.5 * v_r);
	float t = max(length(v_quad) - o, 0.0) / max(v_r - o, 0.001);
	float g = t < 0.25 ? 1.0 - 1.8 * t : 0.55 * max(0.0, 1.0 - (t - 0.25) / 0.75);
	vec3 c = v_col.rgb * (0.5 * v_col.a * g);
	if (v_core.x > 0.0 && abs(v_quad.x) <= v_core.x && abs(v_quad.y) <= v_core.y) {
		// the indicator lamp itself (RoadRenderer._indicator: lamp colour washed a little towards white)
		c += mix(v_col.rgb, vec3(1.0, 0.9, 0.6), 0.35) * min(v_col.a * 1.25, 1.0);
	}
	ALBEDO = c * vis * strength;
}
