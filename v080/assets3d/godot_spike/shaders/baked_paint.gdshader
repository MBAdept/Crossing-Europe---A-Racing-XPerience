// Baked vehicle atlas: albedo.rgb = baked colour, albedo.a = paint mask (1 = body paint -> paint_color),
// ORM atlas, emission atlases for tail / brake.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D tail_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D brake_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec3 paint_color : source_color = vec3(0.6, 0.02, 0.02);
uniform float paint_metallic = 0.3;
uniform float use_paint = 1.0;
uniform float tail_energy = 0.0;
uniform float brake_energy = 0.0;

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	float pm = a.a * use_paint;
	ALBEDO = mix(a.rgb, paint_color, pm);
	ROUGHNESS = orm.g;
	METALLIC = mix(orm.b, paint_metallic, pm);
	CLEARCOAT = pm;
	CLEARCOAT_ROUGHNESS = 0.03;
	EMISSION = texture(tail_tex, UV).rgb * tail_energy + texture(brake_tex, UV).rgb * brake_energy;
}
