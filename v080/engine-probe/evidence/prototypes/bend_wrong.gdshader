shader_type spatial;
render_mode world_vertex_coords;
// Same bending, but relative to the camera of the CURRENT pass (wrong in shadow passes).
global uniform vec4 bend_params;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);

void vertex() {
	float d = max(0.0, CAMERA_POSITION_WORLD.z - VERTEX.z - bend_params.z);
	VERTEX.x += 0.5 * bend_params.x * d * d;
	VERTEX.y += 0.5 * bend_params.y * d * d;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission_color;
}
