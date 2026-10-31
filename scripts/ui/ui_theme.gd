class_name UiTheme
extends RefCounted
## Visual identity of menus and HUD: colour palette, fonts and the Godot Theme (built in code).
## Style: retro-modern arcade – deep night blue, hot magenta + cyan accents, gold highlights,
## slanted (skewed) buttons, chamfered panels. Fonts (OFL, from npm @fontsource, see assets/fonts/):
##   LOGO     Orbitron Black          – logo, countdown
##   TITLE    Exo 2 ExtraBold Italic  – screen titles, big messages
##   HEADING  Exo 2 Bold Italic       – headings, card titles
##   BODY / BODY_MEDIUM / BODY_BOLD   Barlow Condensed 600/500/700 – all running text
##   MONO     Share Tech Mono         – times, speeds, numbers
## Every font falls back to the latin-ext cut and finally to Godot's default font (Cyrillic etc.).

const BG_DEEP := Color("060918")
const BG := Color("0b1130")
const PANEL := Color(0.035, 0.05, 0.14, 0.9)
const PANEL_SOFT := Color(0.035, 0.05, 0.14, 0.66)
const PANEL_HUD := Color(0.02, 0.03, 0.09, 0.72)
const PANEL_LINE := Color("2c3c86")
const ACCENT := Color("ff2e88")
const ACCENT_2 := Color("29d8f5")
const GOLD := Color("ffc93c")
const ORANGE := Color("ff8a2a")
const TEXT := Color("eef1ff")
const TEXT_DIM := Color("a3acd8")
const TEXT_MUTED := Color("7882b2")   # >= 4.5:1 on the panels (small labels, Steam Deck)
const GOOD := Color("3fe08f")
const BAD := Color("ff4d63")
const WARN := Color("ffb020")
const POLICE := Color("2f74ff")
const SEA := Color("081633")
const LAND := Color("17234f")

enum F { LOGO, TITLE, HEADING, BODY, BODY_MEDIUM, BODY_BOLD, MONO }

const FONT_DIR := "res://assets/fonts/"
const FONT_FILES := {
	F.LOGO: ["orbitron-latin-900-normal.woff2"],
	F.TITLE: ["exo-2-latin-800-italic.woff2", "exo-2-latin-ext-800-italic.woff2"],
	F.HEADING: ["exo-2-latin-700-italic.woff2", "exo-2-latin-ext-700-italic.woff2"],
	F.BODY: ["barlow-condensed-latin-600-normal.woff2", "barlow-condensed-latin-ext-600-normal.woff2"],
	F.BODY_MEDIUM: ["barlow-condensed-latin-500-normal.woff2", "barlow-condensed-latin-ext-500-normal.woff2"],
	F.BODY_BOLD: ["barlow-condensed-latin-700-normal.woff2", "barlow-condensed-latin-ext-700-normal.woff2"],
	F.MONO: ["share-tech-mono-latin-400-normal.woff2"],
}

static var _fonts: Dictionary = {}
static var _theme: Theme = null
static var _tex_cache: Dictionary = {}


## Font of the given kind (cached). Falls back to the engine default font if a file is missing.
static func font(kind: int) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var files: Array = FONT_FILES.get(kind, [])
	var primary: FontFile = null
	var chain: Array[Font] = []
	for i in files.size():
		var path: String = FONT_DIR + str(files[i])
		if not ResourceLoader.exists(path):
			continue
		var f: FontFile = load(path)
		if f == null:
			continue
		if primary == null:
			primary = f
		else:
			chain.append(f)
	var result: Font = ThemeDB.fallback_font
	if primary != null:
		# Digits/latin of the mono and logo fonts fall back to the body font first.
		if kind == F.MONO or kind == F.LOGO:
			var body := font(F.BODY)
			if body != ThemeDB.fallback_font:
				chain.append(body)
		chain.append(ThemeDB.fallback_font)
		primary.fallbacks = chain
		result = primary
	_fonts[kind] = result
	return result


