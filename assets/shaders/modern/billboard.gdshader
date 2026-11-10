// Modern: upright billboards - tree impostors (far LOD of a card tree) and the stand-ins of sprite sets
// that have no model yet ("fallback": "sprite": one cell of the Arcade sprite sheet).
// Mesh: a quad in the XY plane whose x = 0 is the anchor column and y = 0 the ground (ModelFactory.
// billboard_mesh), UV 0..1 with v = 0 at the top. The quad turns about its vertical axis so that it stays
// parallel to the screen, like the sprites of the Arcade mode. A mirrored node (negative determinant, the
// left roadside) shows the picture mirrored. Works on MeshInstance3D and MultiMeshInstance3D.
//   uv_rect / lights_rect   cell of the base layer / of the light layer in the texture (x, y, w, h in 0..1)
// Unlit: tinted with ambient + sun from the ce_* globals; the light layer is added with ce_night.
// Colours are sRGB-encoded in the shader stage of the Compatibility renderer (the engine linearises ALBEDO
// afterwards): ce_ambient and ce_sun_color are expected that way, with energies folded in as e^(1/2.2).
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 lights_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float scissor = 0.5;
uniform float sun_min = 0.23;                 // part of the sun on the picture when the sun is behind it ...
uniform float sun_max = 1.03;                 // ... and when it shines from behind the camera
uniform float night_energy = 1.5;

global uniform float ce_night;
global uniform vec4 ce_sun_color : source_color;
global uniform vec4 ce_ambient : source_color;
global uniform vec3 ce_sun_dir;

varying float v_sun;

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
	v_sun = mix(sun_min, sun_max, facing);
}

void fragment() {
	vec4 t = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (t.a < scissor) {
		discard;
	}
	// light = ambient + part of the sun, added in linear space; a product of two sRGB-encoded values is
	// the encoded product of their linear values
	vec3 light = pow(pow(ce_ambient.rgb, vec3(2.2)) + pow(ce_sun_color.rgb, vec3(2.2)) * v_sun, vec3(0.4545));
	vec3 lit = t.rgb * min(light, vec3(1.4));
	if (lights_rect.z > 0.0) {
		vec4 l = texture(tex, lights_rect.xy + UV * lights_rect.zw);
		lit = pow(pow(lit, vec3(2.2)) + pow(l.rgb * l.a, vec3(2.2)) * (ce_night * night_energy), vec3(0.4545));
	}
	ALBEDO = lit;
}
