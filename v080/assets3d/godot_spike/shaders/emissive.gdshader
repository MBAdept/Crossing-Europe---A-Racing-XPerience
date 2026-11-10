// Emissive lamp part: COLOR.rgb = unlit albedo (sRGB bytes); emission colour and energy per material
shader_type spatial;
render_mode cull_back;

uniform vec3 emit_color : source_color = vec3(1.0, 0.1, 0.05);
uniform float energy = 0.0;
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
	EMISSION = emit_color * energy;
}
