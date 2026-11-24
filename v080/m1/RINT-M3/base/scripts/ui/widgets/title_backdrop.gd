class_name TitleBackdrop
extends Control
## Photo backdrop of the title screen: assets/ui/title_background.webp (artwork by the player: a red sports car
## from behind on a German autobahn at sunset, heading for the Frankfurt skyline). Cover-fit to the whole window
## (16:9, the 16:10 Steam Deck screen with the menus' "expand" aspect, wider screens), with subtle life:
##   * Ken Burns: a slow zoom (KB_ZOOM) around the car with a slow drift of the focus (KB_PERIOD, KB_PAN_PERIOD),
##   * the low sun breathes (soft glow and a faint horizontal flare),
##   * faint speed streaks run over the asphalt towards the viewer – only on the road surface, never over the
##     vehicles (STREAK_*, ROAD_* and the vehicle boxes below are measured in the picture),
##   * readability: darker towards the right (logo and menu card) and at the bottom (key hints).
## Everything is one canvas shader on the GPU, animated by the shader TIME; every period divides the 3600 s TIME
## rollover, so nothing jumps. GlassPanel samples the same photo with the same transform at a blurred mip level –
## a frosted-glass card that matches the picture behind it (glass_material()).
## A different picture needs new SUN_UV, ROAD_VP, ROAD_SLOPES, VEHICLES and KB_FOCUS_* values (image UV 0..1).

const IMAGE_PATH := "res://assets/ui/title_background.webp"
## Design frame of the menus (MenuShell.DESIGN_SIZE); the readability gradients are laid out in it.
const FRAME := Vector2(1280, 720)

## Ken Burns: zoom 1 → 1 + KB_ZOOM and back in KB_PERIOD s around a focus that drifts between A and B.
const KB_ZOOM := 0.065
const KB_PERIOD := 45.0
const KB_PAN_PERIOD := 72.0
const KB_FOCUS_A := Vector2(0.34, 0.66)      ## the red car
const KB_FOCUS_B := Vector2(0.40, 0.50)      ## between car and skyline
const SUN_UV := Vector2(0.0885, 0.172)
## Road: vanishing point and the lateral slopes (dx/dy from the vanishing point, in picture pixels) of the
## left and right edge lines; speed streaks only run between them, below the horizon.
const ROAD_VP := Vector2(0.4258, 0.285)
const ROAD_SLOPES := Vector2(-1.08, 2.55)
## Vehicles in the picture (image UV rectangles x0, y0, x1, y1): the streaks pass behind them.
const VEHICLES: Array[Vector4] = [
	Vector4(0.186, 0.455, 0.488, 0.885),     # red car (with its shadow)
	Vector4(0.374, 0.302, 0.456, 0.438),     # white van
	Vector4(0.470, 0.245, 0.545, 0.372),     # green truck
	Vector4(0.527, 0.172, 0.712, 0.468),     # blue truck
	Vector4(0.0, 0.30, 0.37, 0.36),          # cars and guardrail on the left (horizon band)
]

## Shared by the backdrop and the glass: uniforms and the photo mapping (window pixel -> image UV).
const MAP_CODE := """
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 img_size = vec2(1672.0, 941.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float kb_zoom = 0.065;
uniform float kb_period = 45.0;
uniform float kb_pan_period = 72.0;
uniform vec2 kb_focus_a = vec2(0.34, 0.66);
uniform vec2 kb_focus_b = vec2(0.40, 0.50);
uniform float time_offset = 0.0;

// window pixel p -> image UV: cover fit (centred), then the Ken Burns zoom towards a drifting focus.
// The zoom is a convex combination of the focus and the unzoomed point, so it never leaves the picture.
vec2 photo_uv(vec2 p, float t) {
	float s0 = max(view_size.x / img_size.x, view_size.y / img_size.y);
	vec2 ip = (p - view_size * 0.5) / s0 + img_size * 0.5;
	float z = 1.0 + kb_zoom * (0.5 - 0.5 * cos(6.2831853 * t / kb_period));
	vec2 f = mix(kb_focus_a, kb_focus_b, 0.5 - 0.5 * cos(6.2831853 * t / kb_pan_period)) * img_size;
	return clamp((f + (ip - f) / z) / img_size, vec2(0.0), vec2(1.0));
}
"""