## The shared Theme for every menu screen (applied to the menu root).
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font(F.BODY)
	t.default_font_size = 22

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)

	# Buttons: slanted parallelograms; focus = magenta glow frame (keyboard/gamepad).
	t.set_font("font", "Button", font(F.HEADING))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("normal", "Button", button_box(Color(0.07, 0.1, 0.26, 0.92), PANEL_LINE, 0, 2))
	t.set_stylebox("hover", "Button", button_box(Color(0.13, 0.17, 0.4, 0.96), ACCENT_2, 0, 2))
	t.set_stylebox("pressed", "Button", button_box(ACCENT.darkened(0.25), ACCENT, 0, 2))
	t.set_stylebox("hover_pressed", "Button", button_box(ACCENT.darkened(0.2), ACCENT, 0, 2))
	t.set_stylebox("disabled", "Button", button_box(Color(0.05, 0.06, 0.14, 0.7), Color(0.2, 0.24, 0.4, 0.6), 0, 1))
	t.set_stylebox("focus", "Button", focus_box())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("h_separation", "Button", 10)

	var panel := panel_box(PANEL, PANEL_LINE)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	# LineEdit (player name)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.02, 0.03, 0.1, 0.95)
	le.border_color = PANEL_LINE
	le.set_border_width_all(2)
	le.set_content_margin_all(10)
	le.content_margin_left = 14
	var le_focus: StyleBoxFlat = le.duplicate()
	le_focus.border_color = ACCENT
	le_focus.shadow_color = Color(ACCENT, 0.45)
	le_focus.shadow_size = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_font("font", "LineEdit", font(F.HEADING))
	t.set_font_size("font_size", "LineEdit", 30)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.45))
	t.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	t.set_constant("caret_width", "LineEdit", 3)

	# Scroll bars: thin, cyan
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(1, 1, 1, 0.05)
	sb_bg.content_margin_left = 4
	sb_bg.content_margin_right = 4
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color(ACCENT_2, 0.45)
	sb_grab.set_corner_radius_all(3)
	var sb_grab_hi: StyleBoxFlat = sb_grab.duplicate()
	sb_grab_hi.bg_color = Color(ACCENT_2, 0.8)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, sb_bg)
		t.set_stylebox("scroll_focus", cls, sb_bg)
		t.set_stylebox("grabber", cls, sb_grab)
		t.set_stylebox("grabber_highlight", cls, sb_grab_hi)
		t.set_stylebox("grabber_pressed", cls, sb_grab_hi)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


## Slanted button background.
static func button_box(bg: Color, border: Color, radius: int = 0, border_w: int = 2, skew: float = 0.22, margin_h: int = 28) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_bottom = border_w + 1
	s.border_width_left = border_w
	s.border_width_top = 1
	s.border_width_right = 1
	s.set_corner_radius_all(radius)
	s.skew = Vector2(skew, 0.0)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = 8
	s.content_margin_bottom = 9
	s.anti_aliasing = true
	return s


## Applies an upright (unskewed), tight button style – keyboard keys, small square buttons.
static func apply_square_button(b: Button, margin_h: int = 4) -> void:
	b.add_theme_stylebox_override("normal", button_box(Color(0.07, 0.1, 0.26, 0.92), PANEL_LINE, 3, 2, 0.0, margin_h))
	b.add_theme_stylebox_override("hover", button_box(Color(0.13, 0.17, 0.4, 0.96), ACCENT_2, 3, 2, 0.0, margin_h))
	b.add_theme_stylebox_override("pressed", button_box(ACCENT.darkened(0.25), ACCENT, 3, 2, 0.0, margin_h))
	b.add_theme_stylebox_override("hover_pressed", button_box(ACCENT.darkened(0.2), ACCENT, 3, 2, 0.0, margin_h))
	b.add_theme_stylebox_override("focus", focus_box(0.0))


## Applies a lightly slanted style for large card buttons (route options, list entries with content).
static func apply_card_button(b: Button, skew: float = 0.04) -> void:
	b.add_theme_stylebox_override("normal", button_box(Color(0.05, 0.08, 0.21, 0.92), PANEL_LINE, 2, 2, skew, 20))
	b.add_theme_stylebox_override("hover", button_box(Color(0.1, 0.14, 0.34, 0.95), ACCENT_2, 2, 2, skew, 20))
	b.add_theme_stylebox_override("pressed", button_box(Color(0.25, 0.06, 0.2, 0.95), ACCENT, 2, 2, skew, 20))
	b.add_theme_stylebox_override("hover_pressed", button_box(Color(0.25, 0.06, 0.2, 0.95), ACCENT, 2, 2, skew, 20))
	var fb := focus_box(skew)
	b.add_theme_stylebox_override("focus", fb)


## Focus frame drawn on top of the button (no fill): magenta border + glow.
static func focus_box(skew: float = 0.22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = ACCENT
	s.set_border_width_all(3)
	s.skew = Vector2(skew, 0.0)
	s.shadow_color = Color(ACCENT, 0.55)
	s.shadow_size = 10
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	s.anti_aliasing = true
	return s


## Panel background with a thin border and an accent line at the top.
static func panel_box(bg: Color = PANEL, border: Color = PANEL_LINE, accent: Color = Color(0, 0, 0, 0), margin: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	if accent.a > 0.0:
		s.border_color = accent
		s.border_width_top = 3
	s.set_corner_radius_all(2)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


## Vertical gradient texture (cached), e.g. for header bars.
static func gradient_tex(c0: Color, c1: Color, horizontal: bool = true) -> GradientTexture2D:
	var key := "%s|%s|%s" % [c0.to_html(), c1.to_html(), horizontal]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256 if horizontal else 4
	tex.height = 4 if horizontal else 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	_tex_cache[key] = tex
	return tex


## Colour of a time delta (negative = faster = good).
static func delta_color(delta_s: float) -> Color:
	return GOOD if delta_s <= 0.0 else BAD


## Colour for a weather id (icons, accents).
static func weather_color(w: String) -> Color:
	match w:
		"rain":
			return Color("7fb2ff")
		"snow":
			return Color("e6f2ff")
	return GOLD
