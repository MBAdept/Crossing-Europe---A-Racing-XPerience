extends SceneTree
## Renders the "Crossing Europe" brand logo exactly as the title screen draws it, as high-resolution
## transparent PNGs for the Steam library artwork (grid capsules, hero/logo overlay, icon).
##
## Run (needs a real GL context, e.g. a virtual X server):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       -s res://tools/steam/render_logo.gd [-- --out=DIR --scale=6 --only=logo_wide,monogram_ce]
## Output directory: --out=DIR, else $CE_LOGO_OUT, else DEFAULT_OUT (/tmp/crossing-europe-steam/logo).
## Files: logo_stacked_left[_glow] (title-screen layout), logo_stacked_center[_glow], logo_wide[_glow],
## monogram_ce; tools/steam/compose.py builds the Steam set from them.
##
## The logo lines are the real GradientText widget with UiTheme's Orbitron Black, the tagline the same Label
## (Exo 2 ExtraBold Italic, FontVariation glyph spacing, menu theme) that scripts/ui/screens/title_screen.gd
## builds; every size of the title screen (1280x720 design space) is multiplied by --scale.
## Fonts are dynamic (no MSDF): FreeType rasterises the glyphs at the scaled size, the SubViewports force
## font oversampling 1.0, so the output is real high-resolution type, not an upscaled bitmap.
##
## Pipeline per image, one SubViewport per pass:
##   layout (transparent; the canvas blends into premultiplied colour)
##   [glow only: 1/DOWN downsample -> gaussian H -> gaussian V, two radii, logo lines and tagline separately]
##   -> final pass (blend_disabled): glow under the logo, un-premultiply to straight alpha
##   -> crop to the visible pixels (incl. shadow / glow) + PAD_FRAC transparent padding -> PNG.

const DEFAULT_OUT := "/tmp/crossing-europe-steam/logo"

# Title-screen geometry (title_screen.gd): "CROSSING" at (84, 30), "EUROPE" at (84, 114), tagline at (92, 208).
const LOGO_FS := 80
const LOGO_OUTLINE := 10
const LOGO_SHADOW := Vector2(5, 5)
const LINE_STEP := 84.0
const TAG_FROM_LINE := Vector2(8, 94)      # tagline position relative to the "EUROPE" line
const TAGLINE := "A RACING XPERIENCE"
const TAG_FS := 27
const TAG_SPACING := 5
const TAG_SHADOW := Vector2(2, 2)

const MARGIN := 256         # transparent border of every pass (shadow + glow room), multiple of DOWN
const DOWN := 4             # the glow is blurred at 1/DOWN resolution
const PAD_FRAC := 0.02      # transparent padding around the cropped result (of the longer side)

# Soft outer glow (title-screen px, scaled like everything else): two gaussians, pink around the logo
# lines, cyan around the tagline (their own accent colours).
const GLOW_SIGMA_TIGHT := 3.0
const GLOW_SIGMA_WIDE := 10.0
const GLOW_K_TIGHT := 0.35
const GLOW_K_WIDE := 0.5
const GLOW_ALPHA_CUT := 2.0 / 255.0

const DOWN_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
// 4x4 box downsample of the layout alpha (4 bilinear taps); r = logo lines, g = tagline (below split_y).
uniform float split_y = 2.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 u0 = UV + vec2(-px.x, -px.y);
	vec2 u1 = UV + vec2(px.x, -px.y);
	vec2 u2 = UV + vec2(-px.x, px.y);
	vec2 u3 = UV + vec2(px.x, px.y);
	float a0 = texture(TEXTURE, u0).a;
	float a1 = texture(TEXTURE, u1).a;
	float a2 = texture(TEXTURE, u2).a;
	float a3 = texture(TEXTURE, u3).a;
	float t0 = u0.y < split_y ? 0.0 : 1.0;
	float t1 = u1.y < split_y ? 0.0 : 1.0;
	float t2 = u2.y < split_y ? 0.0 : 1.0;
	float t3 = u3.y < split_y ? 0.0 : 1.0;
	float lines = a0 * (1.0 - t0) + a1 * (1.0 - t1) + a2 * (1.0 - t2) + a3 * (1.0 - t3);
	float tag = a0 * t0 + a1 * t1 + a2 * t2 + a3 * t3;
	COLOR = vec4(lines * 0.25, tag * 0.25, 0.0, 1.0);
}
"""

const BLUR_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
// Separable gaussian with two radii. First pass input: r = lines, g = tagline.
// Output (both passes): r = lines tight, g = lines wide, b = tagline tight, a = tagline wide.
uniform vec2 dir = vec2(1.0, 0.0);
uniform float sigma_tight = 4.5;
uniform float sigma_wide = 15.0;
uniform bool second = false;
void fragment() {
	vec2 st = TEXTURE_PIXEL_SIZE * dir;
	int r = int(ceil(3.0 * max(sigma_tight, sigma_wide)));
	float d1 = 2.0 * sigma_tight * sigma_tight;
	float d2 = 2.0 * sigma_wide * sigma_wide;
	vec4 acc = vec4(0.0);
	float w1s = 0.0;
	float w2s = 0.0;
	for (int i = -r; i <= r; i++) {
		float fi = float(i);
		float w1 = exp(-fi * fi / d1);
		float w2 = exp(-fi * fi / d2);
		vec4 s = texture(TEXTURE, UV + st * fi);
		if (second) {
			acc += vec4(s.r * w1, s.g * w2, s.b * w1, s.a * w2);
		} else {
			acc += vec4(s.r * w1, s.r * w2, s.g * w1, s.g * w2);
		}
		w1s += w1;
		w2s += w2;
	}
	COLOR = vec4(acc.r / w1s, acc.g / w2s, acc.b / w1s, acc.a / w2s);
}
"""

