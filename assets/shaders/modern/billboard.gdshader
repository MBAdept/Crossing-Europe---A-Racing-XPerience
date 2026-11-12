// Modern: upright billboards - tree impostors (far LOD of a card tree) and the stand-ins of sprite sets
// that have no model yet ("fallback": "sprite": one cell of the Arcade sprite sheet).
// Mesh: a quad in the XY plane whose x = 0 is the anchor column and y = 0 the ground (ModelFactory.
// billboard_mesh), UV 0..1 with v = 0 at the top. The quad turns about its vertical axis so that it stays
// parallel to the screen, like the sprites of the Arcade mode. A mirrored node (negative determinant, the
// left roadside) shows the picture mirrored. Works on MeshInstance3D and MultiMeshInstance3D.
//   uv_rect / lights_rect   cell of the base layer / of the light layer in the texture (x, y, w, h in 0..1)
// Unlit, but it shows what a lit surface with the picture as albedo would show - by day and by moonlight.
// For that it repeats the arithmetic of the Compatibility renderer (measured, docs/modelle.md):
//   - albedo: sRGB -> linear with the renderer's polynomial (to_lin)
//   - the ambient pass and the pass of the one shadow-casting light (sun / moon) are each converted to
//     display values on their own and then added: show(albedo * ambient) + show(albedo * sun), with
//     show(x) = max(1.055 x^(1/2.4) - 0.055, 0) - below a linear 0.0008 a pass contributes nothing at all
//   - ALBEDO of this unshaded material goes through to_lin and show as well, so the wanted display value
//     is turned back first (albedo_for)
// ce_ambient and ce_sun_color are linear light values (ModernMaterials.light_value: linear colour x energy).
// The light layer of a sprite cell is added in linear light with ce_night.
// Stand-ins (scripts/race3d/prop_library.gd) additionally use:
//   COLOR        per-instance tint of a MultiMesh (the "tint" of a scenery rule); white elsewhere
//   shadow_cut   > 0: dark, half-transparent pixels below this alpha are dropped - the ground shadow that is baked
//                into the Arcade sprites (the props builder lays a contact shadow on the real ground instead)
//   baked_light  1: the picture carries light and shade of its own (Cycles): it is shown as picture x the light a
//                mid-grey surface gets - Arcade's law (sprite x ambient colour), which keeps its hues
//   sun_min / sun_max  ... and are then factors on the sun that level ground gets (PropLibrary.STANDIN_SUN), not
//                parts of the full sun as for an impostor
// and every billboard takes the player's headlights from the globals ce_headlight_pos / _dir / ce_headlight
// (range, intensity; intensity 0 = off): an unshaded material gets nothing from the real spot lights.
// End of the sight (assembly of M1): beyond the end of the depth fog (ce_fog_range.y = the visibility) a prop is
// pure fog colour – a pale silhouette standing in front of the backdrop's own hazy silhouettes (the "bright
// diamonds" at the horizon of S1: impostors of far trees). It fades out with an ordered dither from 0.85 to 1.0 of
// the fog end instead, as Arcade's scenery sprites fade at the end of the sight.
// Fog: Arcade's law for things in the landscape (inc/fog_law.gdshaderinc, FIX1) instead of the engine's depth fog:
// the picture's own colour times the brightened fog colour, by 0.7 of the fog amount.
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 lights_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float scissor = 0.5;
uniform float sun_min = 0.166;                // part of the sun on the picture when the sun is behind it ...
uniform float sun_max = 0.662;                // ... and when it shines from behind the camera (linear)
uniform float night_energy = 1.5;
uniform float shadow_cut = 0.0;
uniform float baked_light = 0.0;              // 1: the picture carries its own light and shade (Arcade sprites)
uniform vec3 headlight_color = vec3(1.0, 0.95, 0.84);   // linear, at intensity 1 right in front of the lamps
// FIX1 (QA QB-03): a landmark keeps Arcade's landmark law (RoadRenderer.landmark_fade, frozen) instead of the prop
// fade at the end of the sight: visible up to L = clamp(visibility × x, min(visibility, 600), max(y, visibility)),
// fading out over the last 28 % of L, its colour going towards the fog colour × 1.15 by 0.85 × the haze from the fog
// begin to L. x = render.landmark_range_factor (2), y = render.landmark_far_m (1900); x <= 0: an ordinary prop.
uniform vec2 landmark_law = vec2(0.0, 1900.0);

global uniform float ce_night;
global uniform float ce_snow;                  // R4: Arcade tints its scenery sprites in snow (RoadRenderer: 15 % towards #bfccd6)
global uniform vec4 ce_sun_color;
global uniform vec4 ce_ambient;
global uniform vec3 ce_sun_dir;
global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;
global uniform vec2 ce_fog_range;
global uniform vec4 ce_fog_color;

#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

varying float v_sun;
varying float v_head;

const float REF_GREY = 0.38;                  // the albedo the environment's light split is exact for

