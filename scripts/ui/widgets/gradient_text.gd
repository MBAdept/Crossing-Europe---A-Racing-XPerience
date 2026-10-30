class_name GradientText
extends Control
## Big display text with a vertical colour gradient (80s chrome look), dark outline and offset shadow.
## The gradient is applied by a small canvas shader that recolours only the white text fill.

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 c_top : source_color = vec4(1.0, 0.96, 0.62, 1.0);
uniform vec4 c_mid : source_color = vec4(1.0, 0.56, 0.16, 1.0);
uniform vec4 c_bot : source_color = vec4(1.0, 0.18, 0.53, 1.0);
uniform float y_top = 0.0;
uniform float y_bot = 100.0;
varying vec2 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec4 c = COLOR;
	if (c.r > 0.97 && c.g > 0.97 && c.b > 0.97) {
		float t = clamp((lp.y - y_top) / max(y_bot - y_top, 1.0), 0.0, 1.0);
		vec3 g = t < 0.55 ? mix(c_top.rgb, c_mid.rgb, t / 0.55) : mix(c_mid.rgb, c_bot.rgb, (t - 0.55) / 0.45);
		float band = smoothstep(0.50, 0.53, t) * (1.0 - smoothstep(0.53, 0.58, t));
		c.rgb = mix(g, vec3(1.0), band * 0.55);
	}
	COLOR = c;
}
"""

static var _shader: Shader

var text := ""
var font: Font
var font_size := 72
var outline := 10
var outline_color := Color("1a0533")
var shadow_color := Color(UiTheme.ACCENT_2, 0.85)
var shadow_offset := Vector2(5, 5)
var align := HORIZONTAL_ALIGNMENT_LEFT
var colors: Array[Color] = [Color(1.0, 0.96, 0.62), Color(1.0, 0.56, 0.16), Color(1.0, 0.18, 0.53)]
var spacing := 0


func _init(p_text: String = "", p_font: Font = null, p_size: int = 72) -> void:
	text = p_text
	font = p_font
	font_size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if font == null:
		font = UiTheme.font(UiTheme.F.LOGO)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	material = mat
	_update_material()
	custom_minimum_size = Vector2(_width(), font.get_height(font_size) + shadow_offset.y)
	resized.connect(_update_material)


func _width() -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + shadow_offset.x + outline


func _baseline() -> float:
	return font.get_ascent(font_size)


func _update_material() -> void:
	var m := material as ShaderMaterial
	if m == null:
		return
	var asc := _baseline()
	m.set_shader_parameter("y_top", asc - font.get_ascent(font_size) * 0.78)
	m.set_shader_parameter("y_bot", asc + font.get_descent(font_size) * 0.1)
	m.set_shader_parameter("c_top", colors[0])
	m.set_shader_parameter("c_mid", colors[1])
	m.set_shader_parameter("c_bot", colors[2])


func _draw() -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := 0.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x = (size.x - tw) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = size.x - tw - shadow_offset.x
	var pos := Vector2(x, _baseline())
	draw_string_outline(font, pos + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(shadow_color, shadow_color.a * 0.5))
	draw_string(font, pos + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