const BACKDROP_CODE := """
shader_type canvas_item;
render_mode blend_mix;
%s
uniform vec2 frame_origin = vec2(0.0);   // top-left of the 1280x720 design frame in the window
uniform vec2 frame_size = vec2(1280.0, 720.0);
uniform vec2 sun_uv = vec2(0.0885, 0.172);
uniform float sun_glow = 0.16;
uniform float sun_flare = 0.06;
uniform vec2 road_vp = vec2(0.4258, 0.285);
uniform vec2 road_slopes = vec2(-1.08, 2.55);
uniform float streaks = 0.14;
uniform vec4 boxes[5];
uniform float right_dark = 0.5;
uniform float bottom_dark = 0.55;
uniform float top_right_dark = 0.32;
varying vec2 lp;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float box_mask(vec2 uv, vec4 b) {
	float e = 0.012;
	float mx = smoothstep(b.x - e, b.x + e, uv.x) * (1.0 - smoothstep(b.z - e, b.z + e, uv.x));
	float my = smoothstep(b.y - e, b.y + e, uv.y) * (1.0 - smoothstep(b.w - e, b.w + e, uv.y));
	return mx * my;
}

// Thin streaks along lines through the vanishing point (lateral slope s = dx/dy is constant along a line on the
// road), moving towards the viewer with perspective: depth ~ 1/dy, so they speed up and lengthen as they near.
float speed_streaks(vec2 uv, float t) {
	vec2 d = (uv - road_vp) * img_size;
	if (d.y < 12.0) {
		return 0.0;
	}
	float s = d.x / d.y;
	if (s < road_slopes.x || s > road_slopes.y) {
		return 0.0;
	}
	float bins = 26.0;
	float u = (s - road_slopes.x) / (road_slopes.y - road_slopes.x) * bins;
	float bin = floor(u);
	float h = hash(bin);
	if (h < 0.45) {
		return 0.0;
	}
	float lateral = abs(fract(u) - 0.5 - (h - 0.72) * 0.6);
	float core = 1.0 - smoothstep(0.015, 0.06, lateral);
	float depth = 1.0 / d.y;
	float speed = 0.5 + 0.25 * floor(hash(bin + 7.0) * 3.0);   // 0.5, 0.75 or 1.0 cycles per second: x 3600 integral
	float phase = fract(depth * 34.0 + t * speed + hash(bin + 3.0));
	float seg = smoothstep(0.0, 0.03, phase) * (1.0 - smoothstep(0.06, 0.14, phase));
	float near = smoothstep(30.0, 260.0, d.y);
	float edge = smoothstep(road_slopes.x, road_slopes.x + 0.25, s) * (1.0 - smoothstep(road_slopes.y - 0.4, road_slopes.y, s));
	float m = 1.0;
	for (int i = 0; i < 5; i++) {
		m *= 1.0 - box_mask(uv, boxes[i]);
	}
	return core * seg * near * edge * m;
}

void fragment() {
	float alpha = COLOR.a;
	float t = TIME + time_offset;
	vec2 uv = photo_uv(lp, t);
	vec3 c = texture(photo, uv).rgb;
	// the low sun breathes: soft glow and a faint horizontal flare (in picture space, it follows the zoom)
	float aspect = img_size.x / img_size.y;
	vec2 sd = (uv - sun_uv) * vec2(aspect, 1.0);
	float breathe = 0.82 + 0.18 * sin(6.2831853 * t / 7.2);
	float glow = exp(-dot(sd, sd) / 0.0065) * sun_glow * breathe;
	float flare = exp(-abs(sd.y) / 0.0045) * exp(-abs(sd.x) / 0.28) * sun_flare * breathe;
	c += vec3(1.0, 0.72, 0.42) * (glow + flare);
	c += vec3(1.0, 0.9, 0.78) * speed_streaks(uv, t) * streaks;
	// readability: darker towards the right and the bottom of the design frame (beyond it the darkest value)
	vec2 f = (lp - frame_origin) / frame_size;
	float right = smoothstep(0.52, 0.98, f.x) * right_dark;
	float bottom = smoothstep(0.80, 1.0, f.y) * bottom_dark;
	vec2 tr = (f - vec2(0.84, 0.13)) * vec2(1.0, 1.9);
	float logo = exp(-dot(tr, tr) / 0.05) * top_right_dark;
	c *= (1.0 - right) * (1.0 - bottom) * (1.0 - logo);
	COLOR = vec4(c, alpha);
}

void vertex() {
	lp = VERTEX;
}
"""

const GLASS_CODE := """
shader_type canvas_item;
render_mode blend_mix;
%s
uniform vec2 origin = vec2(0.0);          // this control's top-left in window pixels (the backdrop's space)
uniform float blur_lod = 3.4;
uniform float blur_px = 7.0;
uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.11, 0.6);
uniform vec4 sheen : source_color = vec4(1.0, 1.0, 1.0, 0.05);
uniform float height = 400.0;
varying vec2 lp;

void fragment() {
	float alpha = COLOR.a;
	float t = TIME + time_offset;
	vec2 uv = photo_uv(lp + origin, t);
	vec2 o = blur_px / img_size * exp2(blur_lod - 1.0);
	vec3 c = textureLod(photo, uv, blur_lod).rgb * 0.2;
	c += textureLod(photo, uv + vec2(o.x, 0.0), blur_lod).rgb * 0.1;
	c += textureLod(photo, uv - vec2(o.x, 0.0), blur_lod).rgb * 0.1;
	c += textureLod(photo, uv + vec2(0.0, o.y), blur_lod).rgb * 0.1;
	c += textureLod(photo, uv - vec2(0.0, o.y), blur_lod).rgb * 0.1;
	c += textureLod(photo, uv + o * 0.7, blur_lod).rgb * 0.1;
	c += textureLod(photo, uv - o * 0.7, blur_lod).rgb * 0.1;
	c += textureLod(photo, uv + vec2(o.x, -o.y) * 0.7, blur_lod).rgb * 0.1;
	c += textureLod(photo, uv + vec2(-o.x, o.y) * 0.7, blur_lod).rgb * 0.1;
	c = mix(c, tint.rgb, tint.a);
	// a faint sheen towards the top edge (light from the sky)
	c += sheen.rgb * sheen.a * (1.0 - smoothstep(0.0, 0.35, lp.y / max(height, 1.0)));
	COLOR = vec4(c, alpha);
}

void vertex() {
	lp = VERTEX;
}
"""