void vertex() {
	// right vector of the camera, flattened: the billboard only turns about the vertical axis
	vec3 cr = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz) * sign(determinant(mat3(MODEL_MATRIX)));
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wp = origin + cr * (VERTEX.x * sx) + vec3(0.0, VERTEX.y * sy, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	// how much of the sun falls on the side the camera sees (a lit model would show the same)
	float facing = dot(normalize(CAMERA_POSITION_WORLD - origin), normalize(ce_sun_dir)) * 0.5 + 0.5;
	v_sun = mix(sun_min, sun_max, facing * facing);
	if (baked_light > 0.5) {
		// a picture with baked light gets the sun as level ground does (Arcade lights sprite and ground alike),
		// a little less against the sun and a little more with it
		v_sun *= max(normalize(ce_sun_dir).y, 0.0);
	}
	// the player's headlights: a cone along ce_headlight_dir that falls off to nothing at its range
	vec3 to = origin + vec3(0.0, 1.5, 0.0) - ce_headlight_pos;
	float d = max(length(to), 0.001);
	float reach = max(1.0 - d / max(ce_headlight.x, 1.0), 0.0);
	v_head = smoothstep(0.80, 0.97, dot(to / d, normalize(ce_headlight_dir))) * reach * reach * ce_headlight.y;
}

// the renderer's sRGB -> linear for albedo values
vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// the renderer's linear -> display value at the end of every pass
vec3 show(vec3 x) {
	return max(1.055 * pow(max(x, vec3(0.0)), vec3(0.416666667)) - 0.055, vec3(0.0));
}

// ALBEDO value the renderer turns into the linear value x: inverse of to_lin (two Newton steps)
vec3 albedo_for(vec3 x) {
	vec3 c = pow(max(x, vec3(0.0)), vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

void fragment() {
	vec4 t = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (t.a < scissor || (t.a < shadow_cut && max(t.r, max(t.g, t.b)) < 0.1)) {
		discard;
	}
	float dist = length(VERTEX);
	float far_keep = 1.0 - smoothstep(ce_fog_range.y * 0.85, ce_fog_range.y, dist);
	float lm_l = 0.0;
	if (landmark_law.x > 0.0) {
		float vis = ce_fog_range.y;
		lm_l = clamp(vis * landmark_law.x, min(vis, 600.0), max(landmark_law.y, vis));
		far_keep = 1.0 - smoothstep(lm_l * 0.72, lm_l, dist);
	}
	float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
	if (far_keep < 0.999 && dither >= far_keep) {
		// M2INT (Arcade's RoadRenderer._draw_landmark): at night the illumination of a landmark (the light layer of its
		// sprite) stays visible up to landmark_law.y (render.landmark_far_m) when the picture itself has faded with the
		// night's short sight – the lit Elbphilharmonie over the Köhlbrandbrücke was missing at 22:00. Only the lit
		// pixels, unfogged, as a dithered cover of light alpha x night x the fade over the last 20 % of that range.
		float lights_keep = 0.0;
		if (landmark_law.x > 0.0 && lights_rect.z > 0.0) {
			lights_keep = clamp(ce_night, 0.0, 1.0) * (1.0 - smoothstep(landmark_law.y * 0.8, landmark_law.y, dist));
		}
		vec4 ll = lights_keep > 0.01 ? texture(tex, lights_rect.xy + UV * lights_rect.zw) : vec4(0.0);
		if (dither >= ll.a * lights_keep) {
			discard;
		}
		ALBEDO = albedo_for(pow((min(ll.rgb, vec3(1.0)) + 0.055) / 1.055, vec3(2.4)));
		FOG = vec4(0.0);
	} else {
		vec3 base = mix(t.rgb * COLOR.rgb, vec3(0.75, 0.8, 0.84), 0.15 * clamp(ce_snow, 0.0, 1.0));
		vec3 a = to_lin(base);
		// what a lit surface shows: two passes, each turned into display values, then added
		vec3 d = show(a * ce_ambient.rgb) + show(a * ce_sun_color.rgb * v_sun);
		if (baked_light > 0.5) {
			// a picture with baked light: its colours times the light a mid-grey surface shows (Arcade's law:
			// sprite x ambient colour) - the hues of the sprite stay as they were painted
			vec3 g = vec3(to_lin(vec3(REF_GREY)).r);
			d = base * (show(g * ce_ambient.rgb) + show(g * ce_sun_color.rgb * v_sun)) / REF_GREY;
		}
		// back to the linear value with that display value (0.00083 is the linear value that still shows as 0)
		vec3 x = pow((min(d, vec3(1.0)) + 0.055) / 1.055, vec3(2.4));
		x += a * headlight_color * v_head;
		float light_cover = 0.0;
		if (lights_rect.z > 0.0) {
			vec4 l = texture(tex, lights_rect.xy + UV * lights_rect.zw);
			light_cover = clamp(l.a * ce_night, 0.0, 1.0);
			if (baked_light > 0.5) {
				// Arcade lays the light layer over the sprite: picture -> light layer by its alpha x the night amount
				vec3 lit = mix(min(d, vec3(1.0)), l.rgb, light_cover);
				x = pow((lit + 0.055) / 1.055, vec3(2.4));
			} else {
				x += to_lin(l.rgb * l.a) * (ce_night * night_energy);
			}
		}
		ALBEDO = albedo_for(x);
		if (lm_l > 0.0) {
			// Arcade hazes the picture of a landmark, but lays its light layer over it unhazed: the lit pixels keep
			// their light (and match the lights that stay beyond L above)
			float haze = clamp((dist - ce_fog_range.x) / max(lm_l - ce_fog_range.x, 1.0), 0.0, 1.0) * 0.85;
			haze *= 1.0 - light_cover;
			FOG = vec4(ce_fog_unshow(min(t.rgb * COLOR.rgb * ce_fog_color.rgb * 1.15, vec3(1.0))), haze);
		} else {
			FOG = ce_arcade_fog(t.rgb * COLOR.rgb, dist, ce_fog_color, ce_fog_range);
		}
	}
}
