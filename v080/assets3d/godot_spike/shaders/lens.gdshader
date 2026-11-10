// Lamp lens: tinted, glossy, alpha blended; COLOR = tint (sRGB bytes), alpha = opacity
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;

varying vec4 v_col;

void vertex() {
	v_col = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
}

void fragment() {
	ALBEDO = v_col.rgb;
	ROUGHNESS = 0.05;
	SPECULAR = 0.7;
	ALPHA = v_col.a;
}
