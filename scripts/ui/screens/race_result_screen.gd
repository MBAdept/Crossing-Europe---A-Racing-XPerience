class_name RaceResultScreen
extends UiScreen
## Race result: total time (sum of stage times + fixed ferry times, pauses excluded), average,
## route (at most two lines), per-stage table and the race leaderboard with name entry for a top-10
## time – in the overall list or in the list of the player's vehicle type.
##
## The stage table has a fixed row height and scrolls when the race has more legs than fit (the
## Königsrennen has 40 stages + ferry): mouse wheel, or ▲▼ while "Hauptmenü" has the focus.
## The save game is cleared only when the result is safe: right away without a placement, otherwise
## after the name entry – closing the game at the name prompt keeps "Rennen fortsetzen", which shows
## this screen again.

const LEG_ROW_H := 28.0
const LEG_FS := 18

var _right: VBoxContainer
var _done: Button
var _board := ""
var _entry: Dictionary = {}
var _legs_scroll: ScrollContainer
var _leg_table: Control


func build() -> void:
	var race: RaceState = GameFlow.race
	if race == null:
		race = RaceState.new()
	var c := cfg()
	var ts := float(ConfigLoader.lookup(c, "time.time_scale", 12.0))
	_board = UiData.race_board_key(race.race_id)
	add_header(tr("Rennen beendet"), race.race_name, UiFormat.vehicle_name(race.vehicle, c))
	hints = [[["Enter", "pad:A"], tr("Bestätigen")]]
	var left := add_panel(Rect2(40, 104, 640, 560), UiTheme.ACCENT, 4)
	left.add_child(UiKit.label(tr("GESAMTZEIT"), UiTheme.F.BODY_BOLD, 18, UiTheme.TEXT_MUTED))
	var big := UiKit.label(UiFormat.time(race.total_time_s), UiTheme.F.MONO, 66, UiTheme.GOLD)
	big.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.55))
	big.add_theme_constant_override("shadow_offset_x", 3)
	big.add_theme_constant_override("shadow_offset_y", 3)
	left.add_child(big)
	left.add_child(UiKit.label(tr("Ø %s  ·  %s  ·  %d Etappen") % [UiFormat.kmh(race.average_kmh(ts)), UiFormat.km(race.total_distance_km()), race.stage_count()], UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	var names: Array[String] = []
	for cid in race.route:
		names.append(UiData.city_name(cid))
	var route_l := UiKit.label(" › ".join(names), UiTheme.F.BODY_MEDIUM, 19, UiTheme.TEXT_DIM)
	route_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_l.max_lines_visible = 2   # long tours: the table below lists every leg anyway
	route_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(route_l)
	var head := _LegTable.new()
	head.legs = race.legs.duplicate()
	head.header_only = true
	head.custom_minimum_size = Vector2(0, 26)
	left.add_child(head)
	_legs_scroll = ScrollContainer.new()
	_legs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_legs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_legs_scroll.focus_mode = Control.FOCUS_NONE
	left.add_child(_legs_scroll)
	var table := _LegTable.new()
	table.legs = race.legs.duplicate()
	table.custom_minimum_size = Vector2(0, LEG_ROW_H * race.legs.size())
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legs_scroll.add_child(table)
	_leg_table = table
	_right = add_panel(Rect2(700, 104, 540, 500), UiTheme.GOLD, 10)
	_done = UiKit.button(tr("Hauptmenü"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	_done.pressed.connect(GameFlow.leave_race_to_title)
	UiKit.place(self, _done, Rect2(700, 614, 540, 50))
	var rank := UiData.would_rank(_board, race.total_time_s, "") if race.total_time_s > 0.0 else 0
	var rank_v := UiData.would_rank(_board, race.total_time_s, race.vehicle) if race.total_time_s > 0.0 and race.vehicle != "" else 0
	if rank > 0 or rank_v > 0:
		_entry = {"time_s": race.total_time_s, "avg_kmh": race.average_kmh(ts), "vehicle": race.vehicle,
			"weather": str(race.stage_legs()[0].get("weather", "normal")) if race.stage_count() > 0 else "normal",
			"start_hour": race.start_hour, "daytime": WorldClock.daytime_category(race.start_hour, c),
			"date": Time.get_date_string_from_system(), "route": race.route.duplicate()}
		var headline := UiFormat.placement_headline(true, rank, rank_v, UiFormat.vehicle_name(race.vehicle, c))
		var hl := UiKit.label(headline, UiTheme.F.TITLE, 30, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(hl)
		var ne := NameEntry.new(str(Settings.player_name))
		ne.alignment = BoxContainer.ALIGNMENT_CENTER
		ne.submitted.connect(_on_name)
		_right.add_child(ne)
		_done.visible = false
		default_focus = ne.line
		hints = NameEntry.key_hints()
	else:
		GameFlow.finish_race()   # nothing to enter: the race is complete, the save can go
		_board_view("", 0)
		default_focus = _done
		_update_hints.call_deferred()
	UiKit.sound("finish")


func _on_name(player_name: String) -> void:
	GameFlow.remember_player_name(player_name)
	_entry["name"] = player_name
	UiData.submit(_board, _entry)
	GameFlow.finish_race()   # entry stored -> the save game is no longer needed
	for ch in _right.get_children():
		ch.queue_free()
	var filter := UiData.board_filter_for(_board, _entry)
	_board_view(filter, UiData.entry_index(UiData.top(_board, filter, 10), _entry) + 1)
	_done.visible = true
	_focus_later(_done)
	_update_hints()


## Race leaderboard; filter "" = all vehicles, else one vehicle type (an entry that only made its
## vehicle's list is shown there, highlighted).
func _board_view(filter: String, hl: int) -> void:
	var head := UiKit.hbox(8)
	var t := UiKit.label(tr("RENNEN – TOP 10"), UiTheme.F.TITLE, 30, UiTheme.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label(UiFormat.vehicle_name(filter, cfg()), UiTheme.F.BODY_BOLD, 19, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	_right.add_child(head)
	var tb := LeaderboardTable.new()
	tb.custom_minimum_size = Vector2(500, 420)
	tb.set_entries(UiData.top(_board, filter, 10), hl)
	_right.add_child(tb)


## Footer once the result is final: "Hauptmenü", plus ▲▼ when the stage table scrolls.
func _update_hints() -> void:
	var h: Array = [[["Enter", "pad:A"], tr("Hauptmenü")]]
	if legs_scrollable():
		h.append([["ud"], tr("Etappen blättern")])
	set_hints(h)


## True if the stage table is taller than its visible area.
func legs_scrollable() -> bool:
	return _leg_table != null and _legs_scroll != null and _leg_table.custom_minimum_size.y > _legs_scroll.size.y + 1.0


## ▲▼ scroll the stage table while "Hauptmenü" has the focus (it has no vertical neighbours).
func _input(event: InputEvent) -> void:
	if _legs_scroll == null or _done == null or not _done.visible or get_viewport().gui_get_focus_owner() != _done:
		return
	var d := 0
	if event.is_action_pressed("ui_down", true):
		d = 1
	elif event.is_action_pressed("ui_up", true):
		d = -1
	if d != 0:
		_legs_scroll.scroll_vertical += int(d * LEG_ROW_H * 2.0)
		get_viewport().set_input_as_handled()


func on_cancel() -> void:
	pass


## Per-stage table (fixed row height; the screen puts it in a ScrollContainer). header_only draws just
## the column titles (kept visible above the scrolled rows). Columns: #, stage, time with the weather
## and daytime icons right next to it, Ø km/h.
class _LegTable extends Control:
	var legs: Array = []
	var header_only := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Column x positions {name, time, icons, avg} – identical for header and rows.
	func columns() -> Dictionary:
		var fm := UiTheme.font(UiTheme.F.MONO)
		var tw := fm.get_string_size("0:00.00", HORIZONTAL_ALIGNMENT_LEFT, -1, LEG_FS).x
		for l in legs:
			tw = maxf(tw, fm.get_string_size(UiFormat.time(float((l as Dictionary).get("time_s", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, LEG_FS).x)
		var c_time := 330.0
		var c_icons := c_time + tw + 8.0
		return {"name": 34.0, "time": c_time, "icons": c_icons, "avg": c_icons + 62.0}

	func _draw() -> void:
		var fb := UiTheme.font(UiTheme.F.BODY_BOLD)
		var fm := UiTheme.font(UiTheme.F.MONO)
		var f := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		var w := size.x
		var cols := columns()
		var c_name: float = cols["name"]
		var c_time: float = cols["time"]
		var c_icons: float = cols["icons"]
		var c_avg: float = cols["avg"]
		if header_only:
			var hy := 18.0
			draw_string(fb, Vector2(0, hy), "#", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
			draw_string(fb, Vector2(c_name, hy), tr("ETAPPE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
			draw_string(fb, Vector2(c_time, hy), tr("ZEIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
			draw_string(fb, Vector2(c_avg, hy), tr("Ø KM/H"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
			draw_line(Vector2(0, hy + 7), Vector2(w, hy + 7), Color(UiTheme.ACCENT_2, 0.35), 1.0)
			return
		var cfg := ConfigLoader.load_merged()
		var row_h := LEG_ROW_H
		var fs := LEG_FS
		var y := 0.0
		var nr := 0
		for i in legs.size():
			var l: Dictionary = legs[i]
			var ferry := str(l.get("kind", "stage")) == "ferry"
			if i % 2 == 0:
				draw_rect(Rect2(0, y, w, row_h - 2), Color(1, 1, 1, 0.035))
			var base := y + row_h * 0.5 + fs * 0.35
			var nm := str(l.get("name", ""))
			if nm == "":
				nm = "%s – %s" % [UiData.city_name(str(l.get("from", ""))), UiData.city_name(str(l.get("to", "")))]
			if not ferry:
				nr += 1
				draw_string(fm, Vector2(0, base), str(nr), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
			draw_string(f, Vector2(c_name, base), nm, HORIZONTAL_ALIGNMENT_LEFT, c_time - c_name - 10.0, fs, UiTheme.ACCENT_2 if ferry else UiTheme.TEXT)
			draw_string(fm, Vector2(c_time, base), UiFormat.time(float(l.get("time_s", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
			if not ferry:
				var cy := y + row_h * 0.5 - 1.0
				UiIcons.weather(self, str(l.get("weather", "normal")), Vector2(c_icons + 10.0, cy), 18.0)
				var hour := Units.hour_of_day(float(l.get("start_world_minutes", 0.0)))
				var dt := str(l.get("daytime", ""))
				if dt == "":
					dt = WorldClock.daytime_category(hour, cfg)
				UiIcons.daytime(self, dt, Vector2(c_icons + 36.0, cy), 18.0)
				draw_string(fm, Vector2(c_avg, base), "%d" % roundi(float(l.get("avg_kmh", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
			y += row_h
