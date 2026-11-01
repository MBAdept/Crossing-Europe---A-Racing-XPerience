class_name AttractOverlay
extends Control
## Overlay of the attract demo (AttractMode), laid out in the 1280×720 race frame above the (reduced) HUD:
##   top centre   logo in one line (chrome gradient) on a soft dark halo, below it a "DEMO" badge with the scene's
##                name – over the sky; landmarks rise at the sides of the road and stay free,
##   bottom left  a blinking "Taste drücken" on a dark pill with the key glyphs of the active device (gamepad: Ⓐ;
##                keyboard: Enter and Ⓐ – any key works); the player's car keeps the bottom centre,
##   bottom edge  a thin line that fills up over the demo (`progress`, set by AttractMode).
## The HUD keeps the clock panel (top left) and the speedometer (bottom right).

const LOGO_SIZE := 36
const LOGO_Y := 10.0
const BADGE_Y := 64.0
const PROMPT := Vector2(24, 668)      ## left end and centre line of the prompt pill

var scene_name := ""
var progress := 0.0
var _t := 0.0
var _f_title: Font
var _f_bold: Font
var _f_body: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_f_title = UiTheme.font(UiTheme.F.TITLE)
	_f_bold = UiTheme.font(UiTheme.F.BODY_BOLD)
	_f_body = UiTheme.font(UiTheme.F.BODY)
	var halo := TextureRect.new()
	halo.texture = TitleBackdrop.halo_texture()
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.modulate.a = 0.8
	UiKit.place(self, halo, Rect2(640 - 380, -70, 760, 230))
	var logo := GradientText.new("CROSSING EUROPE", UiTheme.font(UiTheme.F.LOGO), LOGO_SIZE)
	logo.align = HORIZONTAL_ALIGNMENT_CENTER
	logo.outline = 8
	logo.shadow_offset = Vector2(3, 3)
	UiKit.place(self, logo, Rect2(640 - 300, LOGO_Y, 600, 52))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_draw_badge()
	_draw_prompt()
	if progress > 0.0:
		var w := size.x if size.x > 2.0 else 1280.0
		var h := size.y if size.y > 2.0 else 720.0
		draw_rect(Rect2(0, h - 3, w, 3), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, h - 3, w * progress, 3), Color(UiTheme.ACCENT, 0.8))


## "DEMO" badge and the scene's name, centred under the logo.
func _draw_badge() -> void:
	var badge_w := _f_bold.get_string_size("DEMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 26.0
	var name_w := 0.0
	if scene_name != "":
		name_w = _f_body.get_string_size(scene_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 12.0
	var w := size.x if size.x > 2.0 else 1280.0
	var x := w * 0.5 - (badge_w + name_w) * 0.5
	if name_w > 0.0:
		# dark pill behind badge and name: readable over a bright snowy or midday sky as well
		UiIcons.panel(self, Rect2(x - 5.0, BADGE_Y - 4.0, badge_w + name_w + 14.0, 36.0), Color(0.02, 0.03, 0.09, 0.55), Color(0, 0, 0, 0), 8.0)
	var pulse := 0.75 + 0.25 * sin(_t * TAU * 0.5)
	var r := Rect2(x, BADGE_Y, badge_w, 28)
	UiIcons.panel(self, r, Color(UiTheme.ACCENT, 0.88 * pulse + 0.1), Color(1, 1, 1, 0.5), 6.0, 1.0)
	draw_string(_f_bold, Vector2(r.position.x, r.position.y + 21), "DEMO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, Color.WHITE)
	if scene_name != "":
		var p := Vector2(r.end.x + 12.0, BADGE_Y + 21.0)
		draw_string(_f_body, p + Vector2(1, 2), scene_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0, 0, 0, 0.75))
		draw_string(_f_body, p, scene_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiTheme.TEXT)


## Blinking "Taste drücken" with the glyphs of the active input device.
func _draw_prompt() -> void:
	var text := tr("Taste drücken")
	var fs := 26
	var keys: Array[String] = ["pad:A"]
	if not InputMode.gamepad:
		keys.push_front("Enter")
	var keys_w := 0.0
	for k in keys:
		keys_w += _key_w(k) + 6.0
	var text_w := _f_title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(PROMPT.x, PROMPT.y - 23.0, keys_w + 8.0 + text_w + 40.0, 46.0)
	UiIcons.panel(self, pill, Color(0.02, 0.03, 0.09, 0.66), Color(UiTheme.ACCENT_2, 0.38), 10.0, 1.5)
	# smooth blink: never fully gone, so the hint stays findable
	var a := 0.38 + 0.62 * (0.5 + 0.5 * cos(_t * TAU * 0.9))
	var x := pill.position.x + 20.0
	for k in keys:
		var kw := _key_w(k)
		_draw_key(Rect2(x, PROMPT.y - 13.0, kw, 26.0), k, a)
		x += kw + 6.0
	x += 8.0
	var base := Vector2(x, PROMPT.y + 9.0)
	draw_string(_f_title, base + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
	draw_string(_f_title, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))


func _key_w(k: String) -> float:
	if k.begins_with("pad:"):
		return 26.0
	return maxf(26.0, _f_bold.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 16.0)


## Keycap or gamepad button in the style of KeyHints.
func _draw_key(r: Rect2, key: String, a: float) -> void:
	if key.begins_with("pad:"):
		var b := key.substr(4)
		var col: Color = KeyHints.PAD_COLORS.get(b, Color(0.35, 0.38, 0.5))
		var c := r.get_center()
		draw_circle(c, 12.0, Color(0.05, 0.06, 0.12, maxf(a, 0.6)))
		draw_arc(c, 12.0, 0.0, TAU, 24, Color(col, a), 2.0, true)
		draw_string(_f_bold, Vector2(r.position.x, c.y + 5.5), b, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(col, a))
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.85, 0.87, 0.95, 0.95 * a)
	box.border_color = Color(0.45, 0.48, 0.6, a)
	box.border_width_bottom = 3
	box.set_corner_radius_all(4)
	draw_style_box(box, r)
	draw_string(_f_bold, Vector2(r.position.x, r.position.y + 18.5), key, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(0.08, 0.09, 0.16, a))
