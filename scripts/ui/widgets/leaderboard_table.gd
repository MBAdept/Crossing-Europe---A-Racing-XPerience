class_name LeaderboardTable
extends Control
## Top-10 table: rank, name, time, average speed, vehicle and small weather + daytime icons.
## highlight = 1-based rank to emphasise (new entry), 0 = none. compact hides the vehicle column.

var entries: Array = []
var highlight := 0
var compact := false
var title := ""
var empty_text := ""
var config: Dictionary = {}
var _t := 0.0
var _font: Font
var _font_bold: Font
var _mono: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.font(UiTheme.F.BODY_MEDIUM)
	_font_bold = UiTheme.font(UiTheme.F.BODY_BOLD)
	_mono = UiTheme.font(UiTheme.F.MONO)
	if empty_text == "":
		empty_text = tr("Noch keine Einträge – fahr die erste Bestzeit!")
	if config.is_empty():
		config = ConfigLoader.load_merged()


func set_entries(list: Array, p_highlight: int = 0) -> void:
	entries = list
	highlight = p_highlight
	queue_redraw()


func _process(delta: float) -> void:
	if highlight > 0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var y := 0.0
	if title != "":
		draw_string(UiTheme.font(UiTheme.F.HEADING), Vector2(0, 26), title, HORIZONTAL_ALIGNMENT_LEFT, w, 24, UiTheme.TEXT)
		y = 38.0
	var row_h := minf(36.0, (size.y - y - 28.0) / 10.0)
	# column layout
	var c_rank := 6.0
	var c_name := 44.0
	var c_time := w * (0.38 if not compact else 0.55)
	var c_avg := w * (0.56 if not compact else 0.76)
	var c_veh := w * 0.67
	var c_icons := w - 56.0
	var hy := y + 18.0
	var hcol := UiTheme.TEXT_MUTED
	draw_string(_font_bold, Vector2(c_rank, hy), "#", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hcol)
	draw_string(_font_bold, Vector2(c_name, hy), tr("NAME"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hcol)
	draw_string(_font_bold, Vector2(c_time, hy), tr("ZEIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hcol)
	draw_string(_font_bold, Vector2(c_avg, hy), tr("Ø KM/H"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hcol)
	if not compact:
		draw_string(_font_bold, Vector2(c_veh, hy), tr("FAHRZEUG"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hcol)
	y += 26.0
	draw_line(Vector2(0, y - 2), Vector2(w, y - 2), Color(UiTheme.ACCENT_2, 0.35), 1.0)
	if entries.is_empty():
		draw_string(_font, Vector2(0, y + row_h * 1.5), empty_text, HORIZONTAL_ALIGNMENT_CENTER, w, 20, UiTheme.TEXT_DIM)
		return
	for i in mini(entries.size(), 10):
		var e: Dictionary = entries[i]
		var r := Rect2(0, y + i * row_h, w, row_h - 3)
		var is_hl := highlight == i + 1
		if is_hl:
			var pulse := 0.55 + 0.25 * sin(_t * 6.0)
			UiIcons.panel(self, r, Color(UiTheme.ACCENT, 0.32 * pulse + 0.1), Color(UiTheme.ACCENT, 0.9), 6.0, 2.0)
		elif i % 2 == 0:
			draw_rect(r, Color(1, 1, 1, 0.035))
		var base := r.position.y + row_h * 0.5 + 6.0
		var rank_col := UiTheme.TEXT_DIM
		if i == 0:
			rank_col = UiTheme.GOLD
		elif i == 1:
			rank_col = Color("cfd6e6")
		elif i == 2:
			rank_col = Color("d7925a")
		var tc := Color.WHITE if is_hl else UiTheme.TEXT
		draw_string(_mono, Vector2(c_rank, base), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, rank_col)
		draw_string(_font_bold, Vector2(c_name, base), str(e.get("name", "?")), HORIZONTAL_ALIGNMENT_LEFT, c_time - c_name - 8.0, 21, tc)
		draw_string(_mono, Vector2(c_time, base), UiFormat.time(float(e.get("time_s", -1.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.GOLD if i == 0 else tc)
		draw_string(_mono, Vector2(c_avg, base), "%d" % roundi(float(e.get("avg_kmh", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tc)
		if not compact:
			draw_string(_font, Vector2(c_veh, base), UiFormat.vehicle_name(str(e.get("vehicle", "")), config), HORIZONTAL_ALIGNMENT_LEFT, c_icons - c_veh - 4.0, 17, UiTheme.TEXT_DIM)
		var ic := Vector2(c_icons + 14.0, r.position.y + row_h * 0.5 - 1.0)
		UiIcons.weather(self, str(e.get("weather", "normal")), ic, 20.0)
		var dt := str(e.get("daytime", ""))
		if dt == "":
			dt = WorldClock.daytime_category(float(e.get("start_hour", 12.0)), config)
		UiIcons.daytime(self, dt, ic + Vector2(26.0, 0), 20.0)