const FINAL_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
// TEXTURE = layout render (premultiplied colour). Puts the glow underneath and writes straight alpha.
uniform sampler2D glow_tex : filter_linear, repeat_disable;
uniform bool glow_on = false;
uniform vec4 col_lines = vec4(1.0, 0.18, 0.53, 1.0);
uniform vec4 col_tag = vec4(0.16, 0.85, 0.96, 1.0);
uniform float k_tight = 0.35;
uniform float k_wide = 0.5;
uniform float alpha_cut = 0.0;
void fragment() {
	vec4 p = texture(TEXTURE, UV);
	vec3 prem = p.rgb;
	float a = p.a;
	if (glow_on) {
		vec4 g = texture(glow_tex, UV);
		float al = clamp(k_tight * g.r + k_wide * g.g, 0.0, 1.0);
		float at = clamp(k_tight * g.b + k_wide * g.a, 0.0, 1.0);
		vec3 gp = col_tag.rgb * at + col_lines.rgb * al * (1.0 - at);
		float ga = at + al * (1.0 - at);
		prem += gp * (1.0 - a);
		a += ga * (1.0 - a);
	}
	if (a <= alpha_cut) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(clamp(prem / a, 0.0, 1.0), a);
	}
}
"""

var sc := 6.0
var out_dir := DEFAULT_OUT
var only: PackedStringArray = []
var _shaders: Dictionary = {}


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lf := UiTheme.font(UiTheme.F.LOGO) as FontFile
	if lf != null:
		print("logo font %s: msdf=%s oversampling=%s fixed_size=%d -> glyphs rasterised at %d px" % [
			lf.resource_path.get_file(), lf.multichannel_signed_distance_field, lf.oversampling, lf.fixed_size, roundi(LOGO_FS * sc)])
	var probe := _make("tag", TAGLINE, false)
	print("scale x%.2f (logo %d px, outline %d, tagline %d px, tagline shadow outline %d), output: %s" % [
		sc, roundi(LOGO_FS * sc), roundi(LOGO_OUTLINE * sc), roundi(TAG_FS * sc),
		probe.get_theme_constant("shadow_outline_size"), out_dir])
	probe.free()

	# Ink bounds of every element without its shadow ("body"), relative to the element's position.
	var b := {}
	for t in ["CROSSING", "EUROPE", "CROSSING EUROPE", "CE"]:
		b[t] = await _measure("line", t)
	b["tag"] = await _measure("tag", TAGLINE)
	for k in b:
		print("  body %-16s %s" % [k, b[k]])

	var line2 := LINE_STEP * sc
	var tag_off := TAG_FROM_LINE * sc
	# Title screen: left-aligned stack, exact title-screen offsets.
	var left := [
		_item("line", "CROSSING", Vector2.ZERO, b["CROSSING"]),
		_item("line", "EUROPE", Vector2(0, line2), b["EUROPE"]),
		_item("tag", TAGLINE, Vector2(0, line2) + tag_off, b["tag"]),
	]
	# Same stack, every line centred on its visible glyphs (shadow hangs off to the lower right as usual).
	var center := [
		_item("line", "CROSSING", Vector2(_cx(b["CROSSING"]), 0), b["CROSSING"]),
		_item("line", "EUROPE", Vector2(_cx(b["EUROPE"]), line2), b["EUROPE"]),
		_item("tag", TAGLINE, Vector2(_cx(b["tag"]), line2 + tag_off.y), b["tag"]),
	]
	# One line, tagline centred below at the title screen's line -> tagline distance.
	var wide := [
		_item("line", "CROSSING EUROPE", Vector2(_cx(b["CROSSING EUROPE"]), 0), b["CROSSING EUROPE"]),
		_item("tag", TAGLINE, Vector2(_cx(b["tag"]), tag_off.y), b["tag"]),
	]
	var mono := [_item("line", "CE", Vector2.ZERO, b["CE"])]

	var jobs := [
		["logo_stacked_left", left, false],
		["logo_stacked_left_glow", left, true],
		["logo_stacked_center", center, false],
		["logo_stacked_center_glow", center, true],
		["logo_wide", wide, false],
		["logo_wide_glow", wide, true],
		["monogram_ce", mono, false],
	]
	for j in jobs:
		if only.is_empty() or only.has(j[0]):
			await _render(j[0], j[1], j[2])
	quit()


func _parse_args() -> void:
	var env := OS.get_environment("CE_LOGO_OUT")
	if env != "":
		out_dir = env
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--scale="):
			sc = a.trim_prefix("--scale=").to_float()
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",", false)
	if out_dir.begins_with("res://") or out_dir.begins_with("user://"):
		out_dir = ProjectSettings.globalize_path(out_dir)


# --- elements -------------------------------------------------------------------------------------------

## A logo line ("CROSSING", ...) or the tagline, built like title_screen.gd but scaled by `sc`.
## measure = true leaves the shadow out (ink bounds of the glyphs + outline only).
func _make(kind: String, text: String, measure: bool) -> Control:
	if kind == "line":
		var g := GradientText.new(text, UiTheme.font(UiTheme.F.LOGO), roundi(LOGO_FS * sc))
		g.outline = roundi(LOGO_OUTLINE * sc)
		g.shadow_offset = (LOGO_SHADOW * sc).round()
		if measure:
			g.shadow_color = Color(0, 0, 0, 0)
		return g
	var tag_font := FontVariation.new()
	tag_font.base_font = UiTheme.font(UiTheme.F.TITLE)
	tag_font.spacing_glyph = roundi(TAG_SPACING * sc)
	var tag := Label.new()
	tag.theme = UiTheme.theme()   # the menu shell's theme (title screen inherits it)
	var shadow_outline := tag.get_theme_constant("shadow_outline_size")
	tag.text = text
	tag.add_theme_font_override("font", tag_font)
	tag.add_theme_font_size_override("font_size", roundi(TAG_FS * sc))
	tag.add_theme_color_override("font_color", UiTheme.ACCENT_2)
	tag.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.0 if measure else 0.6))
	tag.add_theme_constant_override("shadow_offset_x", roundi(TAG_SHADOW.x * sc))
	tag.add_theme_constant_override("shadow_offset_y", roundi(TAG_SHADOW.y * sc))
	tag.add_theme_constant_override("shadow_outline_size", roundi(shadow_outline * sc))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tag


func _item(kind: String, text: String, pos: Vector2, body: Rect2) -> Dictionary:
	return {"kind": kind, "text": text, "pos": pos, "body": body}


## x offset that puts the centre of the element's glyphs on x = 0.
func _cx(body: Rect2) -> float:
	return -(body.position.x + body.size.x * 0.5)


func _shadow(kind: String) -> Vector2:
	return (LOGO_SHADOW if kind == "line" else TAG_SHADOW) * sc


## Rough rectangle of everything the element draws (glyphs + shadow), relative to its position.
func _full_rect(it: Dictionary) -> Rect2:
	var body: Rect2 = it["body"]
	return body.merge(Rect2(body.position + _shadow(it["kind"]), body.size)).grow(4.0 * sc)


func _measure(kind: String, text: String) -> Rect2:
	var font: Font = UiTheme.font(UiTheme.F.LOGO if kind == "line" else UiTheme.F.TITLE)
	var fs := roundi((LOGO_FS if kind == "line" else TAG_FS) * sc)
	var est := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	if kind == "tag":
		est.x += text.length() * TAG_SPACING * sc   # FontVariation glyph spacing
	var vp := _viewport(Vector2i(_ceil4(est.x + MARGIN * 2), _ceil4(font.get_height(fs) + MARGIN * 2)))
	var n := _make(kind, text, true)
	n.position = Vector2(MARGIN, MARGIN)
	vp.add_child(n)
	await _frames(4)
	var used := vp.get_texture().get_image().get_used_rect()
	vp.queue_free()
	return Rect2(Vector2(used.position) - Vector2(MARGIN, MARGIN), Vector2(used.size))


# --- rendering ------------------------------------------------------------------------------------------

func _render(file_name: String, items: Array, glow: bool) -> void:
	var bounds := Rect2()
	for i in items.size():
		var r := _full_rect(items[i])
		r.position += items[i]["pos"]
		bounds = r if i == 0 else bounds.merge(r)
	var origin := Vector2(MARGIN, MARGIN) - bounds.position
	var size := Vector2i(_ceil4(bounds.size.x + MARGIN * 2), _ceil4(bounds.size.y + MARGIN * 2))

	var lay := _viewport(size)
	var lines_bottom := -1.0
	var tag_top := -1.0
	for it in items:
		var n := _make(it["kind"], it["text"], false)
		n.position = (origin + it["pos"]).round()
		lay.add_child(n)
		var body: Rect2 = it["body"]
		if it["kind"] == "line":
			lines_bottom = maxf(lines_bottom, n.position.y + body.end.y + _shadow("line").y)
		else:
			tag_top = n.position.y + body.position.y
	var vps: Array[SubViewport] = [lay]

	var fin_mat := _material("final")
	fin_mat.set_shader_parameter("glow_on", glow)
	fin_mat.set_shader_parameter("alpha_cut", GLOW_ALPHA_CUT if glow else 0.0)
	if glow:
		var small := size / DOWN
		var split := 2.0 if tag_top < 0.0 else (lines_bottom + tag_top) * 0.5 / size.y
		var dn := _viewport(small)
		var dm := _material("down")
		dm.set_shader_parameter("split_y", split)
		_pass_rect(dn, lay.get_texture(), dm, CanvasItem.TEXTURE_FILTER_LINEAR)
		var hv := _viewport(small)
		_pass_rect(hv, dn.get_texture(), _blur_material(Vector2(1, 0), false), CanvasItem.TEXTURE_FILTER_NEAREST)
		var vv := _viewport(small)
		_pass_rect(vv, hv.get_texture(), _blur_material(Vector2(0, 1), true), CanvasItem.TEXTURE_FILTER_NEAREST)
		vps.append_array([dn, hv, vv])
		fin_mat.set_shader_parameter("glow_tex", vv.get_texture())
		fin_mat.set_shader_parameter("col_lines", UiTheme.ACCENT)
		fin_mat.set_shader_parameter("col_tag", UiTheme.ACCENT_2)
		fin_mat.set_shader_parameter("k_tight", GLOW_K_TIGHT)
		fin_mat.set_shader_parameter("k_wide", GLOW_K_WIDE)
	var fin := _viewport(size)
	_pass_rect(fin, lay.get_texture(), fin_mat, CanvasItem.TEXTURE_FILTER_NEAREST)
	vps.append(fin)

	await _frames(vps.size() + 4)
	var img := fin.get_texture().get_image()
	for v in vps:
		v.queue_free()
	_save(img, file_name)


func _save(img: Image, file_name: String) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var pad := roundi(PAD_FRAC * maxi(used.size.x, used.size.y))
	var out := Image.create_empty(used.size.x + pad * 2, used.size.y + pad * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, used, Vector2i(pad, pad))
	out.fix_alpha_edges()   # edge colour under (almost) transparent pixels: no dark halos when resampled naively
	var path := out_dir.path_join(file_name + ".png")
	var err := out.save_png(path)
	print("%s %s  %dx%d (glyphs %dx%d, pad %d)" % ["wrote" if err == OK else "FAILED", path, out.get_width(), out.get_height(), used.size.x, used.size.y, pad])


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.oversampling_override = 1.0   # glyphs rasterised at exactly the requested pixel size
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _pass_rect(vp: SubViewport, tex: Texture2D, mat: Material, filter: CanvasItem.TextureFilter) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = filter
	r.material = mat
	r.position = Vector2.ZERO
	r.size = Vector2(vp.size)
	vp.add_child(r)


func _material(kind: String) -> ShaderMaterial:
	if not _shaders.has(kind):
		var s := Shader.new()
		s.code = {"down": DOWN_SHADER, "blur": BLUR_SHADER, "final": FINAL_SHADER}[kind]
		_shaders[kind] = s
	var m := ShaderMaterial.new()
	m.shader = _shaders[kind]
	return m


func _blur_material(dir: Vector2, second: bool) -> ShaderMaterial:
	var m := _material("blur")
	m.set_shader_parameter("dir", dir)
	m.set_shader_parameter("second", second)
	m.set_shader_parameter("sigma_tight", GLOW_SIGMA_TIGHT * sc / DOWN)
	m.set_shader_parameter("sigma_wide", GLOW_SIGMA_WIDE * sc / DOWN)
	return m


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _ceil4(v: float) -> int:
	return int(ceil(v / DOWN)) * DOWN
