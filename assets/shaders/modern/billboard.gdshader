// Modern: upright billboards - tree impostors (far LOD of a card tree) and the stand-ins of sprite sets
// that have no model yet ("fallback": "sprite": one cell of the Arcade sprite sheet).
// Mesh: a quad in the XY plane whose x = 0 is the anchor column and y = 0 the ground (ModelFactory.
// billboard_mesh), UV 0..1 with v = 0 at the top. The quad turns about its vertical axis so that it stays
// parallel to the screen, like the sprites of the Arcade mode. A mirrored node (negative determinant, the
// left roadside) shows the picture mirrored. Works on MeshInstance3D and MultiMeshInstance3D.
//   uv_rect / lights_rect   cell of the base layer / of the light layer in the texture (x, y, w, h in 0..1)
// Unlit, but it shows what a lit surface with the picture as albedo would show - by day and by moonlight.
// For that it repeats the arithmetic of the Compatibility renderer (measured, docs/modelle.md):
//   - albedo: sRGB -> linear with the renderer's polynomial (to_lin)
//   - the ambient pass and the pass of the one shadow-casting light (sun / moon) are each converted to
//     display values on their own and then added: show(albedo * ambient) + show(albedo * sun), with
//     show(x) = max(1.055 x^(1/2.4) - 0.055, 0) - below a linear 0.0008 a pass contributes nothing at all
//   - ALBEDO of this unshaded material goes through to_lin and show as well, so the wanted display value
//     is turned back first (albedo_for)
// ce_ambient and ce_sun_color are linear light values (ModernMaterials.light_value: linear colour x energy).
// The light layer of a sprite cell is added in linear light with ce_night.
// Load only through ModernMaterials - never with preload().
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 lights_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float scissor = 0.5;
uniform float sun_min = 0.166;                // part of the sun on the picture when the sun is behind it ...
uniform float sun_max = 0.662;                // ... and when it shines from behind the camera (linear)
uniform float night_energy = 1.5;

global uniform float ce_night;
global uniform vec4 ce_sun_color;
global uniform vec4 ce_ambient;
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
	v_sun = mix(sun_min, sun_max, facing * facing);
}

// the renderer's sRGB -> linear for albedo values
vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// the renderer's linear -> display value at the end of every pass
vec3 show(vec3 x) {
	return max(1.055 * pow(max(x, vec3(0.0)), vec3(0.416666667)) - 0.055, vec3(0.0));
}

// ALBEDO value the renderer turns into the linear value x: inverse of to_lin (two Newton steps)
vec3 albedo_for(vec3 x) {
	vec3 c = pow(max(x, vec3(0.0)), vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

void fragment() {
	vec4 t = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	if (t.a < scissor) {
		discard;
	}
	vec3 a = to_lin(t.rgb);
	// what a lit surface shows: two passes, each turned into display values, then added
	vec3 d = show(a * ce_ambient.rgb) + show(a * ce_sun_color.rgb * v_sun);
	// back to the linear value with that display value (0.00083 is the linear value that still shows as 0)
	vec3 x = pow((min(d, vec3(1.0)) + 0.055) / 1.055, vec3(2.4));
	if (lights_rect.z > 0.0) {
		vec4 l = texture(tex, lights_rect.xy + UV * lights_rect.zw);
		x += to_lin(l.rgb * l.a) * (ce_night * night_energy);
	}
	ALBEDO = albedo_for(x);
}
