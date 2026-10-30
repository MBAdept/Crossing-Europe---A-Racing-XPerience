class_name VehicleScreen
extends UiScreen
## Vehicle selection: showroom sprite on a turntable, name, stat bars (Höchstgeschwindigkeit,
## Beschleunigung, Agilität, Tank, Verbrauch) and derived values; ◀ ▶ switches, Enter confirms.

var _ids: Array[String] = []
var _index := 0
var _show: CarShowcase
var _name: Label
var _class: Label
var _stats: Control
var _extra: Label
var _dots: Control


func build() -> void:
	var is_race := str(params.get("mode", "race")) == "race"
	var sub := UiData.race_name(str(GameFlow.draft.get("race_id", ""))) if is_race else tr("Einzelne Etappe")
	add_header(tr("Fahrzeug wählen"), sub, tr("Gilt für alle Etappen") if is_race else "")
	hints = [[["lr"], tr("Fahrzeug")], [["Enter", "pad:A"], tr("Auswählen")], [["Esc", "pad:B"], tr("Zurück")]]
	var c := cfg()
	for v in ConfigLoader.lookup(c, "vehicles.order", []):
		_ids.append(str(v))
	if _ids.is_empty():
		_ids.append("limousine")
	var pre := str(GameFlow.draft.get("vehicle", GameFlow.single.get("vehicle", ConfigLoader.lookup(c, "vehicles.default", "limousine"))))
	_index = maxi(_ids.find(pre), 0)
	_show = CarShowcase.new()
	UiKit.place(self, _show, Rect2(48, 112, 660, 400))
	_name = UiKit.label("", UiTheme.F.TITLE, 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_name.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.6))
	_name.add_theme_constant_override("shadow_offset_x", 3)
	_name.add_theme_constant_override("shadow_offset_y", 3)
	UiKit.place(self, _name, Rect2(48, 512, 660, 64))
	_class = UiKit.label("", UiTheme.F.BODY_MEDIUM, 21, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(self, _class, Rect2(48, 572, 660, 30))
	var arrows := _Arrows.new()
	UiKit.place(self, arrows, Rect2(48, 112, 660, 480))
	_dots = _Dots.new()
	(_dots as _Dots).screen = self
	UiKit.place(self, _dots, Rect2(48, 604, 660, 20))
	var panel := add_panel(Rect2(732, 112, 492, 452), UiTheme.ACCENT_2, 10)
	panel.add_child(UiKit.label(tr("DATEN"), UiTheme.F.HEADING, 24, UiTheme.ACCENT_2))
	_stats = _StatBars.new()
	_stats.custom_minimum_size = Vector2(450, 300)
	panel.add_child(_stats)
	_extra = UiKit.label("", UiTheme.F.BODY_MEDIUM, 20, UiTheme.TEXT_DIM)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_extra)
	var ok := UiKit.button(tr("Dieses Fahrzeug nehmen"), 26, HORIZONTAL_ALIGNMENT_CENTER)
	ok.pressed.connect(func() -> void: GameFlow.select_vehicle(_ids[_index]))
	UiKit.place(self, ok, Rect2(752, 590, 452, 56))
	default_focus = ok
	_update(0.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		_switch(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right", true):
		_switch(1)
		get_viewport().set_input_as_handled()


func _switch(d: int) -> void:
	_index = posmod(_index + d, _ids.size())
	UiKit.sound("ui_move")
	_update(float(d))


func _update(dir: float) -> void:
	var c := cfg()
	var id := _ids[_index]
	var spec: Dictionary = ConfigLoader.lookup(c, "vehicles.types." + id, {})
	_show.show_vehicle(id, str(spec.get("showroom", "showroom/" + id)), dir if dir != 0.0 else 1.0)
	_name.text = str(spec.get("name", id)).to_upper()
	var cons := str(spec.get("consumption", "mittel"))
	_class.text = tr("Höchstgeschwindigkeit %d km/h  ·  Tank %d L  ·  Verbrauch %s") % [int(spec.get("vmax_kmh", 0)), int(spec.get("tank_l", 0)), _cons_name(cons)]
	var bars := _stats as _StatBars
	bars.rows = [
		[tr("Höchstgeschwindigkeit"), inverse_lerp(215.0, 275.0, float(spec.get("vmax_kmh", 240))), "%d km/h" % int(spec.get("vmax_kmh", 0)), UiTheme.ACCENT_2],
		[tr("Beschleunigung"), float(spec.get("accel", 3)) / 5.0, "%d / 5" % int(spec.get("accel", 3)), UiTheme.ACCENT_2],
		[tr("Agilität"), float(spec.get("agility", 3)) / 5.0, "%d / 5" % int(spec.get("agility", 3)), UiTheme.ACCENT_2],
		[tr("Tank"), inverse_lerp(35.0, 75.0, float(spec.get("tank_l", 50))), "%d L" % int(spec.get("tank_l", 0)), UiTheme.GOOD],
		[tr("Verbrauch"), _cons_level(cons) / 4.0, _cons_name(cons), UiTheme.WARN.lerp(UiTheme.BAD, _cons_level(cons) / 4.0)],
	]
	bars.queue_redraw()
	var factor := float(ConfigLoader.lookup(c, "vehicles.consumption_factors." + cons, 1.0))
	var tank := float(spec.get("tank_l", 50))
	var r130 := tank / maxf(FuelSystem.base_consumption(c, 130.0) * factor, 0.1) * 100.0
	var r200 := tank / maxf(FuelSystem.base_consumption(c, 200.0) * factor, 0.1) * 100.0
	var acc: Dictionary = ConfigLoader.lookup(c, "vehicles.accel_ratings." + str(int(spec.get("accel", 3))), {})
	_extra.text = tr("0–100 km/h in %s s  ·  0–200 km/h in %s s\nReichweite: %s bei 130 km/h, %s bei 200 km/h") % [
		UiFormat.decimal(float(acc.get("t100_s", 0.0)), 1), UiFormat.decimal(float(acc.get("t200_s", 0.0)), 1),
		UiFormat.km(r130), UiFormat.km(r200)]
	_dots.queue_redraw()


func _cons_level(c: String) -> float:
	match c:
		"niedrig":
			return 1.0
		"mittel":
			return 2.0
		"hoch":
			return 3.0
		"sehr_hoch":
			return 4.0
	return 2.0


func _cons_name(c: String) -> String:
	match c:
		"niedrig":
			return tr("niedrig")
		"hoch":
			return tr("hoch")
		"sehr_hoch":
			return tr("sehr hoch")
	return tr("mittel")


func _click(dir: int) -> void:
	_switch(dir)


class _StatBars extends Control:
	var rows: Array = []

	func _draw() -> void:
		var f := UiTheme.font(UiTheme.F.BODY_BOLD)
		var fm := UiTheme.font(UiTheme.F.MONO)
		var y := 6.0
		for r in rows:
			draw_string(f, Vector2(0, y + 20), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiTheme.TEXT)
			draw_string(fm, Vector2(0, y + 20), str(r[2]), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 20, UiTheme.TEXT_DIM)
			var segs := 20
			var sw := size.x / segs
			var lit := int(roundf(clampf(float(r[1]), 0.0, 1.0) * segs))
			var col: Color = r[3]
			for i in segs:
				var rr := Rect2(i * sw + 1, y + 30, sw - 3, 14)
				draw_rect(rr, col.lerp(Color.WHITE, 0.25 * float(i) / segs) if i < lit else Color(1, 1, 1, 0.08))
			y += 60.0


class _Arrows extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cy := size.y * 0.42
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
		UiIcons.chevron(self, Vector2(26, cy), 44.0, -1.0, Color(UiTheme.ACCENT, pulse), 5.0)
		UiIcons.chevron(self, Vector2(size.x - 26, cy), 44.0, 1.0, Color(UiTheme.ACCENT, pulse), 5.0)

	func _process(_d: float) -> void:
		queue_redraw()


class _Dots extends Control:
	var screen: VehicleScreen

	func _draw() -> void:
		if screen == null:
			return
		var n := screen._ids.size()
		var x0 := size.x * 0.5 - (n - 1) * 11.0
		for i in n:
			var on := i == screen._index
			draw_circle(Vector2(x0 + i * 22.0, size.y * 0.5), 6.0 if on else 4.0, UiTheme.GOLD if on else Color(1, 1, 1, 0.3))
