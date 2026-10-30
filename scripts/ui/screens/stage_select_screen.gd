class_name StageSelectScreen
extends UiScreen
## Single stage: free choice of stage and direction, start time and weather; map preview, stage
## facts and record. "Weiter" -> vehicle selection -> stage screen.
##
## Focus (keyboard / gamepad): the stage list on the left (▲▼, wraps; focusing an entry selects it),
## Enter or ▶ on an entry -> the column Richtung / Startzeit / Wetter / Weiter (▲▼, wraps; ◀▶ change
## the values). ◀ on "Weiter" and Esc in the column return to the selected entry; Esc in the list
## leaves the screen. Explicit neighbours everywhere, so the geometric focus search can never jump
## into the list and silently switch the stage.

var _ids: Array[String] = []
var _stage := ""
var _map: MapView
var _dir: OptionRow
var _time: OptionRow
var _weather: OptionRow
var _facts: VBoxContainer
var _steps: Array[int] = []
var _ok: Button
var _buttons: Dictionary = {}          ## stage id -> list Button


func build() -> void:
	add_header(tr("Einzelne Etappe"), tr("Freie Wahl von Strecke, Richtung, Uhrzeit und Wetter"))
	hints = [[["ud"], tr("Wählen")], [["lr"], tr("Ändern")], [["Enter", "pad:A"], tr("Bestätigen")], [["Esc", "pad:B"], tr("Zurück")]]
	_ids = UiData.visible_stage_ids()
	_ids.sort_custom(func(a: String, b: String) -> bool: return _label(a) < _label(b))
	var lst: Array = UiKit.scroll_list(6)
	var sc: ScrollContainer = lst[0]
	var box: VBoxContainer = lst[1]
	UiKit.place(self, sc, Rect2(48, 104, 404, 560))
	var prev := str(GameFlow.single.get("stage_id", ""))
	var first: Button = null
	var preselect: Button = null
	var list: Array[Button] = []
	for id in _ids:
		var b := UiKit.button(_label(id), 21)
		b.custom_minimum_size = Vector2(384, 44)
		b.clip_text = true
		b.focus_entered.connect(func() -> void: _select(id))
		b.pressed.connect(func() -> void: _dir.grab_focus())
		box.add_child(b)
		list.append(b)
		_buttons[id] = b
		if first == null:
			first = b
		if id == prev:
			preselect = b
	_map = MapView.new()
	_map.set_network(UiData.cities(), UiData.stages(), UiData.ferries(), UiData.map_data())
	UiKit.place(self, _map, Rect2(472, 104, 752, 250))
	var opts := UiKit.vbox(4)
	UiKit.place(self, opts, Rect2(472, 362, 752, 170))
	_dir = OptionRow.new(tr("Richtung"), ["–"], 0)
	_dir.value_width = 470.0
	_dir.value_changed.connect(func(_i: int) -> void: _refresh())
	opts.add_child(_dir)
	_steps = UiFormat.start_time_steps(int(ConfigLoader.lookup(cfg(), "time.start_hour_step_minutes", 30)))
	var time_labels: Array[String] = []
	for m in _steps:
		time_labels.append(Units.format_clock(m) + " " + tr("Uhr"))
	var hour := float(GameFlow.single.get("hour", ConfigLoader.lookup(cfg(), "time.default_start_hour", 8.0)))
	_time = OptionRow.new(tr("Startzeit"), time_labels, maxi(_steps.find(int(hour * 60.0)), 0))
	opts.add_child(_time)
	var weather_ids: Array = ConfigLoader.lookup(cfg(), "weather.types", ["normal", "rain", "snow"])
	var weather_labels: Array[String] = []
	for w in weather_ids:
		weather_labels.append(UiFormat.weather_name(str(w)))
	_weather = OptionRow.new(tr("Wetter"), weather_labels, maxi(weather_ids.find(str(GameFlow.single.get("weather", "normal"))), 0))
	opts.add_child(_weather)
	_facts = add_panel(Rect2(472, 528, 752, 84), Color(0, 0, 0, 0), 0, UiTheme.PANEL_SOFT)
	_ok = UiKit.button(tr("Weiter"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	_ok.pressed.connect(_confirm)
	UiKit.place(self, _ok, Rect2(924, 624, 300, 46))
	# focus chains: list (wraps) and the option column (wraps); ▶ from the list -> Richtung
	UiKit.chain_focus(list)
	UiKit.chain_focus([_dir, _time, _weather, _ok])
	for b in list:
		b.focus_neighbor_right = b.get_path_to(_dir)
		b.focus_neighbor_left = b.get_path_to(b)
	_ok.focus_neighbor_right = _ok.get_path_to(_ok)
	default_focus = preselect if preselect != null else first
	if _ids.is_empty():
		_facts.add_child(UiKit.label(tr("Keine Etappen verfügbar."), UiTheme.F.BODY_MEDIUM, 20, UiTheme.WARN))
		default_focus = _ok
	else:
		_select(prev if preselect != null else _ids[0])


func _label(id: String) -> String:
	var s: Dictionary = UiData.stages().get(id, {})
	return "%s – %s" % [UiData.city_name(str(s.get("from", ""))), UiData.city_name(str(s.get("to", "")))]


func _select(id: String) -> void:
	var keep_dir := _stage == id
	_stage = id
	# ◀ from the option column returns to the selected entry (never to another stage)
	var sel: Button = _buttons.get(id, null)
	for row: Control in [_dir, _time, _weather, _ok]:
		row.focus_neighbor_left = row.get_path_to(sel) if sel != null else row.get_path_to(row)
	var s: Dictionary = UiData.stages().get(id, {})
	var a := str(s.get("from", ""))
	var b := str(s.get("to", ""))
	var labels := [tr("von %s nach %s") % [UiData.city_name(a), UiData.city_name(b)], tr("von %s nach %s") % [UiData.city_name(b), UiData.city_name(a)]]
	var idx := _dir.index if keep_dir else (1 if str(GameFlow.single.get("from_city", "")) == b and str(GameFlow.single.get("stage_id", "")) == id else 0)
	_dir.set_values(labels, idx)
	_refresh()


func _from_city() -> String:
	var s: Dictionary = UiData.stages().get(_stage, {})
	return str(s.get("to", "")) if _dir.index == 1 else str(s.get("from", ""))


func _refresh() -> void:
	var from := _from_city()
	var to := UiData.stage_other_end(_stage, from)
	_map.highlight = [{"from": from, "to": to, "style": "current"}]
	_map.current_city = from
	_map.fit_to([from, to])
	for ch in _facts.get_children():
		ch.queue_free()
	var plan := UiData.stage_plan(_stage, from)
	if plan == null:
		return
	var sm := plan.summary()
	var l1 := tr("%s  ·  Autobahn %s, davon %s frei  ·  %d Radar  ·  %d Tankstellen  ·  %d Tunnel") % [
		UiFormat.km(plan.length_km), UiFormat.km(float(sm["autobahn_km"])), UiFormat.km(float(sm["unlimited_km"])),
		int(sm["radars"]), int(sm["stations"]), int(sm["tunnels"])]
	_facts.add_child(UiKit.label(l1, UiTheme.F.BODY_BOLD, 19, UiTheme.TEXT))
	var rec := UiData.record(plan.board_key)
	var rt := tr("Rekord: %s – %s") % [str(rec.get("name", "")), UiFormat.time(float(rec.get("time_s", -1.0)))] if not rec.is_empty() else tr("Noch kein Rekord in dieser Richtung")
	var l2 := tr("Länder: %s  ·  Verkehr: %s") % [UiFormat.countries_chain(sm["countries"]), UiFormat.traffic_level(float(sm["traffic"]))]
	var row := UiKit.hbox(12)
	var a := UiKit.label(l2, UiTheme.F.BODY_MEDIUM, 18, UiTheme.TEXT_DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(UiKit.label(rt, UiTheme.F.BODY_BOLD, 19, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	_facts.add_child(row)


## Esc / gamepad B: from the option column back to the selected list entry, from the list back.
func on_cancel() -> void:
	var f := get_viewport().gui_get_focus_owner()
	var sel: Button = _buttons.get(_stage, null)
	if sel != null and f != null and f in [_dir, _time, _weather, _ok]:
		sel.grab_focus()
		return
	GameFlow.back()


## The list entry of the selected stage (null if the list is empty).
func selected_button() -> Button:
	return _buttons.get(_stage, null)


func _confirm() -> void:
	if _stage == "":
		GameFlow.back()
		return
	var weather_ids: Array = ConfigLoader.lookup(cfg(), "weather.types", ["normal", "rain", "snow"])
	var w := str(weather_ids[_weather.index]) if _weather.index < weather_ids.size() else "normal"
	GameFlow.configure_single(_stage, _from_city(), _steps[_time.index] / 60.0, w)
