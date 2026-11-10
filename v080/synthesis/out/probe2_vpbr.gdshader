shader_type spatial;
render_mode cull_back;
// Synthesis probe: one vertex format for vehicles ("VPBR-L"):
// COLOR.rgb = albedo (sRGB bytes), COLOR.a = paint code (1 = fixed, 0 = paint, 0.25 = paint2, 0.5 = paint3)
// UV = (roughness, metallic), UV2 = (lamp channel + 0.5 or -1, lamp weight)
instance uniform vec4 paint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 paint2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 lamp_a = vec4(0.0);
instance uniform vec4 lamp_b = vec4(0.0);
instance uniform float fade = 1.0;
global uniform float ce_night;
varying flat float v_code;
varying flat vec2 v_lamp;

vec3 to_linear(vec3 c) { return pow(c, vec3(2.2)); }

void vertex() {
	v_code = COLOR.a;
	v_lamp = UV2;
}

void fragment() {
	vec3 alb = to_linear(COLOR.rgb);
	if (v_code < 0.125) { alb = paint.rgb; }
	else if (v_code < 0.375) { alb = paint2.rgb; }
	ALBEDO = alb;
	ROUGHNESS = UV.x;
	METALLIC = UV.y;
	int ch = int(floor(v_lamp.x));
	float on = 0.0;
	if (ch == 0) { on = lamp_a.x; }
	else if (ch == 1) { on = lamp_a.y; }
	else if (ch == 2) { on = lamp_a.z; }
	else if (ch == 3) { on = lamp_a.w; }
	else if (ch == 4) { on = lamp_b.x; }
	else if (ch == 12) { on = ce_night; }
	EMISSION = to_linear(COLOR.rgb) * on * v_lamp.y * 3.0;
	// path-distance fade as a dither discard (stays in the opaque pass)
	float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
	if (d > fade) { discard; }
}
