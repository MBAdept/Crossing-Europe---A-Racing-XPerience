class_name StartTimeScreen
extends UiScreen
## Start time of the race (00:00 to 24:00 in time.start_hour_step_minutes steps, 30 by default): big
## clock, daytime category and a preview landscape in the race palette; ◀ ▶ = one step, ▲ ▼ = 1 h.
## Every number in the texts (step, stage pause, time-lapse) comes from the configuration.

var _steps: Array[int] = []
var _index := 0
var _per_hour := 2                    ## steps per hour (▲ ▼)
var _clock: Label
var _cat: Label
var _preview: SkyPreview
var _icon: Control


func build() -> void:
	add_header(tr("Startzeit"), UiData.race_name(str(GameFlow.draft.get("race_id", ""))))
	var c := cfg()
	var step_min := maxi(int(ConfigLoader.lookup(c, "time.start_hour_step_minutes", 30)), 1)
	_per_hour = maxi(1, roundi(60.0 / step_min))
	var big_step := tr("±1 Stunde") if _per_hour * step_min == 60 else tr("±%d Minuten") % (_per_hour * step_min)
	hints = [[["lr"], tr("±%d Minuten") % step_min], [["ud"], big_step], [["Enter", "pad:A"], tr("Rennen starten")], [["Esc", "pad:B"], tr("Zurück")]]
	_steps = UiFormat.start_time_steps(step_min)
	var def_min := int(float(ConfigLoader.lookup(c, "time.default_start_hour", 8.0)) * 60.0)
	_index = 0
	for i in _steps.size():
		if _steps[i] <= def_min:
			_index = i
	var left := add_panel(Rect2(56, 112, 560, 452), UiTheme.ACCENT, 6)
	left.add_child(UiKit.label(tr("ABFAHRT ERSTE ETAPPE"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UiKit.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(row)
	_clock = UiKit.label("08:00", UiTheme.F.MONO, 124, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_clock.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.6))
	_clock.add_theme_constant_override("shadow_offset_x", 4)
	_clock.add_theme_constant_override("shadow_offset_y", 4)
	_clock.custom_minimum_size = Vector2(500, 140)
	row.add_child(_clock)
	_icon = _DaytimeIcon.new()
	_icon.custom_minimum_size = Vector2(0, 54)
	left.add_child(_icon)
	_cat = UiKit.label("", UiTheme.F.HEADING, 28, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_cat)
	var note := UiKit.label(start_note(c), UiTheme.F.BODY_MEDIUM, 19, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(500, 0)
	left.add_child(note)
	var arrows := _ClockArrows.new()
	arrows.clicked.connect(_step)
	UiKit.place(self, arrows, Rect2(56, 150, 560, 160))
	_preview = SkyPreview.new()
	UiKit.place(self, _preview, Rect2(640, 112, 584, 452))
	var ok := UiKit.button(tr("Rennen starten"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	ok.pressed.connect(func() -> void: GameFlow.select_start_time(_steps[_index] / 60.0))
	UiKit.place(self, ok, Rect2(56, 590, 560, 58))
	default_focus = ok
	_update()


## Explanation under the clock: stage pause (time.stage_pause_hours) and time-lapse (time.time_scale).
static func start_note(c: Dictionary) -> String:
	var pause_h := float(ConfigLoader.lookup(c, "time.stage_pause_hours", 12.0))
	var game_min := 60.0 / maxf(float(ConfigLoader.lookup(c, "time.time_scale", 12.0)), 0.001)
	return UiFormat.t("Jede weitere Etappe startet %s nach dem Ende der vorherigen – die Pause zählt nicht zur Rennzeit. Die Uhr läuft im Zeitraffer: 1 Stunde dauert %s Spielminuten.") % [
		UiFormat.hours(pause_h), UiFormat.number(game_min, 1)]


func _input(event: InputEvent) -> void:
	var d := 0
	if event.is_action_pressed("ui_left", true):
		d = -1
	elif event.is_action_pressed("ui_right", true):
		d = 1
	elif event.is_action_pressed("ui_up", true):
		d = _per_hour
	elif event.is_action_pressed("ui_down", true):
		d = -_per_hour
	if d != 0:
		_step(d)
		get_viewport().set_input_as_handled()


func _step(d: int) -> void:
	_index = posmod(_index + d, _steps.size())
	UiKit.sound("ui_move")
	_update()


func _update() -> void:
	var minutes := _steps[_index]
	var hour := minutes / 60.0
	_clock.text = Units.format_clock(minutes)
	var cat := WorldClock.daytime_category(hour, cfg())
	_cat.text = UiFormat.daytime_name(cat)
	(_icon as _DaytimeIcon).cat = cat
	_icon.queue_redraw()
	_preview.hour = hour


class _DaytimeIcon extends Control:
	var cat := "day"

	func _draw() -> void:
		UiIcons.daytime(self, cat, Vector2(size.x * 0.5, size.y * 0.5), 50.0)


class _ClockArrows extends Control:
	signal clicked(dir: int)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var x := (event as InputEventMouseButton).position.x
			if x < 80.0:
				clicked.emit(-1)
			elif x > size.x - 80.0:
				clicked.emit(1)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
		UiIcons.chevron(self, Vector2(28, size.y * 0.5), 40.0, -1.0, Color(UiTheme.ACCENT, pulse), 5.0)
		UiIcons.chevron(self, Vector2(size.x - 28, size.y * 0.5), 40.0, 1.0, Color(UiTheme.ACCENT, pulse), 5.0)
