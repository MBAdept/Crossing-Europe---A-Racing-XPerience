class_name BenchOverlay
extends Control
## Overlay of the Leistungstest (v0.8.0) over the race picture while ModernBenchmark drives its scenes: at the top
## centre the badge "LEISTUNGSTEST" with "Szene 2 von 3 · Stadt bei Nacht im Regen" (or "… wird vorbereitet" while
## the renderer still prepares the stage), at the bottom left how to end it (B / Esc), along the bottom edge a thin
## line that fills up over the whole test. The race picture and the full HUD stay as in a race – they are what is
## measured. The layout follows the size of the picture (Modern fills a 16:10 window).
## GameFlow puts it on a canvas layer above the race scene and feeds it from the runner's public state.

const LAYER := 60

var runner: Node = null              ## ModernBenchmark: scene_index, scene_count, scene_name, phase (duck-typed)
var progress := 0.0                  ## 0..1 of the whole test (signal progress of the runner)
var _t := 0.0
var _f_bold: Font
var _f_body: Font
var _f_title: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_f_bold = UiTheme.font(UiTheme.F.BODY_BOLD)
	_f_body = UiTheme.font(UiTheme.F.BODY)
	_f_title = UiTheme.font(UiTheme.F.TITLE)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Text next to the badge: which scene, or that it is being prepared.
func scene_text() -> String:
	if runner == null or not is_instance_valid(runner):
		return ""
	var n := int(runner.get("scene_count"))
	var i := clampi(int(runner.get("scene_index")) + 1, 1, maxi(n, 1))
	var text := tr("Szene %d von %d") % [i, maxi(n, 1)]
	var scene_name := str(runner.get("scene_name"))
	if scene_name != "":
		text += "  ·  " + scene_name
	if int(runner.get("phase")) == 1:   # ModernBenchmark.Phase.PREPARING
		text += "  ·  " + tr("wird vorbereitet")
	return text


func _draw() -> void:
	var w := size.x if size.x > 2.0 else 1280.0
	var h := size.y if size.y > 2.0 else 720.0
	# badge and scene, centred at the top
	var badge_text := tr("LEISTUNGSTEST")
	var text := scene_text()
	var badge_w := _f_bold.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 26.0
	var text_w := _f_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 12.0 if text != "" else 0.0
	var x := w * 0.5 - (badge_w + text_w) * 0.5
	var y := 12.0
	UiIcons.panel(self, Rect2(x - 6.0, y - 5.0, badge_w + text_w + 18.0, 38.0), Color(0.02, 0.03, 0.09, 0.7), Color(UiTheme.ACCENT_2, 0.38), 8.0, 1.5)
	var pulse := 0.75 + 0.25 * sin(_t * TAU * 0.5)
	var r := Rect2(x, y, badge_w, 28)
	UiIcons.panel(self, r, Color(UiTheme.ACCENT_2.darkened(0.45), 0.8 * pulse + 0.2), Color(1, 1, 1, 0.5), 6.0, 1.0)
	draw_string(_f_bold, Vector2(r.position.x, r.position.y + 21.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, Color.WHITE)
	if text != "":
		var p := Vector2(r.end.x + 12.0, y + 21.0)
		draw_string(_f_body, p + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0, 0, 0, 0.75))
		draw_string(_f_body, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiTheme.TEXT)
	# how to end it, bottom left (the key of the active device)
	var key := "pad:B" if InputMode.gamepad else "Esc"
	var label := tr("Abbrechen")
	var kw := KeyHints.glyph_width(key, _f_bold)
	var lw := _f_body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var pill := Rect2(24.0, h - 52.0 - 19.0, kw + lw + 44.0, 38.0)
	UiIcons.panel(self, pill, Color(0.02, 0.03, 0.09, 0.66), Color(UiTheme.ACCENT_2, 0.38), 10.0, 1.5)
	KeyHints.draw_glyph(self, Rect2(pill.position.x + 16.0, pill.position.y + 6.0, kw, 26.0), key, _f_bold)
	draw_string(_f_body, Vector2(pill.position.x + 16.0 + kw + 10.0, pill.position.y + 26.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.TEXT)
	# progress of the whole test
	draw_rect(Rect2(0, h - 4.0, w, 4.0), Color(0, 0, 0, 0.4))
	if progress > 0.0:
		draw_rect(Rect2(0, h - 4.0, w * clampf(progress, 0.0, 1.0), 4.0), Color(UiTheme.ACCENT_2, 0.9))
