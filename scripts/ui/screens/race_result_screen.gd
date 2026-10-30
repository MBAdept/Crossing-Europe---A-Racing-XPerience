class_name RaceResultScreen
extends UiScreen
## Race result: total time (sum of stage times + fixed ferry times, pauses excluded), average,
## route, per-stage table; race leaderboard with name entry for a top-10 time.

var _right: VBoxContainer
var _done: Button
var _board := ""
var _entry: Dictionary = {}


func build() -> void:
	var race: RaceState = GameFlow.race
	if race == null:
		race = RaceState.new()
	GameFlow.finish_race()
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
	left.add_child(route_l)
	var table := _LegTable.new()
	table.legs = race.legs.duplicate()
	table.custom_minimum_size = Vector2(600, 330)
	left.add_child(table)
	_right = add_panel(Rect2(700, 104, 540, 500), UiTheme.GOLD, 10)
	_done = UiKit.button(tr("Hauptmenü"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	_done.pressed.connect(GameFlow.leave_race_to_title)
	UiKit.place(self, _done, Rect2(700, 614, 540, 50))
	var rank := UiData.would_rank(_board, race.total_time_s, "") if race.total_time_s > 0.0 else 0
	var rank_v := UiData.would_rank(_board, race.total_time_s, race.vehicle) if race.total_time_s > 0.0 else 0
	if rank > 0 or rank_v > 0:
		_entry = {"time_s": race.total_time_s, "avg_kmh": race.average_kmh(ts), "vehicle": race.vehicle,
			"weather": str(race.stage_legs()[0].get("weather", "normal")) if race.stage_count() > 0 else "normal",
			"start_hour": race.start_hour, "daytime": WorldClock.daytime_category(race.start_hour, c),
			"date": Time.get_date_string_from_system(), "route": race.route.duplicate()}
		_right.add_child(UiKit.label(tr("RENNEN-TOP-10 – PLATZ %d!") % maxi(rank, rank_v), UiTheme.F.TITLE, 30, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var ne := NameEntry.new(str(Settings.player_name))
		ne.alignment = BoxContainer.ALIGNMENT_CENTER
		ne.submitted.connect(_on_name)
		_right.add_child(ne)
		_done.visible = false
		default_focus = ne.line
		hints = [[["Enter", "pad:A"], tr("Eintragen")], [["ud", "lr"], tr("Tastatur")]]
	else:
		_board_view(0)
		default_focus = _done
	UiKit.sound("finish")


func _on_name(player_name: String) -> void:
	GameFlow.remember_player_name(player_name)
	_entry["name"] = player_name
	UiData.submit(_board, _entry)
	for ch in _right.get_children():
		ch.queue_free()
	var list := UiData.top(_board, "", 10)
	var hl := 0
	for i in list.size():
		if str(list[i].get("name", "")) == player_name and absf(float(list[i].get("time_s", 0.0)) - float(_entry["time_s"])) < 0.0005:
			hl = i + 1
	_board_view(hl)
	_done.visible = true
	_focus_later(_done)
	set_hints([[["Enter", "pad:A"], tr("Hauptmenü")]])


func _board_view(hl: int) -> void:
	_right.add_child(UiKit.label(tr("RENNEN – TOP 10"), UiTheme.F.TITLE, 30, UiTheme.GOLD))
	var t := LeaderboardTable.new()
	t.custom_minimum_size = Vector2(500, 420)
	t.set_entries(UiData.top(_board, "", 10), hl)
	_right.add_child(t)


func on_cancel() -> void:
	pass


class _LegTable extends Control:
	var legs: Array = []

	func _draw() -> void:
		var fb := UiTheme.font(UiTheme.F.BODY_BOLD)
		var fm := UiTheme.font(UiTheme.F.MONO)
		var f := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		var w := size.x
		var hy := 18.0
		var cols := PackedFloat32Array([0.0, 34.0, w * 0.52, w * 0.74, w * 0.88])
		draw_string(fb, Vector2(cols[0], hy), "#", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(cols[1], hy), tr("ETAPPE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(cols[2], hy), tr("ZEIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(cols[3], hy), tr("Ø KM/H"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_line(Vector2(0, hy + 7), Vector2(w, hy + 7), Color(UiTheme.ACCENT_2, 0.35), 1.0)
		var n := legs.size()
		var row_h := minf(30.0, (size.y - 30.0) / maxf(n, 1.0))
		var fs := 19 if row_h >= 26.0 else 15
		var y := hy + 12.0
		var nr := 0
		for i in n:
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
				draw_string(fm, Vector2(cols[0], base), str(nr), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
			draw_string(f, Vector2(cols[1], base), nm, HORIZONTAL_ALIGNMENT_LEFT, float(cols[2]) - float(cols[1]) - 8.0, fs, UiTheme.ACCENT_2 if ferry else UiTheme.TEXT)
			draw_string(fm, Vector2(cols[2], base), UiFormat.time(float(l.get("time_s", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
			if not ferry:
				draw_string(fm, Vector2(cols[3], base), "%d" % roundi(float(l.get("avg_kmh", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
				UiIcons.weather(self, str(l.get("weather", "normal")), Vector2(float(cols[4]) + 12.0, y + row_h * 0.5 - 1.0), row_h * 0.62)
				var hour := Units.hour_of_day(float(l.get("start_world_minutes", 0.0)))
				UiIcons.daytime(self, WorldClock.daytime_category(hour, ConfigLoader.load_merged()), Vector2(float(cols[4]) + 40.0, y + row_h * 0.5 - 1.0), row_h * 0.62)
			y += row_h
