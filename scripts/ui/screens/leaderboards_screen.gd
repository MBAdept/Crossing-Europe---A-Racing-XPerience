class_name LeaderboardsScreen
extends UiScreen
## Leaderboard browser: race boards and stage boards (both directions), filter all / per vehicle
## (◀ ▶, remembered in Settings.leaderboard_filter).

var _boards: Array[Dictionary] = []   ## {key, title, sub}
var _filters: Array[String] = ["all"]
var _filter_index := 0
var _key := ""
var _title: Label
var _sub: Label
var _filter_row: OptionRow
var _table: LeaderboardTable


func build() -> void:
	add_header(tr("Bestenlisten"), tr("Top 10 je Etappe, Richtung und Rennen"))
	hints = [[["ud"], tr("Liste")], [["lr"], tr("Fahrzeugfilter")], [["Esc", "pad:B"], tr("Zurück")]]
	var c := cfg()
	for v in ConfigLoader.lookup(c, "vehicles.order", []):
		_filters.append(str(v))
	_filter_index = maxi(_filters.find(str(Settings.leaderboard_filter)), 0)
	for rid in UiData.visible_race_ids():
		_boards.append({"key": UiData.race_board_key(rid), "title": UiData.race_name(rid), "sub": tr("Rennen"), "race": true})
	for sid in UiData.visible_stage_ids():
		var s: Dictionary = UiData.stages().get(sid, {})
		var a := str(s.get("from", ""))
		var b := str(s.get("to", ""))
		_boards.append({"key": UiData.stage_board_key(sid, a), "title": "%s – %s" % [UiData.city_name(a), UiData.city_name(b)], "sub": tr("Etappe")})
		_boards.append({"key": UiData.stage_board_key(sid, b), "title": "%s – %s" % [UiData.city_name(b), UiData.city_name(a)], "sub": tr("Etappe")})
	var lst: Array = UiKit.scroll_list(6)
	var sc: ScrollContainer = lst[0]
	var box: VBoxContainer = lst[1]
	UiKit.place(self, sc, Rect2(48, 104, 424, 560))
	var first: Button = null
	var last_section := ""
	for bd in _boards:
		var section := tr("RENNEN") if bool(bd.get("race", false)) else tr("ETAPPEN")
		if section != last_section:
			last_section = section
			box.add_child(UiKit.label(section, UiTheme.F.HEADING, 20, UiTheme.ACCENT_2))
		var btn := UiKit.button(str(bd["title"]), 21)
		btn.custom_minimum_size = Vector2(404, 42)
		btn.clip_text = true
		var key := str(bd["key"])
		var title := str(bd["title"])
		var sub := str(bd["sub"])
		btn.focus_entered.connect(func() -> void: _show(key, title, sub))
		box.add_child(btn)
		if first == null:
			first = btn
	var right := add_panel(Rect2(492, 104, 732, 560), UiTheme.GOLD, 6)
	_title = UiKit.label("", UiTheme.F.TITLE, 32, Color.WHITE)
	right.add_child(_title)
	_sub = UiKit.label("", UiTheme.F.BODY_MEDIUM, 19, UiTheme.TEXT_DIM)
	right.add_child(_sub)
	_filter_row = OptionRow.new(tr("Fahrzeug"), [], 0)
	var names: Array[String] = []
	for f in _filters:
		names.append(UiFormat.vehicle_name(f, c))
	_filter_row.set_values(names, _filter_index)
	_filter_row.focus_mode = Control.FOCUS_NONE
	_filter_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_filter_row.value_changed.connect(_on_filter)
	right.add_child(_filter_row)
	_table = LeaderboardTable.new()
	_table.custom_minimum_size = Vector2(690, 400)
	right.add_child(_table)
	if first == null:
		_title.text = tr("Keine Bestenlisten")
		var back := UiKit.button(tr("Zurück"), 22)
		back.pressed.connect(GameFlow.back)
		box.add_child(back)
		first = back
	default_focus = first
	if not _boards.is_empty():
		_show(str(_boards[0]["key"]), str(_boards[0]["title"]), str(_boards[0]["sub"]))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		_filter_row.step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right", true):
		_filter_row.step(1)
		get_viewport().set_input_as_handled()


func _on_filter(i: int) -> void:
	_filter_index = i
	Settings.leaderboard_filter = _filters[i]
	if not GameFlow.sample_mode:
		Settings.save_settings()
	_refresh()


func _show(key: String, title: String, sub: String) -> void:
	_key = key
	_title.text = title
	_sub.text = sub
	_refresh()


func _refresh() -> void:
	_table.set_entries(UiData.top(_key, _filters[_filter_index], 10))
