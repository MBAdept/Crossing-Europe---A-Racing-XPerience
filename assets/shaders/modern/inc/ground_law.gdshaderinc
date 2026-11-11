// Modern: the ground law (RINT-B, docs/renderer-modern.md §13.2) – shared by the road, the terrain ribbon and the far
// ground. Arcade shows ground as albedo × palette.ambient (display values). The engine turns the ambient pass and the
// sun pass into display values separately and adds them; that is not linear in the albedo at the dark end – at night
// a light albedo (snow) showed up to 66 % brighter than Arcade and a dark one 60 % darker, and no reference albedo of
// the environment's light split fits both (computed and measured, N1 snow +37 … +50 %, S1 at night road +47 … +59 %).
// A ground shader therefore switches the engine's ambient pass off (render_mode ambient_light_disabled) and writes
// the base pass itself as EMISSION: ce_ground_base_lin(albedo) is the linear value with which LEVEL ground in the
// light shows exactly albedo × ce_ambient_display – the part the engine's sun pass gives level ground is taken out of
// it. In shadow that part is missing, a slope towards the sun gets more: the light keeps its depth, the level ground
// keeps Arcade's colour at every albedo and hour.
// Use:   #include "res://assets/shaders/modern/inc/ground_law.gdshaderinc"
//        render_mode …, ambient_light_disabled;
//        ALBEDO = a; EMISSION = <encode>(ce_ground_base_lin(a) + <linear extra light × to_lin(a)>);
// Declares the globals ce_ambient_display, ce_sun_color, ce_sun_dir – a shader that includes this file must not
// declare them again. Names: everything here starts with ce_ground_.

global uniform vec4 ce_ambient_display;
global uniform vec4 ce_sun_color;
global uniform vec3 ce_sun_dir;

// The renderer's linear -> display value at the end of every pass (docs/modelle.md §4) …
vec3 ce_ground_show(vec3 x) {
	return max(1.055 * pow(max(x, vec3(0.0)), vec3(0.416666667)) - 0.055, vec3(0.0));
}

// … and the linear value that shows as display value d (0 for d <= 0).
vec3 ce_ground_unshow(vec3 d) {
	vec3 x = pow((max(d, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	return x * step(vec3(1.0e-6), d);
}

// Linear value of the base pass (EMISSION, ambient light of the engine switched off) under which level ground of
// display albedo `albedo` shows albedo × ce_ambient_display in the light of ce_sun_color / ce_sun_dir.
vec3 ce_ground_base_lin(vec3 albedo) {
	vec3 a = albedo * (albedo * (albedo * 0.305306011 + 0.682171111) + 0.012522878);
	vec3 sun_level = ce_ground_show(a * ce_sun_color.rgb * max(normalize(ce_sun_dir).y, 0.0));
	return ce_ground_unshow(albedo * ce_ambient_display.rgb - sun_level);
}
