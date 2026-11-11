// Modern: road signs (builder "signs", contract §6 R3): boards textured from the stage's sign atlas (Arcade's
// SignPainter, drawn once before the stage – SignAtlas) and their posts, all signs of a chunk in one mesh.
//   COLOR.a = 1  board: UV = atlas coordinates; the atlas is premultiplied (a transparent SubViewport), so the
//                colour is t.rgb / t.a, and the board's outline comes from its alpha (scissor at 0.5); the back of a
//                board is bare metal (back_colour)
//   COLOR.a = 0  post: COLOR.rgb = its colour (sRGB)
//   UV2 = (road position z of the sign, 1 inside a tunnel): the path-distance fade of Arcade (RoadRenderer.
//         _item_alpha, F5) is computed here from the camera's road position (uniform cam_z, set every frame by
//         the builder) and drawn as a dither, like the vehicles
// Retro-reflection: a board in the cone of the player's headlights sends their light back towards them (the eye
// is next to them): emission = albedo x gain x cone x reach x facing. Light source from the ce_headlight_* globals
// (layer "lights"); while nobody sets them (ce_headlight.y = 0) the camera stands in for the headlights at night,
// with Arcade's headlight reach (render.headlight_range_m) – Arcade brightens signs in its headlights the same way.
// Colour space as in vpbr.gdshader: ALBEDO / EMISSION are sRGB-encoded in fragment(); light is summed linear.
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float cam_z = 0.0;               // road position of the camera (view.camera_z)
uniform float visibility = 900.0;        // view.visibility_m
uniform float fog_frac = 0.45;           // render.fog_start_frac
uniform float tunnel_fog_m = 260.0;      // render.tunnel.darkness_m
uniform float retro = 0.9;               // retro-reflection gain at the centre of the cone
uniform float hl_range = 80.0;           // headlight reach when the camera stands in (render.headlight_range_m)
uniform vec4 back_colour : source_color = vec4(0.55, 0.57, 0.60, 1.0);
// Fill light of the boards and posts: the reflective sheeting of a sign stays bright in its own shade (Arcade shows a
// board as colour x the whole ambient of the palette, the built-in light law gives a face turned away from the sun
// only half of it). Extra light = fill x ce_ambient, less where the sun falls on the face.
uniform float fill = 1.0;

global uniform float ce_night;
global uniform vec4 ce_ambient;
global uniform vec3 ce_sun_dir;
global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;

varying float v_fade;
varying vec3 v_world;

vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 encode(vec3 x) {
	x = max(x, vec3(0.0));
	vec3 c = pow(x, vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

void vertex() {
	float dz = UV2.x - cam_z;
	if (UV2.y > 0.5) {
		v_fade = 1.0 - pow(clamp((dz - 12.0) / tunnel_fog_m, 0.0, 1.0), 1.6);
	} else {
		float fs = visibility * fog_frac;
		v_fade = 1.0 - pow(clamp((dz - fs) / max(1.0, visibility - fs), 0.0, 1.0), 2.0);
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (v_fade < 0.999) {
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (d >= v_fade) {
			discard;
		}
	}
	vec3 alb = COLOR.rgb;
	bool board = COLOR.a > 0.5;
	if (board) {
		vec4 t = texture(atlas, UV);
		if (t.a < 0.5) {
			discard;
		}
		alb = FRONT_FACING ? clamp(t.rgb / t.a, vec3(0.0), vec3(1.0)) : back_colour.rgb;
	}
	ALBEDO = alb;
	ROUGHNESS = board ? 0.55 : 0.6;
	METALLIC = board ? 0.0 : 0.2;
	SPECULAR = 0.4;
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float in_sun = clamp(dot(n_w, normalize(ce_sun_dir)) * 2.0, 0.0, 1.0);
	vec3 extra = to_lin(alb) * ce_ambient.rgb * (fill * (1.0 - in_sun));
	EMISSION = encode(extra);
	if (board && FRONT_FACING) {
		bool own = ce_headlight.y > 0.0;
		float inten = own ? ce_headlight.y : clamp(ce_night, 0.0, 1.0) * 0.95;
		if (inten > 0.0) {
			vec3 src = own ? ce_headlight_pos : CAMERA_POSITION_WORLD;
			vec3 dir = own ? normalize(ce_headlight_dir) : normalize(-INV_VIEW_MATRIX[2].xyz);
			float range = own ? max(ce_headlight.x, 10.0) : hl_range;
			vec3 to_sign = v_world - src;
			float dist = max(length(to_sign), 0.001);
			vec3 l = to_sign / dist;
			float cone = smoothstep(0.82, 0.985, dot(l, dir));
			float reach = 1.0 - smoothstep(range * 0.3, range * 1.5, dist);
			float facing = clamp(dot(n_w, -l), 0.0, 1.0);
			EMISSION = encode(extra + to_lin(alb) * (inten * cone * reach * facing * retro));
		}
	}
}
