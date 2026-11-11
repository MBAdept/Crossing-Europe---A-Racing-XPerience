// Modern: contact shadows of props (scripts/race3d/builders/props.gd; docs/renderer-modern-gelaende.md) – a soft
// dark patch on the ground under every tree, bush, rock, bale and house, one MultiMesh per chunk. It stands in for
// the ground shadow that is baked into the Arcade sprites, and it carries the shadows of the models beyond the
// reach of the real shadow map.
// Mesh: a unit quad in the XZ plane (-1 .. 1). Instance transform: origin = the foot of the prop, lifted a little;
// X and Z = the ground plane there (tilted with the slope), their length = the radius of the patch.
// INSTANCE_CUSTOM: x = height of the prop / its width (how far its shadow can reach), y = density (0..1),
//                  z = 1 when the prop also casts a real shadow (the patch then fades out towards the camera,
//                  where the shadow map takes over), w unused.
// The patch is stretched away from the sun: length = height x cot(elevation), at most max_reach widths. Its
// darkness is the part of the light on level ground that comes from the sun (from ce_sun_color and ce_ambient,
// with the renderer's own arithmetic for one pass each, docs/modelle.md §4) plus a small contact term that stays
// under an overcast sky and at night. The engine's depth fog applies on top, so a shadow far away fades with the
// ground it lies on.
// Load only after ModernMaterials.ensure_globals() – never with preload().
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.78;                // part of the sun's light the patch takes away at its core
uniform float contact = 0.14;                 // darkness that stays without any sun
uniform float max_reach = 1.6;                // longest shadow, in widths of the prop
uniform float real_from_m = 0.0;              // props with a real shadow: the patch fades in between these distances
uniform float real_to_m = 0.0;                //   from the camera (0 / 0 = no real shadows: the patch is always there)
uniform float ref_albedo = 0.38;

global uniform vec3 ce_sun_dir;
global uniform vec4 ce_sun_color;
global uniform vec4 ce_ambient;

varying vec2 v_local;
varying float v_dark;

// the renderer's sRGB -> linear for albedo values and its linear -> display value at the end of a pass
float to_lin(float c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

float show(float x) {
	return max(1.055 * pow(max(x, 0.0), 0.416666667) - 0.055, 0.0);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 ax = MODEL_MATRIX[0].xyz;
	vec3 az = MODEL_MATRIX[2].xyz;
	float r = length(ax);
	vec3 ux = ax / max(r, 0.0001);
	vec3 uz = az / max(length(az), 0.0001);
	vec3 sun = normalize(ce_sun_dir);
	// direction of the shadow in the patch's plane
	vec2 dir = vec2(dot(-sun, ux), dot(-sun, uz));
	float flat_len = length(dir);
	vec2 d = flat_len > 0.0001 ? dir / flat_len : vec2(0.0, 1.0);
	float elev = max(sun.y, 0.05);
	float reach = min(INSTANCE_CUSTOM.x * 2.0 * r * flat_len / elev, max_reach * 2.0 * r);
	float along = dot(VERTEX.xz, d);
	float across = dot(VERTEX.xz, vec2(-d.y, d.x));
	vec2 q = d * (along * (r + reach * 0.5) + reach * 0.5) + vec2(-d.y, d.x) * (across * r);
	vec3 wp = origin + ux * q.x + uz * q.y;
	// a depth bias along the line of sight: the patch lies on the ground without fighting it
	vec3 to_cam = CAMERA_POSITION_WORLD - wp;
	float dist = length(to_cam);
	wp += to_cam / max(dist, 0.001) * min(max(0.05, dist * 0.004), dist * 0.5);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	v_local = vec2(along, across);
	// how much of the light on level ground is the sun's
	float a = to_lin(ref_albedo);
	float lum_sun = dot(ce_sun_color.rgb, vec3(0.2126, 0.7152, 0.0722)) * elev;
	float lum_amb = dot(ce_ambient.rgb, vec3(0.2126, 0.7152, 0.0722));
	float s = show(a * lum_sun);
	float share = s / max(s + show(a * lum_amb), 0.0001);
	float real_k = 1.0;
	if (real_to_m > 0.0) {
		real_k = mix(1.0, smoothstep(real_from_m, real_to_m, dist), INSTANCE_CUSTOM.z);
	}
	v_dark = (share * strength * real_k + contact * mix(1.0, 0.5, INSTANCE_CUSTOM.z * (1.0 - real_k))) * INSTANCE_CUSTOM.y;
}

void fragment() {
	float q = length(v_local);
	float soft = 1.0 - smoothstep(0.25, 1.0, q);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(v_dark * soft, 0.0, 1.0);
}
