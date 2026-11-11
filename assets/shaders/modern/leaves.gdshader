// Modern, material class "leaves": foliage cards of trees and bushes (docs/modelle.md).
//   UV     leaf atlas (alpha = leaf shape, alpha scissor)
//   COLOR  r = sway amplitude by height (0..1), g = phase per card, b = stiffness, a = brightness
//   NORMAL points outwards from the crown (soft, round shading) - the same on both faces of a card
// Wind from the globals ce_wind (direction x, direction z, strength, gust) and ce_time; nothing uses TIME,
// so a paused game freezes the trees.
// Light: wrapped diffuse + translucency, and the sun's shadow only counts in part (shadow_part): the crown
// would otherwise be shadowed by its own low-poly caster, which sits right behind the outer cards.
// End of the sight (assembly of M1): beyond the end of the depth fog (ce_fog_range.y = the visibility) a prop is
// pure fog colour – a pale silhouette standing in front of the backdrop's own hazy silhouettes (the "bright
// diamonds" at the horizon of S1: impostors of far trees). It fades out with an ordered dither from 0.85 to 1.0 of
// the fog end instead, as Arcade's scenery sprites fade at the end of the sight.
// Fog: Arcade's law for things in the landscape (inc/fog_law.gdshaderinc, FIX1) instead of the engine's depth fog –
// the far crowns were grey-blue "ghost trees" on green fields (QA QB-07).
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor = 0.42;
uniform float sway_m = 0.35;                  // sway of the crown top at wind strength 1
uniform float flutter_m = 0.05;               // small fast motion of single cards
uniform float backlight = 0.35;                // light shining through the leaves from behind
uniform float wrap = 0.35;                     // diffuse wrap (0 = Lambert)
uniform float shadow_part = 0.25;              // how much of the directional shadow darkens the leaves

global uniform vec4 ce_wind;
global uniform float ce_time;
global uniform vec2 ce_fog_range;
global uniform vec4 ce_fog_color;

#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

varying float v_bright;

void vertex() {
	float amp = COLOR.r;
	float phase = COLOR.g * 6.2831853;
	float soft = 1.0 - COLOR.b;
	v_bright = COLOR.a;
	vec2 dir = ce_wind.xy;
	float strength = ce_wind.z;
	float gust = ce_wind.w;
	// one slow sway of the whole crown (per tree: phase from the world position) + flutter per card
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float tree = wp.x * 0.37 + wp.z * 0.23;
	float slow = sin(ce_time * 1.1 + tree) + 0.5 * sin(ce_time * 2.3 + tree * 1.7 + gust * 3.0);
	float fast = sin(ce_time * 5.3 + phase) * soft;
	vec3 push = vec3(dir.x, 0.0, dir.y) * (slow * sway_m * amp * amp * strength);
	push += vec3(sin(phase), 0.3, cos(phase)) * (fast * flutter_m * strength * amp);
	// the push is given in world axes; trees are only turned about the vertical axis and scaled
	VERTEX += (inverse(MODEL_MATRIX) * vec4(push, 0.0)).xyz;
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < scissor) {
		discard;
	}
	float far_keep = 1.0 - smoothstep(ce_fog_range.y * 0.85, ce_fog_range.y, length(VERTEX));
	if (far_keep < 0.999 && fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910))) >= far_keep) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;        // the engine flips the normal of back faces: keep the crown normal
	}
	ALBEDO = t.rgb * v_bright;        // sRGB-encoded, as the Compatibility renderer expects it
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	FOG = ce_arcade_fog(ALBEDO, length(VERTEX), ce_fog_color, ce_fog_range);
}

void light() {
	float att = LIGHT_IS_DIRECTIONAL ? mix(1.0, ATTENUATION, shadow_part) : ATTENUATION;
	float ndl = dot(NORMAL, LIGHT);
	float diff = max((ndl + wrap) / (1.0 + wrap), 0.0);
	float through = max(-ndl, 0.0) * backlight;
	DIFFUSE_LIGHT += LIGHT_COLOR * att * (diff + through) * (1.0 / PI);
}
