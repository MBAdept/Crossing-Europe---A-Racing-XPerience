shader_type spatial;
// Per-instance uniform: one material, different paint colour per MeshInstance3D.
instance uniform vec4 paint : source_color = vec4(1.0);
instance uniform float lights_on = 0.0;
uniform float roughness = 0.3;
void fragment() {
	ALBEDO = paint.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.4;
	EMISSION = vec3(1.0, 0.1, 0.05) * lights_on * step(0.8, UV.y);
}
