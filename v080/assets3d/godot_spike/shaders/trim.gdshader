// Vertex PBR "trim": COLOR.rgb = albedo (sRGB bytes), UV = (roughness, metallic)
shader_type spatial;
render_mode cull_back;

varying vec3 v_albedo;
varying vec2 v_rm;

void vertex() {
	v_albedo = pow(COLOR.rgb, vec3(2.2));
	v_rm = UV;
}

void fragment() {
	ALBEDO = v_albedo;
	ROUGHNESS = v_rm.x;
	METALLIC = v_rm.y;
	SPECULAR = 0.5;
}
