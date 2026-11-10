shader_type spatial;
render_mode world_vertex_coords;
// World bending: geometry is laid out straight (road coordinates: -z ahead, x lateral) and is displaced
// in the vertex stage as a function of the distance ahead of the MAIN camera. The origin comes from a
// global uniform so that the shadow passes (which have their own "camera") use the same displacement.
global uniform vec3 bend_origin;
global uniform vec4 bend_params; // x: lateral curvature (1/m), y: vertical curvature (1/m), z: start distance
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);

void vertex() {
	float d = max(0.0, bend_origin.z - VERTEX.z - bend_params.z);
	VERTEX.x += 0.5 * bend_params.x * d * d;
	VERTEX.y += 0.5 * bend_params.y * d * d;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission_color;
}