static var _backdrop_shader: Shader
static var _glass_shader: Shader
static var _texture: Texture2D

var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if photo() == null:
		return   # picture missing: plain dark background (_draw)
	_mat = ShaderMaterial.new()
	_mat.shader = backdrop_shader()
	apply_map_params(_mat)
	_mat.set_shader_parameter("sun_uv", SUN_UV)
	_mat.set_shader_parameter("road_vp", ROAD_VP)
	_mat.set_shader_parameter("road_slopes", ROAD_SLOPES)
	var boxes := PackedVector4Array()
	for b in VEHICLES:
		boxes.append(b)
	_mat.set_shader_parameter("boxes", boxes)
	material = _mat
	resized.connect(_update_view)
	_update_view()


## The photo (imported with mipmaps: the glass blurs with them); null if the file is missing.
static func photo() -> Texture2D:
	if _texture == null and ResourceLoader.exists(IMAGE_PATH):
		_texture = load(IMAGE_PATH)
	return _texture


static func backdrop_shader() -> Shader:
	if _backdrop_shader == null:
		_backdrop_shader = Shader.new()
		_backdrop_shader.code = BACKDROP_CODE % MAP_CODE
	return _backdrop_shader


## Material of a frosted-glass panel (GlassPanel): the same photo and Ken Burns transform, blurred and tinted.
static func glass_material() -> ShaderMaterial:
	if _glass_shader == null:
		_glass_shader = Shader.new()
		_glass_shader.code = GLASS_CODE % MAP_CODE
	var m := ShaderMaterial.new()
	m.shader = _glass_shader
	apply_map_params(m)
	return m


## Photo, its size and the Ken Burns constants (the same for the backdrop and every glass panel).
static func apply_map_params(m: ShaderMaterial) -> void:
	var tex := photo()
	if tex != null:
		m.set_shader_parameter("photo", tex)
		m.set_shader_parameter("img_size", Vector2(tex.get_size()))
	m.set_shader_parameter("kb_zoom", KB_ZOOM)
	m.set_shader_parameter("kb_period", KB_PERIOD)
	m.set_shader_parameter("kb_pan_period", KB_PAN_PERIOD)
	m.set_shader_parameter("kb_focus_a", KB_FOCUS_A)
	m.set_shader_parameter("kb_focus_b", KB_FOCUS_B)
	# debug/screenshots: --title-time=<s> shifts the animation (e.g. 22.5 = strongest zoom)
	m.set_shader_parameter("time_offset", CliArgs.get_float("title-time", 0.0))


## Image UV of a window pixel at shader time t – the same mapping as the shaders (tests, layout checks).
static func photo_uv(p: Vector2, view: Vector2, img: Vector2, t: float) -> Vector2:
	var s0 := maxf(view.x / img.x, view.y / img.y)
	var ip := (p - view * 0.5) / s0 + img * 0.5
	var z := 1.0 + KB_ZOOM * (0.5 - 0.5 * cos(TAU * t / KB_PERIOD))
	var f := KB_FOCUS_A.lerp(KB_FOCUS_B, 0.5 - 0.5 * cos(TAU * t / KB_PAN_PERIOD)) * img
	return ((f + (ip - f) / z) / img).clamp(Vector2.ZERO, Vector2.ONE)


## Soft elliptic shadow (black, fading out) that lifts a logo off a bright sky (title screen, attract overlay).
static func halo_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.0, 0.06, 0.5))
	g.set_color(1, Color(0.02, 0.0, 0.06, 0.0))
	g.add_point(0.55, Color(0.02, 0.0, 0.06, 0.28))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 128
	return tex


func _update_view() -> void:
	if _mat == null:
		return
	var vs := size if size.x > 2.0 and size.y > 2.0 else get_viewport_rect().size
	_mat.set_shader_parameter("view_size", vs)
	_mat.set_shader_parameter("frame_origin", ((vs - FRAME) * 0.5).max(Vector2.ZERO))
	_mat.set_shader_parameter("frame_size", FRAME.min(vs))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE if _mat != null else UiTheme.BG_DEEP)
